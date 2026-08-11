import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/venue_country.dart';
import '../../models/worlds_50_best_hotel_entry.dart';
import 'country_lookup.dart';
import 'hotel_repository.dart' show hotelFullColumns;
import 'search_query.dart';
import 'worlds_50_best_ranking.dart';

/// One hotel's position on an official World's 50 Best Hotels list for one
/// year — the repository-layer foundation for a future "official rankings"
/// screen (see the Rankings architecture note below). Pairs the real,
/// resolved Hotel (so a tap can open HotelDetailScreen directly, same as
/// every other ranking card in the app) with the rank it held that year.
class HotelWorlds50BestRankingEntry {
  final Hotel hotel;
  final int? rank;
  final int year;
  final HotelWorlds50BestListType listType;

  const HotelWorlds50BestRankingEntry({
    required this.hotel,
    required this.rank,
    required this.year,
    required this.listType,
  });
}

/// Official World's 50 Best Hotels rankings by year — distinct from
/// RankingsRepository, which serves "My Rankings" (personal, per-user
/// aggregation) and "Community" (public.restaurant_rankings, unrelated
/// user-rating data, restaurant-only). This is the third, genuinely
/// different kind of ranking: an external, official award list, with no
/// personal or community rating involved at all.
///
/// Where this belongs in the UI was originally left an open question (see
/// git history for this file's earlier "ARCHITECTURE NOTE") — resolved by
/// Guides Step 2C: FiftyBestHotelGuideScreen is this repository's first
/// real caller, under Guides rather than RankingsScreen, which stays
/// "My Rankings"/"Community" only. An official, externally-curated award
/// list belongs with Guides' other reference catalogues (Michelin
/// Restaurants/Hotels), not folded into either existing Rankings tab.
class HotelWorlds50BestRepository {
  HotelWorlds50BestRepository(this._client);

  final SupabaseClient _client;

  // Years the app should offer in a year selector — hardcoded to the years
  // actually researched and present in the source data (2023-2025) at the
  // time this repository was first built, never fabricated forward.
  // Superseded by [getAvailableYears] (Guides Step 2C), which reads the
  // real distinct years live instead — kept here unused rather than
  // deleted, since removing already-shipped code isn't this step's job and
  // nothing depends on it either way.
  static const availableYears = [2025, 2024, 2023];

  /// Years the app can offer in a year selector, descending, deduplicated —
  /// read live from worlds_50_best_hotels rather than the hardcoded
  /// [availableYears] above, per the Guides Step 2C brief's explicit "do
  /// not hard-code year ranges" requirement.
  Future<List<int>> getAvailableYears() async {
    final rows = await _client.from('worlds_50_best_hotels').select('year');
    final years = <int>{
      for (final row in rows as List) (row['year'] as num).toInt(),
    };
    return sortYearsDescending(years);
  }

  /// One year's list, resolved to real Hotel rows (via hotels_full, the
  /// same shared column list every other hotel screen uses), sorted by
  /// rank ascending (#1 first). [listType] is nullable and defaults to
  /// null, meaning "every list_type for the year" — Guides' World's 50
  /// Best Hotels catalogue (Step 2C) wants one continuous #1-#100 list,
  /// never a separate Top 50/Extended split (the source itself makes no
  /// such distinction to readers); pass a specific [listType] only if a
  /// future caller genuinely needs just one slice. [query]/[countryCode]
  /// narrow the *resolved* hotels — independent filters, combined with
  /// AND, mirroring HotelRepository.search()'s own query/country semantics.
  ///
  /// worlds_50_best_hotels is genuinely deployed and queryable today
  /// (confirmed via a live query during the Step 2C audit) — an earlier
  /// version of this file's docs described its prerequisite migrations as
  /// not yet applied remotely; that was accurate when written but is
  /// stale now, a reminder to verify against the live schema rather than
  /// trust an in-repo comment's age.
  Future<List<HotelWorlds50BestRankingEntry>> getRanking({
    required int year,
    HotelWorlds50BestListType? listType,
    String query = '',
    String? countryCode,
  }) async {
    var rankingBuilder = _client
        .from('worlds_50_best_hotels')
        .select('hotel_id, rank, year, list_type')
        .eq('year', year)
        .not('rank', 'is', null);
    if (listType != null) {
      rankingBuilder = rankingBuilder.eq('list_type', listType.dbValue);
    }
    final rankingRows = await rankingBuilder.order('rank', ascending: true);
    final rankingList = (rankingRows as List).cast<Map<String, dynamic>>();
    if (rankingList.isEmpty) return [];

    final hotelIds = rankingList.map((r) => r['hotel_id'] as String).toSet();
    var hotelBuilder = _client
        .from('hotels_full')
        .select(hotelFullColumns)
        .inFilter('id', hotelIds.toList());
    final orFilter = buildIlikeOrFilter(query, [
      'name',
      'city_name',
      'country_name',
    ]);
    if (orFilter != null) {
      hotelBuilder = hotelBuilder.or(orFilter);
    }
    if (countryCode != null) {
      hotelBuilder = hotelBuilder.eq('country_code', countryCode);
    }
    final hotelRows = await hotelBuilder;

    return buildHotelRankingEntries(
      rankingRows: rankingList,
      hotelRows: (hotelRows as List).cast<Map<String, dynamic>>(),
      year: year,
    );
  }

  /// Countries represented in [year]'s ranking specifically — mirrors
  /// RestaurantWorlds50BestRepository.getCountries exactly.
  Future<List<VenueCountry>> getCountries(int year) async {
    final rankingRows = await _client
        .from('worlds_50_best_hotels')
        .select('hotel_id')
        .eq('year', year)
        .not('rank', 'is', null);
    final hotelIds = <String>{
      for (final row in rankingRows as List) row['hotel_id'] as String,
    };
    if (hotelIds.isEmpty) return [];
    final hotelRows = await _client
        .from('hotels_full')
        .select('country_code')
        .inFilter('id', hotelIds.toList());
    final presentCodes = <String>{
      for (final row in hotelRows as List)
        if ((row['country_code'] as String?)?.isNotEmpty ?? false)
          row['country_code'] as String,
    };
    return resolveVenueCountries(_client, presentCodes);
  }
}
