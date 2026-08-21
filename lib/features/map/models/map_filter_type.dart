import 'map_pin.dart';

/// My Map's own venue-type filter — All / Restaurants / Hotels / Events.
/// Deliberately NOT [ExploreVenueType] (features/explore/models/
/// explore_filters.dart): that enum is shared by Explore, Passport,
/// Rankings and Wishlist, none of which this step is allowed to touch, and
/// none of which have an Events concept — adding an `events` case there
/// would force every one of those unrelated screens' own exhaustive
/// switches to grow a branch they have no use for. My Map gets its own
/// small local enum instead, reusing [CsFilterChip] the same way
/// ExploreVenueType-based screens already do.
enum MapFilterType {
  all,
  restaurants,
  hotels,
  events;

  String get label => switch (this) {
    MapFilterType.all => 'All',
    MapFilterType.restaurants => 'Restaurants',
    MapFilterType.hotels => 'Hotels',
    MapFilterType.events => 'Events',
  };

  bool matches(MapPinType type) => switch (this) {
    MapFilterType.all => true,
    MapFilterType.restaurants => type == MapPinType.restaurant,
    MapFilterType.hotels => type == MapPinType.hotel,
    MapFilterType.events => type == MapPinType.event,
  };
}
