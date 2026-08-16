import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// A compact "2025 ▾" trigger that opens a bottom-sheet list of years (no
/// "All time" option) on tap — the Guides-specific counterpart of
/// [YearFilterControl], built new rather than reusing that widget: this
/// control's [selectedYear] is a non-nullable, always-one-year model
/// (World's 50 Best is a ranked snapshot for a specific year, never a
/// merged-across-years list — see the Guides Step 2C brief's explicit
/// "Passport's `null = All time` model may NOT be appropriate here"),
/// while [YearFilterControl]'s entire API and picker sheet are built
/// around `int? selectedYear` with null meaning "All time" and always
/// inserting an "All time" row first. Retrofitting that shape with an
/// `allowAllTime` flag would still leave every caller (including Passport
/// and My Rankings, whose semantics this must not touch) passing a
/// nullable year through code that no longer always means what it says —
/// a new, small, single-purpose control is the cleaner, lower-coupling
/// choice. [YearFilterControl] itself is completely unchanged by this file
/// existing.
///
/// Always on the ivory Guides canvas — unlike [YearFilterControl], there's
/// no dark-surface variant to support, so [CsSurface] isn't a parameter
/// here.
class GuideYearSelector extends StatelessWidget {
  final List<int> years; // descending, deduplicated
  final int selectedYear;
  final ValueChanged<int> onSelect;

  const GuideYearSelector({
    super.key,
    required this.years,
    required this.selectedYear,
    required this.onSelect,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _GuideYearPickerSheet(years: years, selectedYear: selectedYear),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.subtleBorderLight, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$selectedYear',
              style: GoogleFonts.inter(
                color: AppColors.forestGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.taupe,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuideYearPickerSheet extends StatelessWidget {
  final List<int> years;
  final int selectedYear;
  const _GuideYearPickerSheet({
    required this.years,
    required this.selectedYear,
  });

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
        // A Material ancestor between the Container's own opaque background
        // fill and each ListTile — without this, ListTile's ink splash
        // paints on the nearest Material ancestor further UP the tree,
        // which the Container's background then visually covers ("ListTile
        // background color or ink splashes may be invisible").
        // MaterialType.transparency keeps this invisible itself; it exists
        // purely to give the tiles a paint surface positioned after (i.e.
        // on top of) the rounded card background.
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
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: years.length,
                  itemBuilder: (context, i) {
                    final year = years[i];
                    return _GuideYearTile(
                      year: year,
                      selected: selectedYear == year,
                      onTap: () => Navigator.pop(context, year),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GuideYearTile extends StatelessWidget {
  final int year;
  final bool selected;
  final VoidCallback onTap;
  const _GuideYearTile({
    required this.year,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    title: Text(
      '$year',
      style: GoogleFonts.inter(
        color: selected ? AppColors.forestGreen : AppColors.textPrimary,
        fontSize: 14.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    trailing: selected
        ? const Icon(Icons.check_rounded, color: AppColors.forestGreen)
        : null,
  );
}
