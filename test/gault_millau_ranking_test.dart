// Pure-logic tests for lib/data/repositories/gault_millau_ranking.dart:
// latestGaultMillauAwardPerRestaurant, buildGaultMillauEntries,
// sortGaultMillauEntries. None of these touch Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/gault_millau_ranking.dart';
import 'package:michelin_passport/data/repositories/restaurant_gault_millau_repository.dart';
import 'package:michelin_passport/models/gault_millau_award.dart';
import 'package:michelin_passport/models/restaurant.dart';

Map<String, dynamic> _awardRow({
  required String restaurantId,
  required int guideYear,
  double? score,
  int? toqueCount,
  String? toqueColour,
  String recognitionType = 'scored',
  String? distinctionLabel,
}) => {
  'restaurant_id': restaurantId,
  'guide_year': guideYear,
  'score': score,
  'toque_count': toqueCount,
  'toque_colour': toqueColour,
  'recognition_type': recognitionType,
  'distinction_label': distinctionLabel,
  'gault_millau_url': null,
};

Map<String, dynamic> _restaurantRow({
  required String id,
  required String name,
  String countryCode = 'FR',
}) => {
  'id': id,
  'restaurant_code': id,
  'name': name,
  'michelin_stars': null,
  'inclusion_reason': 'gault_millau',
  'city_name': 'City',
  'country_code': countryCode,
  'country_name': 'Country',
  'flag_emoji': '🏳️',
  'address': '1 Rue',
};

void main() {
  group('latestGaultMillauAwardPerRestaurant', () {
    test('a restaurant with a single row returns that row unchanged', () {
      final result = latestGaultMillauAwardPerRestaurant([
        _awardRow(restaurantId: 'r1', guideYear: 2026, score: 18),
      ]);
      expect(result, hasLength(1));
      expect(result.single.guideYear, 2026);
    });

    test('a restaurant with multiple editions keeps only the highest '
        'guide_year', () {
      final result = latestGaultMillauAwardPerRestaurant([
        _awardRow(restaurantId: 'r1', guideYear: 2024, score: 16),
        _awardRow(restaurantId: 'r1', guideYear: 2026, score: 18),
        _awardRow(restaurantId: 'r1', guideYear: 2025, score: 17),
      ]);
      expect(result, hasLength(1));
      expect(result.single.guideYear, 2026);
      expect(result.single.score, 18);
    });

    test('never produces two rows for the same restaurant even across many '
        'editions', () {
      final result = latestGaultMillauAwardPerRestaurant([
        for (var year = 2020; year <= 2026; year++)
          _awardRow(restaurantId: 'r1', guideYear: year, score: 15),
      ]);
      expect(result, hasLength(1));
    });

    test('distinct restaurants each keep their own latest row', () {
      final result = latestGaultMillauAwardPerRestaurant([
        _awardRow(restaurantId: 'r1', guideYear: 2025, score: 15),
        _awardRow(restaurantId: 'r1', guideYear: 2026, score: 16),
        _awardRow(restaurantId: 'r2', guideYear: 2026, score: 19),
      ]);
      expect(result, hasLength(2));
      final byId = {for (final a in result) a.restaurantId: a};
      expect(byId['r1']!.score, 16);
      expect(byId['r2']!.score, 19);
    });

    test('an empty input yields an empty list', () {
      expect(latestGaultMillauAwardPerRestaurant(const []), isEmpty);
    });
  });

  group('buildGaultMillauEntries', () {
    test('joins award rows to their resolved restaurants', () {
      final entries = buildGaultMillauEntries(
        rawAwardRows: [
          _awardRow(restaurantId: 'r1', guideYear: 2026, score: 18),
        ],
        restaurantRows: [_restaurantRow(id: 'r1', name: 'One')],
      );
      expect(entries, hasLength(1));
      expect(entries.single.restaurant.name, 'One');
      expect(entries.single.award.score, 18);
    });

    test('an award whose restaurant was filtered out of the second query '
        '(search/country) is silently dropped, not crashed on', () {
      final entries = buildGaultMillauEntries(
        rawAwardRows: [
          _awardRow(restaurantId: 'r1', guideYear: 2026, score: 18),
          _awardRow(restaurantId: 'r2', guideYear: 2026, score: 19),
        ],
        restaurantRows: [
          _restaurantRow(id: 'r1', name: 'One'),
          // r2 deliberately absent, as if excluded by a country filter.
        ],
      );
      expect(entries, hasLength(1));
      expect(entries.single.restaurant.name, 'One');
    });

    test('deduplicates multi-edition rows before joining', () {
      final entries = buildGaultMillauEntries(
        rawAwardRows: [
          _awardRow(restaurantId: 'r1', guideYear: 2024, score: 15),
          _awardRow(restaurantId: 'r1', guideYear: 2026, score: 18),
        ],
        restaurantRows: [_restaurantRow(id: 'r1', name: 'One')],
      );
      expect(entries, hasLength(1));
      expect(entries.single.award.score, 18);
    });
  });

  group('sortGaultMillauEntries', () {
    RestaurantGaultMillauEntry entry({
      required String name,
      double? score,
      int? toqueCount,
    }) => RestaurantGaultMillauEntry(
      restaurant: Restaurant.fromJson(_restaurantRow(id: name, name: name)),
      award: GaultMillauAward.fromJson(
        _awardRow(
          restaurantId: name,
          guideYear: 2026,
          score: score,
          toqueCount: toqueCount,
        ),
      ),
    );

    test('orders by score descending', () {
      final sorted = sortGaultMillauEntries([
        entry(name: 'Low', score: 15),
        entry(name: 'High', score: 19.5),
        entry(name: 'Mid', score: 17),
      ]);
      expect(sorted.map((e) => e.restaurant.name), ['High', 'Mid', 'Low']);
    });

    test('within the same score, orders by name alphabetically', () {
      final sorted = sortGaultMillauEntries([
        entry(name: 'Zebra', score: 17),
        entry(name: 'Alpha', score: 17),
      ]);
      expect(sorted.map((e) => e.restaurant.name), ['Alpha', 'Zebra']);
    });

    test('a scored entry always sorts before an unscored entry, regardless '
        'of toque count', () {
      final sorted = sortGaultMillauEntries([
        entry(name: 'Unscored', score: null, toqueCount: 5),
        entry(name: 'Scored', score: 14),
      ]);
      expect(sorted.map((e) => e.restaurant.name), ['Scored', 'Unscored']);
    });

    test('among unscored entries, higher toque count sorts first', () {
      final sorted = sortGaultMillauEntries([
        entry(name: 'ThreeToque', score: null, toqueCount: 3),
        entry(name: 'FiveToque', score: null, toqueCount: 5),
      ]);
      expect(sorted.map((e) => e.restaurant.name), ['FiveToque', 'ThreeToque']);
    });

    test('entries with neither score nor toque count fall back to name '
        'ordering without crashing', () {
      final sorted = sortGaultMillauEntries([
        entry(name: 'Zebra'),
        entry(name: 'Alpha'),
      ]);
      expect(sorted.map((e) => e.restaurant.name), ['Alpha', 'Zebra']);
    });

    test('never mutates the original list', () {
      final input = [entry(name: 'B', score: 10), entry(name: 'A', score: 20)];
      final original = List.of(input);
      sortGaultMillauEntries(input);
      expect(
        input.map((e) => e.restaurant.name),
        original.map((e) => e.restaurant.name),
      );
    });
  });
}
