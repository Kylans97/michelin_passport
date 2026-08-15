// Covers canAttendEvent (Social Foundation Step 2B §21 — event status/
// date safety, extracted as a pure top-level function from
// EventDetailScreen so it's testable without a live Supabase session).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/event_detail_screen.dart';
import 'package:michelin_passport/models/event.dart';

Event _event({
  DateTime? startAt,
  DateTime? endAt,
  EventStatus status = EventStatus.upcoming,
}) => Event(
  id: 'evt-1',
  name: 'Test Event',
  startAt: startAt ?? DateTime(2026, 8, 28),
  endAt: endAt ?? DateTime(2026, 8, 30),
  countryCode: 'NL',
  eventType: EventType.festival,
  status: status,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  final now = DateTime(2026, 8, 15);

  group('canAttendEvent', () {
    test('true for an upcoming, non-cancelled event', () {
      final event = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 30),
      );
      expect(canAttendEvent(event, now: now), isTrue);
    });

    test('false for a cancelled event, even if still upcoming', () {
      final event = _event(
        startAt: DateTime(2026, 8, 28),
        endAt: DateTime(2026, 8, 30),
        status: EventStatus.cancelled,
      );
      expect(canAttendEvent(event, now: now), isFalse);
    });

    test('false for an event that has already ended', () {
      final event = _event(
        startAt: DateTime(2026, 1, 1),
        endAt: DateTime(2026, 1, 2),
      );
      expect(canAttendEvent(event, now: now), isFalse);
    });

    test('false for a completed-status event that already ended', () {
      final event = _event(
        startAt: DateTime(2026, 1, 1),
        endAt: DateTime(2026, 1, 2),
        status: EventStatus.completed,
      );
      expect(canAttendEvent(event, now: now), isFalse);
    });

    test(
      'true for an event currently in progress (started, not yet ended)',
      () {
        final event = _event(
          startAt: DateTime(2026, 8, 14),
          endAt: DateTime(2026, 8, 16),
        );
        expect(canAttendEvent(event, now: now), isTrue);
      },
    );
  });
}
