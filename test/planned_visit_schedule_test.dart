// PLANNED VISITS REFINEMENT: covers the pure filtering/sorting logic
// (isUpcomingPlannedVenue/upcomingPlannedVenues) that determines which
// entries render under "PLANNED VISITS" on the Trips subsection.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/trips/planned_visit_schedule.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/planned_venue.dart';
import 'package:michelin_passport/models/resolved_planned_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({String id = 'r1', String name = 'Test Restaurant'}) =>
    Restaurant(
      id: id,
      restaurantCode: id,
      name: name,
      michelinStars: null,
      inclusionReason: 'michelin_star',
      cityName: 'Paris',
      countryCode: 'FR',
      countryName: 'France',
      flagEmoji: '🇫🇷',
      address: '1 Rue de Test',
    );

Hotel _hotel({String id = 'h1', String name = 'Test Hotel'}) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: null,
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

ResolvedPlannedVenue _plannedRestaurant({
  String id = 'pv1',
  required DateTime visitDate,
}) => ResolvedPlannedVenue(
  plan: PlannedVenue(
    id: id,
    userId: 'u1',
    entityType: 'restaurant',
    entityId: 'r1',
    startDate: visitDate,
    status: PlannedVenueStatus.planned,
    createdAt: DateTime(2026, 1, 1),
  ),
  venue: RestaurantVenue(_restaurant(id: id)),
);

ResolvedPlannedVenue _plannedHotelStay({
  String id = 'pv2',
  required DateTime checkIn,
  DateTime? checkOut,
}) => ResolvedPlannedVenue(
  plan: PlannedVenue(
    id: id,
    userId: 'u1',
    entityType: 'hotel',
    entityId: 'h1',
    startDate: checkIn,
    endDate: checkOut,
    status: PlannedVenueStatus.planned,
    createdAt: DateTime(2026, 1, 1),
  ),
  venue: HotelVenue(_hotel(id: id)),
);

void main() {
  final today = DateTime(2026, 8, 25);

  group('isUpcomingPlannedVenue — restaurant (single date)', () {
    test('a past restaurant visit is excluded', () {
      final entry = _plannedRestaurant(visitDate: DateTime(2026, 8, 10));
      expect(isUpcomingPlannedVenue(entry.plan, now: today), isFalse);
    });

    test("today's restaurant visit is included", () {
      final entry = _plannedRestaurant(visitDate: DateTime(2026, 8, 25));
      expect(isUpcomingPlannedVenue(entry.plan, now: today), isTrue);
    });

    test('a future restaurant visit is included', () {
      final entry = _plannedRestaurant(visitDate: DateTime(2026, 9, 1));
      expect(isUpcomingPlannedVenue(entry.plan, now: today), isTrue);
    });
  });

  group('isUpcomingPlannedVenue — hotel (check-in/check-out range)', () {
    test('a completed hotel stay (checkout already passed) is excluded', () {
      final entry = _plannedHotelStay(
        checkIn: DateTime(2026, 8, 13),
        checkOut: DateTime(2026, 8, 20),
      );
      expect(isUpcomingPlannedVenue(entry.plan, now: today), isFalse);
    });

    test('an ongoing hotel stay (checked in, not yet checked out) is '
        'included', () {
      final entry = _plannedHotelStay(
        checkIn: DateTime(2026, 8, 20),
        checkOut: DateTime(2026, 8, 28),
      );
      expect(isUpcomingPlannedVenue(entry.plan, now: today), isTrue);
    });

    test('a hotel stay checking out exactly today is still included — '
        'the whole day counts', () {
      final entry = _plannedHotelStay(
        checkIn: DateTime(2026, 8, 20),
        checkOut: DateTime(2026, 8, 25),
      );
      expect(isUpcomingPlannedVenue(entry.plan, now: today), isTrue);
    });

    test('a future hotel stay is included', () {
      final entry = _plannedHotelStay(
        checkIn: DateTime(2026, 9, 1),
        checkOut: DateTime(2026, 9, 5),
      );
      expect(isUpcomingPlannedVenue(entry.plan, now: today), isTrue);
    });

    test('a hotel stay with no checkout set yet falls back to check-in — '
        'a past check-in with no checkout is excluded', () {
      final entry = _plannedHotelStay(checkIn: DateTime(2026, 8, 10));
      expect(isUpcomingPlannedVenue(entry.plan, now: today), isFalse);
    });
  });

  group('upcomingPlannedVenues', () {
    test('filters out every past entry, restaurant and hotel alike', () {
      final pastRestaurant = _plannedRestaurant(
        id: 'past-r',
        visitDate: DateTime(2026, 8, 10),
      );
      final pastHotel = _plannedHotelStay(
        id: 'past-h',
        checkIn: DateTime(2026, 8, 13),
        checkOut: DateTime(2026, 8, 20),
      );
      final futureRestaurant = _plannedRestaurant(
        id: 'future-r',
        visitDate: DateTime(2026, 9, 1),
      );

      final result = upcomingPlannedVenues(
        [pastRestaurant, pastHotel, futureRestaurant],
        now: today,
      );
      expect(result.map((v) => v.plan.id).toList(), ['future-r']);
    });

    test('sorts chronologically, nearest first — never creation/insertion '
        'order', () {
      final later = _plannedRestaurant(
        id: 'later',
        visitDate: DateTime(2026, 10, 1),
      );
      final nearest = _plannedRestaurant(
        id: 'nearest',
        visitDate: DateTime(2026, 8, 26),
      );
      final middle = _plannedHotelStay(
        id: 'middle',
        checkIn: DateTime(2026, 9, 10),
        checkOut: DateTime(2026, 9, 15),
      );

      // Deliberately inserted out of chronological order.
      final result = upcomingPlannedVenues([later, nearest, middle], now: today);
      expect(
        result.map((v) => v.plan.id).toList(),
        ['nearest', 'middle', 'later'],
      );
    });

    test('an ongoing hotel stay (started in the past) still sorts by its '
        'own start date, ahead of a later-starting future visit', () {
      final ongoing = _plannedHotelStay(
        id: 'ongoing',
        checkIn: DateTime(2026, 8, 20),
        checkOut: DateTime(2026, 8, 28),
      );
      final future = _plannedRestaurant(
        id: 'future',
        visitDate: DateTime(2026, 9, 1),
      );
      final result = upcomingPlannedVenues([future, ongoing], now: today);
      expect(result.map((v) => v.plan.id).toList(), ['ongoing', 'future']);
    });

    test('historical data is not deleted — filtering only changes what '
        'this function returns, the original list (and its past entries) '
        'is left completely untouched', () {
      final pastRestaurant = _plannedRestaurant(
        id: 'past-r',
        visitDate: DateTime(2026, 8, 10),
      );
      final futureRestaurant = _plannedRestaurant(
        id: 'future-r',
        visitDate: DateTime(2026, 9, 1),
      );
      final original = [pastRestaurant, futureRestaurant];

      final result = upcomingPlannedVenues(original, now: today);

      // The function's own return value excludes the past entry...
      expect(result.map((v) => v.plan.id), isNot(contains('past-r')));
      // ...but the caller's own original list — the thing that actually
      // represents the underlying data — still has both. Nothing was
      // removed, mutated, or deleted; this is a pure read/filter.
      expect(original.length, 2);
      expect(original.map((v) => v.plan.id), contains('past-r'));
    });
  });
}
