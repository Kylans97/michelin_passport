// Covers the Trips redesign's presentation layer (TRIPS REDESIGN STEP 1).
// PlannedTripsScreen/TripDetailScreen/CreateTripSheet all construct
// repositories against Supabase.instance.client eagerly in initState (the
// same established limitation as every other guide/Explore/Wishlist screen
// in this app — see explore_guides_entry_test.dart's own note), so they
// can't be widget-pumped directly without a live session. TripCard,
// PlannedVenueRow and TripSectionLabel are genuinely standalone, public
// widgets, though — those are pumped directly, at full fidelity, rather
// than reconstructed. eventMatchesTrip/eventsMatchingTrip (the WHAT'S ON
// section's matching logic, left untouched by this task) already has its
// own coverage in events_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/trips/widgets/planned_venue_row.dart';
import 'package:michelin_passport/features/trips/widgets/trip_card.dart';
import 'package:michelin_passport/features/trips/widgets/trip_eyebrow.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:michelin_passport/models/planned_venue.dart';
import 'package:michelin_passport/models/resolved_planned_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({
  String name = 'Test Restaurant',
  int? michelinStars,
  String cityName = 'Paris',
}) => Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  cityName: cityName,
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  isInHotel: false,
  hotelName: null,
  worlds50BestRank: null,
);

Hotel _hotel({String name = 'Test Hotel', int? michelinKeys}) => Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: name,
  michelinKeys: michelinKeys,
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
  worlds50BestRank: null,
);

PlannedTrip _trip({
  String title = 'Paris',
  DateTime? start,
  DateTime? end,
  String? city,
}) => PlannedTrip(
  id: 't1',
  userId: 'u1',
  title: title,
  startDate: start ?? DateTime(2026, 10, 16),
  endDate: end ?? DateTime(2026, 10, 19),
  countryCode: 'FR',
  city: city,
  createdAt: DateTime(2026, 1, 1),
);

ResolvedPlannedVenue _plannedRestaurant({
  String name = 'Test Restaurant',
  int? michelinStars,
  PlannedVenueStatus status = PlannedVenueStatus.planned,
  DateTime? start,
}) => ResolvedPlannedVenue(
  plan: PlannedVenue(
    id: 'pv1',
    userId: 'u1',
    entityType: 'restaurant',
    entityId: 'r1',
    startDate: start ?? DateTime(2026, 10, 17),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  ),
  venue: RestaurantVenue(_restaurant(name: name, michelinStars: michelinStars)),
);

ResolvedPlannedVenue _plannedHotel({int? michelinKeys}) => ResolvedPlannedVenue(
  plan: PlannedVenue(
    id: 'pv2',
    userId: 'u1',
    entityType: 'hotel',
    entityId: 'h1',
    startDate: DateTime(2026, 10, 16),
    endDate: DateTime(2026, 10, 19),
    status: PlannedVenueStatus.planned,
    createdAt: DateTime(2026, 1, 1),
  ),
  venue: HotelVenue(_hotel(michelinKeys: michelinKeys)),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: Colors.black, body: child),
);

