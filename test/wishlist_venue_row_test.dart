// Covers WishlistVenueRow (Wishlist UI Consistency Step 1) — the
// editorial thumbnail+name+recognition+city/flag row replacing the old
// boxed WishlistCard, plus its own remove affordance. Structurally the
// same language friend_wishlist_tile.dart already established (see
// friend_visit_wishlist_tiles_test.dart), with a second, independently
// tappable remove control added.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/core/widgets/venue_thumbnail.dart';
import 'package:michelin_passport/features/wishlist/widgets/wishlist_venue_row.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({
  String id = 'r1',
  String name = 'Tout a Fait',
  int? michelinStars = 1,
  String cityName = 'Maastricht',
  String countryCode = 'NL',
  String countryName = 'Netherlands',
  String flagEmoji = '🇳🇱',
}) => Restaurant(
  id: id,
  restaurantCode: 'rest_$id',
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  isHallOfFame: false,
  cityName: cityName,
  countryCode: countryCode,
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
  isInHotel: false,
  hotelId: null,
  hotelName: null,
  worlds50BestRank: null,
);

Hotel _hotel({
  String id = 'h1',
  String name = "De L'Europe",
  int? michelinKeys = 3,
  String cityName = 'Amsterdam',
  String countryCode = 'NL',
  String countryName = 'Netherlands',
  String flagEmoji = '🇳🇱',
}) => Hotel(
  id: id,
  hotelCode: 'hotel_$id',
  name: name,
  michelinKeys: michelinKeys,
  cityName: cityName,
  countryCode: countryCode,
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Canal Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(backgroundColor: AppColors.ivory, body: child),
      ),
    );

void main() {
  group('WishlistVenueRow — restaurant', () {
    testWidgets('renders thumbnail, name, stars, city, flag', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(_restaurant()),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      expect(find.byType(VenueThumbnail), findsOneWidget);
      expect(find.textContaining('Tout a Fait'), findsOneWidget);
      expect(find.byType(StarRow), findsOneWidget);
      final star = tester.widget<StarRow>(find.byType(StarRow));
      expect(star.count, 1);
      expect(find.text('Maastricht'), findsOneWidget);
      expect(find.text('🇳🇱'), findsOneWidget);
    });

    testWidgets('placeholder thumbnail fallback (no restaurant photo data '
        'exists yet)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(_restaurant()),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      final thumb = tester.widget<VenueThumbnail>(find.byType(VenueThumbnail));
      expect(thumb.imageUrl, isNull);
      expect(thumb.size, 52);
    });

    testWidgets('unstarred restaurant renders no StarRow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(_restaurant(michelinStars: null)),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      expect(find.byType(StarRow), findsNothing);
    });

    testWidgets('tapping the row (not the remove control) fires onTap', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(_restaurant()),
            onTap: () => tapped = true,
            onRemove: () => fail('onRemove should not fire'),
          ),
        ),
      );
      await tester.tap(find.textContaining('Tout a Fait'));
      expect(tapped, isTrue);
    });

    testWidgets('tapping the heart fires onRemove, not onTap', (tester) async {
      var removed = false;
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(_restaurant()),
            onTap: () => fail('onTap should not fire'),
            onRemove: () => removed = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      expect(removed, isTrue);
    });

    testWidgets('remove icon is forest-green, never gold', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(_restaurant()),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded));
      expect(icon.color, AppColors.forestGreen);
      expect(icon.color, isNot(AppColors.gold));
    });

    testWidgets('venue name/thumbnail/recognition share one merged '
        'semantics target; remove has its own separate label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(_restaurant()),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Tout a Fait, Maastricht, Netherlands, 1 Michelin star',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Remove from wishlist'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('long restaurant name wraps, no overflow at 320px', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(
              _restaurant(
                name:
                    'An Exceptionally Long Michelin Restaurant Name That '
                    'Genuinely Tests Wrapping Behaviour',
                michelinStars: 3,
              ),
            ),
            onTap: () {},
            onRemove: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      final star = tester.widget<StarRow>(find.byType(StarRow));
      expect(star.count, 3, reason: 'stars must never be truncated away');
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: RestaurantVenue(_restaurant(michelinStars: 3)),
            onTap: () {},
            onRemove: () {},
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('WishlistVenueRow — hotel', () {
    testWidgets('renders thumbnail, name, Keys, city, flag', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: HotelVenue(_hotel()),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      expect(find.byType(VenueThumbnail), findsOneWidget);
      expect(find.textContaining("De L'Europe"), findsOneWidget);
      expect(find.byType(KeyRow), findsOneWidget);
      final key = tester.widget<KeyRow>(find.byType(KeyRow));
      expect(key.count, 3);
      expect(find.text('Amsterdam'), findsOneWidget);
      expect(find.text('🇳🇱'), findsOneWidget);
    });

    testWidgets('hotel with no Keys renders no KeyRow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: HotelVenue(_hotel(michelinKeys: null)),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      expect(find.byType(KeyRow), findsNothing);
    });

    testWidgets('tapping the row fires onTap; tapping the heart fires '
        'onRemove', (tester) async {
      var tapped = false;
      var removed = false;
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: HotelVenue(_hotel()),
            onTap: () => tapped = true,
            onRemove: () => removed = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      expect(removed, isTrue);
      expect(tapped, isFalse);
      await tester.tap(find.textContaining("De L'Europe"));
      expect(tapped, isTrue);
    });

    testWidgets('accessibility: name, city, country and Key count combine '
        'into one label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: HotelVenue(_hotel()),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          "De L'Europe, Amsterdam, Netherlands, 3 Michelin Keys",
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('singular "1 Michelin Key" wording for exactly one Key', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: HotelVenue(_hotel(michelinKeys: 1)),
            onTap: () {},
            onRemove: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          "De L'Europe, Amsterdam, Netherlands, 1 Michelin Key",
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('long hotel name wraps, no overflow at 320px', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: HotelVenue(
              _hotel(
                name:
                    'An Exceptionally Long And Storied Hotel Name For '
                    'Wrapping Behaviour',
                michelinKeys: 3,
              ),
            ),
            onTap: () {},
            onRemove: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      final key = tester.widget<KeyRow>(find.byType(KeyRow));
      expect(key.count, 3, reason: 'Keys must never be truncated away');
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WishlistVenueRow(
            venue: HotelVenue(_hotel(michelinKeys: 3)),
            onTap: () {},
            onRemove: () {},
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
