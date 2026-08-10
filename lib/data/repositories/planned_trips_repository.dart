import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/planned_venue.dart';
import '../../models/resolved_planned_venue.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'hotel_repository.dart' show hotelFullColumns;
import 'restaurant_repository.dart' show restaurantFullColumns;

/// CRUD for `public.planned_trips` / `public.planned_venues` (see
/// supabase/migrations/20260810120000_create_planned_trips.sql — additive,
/// not yet applied). RLS restricts every row to its own `user_id`, so every
/// method here is scoped to the calling [userId] regardless.
class PlannedTripsRepository {
  PlannedTripsRepository(this._client);

  final SupabaseClient _client;

  // ── Trips ────────────────────────────────────────────────────────────

  Future<List<PlannedTrip>> loadTrips(String userId) async {
    final rows = await _client
        .from('planned_trips')
        .select()
        .eq('user_id', userId)
        .order('start_date', ascending: true);
    return [
      for (final row in rows as List)
        PlannedTrip.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<PlannedTrip> createTrip({
    required String userId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required String countryCode,
    String? city,
    String? notes,
  }) async {
    final row = await _client
        .from('planned_trips')
        .insert({
          'user_id': userId,
          'title': title,
          'start_date': _dateOnly(startDate),
          'end_date': _dateOnly(endDate),
          'country_code': countryCode,
          'city': city,
          'notes': notes,
        })
        .select()
        .single();
    return PlannedTrip.fromJson(row);
  }

  Future<PlannedTrip> updateTrip({
    required String userId,
    required String tripId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required String countryCode,
    String? city,
    String? notes,
  }) async {
    final row = await _client
        .from('planned_trips')
        .update({
          'title': title,
          'start_date': _dateOnly(startDate),
          'end_date': _dateOnly(endDate),
          'country_code': countryCode,
          'city': city,
          'notes': notes,
        })
        .eq('id', tripId)
        .eq('user_id', userId)
        .select()
        .single();
    return PlannedTrip.fromJson(row);
  }

  // Planned venues attached to this trip are detached (trip_id -> null) by
  // the column's own ON DELETE SET NULL, never deleted — see the migration.
  Future<void> deleteTrip({
    required String userId,
    required String tripId,
  }) async {
    await _client
        .from('planned_trips')
        .delete()
        .eq('id', tripId)
        .eq('user_id', userId);
  }

  // Every country in the reference table, not just ones present in the
  // restaurant/hotel catalogue — a trip can go anywhere, unlike Explore's
  // country filter (see resolveVenueCountries), which only ever needs
  // catalogue-present countries.
  Future<List<VenueCountry>> loadAllCountries() async {
    final rows = await _client
        .from('countries')
        .select('country_code, name, flag_emoji')
        .order('name');
    return [
      for (final row in rows as List)
        VenueCountry(
          name: (row['name'] as String?) ?? '',
          code: (row['country_code'] as String?) ?? '',
          flag: (row['flag_emoji'] as String?) ?? '',
        ),
    ];
  }

  // ── Planned venues ───────────────────────────────────────────────────

  Future<List<PlannedVenue>> loadPlannedVenues(String userId) async {
    final rows = await _client
        .from('planned_venues')
        .select()
        .eq('user_id', userId)
        .order('start_date', ascending: true);
    return [
      for (final row in rows as List)
        PlannedVenue.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<List<PlannedVenue>> loadPlannedVenuesForTrip({
    required String userId,
    required String tripId,
  }) async {
    final rows = await _client
        .from('planned_venues')
        .select()
        .eq('user_id', userId)
        .eq('trip_id', tripId)
        .order('start_date', ascending: true);
    return [
      for (final row in rows as List)
        PlannedVenue.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<PlannedVenue> createPlannedVenue({
    required String userId,
    required String entityType,
    required String entityId,
    String? tripId,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    final row = await _client
        .from('planned_venues')
        .insert({
          'user_id': userId,
          'entity_type': entityType,
          'entity_id': entityId,
          'trip_id': tripId,
          'start_date': _dateOnly(startDate),
          'end_date': endDate == null ? null : _dateOnly(endDate),
          'notes': notes,
        })
        .select()
        .single();
    return PlannedVenue.fromJson(row);
  }

  Future<PlannedVenue> updatePlannedVenue({
    required String userId,
    required String plannedVenueId,
    String? tripId,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
    required PlannedVenueStatus status,
  }) async {
    final row = await _client
        .from('planned_venues')
        .update({
          'trip_id': tripId,
          'start_date': _dateOnly(startDate),
          'end_date': endDate == null ? null : _dateOnly(endDate),
          'notes': notes,
          'status': status.dbValue,
        })
        .eq('id', plannedVenueId)
        .eq('user_id', userId)
        .select()
        .single();
    return PlannedVenue.fromJson(row);
  }

  Future<void> deletePlannedVenue({
    required String userId,
    required String plannedVenueId,
  }) async {
    await _client
        .from('planned_venues')
        .delete()
        .eq('id', plannedVenueId)
        .eq('user_id', userId);
  }

  // Every planned venue, resolved against restaurants_full/hotels_full so
  // My Planned Trips can render a name/city rather than just a bare
  // entity_id. Three queries total (the planned_venues rows, one batched
  // restaurant lookup, one batched hotel lookup), never one query per
  // planned venue — same shape as VisitedRepository.loadPassportVenues.
  Future<List<ResolvedPlannedVenue>> loadResolvedPlannedVenues(
    String userId,
  ) async {
    final plans = await loadPlannedVenues(userId);
    if (plans.isEmpty) return [];

    final restaurantIds = [
      for (final p in plans)
        if (p.isRestaurant) p.entityId,
    ];
    final hotelIds = [
      for (final p in plans)
        if (p.isHotel) p.entityId,
    ];

    final restaurantsFuture = restaurantIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : _client
              .from('restaurants_full')
              .select(restaurantFullColumns)
              .inFilter('id', restaurantIds)
              .then((r) => (r as List).cast<Map<String, dynamic>>());
    final hotelsFuture = hotelIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : _client
              .from('hotels_full')
              .select(hotelFullColumns)
              .inFilter('id', hotelIds)
              .then((r) => (r as List).cast<Map<String, dynamic>>());

    final restaurantRows = await restaurantsFuture;
    final hotelRows = await hotelsFuture;

    final restaurantsById = {
      for (final row in restaurantRows)
        (row['id'] as String): Restaurant.fromJson(row),
    };
    final hotelsById = {
      for (final row in hotelRows) (row['id'] as String): Hotel.fromJson(row),
    };

    final resolved = <ResolvedPlannedVenue>[];
    for (final plan in plans) {
      PassportVenue? venue;
      if (plan.isRestaurant) {
        final restaurant = restaurantsById[plan.entityId];
        if (restaurant != null) venue = RestaurantVenue(restaurant);
      } else if (plan.isHotel) {
        final hotel = hotelsById[plan.entityId];
        if (hotel != null) venue = HotelVenue(hotel);
      }
      if (venue != null) {
        resolved.add(ResolvedPlannedVenue(plan: plan, venue: venue));
      }
    }
    return resolved;
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
