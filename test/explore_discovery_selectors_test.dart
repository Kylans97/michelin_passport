// Pure-logic tests for Explore's discovery selection rules
// (lib/features/explore/discovery_selectors.dart) — deterministic,
// presentation-only functions over already-loaded catalogue/event data, no
// Supabase involved, so these run as plain unit tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/explore/discovery_selectors.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({
  String id = 'r1',
  String name = 'Test Restaurant',
  int? michelinStars,
  int? worlds50BestRank,
}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  worlds50BestRank: worlds50BestRank,
);

Hotel _hotel({
  String id = 'h1',
  String name = 'Test Hotel',
  int? michelinKeys,
  int? worlds50BestRank,
}) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: michelinKeys,
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
  worlds50BestRank: worlds50BestRank,
);

Event _event({
  String id = 'e1',
  String name = 'Test Event',
  required DateTime startAt,
  DateTime? endAt,
  EventStatus status = EventStatus.upcoming,
}) => Event(
  id: id,
  name: name,
  startAt: startAt,
  endAt: endAt ?? startAt,
  countryCode: 'FR',
  eventType: EventType.festival,
  status: status,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('selectDiscoveryRestaurants', () {
    test('higher Michelin star count sorts first', () {
      final restaurants = [
        _restaurant(id: 'r1', name: 'One Star', michelinStars: 1),
        _restaurant(id: 'r2', name: 'Three Star', michelinStars: 3),
        _restaurant(id: 'r3', name: 'Two Star', michelinStars: 2),
      ];
      final selected = selectDiscoveryRestaurants(restaurants);
      expect(selected.map((r) => r.name), [
        'Three Star',
        'Two Star',
        'One Star',
      ]);
    });

    test('a starless restaurant never sorts as if it had 0 stars — it '
        'sorts after every starred one', () {
      final restaurants = [
        _restaurant(id: 'r1', name: 'Starless', michelinStars: null),
        _restaurant(id: 'r2', name: 'One Star', michelinStars: 1),
      ];
      final selected = selectDiscoveryRestaurants(restaurants);
      expect(selected.map((r) => r.name), ['One Star', 'Starless']);
    });

    test("World's 50 Best rank breaks ties among equally-starred "
        'restaurants, lower rank first', () {
      final restaurants = [
        _restaurant(
          id: 'r1',
          name: 'Rank 40',
          michelinStars: 2,
          worlds50BestRank: 40,
        ),
        _restaurant(
          id: 'r2',
          name: 'Rank 5',
          michelinStars: 2,
          worlds50BestRank: 5,
        ),
      ];
      final selected = selectDiscoveryRestaurants(restaurants);
      expect(selected.map((r) => r.name), ['Rank 5', 'Rank 40']);
    });

    test('final tie-break is alphabetical by name, for total determinism', () {
      final restaurants = [
        _restaurant(id: 'r1', name: 'Zed', michelinStars: 1),
        _restaurant(id: 'r2', name: 'Alpha', michelinStars: 1),
      ];
      final selected = selectDiscoveryRestaurants(restaurants);
      expect(selected.map((r) => r.name), ['Alpha', 'Zed']);
    });

    test('limit caps the returned list', () {
      final restaurants = List.generate(
        20,
        (i) => _restaurant(id: 'r$i', name: 'R$i', michelinStars: 1),
      );
      expect(selectDiscoveryRestaurants(restaurants, limit: 3).length, 3);
    });

    test('never mutates the input list', () {
      final restaurants = [
        _restaurant(id: 'r1', name: 'Zed', michelinStars: 1),
        _restaurant(id: 'r2', name: 'Alpha', michelinStars: 2),
      ];
      final original = [...restaurants];
      selectDiscoveryRestaurants(restaurants);
      expect(restaurants.map((r) => r.name), original.map((r) => r.name));
    });
  });

  group('selectDiscoveryHotels', () {
    test('higher Key count sorts first, unconfirmed Keys never treated '
        'as zero', () {
      final hotels = [
        _hotel(id: 'h1', name: 'No Keys', michelinKeys: null),
        _hotel(id: 'h2', name: 'Two Keys', michelinKeys: 2),
        _hotel(id: 'h3', name: 'One Key', michelinKeys: 1),
      ];
      final selected = selectDiscoveryHotels(hotels);
      expect(selected.map((h) => h.name), ['Two Keys', 'One Key', 'No Keys']);
    });

    test("World's 50 Best rank breaks ties among equally-Keyed hotels", () {
      final hotels = [
        _hotel(
          id: 'h1',
          name: 'Rank 30',
          michelinKeys: 1,
          worlds50BestRank: 30,
        ),
        _hotel(id: 'h2', name: 'Rank 2', michelinKeys: 1, worlds50BestRank: 2),
      ];
      final selected = selectDiscoveryHotels(hotels);
      expect(selected.map((h) => h.name), ['Rank 2', 'Rank 30']);
    });

    test('limit caps the returned list', () {
      final hotels = List.generate(
        20,
        (i) => _hotel(id: 'h$i', name: 'H$i', michelinKeys: 1),
      );
      expect(selectDiscoveryHotels(hotels, limit: 4).length, 4);
    });
  });

  group('selectFeaturedEvent', () {
    test('returns the soonest upcoming event', () {
      final events = [
        _event(id: 'e1', name: 'Later', startAt: DateTime(2026, 12, 1)),
        _event(id: 'e2', name: 'Soonest', startAt: DateTime(2026, 8, 20)),
        _event(id: 'e3', name: 'Middle', startAt: DateTime(2026, 10, 1)),
      ];
      expect(selectFeaturedEvent(events)?.name, 'Soonest');
    });

    test('a cancelled event is excluded even if it is soonest', () {
      final events = [
        _event(
          id: 'e1',
          name: 'Cancelled Soonest',
          startAt: DateTime(2026, 8, 1),
          status: EventStatus.cancelled,
        ),
        _event(id: 'e2', name: 'Next Upcoming', startAt: DateTime(2026, 9, 1)),
      ];
      expect(selectFeaturedEvent(events)?.name, 'Next Upcoming');
    });

    test('returns null when there is nothing to feature', () {
      expect(selectFeaturedEvent(const []), isNull);
      expect(
        selectFeaturedEvent([
          _event(startAt: DateTime(2026, 8, 1), status: EventStatus.cancelled),
        ]),
        isNull,
      );
    });
  });
}
