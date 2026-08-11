import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// A premium, editorial venue-card shell — a warm ivory content surface
/// inside a deep-green environment, with an image ([CsImagePlaceholder]
/// today, real photography later — the caller supplies it, this widget
/// doesn't know which) as the visual anchor. Purely presentational: no
/// knowledge of Restaurant/Hotel/visit-stats types, no navigation logic of
/// its own beyond calling [onTap] — the caller supplies every piece of
/// content and handles what tapping actually does.
///
/// First built for Passport's restaurant/hotel cards; kept generic enough
/// (an eyebrow type label, an optional award-row slot, an optional footer
/// slot) to be reused by a later place-card treatment elsewhere (Explore,
/// Trips, a future Home) without changes, rather than being Passport-only.
class CsPlaceCard extends StatelessWidget {
  final Widget image;

  /// Optional venue-type label (e.g. "RESTAURANT"). Null renders no eyebrow
  /// line at all — not an empty one — so the title sits at the top of the
  /// content column with no leftover gap.
  final String? eyebrow;
  final String title;
  final String subtitle;
  final Widget? awardRow;
  final Widget? footer;
  final VoidCallback onTap;
  final double imageSize;

  const CsPlaceCard({
    super.key,
    required this.image,
    this.eyebrow,
    required this.title,
    required this.subtitle,
    this.awardRow,
    this.footer,
    required this.onTap,
    this.imageSize = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.card),
        child: Container(
          padding: const EdgeInsets.all(CsSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.ivory,
            borderRadius: BorderRadius.circular(CsRadius.card),
            border: Border.all(color: AppColors.subtleBorderLight, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: imageSize, height: imageSize, child: image),
              const SizedBox(width: CsSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(eyebrow!, style: CsTypography.eyebrow),
                      const SizedBox(height: CsSpacing.xs),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle,
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.metadata,
                    ),
                    if (awardRow != null) ...[
                      const SizedBox(height: CsSpacing.sm),
                      awardRow!,
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: CsSpacing.sm),
                      footer!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
