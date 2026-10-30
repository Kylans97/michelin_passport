import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'globe_camera.dart';
import 'globe_outlines.dart';

/// Paints the globe: a forest-green sea, ivory land, a faint graticule and a
/// soft rim of light. Countries in [visitedCountryCodes] are drawn in full
/// ivory; every other country is a quieter, translucent ivory — so the
/// places you've been read as lit, without a second accent colour (gold
/// stays reserved for stars and Keys).
class GlobePainter extends CustomPainter {
  final ValueNotifier<GlobeCamera> camera;
  final GlobeOutlines? outlines;
  final Set<String> visitedCountryCodes;

  GlobePainter({
    required this.camera,
    required this.outlines,
    required this.visitedCountryCodes,
  }) : super(repaint: camera);

  static const _ocean = [
    AppColors.forestGreen,
    AppColors.deepGreen,
    AppColors.darkGreen,
  ];
  static final _visitedLand = Paint()..color = AppColors.ivory;
  static final _otherLand = Paint()
    ..color = AppColors.ivory.withValues(alpha: 0.34);
  static final _border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..color = AppColors.deepGreen.withValues(alpha: 0.35);
  static final _graticule = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..color = AppColors.ivory.withValues(alpha: 0.07);

  @override
  void paint(Canvas canvas, Size size) {
    final projection = GlobeProjection(camera.value, size);
    final center = projection.center;
    final r = projection.radius;
    final disc = Rect.fromCircle(center: center, radius: r);

    // Atmosphere: a soft ivory halo just outside the disc.
    canvas.drawCircle(
      center,
      r * 1.07,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.ivory.withValues(alpha: 0.10),
            AppColors.ivory.withValues(alpha: 0),
          ],
          stops: [1 / 1.07, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.07)),
    );

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: _ocean,
          stops: [0, 0.6, 1],
        ).createShader(disc),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    _paintGraticule(canvas, projection);

    final countries = outlines?.countries ?? const <GlobeCountry>[];
    final visited = Path()..fillType = PathFillType.evenOdd;
    final other = Path()..fillType = PathFillType.evenOdd;
    for (final country in countries) {
      // Skip a country that lies wholly on the far side: its centre is more
      // than 90° plus its own radius away from the middle of the view.
      final (_, _, cz) = projection.rotate(
        country.centerX,
        country.centerY,
        country.centerZ,
      );
      if (cz < -math.sin(math.min(country.radius, math.pi / 2))) continue;
      final target = visitedCountryCodes.contains(country.code)
          ? visited
          : other;
      for (final ring in country.rings) {
        _addRing(target, ring, projection);
      }
    }
    canvas.drawPath(other, _otherLand);
    canvas.drawPath(visited, _visitedLand);
    canvas.drawPath(other, _border);
    canvas.drawPath(visited, _border);

    // Shade towards the rim so the disc reads as a sphere.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.15,
          colors: [
            Colors.transparent,
            Colors.transparent,
            AppColors.heroGradientEnd.withValues(alpha: 0.55),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(disc),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = AppColors.ivory.withValues(alpha: 0.18),
    );
  }

  void _paintGraticule(Canvas canvas, GlobeProjection projection) {
    final path = Path();
    void line(Iterable<(double, double)> points) {
      var drawing = false;
      for (final (lat, lon) in points) {
        final (p, z) = projection.project(lat, lon);
        if (z <= 0) {
          drawing = false;
        } else if (drawing) {
          path.lineTo(p.dx, p.dy);
        } else {
          path.moveTo(p.dx, p.dy);
          drawing = true;
        }
      }
    }

    for (var lat = -60.0; lat <= 60; lat += 30) {
      line([for (var lon = -180.0; lon <= 180; lon += 3) (lat, lon)]);
    }
    for (var lon = -180.0; lon < 180; lon += 30) {
      line([for (var lat = -84.0; lat <= 84; lat += 3) (lat, lon)]);
    }
    canvas.drawPath(path, _graticule);
  }

  /// Adds one ring to [path], clipped to the visible hemisphere. Where the
  /// ring passes behind the globe, the hidden stretch is replaced by an arc
  /// along the rim between the exit and re-entry points, swept the same way
  /// round as the hidden stretch itself travels — so a coastline that wraps
  /// over the horizon still encloses the right side.
  static void _addRing(Path path, Float32List ring, GlobeProjection p) {
    final n = ring.length ~/ 3 - 1; // last point repeats the first
    if (n < 3) return;
    final xs = Float64List(n), ys = Float64List(n), zs = Float64List(n);
    var start = -1;
    var anyHidden = false;
    for (var i = 0; i < n; i++) {
      final (x, y, z) = p.rotate(ring[i * 3], ring[i * 3 + 1], ring[i * 3 + 2]);
      xs[i] = x;
      ys[i] = y;
      zs[i] = z;
      if (z > 0) {
        if (start < 0) start = i;
      } else {
        anyHidden = true;
      }
    }
    if (start < 0) return;

    final cx = p.center.dx, cy = p.center.dy, r = p.radius;
    // Skips points closer than ~0.6 px to the last one drawn — at low zoom
    // most of a 1:50m coastline collapses into a handful of pixels.
    var lastX = double.nan, lastY = double.nan;
    void emit(double x, double y, {bool force = false}) {
      final sx = cx + x * r, sy = cy - y * r;
      if (!force && (sx - lastX).abs() < 0.6 && (sy - lastY).abs() < 0.6) {
        return;
      }
      if (lastX.isNaN) {
        path.moveTo(sx, sy);
      } else {
        path.lineTo(sx, sy);
      }
      lastX = sx;
      lastY = sy;
    }

    if (!anyHidden) {
      for (var i = 0; i < n; i++) {
        emit(xs[i], ys[i]);
      }
      path.close();
      return;
    }

    double exitAngle = 0, prevAngle = 0, sweep = 0;
    emit(xs[start], ys[start], force: true);
    for (var k = 0; k < n; k++) {
      final a = (start + k) % n, b = (start + k + 1) % n;
      final za = zs[a], zb = zs[b];
      if (za > 0 && zb > 0) {
        emit(xs[b], ys[b], force: b == start);
      } else if (za > 0) {
        final t = za / (za - zb);
        exitAngle = math.atan2(
          ys[a] + (ys[b] - ys[a]) * t,
          xs[a] + (xs[b] - xs[a]) * t,
        );
        emit(math.cos(exitAngle), math.sin(exitAngle), force: true);
        prevAngle = exitAngle;
        sweep = 0;
        sweep += _wrap(math.atan2(ys[b], xs[b]) - prevAngle);
        prevAngle = math.atan2(ys[b], xs[b]);
      } else if (zb <= 0) {
        final angle = math.atan2(ys[b], xs[b]);
        sweep += _wrap(angle - prevAngle);
        prevAngle = angle;
      } else {
        final t = za / (za - zb);
        final entryAngle = math.atan2(
          ys[a] + (ys[b] - ys[a]) * t,
          xs[a] + (xs[b] - xs[a]) * t,
        );
        sweep += _wrap(entryAngle - prevAngle);
        final steps = (sweep.abs() / (math.pi / 36)).ceil();
        for (var s = 1; s <= steps; s++) {
          final angle = exitAngle + sweep * s / steps;
          emit(math.cos(angle), math.sin(angle), force: s == steps);
        }
        emit(xs[b], ys[b], force: b == start);
      }
    }
    path.close();
  }

  static double _wrap(double d) {
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d <= -math.pi) {
      d += 2 * math.pi;
    }
    return d;
  }

  @override
  bool shouldRepaint(GlobePainter old) =>
      old.outlines != outlines ||
      old.camera != camera ||
      !_sameSet(old.visitedCountryCodes, visitedCountryCodes);

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
