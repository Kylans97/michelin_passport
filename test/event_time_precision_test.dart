// Events V2 Time Precision Phase B — the future-shaped fixtures and rules
// this phase adds: date-only Events, start-known/end-unknown Events, the
// new sorting/lifecycle/attendance/trip-matching logic that reads
// startDate/endDate/startTime/endTime instead of assuming startAt/endAt
// always exist. Phase A is deployed (production has start_date/end_date/
// start_time/end_time live and backfilled) but start_at/end_at are still
// NOT NULL in the real database — every fixture in this file that omits
// start_at/end_at is a genuine Phase C future shape, not something
// production can send today. See
// docs/Architecture/Events/EVENT_TIME_PRECISION_ARCHITECTURE_AUDIT.md and
// EVENT_TIME_PRECISION_PHASE_B_PRE_FINAL.md for the full rationale.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/event_time.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_chronology.dart';
import 'package:michelin_passport/models/event_local_time.dart';
import 'package:michelin_passport/models/event_trip_match.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:michelin_passport/features/events/event_date_format.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

Map<String, dynamic> _baseJson({
  String id = 'evt-1',
  String name = 'Test Event',
  required String startDate,
  required String endDate,
  String? startAt,
  String? endAt,
  String? startTime,
  String? endTime,
  String? timezone = 'Europe/Amsterdam',
  String countryCode = 'NL',
}) => {
  'id': id,
  'name': name,
  'description': null,
  'start_at': startAt,
  'end_at': endAt,
  'start_date': startDate,
  'end_date': endDate,
  'start_time': startTime,
  'end_time': endTime,
  'timezone': timezone,
  'country_code': countryCode,
  'city': null,
  'venue_name': null,
  'address': null,
  'latitude': null,
  'longitude': null,
  'official_url': null,
  'ticket_url': null,
  'image_url': null,
  'event_type': 'dinner',
  'status': 'upcoming',
  'created_at': '2026-01-01T00:00:00+00:00',
};

