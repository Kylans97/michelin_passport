import '../../models/passport_venue.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;

/// Wishlist's initial venue-type filter, once its data has loaded — never
/// [ExploreVenueType.all] (Wishlist has no All category, see
/// WishlistScreen). Restaurants is the sensible default, EXCEPT when the
/// user's existing wishlist is hotels-only: defaulting to Restaurants
/// there would land them on an empty list for no reason, so Hotels wins
/// only in that one case. A pure function (no Supabase dependency) so it's
/// directly unit-testable — mirrors eventMatchesTrip's own reasoning for
/// staying pure.
ExploreVenueType defaultWishlistVenueType(List<PassportVenue> items) {
  final hasRestaurants = items.any((v) => v is RestaurantVenue);
  final hasHotels = items.any((v) => v is HotelVenue);
  if (!hasRestaurants && hasHotels) return ExploreVenueType.hotels;
  return ExploreVenueType.restaurants;
}
