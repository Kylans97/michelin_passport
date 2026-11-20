import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import '../../models/event.dart';
import '../constants/app_colors.dart';

/// The line-drawn stand-in for a restaurant, hotel, private chef or event
/// that has no photo yet — the vineyard estate header's vocabulary (two
/// deep-green planes, thin ivory line at low opacity, one faint round
/// light) applied to fifteen generic scenes. Chosen by the product owner
/// on 2026-11-20 from the header-drawings design canvas, with the
/// explicit wish that all of them are used and alternate, "anders wordt
/// het ook zo eentonig".
///
/// A drawing is never content about the place: no names, no dates, no
/// gold, nothing a viewer could read as a fact. The venue's own approved
/// photo always replaces it. Gold stays reserved for MICHELIN stars and
/// Keys, which is also why no hotel scene draws a key.
enum HeaderDrawingScene {
  tableSetting,
  kitchenPass,
  archedRoom,
  facade,
  gardenAllee,
  frontDoor,
  chefBoard,
  chefTable,
  dinner,
  lunch,
  festival,
  gala,
  tasting,
  brunch,
  party,
}

/// Which drawing a subject gets, and the small details that vary with it,
/// all derived from [seed] — the venue's or event's id. The same id always
/// resolves to the same picture on every screen and device; a list of
/// photo-less places varies quietly instead of repeating one image.
///
/// The subject decides the pool (a restaurant never gets a hotel façade);
/// the id picks within it. Events are drawn by their type — a Dinner also
/// draws from the restaurant rooms, since dinners are the most common
/// type and would otherwise all show the same candles. A type without a
/// drawing of its own (Market, Experience, other) draws from every event
/// scene.
@immutable
class HeaderDrawing {
  final String seed;
  final List<HeaderDrawingScene> pool;

  const HeaderDrawing._(this.seed, this.pool);

  const HeaderDrawing.restaurant(String id) : this._(id, _restaurantPool);
  const HeaderDrawing.hotel(String id) : this._(id, _hotelPool);
  const HeaderDrawing.privateChef(String id) : this._(id, _chefPool);

  factory HeaderDrawing.event(String id, EventType type) => HeaderDrawing._(
    id,
    switch (type) {
      EventType.dinner => _dinnerPool,
      EventType.lunch => const [
        HeaderDrawingScene.lunch,
        HeaderDrawingScene.tableSetting,
      ],
      EventType.brunch => const [HeaderDrawingScene.brunch],
      EventType.festival => const [HeaderDrawingScene.festival],
      EventType.gala => const [HeaderDrawingScene.gala],
      EventType.tasting => const [HeaderDrawingScene.tasting],
      EventType.party => const [HeaderDrawingScene.party],
      EventType.market || EventType.experience || EventType.other => _eventPool,
    },
  );

  static const _restaurantPool = [
    HeaderDrawingScene.tableSetting,
    HeaderDrawingScene.kitchenPass,
    HeaderDrawingScene.archedRoom,
  ];
  static const _hotelPool = [
    HeaderDrawingScene.facade,
    HeaderDrawingScene.gardenAllee,
    HeaderDrawingScene.frontDoor,
  ];
  static const _chefPool = [
    HeaderDrawingScene.chefBoard,
    HeaderDrawingScene.chefTable,
  ];
  static const _dinnerPool = [
    HeaderDrawingScene.dinner,
    HeaderDrawingScene.tableSetting,
    HeaderDrawingScene.kitchenPass,
    HeaderDrawingScene.archedRoom,
  ];
  static const _eventPool = [
    HeaderDrawingScene.dinner,
    HeaderDrawingScene.lunch,
    HeaderDrawingScene.festival,
    HeaderDrawingScene.gala,
    HeaderDrawingScene.tasting,
    HeaderDrawingScene.brunch,
    HeaderDrawingScene.party,
  ];

  /// FNV-1a over the id's UTF-16 code units, then mixed — stable across platforms and
  /// releases, unlike [String.hashCode], which Dart does not promise.
  static int hashSeed(String seed) {
    var h = 0x811c9dc5;
    for (final unit in seed.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    // MurmurHash3's finaliser: FNV alone leaves ids that differ only in
    // their last character close together, and the first draws would
    // correlate.
    return _fmix(h);
  }

  static int _fmix(int h) {
    h ^= h >> 16;
    h = (h * 0x85ebca6b) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xc2b2ae35) & 0xFFFFFFFF;
    return h ^ (h >> 16);
  }

