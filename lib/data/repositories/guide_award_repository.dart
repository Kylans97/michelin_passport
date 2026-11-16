import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/guide_award.dart';

/// The shared guide tables (guides, guide_awards, guide_coverage) — every
/// guide beyond MICHELIN, World's 50 Best and Gault&Millau, which keep their
/// own repositories. Read-only, through RLS's public read.
class GuideAwardRepository {
  GuideAwardRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'guide_code, edition_year, list_name, rank, score, tier, '
      'distinction_label, guides(name, measure, score_max, tier_labels)';

  /// Every edition this restaurant appears in, newest first, across all
  /// shared guides.
  Future<List<GuideAward>> loadForRestaurant(String restaurantId) async {
    final rows = await _client
        .from('guide_awards')
        .select(_columns)
        .eq('restaurant_id', restaurantId)
        .order('edition_year', ascending: false);
    return (rows as List)
        .map((row) => GuideAward.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Each guide's own latest edition for this restaurant — empty when the
  /// restaurant has left a list, exactly as guide_awards_current reads it.
  Future<List<GuideAward>> loadCurrentForRestaurant(String restaurantId) async {
    final rows = await _client
        .from('guide_awards_current')
        .select(
          'guide_code, guide_name, measure, score_max, edition_year, '
          'list_name, rank, score, tier, distinction_label',
        )
        .eq('restaurant_id', restaurantId)
        .order('guide_code');
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return [];
    // The view carries no tier_labels; read them from guides in one query.
    final guideRows = await _client
        .from('guides')
        .select('guide_code, tier_labels')
        .inFilter(
          'guide_code',
          {for (final r in list) r['guide_code']}.toList(),
        );
    final labels = {
      for (final g in (guideRows as List).cast<Map<String, dynamic>>())
        g['guide_code'] as String: g['tier_labels'],
    };
    return list
        .map(
          (json) => GuideAward.fromJson({
            ...json,
            'guides': {
              'name': json['guide_name'],
              'measure': json['measure'],
              'score_max': json['score_max'],
              'tier_labels': labels[json['guide_code']],
            },
          }),
        )
        .toList();
  }

  /// The coverage note per guide edition, for the guides given.
  Future<List<GuideCoverage>> loadCoverage(Iterable<String> guideCodes) async {
    final codes = guideCodes.toSet().toList();
    if (codes.isEmpty) return [];
    final rows = await _client
        .from('guide_coverage')
        .select('guide_code, edition_year, coverage, note')
        .inFilter('guide_code', codes)
        .isFilter('country_code', null);
    return (rows as List)
        .map((row) => GuideCoverage.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
