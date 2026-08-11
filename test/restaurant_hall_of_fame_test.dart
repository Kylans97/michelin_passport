// Covers the test scenarios from the Gault&Millau catalogue architecture
// fix (docs/Architecture/Michelin_Database/
// GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md): Restaurant.isHallOfFame
// moved from a derived getter (`inclusionReason == 'hall_of_fame'`, which
// always returned false for every real Hall of Fame restaurant — see the
// review's §1.1) to a real field sourced directly from
// restaurants_full.is_hall_of_fame.
//
//   A. inclusion_reason = 'michelin_star' + is_hall_of_fame = true ->
//      Restaurant.isHallOfFame == true (the actual real-world shape of
//      every current Hall of Fame member — all 6 also hold 3 Michelin
//      stars, so inclusion_reason was set to 'michelin_star' at import).
//   B. inclusion_reason = 'hall_of_fame' alone, with is_hall_of_fame
//      absent/false, does NOT make isHallOfFame true — proving the two
//      fields are fully decoupled, not that one derives the other.
//   D. A restaurant with is_hall_of_fame absent/false stays false.
//   E. hasMichelinStar / isWorlds50Best are unaffected regression checks.
//
// C (Explore's Hall of Fame filter uses is_hall_of_fame, not
// inclusion_reason) is a RestaurantRepository.search() network-call
// concern, not a Restaurant model concern, and this project has no
// Supabase mocking harness (see test/hotel_nullable_keys_test.dart's own
// precedent for the identical situation on the Hotel side). It is instead
// verified at the source level: restaurant_repository.dart's hallOfFameOnly
// branch reads `builder.eq('is_hall_of_fame', true)` — grep-verified to be
// the only remaining reference to 'hall_of_fame' as a filter predicate
// anywhere in lib/, with the prior `.eq('inclusion_reason', 'hall_of_fame')`
// removed — and semantically re-exercised by the migration's own local
// Postgres dry-run (docs/Architecture/Michelin_Database/
// GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md §17), which confirmed
// is_hall_of_fame resolves true for exactly the 6 real Hall of Fame
// restaurants and false for all others — the same predicate PostgREST
// translates `.eq('is_hall_of_fame', true)` into server-side.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/restaurant.dart';

Map<String, dynamic> _row({
  int? michelinStars,
  String inclusionReason = 'michelin_star',
  bool? isHallOfFame,
  int? worlds50BestRank,
}) => {
  'id': 'r1',
  'restaurant_code': 'rest_0001',
  'name': 'Test Restaurant',
  'michelin_stars': michelinStars,
  'inclusion_reason': inclusionReason,
  'is_hall_of_fame': ?isHallOfFame,
  'city_name': 'City',
  'country_code': 'FR',
  'country_name': 'Country',
  'flag_emoji': '🏳️',
  'address': '1 Rue',
  'worlds_50_best_rank': worlds50BestRank,
};

void main() {
  group('Restaurant.isHallOfFame — sourced from is_hall_of_fame', () {
    test('A: inclusion_reason=michelin_star + is_hall_of_fame=true -> '
        'isHallOfFame is true (the real shape of every current Hall of Fame '
        'member)', () {
      final restaurant = Restaurant.fromJson(
        _row(
          michelinStars: 3,
          inclusionReason: 'michelin_star',
          isHallOfFame: true,
        ),
      );
      expect(restaurant.inclusionReason, 'michelin_star');
      expect(restaurant.isHallOfFame, isTrue);
      expect(restaurant.hasMichelinStar, isTrue);
    });

    test('B: inclusion_reason=hall_of_fame alone, with is_hall_of_fame '
        'absent, does NOT make isHallOfFame true — the two fields are '
        'decoupled, not one derived from the other', () {
      final restaurant = Restaurant.fromJson(
        _row(inclusionReason: 'hall_of_fame', isHallOfFame: null),
      );
      expect(restaurant.inclusionReason, 'hall_of_fame');
      expect(
        restaurant.isHallOfFame,
        isFalse,
        reason:
            'isHallOfFame must come from is_hall_of_fame, never be '
            "inferred from inclusion_reason's string value",
      );
    });

    test('B (explicit false variant): inclusion_reason=hall_of_fame with '
        'is_hall_of_fame explicitly false stays false', () {
      final restaurant = Restaurant.fromJson(
        _row(inclusionReason: 'hall_of_fame', isHallOfFame: false),
      );
      expect(restaurant.isHallOfFame, isFalse);
    });

    test('D: a restaurant with is_hall_of_fame absent (typical non-Hall-of-'
        'Fame row) defaults to false', () {
      final restaurant = Restaurant.fromJson(_row());
      expect(restaurant.isHallOfFame, isFalse);
    });

    test('D (explicit false variant): is_hall_of_fame=false stays false', () {
      final restaurant = Restaurant.fromJson(
        _row(inclusionReason: 'michelin_star', isHallOfFame: false),
      );
      expect(restaurant.isHallOfFame, isFalse);
    });

    test('E: hasMichelinStar and isWorlds50Best are unaffected by this change '
        '(regression)', () {
      final starredOnly = Restaurant.fromJson(
        _row(michelinStars: 2, isHallOfFame: false),
      );
      expect(starredOnly.hasMichelinStar, isTrue);
      expect(starredOnly.isWorlds50Best, isFalse);

      final w50bOnly = Restaurant.fromJson(
        _row(
          michelinStars: null,
          inclusionReason: 'worlds_50_best',
          worlds50BestRank: 12,
          isHallOfFame: false,
        ),
      );
      expect(w50bOnly.hasMichelinStar, isFalse);
      expect(w50bOnly.isWorlds50Best, isTrue);
      expect(w50bOnly.isHallOfFame, isFalse);

      final all3 = Restaurant.fromJson(
        _row(
          michelinStars: 3,
          inclusionReason: 'michelin_star',
          worlds50BestRank: 1,
          isHallOfFame: true,
        ),
      );
      expect(all3.hasMichelinStar, isTrue);
      expect(all3.isWorlds50Best, isTrue);
      expect(all3.isHallOfFame, isTrue);
    });

    test('a directly-constructed Restaurant (no fromJson) defaults '
        'isHallOfFame to false, matching isInHotel\'s existing default '
        'pattern', () {
      const restaurant = Restaurant(
        id: 'r1',
        restaurantCode: 'rest_0001',
        name: 'Test',
        michelinStars: null,
        inclusionReason: 'michelin_star',
        cityName: 'City',
        countryCode: 'FR',
        countryName: 'France',
        flagEmoji: '🇫🇷',
        address: '1 Rue',
      );
      expect(restaurant.isHallOfFame, isFalse);
    });
  });
}
