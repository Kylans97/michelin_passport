import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/explore_filters.dart';

/// The top-level venue-type segmented selector — compact, full-width,
/// equal segments. [types] defaults to all three ("All / Restaurants /
/// Hotels", Explore's own selector); pass a narrower list to drop options
/// that don't apply to a given screen — Wishlist has no "All" category
/// (see WishlistScreen), so it passes just [restaurants, hotels] here
/// rather than a second bespoke widget.
class VenueTypeSelector extends StatelessWidget {
  final ExploreVenueType selected;
  final ValueChanged<ExploreVenueType> onSelect;
  final List<ExploreVenueType> types;

  const VenueTypeSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.types = ExploreVenueType.values,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Segment(
              label: types[i].label,
              selected: types[i] == selected,
              onTap: () => onSelect(types[i]),
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
