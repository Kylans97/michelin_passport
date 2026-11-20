import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_fonts.dart';
import 'globe_camera.dart';

const double _earthRadiusKm = 6371;

/// One wine region on the globe. With an [outline] it is drawn as its own
/// shape — the union of the municipalities in its official specification
/// (20261101590000_add_wine_region_outlines.sql) — once that shape is big
/// enough on screen to read; before that, and for a region without an
/// outline, as a soft claret patch around its point reaching about
/// [radiusKm].
class GlobeRegion {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final int radiusKm;

  /// Polygons of rings of (longitude, latitude); empty for none.
  final List<List<List<(double, double)>>> outline;

  /// The member has logged a wine from this region: drawn with a ring.
  final bool marked;

  const GlobeRegion({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    this.outline = const [],
    this.marked = false,
  });

  /// The outline's corners, for flying in on the whole region; the point
  /// alone when there is no outline.
  List<(double, double)> get extent {
    if (outline.isEmpty) return [(latitude, longitude)];
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final polygon in outline) {
      for (final (lng, lat) in polygon.first) {
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
        minLng = math.min(minLng, lng);
        maxLng = math.max(maxLng, lng);
      }
    }
    return [
      (minLat, minLng),
      (minLat, maxLng),
      (maxLat, minLng),
      (maxLat, maxLng),
    ];
  }
}

/// A region as placed for one camera.
class _Placed {
  final GlobeRegion region;
  final Offset position;
  final double opacity;

  /// The projected outline, or null when it is drawn as a patch.
  final Path? shape;
  final double patchRadius;

  _Placed(
    this.region,
    this.position,
    this.opacity,
    this.shape,
    this.patchRadius,
  );

  bool hit(Offset point) => shape != null
      ? shape!.contains(point) || (point - position).distance < 18
      : (point - position).distance < math.max(patchRadius, 22);
}

/// Paints [regions] for one camera: the shapes and patches in one painter,
/// the names as widgets on top, and one tap target that finds the region
/// under the finger. Regions on the far side fade out the way pins do.
class GlobeRegionLayer extends StatelessWidget {
  final List<GlobeRegion> regions;
  final GlobeCamera camera;
  final Size size;
  final String? selectedId;
  final ValueChanged<GlobeRegion> onTap;

  const GlobeRegionLayer({
    super.key,
    required this.regions,
    required this.camera,
    required this.size,
    required this.onTap,
    this.selectedId,
  });

  // Depth at which a region starts to show, and is fully shown.
  static const _hideDepth = 0.12;
  static const _fullDepth = 0.35;
  // A patch never swallows the view. It stays visible but true to scale: several small Dutch regions
  // side by side would otherwise merge into one blur. Taps keep their own
  // 44 pt target regardless.
  static const _minRadius = 5.0;
  static const _maxRadius = 90.0;
  // Below this size on screen an outline reads as a speck: draw the patch.
  static const _minShapeSize = 8.0;

