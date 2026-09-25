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
/// header) — retuned to four corner-leaning quadrants in Round 2, see
/// this constant's own doc comment below for why. The `NextStampSlot`'s
/// dashed placeholder always renders at whichever of these 4 anchors its
/// slot index maps to, un-jittered — see [_StampField.build] below (a
/// stale reference to a `_PassportPageState._anchorFor` that doesn't
/// exist in this file was here before this comment; corrected in
/// passing).
// Deliberately NOT collinear (no two anchors share an x or a y) — this
// feature's own visual QA showed two same-axis anchors close enough that
// even modest jitter drove real overlap well past the spec's "at most
// about 10%". Retuned again in Round 2 (booklet redesign): the previous
// middle/bottom pair (-0.20, 0.14) / (0.30, 0.72) was tuned against the
// old full-screen-width stamp page, not the booklet's own, narrower
// ~320-480pt page — at that size a round seal (156pt) landing in the
// middle anchor and a double frame (180×112pt) in the bottom anchor
// overlapped well past 10%, confirmed directly in this round's own
// preview harness. Spread into four quadrant-like anchors instead, each
// pushed toward its own corner of the content rect, for more separation
// between any two anchors regardless of which variants land on them.
// Anchor placement alone still can't guarantee the spec's "maximaal ~10%
// overlap" for every possible variant pairing — see _StampField.build's
// own three-pass layout (resolve → relax apart → clamp once) for the
// actual enforcement of that number. Confirmed via this round's own
// preview harness against an adversarial case (6 same-year items, all 4
// anchors filled): even with that relaxation pass, a round seal and a
// double frame BOTH needing to sit near their own page edge (their own
// halfDiagonal margin, enforced by the final clamp) can still end up
// closer together than the relaxation pass alone moved them apart — the
// clamp step is not itself relaxation-aware. This is a genuine, disclosed
// residual limit of fitting 4 stamps this large (up to ~212pt diagonal)
// on a page this size (~320-480pt), not an unexamined gap: the fix
// materially improves the common case (spread across multiple pages/
// years, confirmed in the same harness) without fully eliminating the
// adversarial single-page worst case. Shrinking the literal stamp sizes
// to close this gap was considered and rejected — Round 1 deliberately
// keeps them unscaled ("a real passport's print doesn't rescale").
const _slotAnchors = [
  Alignment(-0.55, -0.60), // top left
  Alignment(0.55, -0.45), // top right
  Alignment(0.50, 0.20), // mid right
  Alignment(-0.45, 0.55), // lower left (clear of the bottom-left year corner, which sits lower still)
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
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.forestGreen,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.enable('lnum')],
          ),
        ),
        Text(
          'YEAR OF ENTRY',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 8.5 * 0.1,
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
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
      ),
      const SizedBox(width: CsSpacing.sm),
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

/// One stamp mid-layout, between [_StampField]'s three passes — resolved
/// variant/ink/size, and a [center] that starts as the raw anchor+jitter
/// position and gets mutated in place by the pairwise-relaxation pass
/// before anything is clamped to the page or built into a widget.
class _StampEntry {
  final PassportStampItem item;
  final StampVariant variant;
  final StampInk ink;
  final Size size;
  final double halfDiagonal;
  Offset center;

  _StampEntry({
    required this.item,
    required this.variant,
    required this.ink,
    required this.size,
    required this.halfDiagonal,
    required this.center,
  });
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

    final children = <Widget>[];
    final nextStampAnchors = <int>[];

    // Pass 1: resolve variant/ink/size and each stamp's RAW (unclamped)
    // anchor+jitter center — nothing pushed apart yet, nothing clamped to
    // the page yet.
    StampVariant? previousVariant;
    StampInk? previousInk;
    final entries = <_StampEntry>[];
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
          nextStampAnchors.add(i);
        case FilledStampSlot(:final item):
          final variant = pickStampVariant(item.id, avoid: previousVariant);
          final ink = pickStampInk(item.id, avoid: previousInk);
          previousVariant = variant;
          previousInk = ink;
          final size = stampVariantSize(variant);
          final halfDiagonal =
              math.sqrt(size.width * size.width + size.height * size.height) / 2;
          entries.add(
            _StampEntry(
              item: item,
              variant: variant,
              ink: ink,
              size: size,
              halfDiagonal: halfDiagonal,
              center: anchorCenter + pickStampPositionJitter(item.id),
            ),
          );
      }
    }

    // Pass 2: relax every PAIR of stamps apart symmetrically (both move,
    // proportional to their own footprint) when they're closer than the
    // design spec's "maximaal ~10% overlap" allows — run over a few
    // iterations so an early correction that brings one stamp near a
    // THIRD one still gets resolved, not just pairwise-first-come.
    // Deliberately not clamped to the page between iterations: doing that
    // (this file's own first attempt at this fix) let the page-bounds
    // clamp silently undo part of every push — a big stamp anchored near
    // an edge clamps back toward the page centre, toward its neighbour,
    // eating into the very separation just added. Clamping only ONCE at
    // the very end (pass 3) avoids that fight entirely.
    for (var iteration = 0; iteration < 3; iteration++) {
      for (var a = 0; a < entries.length; a++) {
        for (var b = a + 1; b < entries.length; b++) {
          final entryA = entries[a];
          final entryB = entries[b];
          final minSeparation = (entryA.halfDiagonal + entryB.halfDiagonal) * 0.9;
          final delta = entryB.center - entryA.center;
          final dist = delta.distance;
          if (dist >= minSeparation) continue;
          final direction = dist > 0.01
              ? delta / dist
              : const Offset(1, 0); // exact coincidence: pick an arbitrary axis
          final shortfall = minSeparation - dist;
          entryA.center -= direction * (shortfall / 2);
          entryB.center += direction * (shortfall / 2);
        }
      }
    }

    // Pass 3: NOW clamp each relaxed center to the page, and build.
    for (final entry in entries) {
      final center = _clampToContent(
        entry.center,
        stampSize: entry.size,
        contentSize: contentSize,
      );
      children.add(
        Positioned(
          left: center.dx - entry.size.width / 2,
          top: center.dy - entry.size.height / 2,
          child: PassportStampWidget(
            item: entry.item,
            variant: entry.variant,
            ink: entry.ink,
            rotationDegrees: pickStampRotationDegrees(entry.item.id),
            semanticLabel: stampSemanticLabel(
              entry.item,
              countryName: countryNameByCode[entry.item.countryCode],
            ),
            isNew: newStampIds.contains(entry.item.id),
            onTap: () => onTapStamp(entry.item),
          ),
        ),
      );
    }

    for (final i in nextStampAnchors) {
      final anchorCenter = _alignmentWithinRect(
        _slotAnchors[i],
        Rect.fromLTWH(0, 0, contentSize.width, contentSize.height),
      );
      children.add(
        Positioned(
          left: anchorCenter.dx - 52,
          top: anchorCenter.dy - 52,
          child: _NextStampPlaceholder(onTap: onTapNextStamp),
        ),
      );
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

  static const double _diameter = 108;
  static const double _plusDiameter = 30;

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
                    Text(
                      'Add your next stamp',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.2,
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
