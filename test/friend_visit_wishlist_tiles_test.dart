// Covers FriendVisitTile and FriendWishlistTile (Community/Friends UX
// Step 1 — the Friend Profile VISITED/WISHLIST rows). Presentation-only,
// no Supabase involved — Step 1 dropped the embedded FriendPhotoStrip (see
// docs/Architecture/COMMUNITY_FRIENDS_UX.md) so these tiles no longer
// touch Supabase at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
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
    backgroundColor: AppColors.ivory,
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('FriendVisitTile', () {
    testWidgets('renders venue name, city, flag, date, and rating', (
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
      expect(
        find.textContaining('Test Restaurant', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('🇫🇷'), findsOneWidget);
      expect(find.text('9/10 · 12 June 2026'), findsOneWidget);
      expect(find.byType(StarRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'no longer renders notes — this is a concise discovery preview, not '
      'a full visit-detail view (Step 1)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FriendVisitTile(
              venue: RestaurantVenue(_restaurant()),
              visit: _visit(notes: 'Wonderful tasting menu.'),
              onTap: () {},
            ),
          ),
        );
        expect(find.text('Wonderful tasting menu.'), findsNothing);
      },
    );

    testWidgets('omits the date/rating format gracefully when unrated', (
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
      expect(find.text('12 June 2026'), findsOneWidget);
      expect(find.textContaining('/10'), findsNothing);
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
      expect(
        find.textContaining('Test Hotel', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(KeyRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('combines name, city, country and recognition into one spoken '
        'accessibility label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(_restaurant(michelinStars: 3)),
            visit: _visit(rating: 9),
            onTap: () {},
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(FriendVisitTile));
      expect(
        semantics.label,
        'Test Restaurant, Paris, France, 3 Michelin stars, rated 9 out of 10',
      );
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
            visit: _visit(rating: 10),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.ivory,
              body: SizedBox(
                width: 320,
                child: FriendVisitTile(
                  venue: RestaurantVenue(_restaurant(michelinStars: 3)),
                  visit: _visit(rating: 10),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the row fires onTap (navigates to canonical venue '
        'detail)', (tester) async {
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

    testWidgets('shows no chevron and no prominent button — the row itself '
        'reads as tappable', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(_restaurant()),
            visit: _visit(),
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.textContaining('View restaurant'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('never renders gold — rating and date are taupe metadata', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendVisitTile(
            venue: RestaurantVenue(_restaurant()),
            visit: _visit(rating: 9),
            onTap: () {},
          ),
        ),
      );
      final ratingText = tester.widget<Text>(find.text('9/10 · 12 June 2026'));
      expect(ratingText.style?.color, isNot(AppColors.gold));
      expect(ratingText.style?.color, AppColors.taupe);
    });
  });

  group('FriendWishlistTile', () {
    testWidgets('renders venue name, city, flag, and fires onTap', (
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
      expect(
        find.textContaining('Test Restaurant', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('🇫🇷'), findsOneWidget);
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
      expect(
        find.textContaining('Test Hotel', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(KeyRow), findsOneWidget);
    });

    testWidgets('combines name, city, country and recognition into one spoken '
        'accessibility label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendWishlistTile(
            venue: HotelVenue(_hotel(michelinKeys: 2)),
            onTap: () {},
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(FriendWishlistTile));
      expect(semantics.label, 'Test Hotel, Paris, France, 2 Michelin Keys');
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
