import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/vineyard.dart';
import '../../models/vineyard_recognition.dart';
import '../../models/vineyard_visit.dart';

// Every column of public.vineyards_full, listed explicitly so a schema
// change is a visible diff here (the convention JourneyRepository follows).
const _visitColumns =
    'id, vineyard_id, visited_on, activities, rating, comment, visibility';

const vineyardFullColumns =
    'id, vineyard_code, name, country_code, country_name, flag_emoji, '
    'region, city, address, latitude, longitude, website_url, status, '
    'worlds_50_best_year, worlds_50_best_rank, commune_name';

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

  /// Every estate, read a page at a time in a fixed order, so a catalogue
  /// past the server's row limit (1,000) is never cut off silently. Only the
  /// device fallback of [search] needs it now; the collection reads
  /// [getRecognised] and every picker searches.
  Future<List<Vineyard>> getAll() async {
    const page = 1000;
    final all = <Vineyard>[];
    for (var from = 0; ; from += page) {
      final rows =
          await _client
                  .from('vineyards_full')
                  .select(vineyardFullColumns)
                  .order('vineyard_code')
                  .range(from, from + page - 1)
              as List;
      all.addAll([for (final row in rows) Vineyard.fromMap(row)]);
      if (rows.length < page) break;
    }
    return sortVineyardsForCollection(all);
  }

  /// Explore's estate search: names first ([search]), then estates whose
  /// region, wine region or town contains what was typed, at most [limit]
  /// in all. The place match is plain `ilike`, so it is not accent folded.
  Future<List<Vineyard>> searchByNameOrPlace(
    String query, {
    String? countryCode,
    int limit = 20,
  }) async {
    final byName = await search(query, countryCode: countryCode, limit: limit);
    // Characters PostgREST's or() filter reads as syntax are dropped.
    final safe = query
        .trim()
        .replaceAll(RegExp(r'[,()*%.:"\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.length < 2 || byName.length >= limit) return byName;
    List rows;
    try {
      var request = _client
          .from('vineyards_full')
          .select(vineyardFullColumns)
          .or(
            'region.ilike.*$safe*,city.ilike.*$safe*,'
            'wine_region_name.ilike.*$safe*',
          );
      if (countryCode != null) {
        request = request.eq('country_code', countryCode);
      }
      rows = await request.order('name').limit(limit) as List;
    } on PostgrestException {
      return byName;
    }
    final seen = {for (final v in byName) v.id};
    return [
      ...byName,
      for (final row in rows)
        if (seen.add(row['id'] as String)) Vineyard.fromMap(row),
    ].take(limit).toList();
  }

  /// Every country that has an estate: three short columns per estate,
  /// read a page at a time, for Explore's country filter.
  Future<List<({String code, String name, String flag})>> getCountries() async {
    const page = 1000;
    final seen = <String, ({String code, String name, String flag})>{};
    for (var from = 0; ; from += page) {
      final rows =
          await _client
                  .from('vineyards_full')
                  .select(
                    'vineyard_code, country_code, country_name, flag_emoji',
                  )
                  .order('vineyard_code')
                  .range(from, from + page - 1)
              as List;
      for (final row in rows) {
        final code = row['country_code'] as String;
        final name = row['country_name'] as String?;
        if (name == null || name.isEmpty) continue;
        seen[code] ??= (
          code: code,
          name: name,
          flag: row['flag_emoji'] as String? ?? '',
        );
      }
      if (rows.length < page) break;
    }
    return seen.values.toList();
  }

  /// The estates the Wine Estates collection shows: only recognised ones,
  /// today those on the current World's 50 Best Vineyards list, in rank
  /// order (product owner, 2026-11-24: only the top recognised estates in
  /// the collection, the rest found through search). An official
  /// classification joins this when its table exists.
  Future<List<Vineyard>> getRecognised() async {
    final rows =
        await _client
                .from('vineyards_full')
                .select(vineyardFullColumns)
                .not('worlds_50_best_rank', 'is', null)
                .order('worlds_50_best_rank')
            as List;
    return sortVineyardsForCollection([
      for (final row in rows) Vineyard.fromMap(row),
    ]);
  }

  /// The official classifications (`vineyard_recognitions`,
  /// 20261101830000), all or one [scheme]'s. Empty, not an error, before
  /// that migration is applied, so Guides then shows no classification.
  Future<List<VineyardRecognition>> getRecognitions({String? scheme}) async {
    try {
      var request = _client
          .from('vineyard_recognitions')
          .select('vineyard_id, scheme, class, class_order, edition');
      if (scheme != null) request = request.eq('scheme', scheme);
      final rows = await request as List;
      return [
        for (final row in rows)
          VineyardRecognition.fromMap(row as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      if (isMissingTableError(e)) return const [];
      rethrow;
    }
  }

  /// Set once the server says `search_vineyards` does not exist (before
  /// 20261101740000 is applied); [search] then filters the whole list on
  /// the device, as every build did before.
  bool _serverSearchMissing = false;
  List<Vineyard>? _deviceCatalogue;

  /// The estates a typed producer could be, best first, at most [limit].
  /// On the server (`search_vineyards`: names and other names, accents
  /// folded) when it exists, else on the device with [matchingVineyards].
  /// Only proposes: the member picks, nothing is linked by name.
  Future<List<Vineyard>> search(
    String query, {
    String? countryCode,
    int limit = 3,
  }) async {
    final typed = query.trim();
    if (foldForSearch(typed).length < 2) return const [];
    if (!_serverSearchMissing) {
      try {
        final rows = await _client.rpc(
          'search_vineyards',
          params: {
            'p_query': typed,
            'p_country': countryCode,
            'p_limit': limit,
          },
        );
        return [
          for (final row in rows as List)
            Vineyard.fromMap(row as Map<String, dynamic>),
        ];
      } on PostgrestException catch (e) {
        if (!isMissingFunctionError(e)) rethrow;
        _serverSearchMissing = true;
      }
    }
    final all = _deviceCatalogue ??= await getAll();
    final inCountry = countryCode == null
        ? all
        : all.where((v) => v.countryCode == countryCode);
    return matchingVineyards(inCountry, typed, limit: limit);
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

  /// Saves an edited visit; RLS lets only its own member change it.
  Future<VineyardVisit> updateVisit({
    required String visitId,
    required DateTime visitedOn,
    Set<VineyardActivity> activities = const {},
    String? comment,
    bool friendsVisible = false,
  }) async {
    final row = await _client
        .from('vineyard_visits')
        .update(
          buildVineyardVisitUpdate(
            visitedOn: visitedOn,
            activities: activities,
            comment: comment,
            friendsVisible: friendsVisible,
          ),
        )
        .eq('id', visitId)
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

/// PostgREST's answer when an RPC does not exist on this database yet
/// (PGRST202), or Postgres's own (42883).
bool isMissingFunctionError(PostgrestException e) =>
    e.code == 'PGRST202' || e.code == '42883';

/// PostgREST's answer when a table is not in its schema cache (PGRST205),
/// or Postgres's own (42P01).
bool isMissingTableError(PostgrestException e) =>
    e.code == 'PGRST205' || e.code == '42P01';
