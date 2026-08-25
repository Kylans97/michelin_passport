// PASSPORT — WISHLIST UI POLISH V1: covers WishlistRestaurantCard/
// WishlistHotelCard — the ivory CsPlaceCard-family cards that replaced
// WishlistVenueRow's compact list rows. Mirrors passport_cards_test.dart's
// own fixture pattern and documented limitation: tapping through to
// RestaurantDetailScreen/HotelDetailScreen isn't exercised here since both
// construct Supabase-backed repositories eagerly with no session in this
// sandbox — presence of the tap affordance is verified structurally.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/features/wishlist/widgets/wishlist_venue_cards.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';

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

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('WishlistRestaurantCard', () {
    testWidgets('renders name, city+country, stars, and the canonical '
        'image fallback — no visit/rating footer', (tester) async {
      final restaurant = _restaurant(
        name: 'ABAC',
        michelinStars: 2,
        cityName: 'Barcelona',
        countryName: 'Spain',
        flagEmoji: '🇪🇸',
      );
      await tester.pumpWidget(
        _wrap(WishlistRestaurantCard(restaurant: restaurant, onRemove: () {})),
      );
      expect(find.text('ABAC'), findsOneWidget);
      expect(find.text('Barcelona, 🇪🇸 Spain'), findsOneWidget);
      expect(find.byType(StarRow), findsOneWidget);
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
      // Wishlist is not visit history — no rating/visit-count/last-visit.
      expect(find.textContaining('visit'), findsNothing);
      expect(find.textContaining('average'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unstarred restaurant renders no StarRow', (tester) async {
      final restaurant = _restaurant(michelinStars: null);
      await tester.pumpWidget(
        _wrap(WishlistRestaurantCard(restaurant: restaurant, onRemove: () {})),
      );
      expect(find.byType(StarRow), findsNothing);
    });

    testWidgets('the bookmark is filled (already-saved state) — tapping '
        'it fires onRemove, not card navigation', (tester) async {
      var removed = false;
      final restaurant = _restaurant();
      await tester.pumpWidget(
        _wrap(
          WishlistRestaurantCard(
            restaurant: restaurant,
            onRemove: () => removed = true,
          ),
        ),
      );
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      expect(removed, isTrue);
    });

    testWidgets('renders as a tappable card (navigation entry point)', (
      tester,
    ) async {
      final restaurant = _restaurant();
      await tester.pumpWidget(
        _wrap(WishlistRestaurantCard(restaurant: restaurant, onRemove: () {})),
      );
      expect(find.byType(InkWell), findsWidgets);
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('no overflow at ${width.toInt()}px — long name, long '
          'city/country, 3 stars', (tester) async {
        final restaurant = _restaurant(
          name: 'An Exceptionally Long Michelin Restaurant Name',
          michelinStars: 3,
          cityName: 'A Fairly Long City Name',
          countryName: 'A Fairly Long Country Name',
        );
        await tester.pumpWidget(
          _wrap(
            WishlistRestaurantCard(restaurant: restaurant, onRemove: () {}),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow at 1.6x text scale, 320px', (tester) async {
      final restaurant = _restaurant(michelinStars: 3);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 320,
                child: WishlistRestaurantCard(
                  restaurant: restaurant,
                  onRemove: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('WishlistHotelCard', () {
    testWidgets('renders name, city+country, Keys (never Stars)', (
      tester,
    ) async {
      final hotel = _hotel(
        name: "De L'Europe",
        michelinKeys: 3,
        cityName: 'Amsterdam',
        countryName: 'Netherlands',
        flagEmoji: '🇳🇱',
      );
      await tester.pumpWidget(
        _wrap(WishlistHotelCard(hotel: hotel, onRemove: () {})),
      );
      expect(find.text("De L'Europe"), findsOneWidget);
      expect(find.text('Amsterdam, 🇳🇱 Netherlands'), findsOneWidget);
      expect(find.byType(KeyRow), findsOneWidget);
      expect(find.byType(StarRow), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hotel with no Keys renders no KeyRow', (tester) async {
      final hotel = _hotel(michelinKeys: null);
      await tester.pumpWidget(
        _wrap(WishlistHotelCard(hotel: hotel, onRemove: () {})),
      );
      expect(find.byType(KeyRow), findsNothing);
    });

    testWidgets('tapping the filled bookmark fires onRemove', (tester) async {
      var removed = false;
      final hotel = _hotel();
      await tester.pumpWidget(
        _wrap(WishlistHotelCard(hotel: hotel, onRemove: () => removed = true)),
      );
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      expect(removed, isTrue);
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('no overflow at ${width.toInt()}px — long name, 3 Keys', (
        tester,
      ) async {
        final hotel = _hotel(
          name: 'An Exceptionally Long And Storied Hotel Name',
          michelinKeys: 3,
        );
        await tester.pumpWidget(
          _wrap(WishlistHotelCard(hotel: hotel, onRemove: () {}), width: width),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
