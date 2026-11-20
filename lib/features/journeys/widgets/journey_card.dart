import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_header_drawing.dart';
import '../../../models/journey.dart';

/// One train or ship in the Trains & Ships collection. Photos of a
/// journey come from its operator (the venue-supplied content rule), so
/// until an operator supplies them the card shows the train or ship line
/// drawing (CsHeaderDrawing, seeded by the journey's id) above the name,
/// operator and where it runs — never a scraped image. No badge at all: journeys are not in
/// the Mantelier Selection, and nothing here is gold.
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
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CsHeaderDrawing(
                    drawing: HeaderDrawing.journey(
                      journey.id,
                      journey.kind,
                      shipType: journey.shipType,
                    ),
                    borderRadius: BorderRadius.circular(CsRadius.medium),
                  ),
                ),
                const SizedBox(height: CsSpacing.md),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
