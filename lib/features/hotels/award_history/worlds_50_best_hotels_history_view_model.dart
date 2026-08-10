import '../../../models/worlds_50_best_hotel_entry.dart';

/// The historical World's 50 Best Hotels reading of one hotel's raw
/// [HotelWorlds50BestEntry] rows, split by list_type — mirrors
/// Worlds50BestHistorySummary (restaurants) with one structural
/// difference: there is no hallOfFameYear field at all, because there is no
/// Hall of Fame concept for hotels. That's not a value that's merely left
/// null here — the type itself has no place to put one, so a hotel Award
/// History screen built against this class cannot accidentally grow a
/// Hall of Fame block.
class HotelWorlds50BestHistorySummary {
  // Newest year first, matching the list's own display order.
  final List<HotelWorlds50BestEntry> topFiftyYears;
  final List<HotelWorlds50BestEntry> extendedYears;

  const HotelWorlds50BestHistorySummary({
    required this.topFiftyYears,
    required this.extendedYears,
  });

  /// Number of years actually ranked in the Top 50 — never fabricated for
  /// gaps between years.
  int get appearances => topFiftyYears.length;

  /// Lowest (best) numerical rank among Top 50 appearances, or null if
  /// there are none.
  int? get bestRank {
    if (topFiftyYears.isEmpty) return null;
    return topFiftyYears
        .map((e) => e.rank)
        .whereType<int>()
        .fold<int?>(null, (best, r) => best == null || r < best ? r : best);
  }

  bool get isEmpty => topFiftyYears.isEmpty && extendedYears.isEmpty;

  factory HotelWorlds50BestHistorySummary.of(
    List<HotelWorlds50BestEntry> rows,
  ) {
    final topFifty = [
      for (final e in rows)
        if (e.listType == HotelWorlds50BestListType.topFifty) e,
    ]..sort((a, b) => b.year.compareTo(a.year));
    final extended = [
      for (final e in rows)
        if (e.listType == HotelWorlds50BestListType.extended) e,
    ]..sort((a, b) => b.year.compareTo(a.year));

    return HotelWorlds50BestHistorySummary(
      topFiftyYears: topFifty,
      extendedYears: extended,
    );
  }
}
