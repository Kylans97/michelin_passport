import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/country_picker_sheet.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/widgets/sheet_dismiss_handle.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../data/repositories/planned_trips_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../models/hotel.dart';
import '../../../models/planned_trip.dart';
import '../../../models/restaurant.dart';
import '../../../models/trip_destination.dart';
import '../../../models/venue_country.dart';
import '../trip_legs.dart';
import 'city_picker_sheet.dart';
import 'hotel_picker_sheet.dart';
import 'restaurant_picker_sheet.dart';
import 'trip_chrome.dart';
import 'trip_eyebrow.dart';

/// Opens the "Create trip"/"Edit trip" bottom sheet. Passing [existingTrip]
/// switches to edit mode (pre-filled fields, updates in place); omitting it
/// creates a new trip. Returns true once saved, or null if dismissed.
Future<bool?> showCreateTripSheet(
  BuildContext context, {
  required String userId,
  required PlannedTripsRepository repo,
  PlannedTrip? existingTrip,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateTripSheet(
      userId: userId,
      repo: repo,
      existingTrip: existingTrip,
    ),
  );
}

class _CreateTripSheet extends StatefulWidget {
  final String userId;
  final PlannedTripsRepository repo;
  final PlannedTrip? existingTrip;

  const _CreateTripSheet({
    required this.userId,
    required this.repo,
    this.existingTrip,
  });

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

/// One destination being edited. [country] is null only while the user
/// hasn't chosen yet; [city] null means the whole country.
class _LegDraft {
  VenueCountry? country;
  CatalogueCity? city;
  DateTime? start;
  DateTime? end;
  _LegDraft({this.country, this.city, this.start, this.end});
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  late final _titleCtrl = TextEditingController(
    text: widget.existingTrip?.title ?? '',
  );
  // Only used against a server without 20261022120000, where the trip's
  // city is still the original free-text field.
  late final _cityCtrl = TextEditingController(
    text: widget.existingTrip?.city ?? '',
  );
  late final _notesCtrl = TextEditingController(
    text: widget.existingTrip?.notes ?? '',
  );

  // Calendar days only. The defaults used to keep the current time of
  // day, so a destination starting on the trip's first (default) day
  // compared as "before" the trip and failed the leg check.
  late DateTime _startDate = DateUtils.dateOnly(
    widget.existingTrip?.startDate ??
        DateTime.now().add(const Duration(days: 30)),
  );
  late DateTime _endDate = DateUtils.dateOnly(
    widget.existingTrip?.endDate ??
        DateTime.now().add(const Duration(days: 33)),
  );

  // At least one leg, always. Several only when the server has
  // destinations (decision 3: each then needs its own dates).
  final List<_LegDraft> _legs = [_LegDraft()];
  List<VenueCountry> _countries = const [];

  // Optional hotel + restaurants to seed the trip with on creation — see
  // Trip Detail for the same picks made incrementally after the trip
  // already exists. Only ever shown/collected for a NEW trip (not editing
  // an existing one): editing a trip is about the trip's own fields, venue
  // management belongs to Trip Detail once the trip exists.
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  late final _restaurantRepo = RestaurantRepository(Supabase.instance.client);
  Hotel? _selectedHotel;
  final List<Restaurant> _selectedRestaurants = [];

  bool _saving = false;
  String? _error;

  late final Future<List<VenueCountry>> _countriesFuture = widget.repo
      .loadAllCountries()
      .then((countries) {
        // Pre-fill the existing trip's destinations once the list
        // resolves — done here (not in initState) since it depends on
        // this future.
        if (mounted) setState(() => _prefill(countries));
        return countries;
      });

  bool get _isEditing => widget.existingTrip != null;
  bool get _multiAllowed => widget.repo.sharedTripsAvailable;
  bool get _isMulti => _legs.length > 1;