  // The k-th independent draw for one id: each detail gets its own mixed
  // value rather than successive outputs of one small generator, whose
  // low bits would correlate with the scene choice.
  static int _draw(int h, int k) =>
      _fmix((h + (k + 1) * 0x9E3779B9) & 0xFFFFFFFF);

  HeaderDrawingVariant resolve() {
    final h = hashSeed(seed);
    final scene = pool[_draw(h, 0) % pool.length];
    final mirrored = _mirrorable.contains(scene) && _draw(h, 1).isOdd;
    final light = HeaderDrawingLight.values[_draw(h, 2) % 4];
    final lit = <int>{};
    if (scene == HeaderDrawingScene.facade) {
      final count = 1 + _draw(h, 3) % 4;
      for (var k = 4; lit.length < count; k++) {
        lit.add(_draw(h, k) % _facadeWindows.length);
      }
    }
    return HeaderDrawingVariant._(scene, mirrored, light, lit);
  }

  // Scenes whose mirror image is still true. Not the table setting (the
  // knife belongs on the right), the board (same), the front door and the
  // façade (symmetric, so mirroring changes nothing).
  static const _mirrorable = {
    HeaderDrawingScene.kitchenPass,
    HeaderDrawingScene.archedRoom,
    HeaderDrawingScene.gardenAllee,
    HeaderDrawingScene.chefTable,
    HeaderDrawingScene.dinner,
    HeaderDrawingScene.lunch,
    HeaderDrawingScene.festival,
    HeaderDrawingScene.tasting,
    HeaderDrawingScene.brunch,
    HeaderDrawingScene.party,
  };

  @override
  bool operator ==(Object other) =>
      other is HeaderDrawing && other.seed == seed && other.pool == pool;

  @override
  int get hashCode => Object.hash(seed, pool);
}

/// One id's resolved picture: the scene plus its seeded details.
@immutable
class HeaderDrawingVariant {
  final HeaderDrawingScene scene;
  final bool mirrored;
  final HeaderDrawingLight light;

  /// Indexes into the façade's windows that are lit; empty elsewhere.
  final Set<int> litWindows;

  const HeaderDrawingVariant._(
    this.scene,
    this.mirrored,
    this.light,
    this.litWindows,
  );

  @override
  bool operator ==(Object other) =>
      other is HeaderDrawingVariant &&
      other.scene == scene &&
      other.mirrored == mirrored &&
      other.light == light &&
      setEquals(other.litWindows, litWindows);

  @override
  int get hashCode =>
      Object.hash(scene, mirrored, light, Object.hashAllUnordered(litWindows));
}

/// Where the scene's faint round light (moon or sun) sits for one id.
enum HeaderDrawingLight { asDrawn, opposite, none, small }

/// Paints [drawing] cover-fitted into whatever box it is given — a 300 pt
/// hero, a 4:3 card, a 52 pt thumbnail — centre-cropped like a photo would
/// be. Lines stay 1.2 logical px at every size, so a thumbnail reads as
/// texture rather than hairline noise.
///
/// Sizes itself to its constraints (or [width]/[height]), the same way
/// [CsImagePlaceholder] does, so it drops into the same slots. [muted]
/// is the greyed treatment for a permanently closed venue.
class CsHeaderDrawing extends StatelessWidget {
  final HeaderDrawing drawing;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final bool muted;

  const CsHeaderDrawing({
    super.key,
    required this.drawing,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.hasBoundedWidth ? constraints.maxWidth : 64.0;
            final h = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : w * _designHeight / _designWidth;
            return CustomPaint(
              size: Size(w, h),
              painter: HeaderDrawingPainter(drawing.resolve(), muted: muted),
            );
          },
        ),
      ),
    );
  }
}

const double _designWidth = 390;
const double _designHeight = 300;

class HeaderDrawingPainter extends CustomPainter {
  final HeaderDrawingVariant variant;
  final bool muted;

  HeaderDrawingPainter(this.variant, {this.muted = false});

  static const double _lineWidth = 1.2;
  static const Color _ink = AppColors.textOnDark;

  Color _tone(_Tone tone) => switch (tone) {
    _Tone.mid => muted ? const Color(0xFF34322D) : const Color(0xFF1B3B33),
    _Tone.forest => muted ? const Color(0xFF4A463F) : AppColors.forestGreen,
    _Tone.dark => muted ? const Color(0xFF26241F) : AppColors.darkGreen,
    _Tone.ink => _ink,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()..color = muted ? const Color(0xFF3E3B35) : AppColors.deepGreen,
    );

