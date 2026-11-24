import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/visit_wine.dart';

const _legacyWineColumns =
    'id, producer, wine_name, vintage, non_vintage, bottle_size';

// The picked estate comes along with the wine (20261101550000), with its
// country's name, so a cellar can be grouped without a second query.
const _estateColumns =
    'vineyard_id, '
    'vineyards(id, vineyard_code, name, region, city, country_code, '
    'countries(name))';

const _linkedWineColumns = '$_legacyWineColumns, $_estateColumns';

// The verdict and note (20261101640000).
const _wineColumns = '$_linkedWineColumns, verdict, tasting_note';

// A wine kept without a visit (`cellar_wines`, 20261101640000).
const _cellarWineColumns =
    '$_wineColumns, setting, place, drunk_on, created_at';

/// One wine in a member's cellar: from a visit ([visitId] and [date] the
/// visit's day), or kept without one ([visitId] null, [date] the day the
/// member gave, if any).
class CellarWine {
  final VisitWine wine;
  final String? visitId;
  final DateTime? date;

  const CellarWine({required this.wine, this.visitId, this.date});

  bool get isKeptWithoutVisit => visitId == null;
}

CellarWine _cellarWine(Map<String, dynamic> row) => CellarWine(
  wine: VisitWine.fromJson(row),
  visitId: row['visit_id'] as String,
  date: switch (row['visits']) {
    {'visited_on': final String day} => DateTime.tryParse(day),
    _ => null,
  },
);

CellarWine _keptWine(Map<String, dynamic> row) {
  final wine = VisitWine.fromJson(row);
  return CellarWine(wine: wine, date: wine.drunkOn);
}

/// Newest first: the day drunk where there is one, else when it was noted.
int _newestFirst(CellarWine a, CellarWine b) {
  final da = a.date, db = b.date;
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return db.compareTo(da);
}

/// The wines on a visit or stay (`visit_wines`, 20261101330000). RLS makes a
/// wine exactly as visible as its visit, so nothing is filtered here.
///
/// Reads ask for the verdict and the estate link first and fall back step
/// by step to the columns every database has, so this build keeps showing
/// wines before the vineyards or the verdicts migration is applied.
/// `cellar_wines` is read only when it exists.
class VisitWineRepository {
  VisitWineRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> _withFallback(
    Future<List<dynamic>> Function(String columns) query,
  ) async {
    for (final columns in const [_wineColumns, _linkedWineColumns]) {
      try {
        return (await query(columns)).cast<Map<String, dynamic>>();
      } on PostgrestException {
        // An older database: try the next, narrower set.
      }
    }
    return (await query(_legacyWineColumns)).cast<Map<String, dynamic>>();
  }

  Future<List<VisitWine>> loadForVisit(String visitId) async {
    final rows = await _withFallback(
      (columns) => _client
          .from('visit_wines')
          .select(columns)
          .eq('visit_id', visitId)
          .order('display_order', ascending: true)
          .order('created_at', ascending: true),
    );
    return [for (final row in rows) VisitWine.fromJson(row)];
  }

