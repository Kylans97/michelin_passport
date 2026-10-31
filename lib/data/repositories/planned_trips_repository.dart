import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/planned_venue.dart';
import '../../models/resolved_planned_venue.dart';
import '../../models/restaurant.dart';
import '../../models/trip_destination.dart';
import '../../models/trip_member.dart';
import '../../models/venue_country.dart';
import 'hotel_repository.dart' show hotelFullColumns;
import 'restaurant_repository.dart' show restaurantFullColumns;
import 'member_avatar_repository.dart';

/// The current user's trips (own + shared with them and accepted) and the
/// invitations they haven't answered yet.
typedef TripsOverview = ({
  List<PlannedTrip> trips,
  List<TripInvitation> invitations,
});

/// CRUD for `public.planned_trips` / `public.planned_venues` (see
/// supabase/migrations/20260810120000_create_planned_trips.sql), plus
/// destinations and members (20261022120000).
///
/// Works on either side of 20261022120000: when the server doesn't have
/// planned_trip_destinations/planned_trip_members yet (PostgREST's "table
/// not found"), reads fall back to the original owner-only trips with no
/// loaded destinations and [sharedTripsAvailable] turns false, so the
/// screens hide multiple destinations and invitations rather than fail.
class PlannedTripsRepository {
  PlannedTripsRepository(this._client);

  final SupabaseClient _client;

  /// False once a read has shown the server predates 20261022120000.
  bool sharedTripsAvailable = true;

  static bool _isMissingSchema(PostgrestException e) =>
      // Table/view not in the schema cache, function not found, or the
      // Postgres "undefined table" itself.
      e.code == 'PGRST205' || e.code == 'PGRST202' || e.code == '42P01';

  // ── Trips ────────────────────────────────────────────────────────────

  Future<List<PlannedTrip>> loadTrips(String userId) async =>
      (await loadTripsOverview(userId)).trips;

  Future<TripsOverview> loadTripsOverview(String userId) async {
    if (sharedTripsAvailable) {
      try {
        return await _loadSharedOverview(userId);
      } on PostgrestException catch (e) {
        if (!_isMissingSchema(e)) rethrow;
        sharedTripsAvailable = false;
      }
    }
    final rows = await _client
        .from('planned_trips')
        .select()
        .eq('user_id', userId)
        .order('start_date', ascending: true);
    return (
      trips: [
        for (final row in rows as List)
          PlannedTrip.fromJson(row as Map<String, dynamic>),
      ],
      invitations: const <TripInvitation>[],
    );
  }

  Future<TripsOverview> _loadSharedOverview(String userId) async {
    final memberRows = await _client
        .from('planned_trip_members')
        .select('id, trip_id, status, invited_by')
        .eq('user_id', userId);
    final myStatus = <String, Map<String, dynamic>>{
      for (final row in memberRows as List)
        (row['trip_id'] as String): row as Map<String, dynamic>,
    };

    // No user filter: RLS returns the caller's own trips plus every trip
    // they're on or invited to (planned_trips_select / can_view_trip).
    final tripRows = await _client
        .from('planned_trips')
        .select()
        .order('start_date', ascending: true);
    final all = [
      for (final row in tripRows as List)
        PlannedTrip.fromJson(row as Map<String, dynamic>),
    ];
    final legsByTrip = await _loadDestinations([for (final t in all) t.id]);

    final trips = <PlannedTrip>[];
    final invitations = <TripInvitation>[];
    for (final trip in all) {
      final withLegs = trip.withDestinations(legsByTrip[trip.id] ?? const []);
      final membership = myStatus[trip.id];
      if (trip.userId == userId || membership?['status'] == 'accepted') {
        trips.add(withLegs);
      } else if (membership?['status'] == 'pending') {
        invitations.add(
          TripInvitation(
            memberId: membership!['id'] as String,
            tripId: trip.id,
            tripTitle: trip.title,
            startDate: trip.startDate,
            endDate: trip.endDate,
            inviterLabel: await _inviterLabel(
              trip.id,
              membership['invited_by'] as String?,
            ),
          ),
        );
      }
    }
    return (trips: trips, invitations: invitations);
  }

  Future<String?> _inviterLabel(String tripId, String? inviterId) async {
    if (inviterId == null) return null;
    try {
      final members = await loadTripMembers(tripId);
      for (final m in members) {
        if (m.userId == inviterId) return m.label;
      }
    } catch (_) {
      // Display only — an invitation without a name still shows.
    }
    return null;
  }

