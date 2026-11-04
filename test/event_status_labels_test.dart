// Sold out (events.availability_status) and Expected
// (events.announcement_status, 20261101320000): parsing, the labels each
// card shows, and the detail rows. Cancelled outranks both.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/community/widgets/community_events_preview.dart';
import 'package:michelin_passport/features/events/widgets/event_card.dart';
import 'package:michelin_passport/features/events/widgets/event_meta_section.dart';
import 'package:michelin_passport/features/events/widgets/event_status_badges.dart';
import 'package:michelin_passport/features/explore/widgets/explore_event_result_tile.dart';
import 'package:michelin_passport/models/event.dart';

Map<String, dynamic> _json() => {
  'id': 'evt-1',
  'name': 'Four Hands Dinner',
  'start_at': null,
  'end_at': null,
  'start_date': '2026-11-25',
  'end_date': '2026-11-25',
  'timezone': 'Europe/Brussels',
  'country_code': 'BE',
  'city': 'Francorchamps',
  'event_type': 'dinner',
  'created_at': '2026-11-05T12:00:00+00:00',
};

Event _event({
  bool soldOut = false,
  bool expected = false,
  bool cancelled = false,
}) => Event(
  id: 'evt-1',
  name: 'Four Hands Dinner',
  startDate: DateTime.utc(2026, 11, 25),
  endDate: DateTime.utc(2026, 11, 25),
  timezone: 'Europe/Brussels',
  countryCode: 'BE',
  city: 'Francorchamps',
  eventType: EventType.dinner,
  cancelledAt: cancelled ? DateTime.utc(2026, 11, 1) : null,
  availability: soldOut ? EventAvailability.soldOut : EventAvailability.unknown,
  announcement: expected
      ? EventAnnouncement.expected
      : EventAnnouncement.official,
  expectedSourceUrl: expected ? 'https://example.com/press' : null,
  createdAt: DateTime.utc(2026, 11, 5),
);

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
  group('fromJson', () {
    test('columns absent (older schema or select) read as unknown/official', () {
      final e = Event.fromJson(_json());
      expect(e.availability, EventAvailability.unknown);
      expect(e.announcement, EventAnnouncement.official);
      expect(e.expectedSourceUrl, isNull);
      expect(e.isSoldOut, isFalse);
      expect(e.isExpected, isFalse);
    });

    test('sold_out and expected parse', () {
      final e = Event.fromJson(
        _json()
          ..['availability_status'] = 'sold_out'
          ..['announcement_status'] = 'expected'
          ..['expected_source_url'] = 'https://example.com/press',
      );
      expect(e.isSoldOut, isTrue);
      expect(e.isExpected, isTrue);
      expect(e.expectedSourceUrl, 'https://example.com/press');
    });

    test('available and an unknown value never read as sold out', () {
      expect(
        Event.fromJson(_json()..['availability_status'] = 'available').isSoldOut,
        isFalse,
      );
      expect(
        Event.fromJson(_json()..['availability_status'] = 'waitlist').availability,
        EventAvailability.unknown,
      );
      expect(
        Event.fromJson(_json()..['announcement_status'] = 'rumoured').isExpected,
        isFalse,
      );
    });
  });

  group('eventStatusLabels', () {
    test('none for an ordinary event', () {
      expect(eventStatusLabels(_event()), isEmpty);
    });
    test('sold out, then expected', () {
      expect(eventStatusLabels(_event(soldOut: true, expected: true)), [
        'SOLD OUT',
        'EXPECTED',
      ]);
    });
    test('cancelled outranks both', () {
      expect(
        eventStatusLabels(_event(soldOut: true, expected: true, cancelled: true)),
        isEmpty,
      );
    });
  });

  group('EventCard', () {
    testWidgets('shows SOLD OUT and EXPECTED', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(event: _event(soldOut: true, expected: true), onTap: () {}),
        ),
      );
      expect(find.text('SOLD OUT'), findsOneWidget);
      expect(find.text('EXPECTED'), findsOneWidget);
    });

    testWidgets('an ordinary event shows neither', (tester) async {
      await tester.pumpWidget(_wrap(EventCard(event: _event(), onTap: () {})));
      expect(find.text('SOLD OUT'), findsNothing);
      expect(find.text('EXPECTED'), findsNothing);
    });

    testWidgets('a cancelled event shows only CANCELLED', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(soldOut: true, expected: true, cancelled: true),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('SOLD OUT'), findsNothing);
      expect(find.text('EXPECTED'), findsNothing);
    });

    testWidgets('no overflow at narrow width and large text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(event: _event(soldOut: true, expected: true), onTap: () {}),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Explore result tile', () {
    testWidgets('shows both labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ExploreEventResultTile(
            event: _event(soldOut: true, expected: true),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('SOLD OUT'), findsOneWidget);
      expect(find.text('EXPECTED'), findsOneWidget);
    });
  });

  group('Community preview', () {
    testWidgets('one quiet line with both labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommunityEventsPreview(
            events: [_event(soldOut: true, expected: true)],
            goingCounts: const {},
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text('SOLD OUT · EXPECTED'), findsOneWidget);
    });
  });

  group('Event detail meta', () {
    testWidgets('sold out and expected rows', (tester) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(soldOut: true, expected: true))),
      );
      expect(find.text('Sold out'), findsOneWidget);
      expect(find.text('Expected'), findsOneWidget);
      expect(
        find.text('Not yet announced by the venue or organiser'),
        findsOneWidget,
      );
    });

    testWidgets('cancelled hides both rows', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(
            event: _event(soldOut: true, expected: true, cancelled: true),
          ),
        ),
      );
      expect(find.text('This event has been cancelled'), findsOneWidget);
      expect(find.text('Sold out'), findsNothing);
      expect(find.text('Expected'), findsNothing);
    });
  });
}
