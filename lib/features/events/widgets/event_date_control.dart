import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/event_discovery_filters.dart';

const _monthNamesShort = [
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

/// Events V2 Discovery Taxonomy Phase C Correction Pass §7/§8 — the
/// closed Date control's own label: "Date" when no restriction is
/// active, the preset name ("Today"/"This weekend"/"This month") when a
/// preset drove the current [range], or a compact "D–D Mon"/"D Mon – D
/// Mon" form for a custom range — never a verbose sentence, matching
/// this app's existing short date-format conventions
/// (`event_date_format.dart`'s own "D–D Mon YYYY" style, minus the year
/// here since a Discovery-context date is always near-term).
String eventDateControlLabel(
  EventDiscoveryDatePreset preset,
  EventDiscoveryDateRange range,
) {
  switch (preset) {
    case EventDiscoveryDatePreset.none:
      return 'Date';
    case EventDiscoveryDatePreset.today:
      return 'Today';
    case EventDiscoveryDatePreset.thisWeekend:
      return 'This weekend';
    case EventDiscoveryDatePreset.thisMonth:
      return 'This month';
    case EventDiscoveryDatePreset.custom:
      return _formatRangeShort(range);
  }
}

String _formatRangeShort(EventDiscoveryDateRange range) {
  final from = range.from;
  final to = range.to;
  if (from == null && to == null) return 'Date';
  if (from != null && to != null) {
    if (from.year == to.year && from.month == to.month) {
      return '${from.day}–${to.day} ${_monthNamesShort[from.month - 1]}';
    }
    if (from.year == to.year) {
      return '${from.day} ${_monthNamesShort[from.month - 1]} – '
          '${to.day} ${_monthNamesShort[to.month - 1]}';
    }
    return '${from.day} ${_monthNamesShort[from.month - 1]} ${from.year} – '
        '${to.day} ${_monthNamesShort[to.month - 1]} ${to.year}';
  }
  final only = from ?? to!;
  return '${from != null ? 'From' : 'Until'} ${only.day} '
      '${_monthNamesShort[only.month - 1]}';
}

/// What [showEventDateSheet] resolves to on a genuine selection —
/// `null` means the sheet was dismissed without picking anything (the
/// caller's committed Date state must stay unchanged, exactly the same
/// "no-op dismiss" contract the advanced Filters sheet already uses).
class EventDateSelection {
  final EventDiscoveryDatePreset preset;
  final EventDiscoveryDateRange range;
  const EventDateSelection({required this.preset, required this.range});
}

/// The Date control itself — a compact trigger (Phase C Correction Pass
/// §7's own "one clean popover/sheet/picker interaction," never a
/// permanently-visible row of date chips) that opens [showEventDateSheet]
/// on tap. Unlike the advanced Filters sheet, a Date selection commits
/// IMMEDIATELY (Correction Pass §20) — there is no separate Apply step,
/// since Date is now primary discovery context, not a refinement a user
/// should have to open-a-sheet-then-confirm just to change.
class EventDateControl extends StatelessWidget {
  final EventDiscoveryDatePreset preset;
  final EventDiscoveryDateRange range;
  final ValueChanged<EventDateSelection> onChanged;

  const EventDateControl({
    super.key,
    required this.preset,
    required this.range,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final selection = await showEventDateSheet(
      context,
      preset: preset,
      range: range,
    );
    if (selection != null) onChanged(selection);
  }

  @override
  Widget build(BuildContext context) {
    final active = preset != EventDiscoveryDatePreset.none;
    final label = eventDateControlLabel(preset, range);
    return Semantics(
      button: true,
      label: active ? 'Date, $label selected' : 'Date, no restriction',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.brandGreen.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? AppColors.brandGreen.withValues(alpha: 0.4)
                    : AppColors.cardBorder,
                width: active ? 1.0 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: active
                      ? AppColors.brandGreen
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: active
                          ? AppColors.brandGreen
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the Date sheet. Every option except "Custom dates…" pops
/// immediately with its resolved selection (Correction Pass §20's
/// "commits immediately" contract) — there is no Apply button here.
/// "Any date" is the sheet's own built-in independent-clear affordance
/// (Correction Pass §21): resolves to [EventDiscoveryDatePreset.none] /
/// [EventDiscoveryDateRange.none], exactly "no restriction."
Future<EventDateSelection?> showEventDateSheet(
  BuildContext context, {
  required EventDiscoveryDatePreset preset,
  required EventDiscoveryDateRange range,
}) {
  return showModalBottomSheet<EventDateSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventDateSheet(preset: preset, range: range),
  );
}

class _EventDateSheet extends StatelessWidget {
  final EventDiscoveryDatePreset preset;
  final EventDiscoveryDateRange range;
  const _EventDateSheet({required this.preset, required this.range});

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !context.mounted) return;
    final normalized = EventDiscoveryDateRange.normalized(
      from: DateTime.utc(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      ),
      to: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
    );
    Navigator.pop(
      context,
      EventDateSelection(
        preset: EventDiscoveryDatePreset.custom,
        range: normalized,
      ),
    );
  }

  void _pick(BuildContext context, EventDiscoveryDatePreset picked) {
    Navigator.pop(
      context,
      EventDateSelection(
        preset: picked,
        range: resolveEventDiscoveryDateRange(picked),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        // A ListTile's own InkWell paints its splash on the nearest
        // Material ancestor — this Material must sit INSIDE the
        // decorated Container (not outside it), otherwise the
        // Container's own opaque BoxDecoration would sit between the
        // Material and the ListTiles, which Flutter flags as "ink
        // splashes may be invisible" (caught by this widget's own tap-
        // through test). Transparent + explicit type so it contributes
        // no visual change of its own, only a valid paint surface.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  children: [
                    _Tile(
                      label: 'Any date',
                      selected: preset == EventDiscoveryDatePreset.none,
                      onTap: () =>
                          _pick(context, EventDiscoveryDatePreset.none),
                    ),
                    _Tile(
                      label: 'Today',
                      selected: preset == EventDiscoveryDatePreset.today,
                      onTap: () =>
                          _pick(context, EventDiscoveryDatePreset.today),
                    ),
                    _Tile(
                      label: 'This weekend',
                      selected: preset == EventDiscoveryDatePreset.thisWeekend,
                      onTap: () =>
                          _pick(context, EventDiscoveryDatePreset.thisWeekend),
                    ),
                    _Tile(
                      label: 'This month',
                      selected: preset == EventDiscoveryDatePreset.thisMonth,
                      onTap: () =>
                          _pick(context, EventDiscoveryDatePreset.thisMonth),
                    ),
                    _Tile(
                      label: preset == EventDiscoveryDatePreset.custom
                          ? _formatRangeShort(range)
                          : 'Custom dates…',
                      selected: preset == EventDiscoveryDatePreset.custom,
                      onTap: () => _pickCustomRange(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    title: Text(
      label,
      style: GoogleFonts.inter(
        color: selected ? AppColors.brandGreen : AppColors.textPrimary,
        fontSize: 14.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    trailing: selected
        ? const Icon(Icons.check_rounded, color: AppColors.brandGreen)
        : null,
  );
}
