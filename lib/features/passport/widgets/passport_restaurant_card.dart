import 'package:flutter/material.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import '../passport_view_model.dart';
import 'passport_card_chrome.dart';

// "City, 🇳🇱 Country" — falls back to plain "City, Country" when
// flagEmoji is empty rather than inventing one from countryCode.
String _locationLabel(Restaurant restaurant) {
  final country = restaurant.flagEmoji.isNotEmpty
      ? '${restaurant.flagEmoji} ${restaurant.countryName}'
      : restaurant.countryName;
  return '${restaurant.cityName}, $country';
}

/// One unique restaurant in the Passport list, scoped to the active
/// venue-type/year filter: visit count and average rating reflect only
/// the visits [stats] was built from. Tapping opens the existing
/// RestaurantDetailScreen, exactly as before — only the visual
/// presentation (now built on [CsPlaceCard]) changed. StarRow is reused
/// unchanged (gold-filled stars): it's a shared component read by every
/// other screen showing Michelin stars today, and gold-on-ivory is already
/// the established, working combination everywhere else in the app.
///
/// Passport UI Polish V2: the footer no longer shows "Last visit DATE" —
/// removed per explicit product direction (see [PassportCardFooter]'s own
/// doc comment). The bookmark is now a real, wired wishlist toggle
/// ([isWishlisted]/[onToggleWishlist]) rather than the previous pass's
/// deliberately static glyph — [PassportCollectionBody] owns the actual
/// [WishlistRepository] call and optimistic state; this widget only
/// renders what it's told and reports taps.
class PassportRestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final PassportVenueStats stats;
  final bool isWishlisted;
  final VoidCallback onToggleWishlist;

  const PassportRestaurantCard({
    super.key,
    required this.restaurant,
    required this.stats,
    required this.isWishlisted,
    required this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final avg = stats.averageRating;

    return CsPlaceCard(
      image: const CsImagePlaceholder(
        borderRadius: BorderRadius.all(Radius.circular(CsRadius.medium)),
      ),
      title: restaurant.name,
      subtitle: _locationLabel(restaurant),
      awardRow: restaurant.hasMichelinStar
          ? StarRow(count: restaurant.michelinStars!, size: 14)
          : null,
      bookmark: PassportCardBookmark(
        isWishlisted: isWishlisted,
        onTap: onToggleWishlist,
      ),
      fullWidthFooter: PassportCardFooter(
        // A venue only ever reaches this card with visitCount >= 1 (see
        // PassportVenueStats.latestVisit's own non-nullable doc comment)
        // — avg is null only when none of those real visits were rated,
        // never "never visited." No "No visits yet" copy here for that
        // reason; the visit count alone still renders correctly.
        ratingText:
            (avg != null ? '${avg.toStringAsFixed(1)} average · ' : '') +
            (stats.visitCount == 1 ? '1 visit' : '${stats.visitCount} visits'),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
        ),
      ),
    );
  }
}
