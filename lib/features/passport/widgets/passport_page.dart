import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../models/passport_stamp_item.dart';
import '../passport_stamp_source.dart';
import '../utils/passport_stamp_semantics.dart';
import '../utils/passport_stamp_style.dart';
import 'passport_stamp.dart';
import 'passport_stamp_painters.dart' show stampVariantSize, verifiedStampSize;
import '../../../core/theme/cs_fonts.dart';

/// Gap kept between neighbouring cells of [stampGridCells], and between a
/// cell and the edge of the stamp field.
const _cellGap = 6.0;

/// The 2×2 grid a stamp page's (up to) 4 items sit in, in slot order:
/// top-left, top-right, bottom-left, bottom-right. Each item owns one
/// cell outright and is scaled to fit inside it (see [stampPlacementIn]),
/// so no two items can overlap however large their designs are or however
/// narrow the page is — the guarantee the earlier free-form placement
/// (a greedy 8-direction search plus pairwise relaxation) could not give
/// once 4 of the larger September 2026 designs shared one page, which is
/// why that page held only 3. [bottomLeftReserve] shortens the
/// bottom-left cell from below, keeping the page's year corner clear.
List<Rect> stampGridCells(Size field, {double bottomLeftReserve = 0}) {
  final cellWidth = (field.width - _cellGap * 3) / 2;
  final cellHeight = (field.height - _cellGap * 3) / 2;
  return [
    for (var row = 0; row < 2; row++)
      for (var col = 0; col < 2; col++)
        Rect.fromLTWH(
          _cellGap + col * (cellWidth + _cellGap),
          _cellGap + row * (cellHeight + _cellGap),
          cellWidth,
          row == 1 && col == 0
              ? math.max(0.0, cellHeight - bottomLeftReserve)
              : cellHeight,
        ),
  ];
}

/// The axis-aligned box an item of [size] covers once rotated by
/// [rotationDegrees] — a round item ([round]) covers the same box at any
/// angle.
Size rotatedStampBounds(
  Size size,
  double rotationDegrees, {
  bool round = false,
}) {
  if (round) return size;
  final radians = rotationDegrees * math.pi / 180;
  final cos = math.cos(radians).abs();
  final sin = math.sin(radians).abs();
  return Size(
    size.width * cos + size.height * sin,
    size.width * sin + size.height * cos,
  );
}

/// Where one item sits inside its own [cell]: the [scale] (never above 1)
/// at which its rotated footprint ([rotatedStampBounds]) still fits the
/// cell, and its [center] — the cell's centre nudged by [jitter] (the
/// ±12pt "hand-stamped" offset, see [pickStampPositionJitter]), but only
/// as far as the room left over in the cell allows, so the jitter never
/// pushes an item out of its own cell.
({double scale, Offset center}) stampPlacementIn(
  Rect cell, {
  required Size size,
  required double rotationDegrees,
  required Offset jitter,
  bool round = false,
}) {
  final bounds = rotatedStampBounds(size, rotationDegrees, round: round);
  final scale = math.min(
    1.0,
    math.min(cell.width / bounds.width, cell.height / bounds.height),
  );
  // max(0, …): when the scale is set by this axis, the leftover is zero
  // up to rounding, and a value like -7e-15 would make clamp() throw.
  final slackX = math.max(0.0, (cell.width - bounds.width * scale) / 2);
  final slackY = math.max(0.0, (cell.height - bounds.height * scale) / 2);
  return (
    scale: scale,
    center:
        cell.center +
        Offset(
          jitter.dx.clamp(-slackX, slackX).toDouble(),
          jitter.dy.clamp(-slackY, slackY).toDouble(),
        ),
  );
}

