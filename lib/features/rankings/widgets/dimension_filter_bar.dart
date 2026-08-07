import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/ranking_dimension.dart';

/// Horizontal dimension chip row — which personal rating column "My
/// Rankings" is currently sorted by. [dimensions] is the venue-type-scoped
/// list (all five for restaurants, Overall/Service/Value for hotels — see
/// RankingVenueType.validDimensions), not always the full enum.
class DimensionFilterBar extends StatelessWidget {
  final List<RankingDimension> dimensions;
  final RankingDimension selected;
  final ValueChanged<RankingDimension> onSelect;

  const DimensionFilterBar({
    super.key,
    required this.dimensions,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < dimensions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _DimensionChip(
              dimension: dimensions[i],
              selected: dimensions[i] == selected,
              onTap: () => onSelect(dimensions[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DimensionChip extends StatelessWidget {
  final RankingDimension dimension;
  final bool selected;
  final VoidCallback onTap;
  const _DimensionChip({
    required this.dimension,
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
          dimension.label,
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
