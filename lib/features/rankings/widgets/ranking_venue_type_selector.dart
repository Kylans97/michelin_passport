import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/ranking_venue_type.dart';

/// "Restaurants / Hotels" segmented selector for My Rankings — deliberately
/// two options only (no "All"): a restaurant ranking and a hotel ranking
/// are separate contexts with different valid dimensions, unlike Explore/
/// Passport's combined browsing view. Visual styling mirrors Explore's
/// VenueTypeSelector, kept as its own small widget rather than forcing
/// ExploreVenueType.all into a context that never uses it.
class RankingVenueTypeSelector extends StatelessWidget {
  final RankingVenueType selected;
  final ValueChanged<RankingVenueType> onSelect;

  const RankingVenueTypeSelector({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < RankingVenueType.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Segment(
              label: RankingVenueType.values[i].label,
              selected: RankingVenueType.values[i] == selected,
              onTap: () => onSelect(RankingVenueType.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: AppColors.goldAlpha10,
      highlightColor: AppColors.goldAlpha10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.goldMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
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
