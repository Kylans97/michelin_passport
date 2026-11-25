import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/cs_header_drawing.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../core/widgets/follow_toggle_button.dart';
import '../../../core/widgets/framed_image.dart';
import '../../../models/published_venue_photo.dart';
import '../../../models/vineyard.dart';

/// The top of a wine estate's page. Its own widget beside VenueDetailHero,
/// PrivateChefHero, EventDetailHero and JourneyDetailHero (CLAUDE.md: the
/// heroes stay separate, settled, do not unify). An estate has no photo
/// until it supplies one, so this hero shows one of the three wine-estate
/// line drawings, seeded by the estate's id (CsHeaderDrawing; product
/// owner, 2026-11-20), behind the region as an eyebrow, the name, and
/// where it is.
///
/// Once a claimed estate has published photos (vineyard_photos,
/// 20261101780000), [cover], its first photo in its own framing, takes
/// the drawing's place. Follow sits beside the heart, the way it does on
/// a restaurant or hotel.
class VineyardDetailHero extends StatelessWidget {
  final Vineyard vineyard;
  final bool wishlisted;
  final VoidCallback? onToggleWishlist;
  final PublishedVenuePhoto? cover;
  final bool isFollowing;
  final bool followBusy;

  /// Null leaves Follow out (signed out, or the follows table is not on
  /// the server yet).
  final VoidCallback? onToggleFollow;

  const VineyardDetailHero({
    super.key,
    required this.vineyard,
    required this.wishlisted,
    required this.onToggleWishlist,
    this.cover,
    this.isFollowing = false,
    this.followBusy = false,
    this.onToggleFollow,
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
    final photo = cover;
    final drawn = CsHeaderDrawing(
      drawing: drawing,
      belowToolbar: true,
      bottomInset: CsHeaderDrawing.heroTextBand,
    );
    return ColoredBox(
      color: AppColors.deepGreen,
      child: Stack(
        children: [
          Positioned.fill(
            child: photo == null
                ? drawn
                : FramedImage(
                    framing: photo.framing,
                    builder: (alignment) => AppNetworkImage(
                      photo.imageUrl,
                      longEdgePx: displayImageSizeFor(
                        context,
                        MediaQuery.sizeOf(context).width,
                        zoom: photo.framing.zoom,
                      ),
                      fit: BoxFit.cover,
                      alignment: alignment,
                      // While it loads or if it fails, the drawing.
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : drawn,
                      errorBuilder: (_, _, _) => drawn,
                    ),
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
                        if (onToggleFollow != null)
                          FollowToggleButton(
                            isFollowing: isFollowing,
                            busy: followBusy,
                            onTap: onToggleFollow,
                            entityName: vineyard.name,
                          ),
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
