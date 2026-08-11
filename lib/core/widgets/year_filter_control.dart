import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../theme/cs_surface_context.dart';

/// Compact "All time ▾" / "2025 ▾" trigger that opens a bottom-sheet list
/// (All time, then years descending) on tap. Replaces the old persistent
/// "All time | 2026 | 2025 | …" chip row (formerly YearFilterBar) so the
/// year filter stays out of the way until someone actually wants to change
/// it, while keeping exactly the same underlying semantics: [selectedYear]
/// null means "All time", and [years] is the descending, deduplicated list
/// of years actually available to pick from. Shared verbatim by Passport
/// and My Rankings — same widget, same filtering behavior, just a
/// different affordance than the old chip row.
///
/// [surface] is optional and defaults to null, which keeps the original
/// light-surface trigger styling exactly as it always was — My Rankings
/// (which doesn't pass it) is completely unaffected. Passing
/// [CsSurface.dark] switches to a small outlined/tonal look for a
/// deep-green environment (Passport's redesign) — no brass. The picker
/// sheet itself is unchanged either way: a light modal overlay is the
/// established pattern for every bottom sheet in this app already.
class YearFilterControl extends StatelessWidget {
  final List<int> years; // descending, no duplicates
  final int? selectedYear; // null means "All time"
  final ValueChanged<int?> onSelect;
  final CsSurface? surface;

  const YearFilterControl({
    super.key,
    required this.years,
    required this.selectedYear,
    required this.onSelect,
    this.surface,
  });

  Future<void> _open(BuildContext context) async {
    // Wrapped in _YearPick rather than returning `int?` directly: a plain
    // `int?` can't tell "explicitly chose All time" (null) apart from
    // "dismissed the sheet without choosing anything" (also null) — the
    // wrapper makes only the former call onSelect, so swiping the sheet
    // away never silently resets an existing year selection back to All
    // time.
    final picked = await showModalBottomSheet<_YearPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _YearPickerSheet(years: years, selectedYear: selectedYear),
    );
    if (picked != null) onSelect(picked.year);
  }

  @override
  Widget build(BuildContext context) {
    final label = selectedYear == null ? 'All time' : '$selectedYear';
    final onDark = surface == CsSurface.dark;
    final background = onDark ? Colors.transparent : AppColors.surface;
    final border = onDark ? AppColors.subtleBorderDark : AppColors.cardBorder;
    final textColor = onDark ? AppColors.textOnDark : AppColors.textPrimary;
    final iconColor = onDark
        ? AppColors.secondaryOnDark
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down_rounded, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _YearPick {
  final int? year;
  const _YearPick(this.year);
}

class _YearPickerSheet extends StatelessWidget {
  final List<int> years;
  final int? selectedYear;
  const _YearPickerSheet({required this.years, required this.selectedYear});

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
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                itemCount: years.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _YearTile(
                      label: 'All time',
                      selected: selectedYear == null,
                      onTap: () =>
                          Navigator.pop(context, const _YearPick(null)),
                    );
                  }
                  final year = years[i - 1];
                  return _YearTile(
                    label: '$year',
                    selected: selectedYear == year,
                    onTap: () => Navigator.pop(context, _YearPick(year)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _YearTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _YearTile({
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
        color: selected ? AppColors.gold : AppColors.textPrimary,
        fontSize: 14.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    trailing: selected
        ? const Icon(Icons.check_rounded, color: AppColors.gold)
        : null,
  );
}
