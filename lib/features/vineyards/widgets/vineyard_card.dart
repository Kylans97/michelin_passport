import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_header_drawing.dart';
import '../../../models/vineyard.dart';

/// One estate in the Wine Estates collection. Photos of an estate come
/// from the estate after review (the venue-supplied content rule), so
/// until then the card shows the name, where it is and its rank, with one
/// of the three wine-estate line drawings beside it (CsHeaderDrawing,
/// seeded by the estate's id) — never a scraped image. The rank is
/// claret, never gold.
class VineyardCard extends StatelessWidget {
  final Vineyard vineyard;
  final VoidCallback onTap;

  const VineyardCard({super.key, required this.vineyard, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rank = vineyard.worlds50BestRank;
    final where = vineyard.regionLine;
    return Semantics(
      button: true,
      label: [
        vineyard.name,
        if (where.isNotEmpty) where,
        ?vineyard.rankLabel,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    rank == null ? '' : '$rank',
                    style: CsTypography.placeTitle.copyWith(
                      color: AppColors.claret,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vineyard.name,
                        style: CsTypography.placeTitle.copyWith(
                          color: AppColors.forestGreen,
                        ),
                      ),
                      if (where.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          where,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: CsSpacing.md),
                CsHeaderDrawing(
                  drawing: HeaderDrawing.vineyard(vineyard.id),
                  width: 64,
                  height: 64,
                  borderRadius: BorderRadius.circular(CsRadius.small),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
