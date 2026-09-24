// Renders every one of the 5 stamp variants in every one of the 3 inks
// (15 combinations total) — the "preview/screenshot test for all 5
// variants in all 3 inks" the ink-stamp redesign spec asks for.
//
// Deliberately NOT a `matchesGoldenFile` pixel-diff suite: this repo has
// no prior golden-image test of any kind, and Cormorant Garamond/Inter
// are loaded at runtime via google_fonts — without a bundled-font test
// harness (which doesn't exist here yet either), golden PNGs captured in
// one environment are liable to mismatch in another purely from font
// substitution, which would make this suite flaky for reasons that have
// nothing to do with a real regression. What IS asserted, for all 15
// combinations, and additionally with a real long name ("8½ Otto e Mezzo
// Bombana") to specifically exercise every variant's own text-fitting
// path: it renders with no thrown exception (a painter indexing past a
// truncated string, a NaN from a zero-width measurement, etc. would
// surface here) and no layout overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/models/passport_stamp_item.dart';
import 'package:michelin_passport/features/passport/utils/passport_stamp_style.dart';
import 'package:michelin_passport/features/passport/widgets/passport_stamp.dart';
import 'package:michelin_passport/features/passport/widgets/passport_stamp_painters.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

RestaurantStampItem _stampItem({required String id, required String name}) =>
    RestaurantStampItem(
      restaurant: Restaurant(
        id: 'r-$id',
        restaurantCode: 'r-$id',
        name: name,
        michelinStars: 3,
        inclusionReason: 'michelin_star',
        cityName: 'Hong Kong',
        countryCode: 'HK',
        countryName: 'Hong Kong',
        flagEmoji: '🇭🇰',
        address: '1 Test Street',
      ),
      visit: Visit(
        id: id,
        userId: 'u1',
        entityType: 'restaurant',
        entityId: 'r-$id',
        visitedOn: DateTime(2026, 3, 12),
        starsAtVisit: 3,
      ),
    );

Future<void> _pumpStamp(
  WidgetTester tester, {
  required StampVariant variant,
  required StampInk ink,
  required PassportStampItem item,
}) async {
  final size = stampVariantSize(variant);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width + 40,
            height: size.height + 40,
            child: PassportStampWidget(
              item: item,
              variant: variant,
              ink: ink,
              rotationDegrees: -4,
              semanticLabel: 'test stamp',
              isNew: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final variant in StampVariant.values) {
    for (final ink in StampInk.values) {
      testWidgets('$variant in $ink renders with no exception/overflow', (
        tester,
      ) async {
        await _pumpStamp(
          tester,
          variant: variant,
          ink: ink,
          item: _stampItem(id: 'v-$variant-$ink', name: 'Flore'),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        '$variant in $ink fits a long name ("8½ Otto e Mezzo Bombana") '
        'with no exception/overflow',
        (tester) async {
          await _pumpStamp(
            tester,
            variant: variant,
            ink: ink,
            item: _stampItem(
              id: 'long-$variant-$ink',
              name: '8½ Otto e Mezzo Bombana',
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
