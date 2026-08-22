/// Events V2 Step 8C — Passport's own local content-type filter:
/// Restaurants, Hotels, or Events, each rendering its own content
/// exclusively (never merged, never appended below another type).
/// Deliberately NOT `ExploreVenueType` (`features/explore/models/
/// explore_filters.dart`) — that enum is shared across Explore,
/// Wishlist, Rankings, and My Map, none of which have any product
/// reason to gain an "Events" case; adding one there would force every
/// one of those unrelated features to handle it too. This is a small,
/// genuinely Passport-local type instead. No `all` value — Passport's
/// new three-way model shows exactly one content type at a time, never
/// a merged view (the old `ExploreVenueType.all` behavior is not carried
/// forward).
enum PassportFilterType {
  restaurants,
  hotels,
  events;

  String get label => switch (this) {
    PassportFilterType.restaurants => 'Restaurants',
    PassportFilterType.hotels => 'Hotels',
    PassportFilterType.events => 'Events',
  };
}