  /// Every wine [userId] has logged, from visits and kept without one,
  /// newest first: the member's own Cellar, or a friend's Cellar tab.
  /// For a friend RLS returns only wines on shared visits and, when they
  /// share their Cellar, the ones kept without a visit; the caller checks
  /// [canSeeCellar] first.
  Future<List<CellarWine>> loadCellar(String userId) async {
    final rows = await _withFallback(
      (columns) => _client
          .from('visit_wines')
          .select('$columns, visit_id, visits(visited_on)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1000),
    );
    final kept = await _loadKept({'user_id': userId});
    return [for (final row in rows) _cellarWine(row), ...kept]
      ..sort(_newestFirst);
  }

  /// Whether the signed in member may see [ownerId]'s Cellar
  /// (`can_see_cellar`, 20261101730000): their own, or a friend's who
  /// shares it. Before that migration there is no switch and every
  /// friend's Cellar is shared, so a missing function reads as true; the
  /// database still decides which rows come back.
  Future<bool> canSeeCellar(String ownerId) async {
    try {
      final result = await _client.rpc(
        'can_see_cellar',
        params: {'p_owner': ownerId},
      );
      return result == true;
    } on PostgrestException catch (e) {
      if (_isMissingFunction(e)) return true;
      rethrow;
    }
  }

  /// The ones of [ownerIds] whose Cellar the member may see.
  Future<Set<String>> cellarsVisibleOf(List<String> ownerIds) async {
    final visible = await [for (final id in ownerIds) canSeeCellar(id)].wait;
    return {
      for (var i = 0; i < ownerIds.length; i++)
        if (visible[i]) ownerIds[i],
    };
  }

  /// Wines the given friends would drink again, from shared visits and
  /// kept without one, newest first, each with whose it is. RLS decides
  /// which rows come back: a wine on a private visit never does, a kept
  /// wine only from a friend who shares their Cellar (20261101730000).
  /// A friend who keeps their Cellar to themself is left out entirely,
  /// shared visits included, so this list never shows a hidden Cellar.
  /// At most [limit].
  Future<List<({String userId, CellarWine wine})>> loadAgainWinesFor(
    List<String> friendIds, {
    int limit = 12,
  }) async {
    if (friendIds.isEmpty) return const [];
    final userIds = (await cellarsVisibleOf(friendIds)).toList();
    if (userIds.isEmpty) return const [];
    final List<Map<String, dynamic>> visitRows;
    try {
      visitRows =
          (await _client
                  .from('visit_wines')
                  .select(
                    '$_wineColumns, user_id, visit_id, visits(visited_on)',
                  )
                  .inFilter('user_id', userIds)
                  .eq('verdict', WineVerdict.again.dbValue)
                  .order('created_at', ascending: false)
                  .limit(limit))
              .cast<Map<String, dynamic>>();
    } on PostgrestException {
      // Before the verdicts migration there is no verdict to filter on.
      return const [];
    }
    List<Map<String, dynamic>> keptRows;
    try {
      keptRows =
          (await _client
                  .from('cellar_wines')
                  .select('$_cellarWineColumns, user_id')
                  .inFilter('user_id', userIds)
                  .eq('verdict', WineVerdict.again.dbValue)
                  .order('created_at', ascending: false)
                  .limit(limit))
              .cast<Map<String, dynamic>>();
    } on PostgrestException {
      keptRows = const [];
    }
    final all = [
      for (final row in visitRows)
        (userId: row['user_id'] as String, wine: _cellarWine(row)),
      for (final row in keptRows)
        (userId: row['user_id'] as String, wine: _keptWine(row)),
    ]..sort((a, b) => _newestFirst(a.wine, b.wine));
    return all.take(limit).toList();
  }

  /// The member's wines kept without a visit, matching every column in
  /// [filters]. Empty before the verdicts migration is applied, never an
  /// error.
  Future<List<CellarWine>> _loadKept(Map<String, String> filters) async {
    try {
      var query = _client.from('cellar_wines').select(_cellarWineColumns);
      for (final f in filters.entries) {
        query = query.eq(f.key, f.value);
      }
      final rows = await query
          .order('created_at', ascending: false)
          .limit(1000);
      return [for (final row in rows) _keptWine(row)];
    } on PostgrestException {
      return const [];
    }
  }

  /// The member's own wines from one estate, from visits and kept without
  /// one, for "In your Passport" on the estate's page.
  Future<List<CellarWine>> loadForVineyard({
    required String userId,
    required String vineyardId,
  }) async {
    final rows = await _withFallback(
      (columns) => _client
          .from('visit_wines')
          .select('$columns, visit_id, visits(visited_on)')
          .eq('user_id', userId)
          .eq('vineyard_id', vineyardId)
          .order('created_at', ascending: false),
    );
    final kept = await _loadKept({
      'user_id': userId,
      'vineyard_id': vineyardId,
    });
    return [for (final row in rows) _cellarWine(row), ...kept]
      ..sort(_newestFirst);
  }

  Future<VisitWine> add({
    required String userId,
    required String visitId,
    required VisitWine wine,
    required int displayOrder,
  }) async {
    final row = await _client
        .from('visit_wines')
        .insert({
          ...wine.toRow(),
          'user_id': userId,
          'visit_id': visitId,
          'display_order': displayOrder,
        })
        .select('id')
        .single();
    return wine.copyWith(id: row['id'] as String);
  }

  /// [previous]: the wine as it was, so a cleared estate link, verdict or
  /// note is written as null rather than left out.
  Future<void> update(String wineId, VisitWine wine, {VisitWine? previous}) =>
      _client
          .from('visit_wines')
          .update(
            wine.toRow(
              withVineyard: previous?.vineyardId != null,
              withVerdict:
                  previous?.verdict != null || previous?.tastingNote != null,
            ),
          )
          .eq('id', wineId);

  Future<void> delete(String wineId) =>
      _client.from('visit_wines').delete().eq('id', wineId);

  /// A wine kept in the Cellar without a visit (`cellar_wines`).
  Future<VisitWine> addKept({
    required String userId,
    required VisitWine wine,
  }) async {
    final row = await _client
        .from('cellar_wines')
        .insert({...wine.toCellarRow(), 'user_id': userId})
        .select('id')
        .single();
    return wine.copyWith(id: row['id'] as String);
  }

  Future<void> updateKept(String wineId, VisitWine wine) =>
      _client.from('cellar_wines').update(wine.toCellarRow()).eq('id', wineId);

  Future<void> deleteKept(String wineId) =>
      _client.from('cellar_wines').delete().eq('id', wineId);

  /// The member's own earlier producers and wine names, newest first, for
  /// the suggestions in the add sheet. Never anyone else's.
  Future<WineSuggestions> loadSuggestions(String userId) async {
    final rows = await _client
        .from('visit_wines')
        .select('producer, wine_name')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(500);
    final producers = <String>[];
    final names = <String, Set<String>>{};
    final allNames = <String>[];
    for (final row in rows as List) {
      final producer = row['producer'] as String?;
      final name = row['wine_name'] as String?;
      if (producer != null && !producers.contains(producer)) {
        producers.add(producer);
      }
      if (name != null) {
        if (!allNames.contains(name)) allNames.add(name);
        if (producer != null) names.putIfAbsent(producer, () => {}).add(name);
      }
    }
    return WineSuggestions(
      producers: producers,
      wineNames: allNames,
      wineNamesByProducer: names,
    );
  }
}

class WineSuggestions {
  final List<String> producers;
  final List<String> wineNames;
  final Map<String, Set<String>> wineNamesByProducer;

  const WineSuggestions({
    this.producers = const [],
    this.wineNames = const [],
    this.wineNamesByProducer = const {},
  });

  /// Names from the chosen producer first, then every other.
  List<String> namesFor(String producer) => [
    ...?wineNamesByProducer[producer.trim()],
    ...wineNames,
  ];
}

/// PostgREST's "function not found" (PGRST202), or Postgres' own 42883.
bool _isMissingFunction(PostgrestException e) =>
    e.code == 'PGRST202' || e.code == '42883';
