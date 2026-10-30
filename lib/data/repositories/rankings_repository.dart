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

  /// Community Rankings' full list for one [kind], with the recognition
  /// [filter] applied in SQL. Restaurants read `restaurant_rankings`;
  /// hotels and events read `hotel_rankings` / `event_rankings`
  /// (20261030160000). Every view returns aggregates only, from 3 members.
  ///
  /// Until 20261030160000 is applied the two new views don't exist and
  /// restaurant_rankings lacks the appended columns: restaurants then fall
  /// back to the original column list (no photo, no World's 50 Best
  /// filter), and hotels/events come back empty — the screen's own empty
  /// state, never an error over the whole tab.
  Future<List<CommunityRankedVenue>> getCommunityRanking({
    required CommunityRankingKind kind,
    CommunityRecognitionFilter filter = CommunityRecognitionFilter.all,
  }) async {
    switch (kind) {
      case CommunityRankingKind.restaurants:
        try {
          return await _restaurantRanking(filter, _restaurantColumns);
        } on PostgrestException {
          if (filter == CommunityRecognitionFilter.worlds50Best) return [];
          return _restaurantRanking(filter, _legacyRestaurantColumns);
        }
      case CommunityRankingKind.hotels:
        try {
          var builder = _client.from('hotel_rankings').select(_hotelColumns);
          builder = switch (filter) {
            CommunityRecognitionFilter.all => builder,
            CommunityRecognitionFilter.worlds50Best => builder.not(
              'worlds_50_best_rank',
              'is',
              null,
            ),
            _ => builder.eq('michelin_keys', _count(filter)),
          };
          final rows = await builder
              .order('community_rating', ascending: false)
              .order('total_stays', ascending: false);
          return [
            for (final row in (rows as List).cast<Map<String, dynamic>>())
              CommunityRankedVenue.hotelFromJson(row),
          ];
        } on PostgrestException {
          return [];
        }
      case CommunityRankingKind.events:
        try {
          final rows = await _client
              .from('event_rankings')
              .select(_eventColumns)
              .order('community_rating', ascending: false)
              .order('total_attendees', ascending: false);
          return [
            for (final row in (rows as List).cast<Map<String, dynamic>>())
              CommunityRankedVenue.eventFromJson(row),
          ];
        } on PostgrestException {
          return [];
        }
    }
  }

  static const _legacyRestaurantColumns =
      'restaurant_id, name, city, country_flag, michelin_stars, '
      'community_rating, total_visits';
  static const _restaurantColumns =
      '$_legacyRestaurantColumns, worlds_50_best_rank, card_photo_url, '
      'card_focus_x, card_focus_y, card_zoom';
  static const _hotelColumns =
      'hotel_id, name, city, country_flag, michelin_keys, '
      'worlds_50_best_rank, community_rating, total_stays, card_photo_url, '
      'card_focus_x, card_focus_y, card_zoom';
  static const _eventColumns =
      'event_id, name, city, country_code, start_date, end_date, image_url, '
      'community_rating, total_attendees';

  static int _count(CommunityRecognitionFilter filter) => switch (filter) {
    CommunityRecognitionFilter.one => 1,
    CommunityRecognitionFilter.two => 2,
    CommunityRecognitionFilter.three => 3,
    _ => 0,
  };

  Future<List<CommunityRankedVenue>> _restaurantRanking(
    CommunityRecognitionFilter filter,
    String columns,
  ) async {
    var builder = _client.from('restaurant_rankings').select(columns);
    builder = switch (filter) {
      CommunityRecognitionFilter.all => builder,
      CommunityRecognitionFilter.worlds50Best => builder.not(
        'worlds_50_best_rank',
        'is',
        null,
      ),
      _ => builder.eq('michelin_stars', _count(filter)),
    };
    final rows = await builder
        .order('community_rating', ascending: false)
        .order('total_visits', ascending: false);
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        CommunityRankedVenue.restaurantFromJson(row),
    ];
  }
}
