import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';

/// Chef Detail's hero — a parallel, trimmed sibling of [VenueDetailHero],
/// not a reuse of it: that widget hard-requires wishlist state
/// ([isWishlisted]/[wishlistSaving]/[onTapWishlist]), which has no
/// equivalent concept here (Private Chefs is not on Wishlist — see
/// PRIVATE_CHEFS.md §33). Building a small parallel component for a
/// genuinely different screen is this codebase's own established pattern
/// — [VenueDetailHero] itself exists for exactly this reason rather than
/// modifying the older shared `DetailHero`.
///
/// Deliberately shows NO score, rating, review count, "Chasing Stars
/// Selected" badge, Michelin stars, or price badge — the chef's page
/// existing at all is the selection signal (PRIVATE_CHEFS.md §14). The one
/// permitted editorial context label is the small "PRIVATE CHEF" eyebrow,
/// never worded as a badge/credential.
class PrivateChefHero extends StatelessWidget {
  final String displayName;
  final String? businessName;

  /// Pre-formatted "City, CC" (or just city, or just the code) — the hero
  /// doesn't know about PrivateChef, only about strings already assembled
  /// by the caller, matching [PrivateChefRow]'s own location-join
  /// approach.
  final String? location;

  final String? profileImageUrl;
  final double expandedHeight;

  const PrivateChefHero({
    super.key,
    required this.displayName,
    this.businessName,
    this.location,
    this.profileImageUrl,
    this.expandedHeight = 320,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (profileImageUrl ?? '').isNotEmpty;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.deepGreen,
      foregroundColor: AppColors.textOnDark,
      leadingWidth: 56,
      leading: const Padding(
        padding: EdgeInsets.only(left: CsSpacing.sm),
        child: EditorialBackButton(),
      ),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CsTypography.bodyMedium.copyWith(color: AppColors.textOnDark),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              Image.network(
                profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _NoPhotoBackground(),
              )
            else
              const _NoPhotoBackground(),
            // Bottom-weighted vignette so identity text stays legible
            // regardless of whether there's a photo underneath — same
            // treatment as VenueDetailHero.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.deepGreen.withValues(alpha: hasPhoto ? 0.55 : 0),
                    AppColors.deepGreen.withValues(alpha: hasPhoto ? 0.9 : 1),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.hero,
                  CsSpacing.pageHorizontal,
                  CsSpacing.lg,
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PRIVATE CHEF',
                        style: CsTypography.eyebrow.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.xs),
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.displayHero.copyWith(
                          color: AppColors.textOnDark,
                          fontSize: 30,
                          height: 1.1,
                        ),
                      ),
                      if ((businessName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          businessName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.bodyMedium.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                      if ((location ?? '').isNotEmpty) ...[
                        const SizedBox(height: CsSpacing.xs),
                        Text(
                          location!,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPhotoBackground extends StatelessWidget {
  const _NoPhotoBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.brandGreenLight,
          AppColors.deepGreen,
          Color(0xFF0E211C),
        ],
      ),
    ),
  );
}
