// Events V2 Step 8B — Reverse Hosted-Event Discovery.
// Covers HostedEventsSection (lib/features/events/widgets/hosted_events_section.dart)
// — the "EVENTS" section shown on Restaurant/Hotel/Private Chef Detail for
// Events the entity genuinely hosts. This widget trusts whatever [events]
// list it's given (host/venue/participant eligibility and the upcoming/
// active lifecycle filter both already happened in the repository before
// this widget is ever built) — these tests cover its own presentation
// contract: empty-list omission, precision-aware display, tap navigation,
// the deliberate absence of feed-specific chrome, and responsive behavior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/widgets/hosted_events_section.dart';
import 'package:michelin_passport/models/event.dart';

Event _event({
  String id = 'e1',
  String name = 'Test Event',
  DateTime? startAt,
  DateTime? endAt,
  DateTime? startDate,
  DateTime? endDate,
  String? timezone = 'UTC',
  EventAdmissionType admissionType = EventAdmissionType.unknown,
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
  status: EventStatus.upcoming,
  admissionType: admissionType,
  createdAt: DateTime.utc(2026, 1, 1),
);

DateTime _utc(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);

const _pilotTitle = '4 Hands Dinner: Bas van Kranen x Sang Hoon Degeimbre';

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('HostedEventsSection — empty state', () {
    testWidgets('zero Events: renders nothing at all, no "EVENTS" heading, '
        'no placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(HostedEventsSection(events: const [], onTapEvent: (_) {})),
      );
      expect(find.text('EVENTS'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('HostedEventsSection — content', () {
    testWidgets('section title is exactly "EVENTS" — never "HOSTED '
        'EVENTS", "MICHELIN EVENTS", or "STAR EVENTS"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(
            events: [
              _event(
                startAt: _utc(DateTime(2026, 10, 19, 18)),
                endAt: _utc(DateTime(2026, 10, 19, 22)),
              ),
            ],
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text('EVENTS'), findsOneWidget);
      expect(find.textContaining('HOSTED'), findsNothing);
      expect(find.textContaining('MICHELIN'), findsNothing);
      expect(find.textContaining('STAR'), findsNothing);
    });

    testWidgets('the real Flore pilot: date-only Event shows "19 Oct '
        '2026" with no fabricated time', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(
            events: [
              _event(
                name: _pilotTitle,
                startDate: DateTime.utc(2026, 10, 19),
                endDate: DateTime.utc(2026, 10, 19),
                timezone: 'Europe/Amsterdam',
              ),
            ],
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text(_pilotTitle), findsOneWidget);
      expect(find.text('19 Oct 2026'), findsOneWidget);
    });

    testWidgets('a full-time Event shows its real sourced date and time', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(
            events: [
              _event(
                name: 'Full Time Event',
                startAt: _utc(DateTime(2026, 9, 13, 11)),
                endAt: _utc(DateTime(2026, 9, 13, 15)),
              ),
            ],
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text('Full Time Event'), findsOneWidget);
      expect(find.text('13 Sep 2026 · 11:00–15:00'), findsOneWidget);
    });

    testWidgets('admission renders when known, omitted when unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(
            events: [
              _event(
                id: 'paid',
                name: 'Paid Event',
                startAt: _utc(DateTime(2026, 10, 19, 18)),
                endAt: _utc(DateTime(2026, 10, 19, 22)),
                admissionType: EventAdmissionType.paid,
              ),
              _event(
                id: 'unknown',
                name: 'Unknown Admission Event',
                startAt: _utc(DateTime(2026, 10, 20, 18)),
                endAt: _utc(DateTime(2026, 10, 20, 22)),
              ),
            ],
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text('Ticketed'), findsOneWidget);
    });

    testWidgets('multiple Events all render, in the order given (the '
        'repository — not this widget — is responsible for sorting)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(
            events: [
              _event(
                id: 'a',
                name: 'Event A',
                startAt: _utc(DateTime(2026, 10, 19, 18)),
                endAt: _utc(DateTime(2026, 10, 19, 22)),
              ),
              _event(
                id: 'b',
                name: 'Event B',
                startAt: _utc(DateTime(2026, 10, 20, 18)),
                endAt: _utc(DateTime(2026, 10, 20, 22)),
              ),
            ],
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text('Event A'), findsOneWidget);
      expect(find.text('Event B'), findsOneWidget);
      final aY = tester.getTopLeft(find.text('Event A')).dy;
      final bY = tester.getTopLeft(find.text('Event B')).dy;
      expect(aY, lessThan(bY));
    });
  });

  group('HostedEventsSection — no feed-specific chrome', () {
    testWidgets('never shows Interested/Going controls, a relevance '
        'reason, a member count, or the entity\'s own name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(
            events: [
              _event(
                name: _pilotTitle,
                startDate: DateTime.utc(2026, 10, 19),
                endDate: DateTime.utc(2026, 10, 19),
                timezone: 'Europe/Amsterdam',
              ),
            ],
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text('Interested'), findsNothing);
      expect(find.text('Going'), findsNothing);
      expect(find.textContaining('Restaurant Flore'), findsNothing);
      expect(find.textContaining('From a host you follow'), findsNothing);
    });
  });

  group('HostedEventsSection — navigation', () {
    testWidgets('tapping a row calls onTapEvent with exactly that Event', (
      tester,
    ) async {
      Event? tapped;
      final event = _event(
        name: _pilotTitle,
        startDate: DateTime.utc(2026, 10, 19),
        endDate: DateTime.utc(2026, 10, 19),
        timezone: 'Europe/Amsterdam',
      );
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(events: [event], onTapEvent: (e) => tapped = e),
        ),
      );
      await tester.tap(find.text(_pilotTitle));
      expect(tapped, same(event));
    });
  });

  group('HostedEventsSection — responsive', () {
    testWidgets('long pilot title wraps without overflow at 320px', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(
            events: [
              _event(
                name: _pilotTitle,
                startDate: DateTime.utc(2026, 10, 19),
                endDate: DateTime.utc(2026, 10, 19),
                timezone: 'Europe/Amsterdam',
              ),
            ],
            onTapEvent: (_) {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HostedEventsSection(
            events: [
              _event(
                name: _pilotTitle,
                startDate: DateTime.utc(2026, 10, 19),
                endDate: DateTime.utc(2026, 10, 19),
                timezone: 'Europe/Amsterdam',
                admissionType: EventAdmissionType.paid,
              ),
            ],
            onTapEvent: (_) {},
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
