import '../../models/hotel.dart';
import '../../models/restaurant.dart';

/// Michelin Restaurants' result order: current Michelin stars descending,
/// then name alphabetical — never World's 50 Best rank, visit count or any
/// other signal (see the Guides Step 2B brief). Extracted as its own pure,
/// testable function rather than an inline `.sort()` at the call site,
/// mirroring explore_view_model.dart's own isExploreSearching/
/// mergeVenueCountries — [MichelinRestaurantGuideScreen] itself can't be
/// widget-tested (it constructs RestaurantRepository against
/// Supabase.instance.client unconditionally, the same limitation already
/// documented for PassportScreen/ExploreScreen).
///
/// Sorts a copy — never mutates [restaurants] in place, so a caller that
/// also holds the original list (e.g. a cached "last successful load") is
/// never surprised by its own list changing order out from under it.
///
/// Ordering by stars is done server-side wherever practical (see
/// RestaurantRepository.search()'s `starsOnly`, which guarantees every
/// result here already has a non-null michelinStars), but the actual
/// descending-then-alphabetical ORDER isn't expressible in one PostgREST
/// `.order()` call the way `worlds_50_best_rank ascending` is, so it's
/// applied client-side on the (already filtered, already bounded) result
/// set instead.
List<Restaurant> sortGuideRestaurants(List<Restaurant> restaurants) {
  final sorted = List<Restaurant>.of(restaurants);
  sorted.sort((a, b) {
    final starsCompare = (b.michelinStars ?? 0).compareTo(a.michelinStars ?? 0);
    if (starsCompare != 0) return starsCompare;
    return a.name.compareTo(b.name);
  });
  return sorted;
}

/// Michelin Hotels' result order: current Michelin Keys descending, then
/// name alphabetical — the mirror of [sortGuideRestaurants] for hotels.
/// Never mixes in World's 50 Best rank (see the Guides Step 2B brief).
List<Hotel> sortGuideHotels(List<Hotel> hotels) {
  final sorted = List<Hotel>.of(hotels);
  sorted.sort((a, b) {
    final keysCompare = (b.michelinKeys ?? 0).compareTo(a.michelinKeys ?? 0);
    if (keysCompare != 0) return keysCompare;
    return a.name.compareTo(b.name);
  });
  return sorted;
}
