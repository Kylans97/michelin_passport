// Covers GuidesScreen (the Guides landing page, Step 2A). Safe to pump
// directly — like Passport/Explore, it has no Scaffold of its own and,
// unlike those two, it also constructs no repository and touches no
// Supabase at all in this step, so it needs only a Scaffold ancestor for
// Material widgets (InkWell etc.) to resolve.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/fifty_best_hotel_guide_screen.dart';
import 'package:michelin_passport/features/guides/fifty_best_restaurant_guide_screen.dart';
import 'package:michelin_passport/features/guides/guides_screen.dart';
import 'package:michelin_passport/features/guides/michelin_hotel_guide_screen.dart';
import 'package:michelin_passport/features/guides/michelin_restaurant_guide_screen.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('GuidesScreen', () {
    testWidgets('renders the GUIDES header and proposition', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      expect(find.text('GUIDES'), findsOneWidget);
      expect(
        find.text(
          "Exceptional places, recognised by the world's leading guides.",
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the Michelin Guide family with Restaurants and '
        'Hotels destinations', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      expect(find.text('MICHELIN GUIDE'), findsOneWidget);
      // 'Restaurants'/'Hotels' each appear twice total (once per family) —
      // just confirming presence here, the World's 50 Best-specific test
      // below confirms the count precisely.
      expect(find.text('Restaurants'), findsWidgets);
      expect(find.text('Hotels'), findsWidgets);
    });

    testWidgets('renders the World\'s 50 Best family with Restaurants and '
        'Hotels destinations', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      expect(find.text("THE WORLD'S 50 BEST"), findsOneWidget);
      // 'Restaurants'/'Hotels' each appear twice — once per family.
      expect(find.text('Restaurants'), findsNWidgets(2));
      expect(find.text('Hotels'), findsNWidgets(2));
    });

    testWidgets('shows no Gault&Millau family', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      expect(find.textContaining('GAULT'), findsNothing);
      expect(find.textContaining('Millau'), findsNothing);
    });

    testWidgets('shows no fake venue/ranking content', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      // No numbers, no venue names — only the four destination
      // label/descriptor pairs and the two headers should be present.
      expect(find.textContaining('#'), findsNothing);
      expect(find.textContaining('★'), findsNothing);
    });

    testWidgets('tapping Michelin → Restaurants opens '
        'MichelinRestaurantGuideScreen', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      await tester.tap(find.text('Restaurants').first);
      await tester.pumpAndSettle();
      expect(find.byType(MichelinRestaurantGuideScreen), findsOneWidget);
    });

    testWidgets('tapping Michelin → Hotels opens MichelinHotelGuideScreen', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      await tester.tap(find.text('Hotels').first);
      await tester.pumpAndSettle();
      expect(find.byType(MichelinHotelGuideScreen), findsOneWidget);
    });

    testWidgets('tapping World\'s 50 Best → Restaurants opens '
        'FiftyBestRestaurantGuideScreen', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      await tester.tap(find.text('Restaurants').last);
      await tester.pumpAndSettle();
      expect(find.byType(FiftyBestRestaurantGuideScreen), findsOneWidget);
    });

    testWidgets('tapping World\'s 50 Best → Hotels opens '
        'FiftyBestHotelGuideScreen', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      await tester.tap(find.text('Hotels').last);
      await tester.pumpAndSettle();
      expect(find.byType(FiftyBestHotelGuideScreen), findsOneWidget);
    });

    testWidgets('320px and 390px widths — no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(_wrap(const GuidesScreen()));
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('short iPhone-like height (320x568) — no overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: const GuidesScreen(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
