import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../data/repositories/journey_repository.dart';
import '../../../models/journey.dart';
import '../../passport/models/passport_stamp_item.dart';
import '../../passport/utils/passport_stamp_semantics.dart';
import '../../passport/utils/passport_stamp_style.dart';
import '../../passport/widgets/passport_stamp.dart';
import '../../passport/widgets/passport_stamp_painters.dart'
    show stampVariantSize;

/// The stamp this journey gives, on its own page. Before a confirmed
/// travel: an uninked outline holding the journey's name, never a drawn
/// stamp, since a real stamp carries a date and there is none yet. After:
/// the Passport's own stamp for each travel, drawn by the same
/// [PassportStampWidget], design, ink and tilt as in the Passport (all
/// derived from the travel's id), so the page and the Passport match. On
/// a Passport page a stamp may step to the next design to avoid matching
/// its neighbour; this page has no neighbours, so it shows the travel's
/// own design.
class JourneyPassportStamps extends StatelessWidget {
  final Journey journey;
  final List<JourneyRoute> routes;
  final List<JourneyTravel> travels;

  const JourneyPassportStamps({
    super.key,
    required this.journey,
    required this.routes,
    required this.travels,
  });

  static const double _stampBox = 150;

  @override
  Widget build(BuildContext context) {
    if (travels.isEmpty) return _Uninked(journey: journey, box: _stampBox);
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: CsSpacing.base,
        runSpacing: CsSpacing.base,
        children: [
          for (final travel in travels.take(4))
            _InkedStamp(
              item: JourneyStampItem(
                JourneyTravelEntry(
                  travel: travel,
                  journey: journey,
                  route: routes
                      .where((r) => r.id == travel.routeId)
                      .firstOrNull,
                ),
              ),
              box: _stampBox,
            ),
        ],
      ),
    );
  }
}

class _InkedStamp extends StatelessWidget {
  final JourneyStampItem item;
  final double box;

  const _InkedStamp({required this.item, required this.box});

  @override
  Widget build(BuildContext context) {
    final variant = pickStampVariant(item.id);
    final size = stampVariantSize(variant);
    return SizedBox.square(
      dimension: box,
      child: Center(
        child: PassportStampWidget(
          item: item,
          variant: variant,
          ink: pickStampInk(item.id),
          rotationDegrees: pickStampRotationDegrees(item.id),
          scale: math.min(1, box * 0.85 / size.longestSide),
          semanticLabel: stampSemanticLabel(item),
          isNew: false,
          // Already on the page it would open; the stamp is a picture here.
          onTap: () {},
        ),
      ),
    );
  }
}

class _Uninked extends StatelessWidget {
  final Journey journey;
  final double box;

  const _Uninked({required this.journey, required this.box});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Not yet in your Passport',
    excludeSemantics: true,
    child: Center(
      child: CustomPaint(
        painter: _DashedRings(),
        child: SizedBox.square(
          dimension: box,
          child: Padding(
            padding: const EdgeInsets.all(CsSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  journey.kindLabel.toUpperCase(),
                  style: CsTypography.eyebrow.copyWith(
                    color: AppColors.secondaryOnDark,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  journey.name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: CsTypography.editorialLead(
                    size: 15,
                  ).copyWith(color: AppColors.taupe, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedRings extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.secondaryOnDark;
    void ring(double radius, double width, double dash, double gap) {
      paint.strokeWidth = width;
      final circumference = 2 * math.pi * radius;
      final step = (dash + gap) / circumference * 2 * math.pi;
      final sweep = dash / circumference * 2 * math.pi;
      for (var a = 0.0; a < 2 * math.pi; a += step) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          a,
          sweep,
          false,
          paint,
        );
      }
    }

    final r = size.shortestSide / 2;
    ring(r - 1, 1.4, 4, 5);
    ring(r - 10, 0.8, 2, 5);
  }

  @override
  bool shouldRepaint(_DashedRings old) => false;
}