void main() {
  group('formatTripDateRange', () {
    test('same month/year', () {
      expect(
        formatTripDateRange(
          _trip(start: DateTime(2026, 10, 16), end: DateTime(2026, 10, 19)),
        ),
        '16–19 October 2026',
      );
    });

    test('same year, different month', () {
      expect(
        formatTripDateRange(
          _trip(start: DateTime(2026, 10, 28), end: DateTime(2026, 11, 2)),
        ),
        '28 October – 2 November 2026',
      );
    });

    test('different year', () {
      expect(
        formatTripDateRange(
          _trip(start: DateTime(2026, 12, 30), end: DateTime(2027, 1, 3)),
        ),
        '30 December 2026 – 3 January 2027',
      );
    });
  });

  group('TripCard', () {
    testWidgets('renders title, date range and venue counts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripCard(
            trip: _trip(),
            restaurantCount: 2,
            hotelCount: 1,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('16–19 October 2026'), findsOneWidget);
      expect(find.text('2 restaurants · 1 hotel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to "No venues planned yet" with zero counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TripCard(
            trip: _trip(),
            restaurantCount: 0,
            hotelCount: 0,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('No venues planned yet'), findsOneWidget);
    });

    testWidgets('singular counts have no trailing s', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripCard(
            trip: _trip(),
            restaurantCount: 1,
            hotelCount: 1,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('1 restaurant · 1 hotel'), findsOneWidget);
    });

    testWidgets('TRIPS HERO REDESIGN: the venue-counts line is never gold '
        '— no gold anywhere on the visual-direction-audited Trips surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TripCard(
            trip: _trip(),
            restaurantCount: 1,
            hotelCount: 1,
            onTap: () {},
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('1 restaurant · 1 hotel'));
      expect(text.style?.color, isNot(AppColors.gold));
    });

    testWidgets('tap fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          TripCard(
            trip: _trip(),
            restaurantCount: 0,
            hotelCount: 0,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(TripCard));
      expect(tapped, isTrue);
    });

    testWidgets('320px and 390px widths — no overflow with a long title', (
      tester,
    ) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          _wrap(
            TripCard(
              trip: _trip(
                title:
                    'A very long trip name that goes on and on across Southeast Asia',
              ),
              restaurantCount: 5,
              hotelCount: 3,
              onTap: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: TripCard(
                trip: _trip(title: 'Kyoto & Osaka, End of Year'),
                restaurantCount: 3,
                hotelCount: 1,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PlannedVenueRow', () {
    testWidgets('renders venue name, location and plan date', (tester) async {
      await tester.pumpWidget(
        _wrap(PlannedVenueRow(item: _plannedRestaurant(), onTap: () {})),
      );
      expect(find.textContaining('Test Restaurant · Paris'), findsOneWidget);
      expect(find.textContaining('17 Oct 2026'), findsOneWidget);
    });

    testWidgets('shows a Michelin star row for a starred restaurant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlannedVenueRow(
            item: _plannedRestaurant(michelinStars: 2),
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    });

    testWidgets('shows a Michelin Key row for a Keyed hotel', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlannedVenueRow(item: _plannedHotel(michelinKeys: 1), onTap: () {}),
        ),
      );
      expect(find.byIcon(Icons.vpn_key_rounded), findsOneWidget);
    });

    testWidgets('no distinction icons for an unstarred restaurant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(PlannedVenueRow(item: _plannedRestaurant(), onTap: () {})),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.vpn_key_rounded), findsNothing);
    });

    testWidgets('cancelled status shows a strikethrough label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlannedVenueRow(
            item: _plannedRestaurant(status: PlannedVenueStatus.cancelled),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Cancelled'), findsOneWidget);
      final text = tester.widget<Text>(
        find.textContaining('Test Restaurant · Paris'),
      );
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('completed status shows a label, no strikethrough', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlannedVenueRow(
            item: _plannedRestaurant(status: PlannedVenueStatus.completed),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Completed'), findsOneWidget);
      final text = tester.widget<Text>(
        find.textContaining('Test Restaurant · Paris'),
      );
      expect(text.style?.decoration, isNot(TextDecoration.lineThrough));
    });

    testWidgets('tap and long-press fire their callbacks', (tester) async {
      var tapped = false;
      var longPressed = false;
      await tester.pumpWidget(
        _wrap(
          PlannedVenueRow(
            item: _plannedRestaurant(),
            onTap: () => tapped = true,
            onLongPress: () => longPressed = true,
          ),
        ),
      );
      await tester.tap(find.byType(PlannedVenueRow));
      expect(tapped, isTrue);
      await tester.longPress(find.byType(PlannedVenueRow));
      expect(longPressed, isTrue);
    });

    testWidgets('320px width, long venue name — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(
          PlannedVenueRow(
            item: _plannedRestaurant(
              name:
                  'The Extraordinarily Long Named Restaurant of Southern France',
              michelinStars: 3,
            ),
            onTap: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: PlannedVenueRow(
                item: _plannedHotel(michelinKeys: 3),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('TripSectionLabel', () {
    testWidgets('renders the given text', (tester) async {
      await tester.pumpWidget(_wrap(const TripSectionLabel('STAY')));
      expect(find.text('STAY'), findsOneWidget);
    });
  });
}
