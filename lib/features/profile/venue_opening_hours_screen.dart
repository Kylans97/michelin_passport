import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/opening_hours_repository.dart';
import '../../models/opening_hours.dart';

/// Opening hours, reached from a restaurant's landing page
/// (VenueManagementScreen): per day closed, or one or two times, such as
/// lunch and dinner. Saving puts them on the page at once, with no review
/// (decided 2026-11-02) — unlike the about text, team and photos.
class VenueOpeningHoursScreen extends StatefulWidget {
  final String restaurantId;
  final OpeningHoursRepository? repository;

  const VenueOpeningHoursScreen({
    super.key,
    required this.restaurantId,
    this.repository,
  });

  /// The landing page's one-line summary.
  static String summary(OpeningHours hours) {
    if (hours.isEmpty) return 'Not on your page yet';
    final open = [
      for (var d = 1; d <= 7; d++)
        if (hours.on(d).isNotEmpty) d,
    ];
    return open.length == 7
        ? 'Open every day'
        : 'Open ${open.length} days a week';
  }

  @override
  State<VenueOpeningHoursScreen> createState() =>
      _VenueOpeningHoursScreenState();
}

class _VenueOpeningHoursScreenState extends State<VenueOpeningHoursScreen> {
  late final _repo =
      widget.repository ?? OpeningHoursRepository(Supabase.instance.client);

  // Weekday -> ranges being edited. A day absent here is closed.
  Map<int, List<HoursRange>> _days = {};
  bool _hadHours = false;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  String? _error;

  static const _defaultRange = HoursRange(HoursTime(12, 0), HoursTime(22, 0));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final hours = await _repo.load(widget.restaurantId);
      if (!mounted) return;
      setState(() {
        _days = {
          for (final e in hours.days.entries) e.key: [...e.value],
        };
        _hadHours = !hours.isEmpty;
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

  // Opening a day starts from the nearest earlier open day, so filling in
  // a week is mostly switching days on.
  void _setOpen(int day, bool open) {
    setState(() {
      _error = null;
      if (!open) {
        _days.remove(day);
        return;
      }
      for (var d = day - 1; d >= 1; d--) {
        if (_days[d]?.isNotEmpty ?? false) {
          _days[day] = [..._days[d]!];
          return;
        }
      }
      _days[day] = [_defaultRange];
    });
  }

  Future<HoursTime?> _pickTime(HoursTime initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null ? null : HoursTime(picked.hour, picked.minute);
  }

  Future<void> _editTime(int day, int index, {required bool opens}) async {
    final range = _days[day]![index];
    final picked = await _pickTime(opens ? range.opens : range.closes);
    if (picked == null || !mounted) return;
    setState(() {
      _error = null;
      _days[day]![index] = opens
          ? HoursRange(picked, range.closes)
          : HoursRange(range.opens, picked);
    });
  }

  void _addSecond(int day) => setState(() {
    _error = null;
    _days[day]!.add(suggestSecondRange(_days[day]!.first));
  });

  void _removeSecond(int day) => setState(() {
    _error = null;
    _days[day]!.removeLast();
  });

  Future<void> _save({bool clear = false}) async {
    if (_saving) return;
    final hours = clear
        ? OpeningHours.empty
        : OpeningHours({
            for (final e in _days.entries)
              if (e.value.isNotEmpty)
                e.key: [...e.value]..sort((a, b) => a.opens.compareTo(b.opens)),
          });
    final problem = hours.validationError();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.save(widget.restaurantId, hours);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _hadHours = !hours.isEmpty;
        if (clear) _days = {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clear
                ? 'Opening hours removed from your page.'
                : 'Saved. Your page shows them now.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Opening hours',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
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
                  'Could not load your opening hours. Tap to try again.',
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
                  'Set the times you are open, up to two a day, such as lunch and dinner. '
                  'Changes show on your page as soon as you save.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: CsSpacing.lg),
                for (var day = 1; day <= 7; day++) _dayRow(day),
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
                if (_hadHours) ...[
                  const SizedBox(height: CsSpacing.xs),
                  SubtleTextAction(
                    label: 'Remove opening hours from page',
                    onTap: _saving ? () {} : () => _save(clear: true),
                  ),
                ],
                const SizedBox(height: CsSpacing.xxl),
              ],
            ),
    );
  }

  Widget _dayRow(int day) {
    final ranges = _days[day] ?? const [];
    final open = ranges.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  weekdayName(day),
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              Text(
                open ? 'Open' : 'Closed',
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
              Switch(
                value: open,
                activeThumbColor: AppColors.warmWhite,
                activeTrackColor: AppColors.forestGreen,
                onChanged: (v) => _setOpen(day, v),
              ),
            ],
          ),
          for (var i = 0; i < ranges.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: CsSpacing.xs),
              child: Row(
                children: [
                  _TimeChip(
                    label: ranges[i].opens.label,
                    semanticLabel: '${weekdayName(day)} opens',
                    onTap: () => _editTime(day, i, opens: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CsSpacing.sm,
                    ),
                    child: Text(
                      '–',
                      style: CsTypography.body.copyWith(color: AppColors.taupe),
                    ),
                  ),
                  _TimeChip(
                    label: ranges[i].closes.label,
                    semanticLabel: '${weekdayName(day)} closes',
                    onTap: () => _editTime(day, i, opens: false),
                  ),
                  const Spacer(),
                  if (i == 1)
                    IconButton(
                      tooltip: 'Remove second time',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.taupe,
                        size: 20,
                      ),
                      onPressed: () => _removeSecond(day),
                    ),
                ],
              ),
            ),
          if (ranges.length == 1)
            SubtleTextAction(
              label: 'Add a second time',
              onTap: () => _addSecond(day),
            ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$semanticLabel $label',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.subtleBorderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ExcludeSemantics(
          child: Text(
            label,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ),
      ),
    ),
  );
}
