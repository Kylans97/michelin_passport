// Covers VenueTypeSelector's new [types] parameter — added so Wishlist can
// drop the "All" segment (see wishlist_default_venue_type_test.dart)
// without a second bespoke selector widget. Explore's own usage (no
// [types] passed) must keep behaving exactly as before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/explore/models/explore_filters.dart';
import 'package:michelin_passport/features/explore/widgets/venue_type_selector.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('defaults to all three segments when types is omitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        VenueTypeSelector(selected: ExploreVenueType.all, onSelect: (_) {}),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('Hotels'), findsOneWidget);
  });

  testWidgets('a restricted types list (Wishlist) never renders All', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        VenueTypeSelector(
          types: const [ExploreVenueType.restaurants, ExploreVenueType.hotels],
          selected: ExploreVenueType.restaurants,
          onSelect: (_) {},
        ),
      ),
    );

    expect(find.text('All'), findsNothing);
    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('Hotels'), findsOneWidget);
  });

  testWidgets('tapping a segment reports it back via onSelect', (tester) async {
    ExploreVenueType? tapped;
    await tester.pumpWidget(
      _wrap(
        VenueTypeSelector(
          types: const [ExploreVenueType.restaurants, ExploreVenueType.hotels],
          selected: ExploreVenueType.restaurants,
          onSelect: (v) => tapped = v,
        ),
      ),
    );

    await tester.tap(find.text('Hotels'));
    await tester.pump();

    expect(tapped, ExploreVenueType.hotels);
  });
}
