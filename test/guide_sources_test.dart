// Gault&Millau on Restaurant Detail and Award History: the stored profile
// URL is only linked when it is a real URL (GaultMillauAward.profileUrl),
// the hero shows the latest edition as a secondary badge, the utility row
// takes a fifth "Gault&Millau" action without overflowing, and Award
// History lists every edition.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/venue_guide_links.dart';
import 'package:michelin_passport/features/restaurants/widgets/gault_millau_history_section.dart';
import 'package:michelin_passport/features/restaurants/widgets/restaurant_hero.dart';
import 'package:michelin_passport/models/gault_millau_award.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';

GaultMillauAward _award({
  int guideYear = 2026,
  double? score,
  int? toqueCount,
  String? url,
  GaultMillauRecognitionType recognitionType =
      GaultMillauRecognitionType.scored,
  String? distinctionLabel,
}) => GaultMillauAward(
  restaurantId: 'r1',
  guideYear: guideYear,
  score: score,
  toqueCount: toqueCount,
  gaultMillauUrl: url,
  recognitionType: recognitionType,
  distinctionLabel: distinctionLabel,
);

Restaurant _restaurant({int? michelinStars = 3}) => Restaurant(
  id: 'r1',
  restaurantCode: 'rest_0037',
  name: 'De Librije',
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  isHallOfFame: false,
  cityName: 'Zwolle',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: 'Spinhuisplein 1',
  isInHotel: false,
);

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 800)),
    child: Scaffold(
      body: Material(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

Widget _wrapSliver(Widget sliver) => MaterialApp(
  home: Scaffold(body: CustomScrollView(slivers: [sliver])),
);

void main() {
  group('GaultMillauAward.profileUrl', () {
    test('a real https profile URL is returned unchanged', () {
      const url =
          'https://www.gault-millau.nl/en/restaurants/de-librije-zwolle';
      expect(_award(url: url).profileUrl, url);
    });

    test('the "not found" research placeholders read as no link', () {
      expect(_award(url: 'not found').profileUrl, isNull);
      expect(_award(url: "not found (guessed slug 404'd)").profileUrl, isNull);
    });

    test('null, blank, relative and non-web values read as no link', () {
      expect(_award().profileUrl, isNull);
      expect(_award(url: '   ').profileUrl, isNull);
      expect(_award(url: '/en/restaurants/x').profileUrl, isNull);
      expect(_award(url: 'mailto:info@example.com').profileUrl, isNull);
    });
  });

  group("worlds_50_best_url", () {
    const url =
        'https://www.the50.com/discovery/Establishments/Netherlands/Zwolle/De-Librije.html';

    test('restaurants and hotels read it from their _full view', () {
      expect(
        Restaurant.fromJson({
          'id': 'r1',
          'name': 'De Librije',
          'worlds_50_best_url': url,
        }).worlds50BestUrl,
        url,
      );
      expect(
        Hotel.fromJson({
          'id': 'h1',
          'name': 'Raffles',
          'worlds_50_best_url': 'https://www.the50.com/x.html',
        }).worlds50BestUrl,
        'https://www.the50.com/x.html',
      );
    });

    test('absent column (an older server) reads as no link', () {
      expect(
        Restaurant.fromJson({'id': 'r1', 'name': 'X'}).worlds50BestUrl,
        isNull,
      );
      expect(Hotel.fromJson({'id': 'h1', 'name': 'X'}).worlds50BestUrl, isNull);
    });
  });

  group('VenueGuideLinks — guide pages beside Award history', () {
    testWidgets('renders nothing when no guide page is known', (tester) async {
      const links = VenueGuideLinks();
      expect(links.hasAny, isFalse);
      await tester.pumpWidget(_wrap(links));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('only the guides with a real URL appear', (tester) async {
      await tester.pumpWidget(
        _wrap(VenueGuideLinks(onOpenMichelin: () {})),
      );
      expect(find.text('MICHELIN Guide'), findsOneWidget);
      expect(find.text("World's 50 Best"), findsNothing);
      expect(find.text('Gault&Millau'), findsNothing);
    });

    testWidgets('all three wrap without overflow at 320pt and each fires '
        'only its own callback', (tester) async {
      var michelin = 0;
      var best = 0;
      var gm = 0;
      await tester.pumpWidget(
        _wrap(
          VenueGuideLinks(
            onOpenMichelin: () => michelin++,
            onOpenWorlds50Best: () => best++,
            onOpenGaultMillau: () => gm++,
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text("World's 50 Best"));
      expect([michelin, best, gm], [0, 1, 0]);
      await tester.tap(find.text('Gault&Millau'));
      expect([michelin, best, gm], [0, 1, 1]);
      await tester.tap(find.text('MICHELIN Guide'));
      expect([michelin, best, gm], [1, 1, 1]);
    });

    testWidgets('forest-green, never gold', (tester) async {
      await tester.pumpWidget(
        _wrap(VenueGuideLinks(onOpenGaultMillau: () {})),
      );
      final label = tester.widget<Text>(find.text('Gault&Millau'));
      expect(label.style?.color, AppColors.forestGreen);
      final icon = tester.widget<Icon>(find.byIcon(Icons.north_east_rounded));
      expect(icon.color, AppColors.forestGreen);
    });
  });

  group('RestaurantHero — Gault&Millau badge', () {
    testWidgets('shows the latest edition beside the stars', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          RestaurantHero(
            restaurant: _restaurant(),
            hasHotelBadge: false,
            isWishlisted: false,
            wishlistSaving: false,
            onTapWishlist: () {},
            gaultMillauAward: _award(score: 19.5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gault&Millau · 19.5/20'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    });

    testWidgets('no award, or one with nothing publishable: no badge', (
      tester,
    ) async {
      for (final award in [null, _award()]) {
        await tester.pumpWidget(
          _wrapSliver(
            RestaurantHero(
              restaurant: _restaurant(),
              hasHotelBadge: false,
              isWishlisted: false,
              wishlistSaving: false,
              onTapWishlist: () {},
              gaultMillauAward: award,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Gault&Millau'), findsNothing);
      }
    });
  });

  group('GaultMillauHistorySection', () {
    testWidgets('one row per edition, in the order given', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GaultMillauHistorySection(
            awards: [
              _award(guideYear: 2026, score: 19.5),
              _award(guideYear: 2025, score: 19, toqueCount: 5),
              _award(
                guideYear: 2024,
                recognitionType: GaultMillauRecognitionType.unscoredTopTier,
                distinctionLabel: "Toques d'Or",
              ),
              _award(guideYear: 2023),
            ],
          ),
        ),
      );
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('19.5/20'), findsOneWidget);
      expect(find.text('19/20 · 5 Toques'), findsOneWidget);
      expect(find.text("Toques d'Or"), findsOneWidget);
      expect(find.text('Listed'), findsOneWidget);
      final years = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && RegExp(r'^\d{4}$').hasMatch(d))
          .toList();
      expect(years, ['2026', '2025', '2024', '2023']);
    });

    testWidgets('renders nothing for an empty list', (tester) async {
      await tester.pumpWidget(
        _wrap(const GaultMillauHistorySection(awards: [])),
      );
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });
}