/// The bound-page card: ivory paper, a faint guilloché ring pattern, the
/// "ENTRIES · X" / "p. NN" header, and up to 4 stamps (or the dashed
/// "Your next stamp" placeholder), one per cell of [stampGridCells], with
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

  /// The calendar year every stamp on this page belongs to — shown as a
  /// corner label (Round 2's own addition). Null renders no year corner
  /// at all, which no real caller does today but keeps this widget usable
  /// standalone (e.g. the existing widget tests, which predate the year
  /// corner and never pass one) without forcing every call site to invent
  /// a year.
  final int? year;

  /// A subtle background-only horizontal drift as this page moves toward
  /// or away from being centered in its pager — see
  /// PassportOpenBookPager's own doc comment for how this is computed.
  /// Purely decorative, defaults to 0 (no drift) for any caller that
  /// isn't itself inside that pager.
  final double parallaxDx;

  /// The rendered footprint — matches whatever size the cover/data page
  /// were given (see PassportCollectionBody), so the whole booklet reads
  /// as one consistent object while paging through it. Defaults to the
  /// data page's own base design size (320×480) for callers — existing
  /// tests among them — that don't care.
  final Size size;

  const PassportPage({
    super.key,
    required this.slots,
    required this.headerLabel,
    required this.pageNumber,
    required this.countryNameByCode,
    required this.newStampIds,
    required this.onTapStamp,
    required this.onTapNextStamp,
    this.year,
    this.parallaxDx = 0,
    this.size = const Size(320, 480),
  });

  static const _cornerLeft = 4.0;
  static const _cornerRight = 14.0;
  static const _headerZoneHeight = 52.0;

  /// How much of the bottom-left cell the "YEAR OF ENTRY" corner takes:
  /// its own ~42pt of text plus its [CsSpacing.md] bottom inset, with a
  /// little room to spare for a taller display face.
  static const _yearZoneHeight = 62.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
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
            // Background only — the parallax drift never touches the
            // header/stamps/year-corner layers above it, so foreground
            // content stays crisp while only the guilloché rings shift.
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(parallaxDx, 0),
                child: RepaintBoundary(
                  child: CustomPaint(painter: _GuillochePainter()),
                ),
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
            if (year != null)
              Positioned(
                left: CsSpacing.lg,
                bottom: CsSpacing.md,
                child: _YearCorner(year: year!),
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
                  bottomLeftReserve: year == null ? 0 : _yearZoneHeight,
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

/// The bottom-left "YEAR OF ENTRY" corner — Round 2's own addition, shown
/// once per stamp page (every stamp on a page shares one year, per
/// [buildYearGroupedStampPages]' own "every year starts a fresh page"
/// rule, so there's never an ambiguous "which year" to show).
class _YearCorner extends StatelessWidget {
  final int year;
  const _YearCorner({required this.year});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$year',
          style: CsFonts.serif(
            color: AppColors.forestGreen,
            fontSize: 23.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'YEAR OF ENTRY',
          style: CsFonts.sans(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 9 * 0.1,
          ),
        ),
      ],
    ),
  );
}

