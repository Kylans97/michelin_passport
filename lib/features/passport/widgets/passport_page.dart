import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../models/passport_stamp_item.dart';
import '../passport_stamp_source.dart';
import '../utils/passport_stamp_semantics.dart';
import '../utils/passport_stamp_style.dart';
import 'passport_stamp.dart';
import 'passport_stamp_painters.dart' show stampVariantSize;

/// One of the 4 fixed positions a stamp can sit near on a page — "top
/// left, top right, middle, bottom" from the design spec, expressed as a
/// fractional anchor within the page's own content rect (below the
/// header). The `NextStampSlot`'s dashed placeholder always renders at
/// whichever of these 4 anchors its slot index maps to, un-jittered — see
/// [_PassportPageState._anchorFor].
// Deliberately NOT collinear (middle/bottom don't share top-left/top-
// right's x=∓0.42, and don't share each other's x either) — this
// feature's own visual QA showed two same-x anchors close enough in y
// that even modest jitter drove real overlap well past the spec's "at
// most about 10%". Staggering every anchor's x keeps any two stamps'
// bounding boxes from stacking along the same axis.
const _slotAnchors = [
  Alignment(-0.44, -0.55), // top left
  Alignment(0.44, -0.52), // top right
  Alignment(-0.20, 0.14), // middle
  Alignment(0.30, 0.72), // bottom
];

/// The bound-page card: ivory paper, a faint guilloché ring pattern, the
/// "ENTRIES · X" / "p. NN" header, and up to 4 stamps (or the dashed
/// "Your next stamp" placeholder) placed near [_slotAnchors] with
/// deterministic per-stamp rotation/jitter. A pure presentation widget —
/// [slots] is already exactly what this one page should show (see
/// [paginateStamps]); this widget owns none of the pagination or
/// filtering logic itself.
class PassportPage extends StatelessWidget {
  final List<PassportStampSlot> slots;
  final String headerLabel;
  final int pageNumber;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;

  const PassportPage({
    super.key,
    required this.slots,
    required this.headerLabel,
    required this.pageNumber,
    required this.countryNameByCode,
    required this.newStampIds,
    required this.onTapStamp,
    required this.onTapNextStamp,
  });

  static const double height = 460;
  static const _cornerLeft = 4.0;
  static const _cornerRight = 14.0;
  static const _headerZoneHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_cornerLeft),
          bottomLeft: Radius.circular(_cornerLeft),
          topRight: Radius.circular(_cornerRight),
          bottomRight: Radius.circular(_cornerRight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_cornerLeft),
          bottomLeft: Radius.circular(_cornerLeft),
          topRight: Radius.circular(_cornerRight),
          bottomRight: Radius.circular(_cornerRight),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _GuillochePainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.lg,
                CsSpacing.md,
                CsSpacing.lg,
                0,
              ),
              child: _PageHeader(label: headerLabel, pageNumber: pageNumber),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _headerZoneHeight,
              bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints) => _StampField(
                  slots: slots,
                  contentSize: constraints.biggest,
                  countryNameByCode: countryNameByCode,
                  newStampIds: newStampIds,
                  onTapStamp: onTapStamp,
                  onTapNextStamp: onTapNextStamp,
                ),
              ),
            ),
            // A faint inward gradient along the spine (left edge) — Flutter
            // has no native inner-shadow primitive, so this is the standard
            // fake: a translucent-to-transparent gradient laid over the
            // content, wide enough to read as a recess without visibly
            // banding.
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 14,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0x33000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String label;
  final int pageNumber;
  const _PageHeader({required this.label, required this.pageNumber});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
        ),
      ),
      Text(
        'p. ${pageNumber.toString().padLeft(2, '0')}',
        style: GoogleFonts.cormorantGaramond(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );
}

/// Places [slots] near their [_slotAnchors], each with its own
/// deterministic rotation/jitter, tracking the previously-placed stamp's
/// variant/ink as it goes so no two adjacent stamps on this one page
/// repeat either (see [pickStampVariant]/[pickStampInk]'s own `avoid`
/// parameter).
class _StampField extends StatelessWidget {
  final List<PassportStampSlot> slots;
  final Size contentSize;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;

  const _StampField({
    required this.slots,
    required this.contentSize,
    required this.countryNameByCode,
    required this.newStampIds,
    required this.onTapStamp,
    required this.onTapNextStamp,
  });

