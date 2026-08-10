import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'hotel_repository.dart' show hotelFullColumns;
import 'restaurant_repository.dart' show restaurantFullColumns;

/// A single event's linked venues, resolved for Event Detail. Either list
/// may be empty — an event is never required to link to any venue.
class EventVenues {
  final List<Restaurant> restaurants;
  final List<Hotel> hotels;
  const EventVenues({required this.restaurants, required this.hotels});

  bool get isEmpty => restaurants.isEmpty && hotels.isEmpty;
}

/// Reads `public.events`/`event_restaurants`/`event_hotels` (see
/// supabase/migrations/20260810160000_create_events.sql — additive, not
/// yet applied). Public catalogue-style data: no write methods here, same
/// as RestaurantRepository/HotelRepository — events are seeded/maintained
/// server-side, never authored by app users in this slice.
class EventsRepository {
  EventsRepository(this._client);

  final SupabaseClient _client;

  /// Events overlapping [from, to] (inclusive-ish — an event that started
  /// before [from] but is still running is still included), optionally
  /// narrowed to one country. Chronological, soonest first. Cancelled
  /// events ARE included (see EventCard for how they're marked) — hiding
  /// them outright would make "why did this event disappear" a mystery;
  /// only trip-matching (eventMatchesTrip) excludes them outright.
  Future<List<Event>> loadEvents({
    DateTime? from,
    DateTime? to,
    String? countryCode,
  }) async {
    var builder = _client.from('events').select();
    if (from != null) {
      builder = builder.gte('end_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      builder = builder.lte('start_at', to.toUtc().toIso8601String());
    }
    if (countryCode != null) {
      builder = builder.eq('country_code', countryCode);
    }
    final rows = await builder.order('start_at', ascending: true);
    return [
      for (final row in rows as List)
        Event.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Every event in [countryCode], regardless of date — the source list
  /// TripDetailScreen filters client-side via eventsMatchingTrip. Not
  /// date-bounded here: a trip's own start/end dates already do that
  /// filtering inside the pure matching function, and re-deriving the same
  /// window twice (once in SQL, once in Dart) risks the two drifting out
  /// of sync.
  Future<List<Event>> loadEventsForCountry(String countryCode) async {
    final rows = await _client
        .from('events')
        .select()
        .eq('country_code', countryCode)
        .order('start_at', ascending: true);
    return [
      for (final row in rows as List)
        Event.fromJson(row as Map<String, dynamic>),
    ];
  }

  // Countries that have at least one event, for the filter — mirrors
  // RestaurantRepository.getCountries()/HotelRepository.getCountries(),
  // sharing the same countries-join helper.
  Future<List<VenueCountry>> getCountries() async {
    final rows = await _client.from('events').select('country_code');
    final presentCodes = <String>{
      for (final row in rows as List)
        if ((row['country_code'] as String?)?.isNotEmpty ?? false)
          row['country_code'] as String,
    };
    return resolveVenueCountries(_client, presentCodes);
  }

  Future<Event?> loadEventById(String eventId) async {
    final rows = await _client
        .from('events')
        .select()
        .eq('id', eventId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Event.fromJson(list.first as Map<String, dynamic>);
  }

  /// The restaurants/hotels linked to [eventId] — three queries total
  /// (join-table ids, then one batched restaurants_full lookup, one
  /// batched hotels_full lookup), never one query per linked venue.
  Future<EventVenues> loadLinkedVenues(String eventId) async {
    final restaurantLinksFuture = _client
        .from('event_restaurants')
        .select('restaurant_id')
        .eq('event_id', eventId);
    final hotelLinksFuture = _client
        .from('event_hotels')
        .select('hotel_id')
        .eq('event_id', eventId);
    final restaurantLinks = await restaurantLinksFuture;
    final hotelLinks = await hotelLinksFuture;

    final restaurantIds = [
      for (final row in restaurantLinks as List) row['restaurant_id'] as String,
    ];
    final hotelIds = [
      for (final row in hotelLinks as List) row['hotel_id'] as String,
    ];

    final restaurantsFuture = restaurantIds.isEmpty
        ? Future.value(const <Restaurant>[])
        : _client
              .from('restaurants_full')
              .select(restaurantFullColumns)
              .inFilter('id', restaurantIds)
              .then(
                (rows) => [
                  for (final row in rows as List)
                    Restaurant.fromJson(row as Map<String, dynamic>),
                ],
              );
    final hotelsFuture = hotelIds.isEmpty
        ? Future.value(const <Hotel>[])
        : _client
              .from('hotels_full')
              .select(hotelFullColumns)
              .inFilter('id', hotelIds)
              .then(
                (rows) => [
                  for (final row in rows as List)
                    Hotel.fromJson(row as Map<String, dynamic>),
                ],
              );

    return EventVenues(
      restaurants: await restaurantsFuture,
      hotels: await hotelsFuture,
    );
  }
}
