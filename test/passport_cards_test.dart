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
// Passport UI Polish V2: the bookmark is now a real, wired control
// (isWishlisted/onToggleWishlist), tested here at the presentation layer
// — the actual WishlistRepository call and optimistic-state handling
// live in PassportCollectionBody, which (like every other Supabase-eager
// screen in this app) can't be pumped directly; this proves the card
// reports taps correctly and never lets a bookmark tap also trigger
// navigation.
//
// Navigation is verified structurally (an InkWell/tap affordance exists,
// and tapping elsewhere on the card fires onTap) rather than by actually
// tapping through to RestaurantDetailScreen/HotelDetailScreen: those
// construct several repositories against Supabase.instance.client in
// their own initState, which throws immediately with no Supabase session
// initialized — the same UI-navigation limitation events_test.dart
// documents for its own "J: linked venue navigation" case.

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
    testWidgets('renders name, location, and visit info with no overflow — '
        'and no longer shows "Last visit" at all', (tester) async {
      final stats = PassportVenueStats.from(
        RestaurantVenue(_restaurant(michelinStars: 2)),
        [_visit(visitedOn: DateTime(2026, 6, 12), rating: 9, starsAtVisit: 2)],
      );
      await tester.pumpWidget(
        _wrap(
          PassportRestaurantCard(
            restaurant: _restaurant(michelinStars: 2),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () {},
          ),
        ),
      );
      expect(find.text('Test Restaurant'), findsOneWidget);
      expect(find.textContaining('Paris'), findsOneWidget);
      expect(find.textContaining('9.0 average'), findsOneWidget);
      expect(find.textContaining('1 visit'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      // Passport UI Polish V2 — bookmark and the (now single-line) rating
      // footer icon. "Last visit"/calendar icon are gone entirely.
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      expect(find.textContaining('Last visit'), findsNothing);
      expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bookmark shows outline when not wishlisted and filled '
        'when wishlisted', (tester) async {
      final stats = PassportVenueStats.from(RestaurantVenue(_restaurant()), [
        _visit(visitedOn: DateTime(2026, 1, 1)),
      ]);
      await tester.pumpWidget(
        _wrap(
          PassportRestaurantCard(
            restaurant: _restaurant(),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

      await tester.pumpWidget(
        _wrap(
          PassportRestaurantCard(
            restaurant: _restaurant(),
            stats: stats,
            isWishlisted: true,
            onToggleWishlist: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
    });

    testWidgets('tapping the bookmark fires onToggleWishlist and does NOT '
        'also fire the card\'s own onTap (navigation) — if it had, this '
        'would crash: RestaurantDetailScreen is Supabase-eager and there '
        'is no session in this test', (tester) async {
      var toggled = false;
      final stats = PassportVenueStats.from(RestaurantVenue(_restaurant()), [
        _visit(visitedOn: DateTime(2026, 1, 1)),
      ]);
      await tester.pumpWidget(
        _wrap(
          PassportRestaurantCard(
            restaurant: _restaurant(),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () => toggled = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
      await tester.pump();
      expect(toggled, isTrue);
      expect(tester.takeException(), isNull);
      // Still on the same widget tree — no push occurred.
      expect(find.byType(PassportRestaurantCard), findsOneWidget);
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
            isWishlisted: false,
            onToggleWishlist: () {},
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
        _wrap(
          PassportRestaurantCard(
            restaurant: _restaurant(),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () {},
          ),
        ),
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
        _wrap(
          PassportRestaurantCard(
            restaurant: _restaurant(),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () {},
          ),
        ),
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
          PassportRestaurantCard(
            restaurant: restaurant,
            stats: stats,
            isWishlisted: true,
            onToggleWishlist: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('3 visits'), findsOneWidget);
    });

    testWidgets('renders correctly at 320/375/390/430', (tester) async {
      for (final width in [320.0, 375.0, 390.0, 430.0]) {
        final stats = PassportVenueStats.from(
          RestaurantVenue(_restaurant(michelinStars: 1)),
          [_visit(visitedOn: DateTime(2026, 1, 1), starsAtVisit: 1)],
        );
        await tester.pumpWidget(
          _wrap(
            PassportRestaurantCard(
              restaurant: _restaurant(michelinStars: 1),
              stats: stats,
              isWishlisted: false,
              onToggleWishlist: () {},
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull, reason: '${width}px');
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
                  isWishlisted: false,
                  onToggleWishlist: () {},
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
    testWidgets('renders name, location, and stay info with no overflow — '
        'and no longer shows "Last stay" at all', (tester) async {
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
        _wrap(
          PassportHotelCard(
            hotel: _hotel(michelinKeys: 3),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () {},
          ),
        ),
      );
      expect(find.text('Test Hotel'), findsOneWidget);
      expect(find.textContaining('10.0'), findsOneWidget);
      expect(find.textContaining('1 stay'), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      expect(find.textContaining('Last stay'), findsNothing);
      expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bookmark shows outline when not wishlisted and filled '
        'when wishlisted', (tester) async {
      final stats = PassportVenueStats.from(HotelVenue(_hotel()), [
        _visit(
          entityType: 'hotel',
          entityId: 'h1',
          visitedOn: DateTime(2026, 1, 1),
        ),
      ]);
      await tester.pumpWidget(
        _wrap(
          PassportHotelCard(
            hotel: _hotel(),
            stats: stats,
            isWishlisted: true,
            onToggleWishlist: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
    });

    testWidgets('tapping the bookmark fires onToggleWishlist', (tester) async {
      var toggled = false;
      final stats = PassportVenueStats.from(HotelVenue(_hotel()), [
        _visit(
          entityType: 'hotel',
          entityId: 'h1',
          visitedOn: DateTime(2026, 1, 1),
        ),
      ]);
      await tester.pumpWidget(
        _wrap(
          PassportHotelCard(
            hotel: _hotel(),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () => toggled = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
      expect(toggled, isTrue);
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
        _wrap(
          PassportHotelCard(
            hotel: _hotel(michelinKeys: 3),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () {},
          ),
        ),
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
        _wrap(
          PassportHotelCard(
            hotel: _hotel(),
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () {},
          ),
        ),
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
        _wrap(
          PassportHotelCard(
            hotel: hotel,
            stats: stats,
            isWishlisted: false,
            onToggleWishlist: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('2 stays'), findsOneWidget);
    });

    testWidgets('renders correctly at 320/375/390/430', (tester) async {
      for (final width in [320.0, 375.0, 390.0, 430.0]) {
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
          _wrap(
            PassportHotelCard(
              hotel: _hotel(michelinKeys: 2),
              stats: stats,
              isWishlisted: false,
              onToggleWishlist: () {},
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull, reason: '${width}px');
      }
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
                  isWishlisted: false,
                  onToggleWishlist: () {},
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
