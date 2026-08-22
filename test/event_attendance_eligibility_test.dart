// Covers Events V2 Step 4's eligibility rules
// (lib/models/event_attendance_eligibility.dart): §3 post-event
// eligibility, §25 lookback window, §26 cancelled events, §27 multi-day
// events, and cross-timezone correctness (the eligibility rules must key
// off Event.endAt's absolute instant, never a rendered/event-local date —
// the same non-negotiable rule Events V2 Timezone Hardening established
// for canAttendEvent).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_attendance.dart';
import 'package:michelin_passport/models/event_attendance_eligibility.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

Event _event({
  String id = 'evt-1',
  required DateTime startAt,
  required DateTime endAt,
  EventStatus status = EventStatus.upcoming,
  String? timezone,
}) => Event(
  id: id,
  name: 'Test Event',
  startAt: startAt,
  endAt: endAt,
  timezone: timezone,
  countryCode: 'NL',
  eventType: EventType.festival,
  status: status,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  final now = DateTime.utc(2026, 9, 1, 12);

  group('resolveAttendanceUiState — §3 base eligibility', () {
    test('ended + Going + no confirmed attendance => promptable', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.promptable,
      );
    });

    test('future event => none, regardless of intent', () {
      final event = _event(
        startAt: now.add(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 2)),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.none,
      );
    });

    test('cancelled event => none, even if ended and Going', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
        status: EventStatus.cancelled,
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.none,
      );
    });

    test('confirmed attendance already exists => attended, regardless of '
        'intent', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: null,
          hasConfirmedAttendance: true,
          now: now,
        ),
        AttendanceUiState.attended,
      );
    });

    test('§27 multi-day event still running (endAt in the future) => none, '
        'even though it started days ago', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.add(const Duration(hours: 1)),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.none,
      );
    });

    test('exactly at endAt counts as ended (inclusive boundary)', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 1)),
        endAt: now,
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.promptable,
      );
    });

    test('ended, no confirmed attendance, but intent was only Interested '
        '=> manualOnly, not promptable', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.interested,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.manualOnly,
      );
    });

    test('§7 ended, never had any intent at all (null) => manualOnly, not '
        'blocked — manual attendance never requires a pre-existing Going '
        'row', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: null,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.manualOnly,
      );
    });
  });

  group('resolveAttendanceUiState — Events V2 Step 5 cancelled + confirmed '
      'attendance precedence bugfix', () {
    test('event completed, confirmed attendance exists => attended', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: null,
          hasConfirmedAttendance: true,
          now: now,
        ),
        AttendanceUiState.attended,
      );
    });

    test('event later marked cancelled, confirmed attendance still exists '
        '=> still attended, not none — a confirmed historical attendance '
        'must survive a later cancellation', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
        status: EventStatus.cancelled,
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: true,
          now: now,
        ),
        AttendanceUiState.attended,
      );
    });

    test('cancelled event, NO confirmed attendance => none — cancellation '
        'must not become manually addable', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
        status: EventStatus.cancelled,
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: null,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.none,
      );
    });

    test('future upcoming event marked cancelled, no confirmed attendance '
        '=> none', () {
      final event = _event(
        startAt: now.add(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 2)),
        status: EventStatus.cancelled,
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: null,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.none,
      );
    });

    test('cancelled event, confirmed attendance exists, event technically '
        'still "upcoming" per its own dates (e.g. end_at edited after the '
        'fact) => attended still wins over the not-yet-ended check', () {
      final event = _event(
        startAt: now.add(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 2)),
        status: EventStatus.cancelled,
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: null,
          hasConfirmedAttendance: true,
          now: now,
        ),
        AttendanceUiState.attended,
      );
    });
  });

  group('resolveAttendanceUiState — §25 lookback window', () {
    test('Going, ended exactly at the edge of the window => still '
        'promptable', () {
      final event = _event(
        startAt: now.subtract(attendancePromptLookbackWindow),
        endAt: now.subtract(attendancePromptLookbackWindow),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.promptable,
      );
    });

    test('Going, ended just past the window (e.g. an 18-month-old row) => '
        'degrades to manualOnly, never re-prompts', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 550)),
        endAt: now.subtract(const Duration(days: 550)),
      );
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: now,
        ),
        AttendanceUiState.manualOnly,
      );
    });

    test('manual attendance remains available outside the window (§25 '
        'explicit requirement) — manualOnly is still a real, renderable '
        'state, not none', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 550)),
        endAt: now.subtract(const Duration(days: 550)),
      );
      final state = resolveAttendanceUiState(
        event: event,
        intent: EventIntentStatus.going,
        hasConfirmedAttendance: false,
        now: now,
      );
      expect(state, isNot(AttendanceUiState.none));
      expect(state, AttendanceUiState.manualOnly);
    });
  });

  group('resolveAttendanceUiState — cross-timezone correctness', () {
    test('eligibility is driven by the absolute end_at instant, not the '
        'event-local rendered date — a Tokyo event technically "ends '
        'tomorrow" in its own local calendar but the instant comparison '
        'must still be exact', () {
      // 23:30 UTC on Aug 31 -> 08:30 JST on Sep 1 in Tokyo's own zone.
      final event = _event(
        startAt: DateTime.utc(2026, 8, 31, 20),
        endAt: DateTime.utc(2026, 8, 31, 23, 30),
        timezone: 'Asia/Tokyo',
      );
      // "now" is 1 minute after the instant end_at — must already read as
      // ended, regardless of what calendar date that instant falls on in
      // Tokyo vs UTC.
      final justAfterEnd = DateTime.utc(2026, 8, 31, 23, 31);
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: justAfterEnd,
        ),
        AttendanceUiState.promptable,
      );
      // One minute BEFORE the instant end_at must still read as not yet
      // ended, even though in Tokyo's own local calendar the event's
      // start date has already passed (it started the day before).
      final justBeforeEnd = DateTime.utc(2026, 8, 31, 23, 29);
      expect(
        resolveAttendanceUiState(
          event: event,
          intent: EventIntentStatus.going,
          hasConfirmedAttendance: false,
          now: justBeforeEnd,
        ),
        AttendanceUiState.none,
      );
    });
  });

  group('mostRecentEligibleAttendancePromptEvent — §24 the Events-screen '
      'ambient nudge', () {
    test('picks the most-recently-ended eligible event, never stacks '
        'multiple', () {
      final older = _event(
        id: 'older',
        startAt: now.subtract(const Duration(days: 10)),
        endAt: now.subtract(const Duration(days: 9)),
      );
      final newer = _event(
        id: 'newer',
        startAt: now.subtract(const Duration(days: 3)),
        endAt: now.subtract(const Duration(days: 2)),
      );
      final result = mostRecentEligibleAttendancePromptEvent(
        pastGoingEvents: [older, newer],
        confirmedEventIds: {},
        now: now,
      );
      expect(result?.id, 'newer');
    });

    test('excludes an event that already has confirmed attendance', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 3)),
        endAt: now.subtract(const Duration(days: 2)),
      );
      final result = mostRecentEligibleAttendancePromptEvent(
        pastGoingEvents: [event],
        confirmedEventIds: {event.id},
        now: now,
      );
      expect(result, isNull);
    });

    test('excludes a cancelled event', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 3)),
        endAt: now.subtract(const Duration(days: 2)),
        status: EventStatus.cancelled,
      );
      final result = mostRecentEligibleAttendancePromptEvent(
        pastGoingEvents: [event],
        confirmedEventIds: {},
        now: now,
      );
      expect(result, isNull);
    });

    test('excludes an event still running (not yet ended)', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 1)),
        endAt: now.add(const Duration(hours: 2)),
      );
      final result = mostRecentEligibleAttendancePromptEvent(
        pastGoingEvents: [event],
        confirmedEventIds: {},
        now: now,
      );
      expect(result, isNull);
    });

    test('excludes an event outside the lookback window — the Events '
        'screen must never surface a months-old nudge', () {
      final event = _event(
        startAt: now.subtract(const Duration(days: 400)),
        endAt: now.subtract(const Duration(days: 400)),
      );
      final result = mostRecentEligibleAttendancePromptEvent(
        pastGoingEvents: [event],
        confirmedEventIds: {},
        now: now,
      );
      expect(result, isNull);
    });

    test('returns null for an empty candidate list', () {
      expect(
        mostRecentEligibleAttendancePromptEvent(
          pastGoingEvents: const [],
          confirmedEventIds: const {},
          now: now,
        ),
        isNull,
      );
    });

    test('deterministic tie-break by id when two events share the exact '
        'same end instant', () {
      final a = _event(
        id: 'a',
        startAt: now.subtract(const Duration(days: 3)),
        endAt: now.subtract(const Duration(days: 2)),
      );
      final b = _event(
        id: 'b',
        startAt: now.subtract(const Duration(days: 3)),
        endAt: now.subtract(const Duration(days: 2)),
      );
      final result = mostRecentEligibleAttendancePromptEvent(
        pastGoingEvents: [b, a],
        confirmedEventIds: {},
        now: now,
      );
      expect(result?.id, 'a');
    });
  });

  group('Events V2 Time Precision Phase B — unknown-end-time Attendance '
      'eligibility', () {
    // A date-only or start-known/end-unknown Event, per the architecture
    // audit's own recommended rule: eligibility waits until the Event's
    // final LOCAL calendar day has fully ended — never the moment the
    // known start time passes, and never a fabricated end instant.
    Event unknownEndEvent({
      String id = 'evt-1',
      required String startDate,
      required String endDate,
      EventStatus status = EventStatus.upcoming,
    }) => Event(
      id: id,
      name: 'Test Event',
      startDate: DateTime.utc(
        int.parse(startDate.split('-')[0]),
        int.parse(startDate.split('-')[1]),
        int.parse(startDate.split('-')[2]),
      ),
      endDate: DateTime.utc(
        int.parse(endDate.split('-')[0]),
        int.parse(endDate.split('-')[1]),
        int.parse(endDate.split('-')[2]),
      ),
      timezone: 'Europe/Amsterdam',
      countryCode: 'NL',
      eventType: EventType.dinner,
      status: status,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    test('does not prompt merely because the Event is later "today" in UTC '
        '— eligibility is not offered at all while the Event is still '
        'upcoming', () {
      final event = unknownEndEvent(
        startDate: '2026-09-29',
        endDate: '2026-09-29',
      );
      final state = resolveAttendanceUiState(
        event: event,
        intent: EventIntentStatus.going,
        hasConfirmedAttendance: false,
        now: DateTime.utc(2026, 9, 29, 10), // well before the local day ends
      );
      expect(state, AttendanceUiState.none);
    });

    test('waits until the local final day fully ends before becoming '
        'promptable, even though a naive "start time has passed" check '
        'would have already fired', () {
      final event = unknownEndEvent(
        startDate: '2026-09-29',
        endDate: '2026-09-29',
      );
      // 2026-09-29 20:00 UTC = 22:00 CEST local — well past a typical
      // evening start time, but the local day has not ended yet.
      final stillActive = resolveAttendanceUiState(
        event: event,
        intent: EventIntentStatus.going,
        hasConfirmedAttendance: false,
        now: DateTime.utc(2026, 9, 29, 20),
      );
      expect(stillActive, AttendanceUiState.none);

      // 2026-09-29 22:00:01 UTC = 2026-09-30 00:00:01 CEST — just past the
      // local day boundary.
      final nowEnded = resolveAttendanceUiState(
        event: event,
        intent: EventIntentStatus.going,
        hasConfirmedAttendance: false,
        now: DateTime.utc(2026, 9, 29, 22, 0, 1),
      );
      expect(nowEnded, AttendanceUiState.promptable);
    });

    test('multi-day date-only Event: waits until the FINAL day ends, not '
        'the first', () {
      final event = unknownEndEvent(
        startDate: '2026-10-16',
        endDate: '2026-10-18',
      );
      final duringFestival = resolveAttendanceUiState(
        event: event,
        intent: EventIntentStatus.going,
        hasConfirmedAttendance: false,
        now: DateTime.utc(2026, 10, 17, 12),
      );
      expect(duringFestival, AttendanceUiState.none);

      final afterFestival = resolveAttendanceUiState(
        event: event,
        intent: EventIntentStatus.going,
        hasConfirmedAttendance: false,
        now: DateTime.utc(2026, 10, 19, 0),
      );
      expect(afterFestival, AttendanceUiState.promptable);
    });

    test('exact end known (full-time Event, the existing regression case): '
        'unaffected, still uses the precise endAt instant', () {
      final event = _event(
        startAt: DateTime.utc(2026, 9, 29, 16),
        endAt: DateTime.utc(2026, 9, 29, 18),
      );
      final beforeExactEnd = resolveAttendanceUiState(
        event: event,
        intent: EventIntentStatus.going,
        hasConfirmedAttendance: false,
        now: DateTime.utc(2026, 9, 29, 17, 59, 59),
      );
      expect(beforeExactEnd, AttendanceUiState.none);

      final afterExactEnd = resolveAttendanceUiState(
        event: event,
        intent: EventIntentStatus.going,
        hasConfirmedAttendance: false,
        now: DateTime.utc(2026, 9, 29, 18, 0, 1),
      );
      expect(afterExactEnd, AttendanceUiState.promptable);
    });
  });
}
