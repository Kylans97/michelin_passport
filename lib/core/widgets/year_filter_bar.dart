import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Horizontal "All time / 2026 / 2025 / …" chip row. Not restaurant- or
/// dimension-specific — takes whatever year list it's given — so it's
/// shared by Passport and Rankings, and any future Hotels section of either.
class YearFilterBar extends StatelessWidget {
  final List<int> years; // descending, no duplicates
  final int? selectedYear; // null means "All time"
  final ValueChanged<int?> onSelect;

  const YearFilterBar({
    super.key,
    required this.years,
    required this.selectedYear,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _YearChip(
            label: 'All time',
            selected: selectedYear == null,
            onTap: () => onSelect(null),
          ),
          for (final year in years) ...[
            const SizedBox(width: 8),
            _YearChip(
              label: '$year',
              selected: selectedYear == year,
              onTap: () => onSelect(year),
            ),
          ],
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _YearChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: AppColors.goldAlpha10,
      highlightColor: AppColors.goldAlpha10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.goldMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.goldBorder60 : AppColors.cardBorder,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
