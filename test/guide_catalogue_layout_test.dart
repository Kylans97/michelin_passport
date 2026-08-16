// Covers GuideCatalogueLayout — the shared, presentation-only catalogue
// shell every Guides catalogue screen sits on. It never constructs a
// repository or touches Supabase itself (it only ever renders whatever
// [content] widget it's handed), which is exactly why it's still safely
// pumpable directly here even though, as of Step 2C, all four concrete
// catalogue screens (Michelin Restaurants/Hotels, World's 50 Best
// Restaurants/Hotels) are real and construct a repository against
// Supabase.instance.client eagerly in their own initState — none of them
// are pumped in this file (see the Step 2B report for why the Michelin
// pair was first removed from here, and the Step 2C report for the same
// reasoning applied to the World's 50 Best pair). Every screen's
// presentation pieces (GuideVenueCard,
// GuideCatalogueLoading/EmptyState/ErrorState, GuideRankMark,
// GuideYearSelector, the filter enums, the pure ranking/sort logic) are
// covered directly in their own test files instead; full functional
// verification happens via physical-device review.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/widgets/guide_catalogue_layout.dart';
import 'package:michelin_passport/features/guides/widgets/guide_venue_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('GuideCatalogueLayout', () {
    testWidgets('renders source, title and subtitle on the ivory canvas', (
      tester,
    ) async {
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
      expect(scaffold.backgroundColor, AppColors.ivory);
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

    testWidgets('shows a hairline between the header and content when '
        'content is present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GuideCatalogueLayout(
            source: 'MICHELIN GUIDE',
            title: 'Restaurants',
            content: Text('future filter/list content'),
          ),
        ),
      );
      expect(find.byType(GuideVenueCardDivider), findsOneWidget);
    });

    testWidgets('shows no hairline when there is no content to separate', (
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
      expect(find.byType(GuideVenueCardDivider), findsNothing);
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

    testWidgets('a self-scrolling content (e.g. a long result ListView) '
        'lays out without a RenderFlex overflow or nested-scroll error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideCatalogueLayout(
            source: 'MICHELIN GUIDE',
            title: 'Restaurants',
            subtitle:
                'Exceptional restaurants recognised by the Michelin '
                'Guide.',
            content: ListView.builder(
              itemCount: 200,
              itemBuilder: (context, index) =>
                  ListTile(title: Text('Place #$index')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // The header (fixed, non-scrolling) and the first list item are both
      // on screen at once — proof the content isn't nested inside the
      // header's own scroll view.
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Place #0'), findsOneWidget);

      // Scrolling the content must not move the header — only the content
      // owns scrolling, confirming there's exactly one scrollable, not two
      // competing ones.
      await tester.drag(find.text('Place #0'), const Offset(0, -3000));
      await tester.pump();
      expect(find.text('Restaurants'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
}
