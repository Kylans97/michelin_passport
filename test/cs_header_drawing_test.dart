import 'dart:ui' show PictureRecorder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/cs_header_drawing.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/core/widgets/venue_thumbnail.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/journey.dart';

// One id per scene, found by walking ids through every pool — so the
// paint test below covers all fifteen scenes, mirrored or not.
Map<HeaderDrawingScene, HeaderDrawing> _onePerScene() {
  final found = <HeaderDrawingScene, HeaderDrawing>{};
  for (var i = 0; found.length < HeaderDrawingScene.values.length; i++) {
    for (final d in [
      HeaderDrawing.restaurant('r-$i'),
      HeaderDrawing.hotel('h-$i'),
      HeaderDrawing.privateChef('c-$i'),
      HeaderDrawing.event('e-$i', EventType.other),
      HeaderDrawing.vineyard('v-$i'),
      HeaderDrawing.journey('j-$i', JourneyKind.train),
      HeaderDrawing.journey('j-$i', JourneyKind.ship),
      HeaderDrawing.journey(
        'j-$i',
        JourneyKind.ship,
        shipType: 'sailing_yacht',
      ),
    ]) {
      found.putIfAbsent(d.resolve().scene, () => d);
    }
  }
  return found;
}

void main() {
  group('HeaderDrawing', () {
    test(
      'the seed hash is fixed, so an id keeps its picture across releases',
      () {
        // Changing the hash would silently redraw every photo-less card.
        // Pinned values (FNV-1a + MurmurHash3 finaliser, computed
        // 2026-11-20).
        expect(HeaderDrawing.hashSeed(''), 2872998923);
        expect(
          HeaderDrawing.hashSeed('9b2f7c1e-0000-4000-8000-000000000001'),
          3885344675,
        );
        expect(HeaderDrawing.hashSeed('a'), isNot(HeaderDrawing.hashSeed('b')));
      },
    );

    test('the same id always resolves to the same variant', () {
      for (var i = 0; i < 50; i++) {
        final a = HeaderDrawing.hotel('hotel-$i').resolve();
        final b = HeaderDrawing.hotel('hotel-$i').resolve();
        expect(a, b);
      }
    });

    test('each subject draws only from its own scenes', () {
      const restaurant = {
        HeaderDrawingScene.tableSetting,
        HeaderDrawingScene.kitchenPass,
        HeaderDrawingScene.archedRoom,
      };
      const hotel = {
        HeaderDrawingScene.facade,
        HeaderDrawingScene.gardenAllee,
        HeaderDrawingScene.frontDoor,
      };
      const chef = {HeaderDrawingScene.chefBoard, HeaderDrawingScene.chefTable};
      final seenRestaurant = <HeaderDrawingScene>{};
      final seenHotel = <HeaderDrawingScene>{};
      final seenChef = <HeaderDrawingScene>{};
      for (var i = 0; i < 200; i++) {
        seenRestaurant.add(HeaderDrawing.restaurant('$i').resolve().scene);
        seenHotel.add(HeaderDrawing.hotel('$i').resolve().scene);
        seenChef.add(HeaderDrawing.privateChef('$i').resolve().scene);
      }
      // Every drawing is used — the point is that lists alternate.
      expect(seenRestaurant, restaurant);
      expect(seenHotel, hotel);
      expect(seenChef, chef);
    });

    test('wine estates alternate between all three scenes', () {
      final seen = {
        for (var i = 0; i < 100; i++)
          HeaderDrawing.vineyard('$i').resolve().scene,
      };
      expect(seen, {
        HeaderDrawingScene.vineyardRows,
        HeaderDrawingScene.vineyardHouse,
        HeaderDrawingScene.vineyardCellar,
      });
    });

    test('a journey is drawn as its kind, with some windows lit', () {
      for (var i = 0; i < 50; i++) {
        final train = HeaderDrawing.journey('$i', JourneyKind.train).resolve();
        final ship = HeaderDrawing.journey('$i', JourneyKind.ship).resolve();
        expect(train.scene, HeaderDrawingScene.train);
        expect(ship.scene, HeaderDrawingScene.ship);
        expect(train.litWindows.length, inInclusiveRange(1, 4));
        expect(ship.litWindows.length, inInclusiveRange(1, 4));
      }
    });

    test('a sailing yacht gets sails; other ship types keep the ship', () {
      for (var i = 0; i < 20; i++) {
        expect(
          HeaderDrawing.journey(
            '$i',
            JourneyKind.ship,
            shipType: 'sailing_yacht',
          ).resolve().scene,
          HeaderDrawingScene.sailingYacht,
        );
        for (final type in const [null, 'river', 'expedition', 'yacht']) {
          expect(
            HeaderDrawing.journey(
              '$i',
              JourneyKind.ship,
              shipType: type,
            ).resolve().scene,
            HeaderDrawingScene.ship,
          );
        }
      }
    });

    test('an event is drawn by its type', () {
      for (var i = 0; i < 50; i++) {
        expect(
          HeaderDrawing.event('$i', EventType.gala).resolve().scene,
          HeaderDrawingScene.gala,
        );
        expect(
          HeaderDrawing.event('$i', EventType.dinner).resolve().scene,
          isIn(const [
            HeaderDrawingScene.dinner,
            HeaderDrawingScene.tableSetting,
            HeaderDrawingScene.kitchenPass,
            HeaderDrawingScene.archedRoom,
          ]),
        );
      }
    });

    test('scenes whose mirror image would be wrong are never mirrored', () {
      for (var i = 0; i < 300; i++) {
        final v = HeaderDrawing.restaurant('$i').resolve();
        if (v.scene == HeaderDrawingScene.tableSetting) {
          expect(v.mirrored, isFalse);
        }
        final c = HeaderDrawing.privateChef('$i').resolve();
        if (c.scene == HeaderDrawingScene.chefBoard) {
          expect(c.mirrored, isFalse);
        }
      }
    });

    test('among hotels, only the façade has lit windows', () {
      for (var i = 0; i < 100; i++) {
        final v = HeaderDrawing.hotel('$i').resolve();
        if (v.scene == HeaderDrawingScene.facade) {
          expect(v.litWindows.length, inInclusiveRange(1, 4));
        } else {
          expect(v.litWindows, isEmpty);
        }
      }
    });
  });

  testWidgets('every scene paints at hero, card and thumbnail size', (
    tester,
  ) async {
    final scenes = _onePerScene();
    expect(scenes.keys.toSet(), HeaderDrawingScene.values.toSet());
    for (final size in const [
      Size(390, 300),
      Size(214, 120),
      Size(96, 72),
      Size(56, 56),
    ]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final d in scenes.values)
                CsHeaderDrawing(
                  drawing: d,
                  width: size.width,
                  height: size.height,
                ),
              CsHeaderDrawing(
                drawing: scenes.values.first,
                width: size.width,
                height: size.height,
                muted: true,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CsHeaderDrawing).first), size);
    }
  });

  testWidgets('a hero drawing clears the status bar and toolbar', (
    tester,
  ) async {
    final scenes = _onePerScene();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 62)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final d in scenes.values)
                CsHeaderDrawing(
                  drawing: d,
                  width: 40.2,
                  height: 36,
                  belowToolbar: true,
                ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(CsHeaderDrawing).first,
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as HeaderDrawingPainter;
    expect(painter.topInset, 62 + kToolbarHeight);
  });

  testWidgets('VenueThumbnail shows the drawing when given one', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            VenueThumbnail(
              imageUrl: null,
              drawing: HeaderDrawing.restaurant('r-1'),
            ),
            VenueThumbnail(imageUrl: null),
          ],
        ),
      ),
    );
    expect(find.byType(CsHeaderDrawing), findsOneWidget);
    expect(find.byType(CsImagePlaceholder), findsOneWidget);
  });

  test('a hero text band repaints, and every scene paints with it', () {
    final variant = const HeaderDrawing.restaurant('r1').resolve();
    expect(
      HeaderDrawingPainter(
        variant,
        topInset: 115,
      ).shouldRepaint(
        HeaderDrawingPainter(variant, topInset: 115, bottomInset: 120),
      ),
      isTrue,
    );
    for (var i = 0; i < 30; i++) {
      for (final drawing in [
        HeaderDrawing.restaurant('r$i'),
        HeaderDrawing.vineyard('v$i'),
        HeaderDrawing.journey('j$i', JourneyKind.ship),
      ]) {
        final recorder = PictureRecorder();
        HeaderDrawingPainter(
          drawing.resolve(),
          topInset: 115,
          bottomInset: CsHeaderDrawing.heroTextBand,
        ).paint(Canvas(recorder), const Size(402, 361));
        recorder.endRecording();
      }
    }
  });
}
