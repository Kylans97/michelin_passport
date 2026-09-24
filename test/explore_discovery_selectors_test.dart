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
  DateTime? createdAt,
  String? missingListingReportId,
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
  createdAt: createdAt,
  missingListingReportId: missingListingReportId,
);

Hotel _hotel({
  String id = 'h1',
  String name = 'Test Hotel',
  int? michelinKeys,
  int? worlds50BestRank,
  DateTime? createdAt,
  String? missingListingReportId,
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
  createdAt: createdAt,
  missingListingReportId: missingListingReportId,
);

Event _event({
  String id = 'e1',
  String name = 'Test Event',
  required DateTime startAt,
  DateTime? endAt,
  EventStatus status = EventStatus.upcoming,
  DateTime? createdAt,
  String? missingListingReportId,
}) => Event(
  id: id,
  name: name,
  startAt: startAt,
  endAt: endAt ?? startAt,
  countryCode: 'FR',
  eventType: EventType.festival,
  status: status,
  createdAt: createdAt ?? DateTime(2026, 1, 1),
  missingListingReportId: missingListingReportId,
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

  group('selectFreshFinds', () {
    test('excludes every restaurant/hotel/event with no '
        'missingListingReportId', () {
      final result = selectFreshFinds(
        restaurants: [
          _restaurant(id: 'r1', createdAt: DateTime(2026, 9, 1)),
        ],
        hotels: [_hotel(id: 'h1', createdAt: DateTime(2026, 9, 1))],
        events: [_event(id: 'e1', startAt: DateTime(2026, 10, 1))],
      );
      expect(result, isEmpty);
    });

    test('includes a restaurant/hotel only when both createdAt and '
        'missingListingReportId are set — defensive against the '
        'DB-guaranteed-but-not-Dart-guaranteed case', () {
      final result = selectFreshFinds(
        restaurants: [
          _restaurant(
            id: 'r1',
            missingListingReportId: 'report-1',
            createdAt: null,
          ),
        ],
        hotels: const [],
        events: const [],
      );
      expect(result, isEmpty);
    });

    test('sorts newest first across all three types mixed together', () {
      final result = selectFreshFinds(
        restaurants: [
          _restaurant(
            id: 'r1',
            name: 'Oldest',
            missingListingReportId: 'rep-r1',
            createdAt: DateTime(2026, 9, 1),
          ),
        ],
        hotels: [
          _hotel(
            id: 'h1',
            name: 'Newest',
            missingListingReportId: 'rep-h1',
            createdAt: DateTime(2026, 9, 20),
          ),
        ],
        events: [
          _event(
            id: 'e1',
            name: 'Middle',
            startAt: DateTime(2026, 10, 1),
            missingListingReportId: 'rep-e1',
            createdAt: DateTime(2026, 9, 10),
          ),
        ],
      );
      expect(result.map((i) => i.name), ['Newest', 'Middle', 'Oldest']);
    });

    test('caps at the given limit, default 10', () {
      final restaurants = [
        for (var i = 0; i < 12; i++)
          _restaurant(
            id: 'r$i',
            name: 'R$i',
            missingListingReportId: 'rep-$i',
            createdAt: DateTime(2026, 9, i + 1),
          ),
      ];
      expect(
        selectFreshFinds(restaurants: restaurants, hotels: const [], events: const []).length,
        10,
      );
      expect(
        selectFreshFinds(
          restaurants: restaurants,
          hotels: const [],
          events: const [],
          limit: 3,
        ).length,
        3,
      );
    });

    test('each FreshFindItem exposes the right concrete type and fields',
        () {
      final restaurant = _restaurant(
        id: 'r1',
        name: 'Flore',
        missingListingReportId: 'rep-1',
        createdAt: DateTime(2026, 9, 1),
      );
      final result = selectFreshFinds(
        restaurants: [restaurant],
        hotels: const [],
        events: const [],
      );
      expect(result, hasLength(1));
      final item = result.single;
      expect(item, isA<FreshFindRestaurant>());
      expect(item.name, 'Flore');
      expect(item.cityName, 'Paris');
      expect((item as FreshFindRestaurant).restaurant, restaurant);
    });

    test('returns empty for empty input', () {
      expect(
        selectFreshFinds(restaurants: const [], hotels: const [], events: const []),
        isEmpty,
      );
    });
  });
}
