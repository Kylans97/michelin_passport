import 'package:flutter/material.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/venue_detail_hero.dart';
import '../../../models/hotel.dart';

/// UI Consistency Step 1: wraps the shared [VenueDetailHero] instead of the
/// old, widely-shared [DetailHero] — mirrors [RestaurantHero]'s treatment,
/// Keys instead of Stars. Consolidated recognition hierarchy: MICHELIN Keys
/// are the sole primary signal; World's 50 Best Hotels is the only
/// secondary badge (hotels have no Hall of Fame equivalent), previously
/// duplicated in a now-removed `HotelAwardsCard`.
class HotelHero extends StatelessWidget {
  final Hotel hotel;
  final bool isWishlisted;
  final bool wishlistSaving;
  final VoidCallback onTapWishlist;

  const HotelHero({
    super.key,
    required this.hotel,
    required this.isWishlisted,
    required this.wishlistSaving,
    required this.onTapWishlist,
  });

  @override
  Widget build(BuildContext context) {
    return VenueDetailHero(
      title: hotel.name,
      primaryRecognition: hotel.hasMichelinKeys
          ? KeyRow(count: hotel.michelinKeys!, size: 20)
          : null,
      secondaryBadges: [
        if (hotel.isWorlds50Best)
          VenueHeroBadge(
            icon: Icons.emoji_events_rounded,
            // The previous `HotelAwardsCard` also surfaced the ranking
            // year when known — preserved here rather than dropped.
            label: hotel.worlds50BestYear != null
                ? "World's 50 Best · #${hotel.worlds50BestRank} · "
                      '${hotel.worlds50BestYear}'
                : "World's 50 Best · #${hotel.worlds50BestRank}",
          ),
      ],
      isWishlisted: isWishlisted,
      wishlistSaving: wishlistSaving,
      onTapWishlist: onTapWishlist,
    );
  }
}
