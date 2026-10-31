import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/planning/trips_for_planning.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:michelin_passport/models/trip_destination.dart';

PlannedTrip _trip(
  String id,
  String country,
  String start,
  String end, {
  List<String> legs = const [],
}) => PlannedTrip(
  id: id,
  userId: 'u1',
  title: id,
  startDate: DateTime.parse(start),
  endDate: DateTime.parse(end),
  countryCode: country,
  createdAt: DateTime(2026, 1, 1),
  destinations: [for (final c in legs) TripDestination(countryCode: c)],
);

void main() {
  final today = DateTime(2026, 10, 31, 15);
  List<String> ids(List<PlanTripChoice> c) => [for (final x in c) x.trip.id];

  test('only trips with a destination in the venue\'s country', () {
    final trips = [
      _trip('amsterdam', 'NL', '2026-11-10', '2026-11-12'),
      _trip('paris', 'FR', '2026-11-20', '2026-11-22'),
      _trip('benelux', 'BE', '2026-12-01', '2026-12-05', legs: ['BE', 'NL']),
    ];
    expect(ids(tripsForPlanning(trips, countryCode: 'NL', today: today)), [
      'amsterdam',
      'benelux',
    ]);
  });

  test('upcoming and ongoing trips, soonest first; of the ended ones only '
      'the most recent, last and marked ended', () {
    final trips = [
      _trip('later', 'NL', '2026-12-10', '2026-12-12'),
      _trip('now', 'NL', '2026-10-30', '2026-11-02'),
      _trip('ends-today', 'NL', '2026-10-28', '2026-10-31'),
      _trip('last-week', 'NL', '2026-10-20', '2026-10-24'),
      _trip('summer', 'NL', '2026-07-01', '2026-07-05'),
    ];
    final result = tripsForPlanning(trips, countryCode: 'NL', today: today);
    expect(ids(result), ['ends-today', 'now', 'later', 'last-week']);
    expect([for (final c in result) c.ended], [false, false, false, true]);
  });

  test('the trip the plan is already in is kept, even ended or abroad', () {
    final trips = [
      _trip('summer', 'NL', '2026-07-01', '2026-07-05'),
      _trip('last-week', 'NL', '2026-10-20', '2026-10-24'),
      _trip('rome', 'IT', '2026-12-01', '2026-12-03'),
    ];
    expect(
      ids(
        tripsForPlanning(
          trips,
          countryCode: 'NL',
          today: today,
          keepTripId: 'summer',
        ),
      ),
      ['last-week', 'summer'],
    );
    expect(
      ids(
        tripsForPlanning(
          trips,
          countryCode: 'NL',
          today: today,
          keepTripId: 'rome',
        ),
      ),
      ['last-week', 'rome'],
    );
  });

  test('a venue without a country filters on dates only', () {
    final trips = [
      _trip('nl', 'NL', '2026-11-10', '2026-11-12'),
      _trip('fr', 'FR', '2026-11-20', '2026-11-22'),
    ];
    expect(ids(tripsForPlanning(trips, countryCode: '', today: today)), [
      'nl',
      'fr',
    ]);
  });
}
