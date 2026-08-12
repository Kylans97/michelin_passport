import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/gault_millau_award.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'gault_millau_ranking.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;
import 'search_query.dart';

/// One restaurant's latest Gault&Millau recognition — the restaurant-side
/// counterpart of RestaurantWorlds50BestRankingEntry. Pairs the real,
/// resolved Restaurant (so a tap opens RestaurantDetailScreen directly)
/// with its award row.
class RestaurantGaultMillauEntry {
  final Restaurant restaurant;
  final GaultMillauAward award;

  const RestaurantGaultMillauEntry({
    required this.restaurant,
    required this.award,
  });
}

/// Gault&Millau's restaurant guide — the third Guide source (Step 2D), read
/// exclusively from public.gault_millau_awards (the dedicated, authoritative
/// recognition table). Never infers Gault&Millau status from
/// inclusion_reason, Michelin data, World's 50 Best, or restaurant name —
/// see the migration's own architecture note and
/// docs/Architecture/Michelin_Database/GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md.
///
/// No year parameter anywhere on this repository, unlike
/// RestaurantWorlds50BestRepository — the Step 2D brief's explicit MVP
/// decision (see the Guides Step 2D report): production carries a single
/// 2026 edition today, and this catalogue answers "which places can I
/// discover now?" the same way Michelin Restaurants does, not "browse a
/// specific year's edition." [gaultMillauLatestPerRestaurant] still
/// resolves multiple editions correctly if/when they exist (see
/// gault_millau_ranking.dart), so no schema or repository change would be
/// needed to add a year selector later — only a screen-level change.
class RestaurantGaultMillauRepository {
  RestaurantGaultMillauRepository(this._client);

  final SupabaseClient _client;

  static const _awardColumns =
      'restaurant_id, guide_year, score, toque_count, toque_colour, '
      'recognition_type, distinction_label, gault_millau_url';

  /// Every restaurant's latest recognition, resolved to real Restaurant rows
  /// (via restaurants_full, the same shared column list every other
  /// restaurant screen uses), sorted per [sortGaultMillauEntries].
  /// [query]/[countryCode] narrow the *resolved* restaurants — independent
  /// filters, combined with AND, mirroring RestaurantRepository.search()'s
  /// own query/country semantics exactly.
  ///
  /// Two queries total, never one per restaurant: every gault_millau_awards
  /// row (small — 41 rows in production today), then one batched
  /// restaurants_full lookup via `.inFilter('id', ...)` — identical shape to
  /// RestaurantWorlds50BestRepository.getRanking.
  Future<List<RestaurantGaultMillauEntry>> getLatest({
    String query = '',
    String? countryCode,
  }) async {
    final awardRows = await _client
        .from('gault_millau_awards')
        .select(_awardColumns);
    final rawAwardRows = (awardRows as List).cast<Map<String, dynamic>>();
    if (rawAwardRows.isEmpty) return [];

    final latest = latestGaultMillauAwardPerRestaurant(rawAwardRows);
    final restaurantIds = latest.map((a) => a.restaurantId).toSet();

    var builder = _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .inFilter('id', restaurantIds.toList());
    final orFilter = buildIlikeOrFilter(query, [
      'name',
      'city_name',
      'country_name',
    ]);
    if (orFilter != null) {
      builder = builder.or(orFilter);
    }
    if (countryCode != null) {
      builder = builder.eq('country_code', countryCode);
    }
    final restaurantRows = await builder;

    final entries = buildGaultMillauEntries(
      rawAwardRows: rawAwardRows,
      restaurantRows: (restaurantRows as List).cast<Map<String, dynamic>>(),
    );
    return sortGaultMillauEntries(entries);
  }

  /// Countries represented among restaurants with a current Gault&Millau
  /// award — never the entire restaurant catalogue, and never a hardcoded
  /// launch-market list, so the picker can only ever offer a country that
  /// actually has data (naturally excluding Germany today — see the Step 2D
  /// data audit). Same shape as RestaurantWorlds50BestRepository.
  /// getCountries.
  Future<List<VenueCountry>> getCountries() async {
    final awardRows = await _client
        .from('gault_millau_awards')
        .select('restaurant_id');
    final restaurantIds = <String>{
      for (final row in awardRows as List) row['restaurant_id'] as String,
    };
    if (restaurantIds.isEmpty) return [];
    final restaurantRows = await _client
        .from('restaurants_full')
        .select('country_code')
        .inFilter('id', restaurantIds.toList());
    final presentCodes = <String>{
      for (final row in restaurantRows as List)
        if ((row['country_code'] as String?)?.isNotEmpty ?? false)
          row['country_code'] as String,
    };
    return resolveVenueCountries(_client, presentCodes);
  }
}
