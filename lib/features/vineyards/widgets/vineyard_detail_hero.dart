import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_header_drawing.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../models/vineyard.dart';

/// The top of a wine estate's page. Its own widget beside VenueDetailHero,
/// PrivateChefHero, EventDetailHero and JourneyDetailHero (CLAUDE.md: the
/// heroes stay separate, settled, do not unify). An estate has no photo
/// until it supplies one, so this hero shows one of the three wine-estate
/// line drawings, seeded by the estate's id (CsHeaderDrawing; product
/// owner, 2026-11-20), behind the region as an eyebrow, the name, and
/// where it is.
class VineyardDetailHero extends StatelessWidget {
  final Vineyard vineyard;
  final bool wishlisted;
  final VoidCallback onToggleWishlist;

  const VineyardDetailHero({
    super.key,
    required this.vineyard,
    required this.wishlisted,
    required this.onToggleWishlist,
  });

  // Below the status bar: the hero's own height, like VenueDetailHero's.
  static const double _minHeight = 300;

  @override
  Widget build(BuildContext context) {
    final eyebrow = [
      'Wine estate',
      if ((vineyard.region ?? '').trim().isNotEmpty) vineyard.region!.trim(),
    ].join(' · ');
    final where = [
      if ((vineyard.city ?? '').trim().isNotEmpty) vineyard.city!.trim(),
      if ((vineyard.countryName ?? '').trim().isNotEmpty)
        vineyard.countryName!.trim(),
    ].join(', ');
    final drawing = HeaderDrawing.vineyard(vineyard.id);
    return ColoredBox(
      color: AppColors.deepGreen,
      child: Stack(
        children: [
          Positioned.fill(
            child: CsHeaderDrawing(drawing: drawing, belowToolbar: true),
          ),
          // Bottom-weighted vignette so the name stays legible over the
          // drawing — the same treatment VenueDetailHero gives a photo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.deepGreen.withValues(alpha: 0.55),
                    AppColors.deepGreen.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.base,
                0,
                CsSpacing.base,
                CsSpacing.xl,
              ),
              child: ConstrainedBox(
                // Tall enough for the drawing to read as a picture; the
                // name sits at the bottom, over the vignette.
                constraints: const BoxConstraints(minHeight: _minHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const EditorialBackButton(color: AppColors.ivory),
                        const Spacer(),
                        IconButton(
                          onPressed: onToggleWishlist,
                          tooltip: wishlisted
                              ? 'Remove from wishlist'
                              : 'Add to wishlist',
                          icon: Icon(
                            wishlisted
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: AppColors.ivory,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CsSpacing.pageHorizontal - CsSpacing.base,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: CsSpacing.md),
                          Text(
                            eyebrow.toUpperCase(),
                            style: CsTypography.eyebrow.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.sm),
                          Text(
                            vineyard.name,
                            style: CsTypography.displayHero.copyWith(
                              color: AppColors.ivory,
                            ),
                          ),
                          if (where.isNotEmpty) ...[
                            const SizedBox(height: CsSpacing.xs),
                            Text(
                              where,
                              style: CsTypography.body.copyWith(
                                color: AppColors.secondaryOnDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
