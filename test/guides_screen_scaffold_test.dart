// Covers the root cause behind TRIPS + GUIDES DEVICE-FIX PASS item 2: on
// device, GuidesScreen (reached via a direct Navigator.push from Explore's
// "Browse the Guides" row) landed in a brand new Overlay route with no
// Material ancestor above it anywhere — each pushed MaterialPageRoute is a
// sibling of the calling screen's own Scaffold in the Overlay stack, never
// a descendant of it. A bare ColoredBox root left every Text with no
// Material context, which is what produced the underline artifact under
// "GUIDES", its intro line and each family eyebrow (confirmed via an
// on-device A/B rebuild, not by grep). The fix is structural: GuidesScreen
// now supplies its own Scaffold, exactly like GuideCatalogueLayout already
// does for the catalogue result screens.
//
// GuidesScreen itself makes no Supabase calls in its own build() (only its
// onTap handlers push to screens that do), so — unlike PlannedTripsScreen/
// ExploreScreen/etc. — it can be pumped directly here without a live
// session.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/theme/app_theme.dart';
import 'package:michelin_passport/features/guides/guides_screen.dart';

void main() {
  group('GuidesScreen has its own Material ancestor', () {
    testWidgets(
      'supplies its own Scaffold even with no external Scaffold above it '
      '— the exact real navigation shape (a fresh pushed route, not a '
      'descendant of the calling screen\'s Scaffold)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.mantelier, home: const GuidesScreen()),
        );
        expect(find.byType(Scaffold), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text('GUIDES'),
            matching: find.byType(Scaffold),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders every family title and destination', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.mantelier, home: const GuidesScreen()),
      );
      expect(find.text('GUIDES'), findsOneWidget);
      expect(find.text('MICHELIN GUIDE'), findsOneWidget);
      expect(find.text("THE WORLD'S 50 BEST"), findsOneWidget);
      expect(find.text('GAULT&MILLAU'), findsOneWidget);
      expect(find.text('Restaurants'), findsNWidgets(3));
      expect(find.text('Hotels'), findsNWidgets(2));
    });
  });
}