  Future<Map<String, List<TripDestination>>> _loadDestinations(
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) return {};
    final rows = await _client
        .from('planned_trip_destinations')
        .select(
          'trip_id, position, country_code, city_id, start_date, end_date, '
          'cities(name)',
        )
        .inFilter('trip_id', tripIds)
        .order('position', ascending: true);
    final result = <String, List<TripDestination>>{};
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      result
          .putIfAbsent(map['trip_id'] as String, () => [])
          .add(TripDestination.fromJson(map));
    }
    return result;
  }

  /// One trip with its legs, for refreshing Trip Detail after an edit.
  Future<PlannedTrip?> loadTrip(String tripId) async {
    final row = await _client
        .from('planned_trips')
        .select()
        .eq('id', tripId)
        .maybeSingle();
    if (row == null) return null;
    final trip = PlannedTrip.fromJson(row);
    if (!sharedTripsAvailable) return trip;
    try {
      final legs = await _loadDestinations([tripId]);
      return trip.withDestinations(legs[tripId] ?? const []);
    } on PostgrestException catch (e) {
      if (!_isMissingSchema(e)) rethrow;
      sharedTripsAvailable = false;
      return trip;
    }
  }

  /// Replaces a trip's dates and every destination in one atomic call
  /// (save_trip_destinations — owner only; legs need dates once there's
  /// more than one, and must sit inside the trip's dates). It also keeps
  /// planned_trips.country_code/city equal to the first destination.
  Future<void> saveTripDestinations({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required List<TripDestination> destinations,
  }) async {
    await _client.rpc(
      'save_trip_destinations',
      params: {
        'p_trip_id': tripId,
        'p_start_date': _dateOnly(startDate),
        'p_end_date': _dateOnly(endDate),
        'p_destinations': [for (final d in destinations) d.toRpcJson()],
      },
    );
  }

  /// Title and notes only — dates and destinations go through
  /// [saveTripDestinations] when the server has it.
  Future<void> updateTripDetails({
    required String userId,
    required String tripId,
    required String title,
    String? notes,
  }) async {
    await _client
        .from('planned_trips')
        .update({'title': title, 'notes': notes})
        .eq('id', tripId)
        .eq('user_id', userId);
  }

  /// The catalogue's cities in one country, for choosing a destination
  /// city by id. Keyed on the country code, never a name.
  Future<List<({String id, String name, String? region})>> loadCities(
    String countryCode,
  ) async {
    final rows = await _client
        .from('cities')
        .select('id, name, region')
        .eq('country_code', countryCode)
        .order('name', ascending: true);
    return [
      for (final row in rows as List)
        (
          id: row['id'] as String,
          name: (row['name'] as String?) ?? '',
          region: row['region'] as String?,
        ),
    ];
  }

  // ── Members ──────────────────────────────────────────────────────────

  Future<List<TripMember>> loadTripMembers(String tripId) async {
    final rows = await _client.rpc(
      'get_trip_members',
      params: {'p_trip_id': tripId},
    );
    final list = (rows as List).cast<Map<String, dynamic>>();
    // Photos follow the identity rule (MemberAvatarRepository): a
    // co-member who is neither a friend nor discoverable keeps initials.
    final urls = await MemberAvatarRepository(
      _client,
    ).urlsFor([for (final r in list) r['user_id'] as String]);
    return [
      for (final row in list)
        TripMember.fromRow({
          ...row,
          if (urls[row['user_id']] case final String url) 'avatar_url': url,
        }),
    ];
  }

  Future<void> inviteToTrip({
    required String tripId,
    required String friendId,
  }) async {
    await _client.rpc(
      'invite_to_trip',
      params: {'p_trip_id': tripId, 'p_friend_id': friendId},
    );
  }

  Future<void> respondToTripInvite({
    required String memberId,
    required bool accept,
  }) async {
    await _client.rpc(
      'respond_to_trip_invite',
      params: {'p_member_id': memberId, 'p_accept': accept},
    );
  }

  Future<void> leaveTrip(String tripId) async {
    await _client.rpc('leave_trip', params: {'p_trip_id': tripId});
  }

  Future<void> removeTripMember(String memberId) async {
    await _client.rpc('remove_trip_member', params: {'p_member_id': memberId});
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
        // `ascending` must be explicit: postgrest-dart's .order() defaults
        // to descending, which listed countries Z→A (Vietnam first).
        .order('name', ascending: true);
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

  /// Every plan on these trips, including other members' plans on a shared
  /// trip (planned_venues_select lets members read them) — unlike
  /// [loadResolvedPlannedVenues], which is the caller's own plans only.
  Future<List<ResolvedPlannedVenue>> loadResolvedPlannedVenuesForTrips(
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) return [];
    final rows = await _client
        .from('planned_venues')
        .select()
        .inFilter('trip_id', tripIds)
        .order('start_date', ascending: true);
    return _resolve([
      for (final row in rows as List)
        PlannedVenue.fromJson(row as Map<String, dynamic>),
    ]);
  }

  // Every planned venue, resolved against restaurants_full/hotels_full so
  // My Planned Trips can render a name/city rather than just a bare
  // entity_id. Three queries total (the planned_venues rows, one batched
  // restaurant lookup, one batched hotel lookup), never one query per
  // planned venue — same shape as VisitedRepository.loadPassportVenues.
  Future<List<ResolvedPlannedVenue>> loadResolvedPlannedVenues(
    String userId,
  ) async {
    return _resolve(await loadPlannedVenues(userId));
  }

  Future<List<ResolvedPlannedVenue>> _resolve(List<PlannedVenue> plans) async {
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
