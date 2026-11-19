import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/vineyard.dart';

// Every column of public.vineyards_full, listed explicitly so a schema
// change is a visible diff here (the convention JourneyRepository follows).
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
}