    final scale = math.max(
      size.width / _designWidth,
      size.height / _designHeight,
    );
    canvas.translate(
      (size.width - _designWidth * scale) / 2,
      (size.height - _designHeight * scale) / 2,
    );
    canvas.scale(scale);

    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scene = _scenes[variant.scene]!;
    final light = scene.light;
    if (light != null) {
      final placed = switch (variant.light) {
        HeaderDrawingLight.asDrawn => light,
        HeaderDrawingLight.opposite => _Light(
          _designWidth - light.cx,
          light.cy,
          light.r,
          light.opacity,
        ),
        HeaderDrawingLight.small => _Light(
          light.cx - 14,
          light.cy - 8,
          light.r * 0.75,
          light.opacity,
        ),
        HeaderDrawingLight.none => null,
      };
      if (placed != null) {
        canvas.drawCircle(
          Offset(placed.cx, placed.cy),
          placed.r,
          fill..color = _ink.withValues(alpha: placed.opacity),
        );
      }
    }

    canvas.save();
    if (variant.mirrored) {
      canvas.translate(_designWidth, 0);
      canvas.scale(-1, 1);
    }
    for (final layer in scene.layers) {
      final path = layer.path;
      final fillTone = layer.fill;
      if (fillTone != null) {
        fill.color = _tone(fillTone).withValues(alpha: layer.fillOpacity);
        canvas.drawPath(path, fill);
      }
      final lineOpacity = layer.line;
      if (lineOpacity != null) {
        line.color = _ink.withValues(alpha: lineOpacity);
        canvas.drawPath(path, line);
      }
    }
    canvas.restore();

    if (variant.litWindows.isNotEmpty) {
      fill.color = _ink.withValues(alpha: 0.14);
      for (final index in variant.litWindows) {
        canvas.drawRect(_facadeWindows[index], fill);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HeaderDrawingPainter old) =>
      old.variant != variant || old.muted != muted;
}

// ---------------------------------------------------------------------------
// Scene data. Every scene is drawn in a 390×300 design space — the detail
// hero at phone width — as SVG path data, ported one to one from the
// header-drawings design canvas
// (https://claude.ai/artifact/891UF37f9npbsWwYFzrXE5). Layers paint in
// order: fill first, then line, each with its own opacity.
// ---------------------------------------------------------------------------

enum _Tone { mid, forest, dark, ink }

class _Light {
  final double cx;
  final double cy;
  final double r;
  final double opacity;
  const _Light(this.cx, this.cy, this.r, [this.opacity = 0.08]);
}

class _Layer {
  final String d;
  final _Tone? fill;
  final double fillOpacity;

  /// Line opacity; null for a fill-only layer.
  final double? line;

  const _Layer(this.d, {this.fill, this.fillOpacity = 1, this.line});

