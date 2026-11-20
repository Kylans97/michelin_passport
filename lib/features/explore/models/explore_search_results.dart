import '../../../models/event.dart';
import '../../../models/hotel.dart';
import '../../../models/journey.dart';
import '../../../models/restaurant.dart';
import '../../../models/vineyard.dart';

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
  final List<Vineyard> vineyards;

  /// Trains and ships together; the Trains and Ships filters each fill it
  /// with their own kind only.
  final List<Journey> journeys;

  const ExploreSearchResults({
    required this.restaurants,
    required this.hotels,
    required this.events,
    this.vineyards = const [],
    this.journeys = const [],
  });

  static const empty = ExploreSearchResults(
    restaurants: [],
    hotels: [],
    events: [],
  );

  bool get isEmpty =>
      restaurants.isEmpty &&
      hotels.isEmpty &&
      events.isEmpty &&
      vineyards.isEmpty &&
      journeys.isEmpty;

  int get totalCount =>
      restaurants.length +
      hotels.length +
      events.length +
      vineyards.length +
      journeys.length;
}
