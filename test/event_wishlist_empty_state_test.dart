// EVENT WISHLIST V1: covers EventWishlistEmptyState — the restrained
// Events-tab empty state (no illustration, no giant CTA, no fake saved
// events).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/features/wishlist/widgets/event_wishlist_empty_state.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('EventWishlistEmptyState', () {
    testWidgets('shows the exact restrained copy, and the small branded '
        'monogram — never a large illustration', (tester) async {
      await tester.pumpWidget(_wrap(const EventWishlistEmptyState()));
      expect(find.text('No saved events yet.'), findsOneWidget);
      expect(
        find.text('Events you want to experience will appear here.'),
        findsOneWidget,
      );
      final placeholder = tester.widget<CsImagePlaceholder>(
        find.byType(CsImagePlaceholder),
      );
      expect(placeholder.width, lessThanOrEqualTo(64));
      expect(tester.takeException(), isNull);
    });

    testWidgets('onExplore omitted renders no "Explore events" link', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const EventWishlistEmptyState()));
      expect(find.textContaining('Explore events'), findsNothing);
    });

    testWidgets('onExplore provided renders the subtle link and fires on '
        'tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(EventWishlistEmptyState(onExplore: () => tapped = true)),
      );
      expect(find.text('Explore events →'), findsOneWidget);
      await tester.tap(find.text('Explore events →'));
      expect(tapped, isTrue);
    });

    testWidgets('never renders a large CTA button', (tester) async {
      await tester.pumpWidget(
        _wrap(EventWishlistEmptyState(onExplore: () {})),
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
