import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/passport_venue.dart';

/// One venue on a friend's Wishlist (Social Foundation Step 2 §14). Built
/// fresh for the dark editorial system rather than reusing [WishlistCard]
/// (light-card, and carries an owner-only remove action this screen must
/// never offer for someone else's wishlist) — see [FriendVisitTile]'s own
/// doc comment for the same reasoning. Tapping opens the venue's existing
/// Detail screen, exactly like the owner's own Wishlist. No remove
/// action, no "Plan visit" here — those are the owner's own decisions
/// about their own wishlist and trips, not something a viewer acts on
/// from someone else's profile.
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
    final (awardBadge, location) = switch (v) {
      RestaurantVenue(:final restaurant) => (
        restaurant.hasMichelinStar
            ? StarRow(count: restaurant.michelinStars!, size: 12)
            : null,
        '${restaurant.cityName}, ${restaurant.countryName}',
      ),
      HotelVenue(:final hotel) => (
        hotel.hasMichelinKeys
            ? KeyRow(count: hotel.michelinKeys!, size: 12)
            : null,
        '${hotel.cityName}, ${hotel.countryName}',
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CsSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.brandGreenLight,
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderDark),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                    if (awardBadge != null) ...[
                      const SizedBox(height: 6),
                      awardBadge,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryOnDark,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
