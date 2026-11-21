// Guards that the text on a double frame, oval or lozenge stamp stays
// inside its border. The welcome flow's third sample stamp ("Four hands",
// Copenhagen, a dinner) once laid its name out on 2 lines at the largest
// size, which made the stack taller than the frame: the city sat on the
// top border and the date on the bottom one. The oval did the same with
// any short name that wraps, and the lozenge pushed its date over its
// banderole's lower rule. Every width was already capped, nothing
// capped the height, and the existing painter tests only asserted that
// painting didn't throw.
//
// Checked on the rendered pixels rather than on the painter's own
// numbers: between a stamp's two borders there is a thin band that
// nothing but text spilling across the border can ever put ink in. The
// ink grain only ever takes ink away, so the band of an intact stamp is
// white.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/models/passport_stamp_award.dart';
import 'package:michelin_passport/features/passport/utils/passport_stamp_style.dart';
import 'package:michelin_passport/features/passport/widgets/passport_stamp_painters.dart';

const _ratio = 2.0;

Future<ui.Image> _render(
  WidgetTester tester,
  StampVariant variant,
  StampPaintData data,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: CustomPaint(
              size: stampVariantSize(variant),
              painter: stampPainterFor(variant, data),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() => boundary.toImage(pixelRatio: _ratio)))!;
}

/// Whether a point (in stamp points) lies in the band between a stamp's
/// two borders, kept clear of each stroke by [_margin] for antialiasing.
typedef _InGap = bool Function(double x, double y);

const _margin = 0.75;

/// Double frame: outer 3pt stroke centred 3pt in (ends 4.5pt in), inner
/// 1.4pt stroke centred 8pt in (starts 7.3pt in).
bool _inDoubleFrameGap(double x, double y) {
  const w = DoubleFramePainter.width, h = DoubleFramePainter.height;
  final edge = [x, y, w - x, h - y].reduce((a, b) => a < b ? a : b);
  return edge > 4.5 + _margin && edge < 7.3 - _margin;
}

/// Oval: outer 1.5pt stroke on the oval 1.5pt in (ends 2.25pt in), inner
/// 1pt stroke on the oval 7.5pt in (starts 7pt in).
bool _inOvalGap(double x, double y) {
  const cx = OvalPainter.width / 2, cy = OvalPainter.height / 2;
  bool inside(double inset) {
    final dx = (x - cx) / (cx - inset), dy = (y - cy) / (cy - inset);
    return dx * dx + dy * dy <= 1;
  }

  return inside(2.25 + _margin) && !inside(7 - _margin);
}

/// Lozenge: the banderole's 1.4pt outer rule on the band's edge (ends
/// 0.7pt in), its 0.6pt inner rule 3pt in (starts 2.7pt in). The band is
/// [LozengePainter.width] - 4 wide and 50pt tall, centred.
bool _inLozengeBandGap(double x, double y) {
  const w = LozengePainter.width, h = LozengePainter.height;
  const left = 2.0, right = w - 2, top = (h - 50) / 2, bottom = (h + 50) / 2;
  if (x < left || x > right || y < top || y > bottom) return false;
  final edge = [
    x - left,
    y - top,
    right - x,
    bottom - y,
  ].reduce((a, b) => a < b ? a : b);
  return edge > 0.7 + _margin && edge < 2.7 - _margin;
}

Future<List<String>> _inkInGap(
  WidgetTester tester,
  ui.Image image,
  _InGap inGap,
) async {
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final found = <String>[];
  for (var py = 0; py < image.height; py++) {
    for (var px = 0; px < image.width; px++) {
      if (!inGap((px + 0.5) / _ratio, (py + 0.5) / _ratio)) continue;
      final i = (py * image.width + px) * 4;
      if (bytes.getUint8(i) < 200 ||
          bytes.getUint8(i + 1) < 200 ||
          bytes.getUint8(i + 2) < 200) {
        found.add('($px, $py)');
      }
    }
  }
  return found;
}

StampPaintData _data(String city, String cc, String name, StampAward? award) =>
    StampPaintData(
      seedId: 'frame-fit-$name',
      cityName: city,
      countryCode: cc,
      venueName: name,
      date: DateTime(2026, 11, 21),
      award: award,
      // The welcome sample's own ink, and the palest of the three.
      ink: StampInk.gold.color,
    );

void main() {
  final cases = {
    // The welcome flow's own sample stamp, as page 5 prints it.
    'the welcome flow sample': _data(
      'Copenhagen',
      'DK',
      'Four hands',
      const EventTypeAward('DINNER'),
    ),
    // A short name that wraps, with and without an award row.
    'a 10 character name of two wide words': _data(
      'Copenhagen',
      'DK',
      'MMMMM WWWW',
      const StarsAward(3),
    ),
    'the same name without an award': _data('Oslo', 'NO', 'MMMMM WWWW', null),
    // The tiers below: a middle length and a long name on 2 lines.
    'a middle length name': _data(
      'Copenhagen',
      'DK',
      'Restaurant Mmmmmmm',
      const KeysAward(3),
    ),
    'a long name': _data(
      'Hong Kong',
      'HK',
      '8½ Otto e Mezzo Bombana',
      const StarsAward(3),
    ),
    'a single word': _data('Paris', 'FR', 'Plénitude', const StarsAward(3)),
  };

  const variants = {
    StampVariant.doubleFrame: _inDoubleFrameGap,
    StampVariant.oval: _inOvalGap,
    StampVariant.lozenge: _inLozengeBandGap,
  };
  for (final MapEntry(key: variant, value: inGap) in variants.entries) {
    for (final MapEntry(key: label, value: data) in cases.entries) {
      testWidgets('${variant.name}: $label stays inside the border', (
        tester,
      ) async {
        final image = await _render(tester, variant, data);
        expect(await _inkInGap(tester, image, inGap), isEmpty);
      });
    }
  }
}
