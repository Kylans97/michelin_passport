// Pure-logic tests for lib/data/repositories/worlds_50_best_ranking.dart:
// buildRestaurantRankingEntries, buildHotelRankingEntries,
// sortYearsDescending. None of these touch Supabase — fixtures below
// mirror real row shapes discovered live during the Guides Step 2C audit
// (gapped ranks, a null-rank Hall of Fame row, an extended range reaching
// past 100 for some historical years) rather than idealized data, per the
// brief's "test semantics, not live database volatility."

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/worlds_50_best_ranking.dart';

Map<String, dynamic> _restaurantRow({
  required String id,
  required String name,
  String countryCode = 'FR',
}) => {
  'id': id,
  'restaurant_code': id,
  'name': name,
  'michelin_stars': null,
  'inclusion_reason': 'worlds_50_best',
  'city_name': 'City',
  'country_code': countryCode,
  'country_name': 'Country',
  'flag_emoji': '🏳️',
  'address': '1 Rue',
};

Map<String, dynamic> _hotelRow({required String id, required String name}) => {
  'id': id,
  'hotel_code': id,
  'name': name,
  'michelin_keys': null,
  'city_name': 'City',
  'country_code': 'FR',
  'country_name': 'Country',
  'flag_emoji': '🏳️',
  'address': '1 Rue',
  'has_michelin_restaurant': false,
  'restaurant_count': 0,
};

