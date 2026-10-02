import 'package:flutter/material.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/venue_detail_hero.dart';
import '../../../models/hotel.dart';
import '../../../models/published_venue_photo.dart';

/// UI Consistency Step 1: wraps the shared [VenueDetailHero] instead of the
/// old, widely-shared [DetailHero] — mirrors [RestaurantHero]'s treatment,
/// Keys instead of Stars. Consolidated recognition hierarchy: MICHELIN Keys
/// are the sole primary signal; World's 50 Best Hotels is the only
/// secondary badge (hotels have no Hall of Fame equivalent), previously
/// duplicated in a now-removed `HotelAwardsCard`.
class HotelHero extends StatelessWidget {
  final Hotel hotel;

  /// The hotel's full published-photo set, in display_order — see
  /// RestaurantHero.photos' own doc comment, identical reasoning.
  final List<PublishedVenuePhoto> photos;

  final bool isWishlisted;
  final bool wishlistSaving;
  final VoidCallback onTapWishlist;

  // Events V2 Step 6 — see VenueDetailHero's own doc comment for why
  // onTapFollow defaults to null (no control renders until a real
  // callback is wired).
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback? onTapFollow;

  /// See VenueDetailHero.isPreview's own doc comment — passed straight
  /// through; false (the default) means every call site that predates
  /// the Report action is unaffected.
  final bool isPreview;

  const HotelHero({
    super.key,
    required this.hotel,
    this.photos = const [],
    required this.isWishlisted,
    required this.wishlistSaving,
    required this.onTapWishlist,
    this.isFollowing = false,
    this.followBusy = false,
    this.onTapFollow,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    final coverImageUrl = hotel.coverImageUrl;
    final imageUrls = photos.isNotEmpty
        ? [for (final p in photos) p.imageUrl]
        : (coverImageUrl != null ? [coverImageUrl] : const <String>[]);

    return VenueDetailHero(
      title: hotel.name,
      imageUrls: imageUrls,
      photos: photos,
      isPreview: isPreview,
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
      isFollowing: isFollowing,
      followBusy: followBusy,
      onTapFollow: onTapFollow,
      isClosed: hotel.isPermanentlyClosed,
    );
  }
}
