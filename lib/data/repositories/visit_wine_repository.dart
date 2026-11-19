import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/visit_wine.dart';

const _legacyWineColumns =
    'id, producer, wine_name, vintage, non_vintage, bottle_size';

// The picked estate comes along with the wine (20261101550000), with its
// country's name, so a cellar can be grouped without a second query.
const _wineColumns =
    '$_legacyWineColumns, vineyard_id, '
    'vineyards(id, vineyard_code, name, region, city, country_code, '
    'countries(name))';

/// One wine in a member's cellar, with the day of the visit it was on.
class CellarWine {
  final VisitWine wine;
  final String visitId;
  final DateTime? visitedOn;

  const CellarWine({required this.wine, required this.visitId, this.visitedOn});
}

CellarWine _cellarWine(Map<String, dynamic> row) => CellarWine(
  wine: VisitWine.fromJson(row),
  visitId: row['visit_id'] as String,
  visitedOn: switch (row['visits']) {
    {'visited_on': final String day} => DateTime.tryParse(day),
    _ => null,
  },
);

/// The wines on a visit or stay (`visit_wines`, 20261101330000). RLS makes a
/// wine exactly as visible as its visit, so nothing is filtered here.
///
/// Reads ask for the estate link first and fall back to the columns every
/// database has, so this build keeps showing wines before the vineyards
/// migration is applied.
class VisitWineRepository {
  VisitWineRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> _withFallback(
    Future<List<dynamic>> Function(String columns) query,
  ) async {
    try {
      return (await query(_wineColumns)).cast<Map<String, dynamic>>();
    } on PostgrestException {
      return (await query(_legacyWineColumns)).cast<Map<String, dynamic>>();
    }
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

  /// Every wine the member has logged, newest first, for the Passport's
  /// Cellar. Only the member's own: the cellar is personal.
  Future<List<CellarWine>> loadCellar(String userId) async {
    final rows = await _withFallback(
      (columns) => _client
          .from('visit_wines')
          .select('$columns, visit_id, visits(visited_on)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1000),
    );
    return [for (final row in rows) _cellarWine(row)];
  }

  /// The member's own wines from one estate, for "In your Passport" on the
  /// estate's page.
  Future<List<CellarWine>> loadForVineyard({
    required String userId,
    required String vineyardId,
  }) async {
    final rows = await _client
        .from('visit_wines')
        .select('$_wineColumns, visit_id, visits(visited_on)')
        .eq('user_id', userId)
        .eq('vineyard_id', vineyardId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows as List) _cellarWine(row as Map<String, dynamic>),
    ];
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

  /// [wasLinked]: the wine had an estate before, so a cleared link is
  /// written as null rather than left out.
  Future<void> update(
    String wineId,
    VisitWine wine, {
    bool wasLinked = false,
  }) => _client
      .from('visit_wines')
      .update(wine.toRow(withVineyard: wasLinked))
      .eq('id', wineId);

  Future<void> delete(String wineId) =>
      _client.from('visit_wines').delete().eq('id', wineId);

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
