// Covers the redesigned PassportRestaurantCard/PassportHotelCard — the
// visual pieces PassportScreen itself can't be widget-tested for (see
// passport_view_model_test.dart's own note: PassportScreen constructs
// VisitedRepository(Supabase.instance.client) unconditionally, so pumping
// the full screen needs a live Supabase session this sandbox doesn't
// have). These tests pump the cards directly with real PassportVenueStats
// fixtures — no Supabase involved — at narrow widths and with long
// restaurant/hotel/city/country names, mirroring the RestaurantTile/
// HotelTile overflow-regression tests this must not repeat.
//
// Navigation is verified structurally (an InkWell/tap affordance exists)
// rather than by actually tapping through: RestaurantDetailScreen/
// HotelDetailScreen construct several repositories against
// Supabase.instance.client in their own initState, which throws
// immediately with no Supabase session initialized — the same
// UI-navigation limitation events_test.dart documents for its own "J:
// linked venue navigation" case.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/passport_view_model.dart';
import 'package:michelin_passport/features/passport/widgets/passport_hotel_card.dart';
import 'package:michelin_passport/features/passport/widgets/passport_restaurant_card.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

Restaurant _restaurant({
  String name = 'Test Restaurant',
  int? michelinStars,
  String cityName = 'Paris',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
}) => Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  cityName: cityName,
  countryCode: 'FR',
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
);

Hotel _hotel({
  String name = 'Test Hotel',
  int? michelinKeys,
  String cityName = 'Paris',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
}) => Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: name,
  michelinKeys: michelinKeys,
  cityName: cityName,
  countryCode: 'FR',
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Visit _visit({
  String id = 'v1',
  String entityType = 'restaurant',
  String entityId = 'r1',
  required DateTime visitedOn,
  int? rating,
  int? starsAtVisit,
  int? keysAtVisit,
}) => Visit(
  id: id,
  userId: 'u1',
  entityType: entityType,
  entityId: entityId,
  visitedOn: visitedOn,
  rating: rating,
  starsAtVisit: starsAtVisit,
  keysAtVisit: keysAtVisit,
);

