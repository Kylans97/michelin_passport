// Covers the Explore RestaurantTile/HotelTile overflow regression: the
// star/key + location Row, and the World's 50 Best rank Row, both had a
// bare Text with no Expanded/Flexible wrapper — at ~195px available width
// (a real device's content column: cardWidth - margin - padding -
// VenueThumbnail - spacing), a long city/country label or a wide rank
// string overflowed the Row on the right, exactly as reported ("A
// RenderFlex overflowed by 28 pixels on the right", varying amounts across
// different cards). Both rows now wrap their Text in Expanded with
// maxLines: 1 + TextOverflow.ellipsis, mirroring the hotelName/
// restaurantCount rows in the same files, which already did this
// correctly and never overflowed.
//
// tester.takeException() is the actual assertion: a RenderFlex overflow
// throws during layout/paint and is captured there, not as a normal
// widget-tree difference — a test that only checked `findsOneWidget`
// would pass even with the bug present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/explore/widgets/hotel_tile.dart';
import 'package:michelin_passport/features/explore/widgets/restaurant_tile.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({
  String name = 'Test Restaurant',
  int? michelinStars,
  String cityName = 'Paris',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
  bool isInHotel = false,
  String? hotelName,
  int? worlds50BestRank,
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
  isInHotel: isInHotel,
  hotelName: hotelName,
  worlds50BestRank: worlds50BestRank,
);

Hotel _hotel({
  String name = 'Test Hotel',
  int? michelinKeys,
  String cityName = 'Paris',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
  bool hasMichelinRestaurant = false,
  int restaurantCount = 0,
  int? worlds50BestRank,
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
  hasMichelinRestaurant: hasMichelinRestaurant,
  restaurantCount: restaurantCount,
  worlds50BestRank: worlds50BestRank,
);

// The exact width the bug report described as "approximately 195px
// available width" for the Row itself (i.e. wrapping the tile at a
// realistic narrow phone width so the content column comes out to ~195px:
// deviceWidth(361) - margin(40) - padding(28) - thumbnail(84) - spacing(14)).
const double _narrowDeviceWidth = 361;

Widget _wrap(
  Widget child, {
  double width = _narrowDeviceWidth,
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('RestaurantTile — long content at narrow widths', () {
    testWidgets('long city+country name a few pixels over does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RestaurantTile(
            restaurant: _restaurant(
              michelinStars: 1,
              cityName: 'Chateauneuf-sur-Loire',
              countryName: 'France',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('3-star rating plus a long city name (~20-30px case)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RestaurantTile(
            restaurant: _restaurant(
              michelinStars: 3,
              cityName: 'Bad Wörishofen im Allgäu',
              countryName: 'Germany',
              flagEmoji: '🇩🇪',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'very long city and country name, plus hotel line and World\'s 50 '
      'Best rank all at once (~60px+ case)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            RestaurantTile(
              restaurant: _restaurant(
                michelinStars: 3,
                cityName: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
                countryName:
                    'United Kingdom of Great Britain and Northern Ireland',
                flagEmoji: '🇬🇧',
                isInHotel: true,
                hotelName: 'The Grand Exceptionally Long Hotel Property Name',
                worlds50BestRank: 137,
              ),
              showWorlds50BestRank: true,
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('no stars, long location only', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RestaurantTile(
            restaurant: _restaurant(
              cityName: 'Saint-Jean-Pied-de-Port-sur-Adour',
              countryName: 'France',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders correctly at the exact reported ~195px Row width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RestaurantTile(
            restaurant: _restaurant(
              michelinStars: 2,
              cityName: 'Saint-Rémy-de-Provence',
              countryName: 'France',
            ),
          ),
          width: 361,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('increased text scale (accessibility) does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RestaurantTile(
            restaurant: _restaurant(
              michelinStars: 2,
              cityName: 'Bad Wörishofen im Allgäu',
              countryName: 'Germany',
              flagEmoji: '🇩🇪',
              isInHotel: true,
              hotelName: 'The Grand Exceptionally Long Hotel Property Name',
            ),
          ),
          textScale: 1.6,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ellipsis truncation actually applied to the location text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RestaurantTile(
            restaurant: _restaurant(
              michelinStars: 3,
              cityName: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
              countryName: 'United Kingdom',
            ),
          ),
        ),
      );
      await tester.pump();
      final texts = tester.widgetList<Text>(find.byType(Text));
      final locationText = texts.firstWhere(
        (t) =>
            (t.data ?? '').contains('Llanfairpwllgwyngyllgogerychwyrndrobwll'),
      );
      expect(locationText.overflow, TextOverflow.ellipsis);
      expect(locationText.maxLines, 1);
    });
  });

  group('HotelTile — long content at narrow widths', () {
    testWidgets('long city+country name a few pixels over does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HotelTile(
            hotel: _hotel(
              michelinKeys: 1,
              cityName: 'Chateauneuf-sur-Loire',
              countryName: 'France',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('3-key hotel plus a long city name (~20-30px case)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HotelTile(
            hotel: _hotel(
              michelinKeys: 3,
              cityName: 'Bad Wörishofen im Allgäu',
              countryName: 'Germany',
              flagEmoji: '🇩🇪',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'very long city/country, restaurant-count line and World\'s 50 Best '
      'rank all at once (~60px+ case)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            HotelTile(
              hotel: _hotel(
                michelinKeys: 3,
                cityName: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
                countryName:
                    'United Kingdom of Great Britain and Northern Ireland',
                flagEmoji: '🇬🇧',
                hasMichelinRestaurant: true,
                restaurantCount: 3,
                worlds50BestRank: 42,
              ),
              showWorlds50BestRank: true,
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('World\'s 50 Best rank shown with no Keys, long location', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HotelTile(
            hotel: _hotel(
              cityName: 'Saint-Jean-Pied-de-Port-sur-Adour',
              countryName: 'France',
              worlds50BestRank: 8,
            ),
            showWorlds50BestRank: true,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('increased text scale (accessibility) does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HotelTile(
            hotel: _hotel(
              michelinKeys: 2,
              cityName: 'Bad Wörishofen im Allgäu',
              countryName: 'Germany',
              flagEmoji: '🇩🇪',
              hasMichelinRestaurant: true,
              restaurantCount: 2,
            ),
          ),
          textScale: 1.6,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ellipsis truncation actually applied to the location text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HotelTile(
            hotel: _hotel(
              michelinKeys: 3,
              cityName: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
              countryName: 'United Kingdom',
            ),
          ),
        ),
      );
      await tester.pump();
      final texts = tester.widgetList<Text>(find.byType(Text));
      final locationText = texts.firstWhere(
        (t) =>
            (t.data ?? '').contains('Llanfairpwllgwyngyllgogerychwyrndrobwll'),
      );
      expect(locationText.overflow, TextOverflow.ellipsis);
      expect(locationText.maxLines, 1);
    });
  });
}
