/// Michelin Restaurants' star-tier filter. Deliberately a new, Guides-only
/// enum rather than reusing Explore's [RestaurantAwardFilter]: that enum
/// also carries `worlds50Best`/`hallOfFame` tiers that don't belong on a
/// Michelin-only catalogue (cross-recognition is explicitly deferred — see
/// the Guides Step 2B brief), so reusing it here would mean either hiding
/// values Guides never shows or letting an unrelated screen's filter model
/// grow catalogue-specific branches. Symbol labels (★/★★/★★★) mirror
/// [RestaurantAwardFilter]'s own established choice — Guides doesn't invent
/// a new Michelin symbol system, it reuses the one already on screen
/// elsewhere in the app.
enum GuideStarFilter {
  all,
  one,
  two,
  three;

  String get label => switch (this) {
    GuideStarFilter.all => 'All',
    GuideStarFilter.one => '★',
    GuideStarFilter.two => '★★',
    GuideStarFilter.three => '★★★',
  };

  /// The `michelin_stars` value to filter on, or null for "All" (which
  /// still only shows currently-starred restaurants — see
  /// RestaurantRepository.search()'s `starsOnly`).
  int? get starsParam => switch (this) {
    GuideStarFilter.one => 1,
    GuideStarFilter.two => 2,
    GuideStarFilter.three => 3,
    GuideStarFilter.all => null,
  };
}

/// Michelin Hotels' Key-tier filter — the mirror of [GuideStarFilter] for
/// hotels, same reasoning for being its own enum rather than reusing
/// Explore's [HotelKeysFilter] (which also carries a `worlds50Best` tier).
enum GuideKeyFilter {
  all,
  one,
  two,
  three;

  String get label => switch (this) {
    GuideKeyFilter.all => 'All',
    GuideKeyFilter.one => '🔑',
    GuideKeyFilter.two => '🔑🔑',
    GuideKeyFilter.three => '🔑🔑🔑',
  };

  /// The `michelin_keys` value to filter on, or null for "All" (which
  /// still only shows hotels with a confirmed Key value — see
  /// HotelRepository.search()'s `keysOnly`).
  int? get keysParam => switch (this) {
    GuideKeyFilter.one => 1,
    GuideKeyFilter.two => 2,
    GuideKeyFilter.three => 3,
    GuideKeyFilter.all => null,
  };
}
