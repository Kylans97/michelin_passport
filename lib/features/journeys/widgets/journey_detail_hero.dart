import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_header_drawing.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../models/journey.dart';

/// The top of a journey's detail page. A fourth hero, deliberately its own
/// widget beside VenueDetailHero, PrivateChefHero and EventDetailHero
/// (CLAUDE.md: the heroes stay separate, settled, do not unify; product
/// owner, 2026-11-16, for this one). A journey has no photo until its
/// operator supplies one, no address and no award, so this hero shows
/// the train or ship line drawing, seeded by the journey's id
/// (CsHeaderDrawing; product owner, 2026-11-20), behind the kind and
/// operator as an eyebrow, the name, where it runs, and the wishlist
/// heart.
class JourneyDetailHero extends StatelessWidget {
  final Journey journey;
  final bool wishlisted;
  final VoidCallback onToggleWishlist;

  const JourneyDetailHero({
    super.key,
    required this.journey,
    required this.wishlisted,
    required this.onToggleWishlist,
  });

  // Below the status bar: the hero's own height, like VenueDetailHero's.
  static const double _minHeight = 300;

  @override
  Widget build(BuildContext context) {
    final where = journey.whereLine;
    final drawing = HeaderDrawing.journey(
      journey.id,
      journey.kind,
      shipType: journey.shipType,
    );
    return ColoredBox(
      color: AppColors.deepGreen,
      child: Stack(
        children: [
          Positioned.fill(
            child: CsHeaderDrawing(
              drawing: drawing,
              belowToolbar: true,
              bottomInset: CsHeaderDrawing.heroTextBand,
            ),
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
                            '${journey.kindLabel} · ${journey.operatorName}'
                                .toUpperCase(),
                            style: CsTypography.eyebrow.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.sm),
                          Text(
                            journey.name,
                            style: CsTypography.displayHero.copyWith(
                              color: AppColors.ivory,
                            ),
                          ),
                          if (where != null) ...[
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
