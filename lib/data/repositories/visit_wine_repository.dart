import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/visit_wine.dart';

/// The wines on a visit or stay (`visit_wines`, 20261101330000). RLS makes a
/// wine exactly as visible as its visit, so nothing is filtered here.
class VisitWineRepository {
  VisitWineRepository(this._client);

  final SupabaseClient _client;

  Future<List<VisitWine>> loadForVisit(String visitId) async {
    final rows = await _client
        .from('visit_wines')
        .select('id, producer, wine_name, vintage, non_vintage, bottle_size')
        .eq('visit_id', visitId)
        .order('display_order', ascending: true)
        .order('created_at', ascending: true);
    return [
      for (final row in rows as List)
        VisitWine.fromJson(row as Map<String, dynamic>),
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
        .select('id, producer, wine_name, vintage, non_vintage, bottle_size')
        .single();
    return VisitWine.fromJson(row);
  }

  Future<void> update(String wineId, VisitWine wine) =>
      _client.from('visit_wines').update(wine.toRow()).eq('id', wineId);

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
