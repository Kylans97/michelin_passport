import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/journey.dart';

// Every column of public.journeys_full, listed explicitly so a schema change
// is a visible diff here (the convention VisitedRepository and
// EventConfirmedAttendanceRepository already follow).
const journeyFullColumns =
    'id, journey_code, slug, kind, ship_type, name, status, '
    'first_departure_on, summary, cabins_text, guest_capacity, dining_text, '
    'official_url, primary_country_code, regions_text, country_name, '
    'flag_emoji, operator_code, operator_name, operator_website_url, '
    'route_count, route_country_codes';

const _routeColumns =
    'id, route_code, name, from_place, from_country_code, to_place, nights, '
    'duration_text, '
    'season_text, departure_pattern_text';

const _travelColumns =
    'id, journey_id, route_id, departed_on, arrived_on, rating, comment, '
    'visibility';

/// One confirmed travel plus the journey (and, when the member chose one,
/// the route) it was on — what a Passport journey stamp needs. Kept as a
/// plain triple beside [EventAttendanceEntry], not folded into the sealed
/// PassportVenue type, for the same reason events were not: it would force
/// every exhaustive switch over that type to grow a case.
class JourneyTravelEntry {
  final JourneyTravel travel;
  final Journey journey;
  final JourneyRoute? route;

  const JourneyTravelEntry({
    required this.travel,
    required this.journey,
    this.route,
  });
}

/// Trains first, then ships; each alphabetical. The calm default order for
/// the Trains & Ships collection — no ranking signal exists yet.
List<Journey> sortJourneysForCollection(List<Journey> journeys) {
  final sorted = List<Journey>.from(journeys);
  sorted.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

/// The journeys of [kind], or all of them when [kind] is null.
List<Journey> journeysOfKind(List<Journey> journeys, JourneyKind? kind) => [
  for (final journey in journeys)
    if (kind == null || journey.kind == kind) journey,
];

class JourneyRepository {
  JourneyRepository(this._client);

  final SupabaseClient _client;

  /// Every published journey. journeys_full already filters on
  /// publication_status, and RLS hides drafts from every client anyway.
  Future<List<Journey>> getPublishedJourneys() async {
    final rows = await _client.from('journeys_full').select(journeyFullColumns);
    return sortJourneysForCollection([
      for (final row in rows as List) Journey.fromMap(row),
    ]);
  }

  Future<Journey?> getById(String id) async {
    final row = await _client
        .from('journeys_full')
        .select(journeyFullColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Journey.fromMap(row);
  }

  /// One batched lookup, in the order of [ids]; ids that no longer resolve
  /// (unpublished) simply drop out.
  Future<List<Journey>> loadJourneysByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('journeys_full')
        .select(journeyFullColumns)
        .inFilter('id', ids);
    final byId = {
      for (final row in rows as List) row['id'] as String: Journey.fromMap(row),
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<JourneyRoute>> getRoutes(String journeyId) async {
    final rows = await _client
        .from('journey_routes')
        .select(_routeColumns)
        .eq('journey_id', journeyId)
        .order('display_order');
    return [for (final row in rows as List) JourneyRoute.fromMap(row)];
  }

  /// Catalogue restaurants linked as dining partners — id and name only;
  /// the detail screen loads the full restaurant when one is tapped.
  Future<List<({String id, String name})>> getDiningPartners(
    String journeyId,
  ) async {
    final rows = await _client
        .from('journey_restaurants')
        .select('restaurant_id, restaurants(name)')
        .eq('journey_id', journeyId);
    return [
      for (final row in rows as List)
        if (row['restaurants'] != null)
          (
            id: row['restaurant_id'] as String,
            name: (row['restaurants'] as Map)['name'] as String,
          ),
    ];
  }

  // ── Confirmed travel (Passport) ────────────────────────────────────────

  /// Records that the signed-in member travelled. The only path to a
  /// journey stamp; RLS refuses a row for anyone else or a draft journey.
  Future<JourneyTravel> confirmTravel({
    required String userId,
    required String journeyId,
    required DateTime departedOn,
    String? routeId,
    DateTime? arrivedOn,
    JourneyTravelVisibility visibility = JourneyTravelVisibility.private,
  }) async {
    final row = await _client
        .from('journey_travels')
        .insert(
          buildJourneyTravelInsert(
            userId: userId,
            journeyId: journeyId,
            departedOn: departedOn,
            routeId: routeId,
            arrivedOn: arrivedOn,
            visibility: visibility,
          ),
        )
        .select(_travelColumns)
        .single();
    return JourneyTravel.fromMap(row);
  }

  Future<void> deleteTravel(String travelId) =>
      _client.from('journey_travels').delete().eq('id', travelId);

  Future<List<JourneyTravel>> getMyTravels({
    required String userId,
    required String journeyId,
  }) async {
    final rows = await _client
        .from('journey_travels')
        .select(_travelColumns)
        .eq('user_id', userId)
        .eq('journey_id', journeyId)
        .order('departed_on', ascending: false);
    return [for (final row in rows as List) JourneyTravel.fromMap(row)];
  }

  /// Every confirmed travel of [userId] with its journey and route, for the
  /// Passport. Three queries in total, never one per travel.
  Future<List<JourneyTravelEntry>> loadPassportJourneyTravels(
    String userId,
  ) async {
    if (userId.isEmpty) return [];
    final rows = await _client
        .from('journey_travels')
        .select(_travelColumns)
        .eq('user_id', userId)
        .order('departed_on', ascending: false);
    final travels = [
      for (final row in rows as List) JourneyTravel.fromMap(row),
    ];
    if (travels.isEmpty) return [];

    final journeys = await loadJourneysByIds(
      travels.map((t) => t.journeyId).toSet().toList(),
    );
    final journeyById = {for (final j in journeys) j.id: j};

    final routeIds = {
      for (final t in travels)
        if (t.routeId != null) t.routeId!,
    }.toList();
    final routeById = <String, JourneyRoute>{};
    if (routeIds.isNotEmpty) {
      final routeRows = await _client
          .from('journey_routes')
          .select(_routeColumns)
          .inFilter('id', routeIds);
      for (final row in routeRows as List) {
        final route = JourneyRoute.fromMap(row);
        routeById[route.id] = route;
      }
    }

    return [
      for (final travel in travels)
        if (journeyById[travel.journeyId] != null)
          JourneyTravelEntry(
            travel: travel,
            journey: journeyById[travel.journeyId]!,
            route: travel.routeId == null ? null : routeById[travel.routeId],
          ),
    ];
  }
}

/// The insert map for a confirmed travel — pure, so its shape is
/// unit-testable without a Supabase client.
Map<String, dynamic> buildJourneyTravelInsert({
  required String userId,
  required String journeyId,
  required DateTime departedOn,
  String? routeId,
  DateTime? arrivedOn,
  JourneyTravelVisibility visibility = JourneyTravelVisibility.private,
}) => {
  'user_id': userId,
  'journey_id': journeyId,
  'route_id': ?routeId,
  'departed_on': _isoDate(departedOn),
  if (arrivedOn != null) 'arrived_on': _isoDate(arrivedOn),
  'visibility': visibility.dbValue,
  'source': 'manual',
};

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
