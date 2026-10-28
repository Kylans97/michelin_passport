import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/event_time.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/venue_events_repository.dart';
import '../../models/event.dart';
import '../../models/event_local_time.dart';
import '../../models/event_tag.dart';
import '../../models/managed_venue.dart';
import '../../models/venue_event.dart';
import 'pick_event_location_screen.dart';

/// Create or edit one of the venue's own events (venue events phase 3).
///
/// The rules are the server's (validate_venue_event, 20261018130000),
/// checked here first so the venue hears about a mistake before saving:
/// - the dates run from today to one year ahead, "today" being today
///   where the event happens (its own timezone);
/// - a start time is optional, an end time only once there is one, and
///   an unknown time is never filled in (CLAUDE.md, Events);
/// - held at the venue: the server copies the venue's own verified
///   location; held elsewhere: a place, a city, a country and a map pin.
///
/// The timezone comes from the event's country (countries.timezones): one
/// zone is used as it is; with several, the venue chooses.
///
/// What the form did, popped back to the Events screen.
enum VenueEventFormResult { saved, cancelled }

/// Pops a [VenueEventFormResult]. A new event waits for review; an edit
/// to a live event goes live straight away. An existing event can also be
/// cancelled from here (no review needed), after a confirmation.
class VenueEventFormScreen extends StatefulWidget {
  final ManagedVenue venue;

  /// The event being edited, or null to create one.
  final VenueEvent? existing;
  final VenueEventsRepository? repository;

  /// Test seam: "today", in the event's own timezone. Defaults to the
  /// real date there.
  final DateTime Function(String timezone)? todayIn;

  const VenueEventFormScreen({
    super.key,
    required this.venue,
    this.existing,
    this.repository,
    this.todayIn,
  });

  @override
  State<VenueEventFormScreen> createState() => _VenueEventFormScreenState();
}

class _VenueEventFormScreenState extends State<VenueEventFormScreen> {
  late final _repo =
      widget.repository ?? VenueEventsRepository(Supabase.instance.client);
  late final Future<(List<EventCountry>, List<EventTag>)> _lookups;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _placeName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _ticketUrl = TextEditingController();
  final _admissionNote = TextEditingController();

  EventType? _type;
  final Set<String> _tags = {};
  DateTime? _startDate;
  DateTime? _endDate; // null: a single day
  EventLocalTime? _startTime;
  EventLocalTime? _endTime;
  late bool _atVenue;
  String? _countryCode;
  String? _timezone;
  LatLng? _pin;
  EventAdmissionType _admission = EventAdmissionType.unknown;

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;
  bool get _venueHasLocation => widget.venue is! ManagedPrivateChef;

  String? get _venueCountryCode => switch (widget.venue) {
    ManagedRestaurant(:final restaurant) => restaurant.countryCode,
    ManagedHotel(:final hotel) => hotel.countryCode,
    ManagedPrivateChef(:final chef) => chef.homeCountryCode,
  };

  String? get _venueAddress => switch (widget.venue) {
    ManagedRestaurant(:final restaurant) => restaurant.address,
    ManagedHotel(:final hotel) => hotel.address,
    ManagedPrivateChef() => null,
  };

  @override
  void initState() {
    super.initState();
    _lookups = () async {
      final results = await Future.wait([_repo.loadCountries(), _repo.loadTags()]);
      return (results[0] as List<EventCountry>, results[1] as List<EventTag>);
    }();
    final existing = widget.existing;
    if (existing == null) {
      _atVenue = _venueHasLocation;
      _countryCode = _venueCountryCode?.trim();
      return;
    }
    final e = existing.event;
    _name.text = e.name;
    _description.text = e.description ?? '';
    _type = venueEventTypes.contains(e.eventType) ? e.eventType : null;
    _tags.addAll(existing.tagSlugs);
    _startDate = e.startDate;
    _endDate = e.endDate == e.startDate ? null : e.endDate;
    _startTime = e.startTime;
    _endTime = e.endTime;
    _timezone = e.timezone;
    _countryCode = e.countryCode.trim();
    // Held at the venue when it carries the venue's own name and address
    // (the server copied them); anything else was set by hand.
    _atVenue = _venueHasLocation &&
        e.venueName == widget.venue.name &&
        e.address == _venueAddress;
    if (!_atVenue) {
      _placeName.text = e.venueName ?? '';
      _address.text = e.address ?? '';
      _city.text = e.city ?? '';
      if (e.latitude != null && e.longitude != null) {
        _pin = LatLng(e.latitude!, e.longitude!);
      }
    }
    _ticketUrl.text = e.ticketUrl ?? '';
    _admission = e.admissionType;
    _admissionNote.text = e.admissionNote ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _placeName, _address, _city, _ticketUrl, _admissionNote]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime _today(String timezone) {
    if (widget.todayIn != null) return widget.todayIn!(timezone);
    final local = eventLocalDateTime(DateTime.now(), timezone);
    return DateTime.utc(local.year, local.month, local.day);
  }