Widget _wrap(Widget child, {double width = 320}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  group('PassportRestaurantCard', () {
    testWidgets('renders name, location, and visit info with no overflow', (
      tester,
    ) async {
      final stats = PassportVenueStats.from(
        RestaurantVenue(_restaurant(michelinStars: 2)),
        [_visit(visitedOn: DateTime(2026, 6, 12), rating: 9, starsAtVisit: 2)],
      );
      await tester.pumpWidget(
        _wrap(
          PassportRestaurantCard(
            restaurant: _restaurant(michelinStars: 2),
            stats: stats,
          ),
        ),
      );
      expect(find.text('Test Restaurant'), findsOneWidget);
      expect(find.textContaining('Paris'), findsOneWidget);
      expect(find.textContaining('9.0 average'), findsOneWidget);
      expect(find.textContaining('1 visit'), findsOneWidget);
      expect(find.textContaining('12 Jun 2026'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no longer shows a "RESTAURANT" type eyebrow', (tester) async {
      final stats = PassportVenueStats.from(
        RestaurantVenue(_restaurant(michelinStars: 2)),
        [_visit(visitedOn: DateTime(2026, 6, 12), starsAtVisit: 2)],
      );
      await tester.pumpWidget(
        _wrap(
          PassportRestaurantCard(
            restaurant: _restaurant(michelinStars: 2),
            stats: stats,
          ),
        ),
      );
      expect(find.text('RESTAURANT'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows an InkWell tap affordance (navigation entry point)', (
      tester,
    ) async {
      final stats = PassportVenueStats.from(RestaurantVenue(_restaurant()), [
        _visit(visitedOn: DateTime(2026, 1, 1)),
      ]);
      await tester.pumpWidget(
        _wrap(PassportRestaurantCard(restaurant: _restaurant(), stats: stats)),
      );
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('renders with no Michelin star and no average rating', (
      tester,
    ) async {
      final stats = PassportVenueStats.from(RestaurantVenue(_restaurant()), [
        _visit(visitedOn: DateTime(2026, 1, 1)),
      ]);
      await tester.pumpWidget(
        _wrap(PassportRestaurantCard(restaurant: _restaurant(), stats: stats)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('3 Michelin stars, multiple visits, long name/city/country '
        'at a narrow width — no RenderFlex overflow', (tester) async {
      final restaurant = _restaurant(
        name: 'The Extraordinarily Long Restaurant Name Establishment',
        michelinStars: 3,
        cityName: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
        countryName: 'United Kingdom of Great Britain and Northern Ireland',
        flagEmoji: '🇬🇧',
      );
      final stats = PassportVenueStats.from(RestaurantVenue(restaurant), [
        _visit(
          id: 'v1',
          visitedOn: DateTime(2026, 1, 1),
          rating: 10,
          starsAtVisit: 3,
        ),
        _visit(
          id: 'v2',
          visitedOn: DateTime(2026, 5, 20),
          rating: 9,
          starsAtVisit: 3,
        ),
        _visit(
          id: 'v3',
          visitedOn: DateTime(2026, 8, 3),
          rating: 10,
          starsAtVisit: 3,
        ),
      ]);
      await tester.pumpWidget(
        _wrap(
          PassportRestaurantCard(restaurant: restaurant, stats: stats),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('3 visits'), findsOneWidget);
    });

    testWidgets('renders correctly at a narrow iPhone width (320) and a '
        'normal modern width (390)', (tester) async {
      for (final width in [320.0, 390.0]) {
        final stats = PassportVenueStats.from(
          RestaurantVenue(_restaurant(michelinStars: 1)),
          [_visit(visitedOn: DateTime(2026, 1, 1), starsAtVisit: 1)],
        );
        await tester.pumpWidget(
          _wrap(
            PassportRestaurantCard(
              restaurant: _restaurant(michelinStars: 1),
              stats: stats,
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders correctly with increased text scale', (tester) async {
      final stats = PassportVenueStats.from(
        RestaurantVenue(_restaurant(michelinStars: 2)),
        [_visit(visitedOn: DateTime(2026, 1, 1), rating: 8, starsAtVisit: 2)],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: PassportRestaurantCard(
                  restaurant: _restaurant(michelinStars: 2),
                  stats: stats,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PassportHotelCard', () {
    testWidgets('renders name, location, and stay info with no overflow', (
      tester,
    ) async {
      final stats =
          PassportVenueStats.from(HotelVenue(_hotel(michelinKeys: 3)), [
            _visit(
              entityType: 'hotel',
              entityId: 'h1',
              visitedOn: DateTime(2026, 6, 12),
              rating: 10,
              keysAtVisit: 3,
            ),
          ]);
      await tester.pumpWidget(
        _wrap(PassportHotelCard(hotel: _hotel(michelinKeys: 3), stats: stats)),
      );
      expect(find.text('Test Hotel'), findsOneWidget);
      expect(find.textContaining('10.0'), findsOneWidget);
      expect(find.textContaining('1 stay'), findsOneWidget);
      expect(find.textContaining('Last stay'), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_rounded), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no longer shows a "HOTEL" type eyebrow', (tester) async {
      final stats =
          PassportVenueStats.from(HotelVenue(_hotel(michelinKeys: 3)), [
            _visit(
              entityType: 'hotel',
              entityId: 'h1',
              visitedOn: DateTime(2026, 6, 12),
              keysAtVisit: 3,
            ),
          ]);
      await tester.pumpWidget(
        _wrap(PassportHotelCard(hotel: _hotel(michelinKeys: 3), stats: stats)),
      );
      expect(find.text('HOTEL'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with no Keys and no average rating', (tester) async {
      final stats = PassportVenueStats.from(HotelVenue(_hotel()), [
        _visit(
          entityType: 'hotel',
          entityId: 'h1',
          visitedOn: DateTime(2026, 1, 1),
        ),
      ]);
      await tester.pumpWidget(
        _wrap(PassportHotelCard(hotel: _hotel(), stats: stats)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('3 Keys, multiple stays, long name/city/country at a '
        'narrow width — no RenderFlex overflow', (tester) async {
      final hotel = _hotel(
        name: 'The Extraordinarily Long Grand Hotel Establishment',
        michelinKeys: 3,
        cityName: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
        countryName: 'United Kingdom of Great Britain and Northern Ireland',
        flagEmoji: '🇬🇧',
      );
      final stats = PassportVenueStats.from(HotelVenue(hotel), [
        _visit(
          id: 'v1',
          entityType: 'hotel',
          entityId: 'h1',
          visitedOn: DateTime(2026, 1, 1),
          rating: 10,
          keysAtVisit: 3,
        ),
        _visit(
          id: 'v2',
          entityType: 'hotel',
          entityId: 'h1',
          visitedOn: DateTime(2026, 6, 1),
          rating: 9,
          keysAtVisit: 3,
        ),
      ]);
      await tester.pumpWidget(
        _wrap(PassportHotelCard(hotel: hotel, stats: stats), width: 320),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('2 stays'), findsOneWidget);
    });

    testWidgets('renders correctly with increased text scale', (tester) async {
      final stats =
          PassportVenueStats.from(HotelVenue(_hotel(michelinKeys: 2)), [
            _visit(
              entityType: 'hotel',
              entityId: 'h1',
              visitedOn: DateTime(2026, 1, 1),
              rating: 8,
              keysAtVisit: 2,
            ),
          ]);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: PassportHotelCard(
                  hotel: _hotel(michelinKeys: 2),
                  stats: stats,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
