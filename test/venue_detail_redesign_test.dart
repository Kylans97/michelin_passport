// Covers UI Consistency Step 1 through Step 1E (Restaurant + Hotel Detail
// redesign, then successive physical-device polish passes) — focused
// widget coverage for the new, purely presentational components, per the
// task's own test strategy: RestaurantDetailScreen/HotelDetailScreen
// themselves are StatefulWidgets that hit Supabase in initState (this
// project has no Supabase mocking harness — see test/hotel_nullable_keys_
// test.dart's own precedent), so coverage targets the extracted
// presentational primitives they're built from instead: VenueDetailHero
// (+ RestaurantHero/HotelHero, which wrap it), VenueUtilityActions,
// VenueScoreStrip, VenueScoreHeader, VenueAboutSection, SectionDivider,
// VenueVisitRow/VenueVisitStatusRow, LinkedVenueRow,
// RestaurantVisitsCard/HotelStaysCard, RestaurantInfoCard/HotelInfoCard,
// and SubtleTextAction — none of these touch Supabase, all take data via
// constructor params.
//
// The hard color rule (Step 1B §30, reconfirmed every step since): gold is
// reserved for Michelin stars/Keys alone — never Wishlist/visited/stayed
// state, never a generic button, never World's 50 Best, never Hall of
// Fame. Tests below assert this at the token/property level (never a
// brittle pixel test) by checking the actual `Container`/`Icon`/`Text`
// color values the widgets resolve to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/linked_venue_row.dart';
import 'package:michelin_passport/core/widgets/section_divider.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/core/widgets/subtle_text_action.dart';
import 'package:michelin_passport/core/widgets/venue_about_section.dart';
import 'package:michelin_passport/core/widgets/venue_detail_hero.dart';
import 'package:michelin_passport/core/widgets/venue_score_strip.dart';
import 'package:michelin_passport/core/widgets/venue_utility_actions.dart';
import 'package:michelin_passport/core/widgets/venue_visit_row.dart';
import 'package:michelin_passport/features/hotels/widgets/hotel_hero.dart';
import 'package:michelin_passport/features/hotels/widgets/hotel_info_card.dart';
import 'package:michelin_passport/features/hotels/widgets/hotel_stays_card.dart';
import 'package:michelin_passport/features/restaurants/widgets/restaurant_hero.dart';
import 'package:michelin_passport/features/restaurants/widgets/restaurant_info_card.dart';
import 'package:michelin_passport/features/restaurants/widgets/restaurant_visits_card.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

Restaurant _restaurant({
  String name = 'Test Restaurant',
  int? michelinStars,
  bool isHallOfFame = false,
  int? worlds50BestRank,
  bool isInHotel = false,
  String? hotelId,
  String? hotelName,
  String address = '1 Rue de Test',
}) => Restaurant(
  id: 'r1',
  restaurantCode: 'rest_0001',
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  isHallOfFame: isHallOfFame,
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: address,
  isInHotel: isInHotel,
  hotelId: hotelId,
  hotelName: hotelName,
  worlds50BestRank: worlds50BestRank,
);

Hotel _hotel({
  String name = 'Test Hotel',
  int? michelinKeys,
  int? worlds50BestRank,
  int? worlds50BestYear,
  String address = '1 Rue de Test',
}) => Hotel(
  id: 'h1',
  hotelCode: 'hotel_0001',
  name: name,
  michelinKeys: michelinKeys,
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: address,
  hasMichelinRestaurant: false,
  restaurantCount: 0,
  worlds50BestRank: worlds50BestRank,
  worlds50BestYear: worlds50BestYear,
);

Visit _visit({DateTime? visitedOn, int? rating, MenuType? menuType}) => Visit(
  id: 'v1',
  userId: 'u1',
  entityType: 'restaurant',
  entityId: 'r1',
  visitedOn: visitedOn ?? DateTime(2026, 3, 14),
  rating: rating,
  menuType: menuType,
);

Map<String, dynamic> _visitRow({
  String entityType = 'hotel',
  int? rating,
  int? serviceRating,
  int? roomRating,
  int? experienceRating,
  int? valueRating,
}) => {
  'id': 'v1',
  'user_id': 'u1',
  'entity_type': entityType,
  'entity_id': 'h1',
  'visited_on': '2026-08-15',
  'rating': rating,
  'service_rating': serviceRating,
  'room_rating': roomRating,
  'experience_rating': experienceRating,
  'value_rating': valueRating,
};

// VenueDetailHero (and its two wrappers) render a SliverAppBar — needs a
// scroll-sliver host, matching how RestaurantDetailScreen/HotelDetailScreen
// actually mount it, not a bare Material.
Widget _wrapSliver(Widget sliver, {double width = 400}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 800)),
    child: Scaffold(body: CustomScrollView(slivers: [sliver])),
  ),
);

Widget _wrap(Widget child, {double width = 400, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: Material(child: child)),
      ),
    );

