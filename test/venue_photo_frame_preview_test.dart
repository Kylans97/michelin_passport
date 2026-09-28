// Proves VenuePhotoFramePreview uses the REAL numbers found in this
// feature's own investigation — never approximations. Each expectation
// below cites exactly where its number comes from.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:michelin_passport/features/profile/widgets/venue_photo_frame_preview.dart';

// A real, tiny, validly-encoded image — MemoryImage still decodes it
// asynchronously (unlike a NetworkImage, which this test can't use at
// all), so it must be genuine bytes, not arbitrary garbage, or image
// decoding itself throws independently of anything this test is
// actually checking.
final _testImageBytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 4, height: 4)),
);

Widget _wrap(String venueType) => MaterialApp(
  home: Scaffold(
    body: VenuePhotoFramePreview(
      image: MemoryImage(_testImageBytes),
      venueTypeWireValue: venueType,
    ),
  ),
);

void main() {
  group('VenuePhotoFramePreview — restaurant/hotel (unwired today, no deliberate '
      'alignment exists yet — center is the honest neutral default)', () {
    testWidgets('header is a fixed 300px height (VenueDetailHero.expandedHeight), '
        'center alignment', (tester) async {
      await tester.pumpWidget(_wrap('restaurant'));
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(sizedBoxes.any((b) => b.height == 300), isTrue);

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.first.alignment, Alignment.center);
    });

    testWidgets('card is a 1:1 square (VenueThumbnail\'s own default)', (tester) async {
      await tester.pumpWidget(_wrap('hotel'));
      final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatios.first.aspectRatio, 1.0);
    });
  });

  group('VenuePhotoFramePreview — private chef (wired, deliberate alignments)', () {
    testWidgets('header is a fixed 320px height (PrivateChefHero.expandedHeight), '
        'Alignment(0, -0.8) — PrivateChefHero/_HeroImage\'s own top-biased crop', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap('private_chef'));
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(sizedBoxes.any((b) => b.height == 320), isTrue);

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.first.alignment, const Alignment(0, -0.8));
    });

    testWidgets('card is 4:5 portrait, Alignment(0, -0.3) — PrivateChefDiscoveryCard/'
        '_ChefCoverPhoto\'s own values', (tester) async {
      await tester.pumpWidget(_wrap('private_chef'));
      final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatios.first.aspectRatio, 4 / 5);

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.last.alignment, const Alignment(0, -0.3));
    });
  });

  group('VenuePhotoFramePreview — labels', () {
    testWidgets('labels both frames so it\'s unambiguous which shape is which', (tester) async {
      await tester.pumpWidget(_wrap('restaurant'));
      expect(find.text('AS THE HEADER'), findsOneWidget);
      expect(find.text('AS A CARD'), findsOneWidget);
    });
  });
}
