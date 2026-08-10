import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/detail_hero.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';

class RestaurantHero extends StatelessWidget {
  final Restaurant restaurant;
  final bool hasHotelBadge;
  final bool isWishlisted;
  final bool wishlistSaving;
  final VoidCallback onTapWishlist;

  const RestaurantHero({
    super.key,
    required this.restaurant,
    required this.hasHotelBadge,
    required this.isWishlisted,
    required this.wishlistSaving,
    required this.onTapWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final extraBadges = <Widget>[
      if (restaurant.isWorlds50Best)
        HeroBadge(
          icon: Icons.emoji_events_rounded,
          label: "World's 50 Best · #${restaurant.worlds50BestRank}",
        ),
      if (hasHotelBadge)
        HeroBadge(icon: Icons.hotel_rounded, label: restaurant.hotelName!),
    ];

    return DetailHero(
      title: restaurant.name,
      awardBadge: restaurant.hasMichelinStar
          ? StarRow(count: restaurant.michelinStars!, size: 18)
          : const SizedBox.shrink(),
      extraBadges: extraBadges,
      overlayAction: HeroIconButton(
        icon: isWishlisted
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: isWishlisted ? AppColors.goldLight : AppColors.textOnDark,
        onTap: wishlistSaving ? () {} : onTapWishlist,
      ),
    );
  }
}