  // The timezone the rules are measured in: the chosen one, else the
  // country's only one, else the device's own date as a first guess.
  DateTime _todayForPicker(List<EventCountry> countries) {
    final tz = _resolvedTimezone(countries);
    if (tz != null) return _today(tz);
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  EventCountry? _country(List<EventCountry> countries) {
    for (final c in countries) {
      if (c.code == _countryCode) return c;
    }
    return null;
  }

  String? _resolvedTimezone(List<EventCountry> countries) {
    final country = _country(countries);
    if (country == null) return null;
    if (_timezone != null && country.timezones.contains(_timezone)) return _timezone;
    return country.onlyTimezone;
  }

  static DateTime _oneYearAhead(DateTime today) =>
      DateTime.utc(today.year + 1, today.month, today.day);

  Future<void> _pickStartDate(List<EventCountry> countries) async {
    final today = _todayForPicker(countries);
    final first = _isEditing && _startDate != null && _startDate!.isBefore(today)
        ? _startDate!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate != null && !_startDate!.isBefore(first) ? _startDate! : first,
      firstDate: first,
      lastDate: _oneYearAhead(today),
    );
    if (picked == null) return;
    setState(() {
      _startDate = DateTime.utc(picked.year, picked.month, picked.day);
      if (_endDate != null && !_endDate!.isAfter(_startDate!)) _endDate = null;
    });
  }

