import '../../../models/award_history_entry.dart';

/// The historical World's 50 Best reading of one restaurant's raw
/// [Worlds50BestHistoryEntry] rows, split by list_type per the product
/// rule: Top 50 appearances/best-rank are computed only from `top_50` rows,
/// the extended 51-100 list is kept separate, and Hall of Fame is a
/// distinct achievement — never collapsed into a rank.
class Worlds50BestHistorySummary {
  // Newest year first, matching the list's own display order.
  final List<Worlds50BestHistoryEntry> topFiftyYears;
  final List<Worlds50BestHistoryEntry> extendedYears;

  // The induction year, if this restaurant has ever been marked Hall of
  // Fame. Null if not — never inferred from a strong ranking, only ever
  // read directly from a real hall_of_fame row.
  final int? hallOfFameYear;

  const Worlds50BestHistorySummary({
    required this.topFiftyYears,
    required this.extendedYears,
    required this.hallOfFameYear,
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

  bool get isEmpty =>
      topFiftyYears.isEmpty && extendedYears.isEmpty && hallOfFameYear == null;

  factory Worlds50BestHistorySummary.of(List<Worlds50BestHistoryEntry> rows) {
    final topFifty = [
      for (final e in rows)
        if (e.listType == Worlds50BestListType.topFifty) e,
    ]..sort((a, b) => b.year.compareTo(a.year));
    final extended = [
      for (final e in rows)
        if (e.listType == Worlds50BestListType.extended) e,
    ]..sort((a, b) => b.year.compareTo(a.year));
    final hallOfFameYears = [
      for (final e in rows)
        if (e.listType == Worlds50BestListType.hallOfFame) e.year,
    ];
    // A restaurant is inducted once; if data ever carries more than one
    // hall_of_fame row, the earliest year is the actual induction moment.
    final hallOfFameYear = hallOfFameYears.isEmpty
        ? null
        : hallOfFameYears.reduce((a, b) => a < b ? a : b);

    return Worlds50BestHistorySummary(
      topFiftyYears: topFifty,
      extendedYears: extended,
      hallOfFameYear: hallOfFameYear,
    );
  }
}
