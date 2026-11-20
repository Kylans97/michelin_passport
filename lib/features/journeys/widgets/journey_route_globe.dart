import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/journey.dart';
import '../../map/globe/globe_camera.dart';
import '../../map/globe/globe_outlines.dart';
import '../../map/globe/globe_painter.dart';

/// Where a train or ship goes, on the app's own globe (the bundled Natural
/// Earth outlines GlobePainter already draws for My Map): the countries it
/// touches lit, and, when its stops are known, the selected route drawn
/// stop to stop with its other routes faint behind it. Static, no
/// gestures: it is a picture on the page, not a second map screen.
///
/// Lines between stops follow the great circle. Only the stops are data;
/// the track or sea lane between them is not stored, so two stops are one
/// arc.
class JourneyRouteGlobe extends StatefulWidget {
  /// Drawable routes only (see drawableRouteStops), in display order.
  final List<List<JourneyRouteStop>> routes;
  final int selectedIndex;
  final Set<String> countryCodes;
  final double height;

  const JourneyRouteGlobe({
    super.key,
    required this.routes,
    required this.selectedIndex,
    required this.countryCodes,
    this.height = 260,
  });

  @override
  State<JourneyRouteGlobe> createState() => _JourneyRouteGlobeState();
}

class _JourneyRouteGlobeState extends State<JourneyRouteGlobe>
    with SingleTickerProviderStateMixin {
  final _outlines = GlobeOutlines.load();
  GlobeOutlines? _loaded;
  late final _camera = ValueNotifier(
    const GlobeCamera(latitude: 20, longitude: 0),
  );
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  GlobeCamera _from = const GlobeCamera(latitude: 20, longitude: 0);
  GlobeCamera _to = const GlobeCamera(latitude: 20, longitude: 0);

  @override
  void initState() {
    super.initState();
    _flight.addListener(() {
      final t = Curves.easeInOutCubic.transform(_flight.value);
      _camera.value = _from.lerpTo(_to, t);
    });
    _outlines.then((outlines) {
      if (!mounted) return;
      setState(() => _loaded = outlines);
      _camera.value = _fit(outlines);
    });
  }

  @override
  void didUpdateWidget(JourneyRouteGlobe old) {
    super.didUpdateWidget(old);
    final outlines = _loaded;
    if (outlines == null) return;
    if (old.selectedIndex != widget.selectedIndex ||
        old.routes != widget.routes) {
      _from = _camera.value;
      _to = _fit(outlines);
      _flight.forward(from: 0);
    }
  }

  // A Royal Scotsman loop spans a few degrees; at My Map's cap of 6 it
  // would be a smudge. The 1:50m coast still reads well this far in.
  static const double _maxRouteZoom = 14;

  // The route takes about half the panel, so the coast and the
  // neighbouring countries around it show where in the world it is.
  static const double _routeMargin = 0.8;

  GlobeCamera _fit(GlobeOutlines outlines) {
    final routes = widget.routes;
    if (routes.isNotEmpty) {
      final route = routes[widget.selectedIndex.clamp(0, routes.length - 1)];
      final fit = fitGlobeCamera(
        [for (final stop in route) (stop.latitude!, stop.longitude!)],
        fallback: _camera.value,
        singlePointZoom: _maxRouteZoom / _routeMargin,
      );
      return fit.copyWith(zoom: fit.zoom * _routeMargin);
    }
    return fitCountriesCamera(outlines, widget.countryCodes) ??
        _camera.value.copyWith(zoom: GlobeCamera.minZoom);
  }

  @override
  void dispose() {
    _flight.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routes = widget.routes;
    final selected = routes.isEmpty
        ? null
        : routes[widget.selectedIndex.clamp(0, routes.length - 1)];
    return Semantics(
      image: true,
      label: selected == null
          ? 'Map of where it goes'
          : 'Map of the route: ${_stopNames(selected)}',
      excludeSemantics: true,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.subtleBorderLight),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ColoredBox(
            color: AppColors.darkGreen,
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: _loaded == null
                  ? null
                  : CustomPaint(
                      painter: GlobePainter(
                        camera: _camera,
                        outlines: _loaded,
                        visitedCountryCodes: widget.countryCodes,
                      ),
                      foregroundPainter: JourneyRoutePainter(
                        camera: _camera,
                        routes: routes,
                        selectedIndex: widget.selectedIndex,
                        labelStyle: CsTypography.metadata.copyWith(
                          color: AppColors.deepGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  static String _stopNames(List<JourneyRouteStop> stops) =>
      stops.map((s) => s.place).join(', ');
}

/// The camera that frames [codes] when no stop is known: centred between
/// the countries' mainlands, zoomed to their extent. A country's largest
/// ring stands for it, so France's overseas departments do not pull a
/// Rhône cruise out to the whole globe. Null when no code has an outline.
GlobeCamera? fitCountriesCamera(GlobeOutlines outlines, Set<String> codes) {
  final extents = [
    for (final country in outlines.countries)
      if (codes.contains(country.code)) ?_mainland(country),
  ];
  if (extents.isEmpty) return null;
  var sx = 0.0, sy = 0.0, sz = 0.0;
  for (final (x, y, z, _) in extents) {
    sx += x;
    sy += y;
    sz += z;
  }
  final len = math.sqrt(sx * sx + sy * sy + sz * sz);
  if (len < 1e-6) return null;
  final cx = sx / len, cy = sy / len, cz = sz / len;
  var spread = 0.0;
  for (final (x, y, z, radius) in extents) {
    final angle = math.acos((x * cx + y * cy + z * cz).clamp(-1.0, 1.0));
    spread = math.max(spread, angle + radius);
  }
  final zoom = spread >= 70 * math.pi / 180
      ? GlobeCamera.minZoom
      : 0.85 / math.sin(math.max(spread, 0.02));
  return GlobeCamera(
    latitude: math.asin(cz.clamp(-1.0, 1.0)) * 180 / math.pi,
    longitude: math.atan2(cy, cx) * 180 / math.pi,
  ).copyWith(zoom: math.min(zoom, 6));
}

/// Centre (unit vector) and angular radius of a country's home ground: its
/// largest ring plus every ring whose centre lies within
/// [_homeGroundDegrees] of it. That keeps an archipelago whole (Sumatra to
/// Papua) and leaves out territories across an ocean (French Guiana).
(double, double, double, double)? _mainland(GlobeCountry country) {
  if (country.rings.isEmpty) return null;
  (double, double, double)? centre(Float32List ring) {
    var sx = 0.0, sy = 0.0, sz = 0.0;
    for (var i = 0; i < ring.length; i += 3) {
      sx += ring[i];
      sy += ring[i + 1];
      sz += ring[i + 2];
    }
    final len = math.sqrt(sx * sx + sy * sy + sz * sz);
    return len < 1e-9 ? null : (sx / len, sy / len, sz / len);
  }

  final largest = country.rings.reduce((a, b) => a.length >= b.length ? a : b);
  final home = centre(largest);
  if (home == null) return null;
  final limit = math.cos(_homeGroundDegrees * math.pi / 180);
  final rings = [
    for (final ring in country.rings)
      if (centre(ring) case final c?
          when c.$1 * home.$1 + c.$2 * home.$2 + c.$3 * home.$3 >= limit)
        ring,
  ];
  var sx = 0.0, sy = 0.0, sz = 0.0;
  for (final ring in rings) {
    for (var i = 0; i < ring.length; i += 3) {
      sx += ring[i];
      sy += ring[i + 1];
      sz += ring[i + 2];
    }
  }
  final len = math.sqrt(sx * sx + sy * sy + sz * sz);
  if (len < 1e-9) return null;
  final cx = sx / len, cy = sy / len, cz = sz / len;
  var minDot = 1.0;
  for (final ring in rings) {
    for (var i = 0; i < ring.length; i += 3) {
      minDot = math.min(
        minDot,
        ring[i] * cx + ring[i + 1] * cy + ring[i + 2] * cz,
      );
    }
  }
  return (cx, cy, cz, math.acos(minDot.clamp(-1.0, 1.0)));
}

const double _homeGroundDegrees = 40;

/// Draws the routes over the globe: the others as faint ivory threads, the
/// selected one as a dark line on an ivory halo (legible over lit land and
/// open sea alike), its stops as small rings, the first filled, and the
/// names of where it starts and ends.
class JourneyRoutePainter extends CustomPainter {
  final ValueNotifier<GlobeCamera> camera;
  final List<List<JourneyRouteStop>> routes;
  final int selectedIndex;
  final TextStyle labelStyle;

  JourneyRoutePainter({
    required this.camera,
    required this.routes,
    required this.selectedIndex,
    required this.labelStyle,
  }) : super(repaint: camera);

  static final _otherLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = AppColors.deepGreen.withValues(alpha: 0.35);
  static final _halo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = AppColors.ivory;
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = AppColors.deepGreen;

  @override
  void paint(Canvas canvas, Size size) {
    if (routes.isEmpty) return;
    final projection = GlobeProjection(camera.value, size);
    final selected = selectedIndex.clamp(0, routes.length - 1);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < routes.length; i++) {
      if (i == selected) continue;
      canvas.drawPath(routePath(routes[i], projection), _otherLine);
    }
    final route = routes[selected];
    final path = routePath(route, projection);
    canvas.drawPath(path, _halo);
    canvas.drawPath(path, _line);

    for (var i = route.length - 1; i >= 0; i--) {
      final (p, z) = projection.project(
        route[i].latitude!,
        route[i].longitude!,
      );
      if (z <= 0) continue;
      final first = i == 0;
      canvas.drawCircle(
        p,
        first ? 4.5 : 3.5,
        Paint()..color = first ? AppColors.deepGreen : AppColors.ivory,
      );
      canvas.drawCircle(
        p,
        first ? 4.5 : 3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = first ? AppColors.ivory : AppColors.deepGreen,
      );
    }

    final start = route.first;
    final end = route.last;
    final taken = _label(canvas, size, projection, start, null);
    if (end.place != start.place) {
      _label(canvas, size, projection, end, taken);
    }
    canvas.restore();
  }

  /// Paints a stop's name beside its dot: to the right, else to the left,
  /// below or above, whichever first stays on the panel and clear of
  /// [avoid] (the other label). Returns where it went.
  Rect? _label(
    Canvas canvas,
    Size size,
    GlobeProjection projection,
    JourneyRouteStop stop,
    Rect? avoid,
  ) {
    final (p, z) = projection.project(stop.latitude!, stop.longitude!);
    if (z <= 0) return null;
    final text = TextPainter(
      text: TextSpan(
        text: stop.place,
        style: labelStyle.copyWith(
          // An ivory halo, so the name reads over lit land and dark sea.
          shadows: const [
            Shadow(color: AppColors.ivory, blurRadius: 2),
            Shadow(color: AppColors.ivory, blurRadius: 4),
            Shadow(color: AppColors.ivory, blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width / 2);
    final w = text.width, h = text.height;
    final candidates = [
      Offset(p.dx + 9, p.dy - h / 2),
      Offset(p.dx - 9 - w, p.dy - h / 2),
      Offset(p.dx - w / 2, p.dy + 8),
      Offset(p.dx - w / 2, p.dy - 8 - h),
    ];
    final panel = (Offset.zero & size).deflate(4);
    Rect place(Offset o) => Rect.fromLTWH(
      o.dx.clamp(panel.left, math.max(panel.left, panel.right - w)),
      o.dy.clamp(panel.top, math.max(panel.top, panel.bottom - h)),
      w,
      h,
    );
    var rect = place(candidates.first);
    for (final o in candidates) {
      final r = Rect.fromLTWH(o.dx, o.dy, w, h);
      final fits = panel.contains(r.topLeft) && panel.contains(r.bottomRight);
      if (fits && (avoid == null || !r.overlaps(avoid.inflate(2)))) {
        rect = r;
        break;
      }
    }
    text.paint(canvas, rect.topLeft);
    return rect;
  }

  /// The route stop to stop along great circles, broken where it passes
  /// behind the globe.
  static Path routePath(List<JourneyRouteStop> stops, GlobeProjection p) {
    final path = Path();
    var drawing = false;
    for (var i = 0; i < stops.length - 1; i++) {
      final a = unitVector(stops[i].latitude!, stops[i].longitude!);
      final b = unitVector(stops[i + 1].latitude!, stops[i + 1].longitude!);
      final dot = (a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3).clamp(-1.0, 1.0);
      final omega = math.acos(dot);
      final steps = math.max(1, (omega / (math.pi / 180)).ceil());
      for (var s = (i == 0 ? 0 : 1); s <= steps; s++) {
        final t = s / steps;
        final (x, y, z) = omega < 1e-9 ? a : _slerp(a, b, omega, t);
        final (vx, vy, vz) = p.rotate(x, y, z);
        if (vz <= 0) {
          drawing = false;
          continue;
        }
        final point = p.toScreen(vx, vy);
        if (drawing) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          drawing = true;
        }
      }
    }
    return path;
  }

  static (double, double, double) _slerp(
    (double, double, double) a,
    (double, double, double) b,
    double omega,
    double t,
  ) {
    final sinOmega = math.sin(omega);
    final wa = math.sin((1 - t) * omega) / sinOmega;
    final wb = math.sin(t * omega) / sinOmega;
    return (
      a.$1 * wa + b.$1 * wb,
      a.$2 * wa + b.$2 * wb,
      a.$3 * wa + b.$3 * wb,
    );
  }

  @override
  bool shouldRepaint(JourneyRoutePainter old) =>
      old.camera != camera ||
      old.routes != routes ||
      old.selectedIndex != selectedIndex;
}
