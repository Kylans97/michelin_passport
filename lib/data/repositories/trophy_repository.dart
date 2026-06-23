import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/trophy.dart';
import '../../models/restaurant.dart';
import '../../models/visited_restaurant.dart';

class TrophyRepository {
  TrophyRepository(this._client);

  final SupabaseClient _client;

  // Returns all trophies, merged with which ones the user has earned.
  Future<List<Trophy>> getAllTrophies(String userId) async {
    final trophiesRows = await _client.from('trophies').select().order('category').order('key');
    final earnedRows = await _client
        .from('user_trophies')
        .select('trophy_key, earned_at')
        .eq('user_id', userId);

    final earnedMap = <String, DateTime>{};
    for (final row in earnedRows as List) {
      final key = row['trophy_key'] as String;
      final at = DateTime.tryParse(row['earned_at'] as String? ?? '');
      if (at != null) earnedMap[key] = at;
    }

    return (trophiesRows as List).map((row) {
      final trophyRow = row as Map<String, dynamic>;
      return Trophy.fromRow(
        trophyRow: trophyRow,
        earnedAt: earnedMap[trophyRow['key']],
      );
    }).toList();
  }

  // Checks trophy conditions after a new visit and awards any newly earned trophies.
  // Returns the list of newly earned Trophy objects to show in the popup.
  Future<List<Trophy>> checkAndAward({
    required String userId,
    required Restaurant justVisited,
    required double? personalRating,
    required List<VisitedRestaurant> allVisited,
  }) async {
    // Load already-earned trophy keys to avoid re-awarding.
    final earnedRows = await _client
        .from('user_trophies')
        .select('trophy_key')
        .eq('user_id', userId);
    final alreadyEarned = {for (final r in earnedRows as List) r['trophy_key'] as String};

    final toAward = <String>[];
    final allRestaurants = allVisited.map((v) => v.restaurant).toList();
    final visitCount = allRestaurants.length;

    // ── Milestone: first star visits ──────────────────────────────────────────
    if (justVisited.michelinStars == 1 &&
        allRestaurants.where((r) => r.michelinStars == 1).length == 1) {
      toAward.add('first_one_star');
    }
    if (justVisited.michelinStars == 2 &&
        allRestaurants.where((r) => r.michelinStars == 2).length == 1) {
      toAward.add('first_two_star');
    }
    if (justVisited.michelinStars == 3 &&
        allRestaurants.where((r) => r.michelinStars == 3).length == 1) {
      toAward.add('first_three_star');
    }

    // ── Milestone: visit counts ───────────────────────────────────────────────
    for (final milestone in [5, 15, 30, 50, 75, 100, 150, 200]) {
      if (visitCount == milestone) toAward.add('visits_$milestone');
    }

    // ── Milestone: perfect ten ────────────────────────────────────────────────
    if (personalRating != null && personalRating == 10.0) {
      toAward.add('perfect_ten');
    }

    // ── Milestone: cuisine explorer ───────────────────────────────────────────
    final uniqueCuisines = allRestaurants.map((r) => r.cuisine).toSet();
    if (uniqueCuisines.length == 10) toAward.add('cuisine_explorer');

    // ── Travel: country counts ────────────────────────────────────────────────
    final uniqueCountries = allRestaurants.map((r) => r.country).toSet();
    for (final threshold in [5, 10, 20]) {
      if (uniqueCountries.length == threshold) toAward.add('countries_$threshold');
    }

    // ── Country complete trophies ─────────────────────────────────────────────
    final countryMap = {
      'Netherlands': 'nl',
      'France': 'fr',
      'Italy': 'it',
      'Spain': 'es',
      'Japan': 'jp',
      'United Kingdom': 'uk',
      'Germany': 'de',
      'Belgium': 'be',
      'United States': 'us',
    };

    // Only check the country of the restaurant just visited.
    final countryCode = countryMap[justVisited.country];
    if (countryCode != null) {
      // Get total counts for this country from the DB.
      final totalRows = await _client
          .from('restaurants')
          .select('michelin_stars')
          .eq('country', justVisited.country);
      final totals = <int, int>{};
      for (final r in totalRows as List) {
        final stars = (r['michelin_stars'] as int?) ?? 0;
        totals[stars] = (totals[stars] ?? 0) + 1;
      }
      final totalAll = totalRows.length;

      // Count user's visited in this country.
      final visitedInCountry =
          allRestaurants.where((r) => r.country == justVisited.country).toList();
      final visitedByStars = <int, int>{};
      for (final r in visitedInCountry) {
        visitedByStars[r.michelinStars] = (visitedByStars[r.michelinStars] ?? 0) + 1;
      }

      for (final stars in [1, 2, 3]) {
        final total = totals[stars] ?? 0;
        final visited = visitedByStars[stars] ?? 0;
        if (total > 0 && visited == total) {
          toAward.add('${countryCode}_${stars}star_complete');
        }
      }
      if (totalAll > 0 && visitedInCountry.length == totalAll) {
        toAward.add('${countryCode}_legend');
      }
    }

    // Filter out already earned and newly duplicate candidates.
    final newKeys = toAward.where((k) => !alreadyEarned.contains(k)).toSet().toList();
    if (newKeys.isEmpty) return [];

    // Fetch trophy details for newly earned ones.
    final trophyRows = await _client
        .from('trophies')
        .select()
        .inFilter('key', newKeys);

    final now = DateTime.now();
    final awarded = <Trophy>[];
    for (final row in trophyRows as List) {
      final trophy = Trophy.fromRow(trophyRow: row as Map<String, dynamic>, earnedAt: now);
      awarded.add(trophy);
      try {
        await _client.from('user_trophies').insert({
          'user_id': userId,
          'trophy_key': trophy.key,
          'earned_at': now.toIso8601String(),
        });
      } catch (_) {
        // Ignore duplicate inserts.
      }
    }

    return awarded;
  }

  // Awards a social trophy by key, if not already earned.
  Future<Trophy?> awardSocialTrophy(String userId, String key) async {
    final existing = await _client
        .from('user_trophies')
        .select('trophy_key')
        .eq('user_id', userId)
        .eq('trophy_key', key)
        .limit(1);
    if ((existing as List).isNotEmpty) return null;

    final trophyRows = await _client.from('trophies').select().eq('key', key).limit(1);
    if ((trophyRows as List).isEmpty) return null;

    final now = DateTime.now();
    try {
      await _client.from('user_trophies').insert({
        'user_id': userId,
        'trophy_key': key,
        'earned_at': now.toIso8601String(),
      });
    } catch (_) {
      return null;
    }

    return Trophy.fromRow(trophyRow: trophyRows.first as Map<String, dynamic>, earnedAt: now);
  }
}
