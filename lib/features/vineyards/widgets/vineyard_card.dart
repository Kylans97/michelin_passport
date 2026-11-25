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

  /// The big claret figure on the left: the 50 Best rank by default; a
  /// classification section passes an empty one.
  final String? marker;

  /// A line under where the estate is, in claret: its class in a
  /// classification section ("Premier Cru").
  final String? note;

  const VineyardCard({
    super.key,
    required this.vineyard,
    required this.onTap,
    this.marker,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final rank = vineyard.worlds50BestRank;
    final figure = marker ?? (rank == null ? '' : '$rank');
    // In a classification list every estate shares the region, so the
    // village tells them apart.
    final where = note != null ? vineyard.villageLine : vineyard.regionLine;
    return Semantics(
      button: true,
      label: [
        vineyard.name,
        if (where.isNotEmpty) where,
        if (note != null) note! else ?vineyard.rankLabel,
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
                // The rank column only where there is a rank: a
                // classification list has none, so its names start at the
                // card's edge.
                if (figure.isNotEmpty)
                  SizedBox(
                    width: 44,
                    child: Text(
                      figure,
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
                      if (note != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          note!,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.claret,
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
