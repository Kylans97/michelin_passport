// Covers PassportFilterResult/PassportVenueStats — the pure filtering/
// aggregation logic Passport's redesigned screen wires its Restaurants/
// Hotels/All filter and year filter into. The screen itself (PassportScreen)
// constructs VisitedRepository(Supabase.instance.client) unconditionally,
// so it can't be pumped in a widget test without a live Supabase session
// (this project has no mocking harness — see hotel_nullable_keys_test.
// dart's own note on the same limitation); this file instead verifies the
// actual filtering behavior the "Restaurants filter still works"/"Hotels
// filter still works" requirement is really about, directly and without a
// UI in the loop.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/explore/models/explore_filters.dart';
import 'package:michelin_passport/features/passport/passport_view_model.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

Restaurant _restaurant({
  String id = 'r1',
  String name = 'Test Restaurant',
  int? michelinStars,
  String countryCode = 'FR',
}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  cityName: 'Paris',
  countryCode: countryCode,
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
);

Hotel _hotel({
  String id = 'h1',
  String name = 'Test Hotel',
  int? michelinKeys,
  String countryCode = 'FR',
}) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: michelinKeys,
  cityName: 'Paris',
  countryCode: countryCode,
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Visit _visit({
  String id = 'v1',
  String entityType = 'restaurant',
  String entityId = 'r1',
  required DateTime visitedOn,
  int? rating,
  int? starsAtVisit,
  int? keysAtVisit,
}) => Visit(
  id: id,
  userId: 'u1',
  entityType: entityType,
  entityId: entityId,
  visitedOn: visitedOn,
  rating: rating,
  starsAtVisit: starsAtVisit,
  keysAtVisit: keysAtVisit,
);

