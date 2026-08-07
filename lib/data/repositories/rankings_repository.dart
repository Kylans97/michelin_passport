import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/ranking_entry.dart';
import '../../models/venue_entry.dart';
import 'visited_repository.dart';

class RankingsRepository {
  RankingsRepository(this._client);

  final SupabaseClient _client;

  // Source data for "My Rankings": every venue (restaurant or hotel) this
  // user has visited/stayed at, each paired with all of its visits/stays —
  // same shape My Passport is built from (see
  // VisitedRepository.loadPassportVenues). Fetched once; turning this into
  // ranking entries for a specific venue type + dimension + year is a pure,
  // client-side aggregation (buildPersonalRankings in
  // rankings_view_model.dart) so switching any of those doesn't require a
  // new query.
  Future<List<VenueEntry>> getPersonalRankingSource(String userId) {
    return VisitedRepository(_client).loadPassportVenues(userId);
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
