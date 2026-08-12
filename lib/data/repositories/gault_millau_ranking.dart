// Pure row-merging/ordering logic for Gault&Millau's guide catalogue —
// factored out of RestaurantGaultMillauRepository for the same reason
// worlds_50_best_ranking.dart is factored out of *Worlds50BestRepository
// (see that file's own doc): the repository can't be exercised in a
// widget/unit test without a live Supabase session, but the row-shape
// transform its query results feed into can be tested directly with
// constructed fixture JSON.

import '../../models/gault_millau_award.dart';
import '../../models/restaurant.dart';
import 'restaurant_gault_millau_repository.dart'
    show RestaurantGaultMillauEntry;

/// Reduces every `gault_millau_awards` row for a restaurant down to the one
/// with the highest `guide_year` — the "latest available recognition per
/// restaurant" rule the Guides Step 2D brief calls for. Production carries
/// exactly one row per restaurant today (a single 2026 edition; see the
/// Step 2D data audit), so this is currently a no-op in practice, but it is
/// written to handle multiple editions correctly from day one rather than
/// assuming today's shape is permanent — a restaurant re-scored in a future
/// edition must never appear twice in one flat catalogue list.
List<GaultMillauAward> latestGaultMillauAwardPerRestaurant(
  List<Map<String, dynamic>> rawRows,
) {
  final byRestaurant = <String, GaultMillauAward>{};
  for (final row in rawRows) {
    final award = GaultMillauAward.fromJson(row);
    final existing = byRestaurant[award.restaurantId];
    if (existing == null || award.guideYear > existing.guideYear) {
      byRestaurant[award.restaurantId] = award;
    }
  }
  return byRestaurant.values.toList();
}

/// Joins the latest-per-restaurant award rows to their resolved Restaurant
/// rows. An award whose restaurant isn't present in [restaurantRows]
/// (filtered out by a search/country condition on the second query, or —
/// in principle — an orphaned FK) is silently dropped rather than crashed
/// on, mirroring buildRestaurantRankingEntries' identical defensive
/// contract.
List<RestaurantGaultMillauEntry> buildGaultMillauEntries({
  required List<Map<String, dynamic>> rawAwardRows,
  required List<Map<String, dynamic>> restaurantRows,
}) {
  final restaurantsById = {
    for (final row in restaurantRows)
      row['id'].toString(): Restaurant.fromJson(row),
  };
  final latest = latestGaultMillauAwardPerRestaurant(rawAwardRows);
  return [
    for (final award in latest)
      if (restaurantsById[award.restaurantId] != null)
        RestaurantGaultMillauEntry(
          restaurant: restaurantsById[award.restaurantId]!,
          award: award,
        ),
  ];
}

/// Result order: stronger recognition first, then name alphabetically —
/// the Step 2D brief's preferred logic. Safe to compare `score` across every
/// country in today's data because Gault&Millau's 0-20 scale is the SAME
/// scale in every market that publishes one (France/Netherlands/Belgium/
/// Switzerland/Austria — see the schema migration's own comment); this
/// isn't true of, say, Michelin stars vs. Keys, so this rule would need
/// revisiting if a structurally different scale ever entered this
/// catalogue. A null score (a future unscored_top_tier/unscored_casual row,
/// or a toque-only market) sorts after every scored entry rather than being
/// coerced to 0 — among null-score entries, a higher toqueCount still sorts
/// first, then name. This degrades gracefully for data shapes production
/// doesn't have yet without ever comparing incompatible systems as if they
/// were the same number.
List<RestaurantGaultMillauEntry> sortGaultMillauEntries(
  List<RestaurantGaultMillauEntry> entries,
) {
  final sorted = List<RestaurantGaultMillauEntry>.of(entries);
  sorted.sort((a, b) {
    final aScore = a.award.score;
    final bScore = b.award.score;
    if (aScore != null && bScore != null) {
      final scoreCompare = bScore.compareTo(aScore);
      if (scoreCompare != 0) return scoreCompare;
    } else if (aScore != null || bScore != null) {
      // Exactly one has a score — the scored one sorts first.
      return aScore != null ? -1 : 1;
    }
    final aToque = a.award.toqueCount ?? -1;
    final bToque = b.award.toqueCount ?? -1;
    final toqueCompare = bToque.compareTo(aToque);
    if (toqueCompare != 0) return toqueCompare;
    return a.restaurant.name.compareTo(b.restaurant.name);
  });
  return sorted;
}