void main() {
  group('PassportFilterResult.of — venue-type filtering', () {
    final restaurantEntry = VenueEntry(
      venue: RestaurantVenue(_restaurant(id: 'r1', michelinStars: 2)),
      visits: [_visit(visitedOn: DateTime(2026, 6, 1), starsAtVisit: 2)],
    );
    final hotelEntry = VenueEntry(
      venue: HotelVenue(_hotel(id: 'h1', michelinKeys: 1)),
      visits: [
        _visit(
          entityType: 'hotel',
          entityId: 'h1',
          visitedOn: DateTime(2026, 7, 1),
          keysAtVisit: 1,
        ),
      ],
    );
    final allEntries = [restaurantEntry, hotelEntry];

    test('restaurants filter includes only restaurant venues', () {
      final result = PassportFilterResult.of(
        allEntries,
        venueType: ExploreVenueType.restaurants,
      );
      expect(result.entries.length, 1);
      expect(result.entries.single.venue, isA<RestaurantVenue>());
    });

    test('hotels filter includes only hotel venues', () {
      final result = PassportFilterResult.of(
        allEntries,
        venueType: ExploreVenueType.hotels,
      );
      expect(result.entries.length, 1);
      expect(result.entries.single.venue, isA<HotelVenue>());
    });

    test('all includes both', () {
      final result = PassportFilterResult.of(
        allEntries,
        venueType: ExploreVenueType.all,
      );
      expect(result.entries.length, 2);
    });
  });

  group('PassportFilterResult.of — year filtering', () {
    final entry = VenueEntry(
      venue: RestaurantVenue(_restaurant(michelinStars: 1)),
      visits: [
        _visit(id: 'v1', visitedOn: DateTime(2025, 3, 1), starsAtVisit: 1),
        _visit(id: 'v2', visitedOn: DateTime(2026, 3, 1), starsAtVisit: 1),
      ],
    );

    test('null year ("All time") includes every visit', () {
      final result = PassportFilterResult.of([
        entry,
      ], venueType: ExploreVenueType.all);
      expect(result.entries.single.visitCount, 2);
    });

    test('a specific year only counts that year\'s visits', () {
      final result = PassportFilterResult.of(
        [entry],
        venueType: ExploreVenueType.all,
        year: 2026,
      );
      expect(result.entries.single.visitCount, 1);
    });

    test('a year with no visits excludes the venue entirely', () {
      final result = PassportFilterResult.of(
        [entry],
        venueType: ExploreVenueType.all,
        year: 2024,
      );
      expect(result.entries, isEmpty);
    });
  });

  group('PassportFilterResult.of — summary (the CsMetricStrip numbers)', () {
    test('placesVisited/awardsExperienced/countriesVisited match real data, '
        'never invented', () {
      final entries = [
        VenueEntry(
          venue: RestaurantVenue(
            _restaurant(id: 'r1', michelinStars: 2, countryCode: 'FR'),
          ),
          visits: [_visit(visitedOn: DateTime(2026, 1, 1), starsAtVisit: 2)],
        ),
        VenueEntry(
          venue: HotelVenue(
            _hotel(id: 'h1', michelinKeys: 1, countryCode: 'NL'),
          ),
          visits: [
            _visit(
              entityType: 'hotel',
              entityId: 'h1',
              visitedOn: DateTime(2026, 2, 1),
              keysAtVisit: 1,
            ),
          ],
        ),
      ];
      final result = PassportFilterResult.of(
        entries,
        venueType: ExploreVenueType.all,
      );
      expect(result.summary.placesVisited, 2);
      expect(result.summary.awardsExperienced, 3); // 2 stars + 1 key
      expect(result.summary.countriesVisited, 2); // FR + NL
    });

    test('a venue visited multiple times still counts its award once', () {
      final entries = [
        VenueEntry(
          venue: RestaurantVenue(_restaurant(michelinStars: 3)),
          visits: [
            _visit(id: 'v1', visitedOn: DateTime(2026, 1, 1), starsAtVisit: 3),
            _visit(id: 'v2', visitedOn: DateTime(2026, 2, 1), starsAtVisit: 3),
            _visit(id: 'v3', visitedOn: DateTime(2026, 3, 1), starsAtVisit: 3),
          ],
        ),
      ];
      final result = PassportFilterResult.of(
        entries,
        venueType: ExploreVenueType.all,
      );
      expect(result.summary.placesVisited, 1);
      expect(result.summary.awardsExperienced, 3); // not 9
    });
  });

  group('PassportVenueStats.from', () {
    test('averageRating is null when no visit in the period was rated', () {
      final stats = PassportVenueStats.from(RestaurantVenue(_restaurant()), [
        _visit(visitedOn: DateTime(2026, 1, 1)),
      ]);
      expect(stats.averageRating, isNull);
    });

    test('averageRating is the mean of rated visits only', () {
      final stats = PassportVenueStats.from(RestaurantVenue(_restaurant()), [
        _visit(id: 'v1', visitedOn: DateTime(2026, 1, 1), rating: 8),
        _visit(id: 'v2', visitedOn: DateTime(2026, 2, 1), rating: 10),
        _visit(id: 'v3', visitedOn: DateTime(2026, 3, 1)), // unrated
      ]);
      expect(stats.averageRating, 9.0);
    });
  });

  group('PassportMetricLabels.forVenueType — the CsMetricStrip labels', () {
    test('Restaurants: VISITED / COUNTRIES / STARS', () {
      final labels = PassportMetricLabels.forVenueType(
        ExploreVenueType.restaurants,
      );
      expect(labels.visited, 'VISITED');
      expect(labels.countries, 'COUNTRIES');
      expect(labels.awards, 'STARS');
    });

    test('Hotels: STAYS / COUNTRIES / KEYS', () {
      final labels = PassportMetricLabels.forVenueType(ExploreVenueType.hotels);
      expect(labels.visited, 'STAYS');
      expect(labels.countries, 'COUNTRIES');
      expect(labels.awards, 'KEYS');
    });

    test('All: PLACES / COUNTRIES / AWARDS', () {
      final labels = PassportMetricLabels.forVenueType(ExploreVenueType.all);
      expect(labels.visited, 'PLACES');
      expect(labels.countries, 'COUNTRIES');
      expect(labels.awards, 'AWARDS');
    });
  });
}