class _PageHeader extends StatelessWidget {
  final String label;
  final int pageNumber;
  const _PageHeader({required this.label, required this.pageNumber});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Expanded + ellipsis: at the smallest booklet size (240pt wide,
      // ~200pt of content width after this page's own margins) even the
      // literal "ENTRIES · VISAS" can sit close to the available width —
      // a real overflow this exact test caught once PassportPage started
      // being given an explicit, sometimes-narrow [size] instead of
      // always stretching to fill whatever full-width test/screen
      // container happened to host it.
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CsFonts.sans(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
      ),
      const SizedBox(width: CsSpacing.sm),
      Text(
        'p. ${pageNumber.toString().padLeft(2, '0')}',
        style: CsFonts.serif(
          color: AppColors.textPrimary,
          fontSize: 13.5,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );
}

/// Lays [slots] out one per cell of [stampGridCells], each real stamp with
/// its own deterministic rotation/jitter, tracking the previously-placed
/// stamp's variant/ink as it goes so no two adjacent stamps on this one
/// page repeat either (see [pickStampVariant]/[pickStampInk]'s own `avoid`
/// parameter). A [BlankStampSlot] leaves its cell empty.
class _StampField extends StatelessWidget {
  final List<PassportStampSlot> slots;
  final Size contentSize;

  /// Height kept clear at the bottom of the bottom-left cell, for the
  /// year corner drawn there.
  final double bottomLeftReserve;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;

  const _StampField({
    required this.slots,
    required this.contentSize,
    required this.bottomLeftReserve,
    required this.countryNameByCode,
    required this.newStampIds,
    required this.onTapStamp,
    required this.onTapNextStamp,
  });

  static const _nextStampSize = Size(
    _NextStampPlaceholder._diameter,
    _NextStampPlaceholder._diameter,
  );

  @override
  Widget build(BuildContext context) {
    if (contentSize.width <= 0 || contentSize.height <= 0) {
      return const SizedBox.shrink();
    }

    final cells = stampGridCells(
      contentSize,
      bottomLeftReserve: bottomLeftReserve,
    );
    StampVariant? previousVariant;
    StampInk? previousInk;
    final children = <Widget>[];
    for (var i = 0; i < slots.length && i < cells.length; i++) {
      final cell = cells[i];
      switch (slots[i]) {
        case BlankStampSlot():
          continue;
        case NextStampSlot():
          final placement = stampPlacementIn(
            cell,
            size: _nextStampSize,
            rotationDegrees: 0,
            jitter: Offset.zero,
            round: true,
          );
          final size = _nextStampSize * placement.scale;
          children.add(
            Positioned(
              left: placement.center.dx - size.width / 2,
              top: placement.center.dy - size.height / 2,
              width: size.width,
              height: size.height,
              child: FittedBox(
                child: _NextStampPlaceholder(onTap: onTapNextStamp),
              ),
            ),
          );
        case FilledStampSlot(:final item):
          final variant = pickStampVariant(item.id, avoid: previousVariant);
          final ink = pickStampInk(item.id, avoid: previousInk);
          previousVariant = variant;
          previousInk = ink;
          final designSize = item.verified
              ? verifiedStampSize
              : stampVariantSize(variant);
          final rotation = pickStampRotationDegrees(item.id);
          final placement = stampPlacementIn(
            cell,
            size: designSize,
            rotationDegrees: rotation,
            jitter: pickStampPositionJitter(item.id),
            round: !item.verified && variant == StampVariant.roundSeal,
          );
          final size = designSize * placement.scale;
          children.add(
            Positioned(
              left: placement.center.dx - size.width / 2,
              top: placement.center.dy - size.height / 2,
              child: PassportStampWidget(
                item: item,
                variant: variant,
                ink: ink,
                rotationDegrees: rotation,
                scale: placement.scale,
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
}

class _NextStampPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _NextStampPlaceholder({required this.onTap});

  // 108 was too small for its own content: the plus-icon (30) + gap (6) +
  // two-line-wrapped "Add your next stamp" (13pt, ~31px tall) fits inside
  // the 108×108 SQUARE bounding box, but a circle inscribed in that square
  // curves away well before its corners — the top of the icon and the
  // bottom line of text, both near the box's own top/bottom edge, ended up
  // wider than the CIRCLE's actual available width at that height, so they
  // visibly poked out past the dashed ring despite technically staying
  // inside the box. Caught only by screenshotting this in a preview
  // harness, not by analyze/tests. 150 (plus an explicit, narrower text
  // width below) gives real margin between the widest wrapped line and the
  // circle's curve at that vertical offset, not just between the text and
  // the outer square.
  static const double _diameter = 150;
  static const double _plusDiameter = 30;
  static const double _labelWidth = 96;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add a visit',
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _plusDiameter,
                      height: _plusDiameter,
                      decoration: const BoxDecoration(
                        color: AppColors.forestGreen,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.background,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        'Add your next stamp',
                        textAlign: TextAlign.center,
                        style: CsFonts.serif(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
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
