import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/journey.dart';
import '../../explore/widgets/explore_discovery_cards.dart'
    show mantelierSelectionLabel;

/// One train or ship in the Trains & Ships collection. Typographic on
/// purpose: photos of a journey come from its operator (the venue-supplied
/// content rule), and until an operator supplies them the card shows the
/// name, operator and where it runs — never a scraped image, never a
/// placeholder pretending to be one. No badge beyond the Selection line,
/// and that line is forest green, never gold.
class JourneyCard extends StatelessWidget {
  final Journey journey;
  final VoidCallback onTap;

  const JourneyCard({super.key, required this.journey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final eyebrow = '${journey.kindLabel} · ${journey.operatorName}'
        .toUpperCase();
    final where = journey.whereLine;
    final summary = (journey.summary ?? '').trim();

    return Semantics(
      button: true,
      label: [
        journey.name,
        journey.kindLabel,
        journey.operatorName,
        ?where,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(CsRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(CsRadius.card),
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(CsSpacing.cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CsRadius.card),
              border: Border.all(
                color: AppColors.subtleBorderLight,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
                const SizedBox(height: CsSpacing.sm),
                Text(
                  journey.name,
                  style: CsTypography.placeTitle.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
                if (where != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    where,
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
                    ),
                  ),
                ],
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: CsSpacing.md),
                  Text(
                    summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: CsTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (journey.isSelected) ...[
                  const SizedBox(height: CsSpacing.md),
                  Text(
                    mantelierSelectionLabel.toUpperCase(),
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
