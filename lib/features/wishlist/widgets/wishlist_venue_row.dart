import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/passport_venue.dart';

/// One wishlisted venue — Wishlist UI Consistency Step 1. Same compact
/// editorial row language [FriendWishlistTile] already established for a
/// friend's wishlist (thumbnail, name + inline recognition, city + flag,
/// one merged tap target), with a restrained remove affordance added —
/// the one thing a friend's read-only view never needs, but the owner's
/// own Wishlist always has.
///
/// The remove control is deliberately a *second*, independently-tappable
/// target (its own [Semantics] button/label) rather than folded into the
/// row's merged label — tapping the venue name/thumbnail/recognition
/// opens the venue, tapping the heart removes it; two different actions
/// must stay two different targets, not one ambiguous combined one.
class WishlistVenueRow extends StatelessWidget {
  final PassportVenue venue;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const WishlistVenueRow({
    super.key,
    required this.venue,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final v = venue;
    final (recognition, city, country, flag, recognitionLabel) = switch (v) {
      RestaurantVenue(:final restaurant) => (
        restaurant.hasMichelinStar
            ? StarRow(count: restaurant.michelinStars!, size: 12)
            : null,
        restaurant.cityName,
        restaurant.countryName,
        restaurant.flagEmoji,
        restaurant.hasMichelinStar
            ? '${restaurant.michelinStars} ${restaurant.michelinStars == 1 ? 'Michelin star' : 'Michelin stars'}'
            : null,
      ),
      HotelVenue(:final hotel) => (
        hotel.hasMichelinKeys
            ? KeyRow(count: hotel.michelinKeys!, size: 12)
            : null,
        hotel.cityName,
        hotel.countryName,
        hotel.flagEmoji,
        hotel.hasMichelinKeys
            ? '${hotel.michelinKeys} ${hotel.michelinKeys == 1 ? 'Michelin Key' : 'Michelin Keys'}'
            : null,
      ),
    };

    final semanticLabel = [
      v.name,
      if (city.isNotEmpty) city,
      if (country.isNotEmpty) country,
      ?recognitionLabel,
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: semanticLabel,
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
                  highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const VenueThumbnail(imageUrl: null, size: 52),
                      const SizedBox(width: CsSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            recognition == null
                                ? Text(
                                    v.name,
                                    style: CsTypography.placeTitle.copyWith(
                                      fontSize: 17,
                                      color: AppColors.forestGreen,
                                    ),
                                  )
                                : Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: v.name,
                                          style: CsTypography.placeTitle
                                              .copyWith(
                                                fontSize: 17,
                                                color: AppColors.forestGreen,
                                              ),
                                        ),
                                        const WidgetSpan(
                                          child: SizedBox(width: CsSpacing.xs),
                                        ),
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: recognition,
                                        ),
                                      ],
                                    ),
                                  ),
                            if (city.isNotEmpty || flag.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (city.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        city,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: CsTypography.metadata.copyWith(
                                          color: AppColors.taupe,
                                        ),
                                      ),
                                    ),
                                  if (city.isNotEmpty && flag.isNotEmpty)
                                    const SizedBox(width: CsSpacing.xs),
                                  if (flag.isNotEmpty)
                                    Text(
                                      flag,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                ],
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
          ),
          Semantics(
            button: true,
            label: 'Remove from wishlist',
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
                highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
                child: const Padding(
                  padding: EdgeInsets.all(CsSpacing.sm),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.forestGreen,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The same strengthened taupe hairline token established for Guides' and
/// Friends' dense result lists — inlined here rather than importing across
/// feature boundaries, matching this codebase's established precedent
/// (see e.g. friend_activity_list_screen.dart's own copy of this value).
class WishlistRowDivider extends StatelessWidget {
  const WishlistRowDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.75, color: AppColors.taupe.withValues(alpha: 0.55));
}
