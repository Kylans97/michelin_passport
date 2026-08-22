// Events V2 Step 8B — Reverse Hosted-Event Discovery.
// Covers upcomingHostedEvents (lib/data/repositories/events_repository.dart)
// — the pure filter/sort function shared by loadHostedEventsForRestaurant/
// ...ForHotel/...ForChef: excludes cancelled and already-ended Events using
// the same precision-aware eventHasEnded every other lifecycle decision in
// this app uses, then sorts via the canonical compareEventChronology.
//
// The is_host = true / is_venue-only / participant-only exclusion itself is
// a SQL WHERE-clause filter (`.eq('is_host', true)`), not Dart branching —
// EventsRepository is Supabase-eager with no mocking harness in this
// project (the same established constraint as every other repository test
// in this codebase), so that half of Step 8B's Host Semantics is proven
// separately, directly against local Postgres — see the Step 8B pre-final
// doc's Host Semantics section for that proof's exact results.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/events_repository.dart';
import 'package:michelin_passport/models/event.dart';

Event _event({
  String id = 'e1',
  String name = 'Test Event',
  DateTime? startAt,
  DateTime? endAt,
  DateTime? startDate,
  DateTime? endDate,
  String? timezone = 'UTC',
  EventStatus status = EventStatus.upcoming,
}) => Event(
  id: id,
  name: name,
  startAt: startAt,
  endAt: endAt,
  startDate: startDate,
  endDate: endDate,
  timezone: timezone,
  countryCode: 'NL',
  eventType: EventType.dinner,
  status: status,
  createdAt: DateTime.utc(2026, 1, 1),
);

DateTime _utc(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);

void main() {
  group('upcomingHostedEvents — lifecycle exclusion', () {
    test('an exact-instant Event that has already ended is excluded', () {
      final ended = _event(
        id: 'ended',
        startAt: _utc(DateTime(2020, 1, 1, 18)),
        endAt: _utc(DateTime(2020, 1, 1, 22)),
      );
      final result = upcomingHostedEvents([
        ended,
      ], now: DateTime.utc(2026, 1, 1));
      expect(result, isEmpty);
    });

    test('a date-only Event whose final local day has fully elapsed is '
        'excluded — never a raw end_at > now check, since end_at is null '
        'by design for this shape', () {
      final endedDateOnly = _event(
        id: 'ended-date-only',
        startDate: DateTime.utc(2020, 1, 1),
        endDate: DateTime.utc(2020, 1, 1),
      );
      expect(endedDateOnly.endAt, isNull);
      final result = upcomingHostedEvents([
        endedDateOnly,
      ], now: DateTime.utc(2026, 1, 1));
      expect(result, isEmpty);
    });

    test('an exact-instant upcoming Event is included', () {
      final upcoming = _event(
        id: 'upcoming',
        startAt: _utc(DateTime(2026, 10, 19, 18)),
        endAt: _utc(DateTime(2026, 10, 19, 22)),
      );
      final result = upcomingHostedEvents([
        upcoming,
      ], now: DateTime.utc(2026, 1, 1));
      expect(result.map((e) => e.id), ['upcoming']);
    });

    test('the real Flore pilot shape (date-only, no exact instants) is '
        'included when its final local day has not yet elapsed', () {
      final pilot = _event(
        id: 'pilot',
        name: '4 Hands Dinner: Bas van Kranen x Sang Hoon Degeimbre',
        startDate: DateTime.utc(2026, 10, 19),
        endDate: DateTime.utc(2026, 10, 19),
        timezone: 'Europe/Amsterdam',
      );
      final result = upcomingHostedEvents([
        pilot,
      ], now: DateTime.utc(2026, 1, 1));
      expect(result.map((e) => e.id), ['pilot']);
    });

    test('a currently-active multi-day Event (started, not yet ended) is '
        'included — there is no separate "has started" check', () {
      final active = _event(
        id: 'active',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 5),
      );
      final result = upcomingHostedEvents([
        active,
      ], now: DateTime.utc(2026, 1, 3));
      expect(result.map((e) => e.id), ['active']);
    });

    test('a cancelled Event is excluded even though its own end date is '
        'still in the future', () {
      final cancelled = _event(
        id: 'cancelled',
        startAt: _utc(DateTime(2026, 10, 19, 18)),
        endAt: _utc(DateTime(2026, 10, 19, 22)),
        status: EventStatus.cancelled,
      );
      final result = upcomingHostedEvents([
        cancelled,
      ], now: DateTime.utc(2026, 1, 1));
      expect(result, isEmpty);
    });
  });

  group('upcomingHostedEvents — sorting', () {
    test('multiple qualifying Events, mixed precision, sort chronologically '
        'via the canonical compareEventChronology — never a second '
        'comparator', () {
      final later = _event(
        id: 'later',
        startDate: DateTime.utc(2026, 11, 1),
        endDate: DateTime.utc(2026, 11, 1),
      );
      final soonestExact = _event(
        id: 'soonest-exact',
        startAt: _utc(DateTime(2026, 10, 19, 18)),
        endAt: _utc(DateTime(2026, 10, 19, 22)),
      );
      final middleDateOnly = _event(
        id: 'middle-date-only',
        startDate: DateTime.utc(2026, 10, 20),
        endDate: DateTime.utc(2026, 10, 20),
      );
      final result = upcomingHostedEvents([
        later,
        middleDateOnly,
        soonestExact,
      ], now: DateTime.utc(2026, 1, 1));
      expect(result.map((e) => e.id), [
        'soonest-exact',
        'middle-date-only',
        'later',
      ]);
    });

    test('an empty input list returns an empty list, not an error', () {
      expect(
        upcomingHostedEvents(const [], now: DateTime.utc(2026, 1, 1)),
        isEmpty,
      );
    });
  });
}
