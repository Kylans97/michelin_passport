// Covers PhotoFramingEditor: the real frame sizes, that a drag moves the
// photo with the finger (the focus maths), the zoom slider, Reset, and
// that a private chef's untouched card preview matches what the card
// really shows.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:michelin_passport/features/profile/widgets/photo_framing_editor.dart';
import 'package:michelin_passport/models/photo_framing.dart';

// A real 400x200 image: wide, so in the 800x300 header frame it fills the
// width exactly (no horizontal slack at 1x) and overflows the height by
// 100px — enough to make the drag maths checkable by hand.
final _wideImage = MemoryImage(
  Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 200))),
);

// Decodes the image into the shared ImageCache BEFORE any widget (and so
// any google_fonts text) exists: real async work after that point would
// let google_fonts' font download start and fail. The editor then finds
// the decoded image already in the cache.
Future<void> _precache(WidgetTester tester) => tester.runAsync(() {
  final done = Completer<void>();
  final stream = _wideImage.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener((_, _) {
    stream.removeListener(listener);
    if (!done.isCompleted) done.complete();
  });
  stream.addListener(listener);
  return done.future;
});

Future<List<PhotoFraming>> _pump(
  WidgetTester tester, {
  String venueType = 'restaurant',
  PhotoFraming initial = PhotoFraming.center,
  PhotoFraming defaultFraming = PhotoFraming.center,
}) async {
  final changes = <PhotoFraming>[];
  await _precache(tester);
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PhotoFramingEditor(
            image: _wideImage,
            venueTypeWireValue: venueType,
            initial: initial,
            defaultFraming: defaultFraming,
            onChanged: changes.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return changes;
}

Finder get _headerFrame => find.bySemanticsLabel('Photo position and zoom');

void main() {
  testWidgets('restaurant: 300px header, 1:1 card', (tester) async {
    await _pump(tester);
    expect(
      tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .any((b) => b.height == 300),
      isTrue,
    );
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      1.0,
    );
    expect(find.text('AS THE HEADER'), findsOneWidget);
    expect(find.text('AS A CARD'), findsOneWidget);
  });

  testWidgets('private chef: 320px header, 4:5 card', (tester) async {
    await _pump(
      tester,
      venueType: 'private_chef',
      initial: PhotoFraming.chefDefault,
      defaultFraming: PhotoFraming.chefDefault,
    );
    expect(
      tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .any((b) => b.height == 320),
      isTrue,
    );
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      4 / 5,
    );
  });

  testWidgets('on a phone the header has the real hero\'s shape: full width '
      'x (300 + status bar), scaled to the page, with the covered strip '
      'shaded — even under an AppBar, which hides the status bar from '
      'MediaQuery', (tester) async {
    await _precache(tester);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(402, 1400)
      ..padding = const FakeViewPadding(top: 62);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Adjust framing')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PhotoFramingEditor(
              image: _wideImage,
              venueTypeWireValue: 'restaurant',
              initial: PhotoFraming.center,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    const scale = 362 / 402;
    final frame = tester.getSize(_headerFrame);
    expect(frame.width, 362);
    expect(frame.height, closeTo((300 + 62) * scale, 0.01));
    final strip = tester.getSize(find.byKey(const ValueKey('covered-strip')));
    expect(strip.height, closeTo((62 + kToolbarHeight) * scale, 0.01));
  });

  testWidgets('dragging the photo up 20px moves the focus down by 20/100', (
    tester,
  ) async {
    final changes = await _pump(tester);
    // 400x200 shown at 2x cover scale = 800x400 in an 800x300 frame:
    // 100px of vertical slack, none horizontal. The image top sits at
    // focusY * (300 - 400); dragging it up 20px needs focusY + 0.2.
    await tester.drag(
      _headerFrame,
      const Offset(15, -20),
      touchSlopY: 0,
      touchSlopX: 0,
    );
    await tester.pump();
    expect(changes, isNotEmpty);
    expect(changes.last.focusY, closeTo(0.7, 0.02));
    // No horizontal slack at 1x: a sideways drag changes nothing.
    expect(changes.last.focusX, 0.5);
  });

  testWidgets('dragging inside the frame is not taken by the page scroll', (
    tester,
  ) async {
    final changes = await _pump(tester);
    await tester.drag(_headerFrame, const Offset(0, 60));
    await tester.pump();
    expect(changes, isNotEmpty);
    expect(changes.last.focusY, lessThan(0.5));
  });

  testWidgets('the zoom slider zooms, and then sideways slack appears', (
    tester,
  ) async {
    final changes = await _pump(tester);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
    await tester.pump();
    expect(changes.last.zoom, 2);
    await tester.drag(
      _headerFrame,
      const Offset(-80, 0),
      touchSlopX: 0,
      touchSlopY: 0,
    );
    await tester.pump();
    // At 2x the image is 1600px wide in an 800px frame: 800px of slack,
    // so dragging it left 80px moves the focus right by 0.1.
    expect(changes.last.focusX, closeTo(0.6, 0.02));
  });

  testWidgets('Reset goes back to the default and is disabled there', (
    tester,
  ) async {
    final changes = await _pump(
      tester,
      initial: const PhotoFraming(focusY: 0.2, zoom: 2),
    );
    final reset = find.widgetWithText(TextButton, 'Reset');
    expect(tester.widget<TextButton>(reset).onPressed, isNotNull);
    await tester.tap(reset);
    await tester.pump();
    expect(changes.last, PhotoFraming.center);
    expect(tester.widget<TextButton>(reset).onPressed, isNull);
  });

  testWidgets('a chef photo left untouched previews as the card really shows '
      'it, not at the hero default', (tester) async {
    await _pump(
      tester,
      venueType: 'private_chef',
      initial: PhotoFraming.chefDefault,
      defaultFraming: PhotoFraming.chefDefault,
    );
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.first.alignment, PhotoFraming.chefDefault.alignment);
    expect(images.last.alignment, PhotoFraming.chefCardDefault.alignment);
  });
}
