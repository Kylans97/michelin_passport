// Covers the test scenarios from the Culinary Events foundation task:
//   A. standalone event with no linked venue
//   E. week filter
//   F. month filter
//   H. planned-trip overlap
//   I. non-overlapping event excluded
//   K. cancelled event handling
//
// B/C/D (event linked to one/many restaurants, restaurant+hotel), G
// (country filter) and J (linked venue navigation) are Supabase-query or
// widget-navigation concerns with no pure logic to unit test in isolation
// — this project has no Supabase mocking harness (see
// hotel_nullable_keys_test.dart's own note on the same limitation). Those
// were instead verified by: a transactional dry-run of the migration
// against the local Supabase Postgres (confirmed event_restaurants/
// event_hotels create and insert cleanly, then rolled back), and direct
// code review confirming EventDetailScreen reuses RestaurantTile/HotelTile
// unmodified — both already navigate to the real Detail screens, proven
// code from the existing Explore feature, not new logic this task adds.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/events_repository.dart';
import 'package:michelin_passport/features/events/models/event_date_filter.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_trip_match.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:michelin_passport/models/restaurant.dart';

Event _event({
  String id = 'evt-1',
  required DateTime startAt,
  required DateTime endAt,
  String countryCode = 'NL',
  String? city = 'Maastricht',
  EventStatus status = EventStatus.upcoming,
}) => Event(
  id: id,
  name: 'Test Event',
  startAt: startAt,
  endAt: endAt,
  countryCode: countryCode,
  city: city,
  eventType: EventType.festival,
  status: status,
  createdAt: DateTime(2026, 1, 1),
);

PlannedTrip _trip({
  String countryCode = 'NL',
  String? city = 'Maastricht',
  required DateTime startDate,
  required DateTime endDate,
}) => PlannedTrip(
  id: 'trip-1',
  userId: 'user-1',
  title: 'Test Trip',
  startDate: startDate,
  endDate: endDate,
  countryCode: countryCode,
  city: city,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('A: standalone event with no linked venue', () {
    test('EventVenues.isEmpty is true when both lists are empty', () {
      const venues = EventVenues(
        restaurants: <Restaurant>[],
        hotels: <Hotel>[],
      );
      expect(venues.isEmpty, isTrue);
    });

    test('EventVenues.isEmpty is false once one list has an entry', () {
      final venues = EventVenues(
        restaurants: [
          const Restaurant(
            id: 'r1',
            restaurantCode: 'r1',
            name: 'Test',
            michelinStars: null,
            inclusionReason: 'michelin_star',
            cityName: 'Paris',
            countryCode: 'FR',
            countryName: 'France',
            flagEmoji: '🇫🇷',
            address: '1 Rue de Test',
          ),
        ],
        hotels: const <Hotel>[],
      );
      expect(venues.isEmpty, isFalse);
    });
  });

  group('E: week filter', () {
    test('resolves to a 7-day window starting Monday', () {
      final filter = EventDateFilter(mode: EventDateFilterMode.thisWeek);
      final (from, to) = filter.resolve();
      expect(from, isNotNull);
      expect(to, isNotNull);
      expect(from!.weekday, DateTime.monday);
      expect(to!.difference(from).inDays, 7);
    });
  });

  group('F: month filter', () {
    test('resolves to the first day of the month through the next month\'s '
        'first day', () {
      final filter = EventDateFilter(
        mode: EventDateFilterMode.month,
        monthAnchor: DateTime(2026, 8, 15),
      );
      final (from, to) = filter.resolve();
      expect(from, DateTime(2026, 8, 1));
      expect(to, DateTime(2026, 9, 1));
    });

    test('rolls over the year boundary correctly (December)', () {
      final filter = EventDateFilter(
        mode: EventDateFilterMode.month,
        monthAnchor: DateTime(2026, 12, 3),
      );
      final (from, to) = filter.resolve();
      expect(from, DateTime(2026, 12, 1));
      expect(to, DateTime(2027, 1, 1));
    });
  });

  group('H: planned-trip overlap (event matches trip)', () {
    test('event fully inside trip dates, same country + city matches', () {
      final event = _event(
        startAt: DateTime(2026, 8, 27, 18),
        endAt: DateTime(2026, 8, 31),
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
      );
      expect(eventMatchesTrip(event, trip), isTrue);
    });

    test('event partially overlapping the trip edge still matches', () {
      final event = _event(
        startAt: DateTime(2026, 8, 29),
        endAt: DateTime(2026, 9, 2),
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
      );
      expect(eventMatchesTrip(event, trip), isTrue);
    });

    test('country-level event with no city still matches a trip with a '
        'city — city must never hard-require', () {
      final event = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 28, 23),
        city: null,
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
      );
      expect(eventMatchesTrip(event, trip), isTrue);
    });

    test('trip with no city still matches an event that has one', () {
      final event = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 28, 23),
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
        city: null,
      );
      expect(eventMatchesTrip(event, trip), isTrue);
    });

    test('eventsMatchingTrip sorts chronologically and drops non-matches', () {
      final matching1 = _event(
        id: 'e1',
        startAt: DateTime(2026, 8, 29),
        endAt: DateTime(2026, 8, 29, 23),
      );
      final matching2 = _event(
        id: 'e2',
        startAt: DateTime(2026, 8, 27),
        endAt: DateTime(2026, 8, 27, 23),
      );
      final nonOverlapping = _event(
        id: 'e3',
        startAt: DateTime(2026, 9, 10),
        endAt: DateTime(2026, 9, 11),
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
      );
      final result = eventsMatchingTrip([
        matching1,
        nonOverlapping,
        matching2,
      ], trip);
      expect(result.map((e) => e.id).toList(), ['e2', 'e1']);
    });
  });

  group('I: non-overlapping event excluded', () {
    test('event entirely before the trip does not match', () {
      final event = _event(
        startAt: DateTime(2026, 8, 1),
        endAt: DateTime(2026, 8, 2),
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
      );
      expect(eventMatchesTrip(event, trip), isFalse);
    });

    test('event entirely after the trip does not match', () {
      final event = _event(
        startAt: DateTime(2026, 9, 5),
        endAt: DateTime(2026, 9, 6),
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
      );
      expect(eventMatchesTrip(event, trip), isFalse);
    });

    test('same dates, different country does not match', () {
      final event = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 28, 23),
        countryCode: 'BE',
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
      );
      expect(eventMatchesTrip(event, trip), isFalse);
    });

    test('same dates and country, both have a DIFFERENT city, does not '
        'match', () {
      final event = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 28, 23),
        city: 'Amsterdam',
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
        city: 'Maastricht',
      );
      expect(eventMatchesTrip(event, trip), isFalse);
    });
  });

  group('K: cancelled event handling', () {
    test('a cancelled event never matches a trip, even with perfect '
        'date/country/city alignment', () {
      final event = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 28, 23),
        status: EventStatus.cancelled,
      );
      final trip = _trip(
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 8, 30),
      );
      expect(eventMatchesTrip(event, trip), isFalse);
    });

    test('Event.isCancelled reflects status correctly', () {
      final cancelled = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 28),
        status: EventStatus.cancelled,
      );
      final upcoming = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 28),
      );
      expect(cancelled.isCancelled, isTrue);
      expect(upcoming.isCancelled, isFalse);
    });
  });
}
