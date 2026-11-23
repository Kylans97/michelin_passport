import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/map_pin.dart';

/// Small circular map badge for one pin. Restaurant/Hotel/Event pins each
/// use a different icon (matching the icon vocabulary already used for
/// Restaurant/Hotel elsewhere — see PassportScreen's `_placesStat` — plus a
/// calendar icon added for Events V2 Step 5) so all three types stay
/// visually distinguishable at a glance without a legend or a differently
/// shaped marker — deepGreen fill, ivory border/icon throughout, no gold.
///
/// [undated] is a visit without a date (`undated_visits`): the same badge
/// with a dashed ring and a see-through fill, so it reads as "been, date
/// still to come" next to the full pins of dated visits.
class VenuePin extends StatelessWidget {
  static const double size = 34;

  final MapPinType type;
  final bool undated;
  final VoidCallback onTap;

  const VenuePin({
    super.key,
    required this.type,
    this.undated = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      MapPinType.restaurant => Icons.restaurant_rounded,
      MapPinType.hotel => Icons.vpn_key_rounded,
      MapPinType.event => Icons.event_rounded,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: undated
              ? AppColors.deepGreen.withValues(alpha: 0.55)
              : AppColors.deepGreen,
          shape: BoxShape.circle,
          border: undated ? null : Border.all(color: AppColors.ivory, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: CustomPaint(
          painter: undated ? const _DashedRingPainter() : null,
          child: Center(child: Icon(icon, color: AppColors.ivory, size: 17)),
        ),
      ),
    );
  }
}

/// The 2 px ivory ring of a full pin, broken into twelve dashes.
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  static const _dashes = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ivory
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 1,
    );
    const step = 2 * math.pi / _dashes;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) => false;
}
