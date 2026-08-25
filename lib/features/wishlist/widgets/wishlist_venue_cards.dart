import 'package:flutter/material.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../passport/widgets/passport_card_chrome.dart';
import '../../restaurants/restaurant_detail_screen.dart';

/// PASSPORT — WISHLIST UI POLISH V1: a saved restaurant, in the exact same
/// ivory `CsPlaceCard` family as Passport's own collection cards
/// ([PassportRestaurantCard]) — same image slot, same serif title, same
/// award row, same bookmark chrome. Deliberately NOT a reuse of
/// [PassportRestaurantCard] itself: that widget requires
/// [PassportVenueStats] (visit count/average rating), a concept that
/// doesn't exist for a wishlisted-but-never-visited venue. No
/// [CsPlaceCard.fullWidthFooter] here for the same reason — Wishlist is
/// not visit history, so a rating/visit-count footer would be either
/// fabricated or misleading; the card answers exactly what/where/
/// recognition/saved, nothing else.
///
/// [onRemove] always means "remove from wishlist" — every card in this
/// list is, by definition, already wishlisted, so [PassportCardBookmark]
/// is used here as a filled, remove-only affordance rather than a
/// toggle between two states.
class WishlistRestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onRemove;

  const WishlistRestaurantCard({
    super.key,
    required this.restaurant,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => CsPlaceCard(
    image: const CsImagePlaceholder(
      borderRadius: BorderRadius.all(Radius.circular(CsRadius.medium)),
    ),
    title: restaurant.name,
    subtitle: _locationLabel(
      cityName: restaurant.cityName,
      countryName: restaurant.countryName,
      flagEmoji: restaurant.flagEmoji,
    ),
    awardRow: restaurant.hasMichelinStar
        ? StarRow(count: restaurant.michelinStars!, size: 14)
        : null,
    bookmark: PassportCardBookmark(isWishlisted: true, onTap: onRemove),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    ),
  );
}

/// The hotel counterpart to [WishlistRestaurantCard] — same shell, Keys
/// instead of Stars, Hotel Detail instead of Restaurant Detail. See that
/// class's own doc comment for why this isn't a reuse of
/// [PassportHotelCard].
class WishlistHotelCard extends StatelessWidget {
  final Hotel hotel;
  final VoidCallback onRemove;

  const WishlistHotelCard({
    super.key,
    required this.hotel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => CsPlaceCard(
    image: const CsImagePlaceholder(
      borderRadius: BorderRadius.all(Radius.circular(CsRadius.medium)),
    ),
    title: hotel.name,
    subtitle: _locationLabel(
      cityName: hotel.cityName,
      countryName: hotel.countryName,
      flagEmoji: hotel.flagEmoji,
    ),
    awardRow: hotel.hasMichelinKeys
        ? KeyRow(count: hotel.michelinKeys!, size: 14)
        : null,
    bookmark: PassportCardBookmark(isWishlisted: true, onTap: onRemove),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
    ),
  );
}

// "City, 🇳🇱 Country" — matches PassportRestaurantCard/PassportHotelCard's
// own location-label rule exactly, falling back to plain "City, Country"
// when flagEmoji is empty rather than inventing one from countryCode.
String _locationLabel({
  required String cityName,
  required String countryName,
  required String flagEmoji,
}) {
  final country = flagEmoji.isNotEmpty ? '$flagEmoji $countryName' : countryName;
  return '$cityName, $country';
}
