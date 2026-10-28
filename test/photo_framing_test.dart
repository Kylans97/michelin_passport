// Covers PhotoFraming (20261014120000): parsing from the published-photo
// rows and the full views' cover_ columns, clamping, the alignment it
// renders at, and the private-chef defaults that keep every chef photo
// nobody has framed exactly where it was before.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/photo_framing.dart';

void main() {
  group('PhotoFraming.fromJson', () {
    test('reads focus_x/focus_y/zoom', () {
      final f = PhotoFraming.fromJson({
        'focus_x': 0.3,
        'focus_y': 0.2,
        'zoom': 1.8,
      });
      expect(f, const PhotoFraming(focusX: 0.3, focusY: 0.2, zoom: 1.8));
    });

    test('reads the cover_ columns with a prefix', () {
      final f = PhotoFraming.fromJson({
        'cover_focus_x': 0.7,
        'cover_focus_y': 0.25,
        'cover_zoom': 2.5,
      }, prefix: 'cover_');
      expect(f, const PhotoFraming(focusX: 0.7, focusY: 0.25, zoom: 2.5));
    });

    test('a row without the columns (or a venue with no cover) is centred', () {
      expect(PhotoFraming.fromJson(const {}), PhotoFraming.center);
      expect(
        PhotoFraming.fromJson({
          'cover_focus_x': null,
          'cover_focus_y': null,
          'cover_zoom': null,
        }, prefix: 'cover_'),
        PhotoFraming.center,
      );
    });

    test('integers from the numeric column parse too', () {
      expect(
        PhotoFraming.fromJson({'focus_x': 1, 'focus_y': 0, 'zoom': 2}),
        const PhotoFraming(focusX: 1, focusY: 0, zoom: 2),
      );
    });

    test('out-of-range values are clamped, never rendered past the edge', () {
      final f = PhotoFraming.fromJson({
        'focus_x': 1.4,
        'focus_y': -0.2,
        'zoom': 9,
      });
      expect(f, const PhotoFraming(focusX: 1, focusY: 0, zoom: 4));
    });
  });

  test('alignment maps 0..1 onto -1..1, centre at the middle', () {
    expect(PhotoFraming.center.alignment, Alignment.center);
    expect(
      const PhotoFraming(focusX: 0, focusY: 1).alignment,
      Alignment.bottomLeft,
    );
    expect(
      const PhotoFraming(focusX: 0.75, focusY: 0.25).alignment,
      const Alignment(0.5, -0.5),
    );
  });

  test('copyWith clamps zoom to 1..4', () {
    expect(PhotoFraming.center.copyWith(zoom: 0.5).zoom, 1);
    expect(PhotoFraming.center.copyWith(zoom: 6).zoom, 4);
  });

  group('private chef defaults', () {
    test('an untouched chef photo keeps the old hero and card placements', () {
      // The old PrivateChefHero Alignment(0, -0.8) and _ChefCoverPhoto
      // Alignment(0, -0.3).
      expect(PhotoFraming.center.forChef.alignment.y, closeTo(-0.8, 1e-9));
      expect(PhotoFraming.center.forChefCard.alignment.y, closeTo(-0.3, 1e-9));
    });

    test('a framed chef photo is shown exactly as framed, in both', () {
      const framed = PhotoFraming(focusX: 0.4, focusY: 0.6, zoom: 1.5);
      expect(framed.forChef, framed);
      expect(framed.forChefCard, framed);
    });

    test(
      'leaving a chef photo at the editor default stores it as untouched',
      () {
        expect(PhotoFraming.chefDefault.storedForChef, PhotoFraming.center);
        const framed = PhotoFraming(focusY: 0.3);
        expect(framed.storedForChef, framed);
      },
    );
  });
}