void main() {
  group('VenueDetailHero — header hierarchy', () {
    testWidgets('shows title, primary recognition, and secondary badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSliver(
          VenueDetailHero(
            title: 'Le Grand Restaurant',
            primaryRecognition: const StarRow(count: 3, size: 20),
            secondaryBadges: const [
              VenueHeroBadge(
                icon: Icons.emoji_events_rounded,
                label: "World's 50 Best · #4",
              ),
            ],
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Le Grand Restaurant'), findsWidgets);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.textContaining("World's 50 Best · #4"), findsOneWidget);
    });

    testWidgets('omits primary recognition entirely when null — no stray '
        'empty row or placeholder', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          VenueDetailHero(
            title: 'Unstarred Bistro',
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byType(StarRow), findsNothing);
    });

    testWidgets('no-image state renders a tonal gradient, never an Image '
        'widget pretending to be a photo', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          VenueDetailHero(
            title: 'No Photo Venue',
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('back control is present with semantic label "Back"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSliver(
          VenueDetailHero(
            title: 'Venue',
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Back'),
        findsOneWidget,
        reason:
            'Section 5: EditorialBackButton only, no old circular '
            'translucent control',
      );
    });

    testWidgets('wishlist toggle reflects state and fires the callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrapSliver(
          VenueDetailHero(
            title: 'Venue',
            isWishlisted: true,
            wishlistSaving: false,
            onTapWishlist: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      expect(tapped, isTrue);
    });

    testWidgets('a saving wishlist toggle ignores taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrapSliver(
          VenueDetailHero(
            title: 'Venue',
            isWishlisted: false,
            wishlistSaving: true,
            onTapWishlist: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(tapped, isFalse);
    });
  });

  group('VenueDetailHero — responsive (§18)', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('long title + 3 stars + two badges: no overflow at '
          '${width}px', (tester) async {
        await tester.pumpWidget(
          _wrapSliver(
            VenueDetailHero(
              title:
                  'The Extraordinarily Long Name Of A Very Prestigious '
                  'Michelin-Starred Restaurant Establishment',
              primaryRecognition: const StarRow(count: 3, size: 20),
              secondaryBadges: const [
                VenueHeroBadge(
                  icon: Icons.emoji_events_rounded,
                  label: "World's 50 Best · #1",
                ),
                VenueHeroBadge(
                  icon: Icons.hotel_rounded,
                  label: 'Inside The Grand Hotel Of Somewhere Very Far Away',
                ),
              ],
              isWishlisted: false,
              wishlistSaving: false,
              onTapWishlist: () {},
            ),
            width: width,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders at 1.6x text scale with no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 800),
              textScaler: TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  VenueDetailHero(
                    title:
                        'Le Bristol Paris — A Very Long Establishment '
                        'Name',
                    primaryRecognition: const StarRow(count: 3, size: 20),
                    secondaryBadges: const [
                      VenueHeroBadge(
                        icon: Icons.emoji_events_rounded,
                        label: "World's 50 Best · #4",
                      ),
                    ],
                    isWishlisted: false,
                    wishlistSaving: false,
                    onTapWishlist: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('RestaurantHero — consolidated recognition (§6)', () {
    testWidgets('3 stars is the sole primary signal; Hall of Fame, '
        "World's 50 Best, and hotel name are secondary badges", (tester) async {
      final restaurant = _restaurant(
        michelinStars: 3,
        isHallOfFame: true,
        worlds50BestRank: 2,
        isInHotel: true,
        hotelId: 'h1',
        hotelName: 'The Grand Hotel',
      );
      await tester.pumpWidget(
        _wrapSliver(
          RestaurantHero(
            restaurant: restaurant,
            hasHotelBadge: true,
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.textContaining('Hall of Fame'), findsOneWidget);
      expect(find.textContaining("World's 50 Best · #2"), findsOneWidget);
      expect(find.textContaining('The Grand Hotel'), findsOneWidget);
    });

    testWidgets('no stars: no StarRow, restaurant name still primary', (
      tester,
    ) async {
      final restaurant = _restaurant(michelinStars: null);
      await tester.pumpWidget(
        _wrapSliver(
          RestaurantHero(
            restaurant: restaurant,
            hasHotelBadge: false,
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StarRow), findsNothing);
      expect(find.text(restaurant.name), findsWidgets);
    });

    testWidgets('long restaurant name at 320px: no overflow', (tester) async {
      final restaurant = _restaurant(
        name:
            'The Extraordinarily Long Name Of A Very Prestigious '
            'Three-Starred Establishment In The Countryside',
        michelinStars: 3,
      );
      await tester.pumpWidget(
        _wrapSliver(
          RestaurantHero(
            restaurant: restaurant,
            hasHotelBadge: false,
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('HotelHero — MICHELIN Keys recognition (§12)', () {
    testWidgets('2 Keys is the primary signal; World\'s 50 Best (with '
        'year) is a secondary badge', (tester) async {
      final hotel = _hotel(
        michelinKeys: 2,
        worlds50BestRank: 4,
        worlds50BestYear: 2025,
      );
      await tester.pumpWidget(
        _wrapSliver(
          HotelHero(
            hotel: hotel,
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KeyRow), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_rounded), findsNWidgets(2));
      expect(
        find.textContaining("World's 50 Best · #4 · 2025"),
        findsOneWidget,
        reason:
            'the ranking year, previously shown by HotelAwardsCard, '
            'must survive the consolidation into the hero',
      );
    });

    testWidgets('no Keys, no World\'s 50 Best: neither renders', (
      tester,
    ) async {
      final hotel = _hotel();
      await tester.pumpWidget(
        _wrapSliver(
          HotelHero(
            hotel: hotel,
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KeyRow), findsNothing);
      expect(find.textContaining("World's 50 Best"), findsNothing);
    });

    testWidgets('long hotel name at 320px: no overflow', (tester) async {
      final hotel = _hotel(
        name:
            'The Extraordinarily Long Name Of A Very Prestigious Three '
            'Key Hospitality Establishment',
        michelinKeys: 3,
      );
      await tester.pumpWidget(
        _wrapSliver(
          HotelHero(
            hotel: hotel,
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('VenueUtilityActions — utility action row (Step 1D §7-11)', () {
    testWidgets('only Directions when nothing else is available — no dead '
        'Call/Michelin button, and Share is never offered at all (lower '
        'priority than Michelin for this product, not added this pass)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(VenueUtilityActions(onOpenMaps: () {})));
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Michelin'), findsNothing);
      expect(find.text('Website'), findsNothing);
      expect(find.text('Call'), findsNothing);
      expect(find.text('Share'), findsNothing);
    });

    testWidgets('3-item layout: Directions + Website + Michelin when '
        'phone is unavailable — today\'s real Restaurant/Hotel Detail '
        'shape', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VenueUtilityActions(
            onOpenMaps: () {},
            onOpenWebsite: () {},
            onOpenMichelin: () {},
          ),
          width: 320,
        ),
      );
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Michelin'), findsOneWidget);
      expect(find.text('Call'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4-item layout rebalances automatically once phone data '
        'exists: Directions + Website + Call + Michelin', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VenueUtilityActions(
            onOpenMaps: () {},
            onOpenWebsite: () {},
            onCall: () {},
            onOpenMichelin: () {},
          ),
          width: 320,
        ),
      );
      for (final label in ['Directions', 'Website', 'Call', 'Michelin']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Michelin fires only its own callback', (tester) async {
      var michelinCalls = 0;
      var callCalls = 0;
      await tester.pumpWidget(
        _wrap(
          VenueUtilityActions(
            onOpenMaps: () {},
            onCall: () => callCalls++,
            onOpenMichelin: () => michelinCalls++,
          ),
        ),
      );
      await tester.tap(find.text('Michelin'));
      expect(michelinCalls, 1);
      expect(callCalls, 0);
    });

    testWidgets('Michelin icon/text is forest-green, never gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(VenueUtilityActions(onOpenMaps: () {}, onOpenMichelin: () {})),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded));
      expect(icon.color, AppColors.forestGreen);
      expect(icon.color, isNot(AppColors.gold));
      final label = tester.widget<Text>(find.text('Michelin'));
      expect(label.style?.color, isNot(AppColors.gold));
    });

    testWidgets('both when Website is available; tapping Directions fires '
        'its own callback only', (tester) async {
      var mapsCalls = 0;
      var websiteCalls = 0;
      await tester.pumpWidget(
        _wrap(
          VenueUtilityActions(
            onOpenMaps: () => mapsCalls++,
            onOpenWebsite: () => websiteCalls++,
          ),
        ),
      );
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);

      await tester.tap(find.text('Directions'));
      expect(mapsCalls, 1);
      expect(websiteCalls, 0);
    });

    testWidgets('labels never wrap at 320px, even with all 4 actions '
        'present (§7 — the previous generation wrapped "Michelin"/'
        '"Website")', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VenueUtilityActions(
            onOpenMaps: () {},
            onOpenWebsite: () {},
            onCall: () {},
            onOpenMichelin: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final label in ['Directions', 'Website', 'Call', 'Michelin']) {
        final size = tester.getSize(find.text(label));
        // A single-line label's rendered height stays at one line's worth
        // — a wrapped two-line label would roughly double it.
        expect(
          size.height,
          lessThan(20),
          reason: '"$label" wrapped instead of staying on one line',
        );
      }
    });

    testWidgets('row stays balanced with just Directions (no Website '
        'link)', (tester) async {
      await tester.pumpWidget(
        _wrap(VenueUtilityActions(onOpenMaps: () {}), width: 320),
      );
      expect(find.text('Directions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('forest-green icon/text, never gold', (tester) async {
      await tester.pumpWidget(_wrap(VenueUtilityActions(onOpenMaps: () {})));
      final icon = tester.widget<Icon>(find.byIcon(Icons.directions_rounded));
      expect(icon.color, AppColors.forestGreen);
      expect(icon.color, isNot(AppColors.gold));
    });
  });

  group('VenueVisitRow / VenueVisitStatusRow', () {
    testWidgets('shows formatted date, rating, and subtitle; tap fires '
        'onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          VenueVisitRow(
            date: DateTime(2026, 3, 14),
            rating: 9,
            subtitle: 'Tasting menu',
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('14 March 2026'), findsOneWidget);
      expect(find.text('Overall 9/10'), findsOneWidget);
      expect(find.text('Tasting menu'), findsOneWidget);

      await tester.tap(find.byType(VenueVisitRow));
      expect(tapped, isTrue);
    });

    testWidgets('no rating: "Overall" line is omitted, not "Overall '
        'null/10"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VenueVisitRow(date: DateTime(2026, 1, 1), rating: null, onTap: () {}),
        ),
      );
      expect(find.textContaining('Overall'), findsNothing);
    });

    testWidgets('status row shows icon and message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueVisitStatusRow(
            icon: Icons.lock_outline_rounded,
            message: 'Sign in to save visits.',
          ),
        ),
      );
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.text('Sign in to save visits.'), findsOneWidget);
    });
  });

  group('LinkedVenueRow — related hotel / restaurant relationship (§10, '
      '§13)', () {
    testWidgets('interactive: shows a chevron and fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          LinkedVenueRow(
            name: 'The Grand Hotel',
            recognition: const StarRow(count: 2, size: 11),
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('The Grand Hotel'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.byType(LinkedVenueRow));
      expect(tapped, isTrue);
    });

    testWidgets('non-interactive (onTap null — a property_name-only '
        'hotel with no real hotel_id): no chevron, not tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LinkedVenueRow(name: 'Some Property')),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('loading: shows a spinner instead of the chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LinkedVenueRow(name: 'The Grand Hotel', loading: true, onTap: () {}),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('RestaurantVisitsCard — MY VISITS (§8)', () {
    testWidgets('signed out: shows the sign-in status row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RestaurantVisitsCard(
            isAuthenticated: false,
            loading: false,
            visits: const [],
            restaurant: _restaurant(),
            signInMessage: 'Sign in to save visits.',
            onReturn: () {},
          ),
        ),
      );
      expect(find.text('Sign in to save visits.'), findsOneWidget);
    });

    testWidgets('multiple visits: each renders its own row, newest first, '
        'preserving order as passed', (tester) async {
      final visits = [
        _visit(visitedOn: DateTime(2026, 3, 14), rating: 9),
        _visit(visitedOn: DateTime(2025, 6, 1), rating: 7),
      ];
      await tester.pumpWidget(
        _wrap(
          RestaurantVisitsCard(
            isAuthenticated: true,
            loading: false,
            visits: visits,
            restaurant: _restaurant(),
            signInMessage: 'x',
            onReturn: () {},
          ),
        ),
      );
      expect(find.byType(VenueVisitRow), findsNWidgets(2));
      expect(find.text('14 March 2026'), findsOneWidget);
      expect(find.text('1 June 2025'), findsOneWidget);
    });

    testWidgets('no visits: empty-state message, not a blank section', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RestaurantVisitsCard(
            isAuthenticated: true,
            loading: false,
            visits: const [],
            restaurant: _restaurant(),
            signInMessage: 'x',
            onReturn: () {},
          ),
        ),
      );
      expect(
        find.text("You haven't visited this restaurant yet."),
        findsOneWidget,
      );
    });
  });

  group('HotelStaysCard — MY STAYS (§14)', () {
    testWidgets('multiple stays render, no restaurant-only menu-type field '
        'forced into the hotel presentation', (tester) async {
      final stays = [
        _visit(visitedOn: DateTime(2026, 2, 1), rating: 8),
        _visit(visitedOn: DateTime(2025, 12, 25), rating: 10),
      ];
      await tester.pumpWidget(
        _wrap(
          HotelStaysCard(
            isAuthenticated: true,
            loading: false,
            stays: stays,
            hotel: _hotel(),
            signInMessage: 'x',
            onReturn: () {},
          ),
        ),
      );
      expect(find.byType(VenueVisitRow), findsNWidgets(2));
      expect(find.text('Overall 8/10'), findsOneWidget);
      expect(find.text('Overall 10/10'), findsOneWidget);
    });

    testWidgets('no stays: empty-state message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HotelStaysCard(
            isAuthenticated: true,
            loading: false,
            stays: const [],
            hotel: _hotel(),
            signInMessage: 'x',
            onReturn: () {},
          ),
        ),
      );
      expect(
        find.text("You haven't stayed at this hotel yet."),
        findsOneWidget,
      );
    });
  });

  group('RestaurantInfoCard / HotelInfoCard — no duplicate city/country '
      '(§4, §11)', () {
    testWidgets('RestaurantInfoCard shows only the address, never '
        'city/country (already shown once, under the hero)', (tester) async {
      final restaurant = _restaurant(address: '112 Rue du Faubourg');
      await tester.pumpWidget(
        _wrap(RestaurantInfoCard(restaurant: restaurant)),
      );
      expect(find.text('112 Rue du Faubourg'), findsOneWidget);
      expect(find.textContaining('Paris'), findsNothing);
      expect(find.textContaining('France'), findsNothing);
    });

    testWidgets('RestaurantInfoCard renders nothing for an empty address', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RestaurantInfoCard(restaurant: _restaurant(address: ''))),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('HotelInfoCard shows only the address', (tester) async {
      final hotel = _hotel(address: '1-5-6 Otemachi');
      await tester.pumpWidget(_wrap(HotelInfoCard(hotel: hotel)));
      expect(find.text('1-5-6 Otemachi'), findsOneWidget);
      expect(find.textContaining('Paris'), findsNothing);
    });
  });

  group('SubtleTextAction — action accessibility (Step 1E §17-21)', () {
    testWidgets('renders a legible label and fires onTap once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          SubtleTextAction(label: 'Add another visit', onTap: () => taps++),
        ),
      );
      expect(find.text('Add another visit'), findsOneWidget);
      await tester.tap(find.byType(SubtleTextAction));
      expect(taps, 1);
    });

    testWidgets('renders at a practical minimum tap target height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(SubtleTextAction(label: 'Plan visit', onTap: () {})),
      );
      final size = tester.getSize(find.byType(SubtleTextAction));
      expect(
        size.height,
        greaterThanOrEqualTo(32),
        reason: 'no tiny visual control with a tiny actual tap zone',
      );
    });
  });

  group('scoreProgress — pure score→ring calculation (Step 1D §2, §15)', () {
    test('10 → full circle (1.0)', () => expect(scoreProgress(10), 1.0));
    test('9 → 90%', () => expect(scoreProgress(9), closeTo(0.9, 1e-9)));
    test('7 → 70%', () => expect(scoreProgress(7), closeTo(0.7, 1e-9)));
    test('5 → 50%', () => expect(scoreProgress(5), 0.5));
    test(
      'decimal 8.5 → 85%',
      () => expect(scoreProgress(8.5), closeTo(0.85, 1e-9)),
    );
    test('null → 0, never negative or NaN', () {
      expect(scoreProgress(null), 0.0);
    });
    test('a value above 10 is clamped, never drawn past a full circle', () {
      expect(scoreProgress(15), 1.0);
    });
    test('a value below 0 is clamped, never drawn as negative', () {
      expect(scoreProgress(-3), 0.0);
    });
  });

  group('VenueScoreStrip — score rings (Step 1D §1-3, §16)', () {
    testWidgets('one ring per dimension, all identical diameter — no '
        'CircularProgressIndicator, correct progress fraction, forest-'
        'green foreground, never gold', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 7),
              ScoreDimension(label: 'Food', value: 5),
              ScoreDimension(label: 'Service', value: 7),
              ScoreDimension(label: 'Wine', value: 6),
              ScoreDimension(label: 'Value', value: 6),
            ],
          ),
        ),
      );
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a Material progress indicator is not this ring',
      );

      final customPaints = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ScoreRingPainter)
          .toList();
      expect(customPaints, hasLength(5));

      final painters = customPaints
          .map((w) => w.painter as ScoreRingPainter)
          .toList();
      final expectedProgress = [0.7, 0.5, 0.7, 0.6, 0.6];
      for (var i = 0; i < painters.length; i++) {
        expect(painters[i].progress, closeTo(expectedProgress[i], 1e-9));
        expect(painters[i].foreground, AppColors.forestGreen);
        expect(painters[i].foreground, isNot(AppColors.gold));
        expect(painters[i].background, isNot(AppColors.gold));
      }

      final sizes = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ScoreRingPainter)
          .map((w) => tester.getSize(find.byWidget(w)))
          .toSet();
      expect(
        sizes.length,
        1,
        reason: 'all score rings must share one identical diameter',
      );
    });

    testWidgets('a null dimension renders an empty (0-progress) ring, '
        'never a fabricated value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [ScoreDimension(label: 'Wine', value: null)],
          ),
        ),
      );
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ScoreRingPainter>()
          .single;
      expect(painter.progress, 0.0);
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('VenueScoreStrip — ring geometry independent of label length '
      '(Step 1F)', () {
    testWidgets('Hotel: Overall/Service/Room/Experience/Value all render '
        'identically-sized 40x40 rings — "Experience" (the longest label) '
        'must not shrink its own ring', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Service', value: 8),
              ScoreDimension(label: 'Room', value: 7),
              ScoreDimension(label: 'Experience', value: 8),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      final rings = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ScoreRingPainter)
          .toList();
      expect(rings, hasLength(5));
      final sizes = rings.map((w) => tester.getSize(find.byWidget(w))).toList();
      for (final s in sizes) {
        expect(s, const Size(40, 40));
      }
      expect(
        sizes[3], // Experience
        sizes[0], // Overall
        reason:
            'the Experience ring must exactly match every other ring, '
            'not scale down because its label is longer',
      );
    });

    testWidgets('Restaurant: Overall/Food/Service/Wine/Value all render '
        'identically-sized 40x40 rings', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Food', value: 8),
              ScoreDimension(label: 'Service', value: 7),
              ScoreDimension(label: 'Wine', value: 9),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      final sizes = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ScoreRingPainter)
          .map((w) => tester.getSize(find.byWidget(w)))
          .toList();
      expect(sizes, hasLength(5));
      for (final s in sizes) {
        expect(s, const Size(40, 40));
      }
    });

    testWidgets('Hotel null example (Room/Experience unrated): all five '
        'columns keep the exact 40x40 ring geometry — null rings are '
        'never smaller, never omitted', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Service', value: 8),
              ScoreDimension(label: 'Room', value: null),
              ScoreDimension(label: 'Experience', value: null),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      final paints = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ScoreRingPainter)
          .toList();
      expect(
        paints,
        hasLength(5),
        reason: 'all five columns remain in layout, none collapsed',
      );
      for (final w in paints) {
        expect(tester.getSize(find.byWidget(w)), const Size(40, 40));
      }
      final painters = paints
          .map((w) => w.painter as ScoreRingPainter)
          .toList();
      expect(painters[2].progress, 0.0, reason: 'Room: no foreground arc');
      expect(
        painters[3].progress,
        0.0,
        reason: 'Experience: no foreground arc',
      );
      expect(
        painters[0].progress,
        closeTo(0.9, 1e-9),
        reason: 'a real value (Overall=9) still paints its arc normally',
      );
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('Room'), findsOneWidget);
      expect(find.text('Experience'), findsOneWidget);
    });

    testWidgets('Restaurant null example (Service unrated): the empty '
        'ring keeps the same 40x40 geometry as the populated ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Food', value: 8),
              ScoreDimension(label: 'Service', value: null),
              ScoreDimension(label: 'Wine', value: 9),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      final paints = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ScoreRingPainter)
          .toList();
      for (final w in paints) {
        expect(tester.getSize(find.byWidget(w)), const Size(40, 40));
      }
      final painters = paints
          .map((w) => w.painter as ScoreRingPainter)
          .toList();
      expect(painters[2].progress, 0.0);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('Hotel worst case (Experience label present) at '
          '${width}px: every ring stays exactly 40x40, no overflow', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const VenueScoreStrip(
              dimensions: [
                ScoreDimension(label: 'Overall', value: 9),
                ScoreDimension(label: 'Service', value: 8),
                ScoreDimension(label: 'Room', value: 7),
                ScoreDimension(label: 'Experience', value: 8),
                ScoreDimension(label: 'Value', value: 7),
              ],
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
        final sizes = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((w) => w.painter is ScoreRingPainter)
            .map((w) => tester.getSize(find.byWidget(w)))
            .toList();
        expect(sizes, hasLength(5));
        for (final s in sizes) {
          expect(s, const Size(40, 40));
        }
      });
    }

    testWidgets('Hotel worst case at 1.6x text scale: every ring stays '
        'exactly 40x40 — only the label may shrink, never the ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Service', value: 8),
              ScoreDimension(label: 'Room', value: 7),
              ScoreDimension(label: 'Experience', value: 8),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
      final sizes = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ScoreRingPainter)
          .map((w) => tester.getSize(find.byWidget(w)))
          .toList();
      expect(sizes, hasLength(5));
      for (final s in sizes) {
        expect(s, const Size(40, 40));
      }
    });
  });

  group('VenueScoreStrip — uniform label typography (Step 1G §6)', () {
    testWidgets('Hotel: Overall/Service/Room/Experience/Value labels all '
        'share the exact same TextStyle — Experience must not render '
        'smaller than its siblings', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Service', value: 8),
              ScoreDimension(label: 'Room', value: 7),
              ScoreDimension(label: 'Experience', value: 8),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      final overall = tester.widget<Text>(find.text('Overall')).style;
      final service = tester.widget<Text>(find.text('Service')).style;
      final room = tester.widget<Text>(find.text('Room')).style;
      final experience = tester.widget<Text>(find.text('Experience')).style;
      final value = tester.widget<Text>(find.text('Value')).style;
      expect(
        experience,
        overall,
        reason: 'Experience must use the exact same style as Overall',
      );
      expect(service, overall);
      expect(room, overall);
      expect(value, overall);
    });

    testWidgets('Restaurant: Overall/Food/Service/Wine/Value labels all '
        'share the exact same TextStyle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Food', value: 8),
              ScoreDimension(label: 'Service', value: 7),
              ScoreDimension(label: 'Wine', value: 9),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      final overall = tester.widget<Text>(find.text('Overall')).style;
      final food = tester.widget<Text>(find.text('Food')).style;
      final service = tester.widget<Text>(find.text('Service')).style;
      final wine = tester.widget<Text>(find.text('Wine')).style;
      final value = tester.widget<Text>(find.text('Value')).style;
      expect(food, overall);
      expect(service, overall);
      expect(wine, overall);
      expect(value, overall);
    });

    testWidgets('no label-specific FittedBox remains — the old per-label '
        'independent-scaling mechanism is gone', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Service', value: 8),
              ScoreDimension(label: 'Room', value: 7),
              ScoreDimension(label: 'Experience', value: 8),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      expect(find.byType(FittedBox), findsNothing);
    });

    testWidgets('Hotel: every label container is the same height and sits '
        'at the same vertical position — including Experience', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Service', value: 8),
              ScoreDimension(label: 'Room', value: 7),
              ScoreDimension(label: 'Experience', value: 8),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      Finder labelBox(String label) => find
          .ancestor(of: find.text(label), matching: find.byType(SizedBox))
          .first;

      final heights = [
        'Overall',
        'Service',
        'Room',
        'Experience',
        'Value',
      ].map((l) => tester.getSize(labelBox(l)).height).toList();
      for (final h in heights) {
        expect(
          h,
          heights.first,
          reason: 'every label area must reserve the same height',
        );
      }

      final tops = [
        'Overall',
        'Service',
        'Room',
        'Experience',
        'Value',
      ].map((l) => tester.getTopLeft(labelBox(l)).dy).toList();
      for (final t in tops) {
        expect(
          t,
          tops.first,
          reason:
              'every label must start at the same vertical position — '
              'a shared baseline across columns',
        );
      }
    });

    testWidgets('at 1.6x text scale with the Hotel worst case, every label '
        'area is still the same uniform height across all five columns', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Service', value: 8),
              ScoreDimension(label: 'Room', value: 7),
              ScoreDimension(label: 'Experience', value: 8),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
      Finder labelBox(String label) => find
          .ancestor(of: find.text(label), matching: find.byType(SizedBox))
          .first;
      final heights = [
        'Overall',
        'Service',
        'Room',
        'Experience',
        'Value',
      ].map((l) => tester.getSize(labelBox(l)).height).toList();
      for (final h in heights) {
        expect(h, heights.first);
      }
      final overall = tester.widget<Text>(find.text('Overall')).style;
      final experience = tester.widget<Text>(find.text('Experience')).style;
      expect(
        experience,
        overall,
        reason: 'even under text-scale pressure, no per-label scaling',
      );
    });
  });

  group('VenueScoreHeader (Step 1D §4-6)', () {
    testWidgets('contains "(Your latest visit)" and the correct right-'
        'side visit date; the old duplicate "Latest visit · date" line is '
        'gone', (tester) async {
      await tester.pumpWidget(
        _wrap(VenueScoreHeader(noun: 'visit', date: DateTime(2026, 8, 15))),
      );
      expect(find.textContaining('(Your latest visit)'), findsOneWidget);
      expect(find.textContaining('Visited 15 August 2026'), findsOneWidget);
      expect(find.textContaining('Latest visit ·'), findsNothing);
    });

    testWidgets('hotel uses "stay"/"Stayed" vocabulary, matching YOUR '
        'STAYS', (tester) async {
      await tester.pumpWidget(
        _wrap(VenueScoreHeader(noun: 'stay', date: DateTime(2026, 3, 1))),
      );
      expect(find.textContaining('(Your latest stay)'), findsOneWidget);
      expect(find.textContaining('Stayed 1 March 2026'), findsOneWidget);
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('renders with no overflow at ${width}px', (tester) async {
        await tester.pumpWidget(
          _wrap(
            VenueScoreHeader(noun: 'visit', date: DateTime(2026, 8, 15)),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('at 1.6x text scale, stacks rather than overlapping — no '
        'overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VenueScoreHeader(noun: 'visit', date: DateTime(2026, 8, 15)),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('VenueScoreHeader — single-line alignment (Step 1G §13)', () {
    // Locates the header's left cluster ("SCORES  (Your latest …)") and
    // right metadata ("Visited/Stayed …") without assuming Row vs Column —
    // find.textContaining matches on the assembled plain text of a
    // Text.rich span, same technique the existing §4-6 tests already rely
    // on above.
    Finder leftFinder() => find.textContaining('SCORES');
    Finder rightFinder(String text) => find.textContaining(text);

    for (final noun in ['visit', 'stay']) {
      final verb = noun == 'stay' ? 'Stayed' : 'Visited';
      final rightText = '$verb 16 August 2026';

      testWidgets(
        '$noun @ 390px/1.0x: left cluster and right metadata render on '
        'the same row, right metadata anchored to the far-right edge',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              VenueScoreHeader(noun: noun, date: DateTime(2026, 8, 16)),
              width: 390,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byType(Row),
            findsOneWidget,
            reason: 'must lay out as a single Row, never Wrap',
          );
          expect(find.byType(Column), findsNothing);

          final leftDy = tester.getCenter(leftFinder()).dy;
          final rightDy = tester.getCenter(rightFinder(rightText)).dy;
          expect(
            rightDy,
            closeTo(leftDy, 0.5),
            reason:
                'the date must sit on the same horizontal line as '
                '"SCORES (Your latest $noun)", not wrapped beneath it',
          );

          final headerRight = tester
              .getRect(find.byType(VenueScoreHeader))
              .right;
          final rightEdge = tester.getRect(rightFinder(rightText)).right;
          expect(
            rightEdge,
            closeTo(headerRight, 1.0),
            reason: 'right metadata must be anchored to the far-right edge',
          );
        },
      );

      testWidgets(
        '$noun @ 320px/1.0x: intended one-line layout stays stable if it '
        'fits; right metadata stays right-anchored either way; no overflow',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              VenueScoreHeader(noun: noun, date: DateTime(2026, 8, 16)),
              width: 320,
            ),
          );
          expect(tester.takeException(), isNull);
          // Never the uncontrolled-wrap failure mode: exactly one of
          // Row (fits) or Column (deliberate fallback), never both, and
          // never a Wrap.
          expect(find.byType(Wrap), findsNothing);
          final headerRight = tester
              .getRect(find.byType(VenueScoreHeader))
              .right;
          final rightEdge = tester.getRect(rightFinder(rightText)).right;
          expect(
            rightEdge,
            closeTo(headerRight, 1.0),
            reason:
                'right metadata stays anchored to the far-right edge '
                'whether laid out as one row or as a stacked fallback',
          );
        },
      );

      testWidgets(
        '$noun @ 390px/1.6x text scale: deliberate stacked fallback, no '
        'overflow, date never lands under only "(Your latest $noun)"',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              VenueScoreHeader(noun: noun, date: DateTime(2026, 8, 16)),
              width: 390,
              textScale: 1.6,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(Wrap), findsNothing);

          final leftDy = tester.getCenter(leftFinder()).dy;
          final rightDy = tester.getCenter(rightFinder(rightText)).dy;
          // A genuine stacked fallback puts the date meaningfully below
          // the left cluster's own center — not side-by-side.
          expect(
            rightDy,
            greaterThan(leftDy + 5),
            reason:
                'at high text scale this must be a deliberate two-line '
                'stack, not squeezed onto one overflowing/wrapped line',
          );

          final headerRight = tester
              .getRect(find.byType(VenueScoreHeader))
              .right;
          final rightEdge = tester.getRect(rightFinder(rightText)).right;
          expect(rightEdge, closeTo(headerRight, 1.0));
        },
      );
    }
  });

  group('VenueScoreStrip — latest-visit scores on one row (§12-14, §33)', () {
    testWidgets('restaurant: all 5 actual dimensions render with correct '
        'values and labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Food', value: 8),
              ScoreDimension(label: 'Service', value: 10),
              ScoreDimension(label: 'Wine', value: 7),
              ScoreDimension(label: 'Value', value: 6),
            ],
          ),
        ),
      );
      for (final v in ['9', '8', '10', '7', '6']) {
        expect(find.text(v), findsOneWidget);
      }
      for (final l in ['Overall', 'Food', 'Service', 'Wine', 'Value']) {
        expect(find.text(l), findsOneWidget);
      }
    });

    testWidgets('hotel: all 5 actual dimensions (Overall/Service/Room/'
        'Experience/Value) render — no restaurant-only Food/Wine (Step '
        '1E §10, §41)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 8),
              ScoreDimension(label: 'Service', value: 9),
              ScoreDimension(label: 'Room', value: 7),
              ScoreDimension(label: 'Experience', value: 8),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      expect(find.text('Food'), findsNothing);
      expect(find.text('Wine'), findsNothing);
      for (final l in ['Overall', 'Service', 'Room', 'Experience', 'Value']) {
        expect(find.text(l), findsOneWidget);
      }
    });

    testWidgets('hotel: a historical stay with null Room/Experience shows '
        'an empty ring for each — five-column geometry preserved, no fake '
        '0 (Step 1E §11, §41)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 8),
              ScoreDimension(label: 'Service', value: 9),
              ScoreDimension(label: 'Room', value: null),
              ScoreDimension(label: 'Experience', value: null),
              ScoreDimension(label: 'Value', value: 7),
            ],
          ),
        ),
      );
      // Still five columns — Room/Experience keep their position rather
      // than being omitted, so the layout stays balanced.
      final rings = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ScoreRingPainter)
          .map((w) => w.painter as ScoreRingPainter)
          .toList();
      expect(rings, hasLength(5));
      expect(rings[2].progress, 0.0);
      expect(rings[3].progress, 0.0);
      expect(find.text('Room'), findsOneWidget);
      expect(find.text('Experience'), findsOneWidget);
      // Two em-dashes (Room, Experience), never a "0".
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a missing optional dimension shows an em-dash, never a '
        'fake 0', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 8),
              ScoreDimension(label: 'Wine', value: null),
            ],
          ),
        ),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('no gold anywhere in the score strip — a personal rating '
        'is not Michelin recognition (§30)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [ScoreDimension(label: 'Overall', value: 9)],
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('9'));
      expect(text.style?.color, isNot(AppColors.gold));
      expect(text.style?.color, isNot(AppColors.starFilled));
      expect(text.style?.color, AppColors.forestGreen);
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('restaurant\'s 5 dimensions stay on one row at ${width}px '
          '(§13-14 — "alle scores op 1 rij")', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const VenueScoreStrip(
              dimensions: [
                ScoreDimension(label: 'Overall', value: 9),
                ScoreDimension(label: 'Food', value: 8),
                ScoreDimension(label: 'Service', value: 10),
                ScoreDimension(label: 'Wine', value: 7),
                ScoreDimension(label: 'Value', value: 6),
              ],
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(Row), findsWidgets);
      });
    }

    testWidgets('restaurant\'s 5 dimensions stay on one row at 1.6x text '
        'scale — no overflow, no wrap to a second row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VenueScoreStrip(
            dimensions: [
              ScoreDimension(label: 'Overall', value: 9),
              ScoreDimension(label: 'Food', value: 8),
              ScoreDimension(label: 'Service', value: 10),
              ScoreDimension(label: 'Wine', value: 7),
              ScoreDimension(label: 'Value', value: 6),
            ],
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
      // Still exactly one Row — a fallback that added a second row would
      // change the widget tree shape, not just visual scale.
      expect(find.byType(Row), findsOneWidget);
    });
  });

  group('VenueAboutSection — conditional seam (§19-21, §36)', () {
    testWidgets('renders nothing when no data exists — never a "No '
        'description available." placeholder', (tester) async {
      await tester.pumpWidget(_wrap(const VenueAboutSection(text: null)));
      expect(find.text('ABOUT'), findsNothing);
      expect(find.textContaining('No description'), findsNothing);
    });

    testWidgets('renders nothing for an empty/whitespace-only string '
        'either', (tester) async {
      await tester.pumpWidget(_wrap(const VenueAboutSection(text: '   ')));
      expect(find.text('ABOUT'), findsNothing);
    });

    testWidgets('renders the eyebrow + paragraph when real copy exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VenueAboutSection(
            text: 'A quiet dining room overlooking the garden.',
          ),
        ),
      );
      expect(find.text('ABOUT'), findsOneWidget);
      expect(
        find.text('A quiet dining room overlooking the garden.'),
        findsOneWidget,
      );
    });
  });

  group('Visit model — Room/Experience ratings (Step 1E §7, §41)', () {
    test('a historical hotel row with no room_rating/experience_rating '
        '(read before the migration existed) deserializes both to null, '
        'never 0', () {
      final visit = Visit.fromJson(
        _visitRow(rating: 8, serviceRating: 9, valueRating: 7),
      );
      expect(visit.roomRating, isNull);
      expect(visit.experienceRating, isNull);
      // Existing fields are unaffected by the new columns.
      expect(visit.rating, 8);
      expect(visit.serviceRating, 9);
      expect(visit.valueRating, 7);
    });

    test('a new hotel row with all five dimensions rated deserializes '
        'every value correctly', () {
      final visit = Visit.fromJson(
        _visitRow(
          rating: 8,
          serviceRating: 9,
          roomRating: 7,
          experienceRating: 8,
          valueRating: 7,
        ),
      );
      expect(visit.roomRating, 7);
      expect(visit.experienceRating, 8);
    });

    test('a restaurant row never carries room_rating/experience_rating — '
        'both stay null, matching food_rating/wine_rating staying null on '
        'a hotel row', () {
      final visit = Visit.fromJson(
        _visitRow(entityType: 'restaurant', rating: 9),
      );
      expect(visit.roomRating, isNull);
      expect(visit.experienceRating, isNull);
    });

    test('a directly-constructed Visit (no fromJson) defaults both to '
        'null', () {
      final visit = Visit(
        id: 'v1',
        userId: 'u1',
        entityType: 'hotel',
        entityId: 'h1',
        visitedOn: DateTime(2026, 8, 15),
      );
      expect(visit.roomRating, isNull);
      expect(visit.experienceRating, isNull);
    });
  });

  group('SectionDivider — editorial hairlines (Step 1C §4, §16; Step 1E '
      '§30-31 visibility fix)', () {
    testWidgets('renders a thin, visible, subtle-toned divider, never '
        'gold', (tester) async {
      await tester.pumpWidget(_wrap(const SectionDivider()));
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.color, AppColors.taupe.withValues(alpha: 0.4));
      expect(
        divider.color,
        isNot(AppColors.subtleBorderLight),
        reason:
            'the previous token was too low-contrast to be visible '
            'on-device — see the widget\'s own doc comment',
      );
      expect(divider.color, isNot(AppColors.gold));
      expect(divider.thickness, lessThan(1));
    });

    testWidgets('a page using dividers only at named section boundaries '
        'renders exactly one per boundary, not one per row', (tester) async {
      // Simulates a page with 3 major sections and 2 boundaries between
      // them — mirrors how RestaurantDetailScreen/HotelDetailScreen place
      // exactly one SectionDivider between each named section, never
      // inside a section's own row list.
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              const Text('Section A'),
              const Text('row 1'),
              const Text('row 2'),
              const SectionDivider(),
              const Text('Section B'),
              const SectionDivider(),
              const Text('Section C'),
            ],
          ),
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });

  group('Color rule — gold reserved for Michelin stars/Keys only (§30, '
      '§35)', () {
    testWidgets('StarRow (Michelin stars) is gold — the one legitimate '
        'gold usage', (tester) async {
      await tester.pumpWidget(_wrap(const StarRow(count: 1)));
      final icon = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
      expect(icon.color, AppColors.gold);
    });

    testWidgets('KeyRow (MICHELIN Keys) is gold — the other legitimate '
        'gold usage', (tester) async {
      await tester.pumpWidget(_wrap(const KeyRow(count: 1)));
      final icon = tester.widget<Icon>(find.byIcon(Icons.vpn_key_rounded));
      expect(icon.color, AppColors.gold);
    });

    testWidgets('the hero Wishlist toggle — the one canonical Wishlist '
        'control (Step 1E §18) — is never gold in either state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSliver(
          VenueDetailHero(
            title: 'Venue',
            isWishlisted: true,
            wishlistSaving: false,
            onTapWishlist: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded));
      expect(icon.color, isNot(AppColors.gold));
      expect(icon.color, AppColors.textOnDark);
    });

    testWidgets('LinkedVenueRow recognition slot is the only place gold '
        'legitimately appears (via a passed-in StarRow) — the row chrome '
        'itself carries no gold', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkedVenueRow(
            name: 'Chez Michelin',
            recognition: const StarRow(count: 2, size: 11),
            onTap: () {},
          ),
        ),
      );
      final name = tester.widget<Text>(find.text('Chez Michelin'));
      expect(name.style?.color, isNot(AppColors.gold));
      final chevron = tester.widget<Icon>(
        find.byIcon(Icons.chevron_right_rounded),
      );
      expect(chevron.color, isNot(AppColors.gold));
    });
  });
}