void main() {
  group('buildRestaurantRankingEntries', () {
    test('sorts by rank ascending', () {
      final entries = buildRestaurantRankingEntries(
        rankingRows: [
          {'restaurant_id': 'r3', 'rank': 3, 'list_type': 'top_50'},
          {'restaurant_id': 'r1', 'rank': 1, 'list_type': 'top_50'},
          {'restaurant_id': 'r2', 'rank': 2, 'list_type': 'top_50'},
        ],
        restaurantRows: [
          _restaurantRow(id: 'r1', name: 'One'),
          _restaurantRow(id: 'r2', name: 'Two'),
          _restaurantRow(id: 'r3', name: 'Three'),
        ],
        year: 2025,
      );
      expect(entries.map((e) => e.restaurant.name), ['One', 'Two', 'Three']);
      expect(entries.map((e) => e.rank), [1, 2, 3]);
    });

    test('preserves real-world rank gaps rather than renumbering', () {
      // Mirrors the live 2019 shape found during the audit: ranks 3,4,5,7
      // (no 1,2,6) — a genuine data-completeness gap, not a bug to hide.
      final entries = buildRestaurantRankingEntries(
        rankingRows: [
          {'restaurant_id': 'r5', 'rank': 5, 'list_type': 'top_50'},
          {'restaurant_id': 'r3', 'rank': 3, 'list_type': 'top_50'},
          {'restaurant_id': 'r7', 'rank': 7, 'list_type': 'top_50'},
          {'restaurant_id': 'r4', 'rank': 4, 'list_type': 'top_50'},
        ],
        restaurantRows: [
          _restaurantRow(id: 'r3', name: 'Three'),
          _restaurantRow(id: 'r4', name: 'Four'),
          _restaurantRow(id: 'r5', name: 'Five'),
          _restaurantRow(id: 'r7', name: 'Seven'),
        ],
        year: 2019,
      );
      expect(entries.map((e) => e.rank), [3, 4, 5, 7]);
    });

    test('a null-rank Hall of Fame row is excluded from the ranked list', () {
      final entries = buildRestaurantRankingEntries(
        rankingRows: [
          {'restaurant_id': 'r1', 'rank': 1, 'list_type': 'top_50'},
          {'restaurant_id': 'hof', 'rank': null, 'list_type': 'hall_of_fame'},
        ],
        restaurantRows: [
          _restaurantRow(id: 'r1', name: 'One'),
          _restaurantRow(id: 'hof', name: 'Hall of Famer'),
        ],
        year: 2019,
      );
      expect(entries, hasLength(1));
      expect(entries.single.restaurant.name, 'One');
    });

    test('an extended range past 100 (a real historical shape) sorts '
        'correctly', () {
      final entries = buildRestaurantRankingEntries(
        rankingRows: [
          {
            'restaurant_id': 'r119',
            'rank': 119,
            'list_type': 'extended_51_100',
          },
          {'restaurant_id': 'r51', 'rank': 51, 'list_type': 'extended_51_100'},
        ],
        restaurantRows: [
          _restaurantRow(id: 'r51', name: 'Fifty-one'),
          _restaurantRow(id: 'r119', name: 'One nineteen'),
        ],
        year: 2019,
      );
      expect(entries.map((e) => e.rank), [51, 119]);
    });

    test('a ranking row whose restaurant was filtered out of the second '
        'query (search/country) is silently dropped, not crashed on', () {
      final entries = buildRestaurantRankingEntries(
        rankingRows: [
          {'restaurant_id': 'r1', 'rank': 1, 'list_type': 'top_50'},
          {'restaurant_id': 'r2', 'rank': 2, 'list_type': 'top_50'},
        ],
        restaurantRows: [
          _restaurantRow(id: 'r1', name: 'One'),
          // r2 deliberately absent, as if excluded by a country filter.
        ],
        year: 2025,
      );
      expect(entries, hasLength(1));
      expect(entries.single.restaurant.name, 'One');
    });

    test('an unparseable list_type falls back to topFifty rather than '
        'throwing', () {
      final entries = buildRestaurantRankingEntries(
        rankingRows: [
          {'restaurant_id': 'r1', 'rank': 1, 'list_type': 'nonsense'},
        ],
        restaurantRows: [_restaurantRow(id: 'r1', name: 'One')],
        year: 2025,
      );
      expect(entries.single.listType.dbValue, 'top_50');
    });
  });

  group('buildHotelRankingEntries', () {
    test('sorts by rank ascending across a full 1-100 continuous range', () {
      final entries = buildHotelRankingEntries(
        rankingRows: [
          {'hotel_id': 'h100', 'rank': 100, 'list_type': 'extended_51_100'},
          {'hotel_id': 'h1', 'rank': 1, 'list_type': 'top_50'},
          {'hotel_id': 'h51', 'rank': 51, 'list_type': 'extended_51_100'},
        ],
        hotelRows: [
          _hotelRow(id: 'h1', name: 'One'),
          _hotelRow(id: 'h51', name: 'Fifty-one'),
          _hotelRow(id: 'h100', name: 'Hundred'),
        ],
        year: 2025,
      );
      expect(entries.map((e) => e.rank), [1, 51, 100]);
    });

    test('a null-rank row is defensively excluded (schema allows it even '
        "though hotels have no Hall of Fame concept)", () {
      final entries = buildHotelRankingEntries(
        rankingRows: [
          {'hotel_id': 'h1', 'rank': 1, 'list_type': 'top_50'},
          {'hotel_id': 'h2', 'rank': null, 'list_type': 'top_50'},
        ],
        hotelRows: [
          _hotelRow(id: 'h1', name: 'One'),
          _hotelRow(id: 'h2', name: 'Two'),
        ],
        year: 2025,
      );
      expect(entries, hasLength(1));
    });
  });

  group('sortYearsDescending', () {
    test('deduplicates and sorts descending', () {
      expect(sortYearsDescending([2019, 2025, 2019, 2023]), [2025, 2023, 2019]);
    });

    test('excludes nothing — the cancelled 2020 edition is absent simply '
        'because no row for it is ever passed in, not via special-casing', () {
      final years = sortYearsDescending([2019, 2021, 2022]);
      expect(years, isNot(contains(2020)));
    });

    test('an empty input yields an empty list', () {
      expect(sortYearsDescending(const []), isEmpty);
    });
  });
}