  @override
  Widget build(BuildContext context) {
    final projection = GlobeProjection(camera, size);
    final placed = <_Placed>[];
    for (final region in regions) {
      final (position, z) = projection.project(
        region.latitude,
        region.longitude,
      );
      if (z <= _hideDepth) continue;
      final opacity = ((z - _hideDepth) / (_fullDepth - _hideDepth)).clamp(
        0.0,
        1.0,
      );
      final r = (region.radiusKm / _earthRadiusKm * projection.radius).clamp(
        _minRadius,
        _maxRadius,
      );
      Path? shape;
      if (region.outline.isNotEmpty) {
        final path = Path()..fillType = PathFillType.evenOdd;
        for (final polygon in region.outline) {
          for (final ring in polygon) {
            for (var i = 0; i < ring.length; i++) {
              final (lng, lat) = ring[i];
              final (p, _) = projection.project(lat, lng);
              i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
            }
            path.close();
          }
        }
        if (path.getBounds().longestSide >= _minShapeSize) shape = path;
      }
      placed.add(_Placed(region, position, opacity, shape, r));
    }
    // Large shapes first, then smaller ones, then patches, so a region
    // inside another (Vijlen and Voerendaalse Bergen in Mergelland) is
    // painted on top and, hit-tested from the top, takes the tap.
    double extentOf(_Placed p) {
      final shape = p.shape;
      if (shape == null) return -1;
      final b = shape.getBounds();
      return b.width * b.height;
    }

    placed.sort((a, b) => extentOf(b).compareTo(extentOf(a)));
    // Labels only once the globe is turned in far enough to read them, and
    // never on top of each other: a name that would overlap one already
    // placed waits until the globe is zoomed in further. The selected
    // region and the nearest-to-the-viewer ones go first. A drawn shape
    // carries its name on its point; a patch beside its dot.
    final labels = <(_Placed, Offset)>[];
    if (camera.zoom >= 2.5) {
      final placedRects = <Rect>[];
      final ordered = [...placed]
        ..sort((a, b) {
          if (a.region.id == selectedId) return -1;
          if (b.region.id == selectedId) return 1;
          return b.opacity.compareTo(a.opacity);
        });
      for (final entry in ordered) {
        final width = entry.region.label.length * 6.4 + 4;
        final topLeft = entry.shape != null
            ? entry.position - Offset(width / 2, 8)
            : entry.position +
                  Offset(math.min(entry.patchRadius, 18) * 0.6 + 4, -8);
        final rect = topLeft & Size(width, 16);
        // Nor across another region's dot (Bordeaux over the Rhône).
        final coversDot = placed.any(
          (o) =>
              o.region.id != entry.region.id &&
              o.shape == null &&
              rect.inflate(3).contains(o.position),
        );
        if (coversDot || placedRects.any((p) => p.overlaps(rect))) continue;
        placedRects.add(rect);
        labels.add((entry, topLeft));
      }
    }
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              // The topmost region under the finger: the last one painted,
              // the selected one first.
              for (final entry in placed.reversed) {
                if (entry.opacity >= 0.5 && entry.hit(details.localPosition)) {
                  onTap(entry.region);
                  return;
                }
              }
            },
            child: CustomPaint(
              painter: _RegionPainter(placed, selectedId: selectedId),
            ),
          ),
        ),
        for (final entry in placed)
          Positioned(
            left: entry.position.dx - 22,
            top: entry.position.dy - 22,
            width: 44,
            height: 44,
            child: Semantics(
              button: true,
              label: '${entry.region.label}, wine region',
              onTap: () => onTap(entry.region),
              child: const IgnorePointer(child: SizedBox.expand()),
            ),
          ),
        for (final (entry, topLeft) in labels)
          Positioned(
            left: topLeft.dx,
            top: topLeft.dy,
            child: IgnorePointer(
              child: Opacity(
                opacity: entry.opacity,
                child: Text(
                  entry.region.label,
                  style: CsFonts.sans(
                    color: AppColors.ivory,
                    fontSize: entry.region.id == selectedId ? 12 : 10.5,
                    fontWeight: entry.region.id == selectedId
                        ? FontWeight.w600
                        : FontWeight.w500,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RegionPainter extends CustomPainter {
  final List<_Placed> placed;
  final String? selectedId;

  _RegionPainter(this.placed, {this.selectedId});

  static const _claret = Color(0xFF8E3B47);

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in placed) {
      final selected = entry.region.id == selectedId;
      final opacity = entry.opacity;
      final shape = entry.shape;
      if (shape != null) {
        canvas.drawPath(
          shape,
          Paint()
            ..color = _claret.withValues(
              alpha: (selected ? 0.72 : 0.5) * opacity,
            ),
        );
        canvas.drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected || entry.region.marked ? 1.4 : 0.8
            ..strokeJoin = StrokeJoin.round
            ..color =
                (selected || entry.region.marked ? AppColors.ivory : _claret)
                    .withValues(alpha: opacity),
        );
        continue;
      }
      // A blurred disc rather than a gradient shader: soft-edged and
      // cheap, and it renders the same on every backend.
      final r = entry.patchRadius;
      canvas.drawCircle(
        entry.position,
        r * 0.6,
        Paint()
          ..color = _claret.withValues(alpha: 0.75 * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
      );
      canvas.drawCircle(
        entry.position,
        selected ? 3.5 : 2.5,
        Paint()..color = AppColors.ivory.withValues(alpha: opacity),
      );
      if (entry.region.marked || selected) {
        canvas.drawCircle(
          entry.position,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = AppColors.ivory.withValues(alpha: opacity),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RegionPainter old) => true;
}
