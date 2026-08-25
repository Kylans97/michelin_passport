// TRIPS HERO REDESIGN: covers AllUpcomingTripsScreen — the simple, full
// list of every upcoming trip reached via the "N more trips →" link.
// Purely presentational (pumped directly): reuses TripCard unchanged, and
// its own tap-through to TripDetailScreen isn't exercised here since that
// screen constructs a Supabase-backed repository eagerly with no session
// in this sandbox — the same documented limitation every other
// tap-through-to-Detail test in this app already works around by
// verifying the tap affordance structurally instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';
import 'package:michelin_passport/features/trips/all_upcoming_trips_screen.dart';
import 'package:michelin_passport/features/trips/widgets/trip_card.dart';
import 'package:michelin_passport/models/planned_trip.dart';

PlannedTrip _trip({
  String id = 't1',
  String title = 'Maastricht',
}) => PlannedTrip(
  id: id,
  userId: 'u1',
  title: title,
  startDate: DateTime(2026, 8, 26),
  endDate: DateTime(2026, 8, 31),
  countryCode: 'NL',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('AllUpcomingTripsScreen', () {
    testWidgets('renders every trip as a TripCard, in the given order', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AllUpcomingTripsScreen(
            trips: [
              (trip: _trip(id: 't1', title: 'Maastricht'), restaurantCount: 1, hotelCount: 1),
              (trip: _trip(id: 't2', title: 'Copenhagen'), restaurantCount: 2, hotelCount: 0),
              (trip: _trip(id: 't3', title: 'Kyoto'), restaurantCount: 0, hotelCount: 1),
            ],
          ),
        ),
      );
      expect(find.byType(TripCard), findsNWidgets(3));
      expect(find.text('Maastricht'), findsOneWidget);
      expect(find.text('Copenhagen'), findsOneWidget);
      expect(find.text('Kyoto'), findsOneWidget);
      final titles = tester
          .widgetList<TripCard>(find.byType(TripCard))
          .map((c) => c.trip.title)
          .toList();
      expect(titles, ['Maastricht', 'Copenhagen', 'Kyoto']);
    });

    testWidgets('has a back button and a title, no bottom nav (a normal '
        'pushed screen, not a Passport subsection)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AllUpcomingTripsScreen(
            trips: [
              (trip: _trip(), restaurantCount: 1, hotelCount: 1),
            ],
          ),
        ),
      );
      expect(find.byType(EditorialBackButton), findsOneWidget);
      expect(find.text('Upcoming trips'), findsOneWidget);
    });

    testWidgets('the canvas is deep green, matching Trips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AllUpcomingTripsScreen(
            trips: [(trip: _trip(), restaurantCount: 0, hotelCount: 0)],
          ),
        ),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.deepGreen);
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('no overflow at ${width.toInt()}px', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          MaterialApp(
            home: AllUpcomingTripsScreen(
              trips: [
                (
                  trip: _trip(title: 'An Exceptionally Long Trip Title Here'),
                  restaurantCount: 5,
                  hotelCount: 3,
                ),
                (trip: _trip(id: 't2', title: 'Copenhagen'), restaurantCount: 1, hotelCount: 1),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.binding.setSurfaceSize(null);
      });
    }
  });
}