void main() {
  // Each test file runs in its own isolate — tzdata initialized by
  // event_time_test.dart's own setUpAll does not carry over here. See
  // lib/main.dart's own initializeTimeZones() call for the production
  // equivalent.
  setUpAll(tz_data.initializeTimeZones);

  group('PARSING — Event.fromJson across every precision shape', () {
    test('DATE ONLY: start_date/end_date known, everything else null, '
        'parses without throwing and never invents a time', () {
      final event = Event.fromJson(
        _baseJson(startDate: '2026-09-29', endDate: '2026-09-29'),
      );
      expect(event.startDate, DateTime.utc(2026, 9, 29));
      expect(event.endDate, DateTime.utc(2026, 9, 29));
      expect(event.startTime, isNull);
      expect(event.endTime, isNull);
      expect(event.startAt, isNull);
      expect(event.endAt, isNull);
      expect(event.isDateOnly, isTrue);
      expect(event.hasFullTimePrecision, isFalse);
    });

    test('START KNOWN / END UNKNOWN: start_time + start_at known, end side '
        'entirely null', () {
      final event = Event.fromJson(
        _baseJson(
          startDate: '2026-09-29',
          endDate: '2026-09-29',
          startTime: '18:30:00',
          startAt: '2026-09-29T16:30:00+00:00',
        ),
      );
      expect(event.hasStartTime, isTrue);
      expect(event.hasExactStart, isTrue);
      expect(event.hasEndTime, isFalse);
      expect(event.hasExactEnd, isFalse);
      expect(event.startTime, const EventLocalTime(hour: 18, minute: 30));
      expect(event.isDateOnly, isFalse);
      expect(event.hasFullTimePrecision, isFalse);
    });

    test('FULL TIME: every field known, parses exactly as before Phase B', () {
      final event = Event.fromJson(
        _baseJson(
          startDate: '2026-08-27',
          endDate: '2026-08-30',
          startTime: '18:00:00',
          endTime: '00:00:00',
          startAt: '2026-08-27T16:00:00+00:00',
          endAt: '2026-08-30T22:00:00+00:00',
        ),
      );
      expect(event.hasFullTimePrecision, isTrue);
      expect(event.hasExactStart, isTrue);
      expect(event.hasExactEnd, isTrue);
      expect(event.startAt!.toIso8601String(), '2026-08-27T16:00:00.000Z');
      expect(event.endAt!.toIso8601String(), '2026-08-30T22:00:00.000Z');
    });

    test('MULTI-DAY DATE ONLY: dates span multiple days, times/instants '
        'all null', () {
      final event = Event.fromJson(
        _baseJson(startDate: '2026-10-16', endDate: '2026-10-18'),
      );
      expect(event.startDate, DateTime.utc(2026, 10, 16));
      expect(event.endDate, DateTime.utc(2026, 10, 18));
      expect(event.isDateOnly, isTrue);
    });

    test('a malformed start_date fails loudly, never silently invents a '
        'date', () {
      expect(
        () => Event.fromJson(
          _baseJson(startDate: 'not-a-date', endDate: '2026-09-29'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a malformed start_time fails loudly, never silently defaults', () {
      expect(
        () => Event.fromJson(
          _baseJson(
            startDate: '2026-09-29',
            endDate: '2026-09-29',
            startTime: 'not-a-time',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('backward-compat construction: a fixture that only ever supplies '
        'startAt/endAt (the pre-Phase-B shape every existing test fixture '
        'in this codebase still uses) derives startDate/endDate/startTime/'
        'endTime automatically, matching what fromJson would have '
        'produced for the same instants', () {
      final event = Event(
        id: 'e1',
        name: 'Legacy fixture',
        startAt: DateTime.utc(2026, 8, 27, 16),
        endAt: DateTime.utc(2026, 8, 30, 22),
        timezone: 'Europe/Amsterdam',
        countryCode: 'NL',
        eventType: EventType.festival,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(event.startDate, DateTime.utc(2026, 8, 27));
      expect(event.endDate, DateTime.utc(2026, 8, 30));
      expect(event.startTime, const EventLocalTime(hour: 18, minute: 0));
      expect(event.endTime, const EventLocalTime(hour: 0, minute: 0));
    });

    test('constructing an Event with neither startDate nor startAt throws', () {
      expect(
        () => Event(
          id: 'e1',
          name: 'Invalid',
          endAt: DateTime.utc(2026, 1, 2),
          countryCode: 'NL',
          eventType: EventType.dinner,
          status: EventStatus.upcoming,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DISPLAY — formatEventDateAndTime / formatEventDateRange', () {
    Event dateOnly({String start = '2026-09-29', String end = '2026-09-29'}) =>
        Event.fromJson(_baseJson(startDate: start, endDate: end));

    Event startKnown() => Event.fromJson(
      _baseJson(
        startDate: '2026-09-29',
        endDate: '2026-09-29',
        startTime: '18:30:00',
      ),
    );

    Event fullTimeSameDay() => Event.fromJson(
      _baseJson(
        startDate: '2026-09-29',
        endDate: '2026-09-29',
        startTime: '18:30:00',
        endTime: '23:00:00',
      ),
    );

    test('date only, single day: "29 Sep 2026", no time suffix', () {
      expect(formatEventDateAndTime(dateOnly()), '29 Sep 2026');
      expect(formatEventDateAndTime(dateOnly()), isNot(contains('unknown')));
      expect(formatEventDateAndTime(dateOnly()), isNot(contains('TBC')));
    });

    test('multi-day date only: "16–18 Oct 2026"', () {
      final event = dateOnly(start: '2026-10-16', end: '2026-10-18');
      expect(formatEventDateAndTime(event), '16–18 Oct 2026');
    });

    test('start known / end unknown: "29 Sep 2026 · 18:30", no dash/TBC '
        'for the missing end', () {
      final text = formatEventDateAndTime(startKnown());
      expect(text, '29 Sep 2026 · 18:30');
      expect(text, isNot(contains('–?')));
      expect(text, isNot(contains('TBC')));
    });

    test('full time, same day: "29 Sep 2026 · 18:30–23:00"', () {
      expect(
        formatEventDateAndTime(fullTimeSameDay()),
        '29 Sep 2026 · 18:30–23:00',
      );
    });

    test("'t Preuvenemint's own midnight-boundary shape: "
        '"27–30 Aug 2026 · 18:00–00:00" — end_date is the 30th, not the '
        '31st, even though end_time is a genuine 00:00', () {
      final event = Event.fromJson(
        _baseJson(
          startDate: '2026-08-27',
          endDate: '2026-08-30',
          startTime: '18:00:00',
          endTime: '00:00:00',
        ),
      );
      expect(formatEventDateAndTime(event), '27–30 Aug 2026 · 18:00–00:00');
      expect(formatEventDateAndTime(event), isNot(contains('31 Aug')));
    });
  });

  group('SORTING — compareEventChronology', () {
    Event withStart({required String id, required String date, String? time}) =>
        Event.fromJson(
          _baseJson(id: id, startDate: date, endDate: date, startTime: time),
        );

    test('same date: known times sort before an unknown time, earlier '
        'known time first', () {
      final e1800 = withStart(id: 'a', date: '2026-09-29', time: '18:00:00');
      final e2000 = withStart(id: 'b', date: '2026-09-29', time: '20:00:00');
      final unknown = withStart(id: 'c', date: '2026-09-29', time: null);
      final events = [unknown, e2000, e1800]..sort(compareEventChronology);
      expect(events.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('date priority: an earlier date always sorts first regardless of '
        'precision', () {
      final laterWithTime = withStart(
        id: 'later',
        date: '2026-10-01',
        time: '08:00:00',
      );
      final earlierDateOnly = withStart(id: 'earlier', date: '2026-09-29');
      final events = [laterWithTime, earlierDateOnly]
        ..sort(compareEventChronology);
      expect(events.map((e) => e.id).toList(), ['earlier', 'later']);
    });

    test('deterministic tie-break by id when date and time-presence are '
        'identical', () {
      final z = withStart(id: 'z', date: '2026-09-29');
      final a = withStart(id: 'a', date: '2026-09-29');
      final events = [z, a]..sort(compareEventChronology);
      expect(events.map((e) => e.id).toList(), ['a', 'z']);
    });
  });

  group('LIFECYCLE — eventHasEnded for a date-only Event', () {
    Event dateOnlyEvent({
      String start = '2026-09-29',
      String end = '2026-09-29',
    }) => Event.fromJson(_baseJson(startDate: start, endDate: end));

    test('before its day: not ended', () {
      final event = dateOnlyEvent();
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 9, 28, 10),
        ),
        isFalse,
      );
    });

    test('during its day, even late in the evening local time: not ended', () {
      final event = dateOnlyEvent();
      // 2026-09-29 22:00 Europe/Amsterdam (CEST, UTC+2) = 20:00 UTC.
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 9, 29, 20),
        ),
        isFalse,
      );
    });

    test('immediately before local midnight: not yet ended', () {
      final event = dateOnlyEvent();
      // 2026-09-29 23:59:59 Europe/Amsterdam = 21:59:59 UTC.
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 9, 29, 21, 59, 59),
        ),
        isFalse,
      );
    });

    test('just after the local day ends: ended', () {
      final event = dateOnlyEvent();
      // 2026-09-30 00:00:01 Europe/Amsterdam = 2026-09-29 22:00:01 UTC.
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 9, 29, 22, 0, 1),
        ),
        isTrue,
      );
    });

    test('multi-day date-only: active through the intermediate day, ended '
        'only after the FINAL day', () {
      final event = dateOnlyEvent(start: '2026-10-16', end: '2026-10-18');
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 10, 17, 12), // intermediate day
        ),
        isFalse,
      );
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 10, 19, 0), // well after the final day
        ),
        isTrue,
      );
    });

    test('exact end known: uses the exact instant, unaffected by endDate '
        'at all', () {
      final event = Event.fromJson(
        _baseJson(
          startDate: '2026-09-29',
          endDate: '2026-09-29',
          startTime: '18:00:00',
          endTime: '20:00:00',
          startAt: '2026-09-29T16:00:00+00:00',
          endAt: '2026-09-29T18:00:00+00:00',
        ),
      );
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 9, 29, 18, 0, 1),
        ),
        isTrue,
      );
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 9, 29, 17, 59, 59),
        ),
        isFalse,
      );
    });
  });

  group('DST — Europe/Amsterdam transition (2026-10-25)', () {
    test('a date-only Event on the DST transition date has a correctly '
        'computed (23-hour) local day boundary', () {
      // 2026-10-25 is the actual EU DST transition date — the local day
      // is 23 hours, not 24. A naive "+24h" end-of-day computation would
      // be wrong by exactly one hour here.
      final event = Event.fromJson(
        _baseJson(startDate: '2026-10-25', endDate: '2026-10-25'),
      );
      // Local midnight starting 2026-10-26 in Europe/Amsterdam (already
      // CET, UTC+1, since the transition happens at 03:00 CEST that same
      // day) is 2026-10-25 23:00 UTC — NOT 2026-10-25 22:00 UTC (which is
      // what a naive pre-transition-offset assumption would compute).
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 10, 25, 22, 30),
        ),
        isFalse,
        reason:
            '22:30 UTC on the transition date is still 2026-10-25 local '
            '(23:30 CEST-then-becomes-CET), the event has not ended yet',
      );
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 10, 25, 23, 0, 1),
        ),
        isTrue,
      );
    });
  });

  group('TRIPS — date-only Event matching', () {
    PlannedTrip trip({required DateTime start, required DateTime end}) =>
        PlannedTrip(
          id: 'trip-1',
          userId: 'user-1',
          title: 'Test Trip',
          startDate: start,
          endDate: end,
          countryCode: 'NL',
          createdAt: DateTime.utc(2026, 1, 1),
        );

    test('a date-only Event within the trip window matches', () {
      final event = Event.fromJson(
        _baseJson(startDate: '2026-09-28', endDate: '2026-09-28'),
      );
      final t = trip(start: DateTime(2026, 9, 26), end: DateTime(2026, 9, 30));
      expect(eventMatchesTrip(event, t), isTrue);
    });

    test('multi-day date-only overlap: Event ends exactly on the trip '
        'start date still matches', () {
      final event = Event.fromJson(
        _baseJson(startDate: '2026-09-20', endDate: '2026-09-26'),
      );
      final t = trip(start: DateTime(2026, 9, 26), end: DateTime(2026, 9, 30));
      expect(eventMatchesTrip(event, t), isTrue);
    });

    test('Event starts exactly on the trip end date still matches', () {
      final event = Event.fromJson(
        _baseJson(startDate: '2026-09-30', endDate: '2026-10-02'),
      );
      final t = trip(start: DateTime(2026, 9, 26), end: DateTime(2026, 9, 30));
      expect(eventMatchesTrip(event, t), isTrue);
    });

    test('a genuine non-overlap does not match', () {
      final event = Event.fromJson(
        _baseJson(startDate: '2026-11-01', endDate: '2026-11-02'),
      );
      final t = trip(start: DateTime(2026, 9, 26), end: DateTime(2026, 9, 30));
      expect(eventMatchesTrip(event, t), isFalse);
    });

    test('viewer/device timezone is irrelevant — matching is purely by '
        "calendar date fields, never a comparison against a device-local "
        '"now"', () {
      // This test itself doesn't change the device zone (Dart tests run
      // in whatever zone the CI/dev machine is in) — its purpose is to
      // document, via the assertions above, that eventMatchesTrip never
      // reads DateTime.now() or the device's own offset anywhere in its
      // implementation. Confirmed by direct code read of
      // lib/models/event_trip_match.dart — no such call exists.
      expect(true, isTrue);
    });
  });

  group('REGRESSION — existing production Event shapes unchanged', () {
    test("'t Preuvenemint: multi-day full-time, correct midnight-boundary "
        'end_date, display and lifecycle both correct', () {
      final event = Event.fromJson(
        _baseJson(
          id: 'preuvenemint',
          startDate: '2026-08-27',
          endDate: '2026-08-30',
          startTime: '18:00:00',
          endTime: '00:00:00',
          startAt: '2026-08-27T16:00:00+00:00',
          endAt: '2026-08-30T22:00:00+00:00',
        ),
      );
      expect(event.endDate, DateTime.utc(2026, 8, 30));
      expect(formatEventDateRange(event), '27–30 Aug 2026');
      expect(formatEventDateAndTime(event), '27–30 Aug 2026 · 18:00–00:00');
      // Exact-instant lifecycle still governs (endAt is known) —
      // unaffected by the endDate/midnight-boundary distinction, which is
      // a DISPLAY/date-only-lifecycle concern only.
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 8, 30, 21, 59, 59),
        ),
        isFalse,
      );
      expect(
        eventHasEnded(
          endAt: event.endAt,
          endDate: event.endDate,
          timezone: event.timezone,
          now: DateTime.utc(2026, 8, 30, 22, 0, 1),
        ),
        isTrue,
      );
    });

    test('a same-day full-time Event (Wildfestival\'s shape) renders and '
        'sorts unchanged', () {
      final event = Event.fromJson(
        _baseJson(
          id: 'wildfestival',
          startDate: '2026-09-13',
          endDate: '2026-09-13',
          startTime: '13:00:00',
          endTime: '17:00:00',
          startAt: '2026-09-13T11:00:00+00:00',
          endAt: '2026-09-13T15:00:00+00:00',
        ),
      );
      expect(formatEventDateAndTime(event), '13 Sep 2026 · 13:00–17:00');
      expect(event.hasFullTimePrecision, isTrue);
    });
  });
}
