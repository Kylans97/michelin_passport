import '../../models/passport_entry.dart';
import '../../models/restaurant.dart';
import '../../models/visit.dart';

/// Every year that has at least one visit, newest first. Never hardcoded —
/// derived from the user's actual visited_on values so a year only appears
/// once a visit exists in it.
List<int> availablePassportYears(List<PassportEntry> entries) {
  final years = entries
      .expand((entry) => entry.visits)
      .map((visit) => visit.visitedOn.year)
      .toSet()
      .toList();
  years.sort((a, b) => b.compareTo(a));
  return years;
}

/// One restaurant's stats for the currently selected year (or all time).
/// [visitCount], [latestVisit] and [averageRating] only ever reflect the
/// visits that fall inside the active filter — never the restaurant's full
/// history, which remains reachable in full via Restaurant Detail
/// regardless of what Passport is currently filtered to.
class PassportRestaurantStats {
  final Restaurant restaurant;
  final int visitCount;
  final DateTime latestVisit;

  // Arithmetic mean of the non-null overall ratings among the filtered
  // visits. Null when none of them were rated — never coerced to 0.
  final double? averageRating;

  // stars_at_visit from this restaurant's most recent visit within the
  // filtered period (never the restaurant's current michelin_stars). A
  // restaurant is one venue, so its stars are counted once here regardless
  // of how many times it was visited in the period — the passport-wide
  // "Stars" total sums this per-restaurant value, not per-visit.
  final int starsExperienced;

  const PassportRestaurantStats._({
    required this.restaurant,
    required this.visitCount,
    required this.latestVisit,
    required this.averageRating,
    required this.starsExperienced,
  });

  factory PassportRestaurantStats.from(
    Restaurant restaurant,
    List<Visit> visitsInPeriod,
  ) {
    final ratings = [
      for (final visit in visitsInPeriod)
        if (visit.rating != null) visit.rating!,
    ];
    final mostRecentVisit = visitsInPeriod.reduce(
      (a, b) => a.visitedOn.isAfter(b.visitedOn) ? a : b,
    );
    return PassportRestaurantStats._(
      restaurant: restaurant,
      visitCount: visitsInPeriod.length,
      latestVisit: mostRecentVisit.visitedOn,
      averageRating: ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length,
      starsExperienced: mostRecentVisit.starsAtVisit ?? 0,
    );
  }
}

/// Passport-wide totals for the active filter.
class PassportSummary {
  final int restaurantsVisited;

  // Sum of each unique restaurant's stars (from its most recent visit in
  // the period) — not per-visit. A restaurant with 1 star visited 3 times
  // contributes 1, not 3.
  final int michelinStarsExperienced;
  final int countriesVisited;

  const PassportSummary({
    required this.restaurantsVisited,
    required this.michelinStarsExperienced,
    required this.countriesVisited,
  });
}

/// The Passport view for one filter selection: the restaurants that had at
/// least one visit in [year] (all of them when [year] is null), each with
/// its own stats scoped to that same period, plus the passport-wide summary.
class PassportFilterResult {
  final List<PassportRestaurantStats> entries;
  final PassportSummary summary;

  const PassportFilterResult({required this.entries, required this.summary});

  factory PassportFilterResult.of(List<PassportEntry> allEntries, int? year) {
    final stats = <PassportRestaurantStats>[];
    for (final entry in allEntries) {
      final visitsInPeriod = entry.visitsInYear(year);
      if (visitsInPeriod.isEmpty) continue;
      stats.add(PassportRestaurantStats.from(entry.restaurant, visitsInPeriod));
    }
    // Most recently visited (within the active period) first.
    stats.sort((a, b) => b.latestVisit.compareTo(a.latestVisit));

    final starsExperienced = stats.fold<int>(
      0,
      (sum, s) => sum + s.starsExperienced,
    );
    final countries = stats.map((s) => s.restaurant.countryCode).toSet().length;

    return PassportFilterResult(
      entries: stats,
      summary: PassportSummary(
        restaurantsVisited: stats.length,
        michelinStarsExperienced: starsExperienced,
        countriesVisited: countries,
      ),
    );
  }
}
