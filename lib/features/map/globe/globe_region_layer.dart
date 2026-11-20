import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_fonts.dart';
import 'globe_camera.dart';

const double _earthRadiusKm = 6371;

/// One wine region on the globe: a soft claret patch around a point,
/// reaching about [radiusKm], with its name beside it. Never a border —
/// see 20261101580000_add_wine_regions.sql.
class GlobeRegion {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final int radiusKm;

  /// The member has logged a wine from this region: drawn with a ring.
  final bool marked;

  const GlobeRegion({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    this.marked = false,
  });
}

/// Paints [regions] for one camera: the patches as a gradient each, the
/// names and taps as widgets on top. Regions on the far side fade out the
/// way pins do.
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
  // A patch never shrinks below a tappable size, nor swallows the view.
  static const _minRadius = 14.0;
  static const _maxRadius = 90.0;

  @override
  Widget build(BuildContext context) {
    final projection = GlobeProjection(camera, size);
    final placed = <(GlobeRegion, Offset, double, double)>[];
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
      placed.add((region, position, r, opacity));
    }
    // Labels only once the globe is turned in far enough to read them.
    final showLabels = camera.zoom >= 1.6;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PatchPainter(placed, selectedId: selectedId),
            ),
          ),
        ),
        for (final (region, position, r, opacity) in placed)
          Positioned(
            left: position.dx - math.max(r, 22),
            top: position.dy - math.max(r, 22),
            width: math.max(r, 22) * 2,
            height: math.max(r, 22) * 2,
            child: IgnorePointer(
              ignoring: opacity < 0.5,
              child: Semantics(
                button: true,
                label: '${region.label}, wine region',
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => onTap(region),
                ),
              ),
            ),
          ),
        if (showLabels)
          for (final (region, position, r, opacity) in placed)
            Positioned(
              left: position.dx + math.min(r, 18) * 0.6 + 4,
              top: position.dy - 8,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    region.label,
                    style: CsFonts.sans(
                      color: AppColors.ivory,
                      fontSize: region.id == selectedId ? 12 : 10.5,
                      fontWeight: region.id == selectedId
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

class _PatchPainter extends CustomPainter {
  final List<(GlobeRegion, Offset, double, double)> placed;
  final String? selectedId;

  _PatchPainter(this.placed, {this.selectedId});

  static const _claret = Color(0xFF8E3B47);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (region, position, r, opacity) in placed) {
      final rect = Rect.fromCircle(center: position, radius: r);
      canvas.drawCircle(
        position,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _claret.withValues(alpha: 0.9 * opacity),
              _claret.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
      canvas.drawCircle(
        position,
        region.id == selectedId ? 3.5 : 2.5,
        Paint()..color = AppColors.ivory.withValues(alpha: opacity),
      );
      if (region.marked || region.id == selectedId) {
        canvas.drawCircle(
          position,
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
  bool shouldRepaint(_PatchPainter old) => true;
}