  Path get path => _pathCache[d] ??= _parse(d);
}

class _Scene {
  final List<_Layer> layers;
  final _Light? light;
  const _Scene(this.layers, {this.light});
}

final Map<String, Path> _pathCache = {};

Path _parse(String d) {
  final builder = _PathBuilder();
  writeSvgPathDataToPath(d, builder);
  return builder.path;
}

class _PathBuilder extends PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

// Shape helpers, written as path data so every layer is one string.
String _circle(double cx, double cy, double r) =>
    'M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0Z';

String _ellipse(double cx, double cy, double rx, double ry) =>
    'M${cx - rx} ${cy}a$rx $ry 0 1 0 ${2 * rx} 0a$rx $ry 0 1 0 ${-2 * rx} 0Z';

String _rect(double x, double y, double w, double h) =>
    'M$x ${y}h${w}v${h}h${-w}Z';

String _roundRect(double x, double y, double w, double h, double r) =>
    'M${x + r} ${y}H${x + w - r}A$r $r 0 0 1 ${x + w} ${y + r}'
    'V${y + h - r}A$r $r 0 0 1 ${x + w - r} ${y + h}'
    'H${x + r}A$r $r 0 0 1 $x ${y + h - r}V${y + r}A$r $r 0 0 1 ${x + r} ${y}Z';

const double _l = 0.22; // the default line opacity, as in the vineyard

final List<Rect> _facadeWindows = [
  for (final x in [99.0, 142.0, 186.0, 230.0, 273.0]) ...[
    Rect.fromLTWH(x, 110, 18, 28),
    Rect.fromLTWH(x, 156, 18, 28),
    // The ground floor's middle bay is the door.
    if (x != 186) Rect.fromLTWH(x, 206, 18, 30),
  ],
];

final Map<HeaderDrawingScene, _Scene> _scenes = {
  HeaderDrawingScene.tableSetting: _Scene([
    _Layer(_rect(0, 40, 390, 214), fill: _Tone.mid),
    _Layer(_circle(195, 140, 82), fill: _Tone.forest),
    const _Layer('M0 40H390M0 254H390', line: 0.1),
    _Layer(_circle(195, 140, 64), line: _l),
    _Layer(_circle(195, 140, 44), line: 0.12),
    const _Layer(
      'M96 222V134M88 84V120M93 84V120M99 84V120M104 84V120'
      'M88 120Q96 134 104 120',
      line: _l,
    ),
    const _Layer('M292 222V136M290 80Q303 98 300 136H290Z', line: _l),
    const _Layer('M318 222V122', line: _l),
    _Layer(_ellipse(318, 102, 7, 12), line: _l),
    _Layer(_circle(262, 66, 16), line: _l),
    _Layer(_circle(262, 66, 11), line: 0.12),
    _Layer(_circle(122, 62, 18), line: _l),
    const _Layer('M110 56L134 68', line: 0.16),
  ]),
  HeaderDrawingScene.kitchenPass: _Scene([
    const _Layer(
      'M98 76L70 196H150L122 76Z M183 76L155 196H235L207 76Z '
      'M268 76L240 196H320L292 76Z',
      fill: _Tone.ink,
      fillOpacity: 0.045,
    ),
    _Layer(_rect(0, 196, 390, 104), fill: _Tone.mid),
    const _Layer('M110 0V54M195 0V54M280 0V54', line: _l),
    const _Layer(
      'M96 74L102 54H118L124 74Z M181 74L187 54H203L209 74Z '
      'M266 74L272 54H288L294 74Z',
      fill: _Tone.forest,
      line: _l,
    ),
    const _Layer('M28 126H362', line: 0.3),
    const _Layer(
      'M44 126V148H58V126M64 126V144H78V126M312 126V150H326V126'
      'M332 126V142H346V126',
      line: 0.16,
    ),
    const _Layer('M0 196H390', line: _l),
    const _Layer('M0 206H390', line: 0.1),
    const _Layer('M84 196Q110 186 136 196M254 196Q280 186 306 196', line: _l),
    const _Layer('M172 196A23 22 0 0 1 218 196Z', fill: _Tone.forest, line: _l),
    _Layer(_circle(195, 171, 3), line: _l),
    const _Layer('M164 196H226', line: 0.3),
  ]),
  HeaderDrawingScene.archedRoom: _Scene([
    const _Layer(_arches, fill: _Tone.mid),
    _Layer(_circle(206, 116, 11), fill: _Tone.ink, fillOpacity: 0.09),
    _Layer(_rect(0, 236, 390, 64), fill: _Tone.dark),
    const _Layer(_arches, line: _l),
    const _Layer(
      'M68 224V110A37 37 0 0 1 142 110V224 M158 224V110A37 37 0 0 1 232 110V224 '
      'M248 224V110A37 37 0 0 1 322 110V224',
      line: 0.1,
    ),
    const _Layer(
      'M105 79V222M195 79V222M285 79V222M74 150H136M164 150H226M254 150H316',
      line: 0.14,
    ),
    const _Layer('M0 236H390M195 0V40', line: _l),
    const _Layer('M181 54Q195 36 209 54Z', fill: _Tone.forest, line: _l),
    _Layer(_ellipse(195, 230, 46, 6), fill: _Tone.forest, line: _l),
    const _Layer(
      'M195 236V272M178 272H212'
      'M128 196Q125 236 130 272M130 240H156M154 240V272'
      'M262 196Q265 236 260 272M260 240H234M236 240V272',
      line: _l,
    ),
  ]),
  HeaderDrawingScene.facade: _Scene([
    const _Layer('M86 86L104 58H286L304 86Z', fill: _Tone.mid),
    _Layer(_rect(78, 92, 234, 170), fill: _Tone.forest),
    const _Layer('M0 262C120 250 270 250 390 262V300H0Z', fill: _Tone.mid),
    const _Layer(
      'M86 86L104 58H286L304 86M70 92H320M74 86H316'
      'M120 58V44H130V58M260 58V44H270V58M78 262V92M312 262V92'
      'M183 262V226A12 12 0 0 1 207 226V262',
      line: _l,
    ),
    const _Layer(
      'M142 80V68H158V80M187 80V68H203V80M232 80V68H248V80'
      'M140 68L150 60L160 68M185 68L195 60L205 68M230 68L240 60L250 68'
      'M172 262H218M166 268H224',
      line: 0.16,
    ),
    const _Layer('M78 148H312M78 196H312', line: 0.12),
    _Layer(
      [
        for (final w in _facadeWindows) _rect(w.left, w.top, w.width, w.height),
      ].join(' '),
      line: _l,
    ),
  ], light: const _Light(330, 54, 18)),
  HeaderDrawingScene.gardenAllee: _Scene([
    _Layer(_rect(0, 128, 390, 172), fill: _Tone.mid),
    const _Layer(
      'M0 150L183 124V130L0 200Z M390 150L207 124V130L390 200Z',
      fill: _Tone.forest,
    ),
    const _Layer('M0 128H390', line: 0.12),
    const _Layer(
      'M183 128V110H207V128M183 110A12 10 0 0 1 207 110M195 100V96'
      'M0 150L183 124M0 200L183 130M390 150L207 124M390 200L207 130'
      'M120 300L188 130M270 300L202 130',
      line: _l,
    ),
    const _Layer(
      'M132 270H258M146 236H244M158 206H232M167 182H223M174 164H216'
      'M180 150H210',
      line: 0.1,
    ),
    const _Layer(
      'M26 185L40 145L54 185Z M91 162L100 136L109 162Z M140 145L145 130L150 145Z '
      'M364 185L350 145L336 185Z M299 162L290 136L281 162Z '
      'M250 145L245 130L240 145Z',
      fill: _Tone.mid,
      line: _l,
    ),
  ], light: const _Light(304, 58, 16)),
  HeaderDrawingScene.frontDoor: _Scene([
    const _Layer('M140 140A55 55 0 0 1 250 140Z', fill: _Tone.mid),
    _Layer(_rect(140, 140, 110, 132), fill: _Tone.forest),
    _Layer(_rect(0, 272, 390, 28), fill: _Tone.mid),
    const _Layer(
      'M0 24H390M0 48H390M0 96H110M280 96H390M0 120H110M280 120H390'
      'M0 144H70M320 144H390M0 168H62M318 168H390M0 192H62M318 192H390'
      'M0 216H62M318 216H390M0 240H62M318 240H390',
      line: 0.07,
    ),
    const _Layer('M110 78H280M114 72H276', line: _l),
    const _Layer(
      'M120 78V272M134 78V272M256 78V272M270 78V272'
      'M179 140A16 16 0 0 1 211 140'
      'M195 140L242.6 112.5M195 140L222.5 92.4M195 140V85'
      'M195 140L167.5 92.4M195 140L147.4 112.5'
      'M128 272H262M120 280H270M112 288H278',
      line: 0.16,
    ),
    _Layer(
      'M140 140A55 55 0 0 1 250 140Z ${_rect(140, 140, 110, 132)} '
      'M195 140V272 ${_circle(189, 208, 2)} ${_circle(201, 208, 2)} '
      'M88 250V214M302 250V214',
      line: _l,
    ),
    _Layer(
      '${_rect(150, 152, 36, 50)} ${_rect(204, 152, 36, 50)} '
      '${_rect(150, 214, 36, 48)} ${_rect(204, 214, 36, 48)}',
      line: 0.14,
    ),
    const _Layer(
      'M78 272L82 250H94L98 272Z M292 272L296 250H308L312 272Z',
      fill: _Tone.mid,
      line: _l,
    ),
    _Layer(
      '${_circle(88, 198, 18)} ${_circle(302, 198, 18)}',
      fill: _Tone.forest,
      line: _l,
    ),
  ]),
  HeaderDrawingScene.chefBoard: _Scene([
    _Layer(_roundRect(70, 70, 250, 150, 14), fill: _Tone.forest, line: _l),
    const _Layer(
      'M84 100C150 94 220 106 280 98M84 140C160 134 230 146 280 140'
      'M84 186C150 180 230 192 280 184',
      line: 0.08,
    ),
    _Layer(_circle(300, 145, 7), line: _l),
    const _Layer(
      'M118 206L236 112C246 106 250 114 242 120L136 214Z',
      fill: _Tone.mid,
      line: _l,
    ),
    _Layer(
      'M120 206L88 230C82 234 86 242 92 240L134 214 '
      '${_circle(100, 228, 1.5)} ${_circle(114, 219, 1.5)} '
      'M100 96Q130 110 160 108',
      line: _l,
    ),
    const _Layer(
      'M112 101q6-8 12-2q-6 8-12 2Z M126 106q6 8 12 2q-6-8-12-2Z '
      'M140 108q6-8 12-2q-6 8-12 2Z M150 108q6 8 12 2q-6-8-12-2Z',
      fill: _Tone.mid,
      line: _l,
    ),
    _Layer(
      '${_circle(204, 86, 2)} ${_circle(212, 92, 2)} ${_circle(200, 94, 2)}',
      line: 0.16,
    ),
  ]),
  HeaderDrawingScene.chefTable: _Scene([
    _Layer(_circle(195, 140, 64), fill: _Tone.ink, fillOpacity: 0.04),
    _Layer(_rect(0, 262, 390, 38), fill: _Tone.mid),
    const _Layer('M290 36H350V86H290Z', line: 0.12),
    const _Layer('M298 76L314 58L326 70L334 62L342 76', line: 0.1),
    const _Layer('M163 96Q195 60 227 96Z', fill: _Tone.forest, line: _l),
    _Layer(_rect(95, 192, 200, 6), fill: _Tone.forest, line: _l),
    const _Layer('M160 192A35 32 0 0 1 230 192Z', fill: _Tone.mid),
    _Layer(
      'M195 0V74M105 198V262M285 198V262M160 192A35 32 0 0 1 230 192 '
      '${_circle(195, 156, 4)} '
      'M66 150Q64 200 70 262M70 214H92M92 214V262'
      'M324 150Q326 200 320 262M320 214H298M298 214V262M0 262H390',
      line: _l,
    ),
    const _Layer('M152 192H238', line: 0.3),
  ]),
  HeaderDrawingScene.dinner: _Scene([
    _Layer(
      '${_circle(95, 126, 16)} ${_circle(145, 108, 16)} ${_circle(195, 92, 18)} '
      '${_circle(245, 108, 16)} ${_circle(295, 126, 16)}',
      fill: _Tone.ink,
      fillOpacity: 0.05,
    ),
    _Layer(_rect(30, 196, 330, 56), fill: _Tone.mid),
    const _Layer(
      'M95 132q4-6 0-14q-4 8 0 14Z M145 114q4-6 0-14q-4 8 0 14Z '
      'M195 98q4-6 0-14q-4 8 0 14Z M245 114q4-6 0-14q-4 8 0 14Z '
      'M295 132q4-6 0-14q-4 8 0 14Z',
      fill: _Tone.ink,
      fillOpacity: 0.35,
    ),
    const _Layer(
      'M30 196H360M30 196V252M360 196V252'
      'M87 196H103M95 196V176M89 176H101 M137 196H153M145 196V176M139 176H151 '
      'M187 196H203M195 196V176M189 176H201 M237 196H253M245 196V176M239 176H251 '
      'M287 196H303M295 196V176M289 176H301',
      line: _l,
    ),
    const _Layer('M30 252H360', line: 0.14),
    const _Layer('M90 198V252M195 198V252M300 198V252', line: 0.08),
    const _Layer(
      'M92 136h6v40h-6Z M142 118h6v58h-6Z M192 102h6v74h-6Z '
      'M242 118h6v58h-6Z M292 136h6v40h-6Z',
      fill: _Tone.forest,
      line: _l,
    ),
    const _Layer(
      'M114 168q0 12 6 13q6-1 6-13Z M120 181V196M115 196H125 '
      'M264 168q0 12 6 13q6-1 6-13Z M270 181V196M265 196H275',
      line: 0.18,
    ),
  ]),
  HeaderDrawingScene.lunch: _Scene([
    _Layer(_rect(0, 150, 390, 150), fill: _Tone.mid),
    _Layer(_rect(0, 230, 390, 70), fill: _Tone.forest),
    const _Layer('M60 112Q140 70 220 112Z', fill: _Tone.forest),
    const _Layer('M0 150H390', line: 0.16),
    const _Layer(
      'M24 166H120M220 170H340M60 184H180M250 192H370M10 206H90',
      line: 0.1,
    ),
    const _Layer(
      'M0 230H390M60 112Q140 70 220 112'
      'M60 112q10 8 20 0q10 8 20 0q10 8 20 0q10 8 20 0q10 8 20 0'
      'q10 8 20 0q10 8 20 0q10 8 20 0M140 84V230',
      line: _l,
    ),
    const _Layer(
      'M140 91L60 112M140 91L100 112M140 91L180 112M140 91L220 112',
      line: 0.14,
    ),
    _Layer(_ellipse(140, 196, 44, 5), fill: _Tone.mid, line: _l),
    const _Layer(
      'M110 200L106 230M170 200L174 230'
      'M196 168Q194 200 198 230M198 206H220M220 206V230'
      'M84 168Q86 200 82 230M82 206H60M60 206V230',
      line: _l,
    ),
  ], light: const _Light(304, 58, 22, 0.1)),
  HeaderDrawingScene.festival: _Scene([
    const _Layer(
      'M0 176C80 150 170 156 250 172C310 184 350 178 390 166V300H0Z',
      fill: _Tone.forest,
    ),
    const _Layer(
      'M0 230C90 206 200 210 290 226C340 234 370 232 390 228V300H0Z',
      fill: _Tone.mid,
    ),
    const _Layer(
      'M84 172L96 146L120 132L144 146L156 172Z '
      'M186 174L194 156L210 146L226 156L234 174Z '
      'M270 182L277 168L290 160L303 168L310 182Z',
      fill: _Tone.mid,
      line: _l,
    ),
    const _Layer(
      'M112 172L120 152L128 172M204 174L210 160L216 174M286 182L290 172L294 182'
      'M120 124Q165 150 210 138Q250 162 290 152',
      line: 0.16,
    ),
    const _Layer('M120 132V120M210 146V136M290 160V152', line: _l),
    const _Layer(
      'M120 120L130 124L120 128M210 136L218 139L210 142M290 152L297 155L290 158',
      line: 0.3,
    ),
    const _Layer(
      'M134 133L138 141L142 133M152 139L156 147L160 139M170 141L174 149L178 141'
      'M188 141L192 149L196 141M226 148L230 156L234 148M246 153L250 161L254 153'
      'M266 155L270 163L274 155',
      line: 0.26,
    ),
    const _Layer('M40 300C90 262 150 250 196 232', line: 0.12),
  ], light: const _Light(320, 64, 18)),
  HeaderDrawingScene.gala: _Scene([
    _Layer(_circle(195, 124, 72), fill: _Tone.ink, fillOpacity: 0.035),
    _Layer(_circle(195, 124, 44), fill: _Tone.ink, fillOpacity: 0.04),
    _Layer(_rect(0, 250, 390, 50), fill: _Tone.mid),
    _Layer(
      '${_ellipse(150, 75, 2, 3.5)} ${_ellipse(240, 75, 2, 3.5)} '
      '${_ellipse(118, 111, 2, 3.5)} ${_ellipse(156, 122, 2, 3.5)} '
      '${_ellipse(234, 122, 2, 3.5)} ${_ellipse(272, 111, 2, 3.5)}',
      fill: _Tone.ink,
      fillOpacity: 0.4,
    ),
    _Layer(
      'M195 0V40M185 40H205M189 40L195 32L201 40M195 40V150'
      'M150 92Q195 112 240 92M118 128Q195 158 272 128'
      'M145 92H155M150 92V80M235 92H245M240 92V80M113 128H123M118 128V116'
      'M151 139H161M156 139V127M229 139H239M234 139V127M267 128H277M272 128V116'
      '${_circle(130, 149, 2.5)} ${_circle(150, 155, 2.5)} '
      '${_circle(175, 159, 2.5)} ${_circle(215, 159, 2.5)} '
      '${_circle(240, 155, 2.5)} ${_circle(260, 149, 2.5)} '
      'M195 150L189 162L195 176L201 162Z M0 250H390',
      line: _l,
    ),
    const _Layer(
      'M130 132V146M150 138V152M175 142V156M215 142V156M240 138V152M260 132V146',
      line: 0.16,
    ),
    const _Layer(
      'M150 250L60 300M240 250L330 300M195 250V300M105 250L-30 300M285 250L420 300',
      line: 0.08,
    ),
  ]),
  HeaderDrawingScene.tasting: _Scene([
    _Layer(_rect(0, 214, 390, 86), fill: _Tone.mid),
    const _Layer(
      'M66 158c2 10 7 13 13 14c6-1 11-4 13-14Z '
      'M122 146c1 16 7 24 15 26c8-2 14-10 15-26Z '
      'M239 152c1 12 7 19 14 20c7-1 13-8 14-20Z '
      'M301 164c2 5 6 7 10 8c4-1 8-3 10-8Z',
      fill: _Tone.ink,
      fillOpacity: 0.1,
    ),
    _Layer(
      'M0 214H390 ${[
        for (final x in const [79.0, 137.0, 195.0, 253.0, 311.0]) _glass(x),
      ].join(' ')}',
      line: _l,
    ),
    const _Layer('M66 158H92M122 146H152M239 152H267M301 164H321', line: 0.18),
    _Layer(
      [
        for (final x in const [69.0, 127.0, 185.0, 243.0, 301.0])
          _rect(x, 226, 20, 12),
      ].join(' '),
      line: 0.12,
    ),
  ]),
  HeaderDrawingScene.brunch: _Scene([
    _Layer(_rect(112, 34, 166, 168), fill: _Tone.mid),
    _Layer(_circle(236, 146, 20), fill: _Tone.ink, fillOpacity: 0.1),
    _Layer(_rect(0, 236, 390, 64), fill: _Tone.forest),
    const _Layer(
      'M132 240H286L318 290H156Z',
      fill: _Tone.ink,
      fillOpacity: 0.04,
    ),
    _Layer(
      '${_rect(112, 34, 166, 168)} M195 34V202M112 118H278M0 236H390',
      line: _l,
    ),
    const _Layer('M153 34V202M236 34V202M112 176H278', line: 0.12),
    const _Layer(
      'M104 236L108 196Q120 188 132 196L136 236Z M186 234L184 218H208L206 234Z',
      fill: _Tone.mid,
      line: _l,
    ),
    _Layer(
      'M132 206L146 196M106 204Q94 214 106 226 ${_circle(120, 188, 3)} '
      'M180 236H212M208 222Q216 224 208 230'
      'M262 236Q258 222 266 214V202H270V214Q278 222 274 236Z'
      'M268 202Q266 180 272 166M268 188Q276 182 278 176 '
      '${_circle(272, 161, 5)}',
      line: _l,
    ),
    const _Layer('M194 212Q190 204 196 198Q200 192 196 186', line: 0.16),
  ]),
  HeaderDrawingScene.party: _Scene([
    const _Layer('${_rooftops}V300H0Z', fill: _Tone.mid),
    _Layer(
      '${_circle(127, 119, 11)} ${_circle(229, 127, 11)} ${_circle(178, 166, 11)}',
      fill: _Tone.ink,
      fillOpacity: 0.05,
    ),
    _Layer(
      [for (final p in _bulbs) _circle(p.dx, p.dy + 7, 3)].join(' '),
      fill: _Tone.ink,
      fillOpacity: 0.32,
    ),
    const _Layer(_rooftops, line: 0.12),
    const _Layer('M24 300V70M366 300V80', line: _l),
    _Layer(
      'M24 76Q195 160 366 86M24 118Q195 196 366 128 '
      '${[for (final p in _bulbs) 'M${p.dx} ${p.dy}v4'].join()}',
      line: 0.18,
    ),
  ]),
};

const String _arches =
    'M74 222V110A31 31 0 0 1 136 110V222Z M164 222V110A31 31 0 0 1 226 110V222Z '
    'M254 222V110A31 31 0 0 1 316 110V222Z';

const String _rooftops =
    'M0 240H40V222H70V232H110V214L124 204L138 214V236H190V226H230V240'
    'H260V218H300V228H340V210H360V240H390';

// Where each bulb's drop hangs from the two strings of lights.
const List<Offset> _bulbs = [
  Offset(58, 91),
  Offset(92, 103),
  Offset(127, 112),
  Offset(161, 118),
  Offset(195, 121),
  Offset(229, 120),
  Offset(263, 116),
  Offset(298, 109),
  Offset(332, 99),
  Offset(75, 138),
  Offset(127, 152),
  Offset(178, 159),
  Offset(229, 159),
  Offset(281, 153),
  Offset(332, 140),
];

String _glass(double x) =>
    'M${x - 15} 120c-2 28 3 48 15 52c12-4 17-24 15-52'
    'M$x 172V210M${x - 13} 214q13-6 26 0';
