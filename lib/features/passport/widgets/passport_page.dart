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
import 'passport_stamp_painters.dart' show stampVariantSize, verifiedStampSize;

/// The 8 compass directions [_directedAnchor] tries for every stamp/
/// placeholder on a page — replaces the October round's fixed, same-for-
/// every-design corner anchors (kept here in git history if that simpler
/// scheme is ever wanted back). That scheme broke down once the September
/// 2026 stamp redesign made every design physically bigger (up to ~283pt
/// diagonal): pinning every item to the SAME 4 points regardless of its
/// own footprint meant two wide designs sharing the "top" pair (e.g. a
/// 228pt oval and a 176pt round seal) always collided, since 228+176
/// already exceeds this page's own content width on its own — no anchor
/// tuning fixes that, because it isn't an anchor problem, it's that two
/// side-by-side items literally don't both fit at their natural size.
/// [_StampField.build]'s own greedy placement (score each of these 8
/// directions by how much clearance it leaves against everything already
/// placed, keep the best) discovers on its own that two wide items belong
/// stacked north/south rather than crammed side by side at NW/NE — no
/// hand-tuning per combination needed, because the search runs fresh for
/// whatever sizes actually land on a given page.
const _candidateDirections = [
  Alignment(-1, -1), // NW
  Alignment(1, -1), // NE
  Alignment(1, 1), // SE
  Alignment(-1, 1), // SW
  Alignment(0, -1), // N
  Alignment(1, 0), // E
  Alignment(0, 1), // S
  Alignment(-1, 0), // W
];

/// Clearance kept between an item's own edge and the content rect's edge
/// when [_directedAnchor] pushes it as far toward [direction] as it can.
const _edgeMargin = 6.0;

/// Where an item with [halfDiagonal] would sit if pushed as far toward
/// [direction] as its own footprint allows within [contentSize] (leaving
/// [margin] clear of the edge) — a wide oval anchored "east" ends up
/// closer to center than a narrower round seal anchored the same
/// direction would, because there's less room for the oval to be pushed
/// before its own edge would leave the page. This is what makes the
/// search in [_StampField.build] size-aware instead of every design
/// sharing one fixed point regardless of its own footprint.
///
/// Deliberately [halfDiagonal], not half the item's own width/height
/// separately: [_StampField._clampToContent] (the final safety-net pass,
/// after this search has already run) constrains BOTH axes by that same
/// diagonal, to leave room for rotation. An earlier version of this
/// function used plain half-width/half-height here, which is a laxer
/// bound than the clamp's own — so a candidate this function considered
/// safely inside the page could still get yanked back inward by that
/// later, stricter clamp, landing right back in the collision the search
/// had specifically picked that candidate to avoid. Confirmed via this
/// round's own preview harness: two large designs the search had placed
/// at opposite corners with real clearance between them still rendered
/// overlapping, because the clamp silently overrode the second one's
/// position. Matching the clamp's own bound here means the clamp has
/// nothing left to correct in the common case — it stays a pure safety
/// net rather than an active participant in placement.
Offset _directedAnchor(
  Alignment direction,
  double halfDiagonal,
  Size contentSize,
  double margin,
) {
  final maxDx = (contentSize.width / 2 - halfDiagonal - margin).clamp(
    0.0,
    contentSize.width / 2,
  );
  final maxDy = (contentSize.height / 2 - halfDiagonal - margin).clamp(
    0.0,
    contentSize.height / 2,
  );
  return Offset(
    contentSize.width / 2 + direction.x * maxDx,
    contentSize.height / 2 + direction.y * maxDy,
  );
}

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
/// One stamp OR the next-stamp placeholder ([item] null), mid-layout —
/// resolved variant/ink/size (real stamps only), and a [center] that
/// starts unset (`Offset.zero`, assigned by [_StampField.build]'s own
/// greedy search) and gets mutated in place by the pairwise-relaxation
/// pass afterward, before anything is clamped to the page or built into a
/// widget. Both kinds share one class because they compete for the same
/// space on the page and need to be placed against each other, not just
/// against other real stamps — see [_StampField.build]'s own doc comment.
class _Placeable {
  final PassportStampItem? item;
  final StampVariant? variant;
  final StampInk? ink;
  final Size size;
  final double halfDiagonal;

  /// The next-stamp placeholder stays un-jittered (matching every earlier
  /// version of this page) — it's a fixed "add here" affordance, not a
  /// pressed ink stamp.
  final Offset jitter;
  Offset center = Offset.zero;

  _Placeable({
    required this.item,
    required this.variant,
    required this.ink,
    required this.size,
    required this.halfDiagonal,
    required this.jitter,
  });

  bool get isNextStamp => item == null;
}

double _diagonalOf(Size size) =>
    math.sqrt(size.width * size.width + size.height * size.height) / 2;

