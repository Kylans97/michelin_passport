import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/guide_award.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;
import 'search_query.dart';

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

  /// One shared guide's current list (its own latest edition, as
  /// guide_awards_current reads it), resolved to real Restaurant rows and
  /// sorted per [sortSharedGuideEntries]. [query]/[countryCode] narrow the
  /// resolved restaurants, as on the Gault&Millau guide. Two queries plus
  /// the guide's tier labels, never one per restaurant.
  Future<List<SharedGuideEntry>> getCurrentRestaurants(
    String guideCode, {
    String query = '',
    String? countryCode,
  }) async {
    final awardRows = await _client
        .from('guide_awards_current')
        .select(
          'guide_code, guide_name, measure, score_max, edition_year, '
          'list_name, rank, score, tier, distinction_label, restaurant_id',
        )
        .eq('guide_code', guideCode)
        .not('restaurant_id', 'is', null);
    final awards = (awardRows as List).cast<Map<String, dynamic>>();
    if (awards.isEmpty) return [];

    final guideRow = await _client
        .from('guides')
        .select('tier_labels')
        .eq('guide_code', guideCode)
        .maybeSingle();

    var builder = _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .inFilter('id', {for (final a in awards) a['restaurant_id']}.toList());
    final orFilter = buildIlikeOrFilter(query, [
      'name',
      'city_name',
      'country_name',
    ]);
    if (orFilter != null) builder = builder.or(orFilter);
    if (countryCode != null) builder = builder.eq('country_code', countryCode);
    final restaurantRows = await builder;

    return buildSharedGuideEntries(
      awardRows: awards,
      tierLabels: guideRow?['tier_labels'] as Map<String, dynamic>?,
      restaurantRows: (restaurantRows as List).cast<Map<String, dynamic>>(),
    );
  }

  /// Countries among the restaurants on this guide's current list, so the
  /// picker only offers a country that has data.
  Future<List<VenueCountry>> getCountries(String guideCode) async {
    final awardRows = await _client
        .from('guide_awards_current')
        .select('restaurant_id')
        .eq('guide_code', guideCode)
        .not('restaurant_id', 'is', null);
    final ids = {for (final r in awardRows as List) r['restaurant_id']};
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('restaurants_full')
        .select('country_code')
        .inFilter('id', ids.toList());
    final codes = <String>{
      for (final r in rows as List)
        if ((r['country_code'] as String?)?.isNotEmpty ?? false)
          r['country_code'] as String,
    };
    return resolveVenueCountries(_client, codes);
  }

  /// The coverage note for this guide's latest edition: what we hold of
  /// it, said plainly. A guide-wide note when there is one, else its
  /// single country note (Guía Repsol covers Spain). Null without one.
  Future<GuideCoverage?> loadLatestCoverage(String guideCode) async {
    final rows = await _client
        .from('guide_coverage')
        .select('guide_code, edition_year, coverage, note, country_code')
        .eq('guide_code', guideCode)
        .order('edition_year', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    final latest = list.first['edition_year'];
    final ofLatest = list.where((r) => r['edition_year'] == latest).toList();
    final guideWide = ofLatest.where((r) => r['country_code'] == null);
    if (guideWide.isNotEmpty) return GuideCoverage.fromJson(guideWide.first);
    return ofLatest.length == 1 ? GuideCoverage.fromJson(ofLatest.first) : null;
  }
}

/// One restaurant on a shared guide's current list.
class SharedGuideEntry {
  final Restaurant restaurant;
  final GuideAward award;

  const SharedGuideEntry({required this.restaurant, required this.award});
}

/// Pairs guide_awards_current rows with resolved restaurants_full rows.
/// A restaurant the filters dropped, or one not in the catalogue view, is
/// simply absent: never a placeholder. Sorted per [sortSharedGuideEntries].
List<SharedGuideEntry> buildSharedGuideEntries({
  required List<Map<String, dynamic>> awardRows,
  required Map<String, dynamic>? tierLabels,
  required List<Map<String, dynamic>> restaurantRows,
}) {
  final byId = {for (final row in restaurantRows) row['id'].toString(): row};
  final entries = <SharedGuideEntry>[];
  for (final a in awardRows) {
    final row = byId[a['restaurant_id'].toString()];
    if (row == null) continue;
    entries.add(
      SharedGuideEntry(
        restaurant: Restaurant.fromJson(row),
        award: GuideAward.fromJson({
          ...a,
          'guides': {
            'name': a['guide_name'],
            'measure': a['measure'],
            'score_max': a['score_max'],
            'tier_labels': tierLabels,
          },
        }),
      ),
    );
  }
  return sortSharedGuideEntries(entries);
}

/// In the guide's own order: by rank (lowest first) for a ranked list, by
/// tier or score (highest first) otherwise; ties, and rows without a
/// value, by restaurant name. Rows without a value sort last.
List<SharedGuideEntry> sortSharedGuideEntries(List<SharedGuideEntry> list) {
  num? key(GuideAward a) => switch (a.measure) {
    GuideMeasure.rank => a.rank,
    GuideMeasure.score => a.score == null ? null : -a.score!,
    GuideMeasure.tier => a.tier == null ? null : -a.tier!,
  };
  final sorted = [...list]
    ..sort((x, y) {
      final kx = key(x.award), ky = key(y.award);
      if (kx != null && ky != null && kx != ky) return kx.compareTo(ky);
      if (kx == null && ky != null) return 1;
      if (kx != null && ky == null) return -1;
      return x.restaurant.name.toLowerCase().compareTo(
        y.restaurant.name.toLowerCase(),
      );
    });
  return sorted;
}
