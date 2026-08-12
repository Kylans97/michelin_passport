// Covers the "Trips" entry point WishlistScreen's AppBar upgrades to in
// Navigation Step 1 (an unlabelled icon button becomes a labelled one —
// PlannedTripsScreen itself was already reachable, only the affordance
// changed). WishlistScreen constructs repositories against
// Supabase.instance.client eagerly in initState, so — same established
// limitation as ExploreScreen/the Michelin/World's 50 Best guide screens —
// it can't be pumped directly without a live session. This reconstructs
// the exact button shape in isolation instead, mirroring
// explore_guides_entry_test.dart's approach for the equivalent Explore
// entry.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';

Widget _tripsButton(VoidCallback onPressed) => TextButton.icon(
  onPressed: onPressed,
  icon: const Icon(
    Icons.card_travel_rounded,
    color: AppColors.textSecondary,
    size: 18,
  ),
  label: Text(
    'Trips',
    style: GoogleFonts.inter(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  ),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Wishlist'),
      actions: [child],
    ),
  ),
);

void main() {
  group('Wishlist "Trips" entry', () {
    testWidgets('renders a labelled Trips button, not a bare icon', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(_tripsButton(() => tapped = true)));
      expect(find.text('Trips'), findsOneWidget);
      expect(find.byIcon(Icons.card_travel_rounded), findsOneWidget);
      await tester.tap(find.text('Trips'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px and 390px widths — no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(_wrap(_tripsButton(() {})));
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                title: const Text('Wishlist'),
                actions: [_tripsButton(() {})],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap target meets the 44px minimum', (tester) async {
      await tester.pumpWidget(_wrap(_tripsButton(() {})));
      final size = tester.getSize(find.byType(TextButton));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
