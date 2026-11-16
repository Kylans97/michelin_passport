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
      'distinction_label, guides(name, measure, score_max)';

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
    return (rows as List).map((row) {
      final json = row as Map<String, dynamic>;
      return GuideAward.fromJson({
        ...json,
        'guides': {
          'name': json['guide_name'],
          'measure': json['measure'],
          'score_max': json['score_max'],
        },
      });
    }).toList();
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
