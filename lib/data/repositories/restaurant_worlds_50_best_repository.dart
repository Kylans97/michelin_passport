import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/award_history_entry.dart' show Worlds50BestListType;
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;
import 'search_query.dart';
import 'worlds_50_best_ranking.dart';

/// One restaurant's position on an official World's 50 Best Restaurants
/// list for one year — the restaurant-side mirror of
/// HotelWorlds50BestRankingEntry (hotel_worlds_50_best_repository.dart).
/// Pairs the real, resolved Restaurant (so a tap opens
/// RestaurantDetailScreen directly) with the rank it held that year.
/// [rank] is nullable only because [HotelWorlds50BestRankingEntry] is, for
/// shape symmetry — in practice every entry this repository returns has a
/// non-null rank, since Hall of Fame rows (which carry a null rank; see
/// Worlds50BestListType.hallOfFame) are excluded upstream, both by the
/// server-side query and defensively in [buildRestaurantRankingEntries].
class RestaurantWorlds50BestRankingEntry {
  final Restaurant restaurant;
  final int? rank;
  final int year;
  final Worlds50BestListType listType;

  const RestaurantWorlds50BestRankingEntry({
    required this.restaurant,
    required this.rank,
    required this.year,
    required this.listType,
  });
}

/// Official World's 50 Best Restaurants rankings by year — the restaurant
/// counterpart of HotelWorlds50BestRepository, built for Guides Step 2C.
/// Reads directly from public.worlds_50_best (the authoritative annual-
/// snapshot table) rather than restaurants_full.worlds_50_best_rank, which
/// only ever exposes the single CURRENT year and can't support browsing
/// history — see the Guides Step 1/2C audits.
class RestaurantWorlds50BestRepository {
  RestaurantWorlds50BestRepository(this._client);

  final SupabaseClient _client;

  /// Years the app can offer in a year selector, descending, deduplicated —
  /// read live from worlds_50_best rather than hardcoded (unlike
  /// HotelWorlds50BestRepository.availableYears, which predates this
  /// screen's actual UI and hardcodes 2023-2025 for reasons documented on
  /// that constant). The list naturally has no 2020 entry (the cancelled
  /// edition) because no row exists for it — nothing here needs to special-
  /// case that year.
  Future<List<int>> getAvailableYears() async {
    final rows = await _client.from('worlds_50_best').select('year');
    final years = <int>{
      for (final row in rows as List) (row['year'] as num).toInt(),
    };
    return sortYearsDescending(years);
  }

  /// One year's ranking, resolved to real Restaurant rows (via
  /// restaurants_full, the same shared column list every other restaurant
  /// screen uses), sorted by rank ascending (#1 first). [query]/
  /// [countryCode] narrow the *resolved* restaurants — independent filters,
  /// combined with AND, mirroring RestaurantRepository.search()'s own
  /// query/country semantics exactly. Hall of Fame rows (null rank) are
  /// excluded server-side before the second query ever runs, so they never
  /// cost a restaurants_full lookup.
  ///
  /// Two queries total, never one per restaurant: the year's ranking rows,
  /// then one batched restaurants_full lookup via `.inFilter('id', ...)`.
  Future<List<RestaurantWorlds50BestRankingEntry>> getRanking({
    required int year,
    String query = '',
    String? countryCode,
  }) async {
    final rankingRows = await _client
        .from('worlds_50_best')
        .select('restaurant_id, rank, list_type')
        .eq('year', year)
        .not('rank', 'is', null)
        .order('rank', ascending: true);
    final rankingList = (rankingRows as List).cast<Map<String, dynamic>>();
    if (rankingList.isEmpty) return [];

    final restaurantIds = rankingList
        .map((row) => row['restaurant_id'] as String)
        .toSet();
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

    return buildRestaurantRankingEntries(
      rankingRows: rankingList,
      restaurantRows: (restaurantRows as List).cast<Map<String, dynamic>>(),
      year: year,
    );
  }

  /// Countries represented in [year]'s ranking specifically — never the
  /// entire restaurant catalogue — so the picker never offers a country
  /// with zero entries in the selected year. Same two-query batched shape
  /// as [getRanking]'s first half, sharing resolveVenueCountries() with
  /// every other catalogue's country picker.
  Future<List<VenueCountry>> getCountries(int year) async {
    final rankingRows = await _client
        .from('worlds_50_best')
        .select('restaurant_id')
        .eq('year', year)
        .not('rank', 'is', null);
    final restaurantIds = <String>{
      for (final row in rankingRows as List) row['restaurant_id'] as String,
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
