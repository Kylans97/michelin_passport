import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../models/journey.dart';

/// The top of a journey's detail page. A fourth hero, deliberately its own
/// widget beside VenueDetailHero, PrivateChefHero and EventDetailHero
/// (CLAUDE.md: the heroes stay separate, settled, do not unify; product
/// owner, 2026-11-16, for this one). A journey has no photo until its
/// operator supplies one, no address and no award, so this hero is
/// typographic: deep green, the kind and operator as an eyebrow, the name,
/// where it runs, and the wishlist heart.
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

  @override
  Widget build(BuildContext context) {
    final where = journey.whereLine;
    return ColoredBox(
      color: AppColors.deepGreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.base,
            0,
            CsSpacing.base,
            CsSpacing.xl,
          ),
          child: Column(
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
    );
  }
}
