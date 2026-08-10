import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/worlds_50_best_hotel_entry.dart';
import 'hotel_repository.dart' show hotelFullColumns;

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

/// Official World's 50 Best Hotels rankings by year/list_type — distinct
/// from RankingsRepository, which serves "My Rankings" (personal,
/// per-user aggregation) and "Community" (public.restaurant_rankings,
/// unrelated user-rating data, restaurant-only). This is the third,
/// genuinely different kind of ranking: an external, official award list,
/// with no personal or community rating involved at all.
///
/// ARCHITECTURE NOTE — where this belongs in the UI is not decided here.
/// RankingsScreen currently has exactly two tabs, "My Rankings" and
/// "Community" (lib/features/rankings/rankings_screen.dart) — "Community"
/// is restaurant-only user-rating data (public.restaurant_rankings) and is
/// not the right home for an official, externally-curated award list;
/// forcing this into either existing tab would misrepresent what both
/// currently mean. Per the task scope for this pass, only this
/// repository/model foundation is built — the actual screen/tab is left
/// for a follow-up decision. See phase-report section 8 for the full
/// reasoning.
class HotelWorlds50BestRepository {
  HotelWorlds50BestRepository(this._client);

  final SupabaseClient _client;

  // Years the app should offer in a year selector — hardcoded to the years
  // actually researched and present in the source data (2023-2025), never
  // fabricated forward. A future year's data arriving is a data change, not
  // a code change: this list intentionally does NOT compute "current year"
  // or extrapolate — see the task guardrail against inventing a hardcoded
  // "current year" concept for a list that only publishes annually and
  // irregularly.
  static const availableYears = [2025, 2024, 2023];

  /// One year's list, resolved to real Hotel rows (via hotels_full, the
  /// same shared column list — and the same NOT-yet-exposed
  /// worlds_50_best_rank/year limitation — every other hotel screen uses),
  /// sorted by rank ascending (#1 first). [listType] defaults to the
  /// numbered Top 50; pass extended to get the 51-100 list, which per the
  /// source data only exists for 2025.
  ///
  /// Requires both prerequisite migrations
  /// (20260807150000_hotel_michelin_keys_nullable.sql,
  /// 20260807160000_create_worlds_50_best_hotels.sql) to be applied on the
  /// target — neither is applied remotely yet, so this throws against the
  /// current production schema exactly like HotelRepository.search(
  /// worlds50BestOnly: true) does. The code is ready; the data layer isn't
  /// deployed.
  Future<List<HotelWorlds50BestRankingEntry>> getRanking({
    required int year,
    HotelWorlds50BestListType listType = HotelWorlds50BestListType.topFifty,
  }) async {
    final rankingRows = await _client
        .from('worlds_50_best_hotels')
        .select('hotel_id, rank, year, list_type')
        .eq('year', year)
        .eq('list_type', listType.dbValue)
        .order('rank', ascending: true);
    final rankingList = (rankingRows as List).cast<Map<String, dynamic>>();
    if (rankingList.isEmpty) return [];

    final hotelIds = rankingList.map((r) => r['hotel_id'] as String).toSet();
    final hotelRows = await _client
        .from('hotels_full')
        .select(hotelFullColumns)
        .inFilter('id', hotelIds.toList());
    final hotelsById = {
      for (final row in hotelRows as List)
        (row['id'] as String): Hotel.fromJson(row as Map<String, dynamic>),
    };

    return [
      for (final row in rankingList)
        if (hotelsById[row['hotel_id'] as String] != null)
          HotelWorlds50BestRankingEntry(
            hotel: hotelsById[row['hotel_id'] as String]!,
            rank: (row['rank'] as num?)?.toInt(),
            year: (row['year'] as num).toInt(),
            listType: listType,
          ),
    ];
  }
}
