import '../../models/event.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';

/// Explore's Discovery-mode "what to surface" logic — pure, deterministic,
/// presentation-only selectors over already-loaded catalogue/event data.
/// No database changes, no new "featured" column, no popularity table, no
/// recommendation score: every rule here reads only fields that already
/// exist on [Restaurant]/[Hotel]/[Event] today. Kept separate from
/// rendering (nothing here builds a widget) specifically so a future
/// editorial/commercial/community selection mechanism can replace the body
/// of one of these functions later without touching any discovery widget
/// at all — the call sites only ever see "a short list of things to show",
/// never how that list was chosen.

/// "Worth the Journey" — restaurants worth surfacing on Explore's discovery
/// feed. Deterministic rule, in priority order: higher current Michelin
/// star count first (a starless restaurant sorts after every starred one,
/// never assumed to be "0 stars" — see [Restaurant.michelinStars]'s own
/// null-means-unstarred contract), then a current World's 50 Best rank as
/// a tie-breaker among equally-starred restaurants (lower rank, i.e. closer
/// to #1, first), then alphabetically by name for total stability so the
/// same input always produces the same output. [limit] caps the list to a
/// browsable discovery row rather than the whole catalogue.
List<Restaurant> selectDiscoveryRestaurants(
  List<Restaurant> restaurants, {
  int limit = 8,
}) {
  final sorted = [...restaurants];
  sorted.sort((a, b) {
    final byStars = (b.michelinStars ?? -1).compareTo(a.michelinStars ?? -1);
    if (byStars != 0) return byStars;
    final byRank = (a.worlds50BestRank ?? 1 << 30).compareTo(
      b.worlds50BestRank ?? 1 << 30,
    );
    if (byRank != 0) return byRank;
    return a.name.compareTo(b.name);
  });
  return sorted.take(limit).toList();
}

/// "Stay a Little Longer" — the hotel equivalent of
/// [selectDiscoveryRestaurants], same rule shape applied to MICHELIN Keys
/// instead of stars: higher current Key count first (null/unconfirmed Keys
/// sort last, never assumed to be zero — see [Hotel.michelinKeys]), then
/// current World's 50 Best Hotels rank as a tie-breaker, then
/// alphabetically by name.
List<Hotel> selectDiscoveryHotels(List<Hotel> hotels, {int limit = 8}) {
  final sorted = [...hotels];
  sorted.sort((a, b) {
    final byKeys = (b.michelinKeys ?? -1).compareTo(a.michelinKeys ?? -1);
    if (byKeys != 0) return byKeys;
    final byRank = (a.worlds50BestRank ?? 1 << 30).compareTo(
      b.worlds50BestRank ?? 1 << 30,
    );
    if (byRank != 0) return byRank;
    return a.name.compareTo(b.name);
  });
  return sorted.take(limit).toList();
}

/// "What's On" — the single event featured at the top of Explore's
/// discovery feed: the soonest upcoming event, excluding cancelled ones
/// (a cancelled event stays visible everywhere it's explicitly searched
/// for or browsed in the full Events list — see EventCard's cancelled
/// badge — but is never the thing Explore leads with). Sorts by
/// [Event.startAt] ascending internally rather than trusting the caller's
/// ordering, so this function's output is deterministic regardless of what
/// order [events] arrives in. Returns null when there is nothing upcoming
/// to feature — callers must render no "What's On" section at all in that
/// case, never an empty/fake card.
Event? selectFeaturedEvent(List<Event> events) {
  final upcoming = events.where((e) => !e.isCancelled).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  return upcoming.isEmpty ? null : upcoming.first;
}
