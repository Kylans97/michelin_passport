// Events V2 Step 8A §31 — EventCard's extended [reason] slot: no reason
// (existing behavior untouched), exactly one reason rendered for each of
// the five relevance types, never more than one reason, existing metadata
// (name/date/location/badges) stays intact, no gold, no overflow at narrow
// width or large text scale.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/events/widgets/event_card.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_relevance_reason.dart';

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

Event _event({bool freeEntry = false, bool cancelled = false}) => Event(
  id: 'evt-1',
  name: "'t Preuvenemint",
  startAt: DateTime.utc(2026, 9, 20, 18),
  endAt: DateTime.utc(2026, 9, 20, 22),
  timezone: 'Europe/Amsterdam',
  countryCode: 'NL',
  city: 'Maastricht',
  eventType: EventType.festival,
  status: cancelled ? EventStatus.cancelled : EventStatus.upcoming,
  admissionType: freeEntry ? EventAdmissionType.free : EventAdmissionType.paid,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('EventCard — no reason (existing behavior)', () {
    testWidgets('renders name/date/location with no reason row', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(EventCard(event: _event(), onTap: () {})));
      expect(find.text("'t Preuvenemint"), findsOneWidget);
      expect(find.text('Maastricht, NL'), findsOneWidget);
      expect(find.byIcon(Icons.card_travel), findsNothing);
      expect(find.byIcon(Icons.people_alt_outlined), findsNothing);
      expect(find.byIcon(Icons.bookmark_outline), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.byIcon(Icons.trending_up), findsNothing);
    });

    testWidgets('free entry and cancelled badges still render unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EventCard(event: _event(freeEntry: true), onTap: () {})),
      );
      expect(find.text('FREE ENTRY'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(EventCard(event: _event(cancelled: true), onTap: () {})),
      );
      expect(find.text('CANCELLED'), findsOneWidget);
    });
  });

  group('EventCard — exactly one reason rendered per type', () {
    testWidgets('Trip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(),
            reason: const TripRelevanceReason(destinationLabel: 'Maastricht'),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('During your Maastricht trip'), findsOneWidget);
      expect(find.byIcon(Icons.card_travel), findsOneWidget);
    });

    testWidgets('Friend Going', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(),
            reason: const FriendGoingRelevanceReason(
              count: 1,
              singleFriendName: 'Ward',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Ward is going'), findsOneWidget);
      expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
    });

    testWidgets('Followed Host', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(),
            reason: const FollowedHostRelevanceReason(hostName: 'Parkheuvel'),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Hosted by Parkheuvel'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
    });

    testWidgets('Friend Interested', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(),
            reason: const FriendInterestedRelevanceReason(count: 2),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('2 friends are interested'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('Popularity', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(),
            reason: const PopularRelevanceReason(),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Popular with Chasing Stars members'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('never renders more than one reason icon at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(),
            reason: const TripRelevanceReason(destinationLabel: 'Maastricht'),
            onTap: () {},
          ),
        ),
      );
      final reasonIcons = [
        Icons.card_travel,
        Icons.people_alt_outlined,
        Icons.bookmark_outline,
        Icons.star_border,
        Icons.trending_up,
      ];
      final rendered = [
        for (final icon in reasonIcons) find.byIcon(icon).evaluate().length,
      ];
      expect(rendered.reduce((a, b) => a + b), 1);
    });
  });

  group('EventCard — visual contract', () {
    testWidgets('never renders gold anywhere on the card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(freeEntry: true),
            reason: const TripRelevanceReason(destinationLabel: 'Maastricht'),
            onTap: () {},
          ),
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width with a long reason — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(),
            reason: const FriendGoingRelevanceReason(
              count: 1,
              singleFriendName: 'A Very Long Friend Display Name Indeed',
            ),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale with free entry + a reason — no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventCard(
            event: _event(freeEntry: true),
            reason: const PopularRelevanceReason(),
            onTap: () {},
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
