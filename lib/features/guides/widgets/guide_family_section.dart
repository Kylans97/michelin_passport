import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import 'guide_destination_row.dart';

/// One source family on the Guides landing page — "MICHELIN GUIDE",
/// "THE WORLD'S 50 BEST", and later "GAULT&MILLAU" (see this class's own
/// doc on why adding a third family needs no change here). The family
/// name, then its destinations with generous space between them —
/// hierarchy comes from spacing and typography alone (no hairline under
/// the family name): a translucent-ivory divider over the deep-green
/// canvas reads as a faint green line rather than a crisp rule, and the
/// brief is explicit that this screen should rely on whitespace, not
/// horizontal rules.
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
      const SizedBox(height: CsSpacing.xl),
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
