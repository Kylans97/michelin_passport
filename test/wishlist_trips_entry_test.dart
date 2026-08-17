// Covers the "Trips" entry point on Wishlist — Wishlist UI Consistency
// Step 1 moves it from a labelled AppBar action (dark canvas,
// AppColors.textSecondary) into a restrained SubtleTextAction sitting at
// the top of the ivory content area, right-aligned, matching the same
// "Label →" secondary-affordance language Restaurant/Hotel Detail already
// use ("Award history", "Plan visit" — see venue_detail_redesign_test.dart's
// own SubtleTextAction coverage). WishlistScreen constructs
// WishlistRepository against Supabase.instance.client eagerly in
// initState, so — same established limitation as ExploreScreen/the
// Michelin/World's 50 Best guide screens — it can't be pumped directly
// without a live session; this exercises the real SubtleTextAction widget
// with the exact wiring WishlistScreen uses instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/subtle_text_action.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('Wishlist "Trips" entry', () {
    testWidgets('renders a legible "Trips" label and fires its callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(SubtleTextAction(label: 'Trips', onTap: () => tapped = true)),
      );
      expect(find.text('Trips'), findsOneWidget);
      await tester.tap(find.byType(SubtleTextAction));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px and 390px widths — no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          _wrap(
            Align(
              child: SubtleTextAction(label: 'Trips', onTap: () {}),
            ),
          ),
        );
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
              backgroundColor: AppColors.ivory,
              body: Align(
                child: SubtleTextAction(label: 'Trips', onTap: () {}),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('never renders gold — Trips is a restrained forest-green '
        'secondary action, not a primary CTA', (tester) async {
      await tester.pumpWidget(
        _wrap(SubtleTextAction(label: 'Trips', onTap: () {})),
      );
      final label = tester.widget<Text>(find.text('Trips'));
      expect(label.style?.color, AppColors.forestGreen);
      expect(label.style?.color, isNot(AppColors.gold));
    });

    testWidgets('renders at a practical minimum tap target height — same '
        'established SubtleTextAction floor used elsewhere in the app', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(SubtleTextAction(label: 'Trips', onTap: () {})),
      );
      final size = tester.getSize(find.byType(SubtleTextAction));
      expect(size.height, greaterThanOrEqualTo(32));
    });
  });
}
