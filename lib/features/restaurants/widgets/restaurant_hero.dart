import 'package:flutter/material.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_detail_hero.dart';
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
    // Consolidated recognition hierarchy (UI Consistency Step 1): Michelin
    // stars are the sole primary signal (above, large, alone). Every other
    // current-status recognition — World's 50 Best rank, Hall of Fame — is
    // a secondary badge here rather than a second, duplicate "AWARDS" card
    // further down the screen (the previous generation showed Michelin
    // stars/W50B/rank in BOTH the hero AND a full awards card below it).
    // Hall of Fame previously lived only in that now-removed card; the
    // capability survives, relocated here rather than silently dropped.
    final secondaryBadges = <Widget>[
      if (restaurant.isHallOfFame)
        const VenueHeroBadge(
          icon: Icons.military_tech_rounded,
          label: 'Hall of Fame',
        ),
      if (restaurant.isWorlds50Best)
        VenueHeroBadge(
          icon: Icons.emoji_events_rounded,
          label: "World's 50 Best · #${restaurant.worlds50BestRank}",
        ),
      if (hasHotelBadge)
        VenueHeroBadge(icon: Icons.hotel_rounded, label: restaurant.hotelName!),
    ];

    return VenueDetailHero(
      title: restaurant.name,
      primaryRecognition: restaurant.hasMichelinStar
          ? StarRow(count: restaurant.michelinStars!, size: 20)
          : null,
      secondaryBadges: secondaryBadges,
      isWishlisted: isWishlisted,
      wishlistSaving: wishlistSaving,
      onTapWishlist: onTapWishlist,
    );
  }
}
