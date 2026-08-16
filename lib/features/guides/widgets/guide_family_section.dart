import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import 'guide_destination_row.dart';
import 'guide_venue_card.dart';

/// One source family on the Guides landing page — "MICHELIN GUIDE",
/// "THE WORLD'S 50 BEST", and later "GAULT&MILLAU" (see this class's own
/// doc on why adding a third family needs no change here). Step 1A: an
/// ivory editorial block sitting on [GuidesScreen]'s forest-green canvas —
/// the canvas itself, visible between blocks, is now what separates one
/// family from the next (see [GuidesScreen]), so this widget no longer
/// needs to create that separation on its own.
///
/// The family name reads as a genuine masthead — [CsTypography.sectionTitle]
/// (Cormorant Garamond), not the eyebrow-weight metadata treatment Step 1
/// used — with a [GuideVenueCardDivider] hairline between each destination:
/// physical-device review of Step 1 found the family name and its
/// destinations competing rather than reading as two distinct levels, and
/// asked for internal hairlines between destinations specifically (unlike
/// the family-to-family separation above, which stays block-boundary-based,
/// never a hairline).
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      CsSpacing.xl,
      CsSpacing.xl,
      CsSpacing.xl,
      CsSpacing.lg,
    ),
    decoration: BoxDecoration(
      color: AppColors.ivory,
      borderRadius: BorderRadius.circular(CsRadius.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: CsTypography.sectionTitle.copyWith(
            color: AppColors.forestGreen,
          ),
        ),
        const SizedBox(height: CsSpacing.lg),
        for (var i = 0; i < destinations.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: CsSpacing.sm),
              child: GuideVenueCardDivider(),
            ),
          destinations[i],
        ],
      ],
    ),
  );
}
