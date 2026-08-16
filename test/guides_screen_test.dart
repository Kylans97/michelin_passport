// Covers GuidesScreen (the Guides landing page, Step 2A). Safe to pump
// directly — like Passport/Explore, it has no Scaffold of its own and it
// constructs no repository and touches no Supabase itself, so it needs
// only a Scaffold ancestor for Material widgets (InkWell etc.) to resolve.
// As of Step 2D, ALL FIVE of its destinations (Michelin Restaurants/
// Hotels, Step 2B; World's 50 Best Restaurants/Hotels, Step 2C;
// Gault&Millau Restaurants, Step 2D) construct a repository against
// Supabase.instance.client eagerly in their own initState — see the note
// above the "destination routing" comment below for why none of them are
// tapped through to completion here anymore.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/guides_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

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

    testWidgets(
      'Step 1A: canvas is forest-green, GUIDES/back arrow are ivory, with '
      'three ivory family blocks visible on top of it',
      (tester) async {
        await tester.pumpWidget(_wrap(const GuidesScreen()));

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, AppColors.forestGreen);

        final title = tester.widget<Text>(find.text('GUIDES'));
        expect(title.style!.color, AppColors.ivory);

        final backIcon = tester.widget<Icon>(
          find.byIcon(Icons.arrow_back_ios_new_rounded),
        );
        expect(backIcon.color, AppColors.ivory);

        // One ivory-decorated Container per family block — Michelin,
        // World's 50 Best, Gault&Millau.
        final ivoryBlocks = tester
            .widgetList<Container>(find.byType(Container))
            .where((c) {
              final decoration = c.decoration;
              return decoration is BoxDecoration &&
                  decoration.color == AppColors.ivory;
            });
        expect(ivoryBlocks.length, 3);
      },
    );

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
      // 'Hotels' appears twice total (Michelin + World's 50 Best — G&M has
      // no Hotels destination); 'Restaurants' appears three times (all
      // three families) — the Gault&Millau-specific test below confirms
      // that count precisely.
      expect(find.text('Hotels'), findsNWidgets(2));
    });

    testWidgets('renders the Gault&Millau family with only a Restaurants '
        'destination — no Hotels', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      expect(find.text('GAULT&MILLAU'), findsOneWidget);
      expect(
        find.text('Distinctive restaurants recognised by Gault&Millau.'),
        findsOneWidget,
      );
      // 'Restaurants' now appears three times total (Michelin, World's 50
      // Best, Gault&Millau) — confirming the third family's destination is
      // actually present, not just its title.
      expect(find.text('Restaurants'), findsNWidgets(3));
    });

    testWidgets('shows no fake venue/ranking content', (tester) async {
      await tester.pumpWidget(_wrap(const GuidesScreen()));
      // No numbers, no venue names — only the five destination
      // label/descriptor pairs and the three family headers should be
      // present.
      expect(find.textContaining('#'), findsNothing);
      expect(find.textContaining('★'), findsNothing);
    });

    // Destination routing: as of Step 2C, none of the four destinations
    // (Michelin Restaurants/Hotels, World's 50 Best Restaurants/Hotels) can
    // be tapped through to completion here — every one of them now
    // constructs a repository against Supabase.instance.client eagerly in
    // its own initState (to load its real catalogue), so, like
    // ExploreScreen (which has never had a screen-level widget test for the
    // same reason), actually completing that navigation isn't safe without
    // a live Supabase session. GuidesScreen._open() itself is a single,
    // trivial private helper (`Navigator.push(MaterialPageRoute(builder:
    // (_) => screen))`) shared by all four destinations and unchanged since
    // Step 2A — its correctness for each destination was confirmed via
    // physical-device review instead (Michelin: Step 2B report; World's 50
    // Best: Step 2C report).

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
            child: const GuidesScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
