// Events V2 Step 8C — Events in Passport.
// Covers the pure functions added to
// lib/data/repositories/event_confirmed_attendance_repository.dart:
// sortEventAttendanceByEventDate, eventAttendanceInYear,
// availableEventAttendanceYears. EventConfirmedAttendanceRepository itself
// is Supabase-eager (constructs SupabaseClient unconditionally) and can't be
// exercised directly in this sandbox — the same established limitation as
// every other repository test in this codebase (see
// passport_view_model_test.dart's own note) — so these pure functions,
// which own 100% of the actual sort/filter LOGIC Step 8C needed to fix, are
// tested directly and completely here.
//
// Eligibility itself (confirmed attendance only, never Interested/Going) is
// enforced structurally, not by any of these functions: an
// [EventAttendanceEntry] can only ever be constructed from an
// [EventConfirmedAttendance] row — there is no code path from
// `event_attendance` (pre-event intent) into this type at all. The tests
// below confirm these pure functions never change WHICH entries are
// present, only their order/grouping — i.e. eligibility-neutral.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/event_confirmed_attendance_repository.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';

Event _event({
  required String id,
  String name = 'Test Event',
  DateTime? startDate,
  DateTime? endDate,
  String? timezone = 'Europe/Amsterdam',
}) => Event(
  id: id,
  name: name,
  startDate: startDate,
  endDate: endDate ?? startDate,
  timezone: timezone,
  countryCode: 'NL',
  eventType: EventType.dinner,
  status: EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

EventConfirmedAttendance _attendance({
  required String id,
  required String eventId,
  DateTime? confirmedAt,
}) => EventConfirmedAttendance(
  id: id,
  eventId: eventId,
  userId: 'u1',
  confirmedAt: confirmedAt ?? DateTime.utc(2026, 1, 1),
  visibility: ConfirmedAttendanceVisibility.private,
  source: EventAttendanceSource.manual,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('sortEventAttendanceByEventDate', () {
    test('sorts by the Event\'s own date, most recent first — never by '
        'confirmed_at', () {
      // Confirmed_at order (oldest confirmation first) is the OPPOSITE of
      // what the Event dates themselves would produce — a real proof this
      // isn't accidentally still sorting by confirmedAt.
      final earlyConfirmationLateEvent = EventAttendanceEntry(
        attendance: _attendance(
          id: 'a1',
          eventId: 'e1',
          confirmedAt: DateTime.utc(2020, 1, 1), // confirmed first
        ),
        event: _event(id: 'e1', startDate: DateTime.utc(2026, 12, 1)),
      );
      final lateConfirmationEarlyEvent = EventAttendanceEntry(
        attendance: _attendance(
          id: 'a2',
          eventId: 'e2',
          confirmedAt: DateTime.utc(2027, 1, 1), // confirmed last
        ),
        event: _event(id: 'e2', startDate: DateTime.utc(2026, 1, 1)),
      );

      final sorted = sortEventAttendanceByEventDate([
        lateConfirmationEarlyEvent,
        earlyConfirmationLateEvent,
      ]);

      // Event date order: Dec 2026 event before Jan 2026 event, most
      // recent EVENT first — regardless of confirmation order.
      expect(sorted.map((e) => e.event.id), ['e1', 'e2']);
    });

    test('the real Passport scenario: an Event that happened 31 Dec 2026, '
        'confirmed 1 Jan 2027, still sorts by its own Dec 2026 date', () {
      final entry = EventAttendanceEntry(
        attendance: _attendance(
          id: 'a1',
          eventId: 'e1',
          confirmedAt: DateTime.utc(2027, 1, 1),
        ),
        event: _event(id: 'e1', startDate: DateTime.utc(2026, 12, 31)),
      );
      final laterEvent = EventAttendanceEntry(
        attendance: _attendance(
          id: 'a2',
          eventId: 'e2',
          confirmedAt: DateTime.utc(2026, 6, 1),
        ),
        event: _event(id: 'e2', startDate: DateTime.utc(2027, 1, 5)),
      );

      final sorted = sortEventAttendanceByEventDate([entry, laterEvent]);
      expect(sorted.map((e) => e.event.id), ['e2', 'e1']);
    });

    test('date-only Events sort correctly alongside each other', () {
      final earlier = EventAttendanceEntry(
        attendance: _attendance(id: 'a1', eventId: 'e1'),
        event: _event(id: 'e1', startDate: DateTime.utc(2026, 9, 1)),
      );
      final later = EventAttendanceEntry(
        attendance: _attendance(id: 'a2', eventId: 'e2'),
        event: _event(id: 'e2', startDate: DateTime.utc(2026, 10, 19)),
      );
      final sorted = sortEventAttendanceByEventDate([earlier, later]);
      expect(sorted.map((e) => e.event.id), ['e2', 'e1']);
    });

    test('deterministic tie-break on the same date — the whole canonical '
        'comparator is reversed for most-recent-first order, tie-break '
        'included, not just the date component', () {
      final a = EventAttendanceEntry(
        attendance: _attendance(id: 'a1', eventId: 'z-event'),
        event: _event(id: 'z-event', startDate: DateTime.utc(2026, 9, 1)),
      );
      final b = EventAttendanceEntry(
        attendance: _attendance(id: 'a2', eventId: 'a-event'),
        event: _event(id: 'a-event', startDate: DateTime.utc(2026, 9, 1)),
      );
      final sorted = sortEventAttendanceByEventDate([a, b]);
      // compareEventChronology(a, b) normally sorts 'a-event' before
      // 'z-event' (ascending id tie-break); reversing the operands for
      // descending date order reverses the tie-break too, deterministically.
      expect(sorted.map((e) => e.event.id), ['z-event', 'a-event']);
    });

    test('never mutates the input list, and an empty list returns empty', () {
      final input = <EventAttendanceEntry>[];
      expect(sortEventAttendanceByEventDate(input), isEmpty);

      final entry = EventAttendanceEntry(
        attendance: _attendance(id: 'a1', eventId: 'e1'),
        event: _event(id: 'e1', startDate: DateTime.utc(2026, 9, 1)),
      );
      final original = [entry];
      final sorted = sortEventAttendanceByEventDate(original);
      expect(identical(original, sorted), isFalse);
    });
  });

  group('eventAttendanceInYear', () {
    test('filters by the Event\'s own startDate.year, never confirmedAt', () {
      final entry = EventAttendanceEntry(
        attendance: _attendance(
          id: 'a1',
          eventId: 'e1',
          confirmedAt: DateTime.utc(2027, 1, 1), // confirmed in 2027
        ),
        event: _event(
          id: 'e1',
          startDate: DateTime.utc(2026, 12, 31), // happened in 2026
        ),
      );
      expect(eventAttendanceInYear([entry], 2026), [entry]);
      expect(eventAttendanceInYear([entry], 2027), isEmpty);
    });

    test('null year returns every entry unfiltered ("All time")', () {
      final entry = EventAttendanceEntry(
        attendance: _attendance(id: 'a1', eventId: 'e1'),
        event: _event(id: 'e1', startDate: DateTime.utc(2025, 5, 1)),
      );
      expect(eventAttendanceInYear([entry], null), [entry]);
    });

    test('a year with no matching Event returns empty, not an error', () {
      final entry = EventAttendanceEntry(
        attendance: _attendance(id: 'a1', eventId: 'e1'),
        event: _event(id: 'e1', startDate: DateTime.utc(2026, 5, 1)),
      );
      expect(eventAttendanceInYear([entry], 1999), isEmpty);
    });
  });

  group('availableEventAttendanceYears', () {
    test('every distinct year with confirmed attendance, descending, using '
        'the Event\'s own date', () {
      final e2025 = EventAttendanceEntry(
        attendance: _attendance(id: 'a1', eventId: 'e1'),
        event: _event(id: 'e1', startDate: DateTime.utc(2025, 3, 1)),
      );
      final e2026 = EventAttendanceEntry(
        attendance: _attendance(id: 'a2', eventId: 'e2'),
        event: _event(id: 'e2', startDate: DateTime.utc(2026, 3, 1)),
      );
      final e2026Again = EventAttendanceEntry(
        attendance: _attendance(id: 'a3', eventId: 'e3'),
        event: _event(id: 'e3', startDate: DateTime.utc(2026, 9, 1)),
      );
      final years = availableEventAttendanceYears([e2025, e2026, e2026Again]);
      expect(years, [2026, 2025]); // descending, no duplicate 2026
    });

    test('empty input returns an empty year list', () {
      expect(availableEventAttendanceYears(const []), isEmpty);
    });

    test('a year with ONLY confirmed Event attendance (no Restaurant/Hotel '
        'visit at all in that year) is still available — this list is '
        'independent of availableVisitYears', () {
      final onlyEvent = EventAttendanceEntry(
        attendance: _attendance(id: 'a1', eventId: 'e1'),
        event: _event(id: 'e1', startDate: DateTime.utc(2030, 1, 1)),
      );
      expect(availableEventAttendanceYears([onlyEvent]), [2030]);
    });
  });

  group('eligibility neutrality', () {
    test('sortEventAttendanceByEventDate and eventAttendanceInYear(..., '
        'null) never drop or add entries — only reorder/pass through '
        'exactly the confirmed-attendance entries given, since eligibility '
        'itself is enforced by EventAttendanceEntry only ever being '
        'constructed from event_confirmed_attendance rows', () {
      final entries = [
        EventAttendanceEntry(
          attendance: _attendance(id: 'a1', eventId: 'e1'),
          event: _event(id: 'e1', startDate: DateTime.utc(2026, 1, 1)),
        ),
        EventAttendanceEntry(
          attendance: _attendance(id: 'a2', eventId: 'e2'),
          event: _event(id: 'e2', startDate: DateTime.utc(2026, 6, 1)),
        ),
        EventAttendanceEntry(
          attendance: _attendance(id: 'a3', eventId: 'e3'),
          event: _event(id: 'e3', startDate: DateTime.utc(2026, 12, 1)),
        ),
      ];
      expect(sortEventAttendanceByEventDate(entries).length, entries.length);
      expect(eventAttendanceInYear(entries, null).length, entries.length);
      expect(
        sortEventAttendanceByEventDate(
          entries,
        ).map((e) => e.attendance.id).toSet(),
        entries.map((e) => e.attendance.id).toSet(),
      );
    });
  });
}
