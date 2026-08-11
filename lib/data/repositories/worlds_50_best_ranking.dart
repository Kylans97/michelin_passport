// Pure row-merging logic shared by RestaurantWorlds50BestRepository and
// HotelWorlds50BestRepository — deliberately factored out of both (rather
// than inlined in each `getRanking()`) so it's testable without Supabase,
// mirroring guide_view_model.dart's own reasoning for
// sortGuideRestaurants/sortGuideHotels (Step 2B): neither repository can
// itself be exercised in a widget/unit test without a live session, but
// the row-shape transform their query results feed into can be tested
// directly with constructed fixture JSON.
//
// Lives in lib/data/repositories/ (not lib/features/guides/) because it
// operates on raw PostgREST row maps and produces repository-return types
// — a data-layer concern, the same layer Restaurant.fromJson/
// Hotel.fromJson and buildIlikeOrFilter/resolveVenueCountries already live
// in, not a screen-facing one.

import '../../models/award_history_entry.dart' show Worlds50BestListType;
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../../models/worlds_50_best_hotel_entry.dart'
    show HotelWorlds50BestListType;
import 'hotel_worlds_50_best_repository.dart'
    show HotelWorlds50BestRankingEntry;
import 'restaurant_worlds_50_best_repository.dart'
    show RestaurantWorlds50BestRankingEntry;

/// Builds ranked restaurant entries from a year's raw `worlds_50_best` rows
/// and the resolved `restaurants_full` rows for the restaurants present in
/// them. Any ranking row with a null [rank] (Hall of Fame — see
/// [Worlds50BestListType.hallOfFame], which has no numeric position) is
/// excluded — a defensive second filter alongside the server-side
/// `.not('rank', 'is', null)` in RestaurantWorlds50BestRepository.getRanking,
/// so Hall of Fame can never leak into a ranked list even if a future
/// caller forgets that server-side filter. A ranking row whose restaurant
/// isn't present in [restaurantRows] (filtered out by a search/country
/// condition on the second query) is silently dropped rather than crashing
/// — that's the search/country filter doing its job, not a data error.
List<RestaurantWorlds50BestRankingEntry> buildRestaurantRankingEntries({
  required List<Map<String, dynamic>> rankingRows,
  required List<Map<String, dynamic>> restaurantRows,
  required int year,
}) {
  final restaurantsById = {
    for (final row in restaurantRows)
      row['id'].toString(): Restaurant.fromJson(row),
  };
  final entries = <RestaurantWorlds50BestRankingEntry>[
    for (final row in rankingRows)
      if (row['rank'] != null &&
          restaurantsById[row['restaurant_id'] as String] != null)
        RestaurantWorlds50BestRankingEntry(
          restaurant: restaurantsById[row['restaurant_id'] as String]!,
          rank: (row['rank'] as num).toInt(),
          year: year,
          listType:
              Worlds50BestListType.fromDbValue(row['list_type'] as String?) ??
              Worlds50BestListType.topFifty,
        ),
  ];
  entries.sort((a, b) => a.rank!.compareTo(b.rank!));
  return entries;
}

/// The hotel mirror of [buildRestaurantRankingEntries] — see that
/// function's doc for the full reasoning, identical here except hotels
/// have no Hall of Fame list_type at all (see [HotelWorlds50BestListType]),
/// so the null-rank guard exists purely as defensive symmetry with the
/// restaurant version and the schema's own nullable `rank` column, not
/// because hotel data is expected to ever produce one today.
List<HotelWorlds50BestRankingEntry> buildHotelRankingEntries({
  required List<Map<String, dynamic>> rankingRows,
  required List<Map<String, dynamic>> hotelRows,
  required int year,
}) {
  final hotelsById = {
    for (final row in hotelRows) row['id'].toString(): Hotel.fromJson(row),
  };
  final entries = <HotelWorlds50BestRankingEntry>[
    for (final row in rankingRows)
      if (row['rank'] != null && hotelsById[row['hotel_id'] as String] != null)
        HotelWorlds50BestRankingEntry(
          hotel: hotelsById[row['hotel_id'] as String]!,
          rank: (row['rank'] as num).toInt(),
          year: year,
          listType:
              HotelWorlds50BestListType.fromDbValue(
                row['list_type'] as String?,
              ) ??
              HotelWorlds50BestListType.topFifty,
        ),
  ];
  entries.sort((a, b) => a.rank!.compareTo(b.rank!));
  return entries;
}

/// Deduplicated, descending year list — the shared "years for a Year
/// selector" shape both RestaurantWorlds50BestRepository.getAvailableYears
/// and HotelWorlds50BestRepository.getAvailableYears reduce their raw query
/// results to.
List<int> sortYearsDescending(Iterable<int> years) {
  final unique = years.toSet().toList();
  unique.sort((a, b) => b.compareTo(a));
  return unique;
}
