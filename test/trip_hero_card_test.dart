// TRIPS HERO REDESIGN: covers TripHeroCard (the single featured upcoming
// trip) and MoreTripsLink. Purely presentational — pumped directly, no
// Supabase involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/trips/widgets/trip_hero_card.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/planned_trip.dart';

PlannedTrip _trip({
  String title = 'Maastricht',
  DateTime? startDate,
  DateTime? endDate,
  String? city,
}) => PlannedTrip(
  id: 't1',
  userId: 'u1',
  title: title,
  startDate: startDate ?? DateTime(2026, 8, 26),
  endDate: endDate ?? DateTime(2026, 8, 31),
  countryCode: 'NL',
  city: city,
  createdAt: DateTime(2026, 1, 1),
);

Event _event({
  String name = "'t Preuvenemint",
  DateTime? startDate,
  DateTime? endDate,
}) => Event(
  id: 'evt-1',
  name: name,
  // Calendar dates supplied directly — bypasses startAt/endAt derivation
  // entirely (and its midnight-boundary/local-zone-conversion rules,
  // both real pitfalls for a plain local DateTime in a test), matching
  // exactly what formatEventDateRange/_shortEventDateRange render.
  startDate: startDate ?? DateTime.utc(2026, 8, 27),
  endDate: endDate ?? DateTime.utc(2026, 8, 31),
  countryCode: 'NL',
  eventType: EventType.festival,
  status: EventStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  final now = DateTime(2026, 8, 24);

  group('TripHeroCard', () {
    testWidgets('renders destination, date range, and venue counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(),
            restaurantCount: 1,
            hotelCount: 1,
            onTap: () {},
            now: now,
          ),
        ),
      );
      expect(find.text('Maastricht'), findsOneWidget);
      expect(find.text('26–31 August 2026'), findsOneWidget);
      expect(find.text('1 restaurant · 1 hotel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a dynamic "In N days" label computed from the '
        'trip start date', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(startDate: DateTime(2026, 9, 10)),
            restaurantCount: 0,
            hotelCount: 0,
            onTap: () {},
            now: now,
          ),
        ),
      );
      expect(find.text('In 17 days'), findsOneWidget);
    });

    testWidgets('omits the start label entirely for a trip already under '
        'way — never a bright badge, never a negative count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(
              startDate: DateTime(2026, 8, 20),
              endDate: DateTime(2026, 8, 28),
            ),
            restaurantCount: 0,
            hotelCount: 0,
            onTap: () {},
            now: now,
          ),
        ),
      );
      expect(find.textContaining('Starts'), findsNothing);
      expect(find.textContaining('In '), findsNothing);
    });

    testWidgets('tapping the card fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(),
            restaurantCount: 1,
            hotelCount: 1,
            onTap: () => tapped = true,
            now: now,
          ),
        ),
      );
      await tester.tap(find.byType(TripHeroCard));
      expect(tapped, isTrue);
    });

    testWidgets('shows the matching event, subtly, when one overlaps', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(),
            restaurantCount: 1,
            hotelCount: 1,
            matchingEvent: _event(),
            onTap: () {},
            now: now,
          ),
        ),
      );
      expect(find.textContaining("'t Preuvenemint"), findsOneWidget);
      expect(find.textContaining('27–31 Aug'), findsOneWidget);
      // Not the event's own year — the card's own date range above it
      // already carries that.
      expect(find.textContaining('2026'), findsOneWidget); // trip date only
    });

    testWidgets('omits the event line entirely when there is no match — '
        'no empty-state placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(),
            restaurantCount: 1,
            hotelCount: 1,
            matchingEvent: null,
            onTap: () {},
            now: now,
          ),
        ),
      );
      // Only the venue-counts line uses "·" — no second line from an
      // event, and no placeholder text for the absence of one.
      expect(find.textContaining('·'), findsOneWidget);
      expect(find.textContaining('Preuvenemint'), findsNothing);
      expect(find.textContaining('No event'), findsNothing);
    });

    testWidgets('tapping the event name fires onTapEvent, not the card\'s '
        'own onTap', (tester) async {
      var cardTapped = false;
      var eventTapped = false;
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(),
            restaurantCount: 1,
            hotelCount: 1,
            matchingEvent: _event(),
            onTap: () => cardTapped = true,
            onTapEvent: () => eventTapped = true,
            now: now,
          ),
        ),
      );
      await tester.tap(find.textContaining("'t Preuvenemint"));
      expect(eventTapped, isTrue);
      expect(cardTapped, isFalse);
    });

    testWidgets('Ivory Hero Refinement: the card surface is ivory, the '
        'destination title is deep green — the one deliberate light '
        'object on the deep-green Trips page', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(),
            restaurantCount: 1,
            hotelCount: 1,
            onTap: () {},
            now: now,
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(TripHeroCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.ivory);
      expect(decoration.color, isNot(AppColors.brandGreenLight));

      final title = tester.widget<Text>(find.text('Maastricht'));
      expect(title.style?.color, AppColors.deepGreen);
      expect(title.style?.color, isNot(AppColors.textOnDark));
    });

    testWidgets('never renders gold', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripHeroCard(
            trip: _trip(startDate: DateTime(2026, 8, 25)),
            restaurantCount: 1,
            hotelCount: 1,
            matchingEvent: _event(),
            onTap: () {},
            now: now,
          ),
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('no overflow at ${width.toInt()}px — long destination '
          'name, matching event', (tester) async {
        await tester.pumpWidget(
          _wrap(
            TripHeroCard(
              trip: _trip(
                title: 'An Exceptionally Long Trip Destination Name',
                startDate: DateTime(2026, 8, 25),
              ),
              restaurantCount: 4,
              hotelCount: 2,
              matchingEvent: _event(
                name: 'A Fairly Long Culinary Festival Name',
              ),
              onTap: () {},
              now: now,
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow at 1.6x text scale, 320px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 320,
                child: TripHeroCard(
                  trip: _trip(startDate: DateTime(2026, 8, 25)),
                  restaurantCount: 1,
                  hotelCount: 1,
                  matchingEvent: _event(),
                  onTap: () {},
                  now: now,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('MoreTripsLink', () {
    testWidgets('renders the dynamic count, singular and plural', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(MoreTripsLink(count: 1, onTap: () {})));
      expect(find.text('1 more trip'), findsOneWidget);

      await tester.pumpWidget(_wrap(MoreTripsLink(count: 2, onTap: () {})));
      expect(find.text('2 more trips'), findsOneWidget);
    });

    testWidgets('tapping fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(MoreTripsLink(count: 3, onTap: () => tapped = true)),
      );
      await tester.tap(find.text('3 more trips'));
      expect(tapped, isTrue);
    });

    testWidgets('never gold', (tester) async {
      await tester.pumpWidget(_wrap(MoreTripsLink(count: 2, onTap: () {})));
      final text = tester.widget<Text>(find.text('2 more trips'));
      expect(text.style?.color, isNot(AppColors.gold));
    });
  });
}
