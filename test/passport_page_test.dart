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
import 'package:michelin_passport/features/passport/utils/passport_stamp_style.dart';
import 'package:michelin_passport/features/passport/widgets/passport_cover.dart';
import 'package:michelin_passport/features/passport/widgets/passport_stamp_painters.dart';
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

/// The stamp page's size for a phone [screenWidth] points wide — the same
/// arithmetic PassportBookletView and PassportCollectionBody use (20pt
/// page margins, 92% of what's left, the cover's 270×410 shape).
Size _bookSizeFor(double screenWidth) {
  final width = ((screenWidth - 40) * 0.92).clamp(240.0, 480.0);
  return Size(
    width,
    width * PassportCoverFace.baseHeight / PassportCoverFace.baseWidth,
  );
}

/// A visit id whose stamp is dealt [variant] after [avoid].
String _idDealt(StampVariant variant, {StampVariant? avoid}) {
  for (var i = 0; ; i++) {
    if (pickStampVariant('deal-$i', avoid: avoid) == variant) return 'deal-$i';
  }
}

void main() {
  group('4 stamps per page never overlap', () {
    // 320 is the smallest supported iPhone; 240/480 are the booklet's own
    // clamp bounds either side of every real phone.
    const screenWidths = [262.0, 320.0, 375.0, 393.0, 430.0, 562.0];
    final footprints = <(String, Size, bool)>[
      for (final v in StampVariant.values)
        (v.name, stampVariantSize(v), v == StampVariant.roundSeal),
      ('verified', verifiedStampSize, false),
      ('next stamp', const Size(150, 150), true),
    ];

    for (final screen in screenWidths) {
      test('at a ${screen.toInt()}pt-wide screen, every design at every '
          'rotation stays inside its own cell, and the cells are disjoint', () {
        final book = _bookSizeFor(screen);
        // The stamp field: the page minus its 52pt header zone.
        final field = Size(book.width, book.height - 52);
        final cells = stampGridCells(field, bottomLeftReserve: 62);
        expect(cells, hasLength(4));
        for (var a = 0; a < cells.length; a++) {
          expect((Offset.zero & field).intersect(cells[a]), cells[a]);
          for (var b = a + 1; b < cells.length; b++) {
            final overlap = cells[a].intersect(cells[b]);
            expect(
              overlap.width <= 0 || overlap.height <= 0,
              isTrue,
              reason: 'cells $a and $b overlap',
            );
          }
        }
        for (final cell in cells) {
          for (final (name, size, round) in footprints) {
            for (final rotation in [-7.0, -3.5, 0.0, 3.0, 6.0]) {
              for (final jitter in const [
                Offset(-12, -12),
                Offset(12, 12),
                Offset(12, -12),
              ]) {
                final placement = stampPlacementIn(
                  cell,
                  size: size,
                  rotationDegrees: rotation,
                  jitter: jitter,
                  round: round,
                );
                expect(placement.scale, inInclusiveRange(0.0, 1.0));
                final bounds = rotatedStampBounds(
                  size * placement.scale,
                  rotation,
                  round: round,
                );
                final drawn = Rect.fromCenter(
                  center: placement.center,
                  width: bounds.width,
                  height: bounds.height,
                );
                expect(
                  cell.inflate(0.001).contains(drawn.topLeft) &&
                      cell.inflate(0.001).contains(drawn.bottomRight),
                  isTrue,
                  reason: '$name at $rotation° leaves its cell $cell: $drawn',
                );
              }
            }
          }
        }
      });
    }

    testWidgets('a full page at 320pt renders 4 different designs, each '
        'inside the page and none overlapping another', (tester) async {
      final ids = <String>[];
      StampVariant? previous;
      for (final v in [
        StampVariant.oval,
        StampVariant.lozenge,
        StampVariant.doubleFrame,
        StampVariant.shield,
      ]) {
        ids.add(_idDealt(v, avoid: previous));
        previous = v;
      }
      final book = _bookSizeFor(320);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PassportPage(
                slots: [for (final id in ids) FilledStampSlot(_item(id))],
                headerLabel: 'ENTRIES · RESTAURANTS',
                pageNumber: 1,
                year: 2026,
                countryNameByCode: const {},
                newStampIds: const {},
                onTapStamp: (_) {},
                onTapNextStamp: () {},
                size: book,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final page = tester.getRect(find.byType(PassportPage));
      final stamps = find.byType(PassportStampWidget);
      expect(stamps, findsNWidgets(4));
      final rects = [for (var i = 0; i < 4; i++) tester.getRect(stamps.at(i))];
      for (var a = 0; a < 4; a++) {
        expect(page.inflate(0.001).contains(rects[a].topLeft), isTrue);
        expect(page.inflate(0.001).contains(rects[a].bottomRight), isTrue);
        for (var b = a + 1; b < 4; b++) {
          final overlap = rects[a].intersect(rects[b]);
          expect(
            overlap.width <= 0 || overlap.height <= 0,
            isTrue,
            reason: 'stamps $a and $b overlap: ${rects[a]} / ${rects[b]}',
          );
        }
      }
    });
  });

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

  testWidgets('1 filled + next slot + 2 blanks: 1 stamp, exactly 1 next-stamp '
      'placeholder, no crash from the blank slots', (tester) async {
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
  });

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
