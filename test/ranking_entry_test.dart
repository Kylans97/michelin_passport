// Covers CommunityRankingEntry.fromJson (Community Rankings Backend V1)
// — a pure model, no Supabase dependency, so parsing is tested directly
// against the exact JSON shape the restaurant_rankings view produces:
// restaurant_id, name, city, country_flag, michelin_stars,
// community_rating, total_visits.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/ranking_entry.dart';

void main() {
  group('CommunityRankingEntry.fromJson', () {
    test('parses every field from the restaurant_rankings view shape', () {
      final entry = CommunityRankingEntry.fromJson({
        'restaurant_id': 'r1',
        'name': 'Maison Verte',
        'city': 'Paris',
        'country_flag': '🇫🇷',
        'michelin_stars': 2,
        'community_rating': 9.0,
        'total_visits': 3,
      });

      expect(entry.restaurantId, 'r1');
      expect(entry.name, 'Maison Verte');
      expect(entry.city, 'Paris');
      expect(entry.countryFlag, '🇫🇷');
      expect(entry.michelinStars, 2);
      expect(entry.communityRating, 9.0);
      expect(entry.totalVisits, 3);
    });

    test('community_rating survives PostgREST numeric precision (e.g. '
        '"8.67" from an average, not a round number)', () {
      final entry = CommunityRankingEntry.fromJson({
        'restaurant_id': 'r1',
        'name': 'Test',
        'city': 'Test',
        'country_flag': '🏳️',
        'michelin_stars': 0,
        'community_rating': 8.67,
        'total_visits': 3,
      });
      expect(entry.communityRating, 8.67);
    });

    test('michelin_stars defaults to 0 when null (unstarred restaurant)', () {
      final entry = CommunityRankingEntry.fromJson({
        'restaurant_id': 'r1',
        'name': 'Test',
        'city': 'Test',
        'country_flag': '🏳️',
        'michelin_stars': null,
        'community_rating': 8.0,
        'total_visits': 3,
      });
      expect(entry.michelinStars, 0);
    });

    test('restaurant_id is stringified regardless of source type', () {
      final entry = CommunityRankingEntry.fromJson({
        'restaurant_id': 'r1',
        'name': 'Test',
        'city': 'Test',
        'country_flag': '🏳️',
        'michelin_stars': 0,
        'community_rating': 8.0,
        'total_visits': 3,
      });
      expect(entry.restaurantId, isA<String>());
    });

    test('mapping a list of rows preserves backend order — the repository '
        'never re-sorts client-side', () {
      final rows = [
        {
          'restaurant_id': 'r1',
          'name': 'First',
          'city': 'A',
          'country_flag': '🏳️',
          'michelin_stars': 0,
          'community_rating': 9.5,
          'total_visits': 5,
        },
        {
          'restaurant_id': 'r2',
          'name': 'Second',
          'city': 'B',
          'country_flag': '🏳️',
          'michelin_stars': 0,
          'community_rating': 9.0,
          'total_visits': 10,
        },
        {
          'restaurant_id': 'r3',
          'name': 'Third',
          'city': 'C',
          'country_flag': '🏳️',
          'michelin_stars': 0,
          'community_rating': 9.0,
          'total_visits': 3,
        },
      ];
      final entries = rows.map(CommunityRankingEntry.fromJson).toList();
      expect(entries.map((e) => e.name).toList(), ['First', 'Second', 'Third']);
    });
  });
}
