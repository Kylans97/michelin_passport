import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/passport_venue.dart';

/// One venue on a friend's Wishlist (Community/Friends UX Step 1) — the
/// same compact editorial row [FriendVisitTile] uses, minus the rating/
/// date metadata line (a wishlist entry has none). Answers "where does
/// this person want to go?", not how the data is modeled — venue name,
/// recognition, city, flag only, no technical labels.
///
/// Tapping opens the venue's existing canonical Detail screen, exactly
/// like the owner's own Wishlist. No remove action, no "Plan visit" here
/// — those are the owner's own decisions about their own wishlist and
/// trips, not something a viewer acts on from someone else's profile.
class FriendWishlistTile extends StatelessWidget {
  final PassportVenue venue;
  final VoidCallback onTap;

  const FriendWishlistTile({
    super.key,
    required this.venue,
    required this.onTap,
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

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
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
                                    style: CsTypography.placeTitle.copyWith(
                                      fontSize: 17,
                                      color: AppColors.forestGreen,
                                    ),
                                  ),
                                  const WidgetSpan(
                                    child: SizedBox(width: CsSpacing.xs),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
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
                              Text(flag, style: const TextStyle(fontSize: 13)),
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
    );
  }
}
