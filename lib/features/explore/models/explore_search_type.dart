/// Explore's Search-mode result-type filter: All / Restaurants / Hotels /
/// Events. Deliberately a NEW, separate enum from [ExploreVenueType]
/// (models/explore_filters.dart) rather than adding an `events` case to
/// that one — [ExploreVenueType] is shared verbatim by Passport (a
/// person's own visited venues — there is no such thing as a "visited"
/// event yet) and Wishlist (restaurants/hotels only, no "all" case at
/// all). Folding Events into it would force both of those screens to
/// reason about a venue type that can never apply to them, and a Passport/
/// Wishlist call site would have to handle an `events` case that can never
/// actually be reached — a correctness footgun for no benefit. This type
/// exists purely for Explore's own search-mode filter chips and result
/// grouping; it has no relationship to venue-visit tracking at all.
enum ExploreSearchType {
  all,
  restaurants,
  hotels,
  events;

  String get label => switch (this) {
    ExploreSearchType.all => 'All',
    ExploreSearchType.restaurants => 'Restaurants',
    ExploreSearchType.hotels => 'Hotels',
    ExploreSearchType.events => 'Events',
  };
}
