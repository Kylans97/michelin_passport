// Covers FriendGoingTile (Social Foundation Step 2B §13-14 — the Friend
// Profile GOING tile). Pure presentation, no Supabase dependency.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/friends/widgets/friend_going_tile.dart';
import 'package:michelin_passport/models/event.dart';

Event _event({
  String id = 'evt-1',
  String name = 'Test Festival',
  String? venueName,
  String? city = 'Maastricht',
  DateTime? startAt,
  DateTime? endAt,
}) => Event(
  id: id,
  name: name,
  venueName: venueName,
  city: city,
  startAt: startAt ?? DateTime(2026, 8, 28),
  endAt: endAt ?? DateTime(2026, 8, 30),
  countryCode: 'NL',
  eventType: EventType.festival,
  status: EventStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('FriendGoingTile', () {
    testWidgets('renders event name and date range · location', (tester) async {
      await tester.pumpWidget(
        _wrap(FriendGoingTile(event: _event(), onTap: () {})),
      );
      expect(find.text('Test Festival'), findsOneWidget);
      expect(find.textContaining('Maastricht'), findsOneWidget);
      expect(find.textContaining('28'), findsOneWidget);
    });

    testWidgets('tapping fires onTap (navigates to canonical EventDetail)', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(FriendGoingTile(event: _event(), onTap: () => tapped = true)),
      );
      await tester.tap(find.byType(FriendGoingTile));
      expect(tapped, isTrue);
    });

    testWidgets('shows a chevron affordance', (tester) async {
      await tester.pumpWidget(
        _wrap(FriendGoingTile(event: _event(), onTap: () {})),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('works without a city (location omitted cleanly)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(FriendGoingTile(event: _event(city: null), onTap: () {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('long event name + long city — no overflow, 320px', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendGoingTile(
            event: _event(
              name:
                  'An Extraordinarily Long and Elaborate Festival Name '
                  'For Testing Purposes',
              city: 'A Very Long City Name Indeed For Overflow Testing',
            ),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: FriendGoingTile(event: _event(), onTap: () {}),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
