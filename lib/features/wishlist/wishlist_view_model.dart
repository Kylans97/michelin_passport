import '../../models/event.dart';
import '../../models/passport_venue.dart';

/// Wishlist's own three tabs — Restaurants/Hotels/Events. Deliberately a
/// separate enum from [ExploreVenueType] (`explore_filters.dart`), not an
/// added member on it: that enum is read by exhaustive switches across
/// Explore, Map and Passport's own collection — none of which gain an
/// Events concept as part of EVENT WISHLIST V1 — so extending it there
/// would force unrelated screens to handle a case that doesn't apply to
/// them. Wishlist is the one place these three venue types are ever
/// switched between, so it gets its own scoped enum, matching this
/// codebase's precedent of small screen-local tab enums (e.g.
/// `CommunityTopTab`) rather than reusing/widening a shared one.
enum WishlistVenueType {
  restaurants,
  hotels,
  events;

  String get label => switch (this) {
    WishlistVenueType.restaurants => 'Restaurants',
    WishlistVenueType.hotels => 'Hotels',
    WishlistVenueType.events => 'Events',
  };
}

/// Wishlist's initial venue-type filter, once its data has loaded — never
/// [WishlistVenueType.events] as a hard default (Restaurants is still the
/// sensible first choice for most users), except when the user's existing
/// wishlist has no restaurants at all: then Hotels wins if any exist,
/// else Events, if any exist — the same "don't land on an empty tab for
/// no reason" rule this function already applied to Restaurants/Hotels,
/// simply extended one tier further for the new third tab. A pure
/// function (no Supabase dependency) so it's directly unit-testable —
/// mirrors eventMatchesTrip's own reasoning for staying pure.
WishlistVenueType defaultWishlistVenueType(
  List<PassportVenue> venues,
  List<Event> events,
) {
  final hasRestaurants = venues.any((v) => v is RestaurantVenue);
  if (hasRestaurants) return WishlistVenueType.restaurants;
  final hasHotels = venues.any((v) => v is HotelVenue);
  if (hasHotels) return WishlistVenueType.hotels;
  if (events.isNotEmpty) return WishlistVenueType.events;
  return WishlistVenueType.restaurants;
}
