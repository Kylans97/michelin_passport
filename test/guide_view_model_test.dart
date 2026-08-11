// Pure-logic tests for lib/features/guides/guide_view_model.dart
// (sortGuideRestaurants/sortGuideHotels) and
// lib/features/guides/models/guide_filters.dart (GuideStarFilter/
// GuideKeyFilter). Neither touches Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/guides/guide_view_model.dart';
import 'package:michelin_passport/features/guides/models/guide_filters.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({required String name, int? stars, String id = 'r'}) =>
    Restaurant(
      id: id,
      restaurantCode: id,
      name: name,
      michelinStars: stars,
      inclusionReason: 'michelin',
      cityName: 'City',
      countryCode: 'FR',
      countryName: 'France',
      flagEmoji: '🇫🇷',
      address: '1 Rue',
    );

Hotel _hotel({required String name, int? keys, String id = 'h'}) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: keys,
  cityName: 'City',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

void main() {
  group('sortGuideRestaurants', () {
    test('orders by current Michelin stars descending', () {
      final input = [
        _restaurant(name: 'One Star', stars: 1),
        _restaurant(name: 'Three Star', stars: 3),
        _restaurant(name: 'Two Star', stars: 2),
      ];
      final sorted = sortGuideRestaurants(input);
      expect(sorted.map((r) => r.name), ['Three Star', 'Two Star', 'One Star']);
    });

    test('within the same star tier, orders by name alphabetically', () {
      final input = [
        _restaurant(name: 'Zebra', stars: 2),
        _restaurant(name: 'Alpha', stars: 2),
        _restaurant(name: 'Mango', stars: 2),
      ];
      final sorted = sortGuideRestaurants(input);
      expect(sorted.map((r) => r.name), ['Alpha', 'Mango', 'Zebra']);
    });

    test('never mutates the original list', () {
      final input = [
        _restaurant(name: 'Two Star', stars: 2),
        _restaurant(name: 'Three Star', stars: 3),
      ];
      final original = List.of(input);
      sortGuideRestaurants(input);
      expect(input.map((r) => r.name), original.map((r) => r.name));
    });

    test('sort is deterministic across repeated calls', () {
      final input = [
        _restaurant(name: 'Beta', stars: 1),
        _restaurant(name: 'Alpha', stars: 1),
        _restaurant(name: 'Gamma', stars: 2),
      ];
      final first = sortGuideRestaurants(input).map((r) => r.name).toList();
      final second = sortGuideRestaurants(input).map((r) => r.name).toList();
      expect(first, second);
    });
  });

  group('sortGuideHotels', () {
    test('orders by current Michelin Keys descending', () {
      final input = [
        _hotel(name: 'One Key', keys: 1),
        _hotel(name: 'Three Key', keys: 3),
        _hotel(name: 'Two Key', keys: 2),
      ];
      final sorted = sortGuideHotels(input);
      expect(sorted.map((h) => h.name), ['Three Key', 'Two Key', 'One Key']);
    });

    test('within the same Key tier, orders by name alphabetically', () {
      final input = [
        _hotel(name: 'Zebra', keys: 2),
        _hotel(name: 'Alpha', keys: 2),
      ];
      final sorted = sortGuideHotels(input);
      expect(sorted.map((h) => h.name), ['Alpha', 'Zebra']);
    });

    test('never mutates the original list', () {
      final input = [
        _hotel(name: 'Two Key', keys: 2),
        _hotel(name: 'Three Key', keys: 3),
      ];
      final original = List.of(input);
      sortGuideHotels(input);
      expect(input.map((h) => h.name), original.map((h) => h.name));
    });
  });

  group('GuideStarFilter', () {
    test('"All" carries no stars param', () {
      expect(GuideStarFilter.all.starsParam, isNull);
    });

    test('each tier maps to its exact star count', () {
      expect(GuideStarFilter.one.starsParam, 1);
      expect(GuideStarFilter.two.starsParam, 2);
      expect(GuideStarFilter.three.starsParam, 3);
    });

    test('labels reuse the established star symbol language', () {
      expect(GuideStarFilter.all.label, 'All');
      expect(GuideStarFilter.one.label, '★');
      expect(GuideStarFilter.two.label, '★★');
      expect(GuideStarFilter.three.label, '★★★');
    });
  });

  group('GuideKeyFilter', () {
    test('"All" carries no keys param', () {
      expect(GuideKeyFilter.all.keysParam, isNull);
    });

    test('each tier maps to its exact Key count', () {
      expect(GuideKeyFilter.one.keysParam, 1);
      expect(GuideKeyFilter.two.keysParam, 2);
      expect(GuideKeyFilter.three.keysParam, 3);
    });

    test('labels reuse the established Key symbol language', () {
      expect(GuideKeyFilter.all.label, 'All');
      expect(GuideKeyFilter.one.label, '🔑');
      expect(GuideKeyFilter.two.label, '🔑🔑');
      expect(GuideKeyFilter.three.label, '🔑🔑🔑');
    });
  });
}
