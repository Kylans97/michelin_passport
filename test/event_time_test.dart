// Covers Events V2 Timezone Hardening's central conversion/formatting
// layer (lib/core/utils/event_time.dart, lib/features/events/
// event_date_format.dart). The product rule under test: an Event's
// date/time must always render in the EVENT'S OWN IANA zone, derived from
// its absolute instant + timezone — never the viewer/device's zone, and
// never by inspecting how the input DateTime happens to already be
// tagged. Reference zones were picked deliberately: Europe/Amsterdam
// (has DST), Asia/Tokyo and Asia/Dubai (fixed offset, no DST, both ahead
// of UTC so they exercise the "local date is already tomorrow" case),
// America/New_York (has DST, behind UTC, so it exercises the "local date
// is still yesterday" case).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/event_time.dart';
import 'package:michelin_passport/features/events/event_date_format.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_trip_match.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  // The "_all" variant, matching lib/main.dart's own initializer exactly —
  // "Europe/Amsterdam" (used throughout these tests, and by every real
  // event today) doesn't resolve under the smaller default variant; see
  // lib/main.dart's initializeTimeZones() comment for the full story.
  setUpAll(tz_data.initializeTimeZones);

  group('eventLocalDateTime — reference zone conversions', () {
    test('Europe/Amsterdam in summer (CEST, UTC+2)', () {
      final local = eventLocalDateTime(
        DateTime.utc(2026, 8, 27, 16),
        'Europe/Amsterdam',
      );
      expect(local.year, 2026);
      expect(local.month, 8);
      expect(local.day, 27);
      expect(local.hour, 18);
    });

    test('Europe/Amsterdam in winter (CET, UTC+1)', () {
      final local = eventLocalDateTime(
        DateTime.utc(2026, 1, 15, 16),
        'Europe/Amsterdam',
      );
      expect(local.day, 15);
      expect(local.hour, 17);
    });

    test('Europe/Amsterdam spring-forward DST transition (2026-03-29, '
        '01:00 UTC): offset jumps from +1 to +2 within the same UTC day', () {
      final before = eventLocalDateTime(
        DateTime.utc(2026, 3, 29, 0, 30),
        'Europe/Amsterdam',
      );
      final after = eventLocalDateTime(
        DateTime.utc(2026, 3, 29, 1, 30),
        'Europe/Amsterdam',
      );
      expect(before.hour, 1); // CET, UTC+1
      expect(after.hour, 3); // CEST, UTC+2 — an hour "disappears"
    });

    test('Europe/Amsterdam fall-back DST transition (2026-10-25, '
        '01:00 UTC): offset drops from +2 to +1', () {
      final before = eventLocalDateTime(
        DateTime.utc(2026, 10, 25, 0, 30),
        'Europe/Amsterdam',
      );
      final after = eventLocalDateTime(
        DateTime.utc(2026, 10, 25, 2, 30),
        'Europe/Amsterdam',
      );
      expect(before.hour, 2); // CEST, UTC+2
      expect(after.hour, 3); // CET, UTC+1
    });

    test('Asia/Tokyo has no DST — same +9 offset in January and August, '
        'and both cross the UTC calendar-date boundary', () {
      final august = eventLocalDateTime(
        DateTime.utc(2026, 8, 27, 16),
        'Asia/Tokyo',
      );
      final january = eventLocalDateTime(
        DateTime.utc(2026, 1, 27, 16),
        'Asia/Tokyo',
      );
      expect(august.day, 28); // next calendar day in Tokyo
      expect(august.hour, 1);
      expect(january.day, 28);
      expect(january.hour, 1);
    });

    test('Asia/Dubai has no DST — same +4 offset in January and July', () {
      final january = eventLocalDateTime(
        DateTime.utc(2026, 1, 15, 20),
        'Asia/Dubai',
      );
      final july = eventLocalDateTime(
        DateTime.utc(2026, 7, 15, 20),
        'Asia/Dubai',
      );
      expect(january.day, 16); // next calendar day in Dubai
      expect(january.hour, 0);
      expect(july.day, 16);
      expect(july.hour, 0);
    });

    test('America/New_York DST: summer EDT (UTC-4) vs winter EST (UTC-5)', () {
      final summer = eventLocalDateTime(
        DateTime.utc(2026, 7, 4, 16),
        'America/New_York',
      );
      final winter = eventLocalDateTime(
        DateTime.utc(2026, 1, 4, 16),
        'America/New_York',
      );
      expect(summer.hour, 12); // EDT, UTC-4
      expect(summer.day, 4);
      expect(winter.hour, 11); // EST, UTC-5
      expect(winter.day, 4);
    });

    test('a zone behind UTC can put the event-local date a day BEHIND the '
        'UTC date (the mirror case of Tokyo/Dubai being a day ahead)', () {
      final local = eventLocalDateTime(
        DateTime.utc(2026, 8, 28, 2), // 02:00 UTC on the 28th
        'America/New_York',
      );
      expect(local.day, 27); // still the 27th in New York (EDT, UTC-4)
      expect(local.hour, 22);
    });
  });

  group('eventLocalDateTime — fallback behavior (never device-local)', () {
    final instant = DateTime.utc(2026, 8, 27, 16);

    test('null timezone falls back to UTC', () {
      final result = eventLocalDateTime(instant, null);
      expect(result.day, 27);
      expect(result.hour, 16);
      expect(identical(result.location, tz.UTC), isTrue);
    });

    test('empty-string timezone falls back to UTC', () {
      final result = eventLocalDateTime(instant, '');
      expect(result.hour, 16);
    });

    test('an invalid/unrecognized IANA identifier falls back to UTC rather '
        'than throwing', () {
      expect(() => eventLocalDateTime(instant, 'Not/AZone'), returnsNormally);
      final result = eventLocalDateTime(instant, 'Not/AZone');
      expect(result.hour, 16);
    });

    test('conversion depends only on the instant, never on how the input '
        'DateTime happens to already be tagged — the exact leak the '
        '.toLocal() bug this hardening fixes would have caused', () {
      final ms = DateTime.utc(2026, 8, 27, 16).millisecondsSinceEpoch;
      final utcTagged = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      final deviceTagged = DateTime.fromMillisecondsSinceEpoch(ms);
      final fromUtcTagged = eventLocalDateTime(utcTagged, 'Asia/Tokyo');
      final fromDeviceTagged = eventLocalDateTime(deviceTagged, 'Asia/Tokyo');
      expect(fromUtcTagged.hour, fromDeviceTagged.hour);
      expect(fromUtcTagged.day, fromDeviceTagged.day);
    });
  });

  group('formatEventDateTime — event-local rendering', () {
    test('a Tokyo event at 19:00 JST shows 19:00, not the UTC hour', () {
      // 19:00 JST == 10:00 UTC.
      final text = formatEventDateTime(
        DateTime.utc(2026, 8, 27, 10),
        'Asia/Tokyo',
      );
      expect(text, contains('19:00'));
      expect(text, contains('27 Aug 2026'));
    });

    test('the same instant renders a different wall-clock time per zone — '
        'proving rendering is event-local, not viewer-local', () {
      final instant = DateTime.utc(2026, 8, 27, 16);
      final tokyo = formatEventDateTime(instant, 'Asia/Tokyo');
      final amsterdam = formatEventDateTime(instant, 'Europe/Amsterdam');
      final newYork = formatEventDateTime(instant, 'America/New_York');
      expect(tokyo, contains('01:00'));
      expect(amsterdam, contains('18:00'));
      expect(newYork, contains('12:00'));
    });
  });

  group('formatEventDateRange — date range formatting', () {
    Event event({
      required DateTime startAt,
      required DateTime endAt,
      String? tz,
    }) => Event(
      id: 'e1',
      name: 'Test',
      startAt: startAt,
      endAt: endAt,
      timezone: tz,
      countryCode: 'NL',
      eventType: EventType.festival,
      status: EventStatus.upcoming,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    test('same-day event renders a single date', () {
      final e = event(
        startAt: DateTime.utc(2026, 8, 27, 16),
        endAt: DateTime.utc(2026, 8, 27, 20),
        tz: 'Europe/Amsterdam',
      );
      expect(formatEventDateRange(e), '27 Aug 2026');
    });

    test('a Preuvenemint-style broad multi-day range renders start–end '
        'within the same month', () {
      final e = event(
        startAt: DateTime.utc(2026, 8, 27, 16),
        endAt: DateTime.utc(2026, 8, 30, 19), // 21:00 CEST, still the 30th
        tz: 'Europe/Amsterdam',
      );
      expect(formatEventDateRange(e), '27–30 Aug 2026');
    });

    test('an overnight event that is same-UTC-day but crosses the '
        "event-local midnight renders as TWO calendar days — the exact "
        'regression this hardening pass fixes (a naive UTC-date check '
        'would have shown only one day)', () {
      // Both instants fall on 2026-08-27 in UTC, but 23:00-01:00 JST spans
      // the 27th into the 28th in Tokyo.
      final e = event(
        startAt: DateTime.utc(2026, 8, 27, 14), // 23:00 JST on the 27th
        endAt: DateTime.utc(2026, 8, 27, 16), // 01:00 JST on the 28th
        tz: 'Asia/Tokyo',
      );
      expect(formatEventDateRange(e), '27–28 Aug 2026');
    });

    test('a range crossing a month boundary renders both months', () {
      final e = event(
        startAt: DateTime.utc(2026, 8, 30, 10),
        endAt: DateTime.utc(2026, 9, 2, 10),
        tz: 'Europe/Amsterdam',
      );
      expect(formatEventDateRange(e), '30 Aug – 2 Sep 2026');
    });

    test('a range crossing a year boundary renders both years', () {
      final e = event(
        startAt: DateTime.utc(2026, 12, 30, 10),
        endAt: DateTime.utc(2027, 1, 2, 10),
        tz: 'Europe/Amsterdam',
      );
      expect(formatEventDateRange(e), '30 Dec 2026 – 2 Jan 2027');
    });
  });

  group('Event.fromJson — timezone parsing', () {
    Map<String, dynamic> baseJson() => {
      'id': 'evt-1',
      'name': 'Test Event',
      'description': null,
      'start_at': '2026-08-27T16:00:00+00:00',
      'end_at': '2026-08-30T22:00:00+00:00',
      'start_date': '2026-08-27',
      'end_date': '2026-08-30',
      'country_code': 'NL',
      'city': 'Maastricht',
      'venue_name': null,
      'address': null,
      'latitude': null,
      'longitude': null,
      'official_url': null,
      'ticket_url': null,
      'image_url': null,
      'event_type': 'festival',
      'status': 'upcoming',
      'created_at': '2026-08-10T12:00:00+00:00',
    };

    test('a valid IANA timezone parses through unchanged', () {
      final event = Event.fromJson(
        baseJson()..['timezone'] = 'Europe/Amsterdam',
      );
      expect(event.timezone, 'Europe/Amsterdam');
    });

    test('a row with no timezone key at all (pre-backfill/pre-migration '
        'data) parses to null, never crashes', () {
      final event = Event.fromJson(baseJson());
      expect(event.timezone, isNull);
    });

    test('an explicit JSON null timezone parses to null', () {
      final event = Event.fromJson(baseJson()..['timezone'] = null);
      expect(event.timezone, isNull);
    });

    test('startAt/endAt are never converted to device-local — parsing '
        'preserves the absolute instant exactly as sent, tagged UTC', () {
      final event = Event.fromJson(baseJson());
      expect(event.startAt!.isUtc, isTrue);
      expect(event.endAt!.isUtc, isTrue);
      expect(event.startAt!.toIso8601String(), '2026-08-27T16:00:00.000Z');
      expect(event.endAt!.toIso8601String(), '2026-08-30T22:00:00.000Z');
    });
  });

  group('eventMatchesTrip — event-local calendar date (not device/UTC '
      'date)', () {
    PlannedTrip trip({required DateTime start, required DateTime end}) =>
        PlannedTrip(
          id: 'trip-1',
          userId: 'user-1',
          title: 'Test Trip',
          startDate: start,
          endDate: end,
          countryCode: 'JP',
          city: null,
          createdAt: DateTime.utc(2026, 1, 1),
        );

    test('an event whose UTC date is the 30th but whose Tokyo-local date '
        'is already the 31st matches a trip booked ONLY for the 31st — '
        'the naive UTC-date comparison this fix replaces would have '
        'missed it', () {
      final event = Event(
        id: 'e1',
        name: 'Test',
        startAt: DateTime.utc(2026, 8, 30, 20), // 05:00 JST on the 31st
        endAt: DateTime.utc(2026, 8, 30, 22),
        timezone: 'Asia/Tokyo',
        countryCode: 'JP',
        eventType: EventType.festival,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final tripOn31st = trip(
        start: DateTime.utc(2026, 8, 31),
        end: DateTime.utc(2026, 8, 31),
      );
      expect(eventMatchesTrip(event, tripOn31st), isTrue);
    });

    test('an event whose UTC date is the 28th but whose New York-local '
        'date is still the 27th does NOT match a trip booked only for the '
        '28th', () {
      final event = Event(
        id: 'e2',
        name: 'Test',
        startAt: DateTime.utc(2026, 8, 28, 2), // 22:00 EDT on the 27th
        endAt: DateTime.utc(2026, 8, 28, 3),
        timezone: 'America/New_York',
        countryCode: 'US',
        eventType: EventType.festival,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final tripOn28th = trip(
        start: DateTime.utc(2026, 8, 28),
        end: DateTime.utc(2026, 8, 28),
      );
      expect(eventMatchesTrip(event, tripOn28th), isFalse);
    });
  });

  group('eventsMatchingTrip — sorting stays instant-based across mixed '
      'timezones', () {
    test('events from different zones still sort by absolute instant, not '
        'by their own local wall-clock hour', () {
      final trip = PlannedTrip(
        id: 'trip-1',
        userId: 'user-1',
        title: 'Test',
        startDate: DateTime.utc(2026, 8, 27),
        endDate: DateTime.utc(2026, 8, 31),
        countryCode: 'NL',
        city: null,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      // "later" starts at an earlier UTC instant than "earlier" does, but
      // its Tokyo-local wall-clock HOUR (01:00) reads smaller than
      // "earlier"'s Amsterdam-local hour (18:00) — sorting must not be
      // fooled by that.
      final earlier = Event(
        id: 'earlier',
        name: 'Earlier (Amsterdam)',
        startAt: DateTime.utc(2026, 8, 28, 16), // 18:00 CEST on the 28th
        endAt: DateTime.utc(2026, 8, 28, 20),
        timezone: 'Europe/Amsterdam',
        countryCode: 'NL',
        eventType: EventType.festival,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final later = Event(
        id: 'later',
        name: 'Later (Tokyo)',
        startAt: DateTime.utc(2026, 8, 29, 8), // 17:00 JST on the 29th
        endAt: DateTime.utc(2026, 8, 29, 10),
        timezone: 'Asia/Tokyo',
        countryCode: 'NL',
        eventType: EventType.festival,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final result = eventsMatchingTrip([later, earlier], trip);
      expect(result.map((e) => e.id).toList(), ['earlier', 'later']);
    });
  });
}