  void _prefill(List<VenueCountry> countries) {
    _countries = countries;
    final trip = widget.existingTrip;
    if (trip == null) return;
    VenueCountry? byCode(String code) {
      for (final c in countries) {
        if (c.code.toUpperCase() == code.toUpperCase()) return c;
      }
      return null;
    }

    final legs = effectiveLegs(trip);
    _legs
      ..clear()
      ..addAll([
        for (final leg in legs)
          _LegDraft(
            country: byCode(leg.countryCode),
            city: leg.cityId == null
                ? null
                : (id: leg.cityId!, name: leg.cityName ?? '', region: null),
            start: leg.startDate,
            end: leg.endDate,
          ),
      ]);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _countryLabel(VenueCountry country) =>
      country.flag.isEmpty ? country.name : '${country.flag} ${country.name}';

  String _countryLabelForCode(String code) {
    for (final c in _countries) {
      if (c.code.toUpperCase() == code.toUpperCase()) return _countryLabel(c);
    }
    return code;
  }

  /// The chosen legs as destinations; dates only on a multi-leg trip.
  List<TripDestination> get _destinations => [
    for (final leg in _legs)
      if (leg.country != null)
        TripDestination(
          countryCode: leg.country!.code,
          cityId: leg.city?.id,
          cityName: leg.city?.name,
          startDate: _isMulti ? leg.start : null,
          endDate: _isMulti ? leg.end : null,
        ),
  ];

  String get _scopeLabel =>
      _destinations.map((d) => legLabel(d, _countryLabelForCode)).join(' · ');

  bool _inPlaces(String countryCode, String? cityId) => _destinations.any(
    (d) => d.cityId != null
        ? d.cityId == cityId
        : d.countryCode.toUpperCase() == countryCode.toUpperCase(),
  );

  // Any change to the destinations drops picks that are no longer in one
  // of them — the pickers only offer venues there (codes, never names),
  // so a stale selection would be the one way around that.
  void _dropOutOfScopePicks() {
    if (_selectedHotel case final hotel?
        when !_inPlaces(hotel.countryCode, hotel.cityId)) {
      _selectedHotel = null;
    }
    _selectedRestaurants.removeWhere(
      (r) => !_inPlaces(r.countryCode, r.cityId),
    );
  }

  /// The dates a pick defaults to: its destination's, else the trip's.
  (DateTime, DateTime) _datesFor(String countryCode, String? cityId) {
    if (_isMulti) {
      for (final leg in _legs) {
        final country = leg.country;
        if (country == null || leg.start == null || leg.end == null) continue;
        final matches = leg.city != null
            ? leg.city!.id == cityId
            : country.code.toUpperCase() == countryCode.toUpperCase();
        if (matches) return (leg.start!, leg.end!);
      }
    }
    return (_startDate, _endDate);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now,
      lastDate: DateTime(now.year + 6),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(_startDate.year + 6),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  // Leg dates are chosen inside the trip's own range.
  Future<void> _pickLegDate(int i, {required bool start}) async {
    final leg = _legs[i];
    final first = start ? _startDate : (leg.start ?? _startDate);
    final current = start ? leg.start : leg.end;
    var initial = current ?? first;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(_endDate)) initial = _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: _endDate,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        leg.start = picked;
        if (leg.end != null && leg.end!.isBefore(picked)) leg.end = picked;
      } else {
        leg.end = picked;
      }
    });
  }

  Future<void> _pickCountry(int i, List<VenueCountry> countries) async {
    final picked = await showCountryPickerSheet(context, countries: countries);
    if (picked == null) return;
    setState(() {
      final leg = _legs[i];
      if (leg.country?.code != picked.code) leg.city = null;
      leg.country = picked;
      _dropOutOfScopePicks();
    });
  }

  Future<void> _pickCity(int i) async {
    final country = _legs[i].country;
    if (country == null) return;
    final choice = await showTripCityPicker(
      context,
      countryLabel: _countryLabel(country),
      cities: widget.repo.loadCities(country.code),
    );
    if (choice == null) return;
    setState(() {
      _legs[i].city = choice.city;
      _dropOutOfScopePicks();
    });
  }

  void _addLeg() => setState(() => _legs.add(_LegDraft()));

  void _removeLeg(int i) => setState(() {
    _legs.removeAt(i);
    _dropOutOfScopePicks();
  });

  Future<void> _pickHotel() async {
    final scope = legScope(_destinations);
    if (scope.countryCodes.isEmpty && scope.cityIds.isEmpty) return;
    final picked = await showHotelPickerSheet(
      context,
      repo: _hotelRepo,
      countryCodes: scope.countryCodes,
      cityIds: scope.cityIds,
      destinationLabel: _scopeLabel,
    );
    if (picked != null) setState(() => _selectedHotel = picked);
  }

  Future<void> _pickRestaurant() async {
    final scope = legScope(_destinations);
    if (scope.countryCodes.isEmpty && scope.cityIds.isEmpty) return;
    final picked = await showRestaurantPickerSheet(
      context,
      repo: _restaurantRepo,
      countryCodes: scope.countryCodes,
      cityIds: scope.cityIds,
      destinationLabel: _scopeLabel,
      excludeIds: {for (final r in _selectedRestaurants) r.id},
    );
    if (picked != null) setState(() => _selectedRestaurants.add(picked));
  }

  String? _validate(String title) {
    if (title.isEmpty) return 'Give this trip a name.';
    if (_legs.any((l) => l.country == null)) {
      return _isMulti
          ? 'Choose a country for every destination.'
          : 'Choose a country.';
    }
    if (_endDate.isBefore(_startDate)) {
      return 'End date must be on or after the start date.';
    }
    if (_isMulti) {
      for (var i = 0; i < _legs.length; i++) {
        final leg = _legs[i];
        if (leg.start == null || leg.end == null) {
          return 'Say when you\'ll be in each destination.';
        }
        // Compared as calendar days, never instants.
        final start = DateUtils.dateOnly(leg.start!);
        final end = DateUtils.dateOnly(leg.end!);
        if (start.isBefore(_startDate) || end.isAfter(_endDate)) {
          final name = leg.country?.name ?? 'Destination ${i + 1}';
          return '$name (${_formatDate(start)} – ${_formatDate(end)}) is '
              'outside the trip\'s dates, ${_formatDate(_startDate)} – '
              '${_formatDate(_endDate)}. Adjust one of them.';
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final problem = _validate(title);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notes = _notesCtrl.text.trim();
      final destinations = _destinations;
      final first = destinations.first;
      // With destinations on the server the first one is the trip's
      // country/city (save_trip_destinations keeps them in step);
      // without, the free-text city field is still the trip's city.
      final city = _multiAllowed ? first.cityName : _cityCtrl.text.trim();
      if (_isEditing) {
        final tripId = widget.existingTrip!.id;
        if (_multiAllowed) {
          await widget.repo.saveTripDestinations(
            tripId: tripId,
            startDate: _startDate,
            endDate: _endDate,
            destinations: destinations,
          );
          await widget.repo.updateTripDetails(
            userId: widget.userId,
            tripId: tripId,
            title: title,
            notes: notes.isEmpty ? null : notes,
          );
        } else {
          await widget.repo.updateTrip(
            userId: widget.userId,
            tripId: tripId,
            title: title,
            startDate: _startDate,
            endDate: _endDate,
            countryCode: first.countryCode,
            city: (city == null || city.isEmpty) ? null : city,
            notes: notes.isEmpty ? null : notes,
          );
        }
      } else {
        final trip = await widget.repo.createTrip(
          userId: widget.userId,
          title: title,
          startDate: _startDate,
          endDate: _endDate,
          countryCode: first.countryCode,
          city: (city == null || city.isEmpty) ? null : city,
          notes: notes.isEmpty ? null : notes,
        );
        if (_multiAllowed) {
          await widget.repo.saveTripDestinations(
            tripId: trip.id,
            startDate: _startDate,
            endDate: _endDate,
            destinations: destinations,
          );
        }
        // Normalized references only (entity_id -> hotels_full/
        // restaurants_full), never copied venue data — same
        // planned_venues shape Trip Detail's own add-venue actions use.
        // Each defaults to its own destination's dates.
        final hotel = _selectedHotel;
        if (hotel != null) {
          final (start, end) = _datesFor(hotel.countryCode, hotel.cityId);
          await widget.repo.createPlannedVenue(
            userId: widget.userId,
            entityType: 'hotel',
            entityId: hotel.id,
            tripId: trip.id,
            startDate: start,
            endDate: end,
          );
        }
        for (final restaurant in _selectedRestaurants) {
          final (start, _) = _datesFor(
            restaurant.countryCode,
            restaurant.cityId,
          );
          await widget.repo.createPlannedVenue(
            userId: widget.userId,
            entityType: 'restaurant',
            entityId: restaurant.id,
            tripId: trip.id,
            startDate: start,
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is PostgrestException
            ? 'Could not save trip: ${error.message}'
            : 'Could not save trip. Please try again.';
      });
    }
  }

  // A borderless, underline-only field for text entry directly on the
  // sheet's dark canvas — explicitly overrides the app's global
  // InputDecorationTheme (filled: true, fillColor: AppColors.surface),
  // which would otherwise still paint an ivory box behind the hairline.
  InputDecoration _underlineDecoration(String hint, {TextStyle? hintStyle}) =>
      InputDecoration(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        hintText: hint,
        hintStyle:
            hintStyle ??
            CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.textOnDark.withValues(alpha: 0.2),
          ),
        ),
        // Ivory, never gold — gold is reserved for stars and Keys.
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.textOnDark, width: 1.25),
        ),
      );

  Widget _legEditor(int i, List<VenueCountry> countries, bool loading) {
    final leg = _legs[i];
    final country = leg.country;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isMulti) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Destination ${i + 1}',
                  style: CsTypography.placeTitle.copyWith(
                    color: AppColors.textOnDark,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeLeg(i),
                tooltip: 'Remove destination',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.secondaryOnDark,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: CsSpacing.xs),
        ],
        _BorderedRow(
          onTap: countries.isEmpty ? null : () => _pickCountry(i, countries),
          child: Text(
            country == null
                ? (loading ? 'Loading countries…' : 'Choose a country')
                : _countryLabel(country),
            style: CsTypography.bodyMedium.copyWith(
              color: country == null
                  ? AppColors.secondaryOnDark
                  : AppColors.textOnDark,
            ),
          ),
        ),
        if (_multiAllowed && country != null) ...[
          const SizedBox(height: CsSpacing.sm),
          _BorderedRow(
            onTap: () => _pickCity(i),
            child: Text(
              leg.city?.name ?? 'The whole country',
              style: CsTypography.bodyMedium.copyWith(
                color: leg.city == null
                    ? AppColors.secondaryOnDark
                    : AppColors.textOnDark,
              ),
            ),
          ),
        ],
        if (_isMulti) ...[
          const SizedBox(height: CsSpacing.sm),
          _TripDateRangeRow(
            fromLabel: 'ARRIVE',
            toLabel: 'LEAVE',
            startDate: leg.start,
            endDate: leg.end,
            onTapStart: () => _pickLegDate(i, start: true),
            onTapEnd: () => _pickLegDate(i, start: false),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    final hasDestination = _destinations.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.greenSurface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(CsRadius.large),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Explicit Close plus the drag handle — the shared
                  // SheetDismissHandle every dismissible sheet uses; pops
                  // with no result, so it never saves anything.
                  SheetDismissHandle(
                    onClose: () => Navigator.pop(context),
                    handleColor: AppColors.textOnDark.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: CsSpacing.lg),

                  Text(
                    _isEditing ? 'Edit trip' : 'Plan a trip',
                    style: CsTypography.sectionTitle.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isEditing
                        ? 'Change the name, dates or destinations.'
                        : 'A destination and dates. The rest can follow.',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xl),
                  const TripSectionLabel('NAME'),
                  const SizedBox(height: CsSpacing.xs),
                  TextField(
                    controller: _titleCtrl,
                    style: CsTypography.placeTitle.copyWith(
                      color: AppColors.textOnDark,
                    ),
                    decoration: _underlineDecoration(
                      'Trip name, e.g. Autumn in Burgundy',
                      hintStyle: CsTypography.placeTitle.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xl),

                  const TripSectionLabel('DATES'),
                  const SizedBox(height: CsSpacing.sm),
                  _TripDateRangeRow(
                    startDate: _startDate,
                    endDate: _endDate,
                    onTapStart: _pickStartDate,
                    onTapEnd: _pickEndDate,
                  ),
                  const SizedBox(height: CsSpacing.xl),

                  TripSectionLabel(_isMulti ? 'DESTINATIONS' : 'DESTINATION'),
                  if (_isMulti) ...[
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      'Say when you\'ll be in each one.',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: CsSpacing.sm),
                  FutureBuilder<List<VenueCountry>>(
                    future: _countriesFuture,
                    builder: (context, snap) {
                      final countries = snap.data ?? [];
                      final loading =
                          snap.connectionState == ConnectionState.waiting;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _legs.length; i++) ...[
                            if (i > 0) const SizedBox(height: CsSpacing.lg),
                            _legEditor(i, countries, loading),
                          ],
                        ],
                      );
                    },
                  ),
                  if (_multiAllowed) ...[
                    const SizedBox(height: CsSpacing.xs),
                    TripTextAction(
                      label: 'Add another destination',
                      onTap: _addLeg,
                      enabled: _legs.last.country != null,
                    ),
                  ] else ...[
                    const SizedBox(height: CsSpacing.md),
                    TextField(
                      controller: _cityCtrl,
                      style: CsTypography.body.copyWith(
                        color: AppColors.textOnDark,
                      ),
                      decoration: _underlineDecoration('City'),
                    ),
                  ],
                  const SizedBox(height: CsSpacing.section),

                  if (!_isEditing) ...[
                    const TripSectionLabel('STAY & DINING'),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      hasDestination
                          ? 'Add a hotel or restaurants now, or come back to '
                                'it later.'
                          : 'Choose a destination first — you\'ll pick from '
                                'its hotels and restaurants.',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.sm),
                    if (_selectedHotel == null)
                      TripTextAction(
                        label: 'Add hotel',
                        onTap: _pickHotel,
                        enabled: hasDestination,
                      )
                    else
                      _SelectedVenueRow(
                        title: _selectedHotel!.name,
                        subtitle:
                            '${_selectedHotel!.cityName}, '
                            '${_selectedHotel!.countryName}',
                        onChange: _pickHotel,
                        onRemove: () => setState(() => _selectedHotel = null),
                      ),
                    if (_selectedHotel != null)
                      const SizedBox(height: CsSpacing.md),
                    for (var i = 0; i < _selectedRestaurants.length; i++) ...[
                      _SelectedVenueRow(
                        title: _selectedRestaurants[i].name,
                        subtitle:
                            '${_selectedRestaurants[i].cityName}, '
                            '${_selectedRestaurants[i].countryName}',
                        onRemove: () =>
                            setState(() => _selectedRestaurants.removeAt(i)),
                      ),
                      const SizedBox(height: CsSpacing.sm),
                    ],
                    TripTextAction(
                      label: 'Add restaurant',
                      onTap: _pickRestaurant,
                      enabled: hasDestination,
                    ),
                    const SizedBox(height: CsSpacing.xl),
                  ],

                  const TripSectionLabel('NOTES'),
                  const SizedBox(height: CsSpacing.sm),
                  TextField(
                    controller: _notesCtrl,
                    style: CsTypography.body.copyWith(
                      color: AppColors.textOnDark,
                    ),
                    maxLines: 3,
                    minLines: 2,
                    decoration: _underlineDecoration(
                      'Anything to remember for this trip…',
                    ),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.error,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: CsTypography.metadata.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(height: CsSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: CsPrimaryButton(
                      label: _isEditing ? 'Save changes' : 'Create trip',
                      onTap: _save,
                      loading: _saving,
                      surface: CsSurface.dark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact "belong together" trip-date control — Start and End share one
/// bordered (not filled) row, separated by a small arrow, rather than two
/// large independent cards. Deliberately outlined only, no ivory fill: a
/// premium travel-planning form doesn't need every field to look like a
/// white card.
class _TripDateRangeRow extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onTapStart;
  final VoidCallback onTapEnd;
  final String fromLabel;
  final String toLabel;

  const _TripDateRangeRow({
    required this.startDate,
    required this.endDate,
    required this.onTapStart,
    required this.onTapEnd,
    this.fromLabel = 'FROM',
    this.toLabel = 'TO',
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.textOnDark.withValues(alpha: 0.2)),
      borderRadius: BorderRadius.circular(CsRadius.medium),
    ),
    child: Row(
      children: [
        Expanded(
          child: _DateHalf(
            label: fromLabel,
            date: startDate,
            onTap: onTapStart,
          ),
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 14,
          color: AppColors.secondaryOnDark.withValues(alpha: 0.7),
        ),
        Expanded(
          child: _DateHalf(label: toLabel, date: endDate, onTap: onTapEnd),
        ),
      ],
    ),
  );
}

class _DateHalf extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateHalf({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
      highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.md,
          vertical: CsSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: CsTypography.eyebrow.copyWith(
                color: AppColors.secondaryOnDark,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date == null ? 'Choose' : _formatDate(date!),
              style: CsTypography.bodyMedium.copyWith(
                color: date == null
                    ? AppColors.secondaryOnDark
                    : AppColors.textOnDark,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// A slim bordered (not filled) tappable row — used for Country, where a
/// picker sheet opens on tap. Outlined rather than an ivory-filled card,
/// same restrained treatment as [_TripDateRangeRow].
class _BorderedRow extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _BorderedRow({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
      highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.base,
          vertical: CsSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.textOnDark.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(CsRadius.medium),
        ),
        child: Row(
          children: [
            Expanded(child: child),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondaryOnDark,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A hotel or restaurant already picked for this trip — a plain row, not a
/// card: name/location plus an optional "Change" (hotel only, since a trip
/// has at most one) and a "Remove" affordance. [onChange] omitted means no
/// change action (used for restaurant rows, where "remove and add a
/// different one" is the same number of taps as a dedicated change action
/// would be).
class _SelectedVenueRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onChange;
  final VoidCallback onRemove;
  const _SelectedVenueRow({
    required this.title,
    required this.subtitle,
    this.onChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.placeTitle.copyWith(
                color: AppColors.textOnDark,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ),
      ),
      if (onChange != null)
        TextButton(
          onPressed: onChange,
          child: Text(
            'Change',
            style: CsTypography.metadata.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      IconButton(
        onPressed: onRemove,
        icon: const Icon(
          Icons.close_rounded,
          color: AppColors.secondaryOnDark,
          size: 18,
        ),
        tooltip: 'Remove',
      ),
    ],
  );
}
