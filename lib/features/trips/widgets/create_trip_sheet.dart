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
import '../../../models/venue_country.dart';
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

class _CreateTripSheetState extends State<_CreateTripSheet> {
  late final _titleCtrl = TextEditingController(
    text: widget.existingTrip?.title ?? '',
  );
  late final _cityCtrl = TextEditingController(
    text: widget.existingTrip?.city ?? '',
  );
  late final _notesCtrl = TextEditingController(
    text: widget.existingTrip?.notes ?? '',
  );

  late DateTime _startDate =
      widget.existingTrip?.startDate ??
      DateTime.now().add(const Duration(days: 30));
  late DateTime _endDate =
      widget.existingTrip?.endDate ??
      DateTime.now().add(const Duration(days: 33));
  VenueCountry? _country;

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
        // Pre-select the existing trip's country once the list resolves —
        // done here (not in initState) since it depends on this future.
        final existingCode = widget.existingTrip?.countryCode;
        if (existingCode != null && mounted) {
          final match = countries.where((c) => c.code == existingCode);
          if (match.isNotEmpty) setState(() => _country = match.first);
        }
        return countries;
      });

  bool get _isEditing => widget.existingTrip != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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

  // Changing the destination drops any hotel/restaurant already picked
  // outside it — the pickers only ever offer venues in the trip's own
  // country (keyed on country_code, never a name), so a selection from
  // the previous country would otherwise be the one way to bypass that.
  Future<void> _pickCountry(List<VenueCountry> countries) async {
    final picked = await showCountryPickerSheet(context, countries: countries);
    if (picked == null) return;
    setState(() {
      _country = picked;
      if (_selectedHotel?.countryCode != picked.code) _selectedHotel = null;
      _selectedRestaurants.removeWhere((r) => r.countryCode != picked.code);
    });
  }

  String _destinationLabel(VenueCountry country) =>
      country.flag.isEmpty ? country.name : '${country.flag} ${country.name}';

  Future<void> _pickHotel() async {
    final country = _country;
    if (country == null) return;
    final picked = await showHotelPickerSheet(
      context,
      repo: _hotelRepo,
      countryCode: country.code,
      destinationLabel: _destinationLabel(country),
    );
    if (picked != null) setState(() => _selectedHotel = picked);
  }

  Future<void> _pickRestaurant() async {
    final country = _country;
    if (country == null) return;
    final picked = await showRestaurantPickerSheet(
      context,
      repo: _restaurantRepo,
      countryCode: country.code,
      destinationLabel: _destinationLabel(country),
      excludeIds: {for (final r in _selectedRestaurants) r.id},
    );
    if (picked != null) setState(() => _selectedRestaurants.add(picked));
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this trip a name.');
      return;
    }
    if (_country == null) {
      setState(() => _error = 'Choose a country.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(() => _error = 'End date must be on or after the start date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final city = _cityCtrl.text.trim();
      final notes = _notesCtrl.text.trim();
      if (_isEditing) {
        await widget.repo.updateTrip(
          userId: widget.userId,
          tripId: widget.existingTrip!.id,
          title: title,
          startDate: _startDate,
          endDate: _endDate,
          countryCode: _country!.code,
          city: city.isEmpty ? null : city,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        final trip = await widget.repo.createTrip(
          userId: widget.userId,
          title: title,
          startDate: _startDate,
          endDate: _endDate,
          countryCode: _country!.code,
          city: city.isEmpty ? null : city,
          notes: notes.isEmpty ? null : notes,
        );
        // Normalized references only (entity_id -> hotels_full/
        // restaurants_full), never copied venue data — same
        // planned_venues shape Trip Detail's own add-venue actions use.
        final hotel = _selectedHotel;
        if (hotel != null) {
          await widget.repo.createPlannedVenue(
            userId: widget.userId,
            entityType: 'hotel',
            entityId: hotel.id,
            tripId: trip.id,
            startDate: _startDate,
            endDate: _endDate,
          );
        }
        for (final restaurant in _selectedRestaurants) {
          await widget.repo.createPlannedVenue(
            userId: widget.userId,
            entityType: 'restaurant',
            entityId: restaurant.id,
            tripId: trip.id,
            startDate: _startDate,
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save trip: $error';
      });
    }
  }

  // A borderless, underline-only field for text entry directly on the
  // sheet's dark canvas — explicitly overrides the app's global
  // InputDecorationTheme (filled: true, fillColor: AppColors.surface),
  // which would otherwise still paint an ivory box behind the hairline.
  // Used for Trip name/City/Notes: fields that don't need to read as
  // "cards" the way a tappable picker row does.
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

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
                        ? 'Change the name, dates or destination.'
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
                      'Trip name, e.g. Maastricht',
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

                  const TripSectionLabel('DESTINATION'),
                  const SizedBox(height: CsSpacing.sm),
                  FutureBuilder<List<VenueCountry>>(
                    future: _countriesFuture,
                    builder: (context, snap) {
                      final countries = snap.data ?? [];
                      return _BorderedRow(
                        onTap: countries.isEmpty
                            ? null
                            : () => _pickCountry(countries),
                        child: Text(
                          _country == null
                              ? (snap.connectionState == ConnectionState.waiting
                                    ? 'Loading countries…'
                                    : 'Choose a country')
                              : '${_country!.flag}  ${_country!.name}',
                          style: CsTypography.bodyMedium.copyWith(
                            color: _country == null
                                ? AppColors.secondaryOnDark
                                : AppColors.textOnDark,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: CsSpacing.md),
                  TextField(
                    controller: _cityCtrl,
                    style: CsTypography.body.copyWith(
                      color: AppColors.textOnDark,
                    ),
                    decoration: _underlineDecoration('City'),
                  ),
                  const SizedBox(height: CsSpacing.section),

                  if (!_isEditing) ...[
                    const TripSectionLabel('STAY & DINING'),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      _country == null
                          ? 'Choose a destination first — you\'ll pick from '
                                'its hotels and restaurants.'
                          : 'Add a hotel or restaurants now, or come back to '
                                'it later.',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.sm),
                    if (_selectedHotel == null)
                      TripTextAction(
                        label: 'Add hotel',
                        onTap: _pickHotel,
                        enabled: _country != null,
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
                      enabled: _country != null,
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
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onTapStart;
  final VoidCallback onTapEnd;

  const _TripDateRangeRow({
    required this.startDate,
    required this.endDate,
    required this.onTapStart,
    required this.onTapEnd,
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
          child: _DateHalf(label: 'FROM', date: startDate, onTap: onTapStart),
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 14,
          color: AppColors.secondaryOnDark.withValues(alpha: 0.7),
        ),
        Expanded(
          child: _DateHalf(label: 'TO', date: endDate, onTap: onTapEnd),
        ),
      ],
    ),
  );
}

class _DateHalf extends StatelessWidget {
  final String label;
  final DateTime date;
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
              _formatDate(date),
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.textOnDark,
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
