import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/event_time.dart' show eventHasEnded;
import '../../models/event.dart';
import '../../models/event_chronology.dart';
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

/// Events V2 Step 8B — filters a raw list of Events down to the ones that
/// belong in a reverse-host "EVENTS" section on a Restaurant/Hotel/
/// Private Chef Detail page: not cancelled, and not yet ended per the
/// same precision-aware [eventHasEnded] every other lifecycle decision in
/// this app already uses (exact instant when known, else the local-day-
/// end of [Event.endDate] in [Event.timezone]) — never a raw `end_at >
/// now` comparison, which would incorrectly exclude a date-only Event
/// whose `end_at` is null by design. An Event that has started but not
/// yet ended is included (`!eventHasEnded` alone already covers
/// "upcoming or currently active" — there is no separate "has started"
/// check to make). Sorted via the canonical [compareEventChronology] —
/// never a second comparator. Extracted as a standalone pure function,
/// matching [eventBrowseWindowBounds]'s own precedent, so this filter/
/// sort logic is unit-testable without a live SupabaseClient.
List<Event> upcomingHostedEvents(List<Event> events, {DateTime? now}) {
  final effectiveNow = now ?? DateTime.now();
  final filtered = events.where((event) {
    if (event.isCancelled) return false;
    return !eventHasEnded(
      endAt: event.endAt,
      endDate: event.endDate,
      timezone: event.timezone,
      now: effectiveNow,
    );
  }).toList();
  filtered.sort(compareEventChronology);
  return filtered;
}

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
  ///
  /// Events V2 Discovery Taxonomy Phase B: [eventTypes]/[countryCodes] are
  /// additional, independent, ANDed-with-everything-else server-side
  /// predicates (OR within each — `.inFilter`), layered on top of the
  /// same query rather than a separate one, so Type/Country filtering
  /// never requires fetching the full unfiltered catalogue first (Phase B
  /// §11's own "no fetching all production Events when strong server-side
  /// predicates can narrow them first" requirement). [countryCodes] is
  /// deliberately a second, independent parameter from the pre-existing
  /// single [countryCode] — the original single-selection call site
  /// (`EventsScreen`'s own `CountryFilterControl`) is untouched by this
  /// addition; a future multi-select control would pass [countryCodes]
  /// instead, never both at once in practice, though nothing prevents it
  /// (both are simply ANDed if a caller genuinely did).
  Future<List<Event>> loadEvents({
    DateTime? from,
    DateTime? to,
    String? countryCode,
    Set<String>? countryCodes,
    Set<EventType>? eventTypes,
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
    if (countryCodes != null && countryCodes.isNotEmpty) {
      builder = builder.inFilter('country_code', countryCodes.toList());
    }
    if (eventTypes != null && eventTypes.isNotEmpty) {
      builder = builder.inFilter('event_type', [
        for (final type in eventTypes) type.dbValue,
      ]);
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

  /// EVENT WISHLIST V1 — one batched lookup for a set of Event ids
  /// (e.g. WishlistRepository.getWishlistEvents resolving saved-event
  /// ids), never one query per id. No status/lifecycle filtering here —
  /// unlike [_loadHostedEvents]/[upcomingHostedEvents], the caller may
  /// deliberately want past or cancelled Events too (a Wishlist is user
  /// intent/history, not a live discovery feed). [eventIds] that no
  /// longer resolve (an Event later unpublished/archived/deleted) are
  /// simply absent from the result — never an error, never a crash — so
  /// callers resolving a wishlist can skip whatever isn't returned.
  Future<List<Event>> loadEventsByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return const [];
    final rows = await _client.from('events').select().inFilter('id', eventIds);
    return [
      for (final row in rows as List)
        Event.fromJson(row as Map<String, dynamic>),
    ];
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

  /// Events V2 Step 8B — the reverse direction of [loadLinkedVenues]:
  /// Events [restaurantId] genuinely HOSTS (`is_host = true` on
  /// `event_restaurants`), not merely a physical venue for
  /// (`is_venue`-only) or a culinary participant in (`is_host = false,
  /// is_venue = false`) — see the Step 8B architecture audit's own Host
  /// Semantics section for why that distinction is non-negotiable. No
  /// `moderation_status` filter is applied here explicitly — it doesn't
  /// need to be: `event_restaurants` itself has no moderation column and
  /// its own RLS is unconditionally public, but the second query below
  /// reads `events` directly, whose RLS (`moderation_status =
  /// 'published'`) is enforced automatically, so a relationship row
  /// pointing at a draft/rejected/archived Event simply yields no
  /// corresponding row here — the exact same RLS composition
  /// [loadLinkedVenues] already relies on for the forward direction.
  /// Upcoming/active only, chronologically sorted — see
  /// [upcomingHostedEvents].
  Future<List<Event>> loadHostedEventsForRestaurant(
    String restaurantId, {
    DateTime? now,
  }) => _loadHostedEvents(
    table: 'event_restaurants',
    entityColumn: 'restaurant_id',
    entityId: restaurantId,
    now: now,
  );

  /// Events V2 Step 8B — the Hotel equivalent of
  /// [loadHostedEventsForRestaurant]. Production currently has zero
  /// `event_hotels` rows of any kind (host, venue, or participant) — this
  /// method is exercised by repository-shape reasoning and fixture/widget
  /// tests today, not yet by a real production Hotel host.
  Future<List<Event>> loadHostedEventsForHotel(
    String hotelId, {
    DateTime? now,
  }) => _loadHostedEvents(
    table: 'event_hotels',
    entityColumn: 'hotel_id',
    entityId: hotelId,
    now: now,
  );

  /// Events V2 Step 8B — the Private Chef equivalent of
  /// [loadHostedEventsForRestaurant]. Production currently has zero
  /// `event_chefs` rows — same caveat as [loadHostedEventsForHotel].
  Future<List<Event>> loadHostedEventsForChef(String chefId, {DateTime? now}) =>
      _loadHostedEvents(
        table: 'event_chefs',
        entityColumn: 'chef_id',
        entityId: chefId,
        now: now,
      );

  // Shared shape behind all three loadHostedEventsFor* methods — exactly
  // 2 queries (the relationship-id fetch, then one batched Event fetch),
  // mirroring loadLinkedVenues' own established two-query pattern,
  // reversed. No N+1 regardless of how many Events an entity hosts.
  Future<List<Event>> _loadHostedEvents({
    required String table,
    required String entityColumn,
    required String entityId,
    DateTime? now,
  }) async {
    final relRows = await _client
        .from(table)
        .select('event_id')
        .eq(entityColumn, entityId)
        .eq('is_host', true);
    final eventIds = [
      for (final row in relRows as List) row['event_id'] as String,
    ];
    if (eventIds.isEmpty) return const [];
    final rows = await _client.from('events').select().inFilter('id', eventIds);
    final events = [
      for (final row in rows as List)
        Event.fromJson(row as Map<String, dynamic>),
    ];
    return upcomingHostedEvents(events, now: now);
  }
}