_Placeable _stampPlaceable({
  required PassportStampItem item,
  required StampVariant variant,
  required StampInk ink,
  required Size size,
}) => _Placeable(
  item: item,
  variant: variant,
  ink: ink,
  size: size,
  halfDiagonal: _diagonalOf(size),
  jitter: pickStampPositionJitter(item.id),
);

_Placeable _nextStampPlaceable() {
  const size = Size(
    _NextStampPlaceholder._diameter,
    _NextStampPlaceholder._diameter,
  );
  return _Placeable(
    item: null,
    variant: null,
    ink: null,
    size: size,
    halfDiagonal: _diagonalOf(size),
    jitter: Offset.zero,
  );
}

/// Places [slots] via [_StampField.build]'s own size-aware greedy search,
/// each real stamp with its own deterministic rotation/jitter, tracking
/// the previously-placed stamp's variant/ink as it goes so no two
/// adjacent stamps on this one page repeat either (see
/// [pickStampVariant]/[pickStampInk]'s own `avoid` parameter).
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

    // Pass 1: resolve variant/ink/size for every non-blank slot, in order
    // — no positions yet. A [BlankStampSlot] contributes nothing (not
    // even a placeholder), matching every earlier version of this page.
    StampVariant? previousVariant;
    StampInk? previousInk;
    final placeable = <_Placeable>[];
    for (final slot in slots) {
      switch (slot) {
        case BlankStampSlot():
          continue;
        case NextStampSlot():
          placeable.add(_nextStampPlaceable());
        case FilledStampSlot(:final item):
          final variant = pickStampVariant(item.id, avoid: previousVariant);
          final ink = pickStampInk(item.id, avoid: previousInk);
          previousVariant = variant;
          previousInk = ink;
          final size = item.verified ? verifiedStampSize : stampVariantSize(variant);
          placeable.add(
            _stampPlaceable(item: item, variant: variant, ink: ink, size: size),
          );
      }
    }

    // Pass 2: place each item greedily, in slot order — for every one of
    // the 8 [_candidateDirections], compute where THIS item's own size
    // would sit (see [_directedAnchor]) and add its own jitter, then score
    // that candidate by the worst-case clearance it leaves against every
    // item already placed (negative = still overlapping, but by less than
    // an unscored candidate would). Keep whichever candidate scores
    // highest. The first item has nothing yet to score against — every
    // candidate ties at +infinity clearance, and the fold below keeps the
    // FIRST one checked (NW) in that case, so a page's first stamp still
    // lands top-left, matching every earlier version of this page.
    for (var i = 0; i < placeable.length; i++) {
      final current = placeable[i];
      final alreadyPlaced = placeable.take(i);
      Offset? best;
      var bestScore = double.negativeInfinity;
      for (final direction in _candidateDirections) {
        final candidate =
            _directedAnchor(direction, current.halfDiagonal, contentSize, _edgeMargin) +
            current.jitter;
        final score = alreadyPlaced.fold<double>(
          double.infinity,
          (worst, other) => math.min(
            worst,
            (candidate - other.center).distance -
                (current.halfDiagonal + other.halfDiagonal),
          ),
        );
        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
      }
      current.center = best!;
    }

    // Pass 3: a light relaxation safety net — the greedy search above
    // already accounts for everything placed BEFORE a given item, but
    // can't retroactively account for what comes after it. Nudge every
    // PAIR still closer than a small clearance apart, symmetrically,
    // proportional to their own footprint, over a few iterations so an
    // early correction that brings one item near a THIRD one still gets
    // resolved. Deliberately not clamped to the page between iterations —
    // clamping mid-loop let a big item anchored near an edge clamp back
    // toward the page centre, toward its neighbour, eating into the very
    // separation just added (this page's own prior round already found
    // this the hard way). Clamping only ONCE at the very end (pass 4)
    // avoids that fight entirely.
    for (var iteration = 0; iteration < 3; iteration++) {
      for (var a = 0; a < placeable.length; a++) {
        for (var b = a + 1; b < placeable.length; b++) {
          final entryA = placeable[a];
          final entryB = placeable[b];
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

    // Pass 4: NOW clamp each relaxed center to the page, and build.
    final children = <Widget>[];
    for (final entry in placeable) {
      final center = _clampToContent(
        entry.center,
        stampSize: entry.size,
        contentSize: contentSize,
      );
      if (entry.isNextStamp) {
        children.add(
          Positioned(
            left: center.dx - entry.size.width / 2,
            top: center.dy - entry.size.height / 2,
            child: _NextStampPlaceholder(onTap: onTapNextStamp),
          ),
        );
        continue;
      }
      final item = entry.item!;
      children.add(
        Positioned(
          left: center.dx - entry.size.width / 2,
          top: center.dy - entry.size.height / 2,
          child: PassportStampWidget(
            item: item,
            variant: entry.variant!,
            ink: entry.ink!,
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
                        style: GoogleFonts.cormorantGaramond(
                          color: AppColors.textSecondary,
                          fontSize: 13,
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
