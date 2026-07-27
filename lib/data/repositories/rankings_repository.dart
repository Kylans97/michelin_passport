import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/ranking_entry.dart';
import 'visited_repository.dart';

class RankingsRepository {
  RankingsRepository(this._client);

  final SupabaseClient _client;

  // Personal rankings: visited restaurants sorted by personal_rating desc.
  // Optionally filtered by michelin_stars.
  Future<List<PersonalRankingEntry>> getPersonalRankings(
    String userId, {
    int? stars,
  }) async {
    final visited = await VisitedRepository(
      _client,
    ).getVisitedWithRatings(userId);
    var entries = visited
        .where((v) => v.personalRating != null)
        .map(
          (v) => PersonalRankingEntry(
            restaurant: v.restaurant,
            personalRating: v.personalRating!,
            visitedAt: v.visitedAt,
          ),
        )
        .toList();

    if (stars != null) {
      entries = entries
          .where((e) => e.restaurant.michelinStars == stars)
          .toList();
    }

    entries.sort((a, b) => b.personalRating.compareTo(a.personalRating));
    return entries;
  }

  // Community rankings from the restaurant_rankings view, optionally filtered by stars.
  Future<List<CommunityRankingEntry>> getCommunityRankings({int? stars}) async {
    var builder = _client
        .from('restaurant_rankings')
        .select(
          'restaurant_id, name, city, country_flag, michelin_stars, community_rating, total_visits',
        );

    if (stars != null) {
      builder = builder.eq('michelin_stars', stars);
    }

    final rows = await builder.order('community_rating', ascending: false);
    return (rows as List)
        .map(
          (row) => CommunityRankingEntry.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }
}
