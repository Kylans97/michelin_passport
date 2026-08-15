// Covers FriendVisitTile and FriendWishlistTile (Social Foundation Step 2
// §13-14 — the Friend Profile VISITED/WISHLIST tiles). Pumped directly,
// including the real FriendPhotoStrip FriendVisitTile embeds: confirmed
// safe without a live Supabase session because FriendPhotoStrip's own
// _load() catches the synchronous throw from an uninitialized
// Supabase.instance.client inside its own try block (see the widget's own
// doc comment) — no presentation-seam stand-in needed here, unlike
// screens that touch Supabase in initState outside a try/catch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/friends/widgets/friend_visit_tile.dart';
import 'package:michelin_passport/features/friends/widgets/friend_wishlist_tile.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

Restaurant _restaurant({
  String name = 'Test Restaurant',
  int? michelinStars,
  String cityName = 'Paris',
  String countryName = 'France',
}) => Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  cityName: cityName,
  countryCode: 'FR',
  countryName: countryName,
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
);

Hotel _hotel({
  String name = 'Test Hotel',
  int? michelinKeys,
  String cityName = 'Paris',
  String countryName = 'France',
}) => Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: name,
  michelinKeys: michelinKeys,
  cityName: cityName,
  countryCode: 'FR',
  countryName: countryName,
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Visit _visit({
  String id = 'v1',
  int? rating,
  String? notes,
  DateTime? visitedOn,
  VisitVisibility visibility = VisitVisibility.friends,
}) => Visit(
  id: id,
  userId: 'friend-u1',
  entityType: 'restaurant',
  entityId: 'r1',
  visitedOn: visitedOn ?? DateTime(2026, 6, 12),
  rating: rating,
  notes: notes,
  visibility: visibility,
);

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('FriendVisitTile', () {
    testWidgets('renders venue name, location, date, and rating', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(_restaurant(michelinStars: 2)),
            visit: _visit(rating: 9),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Test Restaurant'), findsOneWidget);
      expect(find.text('Paris, France'), findsOneWidget);
      expect(find.text('9/10'), findsOneWidget);
      expect(find.text('12 June 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders notes when present, omits them when absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(_restaurant()),
            visit: _visit(notes: 'Wonderful tasting menu.'),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Wonderful tasting menu.'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(_restaurant()),
            visit: _visit(),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Wonderful tasting menu.'), findsNothing);
    });

    testWidgets('renders a hotel stay via HotelVenue with Keys', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: HotelVenue(_hotel(michelinKeys: 3)),
            visit: _visit(rating: 8),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Test Hotel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long restaurant name + long city/country — no overflow, '
        '320px', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(
              _restaurant(
                name:
                    'The Extraordinarily Long and Elaborate Tasting Room '
                    'Restaurant Name',
                cityName: 'Saint-Jean-de-Very-Long-City-Name-Indeed',
                countryName: 'United Kingdom of Great Britain',
              ),
            ),
            visit: _visit(
              rating: 10,
              notes:
                  'A very long note that keeps going and going and going '
                  'well past what a single line could ever hold comfortably.',
            ),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      await tester.pump();
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
                child: FriendVisitTile(
                  venue: RestaurantVenue(_restaurant(michelinStars: 3)),
                  visit: _visit(rating: 10, notes: 'Long note here.'),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the row fires onTap (navigates to canonical venue '
        'detail — Step 2B §2)', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(_restaurant()),
            visit: _visit(),
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(FriendVisitTile));
      expect(tapped, isTrue);
    });

    testWidgets('shows a chevron affordance, not a prominent button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(_restaurant()),
            visit: _visit(),
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.textContaining('View restaurant'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('FriendWishlistTile', () {
    testWidgets('renders venue name, location, and fires onTap', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FriendWishlistTile(
            venue: RestaurantVenue(_restaurant(michelinStars: 1)),
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Test Restaurant'), findsOneWidget);
      expect(find.text('Paris, France'), findsOneWidget);
      await tester.tap(find.byType(FriendWishlistTile));
      expect(tapped, isTrue);
    });

    testWidgets('never shows a remove affordance', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendWishlistTile(
            venue: RestaurantVenue(_restaurant()),
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.textContaining('Remove'), findsNothing);
    });

    testWidgets('renders a hotel venue with Keys', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendWishlistTile(
            venue: HotelVenue(_hotel(michelinKeys: 2)),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Test Hotel'), findsOneWidget);
    });

    testWidgets('long name — no overflow, 320px', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendWishlistTile(
            venue: RestaurantVenue(
              _restaurant(
                name: 'An Impressively Overlong Restaurant Name For Testing',
                cityName: 'A Very Long City Name',
                countryName: 'A Very Long Country Name Indeed',
              ),
            ),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
