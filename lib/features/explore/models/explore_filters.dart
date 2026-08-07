/// Explore's top-level venue-type selector: All / Restaurants / Hotels.
enum ExploreVenueType {
  all,
  restaurants,
  hotels;

  String get label => switch (this) {
    ExploreVenueType.all => 'All',
    ExploreVenueType.restaurants => 'Restaurants',
    ExploreVenueType.hotels => 'Hotels',
  };
}

/// Restaurant award filter, shown only when [ExploreVenueType.restaurants]
/// is selected — a single-select radio group, each option mapping to
/// RestaurantRepository.search()'s params.
enum RestaurantAwardFilter {
  all,
  oneStar,
  twoStars,
  threeStars,
  worlds50Best,
  hallOfFame;

  String get label => switch (this) {
    RestaurantAwardFilter.all => 'All',
    RestaurantAwardFilter.oneStar => '★',
    RestaurantAwardFilter.twoStars => '★★',
    RestaurantAwardFilter.threeStars => '★★★',
    RestaurantAwardFilter.worlds50Best => "World's 50 Best",
    RestaurantAwardFilter.hallOfFame => 'Hall of Fame',
  };

  /// The `michelin_stars` value to filter on, or null for "All" or a
  /// non-star award (World's 50 Best / Hall of Fame apply independently).
  int? get starsParam => switch (this) {
    RestaurantAwardFilter.oneStar => 1,
    RestaurantAwardFilter.twoStars => 2,
    RestaurantAwardFilter.threeStars => 3,
    _ => null,
  };

  bool get isWorlds50Best => this == RestaurantAwardFilter.worlds50Best;
  bool get isHallOfFame => this == RestaurantAwardFilter.hallOfFame;
}

/// Hotel Michelin Keys filter, shown only when [ExploreVenueType.hotels] is
/// selected — maps to HotelRepository.search()'s `keys` param.
enum HotelKeysFilter {
  all,
  oneKey,
  twoKeys,
  threeKeys;

  String get label => switch (this) {
    HotelKeysFilter.all => 'All',
    HotelKeysFilter.oneKey => '🔑',
    HotelKeysFilter.twoKeys => '🔑🔑',
    HotelKeysFilter.threeKeys => '🔑🔑🔑',
  };

  int? get keysParam => switch (this) {
    HotelKeysFilter.oneKey => 1,
    HotelKeysFilter.twoKeys => 2,
    HotelKeysFilter.threeKeys => 3,
    _ => null,
  };
}
