// TRIPS HERO REDESIGN: covers the pure trip-scheduling logic
// (isUpcomingTrip/upcomingTrips/tripStartLabel) that determines which
// trip becomes the Trips subsection's featured TripHeroCard.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/trips/trip_schedule.dart';
import 'package:michelin_passport/models/planned_trip.dart';

PlannedTrip _trip({
  String id = 't1',
  String title = 'Maastricht',
  required DateTime startDate,
  required DateTime endDate,
}) => PlannedTrip(
  id: id,
  userId: 'u1',
  title: title,
  startDate: startDate,
  endDate: endDate,
  countryCode: 'NL',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  final now = DateTime(2026, 8, 24);

  group('isUpcomingTrip / upcomingTrips', () {
    test('a trip ending in the future is upcoming', () {
      final trip = _trip(
        startDate: DateTime(2026, 8, 26),
        endDate: DateTime(2026, 8, 31),
      );
      expect(isUpcomingTrip(trip, now: now), isTrue);
    });

    test('a trip currently underway (today within start/end) is still '
        'upcoming', () {
      final trip = _trip(
        startDate: DateTime(2026, 8, 20),
        endDate: DateTime(2026, 8, 28),
      );
      expect(isUpcomingTrip(trip, now: now), isTrue);
    });

    test('a trip ending today is still upcoming (the whole day counts)', () {
      final trip = _trip(
        startDate: DateTime(2026, 8, 20),
        endDate: DateTime(2026, 8, 24),
      );
      expect(isUpcomingTrip(trip, now: now), isTrue);
    });

    test('a trip that fully ended in the past is not upcoming', () {
      final trip = _trip(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 10),
      );
      expect(isUpcomingTrip(trip, now: now), isFalse);
    });

    test('upcomingTrips filters out past trips and sorts the rest '
        'soonest-first, regardless of input order', () {
      final past = _trip(
        id: 'past',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 5),
      );
      final soonest = _trip(
        id: 'soonest',
        startDate: DateTime(2026, 8, 26),
        endDate: DateTime(2026, 8, 31),
      );
      final later = _trip(
        id: 'later',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 10),
      );
      final result = upcomingTrips([later, past, soonest], now: now);
      expect(result.map((t) => t.id).toList(), ['soonest', 'later']);
    });

    test('upcomingTrips returns an empty list when every trip has ended', () {
      final past = _trip(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 5),
      );
      expect(upcomingTrips([past], now: now), isEmpty);
    });
  });

  group('tripStartLabel', () {
    test('starts tomorrow', () {
      expect(tripStartLabel(DateTime(2026, 8, 25), now: now), 'Starts tomorrow');
    });

    test('starts today', () {
      expect(tripStartLabel(DateTime(2026, 8, 24), now: now), 'Starts today');
    });

    test('multiple days away renders "In N days"', () {
      expect(tripStartLabel(DateTime(2026, 9, 10), now: now), 'In 17 days');
    });

    test('a trip that already started returns null — never a negative '
        'day count', () {
      expect(tripStartLabel(DateTime(2026, 8, 20), now: now), isNull);
    });

    test('exactly one day away is "tomorrow", not "In 1 days"', () {
      final label = tripStartLabel(DateTime(2026, 8, 25), now: now);
      expect(label, isNot(contains('In 1')));
    });
  });
}