  Future<void> _pickEndDate(List<EventCountry> countries) async {
    if (_startDate == null) return;
    final today = _todayForPicker(countries);
    final first = _startDate!.add(const Duration(days: 1));
    final last = _oneYearAhead(today);
    if (first.isAfter(last)) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? first,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _endDate = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay(hour: start ? 19 : 23, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final time = EventLocalTime(hour: picked.hour, minute: picked.minute);
    setState(() => start ? _startTime = time : _endTime = time);
  }

  Future<void> _pickPin() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => PickEventLocationScreen(initial: _pin)),
    );
    if (picked != null) setState(() => _pin = picked);
  }

  /// The form's own check, before the server's. Null when it can be saved.
  String? _validate(List<EventCountry> countries) {
    if (_name.text.trim().isEmpty) return 'Give the event a name.';
    if (_description.text.trim().isEmpty) return 'Describe the event.';
    if (_type == null) return 'Choose a type.';
    if (_startDate == null) return 'Choose a date.';
    if (!_atVenue) {
      if (_placeName.text.trim().isEmpty) return "Give the place's name.";
      if (_city.text.trim().isEmpty) return 'Give the city.';
      if (_country(countries) == null) return 'Choose the country.';
      if (_pin == null) return 'Set the location on the map.';
    } else if (_country(countries) == null) {
      return 'This venue has no country. Set the location by hand.';
    }
    final tz = _resolvedTimezone(countries);
    if (tz == null) return 'Choose the timezone.';
    final today = _today(tz);
    final end = _endDate ?? _startDate!;
    final keepsPastStart = _isEditing && _startDate == widget.existing!.event.startDate;
    if (_startDate!.isBefore(today) && !keepsPastStart) {
      return "The event can't start in the past.";
    }
    if (end.isBefore(today)) return "The event can't end in the past.";
    if (end.isAfter(_oneYearAhead(today))) {
      return 'Events can be added at most one year ahead.';
    }
    if (_endTime != null && _startTime == null) return 'Add a start time first.';
    if (_endDate == null &&
        _startTime != null &&
        _endTime != null &&
        _endTime != const EventLocalTime(hour: 0, minute: 0) &&
        _endTime!.compareTo(_startTime!) <= 0) {
      return 'The end time must be after the start time. For an event '
          'that runs past midnight, add an end date.';
    }
    final url = _ticketUrl.text.trim();
    if (url.isNotEmpty && (!url.startsWith('https://') || url.contains(' '))) {
      return 'The ticket link must be a full https:// address.';
    }
    return null;
  }

  Future<void> _save(List<EventCountry> countries) async {
    if (_saving) return;
    final problem = _validate(countries);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final draft = VenueEventDraft(
      name: _name.text,
      description: _description.text,
      eventType: _type!,
      tagSlugs: _tags.toList()..sort(),
      startDate: _startDate!,
      endDate: _endDate,
      startTime: _startTime,
      endTime: _startTime == null ? null : _endTime,
      timezone: _resolvedTimezone(countries)!,
      atVenue: _atVenue,
      venueName: _placeName.text,
      address: _address.text,
      city: _city.text,
      countryCode: _countryCode,
      latitude: _pin?.latitude,
      longitude: _pin?.longitude,
      ticketUrl: _ticketUrl.text,
      admissionType: _admission,
      admissionNote: _admissionNote.text,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await _repo.update(widget.existing!.event.id, draft);
      } else {
        await _repo.submit(widget.venue, draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop(VenueEventFormResult.saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = venueEventErrorMessage(e);
      });
    }
  }

  Future<void> _cancelEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text(
          'It stays listed as cancelled, so anyone planning to go can see it. '
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Cancel event', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.cancel(widget.existing!.event.id);
      if (!mounted) return;
      Navigator.of(context).pop(VenueEventFormResult.cancelled);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = venueEventErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit event' : 'New event',
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: FutureBuilder<(List<EventCountry>, List<EventTag>)>(
        future: _lookups,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.forestGreen, strokeWidth: 1.5),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(CsSpacing.xl),
                child: Text(
                  'Could not load the form. Please try again.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
              ),
            );
          }
          final (countries, tags) = snap.data!;
          return _form(countries, tags);
        },
      ),
    );
  }

  Widget _form(List<EventCountry> countries, List<EventTag> tags) {
    final country = _country(countries);
    final status = widget.existing?.status;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      children: [
        if (status == VenueEventStatus.live)
          _note('This event is live: changes go live straight away.')
        else if (status == VenueEventStatus.notApproved) ...[
          _note('Not approved. Saving your changes sends it back for review.'),
          if ((widget.existing!.reviewNote ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: CsSpacing.md),
              child: Text(
                '"${widget.existing!.reviewNote!.trim()}"',
                style: CsTypography.body.copyWith(
                  color: AppColors.taupe,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ] else if (!_isEditing)
          _note("New events are reviewed by hand before they're shown."),

        _label('NAME'),
        _field(_name, hint: 'Four Hands Dinner with …', maxLength: 200),
        _label('DESCRIPTION'),
        _field(_description, hint: 'What makes this evening special?', maxLines: 6, maxLength: 5000),

        _label('TYPE'),
        Wrap(
          spacing: CsSpacing.sm,
          runSpacing: CsSpacing.sm,
          children: [
            for (final t in venueEventTypes)
              CsFilterChip(
                label: t.label,
                selected: _type == t,
                surface: CsSurface.light,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: CsSpacing.lg),
        _label('TAGS (OPTIONAL)'),
        Wrap(
          spacing: CsSpacing.sm,
          runSpacing: CsSpacing.sm,
          children: [
            for (final tag in tags)
              CsFilterChip(
                label: tag.name,
                selected: _tags.contains(tag.slug),
                surface: CsSurface.light,
                onTap: () => setState(
                  () => _tags.contains(tag.slug) ? _tags.remove(tag.slug) : _tags.add(tag.slug),
                ),
              ),
          ],
        ),
        const SizedBox(height: CsSpacing.lg),

        _label('WHEN'),
        _pickerRow(
          'Date',
          _startDate == null ? 'Choose' : _formatDate(_startDate!),
          () => _pickStartDate(countries),
        ),
        _pickerRow(
          'End date',
          _endDate == null ? 'Same day' : _formatDate(_endDate!),
          _startDate == null ? null : () => _pickEndDate(countries),
          onClear: _endDate == null ? null : () => setState(() => _endDate = null),
        ),
        _pickerRow(
          'Start time',
          _startTime?.format() ?? 'Not given',
          () => _pickTime(start: true),
          onClear: _startTime == null
              ? null
              : () => setState(() {
                  _startTime = null;
                  _endTime = null;
                }),
        ),
        _pickerRow(
          'End time',
          _endTime?.format() ?? 'Not given',
          _startTime == null ? null : () => _pickTime(start: false),
          onClear: _endTime == null ? null : () => setState(() => _endTime = null),
        ),
        Padding(
          padding: const EdgeInsets.only(top: CsSpacing.xs, bottom: CsSpacing.lg),
          child: Text(
            "Leave a time out if it isn't set yet; it's shown as not given, never guessed.",
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ),

        _label('WHERE'),
        if (_venueHasLocation)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _atVenue,
            activeTrackColor: AppColors.forestGreen,
            title: Text(
              'At ${widget.venue.name}',
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            ),
            subtitle: _atVenue && _venueAddress != null
                ? Text(_venueAddress!, style: CsTypography.metadata.copyWith(color: AppColors.taupe))
                : null,
            onChanged: (v) => setState(() {
              _atVenue = v;
              if (v) _countryCode = _venueCountryCode?.trim();
            }),
          ),
        if (!_atVenue) ...[
          _field(_placeName, hint: "The place's name", maxLength: 200),
          _field(_address, hint: 'Address (optional)', maxLength: 300),
          _field(_city, hint: 'City', maxLength: 100),
          DropdownButtonFormField<String>(
            initialValue: country?.code,
            isExpanded: true,
            decoration: _decoration('Country'),
            items: [
              for (final c in countries)
                DropdownMenuItem(value: c.code, child: Text('${c.flag} ${c.name}')),
            ],
            onChanged: (code) => setState(() {
              _countryCode = code;
              _timezone = null;
            }),
          ),
          const SizedBox(height: CsSpacing.sm),
          _pickerRow(
            'Map pin',
            _pin == null ? 'Set on the map' : 'Set',
            _pickPin,
          ),
        ],
        if (country != null && country.timezones.length > 1) ...[
          const SizedBox(height: CsSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: country.timezones.contains(_timezone) ? _timezone : null,
            isExpanded: true,
            decoration: _decoration('Timezone (${country.name} has several)'),
            items: [
              for (final z in country.timezones)
                DropdownMenuItem(value: z, child: Text(z.replaceAll('_', ' '))),
            ],
            onChanged: (z) => setState(() => _timezone = z),
          ),
        ] else if (country != null)
          Padding(
            padding: const EdgeInsets.only(top: CsSpacing.xs),
            child: Text(
              'Times are in ${country.onlyTimezone!.replaceAll('_', ' ')}.',
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
          ),
        const SizedBox(height: CsSpacing.lg),

        _label('TICKETS (OPTIONAL)'),
        _field(_ticketUrl, hint: 'https://…', keyboard: TextInputType.url, maxLength: 2000),
        DropdownButtonFormField<EventAdmissionType>(
          initialValue: _admission,
          isExpanded: true,
          decoration: _decoration('Admission'),
          items: [
            for (final a in EventAdmissionType.values)
              DropdownMenuItem(value: a, child: Text(a.label)),
          ],
          onChanged: (a) => setState(() => _admission = a ?? EventAdmissionType.unknown),
        ),
        const SizedBox(height: CsSpacing.sm),
        _field(_admissionNote, hint: 'Admission note (optional)', maxLength: 500),

        if (_error != null) ...[
          const SizedBox(height: CsSpacing.sm),
          Text(_error!, style: CsTypography.metadata.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: CsSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: CsPrimaryButton(
            label: _isEditing
                ? (status == VenueEventStatus.notApproved ? 'Save and resubmit' : 'Save changes')
                : 'Submit for review',
            surface: CsSurface.light,
            loading: _saving,
            onTap: () => _save(countries),
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: CsSpacing.sm),
          Center(
            child: TextButton(
              onPressed: _saving ? null : _cancelEvent,
              child: Text(
                'Cancel this event',
                style: CsTypography.metadata.copyWith(color: AppColors.error),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.md),
    child: Text(text, style: CsTypography.body.copyWith(color: AppColors.forestGreen, height: 1.5)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.sm),
    child: Text(text, style: CsTypography.eyebrow.copyWith(color: AppColors.taupe)),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    labelText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.subtleBorderLight),
    ),
  );

  Widget _field(
    TextEditingController controller, {
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.sm),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      maxLength: maxLength,
      keyboardType: keyboard,
      style: CsTypography.body.copyWith(color: AppColors.forestGreen),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.subtleBorderLight),
        ),
      ),
    ),
  );

  Widget _pickerRow(String label, String value, VoidCallback? onTap, {VoidCallback? onClear}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: CsTypography.body.copyWith(
                    color: onTap == null ? AppColors.taupe : AppColors.forestGreen,
                  ),
                ),
              ),
              Text(value, style: CsTypography.body.copyWith(color: AppColors.taupe)),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.taupe,
                  tooltip: 'Clear $label',
                  visualDensity: VisualDensity.compact,
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
      );
}
