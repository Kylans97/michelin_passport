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

  /// Community Rankings' full list for one [kind], best first. Country
  /// and recognition filters are applied in the app
  /// ([applyCommunityFilters]); the lists only hold venues with 3+
  /// members. Restaurants read `restaurant_rankings`, hotels and events
  /// `hotel_rankings` / `event_rankings` (20261030160000).
  ///
  /// Each read tries the newest column set first and steps back on a
  /// PostgREST error, so the screen works before 20261030180000
  /// (country_code) is applied — the country filter simply has nothing to
  /// offer then — and restaurants still load on a database without
  /// 20261030160000 at all.
  Future<List<CommunityRankedVenue>> getCommunityRanking(
    CommunityRankingKind kind,
  ) async {
    switch (kind) {
      case CommunityRankingKind.restaurants:
        return _firstThatLoads(
          'restaurant_rankings',
          const [
            '$_restaurantColumns, country_code',
            _restaurantColumns,
            _legacyRestaurantColumns,
          ],
          'total_visits',
          CommunityRankedVenue.restaurantFromJson,
        );
      case CommunityRankingKind.hotels:
        return _firstThatLoads(
          'hotel_rankings',
          const ['$_hotelColumns, country_code', _hotelColumns],
          'total_stays',
          CommunityRankedVenue.hotelFromJson,
        );
      case CommunityRankingKind.events:
        return _firstThatLoads(
          'event_rankings',
          const [_eventColumns],
          'total_attendees',
          CommunityRankedVenue.eventFromJson,
        );
    }
  }

  Future<List<CommunityRankedVenue>> _firstThatLoads(
    String view,
    List<String> columnSets,
    String countColumn,
    CommunityRankedVenue Function(Map<String, dynamic>) fromJson,
  ) async {
    for (final columns in columnSets) {
      try {
        final rows = await _client
            .from(view)
            .select(columns)
            .order('community_rating', ascending: false)
            .order(countColumn, ascending: false);
        return [
          for (final row in (rows as List).cast<Map<String, dynamic>>())
            fromJson(row),
        ];
      } on PostgrestException {
        continue;
      }
    }
    return [];
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
}
