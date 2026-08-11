import '../../../models/event.dart';
import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';

/// Explore's Search-mode result set — three independently-fetched, already
/// filtered lists, kept as their own typed collections rather than forced
/// into one flat combined/sorted list. This is what makes the "grouped
/// sections, not one alphabetically interleaved list" presentation (a
/// RESTAURANTS section, then HOTELS, then EVENTS) trivial to render: the
/// grouping already exists at the data level, nothing needs re-splitting
/// by type at render time.
class ExploreSearchResults {
  final List<Restaurant> restaurants;
  final List<Hotel> hotels;
  final List<Event> events;

  const ExploreSearchResults({
    required this.restaurants,
    required this.hotels,
    required this.events,
  });

  static const empty = ExploreSearchResults(
    restaurants: [],
    hotels: [],
    events: [],
  );

  bool get isEmpty => restaurants.isEmpty && hotels.isEmpty && events.isEmpty;

  int get totalCount => restaurants.length + hotels.length + events.length;
}