  @override
  Widget build(BuildContext context) {
    if (contentSize.width <= 0 || contentSize.height <= 0) {
      return const SizedBox.shrink();
    }

    StampVariant? previousVariant;
    StampInk? previousInk;
    final children = <Widget>[];

    for (var i = 0; i < slots.length && i < _slotAnchors.length; i++) {
      final slot = slots[i];
      final anchorCenter = _alignmentWithinRect(
        _slotAnchors[i],
        Rect.fromLTWH(0, 0, contentSize.width, contentSize.height),
      );

      switch (slot) {
        case BlankStampSlot():
          continue;
        case NextStampSlot():
          children.add(
            Positioned(
              left: anchorCenter.dx - 52,
              top: anchorCenter.dy - 52,
              child: _NextStampPlaceholder(onTap: onTapNextStamp),
            ),
          );
        case FilledStampSlot(:final item):
          final variant = pickStampVariant(item.id, avoid: previousVariant);
          final ink = pickStampInk(item.id, avoid: previousInk);
          previousVariant = variant;
          previousInk = ink;
          final size = stampVariantSize(variant);
          final jitter = pickStampPositionJitter(item.id);
          final center = _clampToContent(
            anchorCenter + jitter,
            stampSize: size,
            contentSize: contentSize,
          );
          children.add(
            Positioned(
              left: center.dx - size.width / 2,
              top: center.dy - size.height / 2,
              child: PassportStampWidget(
                item: item,
                variant: variant,
                ink: ink,
                rotationDegrees: pickStampRotationDegrees(item.id),
                semanticLabel: stampSemanticLabel(
                  item,
                  countryName: countryNameByCode[item.countryCode],
                ),
                isNew: newStampIds.contains(item.id),
                onTap: () => onTapStamp(item),
              ),
            ),
          );
      }
    }

    return Stack(children: children);
  }

  /// Keeps a jittered stamp's whole bounding box — inflated by its own
  /// diagonal rather than half its width/height, a safety margin generous
  /// enough to cover any rotation in [-12°, 8°] — fully inside
  /// [contentSize]: never off the page, never back up into the header
  /// zone above (that zone is already excluded from [contentSize] itself
  /// — see [PassportPage]'s `Positioned(top: _headerZoneHeight, ...)`).
  Offset _clampToContent(
    Offset center, {
    required Size stampSize,
    required Size contentSize,
  }) {
    final diagonal =
        math.sqrt(stampSize.width * stampSize.width + stampSize.height * stampSize.height) /
        2;
    final minX = diagonal.clamp(0, contentSize.width / 2);
    final maxX = (contentSize.width - diagonal).clamp(minX, contentSize.width);
    final minY = diagonal.clamp(0, contentSize.height / 2);
    final maxY = (contentSize.height - diagonal).clamp(
      minY,
      contentSize.height,
    );
    return Offset(
      center.dx.clamp(minX, maxX).toDouble(),
      center.dy.clamp(minY, maxY).toDouble(),
    );
  }
}

Offset _alignmentWithinRect(Alignment alignment, Rect rect) => Offset(
  rect.left + (alignment.x + 1) / 2 * rect.width,
  rect.top + (alignment.y + 1) / 2 * rect.height,
);

class _NextStampPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _NextStampPlaceholder({required this.onTap});

  static const double _diameter = 104;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Your next stamp — explore places to visit',
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _diameter,
          height: _diameter,
          child: ExcludeSemantics(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(_diameter, _diameter),
                  painter: _DashedCirclePainter(),
                ),
                Text(
                  'Your next\nstamp',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    const dashLength = 6.0;
    const gapLength = 5.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final paint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final anglePerDash = (2 * math.pi) / dashCount;
    final dashAngle = anglePerDash * (dashLength / (dashLength + gapLength));
    for (var i = 0; i < dashCount; i++) {
      final start = i * anglePerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}

/// Fine concentric rings anchored just below the page's bottom-centre —
/// "1px lines, 8px apart, gold at 9%" from the design spec, drawn as
/// literal full circles (not the fading corner-cluster ellipses
/// journey_card.dart's own security-paper texture uses — a deliberately
/// different, simpler motif here: one steady ring pattern, not fading,
/// matching the spec's plain "concentric rings" description). Relies on
/// the caller's own [ClipRRect] (see [PassportPage.build]) to clip rings
/// to the page's rounded shape — no clipping done here.
class _GuillochePainter extends CustomPainter {
  const _GuillochePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height + 24);
    final maxRadius = (center - Offset.zero).distance + size.width;
    final paint = Paint()
      ..color = AppColors.stampGuillocheLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 8.0;
    var radius = spacing;
    while (radius < maxRadius) {
      canvas.drawCircle(center, radius, paint);
      radius += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _GuillochePainter oldDelegate) => false;
}
