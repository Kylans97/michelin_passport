// Covers GuideCatalogueLayout (the shared, presentation-only catalogue
// shell) and the four concrete Step 2A catalogue screens. None of these
// construct a repository or touch Supabase — pumping them directly with
// no Supabase session initialized is exactly how that's verified: if any
// of them did eager Supabase work, these tests would throw.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/fifty_best_hotel_guide_screen.dart';
import 'package:michelin_passport/features/guides/fifty_best_restaurant_guide_screen.dart';
import 'package:michelin_passport/features/guides/michelin_hotel_guide_screen.dart';
import 'package:michelin_passport/features/guides/michelin_restaurant_guide_screen.dart';
import 'package:michelin_passport/features/guides/widgets/guide_catalogue_layout.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('GuideCatalogueLayout', () {
    testWidgets('renders source, title and subtitle on a deep-green '
        'canvas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GuideCatalogueLayout(
            source: 'MICHELIN GUIDE',
            title: 'Restaurants',
            subtitle: 'A subtitle.',
          ),
        ),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.deepGreen);
      expect(find.text('MICHELIN GUIDE'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('A subtitle.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('subtitle is optional', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GuideCatalogueLayout(source: 'MICHELIN GUIDE', title: 'Hotels'),
        ),
      );
      expect(find.text('Hotels'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('has a back affordance that pops the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GuideCatalogueLayout(
                        source: 'MICHELIN GUIDE',
                        title: 'Restaurants',
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Restaurants'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Restaurants'), findsNothing);
    });

    testWidgets('renders an optional content slot below the header', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GuideCatalogueLayout(
            source: 'MICHELIN GUIDE',
            title: 'Restaurants',
            content: Text('future filter/list content'),
          ),
        ),
      );
      expect(find.text('future filter/list content'), findsOneWidget);
    });

    testWidgets('content slot is absent (no fake content) when omitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GuideCatalogueLayout(
            source: 'MICHELIN GUIDE',
            title: 'Restaurants',
          ),
        ),
      );
      expect(find.textContaining('Coming soon'), findsNothing);
    });

    testWidgets('320px and 390px widths — no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          _wrap(
            const GuideCatalogueLayout(
              source: "THE WORLD'S 50 BEST",
              title: 'Restaurants',
              subtitle: 'The restaurants shaping global dining.',
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('short iPhone-like height (320x568) — no overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      await tester.pumpWidget(
        _wrap(
          const GuideCatalogueLayout(
            source: "THE WORLD'S 50 BEST",
            title: 'Hotels',
            subtitle: "The world's most remarkable stays.",
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: const GuideCatalogueLayout(
              source: "THE WORLD'S 50 BEST",
              title: 'Restaurants',
              subtitle: 'The restaurants shaping global dining.',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('The four Step 2A catalogue screens', () {
    testWidgets('MichelinRestaurantGuideScreen renders the right family/'
        'title, no data loading', (tester) async {
      await tester.pumpWidget(_wrap(const MichelinRestaurantGuideScreen()));
      expect(find.text('MICHELIN GUIDE'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MichelinHotelGuideScreen renders the right family/title, '
        'no data loading', (tester) async {
      await tester.pumpWidget(_wrap(const MichelinHotelGuideScreen()));
      expect(find.text('MICHELIN GUIDE'), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FiftyBestRestaurantGuideScreen renders the right family/'
        'title, no data loading', (tester) async {
      await tester.pumpWidget(_wrap(const FiftyBestRestaurantGuideScreen()));
      expect(find.text("THE WORLD'S 50 BEST"), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FiftyBestHotelGuideScreen renders the right family/title, '
        'no data loading', (tester) async {
      await tester.pumpWidget(_wrap(const FiftyBestHotelGuideScreen()));
      expect(find.text("THE WORLD'S 50 BEST"), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
