// Widget-level coverage for passport_page.dart: a page renders exactly one
// tappable stamp per FilledStampSlot, exactly one "Add your next stamp"
// placeholder for a NextStampSlot, and nothing observable for a
// BlankStampSlot — plus that tapping each wires to the right callback.
// The "how many PAGES for N visits" half of the ink-stamp redesign's
// "Done when: 1, 4, 5, 13 visits" acceptance case is covered at the pure
// data-structure level in passport_stamp_source_test.dart (paginateStamps
// IS what PassportPageView's page count comes from, unmodified) — this
// file covers what a single page actually renders from its slots.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/models/passport_stamp_item.dart';
import 'package:michelin_passport/features/passport/passport_stamp_source.dart';
import 'package:michelin_passport/features/passport/widgets/passport_stamp.dart';
import 'package:michelin_passport/features/passport/widgets/passport_page.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

RestaurantStampItem _item(String id) => RestaurantStampItem(
  restaurant: Restaurant(
    id: 'r-$id',
    restaurantCode: 'r-$id',
    name: 'Flore',
    michelinStars: 2,
    inclusionReason: 'michelin_star',
    cityName: 'Amsterdam',
    countryCode: 'NL',
    countryName: 'Netherlands',
    flagEmoji: '🇳🇱',
    address: '1 Prinsengracht',
  ),
  visit: Visit(
    id: id,
    userId: 'u1',
    entityType: 'restaurant',
    entityId: 'r-$id',
    visitedOn: DateTime(2026, 1, 15),
    starsAtVisit: 2,
  ),
);

Future<void> _pumpPage(
  WidgetTester tester, {
  required List<PassportStampSlot> slots,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PassportPage(
          slots: slots,
          headerLabel: 'ENTRIES · RESTAURANTS',
          pageNumber: 1,
          countryNameByCode: const {'NL': 'Netherlands'},
          newStampIds: const {},
          onTapStamp: (_) {},
          onTapNextStamp: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a full page of 4 filled slots renders 4 tappable stamps', (
    tester,
  ) async {
    final slots = [
      FilledStampSlot(_item('v0')),
      FilledStampSlot(_item('v1')),
      FilledStampSlot(_item('v2')),
      FilledStampSlot(_item('v3')),
    ];
    await _pumpPage(tester, slots: slots);
    expect(tester.takeException(), isNull);
    expect(find.byType(PassportStampWidget), findsNWidgets(4));
    expect(find.textContaining('your next'), findsNothing);
  });

  testWidgets(
    '1 filled + next slot + 2 blanks: 1 stamp, exactly 1 next-stamp '
    'placeholder, no crash from the blank slots',
    (tester) async {
      final slots = [
        FilledStampSlot(_item('v0')),
        const NextStampSlot(),
        const BlankStampSlot(),
        const BlankStampSlot(),
      ];
      await _pumpPage(tester, slots: slots);
      expect(tester.takeException(), isNull);
      expect(find.byType(PassportStampWidget), findsOneWidget);
      expect(find.textContaining('your next'), findsOneWidget);
    },
  );

  testWidgets('tapping a stamp calls onTapStamp with that exact item', (
    tester,
  ) async {
    PassportStampItem? tapped;
    final item = _item('v0');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassportPage(
            slots: [FilledStampSlot(item)],
            headerLabel: 'ENTRIES · RESTAURANTS',
            pageNumber: 1,
            countryNameByCode: const {},
            newStampIds: const {},
            onTapStamp: (i) => tapped = i,
            onTapNextStamp: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PassportStampWidget));
    await tester.pumpAndSettle();
    expect(tapped, same(item));
  });

  testWidgets('tapping the next-stamp placeholder calls onTapNextStamp', (
    tester,
  ) async {
    var tappedNext = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassportPage(
            slots: const [NextStampSlot()],
            headerLabel: 'ENTRIES · RESTAURANTS',
            pageNumber: 1,
            countryNameByCode: {},
            newStampIds: {},
            onTapStamp: (_) {},
            onTapNextStamp: () => tappedNext = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('your next'));
    await tester.pumpAndSettle();
    expect(tappedNext, isTrue);
  });

  testWidgets('the header shows the label and zero-padded page number', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassportPage(
            slots: const [],
            headerLabel: 'ENTRIES · RESTAURANTS',
            pageNumber: 3,
            countryNameByCode: const {},
            newStampIds: const {},
            onTapStamp: (_) {},
            onTapNextStamp: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ENTRIES · RESTAURANTS'), findsOneWidget);
    expect(find.text('p. 03'), findsOneWidget);
  });
}
