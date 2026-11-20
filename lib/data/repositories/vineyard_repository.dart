import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/vineyard.dart';
import '../../models/vineyard_visit.dart';

// Every column of public.vineyards_full, listed explicitly so a schema
// change is a visible diff here (the convention JourneyRepository follows).
const _visitColumns =
    'id, vineyard_id, visited_on, activities, rating, comment, visibility';

const vineyardFullColumns =
    'id, vineyard_code, name, country_code, country_name, flag_emoji, '
    'region, city, address, latitude, longitude, website_url, status, '
    'worlds_50_best_year, worlds_50_best_rank';

/// Ranked estates first, by rank; then the rest alphabetically. The calm
/// default order for the Wine Estates collection.
List<Vineyard> sortVineyardsForCollection(Iterable<Vineyard> vineyards) {
  final sorted = List<Vineyard>.from(vineyards);
  sorted.sort((a, b) {
    final ra = a.worlds50BestRank;
    final rb = b.worlds50BestRank;
    if (ra != null && rb != null) return ra.compareTo(rb);
    if (ra != null) return -1;
    if (rb != null) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

/// Wine estates (`public.vineyards_full`, 20261101550000). Catalogue data:
/// world-readable, no client write.
class VineyardRepository {
  VineyardRepository(this._client);

  final SupabaseClient _client;

  /// Every estate. The catalogue starts at fifty, so the whole list is read
  /// at once and filtered on the device (the producer suggestion too).
  Future<List<Vineyard>> getAll() async {
    final rows = await _client
        .from('vineyards_full')
        .select(vineyardFullColumns);
    return sortVineyardsForCollection([
      for (final row in rows as List) Vineyard.fromMap(row),
    ]);
  }

  /// Whether any estate is readable — false before the vineyards migration
  /// and its reviewed data are applied.
  Future<bool> hasAny() async {
    final rows = await _client.from('vineyards').select('id').limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<Vineyard?> getById(String id) async {
    final row = await _client
        .from('vineyards_full')
        .select(vineyardFullColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Vineyard.fromMap(row);
  }

  /// The estates taking part in [eventId], ranked first. RLS returns only
  /// the approved links of a published event.
  Future<List<Vineyard>> getForEvent(String eventId) async {
    final links = await _client
        .from('event_vineyards')
        .select('vineyard_id')
        .eq('event_id', eventId);
    final ids = [for (final row in links as List) row['vineyard_id'] as String];
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('vineyards_full')
        .select(vineyardFullColumns)
        .inFilter('id', ids);
    return sortVineyardsForCollection([
      for (final row in rows as List) Vineyard.fromMap(row),
    ]);
  }

  /// One batched lookup, in the order of [ids]; ids that no longer resolve
  /// simply drop out.
  Future<List<Vineyard>> loadByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('vineyards_full')
        .select(vineyardFullColumns)
        .inFilter('id', ids);
    final byId = {
      for (final row in rows as List)
        row['id'] as String: Vineyard.fromMap(row),
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  // ── Visits (Passport) ─────────────────────────────────────────────────

  /// Records the signed-in member's visit to an estate — the only path to
  /// an estate Passport stamp.
  Future<VineyardVisit> logVisit({
    required String userId,
    required String vineyardId,
    required DateTime visitedOn,
    Set<VineyardActivity> activities = const {},
    String? comment,
    bool friendsVisible = false,
  }) async {
    final row = await _client
        .from('vineyard_visits')
        .insert(
          buildVineyardVisitInsert(
            userId: userId,
            vineyardId: vineyardId,
            visitedOn: visitedOn,
            activities: activities,
            comment: comment,
            friendsVisible: friendsVisible,
          ),
        )
        .select(_visitColumns)
        .single();
    return VineyardVisit.fromMap(row);
  }

  Future<void> deleteVisit(String visitId) =>
      _client.from('vineyard_visits').delete().eq('id', visitId);

  /// The member's own visits to [vineyardId], newest first.
  Future<List<VineyardVisit>> getMyVisits({
    required String userId,
    required String vineyardId,
  }) async {
    final rows = await _client
        .from('vineyard_visits')
        .select(_visitColumns)
        .eq('user_id', userId)
        .eq('vineyard_id', vineyardId)
        .order('visited_on', ascending: false);
    return [for (final row in rows as List) VineyardVisit.fromMap(row)];
  }

  /// Every estate visit of [userId] with its estate, for the Passport. Two
  /// queries in total, never one per visit.
  Future<List<VineyardVisitEntry>> loadPassportVineyardVisits(
    String userId,
  ) async {
    if (userId.isEmpty) return [];
    final rows = await _client
        .from('vineyard_visits')
        .select(_visitColumns)
        .eq('user_id', userId)
        .order('visited_on', ascending: false);
    final visits = [for (final row in rows as List) VineyardVisit.fromMap(row)];
    if (visits.isEmpty) return [];
    final vineyards = await loadByIds(
      visits.map((v) => v.vineyardId).toSet().toList(),
    );
    final byId = {for (final v in vineyards) v.id: v};
    return [
      for (final visit in visits)
        if (byId[visit.vineyardId] != null)
          VineyardVisitEntry(visit: visit, vineyard: byId[visit.vineyardId]!),
    ];
  }
}
