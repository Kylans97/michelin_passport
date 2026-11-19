import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/booking_window_repository.dart';
import '../../models/booking_window.dart';
import '../../models/opening_hours.dart' show HoursTime;

/// When bookings open, reached from a restaurant's landing page
/// (VenueManagementScreen). Members who plan a month at the restaurant
/// get a reminder the day before that month opens, so this has to be the
/// restaurant's real practice, in its own local time. It goes live at
/// once, with no review (decided 2026-11-16), like opening hours.
class VenueBookingWindowScreen extends StatefulWidget {
  final String restaurantId;
  final String countryCode;
  final BookingWindowRepository? repository;

  const VenueBookingWindowScreen({
    super.key,
    required this.restaurantId,
    required this.countryCode,
    this.repository,
  });

  /// The landing page's one-line summary.
  static String summary(BookingWindow? window) =>
      window == null ? 'Not set' : window.summary;

  @override
  State<VenueBookingWindowScreen> createState() =>
      _VenueBookingWindowScreenState();
}

class _VenueBookingWindowScreenState extends State<VenueBookingWindowScreen> {
  late final _repo =
      widget.repository ?? BookingWindowRepository(Supabase.instance.client);
  final _amountCtrl = TextEditingController();

  BookingWindowKind _kind = BookingWindowKind.rolling;
  String _unit = 'day';
  int _releaseDay = 1;
  int _monthsAhead = 2;
  HoursTime? _time = const HoursTime(10, 0);
  BookingPlatform? _platform;
  List<BookingRelease> _releases = [];
  List<String> _timezones = [];
  String? _timezone;
  bool _hadWindow = false;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final window = await _repo.load(widget.restaurantId);
      final zones = await _repo.countryTimezones(widget.countryCode);
      if (!mounted) return;
      setState(() {
        _timezones = zones;
        _timezone =
            window?.timezone ?? (zones.length == 1 ? zones.first : null);
        _hadWindow = window != null;
        if (window != null && window.kind != BookingWindowKind.unknown) {
          _kind = window.kind;
          _unit = window.rollingUnit ?? 'day';
          _releaseDay = window.releaseDay ?? 1;
          _monthsAhead = window.monthsAhead ?? 2;
          _time = window.releaseTime;
          _platform = window.platform;
          _releases = [...window.releases];
          if (window.rollingAmount != null) {
            _amountCtrl.text = '${window.rollingAmount}';
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  BookingWindow? _build() {
    final timezone = _timezone;
    if (timezone == null) return null;
    return BookingWindow(
      kind: _kind,
      timezone: timezone,
      rollingAmount: int.tryParse(_amountCtrl.text.trim()),
      rollingUnit: _unit,
      releaseDay: _releaseDay,
      monthsAhead: _monthsAhead,
      releaseTime: _time,
      platform: _platform,
      releases: _releases,
    );
  }

  Future<void> _save({bool remove = false}) async {
    if (_saving) return;
    final window = remove ? null : _build();
    if (!remove) {
      if (window == null) {
        setState(() => _error = 'Choose your timezone.');
        return;
      }
      final problem = window.validationError();
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.save(widget.restaurantId, window);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _hadWindow = !remove;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remove
                ? 'Booking window removed. No reminders will be sent.'
                : 'Saved. Members planning a month here will be reminded.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  Future<HoursTime?> _pickTime(HoursTime? initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initial?.hour ?? 10,
        minute: initial?.minute ?? 0,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null ? null : HoursTime(picked.hour, picked.minute);
  }

  Future<void> _addRelease() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final releaseOn = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 3),
      helpText: 'Bookings open on',
    );
    if (releaseOn == null || !mounted) return;
    final covers = await showDateRangePicker(
      context: context,
      firstDate: releaseOn,
      lastDate: DateTime(releaseOn.year + 3),
      helpText: 'Dates that open',
      saveText: 'Next',
    );
    if (covers == null || !mounted) return;
    final time = await _pickTime(_time);
    if (!mounted) return;
    setState(() {
      _error = null;
      _releases = [
        ..._releases,
        BookingRelease(
          releaseOn: releaseOn,
          releaseTime: time,
          coversFrom: covers.start,
          coversTo: covers.end,
        ),
      ]..sort((a, b) => a.releaseOn.compareTo(b.releaseOn));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Booking window',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            )
          : _loadFailed
          ? Center(
              child: TextButton(
                onPressed: _load,
                child: Text(
                  'Could not load your booking window. Tap to try again.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
                vertical: CsSpacing.md,
              ),
              children: [
                Text(
                  'When do your bookings open? Members who plan a month at your '
                  'restaurant get a reminder the day before that month opens. '
                  'Changes apply as soon as you save.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: CsSpacing.lg),
                _label('HOW BOOKINGS OPEN'),
                RadioGroup<BookingWindowKind>(
                  groupValue: _kind,
                  onChanged: (v) => setState(() {
                    _kind = v!;
                    _error = null;
                  }),
                  child: Column(
                    children: [
                      for (final (kind, title, subtitle) in const [
                        (
                          BookingWindowKind.rolling,
                          'A set time ahead',
                          'Every day a new day opens, such as 60 days ahead.',
                        ),
                        (
                          BookingWindowKind.monthly,
                          'Once a month',
                          'On one day each month, a whole month opens.',
                        ),
                        (
                          BookingWindowKind.seasonal,
                          'By season',
                          'On set dates, a season or period opens.',
                        ),
                      ])
                        RadioListTile<BookingWindowKind>(
                          value: kind,
                          activeColor: AppColors.forestGreen,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            title,
                            style: CsTypography.body.copyWith(
                              color: AppColors.forestGreen,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: CsTypography.metadata,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: CsSpacing.md),
                ...switch (_kind) {
                  BookingWindowKind.rolling => _rollingFields(),
                  BookingWindowKind.monthly => _monthlyFields(),
                  BookingWindowKind.seasonal => _seasonalFields(),
                  BookingWindowKind.unknown => const <Widget>[],
                },
                if (_timezones.length > 1) ...[
                  const SizedBox(height: CsSpacing.lg),
                  _label('YOUR TIMEZONE'),
                  DropdownButton<String>(
                    value: _timezone,
                    isExpanded: true,
                    hint: const Text('Choose'),
                    items: [
                      for (final z in _timezones)
                        DropdownMenuItem(value: z, child: Text(z)),
                    ],
                    onChanged: (v) => setState(() => _timezone = v),
                  ),
                ],
                const SizedBox(height: CsSpacing.lg),
                _label('WHERE GUESTS BOOK (OPTIONAL)'),
                DropdownButton<BookingPlatform?>(
                  value: _platform,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final p in BookingPlatform.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (v) => setState(() => _platform = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: CsSpacing.md),
                  Text(
                    _error!,
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: CsSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: CsPrimaryButton(
                    label: 'Save',
                    surface: CsSurface.light,
                    loading: _saving,
                    onTap: _save,
                  ),
                ),
                if (_hadWindow) ...[
                  const SizedBox(height: CsSpacing.xs),
                  SubtleTextAction(
                    label: 'Remove booking window',
                    onTap: _saving ? () {} : () => _save(remove: true),
                  ),
                ],
                const SizedBox(height: CsSpacing.xxl),
              ],
            ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.sm),
    child: Text(
      text,
      style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
    ),
  );

  // The time a new day or month opens, or "not fixed": a time is never
  // made up, and the reminder then names only the date.
  Widget _timeRow() => Row(
    children: [
      Expanded(
        child: Text(
          'Opens at',
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
      ),
      if (_time != null)
        _chip(_time!.label, () async {
          final t = await _pickTime(_time);
          if (t != null) setState(() => _time = t);
        }),
      const SizedBox(width: CsSpacing.sm),
      Text('No fixed time', style: CsTypography.metadata),
      Checkbox(
        value: _time == null,
        activeColor: AppColors.forestGreen,
        onChanged: (v) =>
            setState(() => _time = v == true ? null : const HoursTime(10, 0)),
      ),
    ],
  );

  List<Widget> _rollingFields() => [
    Row(
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '60'),
          ),
        ),
        const SizedBox(width: CsSpacing.md),
        DropdownButton<String>(
          value: _unit,
          items: const [
            DropdownMenuItem(value: 'day', child: Text('days ahead')),
            DropdownMenuItem(value: 'month', child: Text('months ahead')),
          ],
          onChanged: (v) => setState(() => _unit = v!),
        ),
      ],
    ),
    const SizedBox(height: CsSpacing.sm),
    _timeRow(),
  ];

  List<Widget> _monthlyFields() => [
    Row(
      children: [
        Text(
          'On the',
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
        const SizedBox(width: CsSpacing.sm),
        DropdownButton<int>(
          value: _releaseDay,
          items: [
            for (var d = 1; d <= 31; d++)
              DropdownMenuItem(value: d, child: Text(ordinal(d))),
          ],
          onChanged: (v) => setState(() => _releaseDay = v!),
        ),
        const SizedBox(width: CsSpacing.sm),
        Text(
          'of each month',
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
      ],
    ),
    Row(
      children: [
        Text(
          'the month',
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
        const SizedBox(width: CsSpacing.sm),
        DropdownButton<int>(
          value: _monthsAhead,
          items: [
            for (var m = 1; m <= 24; m++)
              DropdownMenuItem(value: m, child: Text('$m')),
          ],
          onChanged: (v) => setState(() => _monthsAhead = v!),
        ),
        const SizedBox(width: CsSpacing.sm),
        Expanded(
          child: Text(
            _monthsAhead == 1 ? 'month later opens' : 'months later opens',
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ),
      ],
    ),
    if (_releaseDay > 28)
      Text('In a shorter month, its last day.', style: CsTypography.metadata),
    const SizedBox(height: CsSpacing.sm),
    _timeRow(),
  ];

  List<Widget> _seasonalFields() => [
    for (final r in _releases)
      Row(
        children: [
          Expanded(
            child: Text(
              'On ${_date(r.releaseOn)}'
              '${r.releaseTime == null ? '' : ' at ${r.releaseTime!.label}'}: '
              '${_date(r.coversFrom)} – ${_date(r.coversTo)}',
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            ),
          ),
          IconButton(
            tooltip: 'Remove this release',
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.taupe,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _releases = [..._releases]..remove(r)),
          ),
        ],
      ),
    SubtleTextAction(label: 'Add a release', onTap: _addRelease),
  ];

  Widget _chip(String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.subtleBorderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: CsTypography.body.copyWith(color: AppColors.forestGreen),
      ),
    ),
  );

  static String _date(DateTime d) =>
      '${d.day} ${monthNames[d.month - 1].substring(0, 3)} ${d.year}';
}
