import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'hotel_repository.dart' show hotelFullColumns;
import 'restaurant_repository.dart' show restaurantFullColumns;
import 'search_query.dart';

/// The conservative, one-calendar-day-widened `end_date`/`start_date` SQL
/// bounds [EventsRepository.loadEvents] applies for a given browse
/// window — extracted as a standalone pure function specifically so this
/// exact date arithmetic can be unit-tested without a live SupabaseClient
/// (see [EventsRepository.loadEvents]'s own doc comment for why the
/// widening exists, and
/// event_confirmed_attendance_repository_test.dart's identical "extract
/// the pure part, prove the network call separately against local
/// Postgres" precedent — the network call itself is proven in
/// docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_C_PRE_APPLY.md's
/// Local Date-Only Insert / Start-Known End-Unknown Insert sections).
({String? gteEndDate, String? lteStartDate}) eventBrowseWindowBounds({
  DateTime? from,
  DateTime? to,
}) {
  return (
    gteEndDate: from == null
        ? null
        : _dateOnly(from.subtract(const Duration(days: 1))),
    lteStartDate: to == null
        ? null
        : _dateOnly(to.add(const Duration(days: 1))),
  );
}

// 'YYYY-MM-DD' — matches the date column's own text form (and
// PlannedTripsRepository's identical convention for the same reason): no
// time-of-day, no timezone conversion, since `date` columns compare as
// calendar dates regardless of session timezone.
String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

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
  /// narrowed to one country and/or a free-text [query]. [query] and
  /// [countryCode] are independent, ANDed constraints — a city search must
  /// work with no country picked at all (see RestaurantRepository.search()/
  /// HotelRepository.search(), which follow the same independent-filter
  /// shape). Chronological, soonest first. Cancelled events ARE included
  /// (see EventCard for how they're marked) — hiding them outright would
  /// make "why did this event disappear" a mystery; only trip-matching
  /// (eventMatchesTrip) excludes them outright.
  ///
  /// Events V2 Time Precision Phase C: filters and orders on
  /// [start_date]/[end_date] — each event's OWN local calendar date — never
  /// on start_at/end_at, which are nullable from Phase C onward (a
  /// date-only or start-known/end-unknown event has no exact instant to
  /// compare). [from]/[to] arrive as device-local DateTimes (see
  /// EventDateFilter.resolve()); comparing a device-local calendar day
  /// directly against another event's own IANA-zone calendar day is exactly
  /// the trap this repository must not fall into — a person a day away by
  /// timezone must never see a legitimate event silently vanish near a
  /// midnight boundary. So the SQL window is widened by one calendar day on
  /// each open end before being sent as the filter: since any two IANA
  /// zones differ by at most ~26 hours, "today" can disagree by at most one
  /// calendar day between the viewer's device and an event's own zone, and
  /// widening by exactly one day on each side is therefore always enough to
  /// avoid excluding a legitimate boundary event. This trades a rare extra
  /// edge-of-window event for never hiding one — see
  /// docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_C_PRE_APPLY.md's
  /// International Date-Boundary Strategy section for the full reasoning.
  /// No further "exact" trim runs afterward in Dart — once timezones
  /// differ, there is no single correct answer, only "never silently hide."
  Future<List<Event>> loadEvents({
    DateTime? from,
    DateTime? to,
    String? countryCode,
    String query = '',
  }) async {
    var builder = _client.from('events').select();
    // name/city/venue_name — the textual fields a person would actually
    // type. No country_name here: events only stores country_code (no
    // denormalized name column, unlike restaurants_full/hotels_full), so a
    // country is matched via the separate country chip, not text.
    final orFilter = buildIlikeOrFilter(query, ['name', 'city', 'venue_name']);
    if (orFilter != null) {
      builder = builder.or(orFilter);
    }
    final bounds = eventBrowseWindowBounds(from: from, to: to);
    if (bounds.gteEndDate != null) {
      builder = builder.gte('end_date', bounds.gteEndDate!);
    }
    if (bounds.lteStartDate != null) {
      builder = builder.lte('start_date', bounds.lteStartDate!);
    }
    if (countryCode != null) {
      builder = builder.eq('country_code', countryCode);
    }
    final rows = await builder.order('start_date', ascending: true);
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
  /// of sync. Ordered on start_date (Phase C — never start_at, nullable
  /// from Phase C onward).
  Future<List<Event>> loadEventsForCountry(String countryCode) async {
    final rows = await _client
        .from('events')
        .select()
        .eq('country_code', countryCode)
        .order('start_date', ascending: true);
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
