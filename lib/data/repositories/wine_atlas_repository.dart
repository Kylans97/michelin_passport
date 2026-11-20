import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/wine_atlas.dart';
import 'visit_wine_repository.dart';

const _regionColumns =
    'id, region_code, name, aliases, country_code, parent_id, latitude, '
    'longitude, radius_km, summary, red_body, red_acidity, red_tannin, '
    'pairing, label_note, countries(name)';
const _grapeColumns =
    'id, grape_code, name, aliases, colour, summary, tastes, aged_note, '
    'body, acidity, tannin, similar_grape_id, similar_note';
const _appellationColumns =
    'id, name, aliases, region_id, colour, note, display_order';

/// The globe's wine layer (20261101580000_add_wine_regions.sql). Reference
/// content: world-readable once published, no client write. RLS returns
/// published rows only, so drafts never reach the app.
class WineAtlasRepository {
  WineAtlasRepository(this._client);

  final SupabaseClient _client;

  /// Everything at once — a few dozen rows, searched on the device. Before
  /// the migration is applied the tables don't exist; that is an error the
  /// caller turns into "no wine layer".
  Future<WineAtlas> load() async {
    final regions = _loadRegions();
    final grapes = _client.from('grapes').select(_grapeColumns);
    final links = _client
        .from('wine_region_grapes')
        .select('region_id, grape_id, local_note, display_order');
    final appellations = _client
        .from('wine_appellations')
        .select(_appellationColumns);
    final results = await Future.wait([regions, grapes, links, appellations]);
    return WineAtlas(
      regions: [
        for (final row in results[0])
          WineRegion.fromMap(row as Map<String, dynamic>),
      ]..sort((a, b) => a.name.compareTo(b.name)),
      grapes: [
        for (final row in results[1])
          Grape.fromMap(row as Map<String, dynamic>),
      ]..sort((a, b) => a.name.compareTo(b.name)),
      regionGrapes: [
        for (final row in results[2])
          RegionGrape.fromMap(row as Map<String, dynamic>),
      ],
      appellations: [
        for (final row in results[3])
          WineAppellation.fromMap(row as Map<String, dynamic>),
      ],
    );
  }

  /// The regions with their outlines (20261101590000). Until that
  /// migration is applied the column doesn't exist (42703): the regions
  /// then load without it and draw as patches around their point.
  Future<List<dynamic>> _loadRegions() async {
    try {
      return await _client
          .from('wine_regions')
          .select('$_regionColumns, outline');
    } on PostgrestException catch (e) {
      if (e.code != '42703') rethrow;
      return await _client.from('wine_regions').select(_regionColumns);
    }
  }

  /// How many of [userId]'s logged wines come from each region — through
  /// the estate a wine was linked to (`vineyards.wine_region_id`). Wines
  /// with only a free-text producer are never matched to a region by name.
  Future<Map<String, int>> loadMyWineCountsByRegion(String userId) async {
    if (userId.isEmpty) return const {};
    final wines = await VisitWineRepository(_client).loadCellar(userId);
    final vineyardIds = {
      for (final w in wines)
        if (w.wine.vineyardId != null) w.wine.vineyardId!,
    };
    if (vineyardIds.isEmpty) return const {};
    final rows = await _client
        .from('vineyards')
        .select('id, wine_region_id')
        .inFilter('id', vineyardIds.toList())
        .not('wine_region_id', 'is', null);
    final regionOf = {
      for (final row in rows as List)
        row['id'] as String: row['wine_region_id'] as String,
    };
    final counts = <String, int>{};
    for (final w in wines) {
      final region = regionOf[w.wine.vineyardId];
      if (region != null) counts[region] = (counts[region] ?? 0) + 1;
    }
    return counts;
  }
}
