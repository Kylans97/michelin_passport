// EVENT WISHLIST V1 — covers scheduleEventWishlist's pure Upcoming/Past
// classification and sort order. Reuses the existing, already-tested
// eventHasEnded/compareEventChronology utilities rather than duplicating
// date/timezone logic — this file only proves the classification/sort
// composition built on top of them.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/wishlist/event_wishlist_schedule.dart';
import 'package:michelin_passport/models/event.dart';

final _now = DateTime.utc(2026, 8, 25, 12);

Event _event({
  String id = 'e1',
  String name = 'Test Event',
  required DateTime startDate,
  required DateTime endDate,
}) => Event(
  id: id,
  name: name,
  startDate: startDate,
  endDate: endDate,
  timezone: 'UTC',
  countryCode: 'FR',
  eventType: EventType.dinner,
  status: EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('scheduleEventWishlist — classification', () {
    test('a future Event is classified as Upcoming', () {
      final event = _event(
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 1),
      );
      final schedule = scheduleEventWishlist([event], now: _now);
      expect(schedule.upcoming, [event]);
      expect(schedule.past, isEmpty);
    });

    test("today's Event (not yet ended) remains Upcoming/ongoing", () {
      final event = _event(
        startDate: DateTime.utc(2026, 8, 25),
        endDate: DateTime.utc(2026, 8, 25),
      );
      final schedule = scheduleEventWishlist([event], now: _now);
      expect(schedule.upcoming, [event]);
      expect(schedule.past, isEmpty);
    });

    test('an ongoing multi-day Event (started in the past, ends in the '
        'future) remains Upcoming', () {
      final event = _event(
        startDate: DateTime.utc(2026, 8, 20),
        endDate: DateTime.utc(2026, 8, 30),
      );
      final schedule = scheduleEventWishlist([event], now: _now);
      expect(schedule.upcoming, [event]);
      expect(schedule.past, isEmpty);
    });

    test('a completed Event is classified as Past', () {
      final event = _event(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 2),
      );
      final schedule = scheduleEventWishlist([event], now: _now);
      expect(schedule.past, [event]);
      expect(schedule.upcoming, isEmpty);
    });

    test('a past Event remains in the schedule — never dropped', () {
      final event = _event(
        id: 'past-1',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 2),
      );
      final schedule = scheduleEventWishlist([event], now: _now);
      expect(schedule.past.map((e) => e.id), contains('past-1'));
    });

    test('Past is empty when every saved Event is upcoming', () {
      final event = _event(
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 1),
      );
      final schedule = scheduleEventWishlist([event], now: _now);
      expect(schedule.past, isEmpty);
    });
  });

  group('scheduleEventWishlist — sort order', () {
    test('Upcoming events sort nearest-first', () {
      final soonest = _event(
        id: 'soonest',
        startDate: DateTime.utc(2026, 8, 26),
        endDate: DateTime.utc(2026, 8, 26),
      );
      final middle = _event(
        id: 'middle',
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 1),
      );
      final furthest = _event(
        id: 'furthest',
        startDate: DateTime.utc(2026, 10, 1),
        endDate: DateTime.utc(2026, 10, 1),
      );
      final schedule = scheduleEventWishlist([furthest, soonest, middle], now: _now);
      expect(
        schedule.upcoming.map((e) => e.id).toList(),
        ['soonest', 'middle', 'furthest'],
      );
    });

    test('Past events sort most-recently-ended first', () {
      final longAgo = _event(
        id: 'long-ago',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 2),
      );
      final recent = _event(
        id: 'recent',
        startDate: DateTime.utc(2026, 8, 20),
        endDate: DateTime.utc(2026, 8, 21),
      );
      final schedule = scheduleEventWishlist([longAgo, recent], now: _now);
      expect(
        schedule.past.map((e) => e.id).toList(),
        ['recent', 'long-ago'],
      );
    });

    test('a mix of past and future events is split and each half sorted '
        'independently', () {
      final future1 = _event(
        id: 'future1',
        startDate: DateTime.utc(2026, 9, 10),
        endDate: DateTime.utc(2026, 9, 10),
      );
      final future2 = _event(
        id: 'future2',
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 1),
      );
      final past1 = _event(
        id: 'past1',
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 1),
      );
      final past2 = _event(
        id: 'past2',
        startDate: DateTime.utc(2026, 7, 1),
        endDate: DateTime.utc(2026, 7, 1),
      );
      final schedule = scheduleEventWishlist(
        [future1, past1, future2, past2],
        now: _now,
      );
      expect(
        schedule.upcoming.map((e) => e.id).toList(),
        ['future2', 'future1'],
      );
      expect(schedule.past.map((e) => e.id).toList(), ['past1', 'past2']);
    });
  });
}
