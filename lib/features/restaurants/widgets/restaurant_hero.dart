import 'package:flutter/material.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_detail_hero.dart';
import '../../../models/published_venue_photo.dart';
import '../../../models/restaurant.dart';

class RestaurantHero extends StatelessWidget {
  final Restaurant restaurant;
  final bool hasHotelBadge;

  /// The restaurant's full published-photo set, in display_order — loaded
  /// independently by RestaurantDetailScreen (one venue, one query; never
  /// merged onto the Restaurant model or restaurants_full, which only ever
  /// resolves the single cover photo — see RestaurantRepository
  /// .getPhotos' own doc comment). Empty while that load is still in
  /// flight or on a venue with no photos; [restaurant.coverImageUrl] covers
  /// that gap below so the hero never regresses to the gradient for a venue
  /// whose cover photo is already known synchronously from the initial
  /// restaurants_full row. Typed as [PublishedVenuePhoto], not a bare url
  /// list, since Report (below) needs each photo's real id — the cover
  /// fallback deliberately never flows through here, since it has no
  /// `restaurant_photos` row to report.
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

  const RestaurantHero({
    super.key,
    required this.restaurant,
    required this.hasHotelBadge,
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

    final coverImageUrl = restaurant.coverImageUrl;
    final imageUrls = photos.isNotEmpty
        ? [for (final p in photos) p.imageUrl]
        : (coverImageUrl != null ? [coverImageUrl] : const <String>[]);

    return VenueDetailHero(
      title: restaurant.name,
      imageUrls: imageUrls,
      photos: photos,
      isPreview: isPreview,
      primaryRecognition: restaurant.hasMichelinStar
          ? StarRow(count: restaurant.michelinStars!, size: 20)
          : null,
      secondaryBadges: secondaryBadges,
      isWishlisted: isWishlisted,
      wishlistSaving: wishlistSaving,
      onTapWishlist: onTapWishlist,
      isFollowing: isFollowing,
      followBusy: followBusy,
      onTapFollow: onTapFollow,
      isClosed: restaurant.isPermanentlyClosed,
    );
  }
}
