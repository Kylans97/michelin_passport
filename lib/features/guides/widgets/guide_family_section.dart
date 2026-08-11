import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import 'guide_destination_row.dart';

/// One source family on the Guides landing page — "MICHELIN GUIDE",
/// "THE WORLD'S 50 BEST", and later "GAULT&MILLAU" (see this class's own
/// doc on why adding a third family needs no change here). A thin
/// hairline under the family name, then its destinations with generous
/// space between them — deliberately no divider between every row: a
/// line under each destination would read as a settings list; one line
/// under the family name, then open breathing room, reads as an editorial
/// index instead.
///
/// [GuidesScreen] adds a third family later purely by adding another
/// `GuideFamilySection(title: 'GAULT&MILLAU', destinations: [...])` to its
/// own Column — nothing here assumes exactly two families, and nothing
/// here is Michelin/50-Best-specific.
class GuideFamilySection extends StatelessWidget {
  final String title;
  final List<GuideDestinationRow> destinations;

  const GuideFamilySection({
    super.key,
    required this.title,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
      ),
      const SizedBox(height: CsSpacing.sm),
      Container(height: 0.5, color: AppColors.subtleBorderDark),
      const SizedBox(height: CsSpacing.lg),
      for (var i = 0; i < destinations.length; i++) ...[
        // ~12.5% less than CsSpacing.xl (24) per physical-device review —
        // Restaurants/Hotels should read as two destinations within ONE
        // family, distinctly tighter than the gap between families itself
        // (see GuidesScreen, unchanged at CsSpacing.section-derived
        // spacing between GuideFamilySections).
        if (i > 0) const SizedBox(height: 21),
        destinations[i],
      ],
    ],
  );
}
