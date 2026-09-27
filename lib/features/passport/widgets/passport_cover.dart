import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_masthead_logo.dart';
import '../passport_booklet_data.dart';
import 'passport_page_dots.dart';

/// The closed cover of the one continuous [PassportVolume] — no more
/// per-year covers, so [depth] is always 0 in practice now (see
/// [PassportCoverStack]'s own doc comment); the parameter stays because a
/// single-face render is still exactly what this widget does.
///
/// Chocolate leather (see [AppColors.coverLeather]/[coverLeatherDeep]), not
/// a flat lerped green — a September 2026 revision to the original build.
/// Gold foil now covers the logo mark, the MANTELIER wordmark, the italic
/// tagline, AND the member number — an explicit, confirmed exception to
/// this app's general "no gold text" rule, asked for by name for this one
/// ornamental object (a bound cover, not a UI control) after this file
/// previously kept the tagline/number ivory as an interpretive call nobody
/// had actually asked for either way. The two solid gold border strokes
/// that used to sit under [_CoverBorderPainter] are gone too, replaced by
/// the single dashed gold saddle-stitch ([_SaddleStitchPainter]) — the
/// brief is explicit that nothing else draws a line/frame on the leather.
class PassportCoverFace extends StatelessWidget {
  final PassportVolume volume;

  // Null only for the handful of pre-existing test accounts the member-
  // number backfill deliberately left unnumbered (see the migration's own
  // header) — never expected for a real member.
  final int? memberNumber;

  /// 0 = the true front cover (full color, full contrast). Each step back
  /// in the physical stack lightens the face slightly toward
  /// [AppColors.forestGreen] — see [PassportCoverStack]'s own doc comment
  /// for why depth is capped rather than unbounded.
  final int depth;

  /// The rendered footprint — the same [Size] the data page (and, in
  /// Round 2, every stamp page) is given, so the booklet reads as one
  /// consistent physical object while paging through it rather than
  /// changing shape from screen to screen. Defaults to the original
  /// design size for callers (tests, older previews) that don't care.
  final Size size;

  const PassportCoverFace({
    super.key,
    required this.volume,
    required this.memberNumber,
    this.depth = 0,
    this.size = const Size(baseWidth, baseHeight),
  });

  /// The design's own reference size, at the original (pre "make it
  /// bigger") scale — kept as the aspect-ratio source every caller that
  /// computes a responsive [size] derives from, and as the default above.
  static const double baseWidth = 270;
  static const double baseHeight = 410;

  /// Corners: 6 left (spine) / 16 right — mirrored by
  /// [PassportBackCoverFace]'s own `_radius` for the true back of the
  /// book, whose spine sits on the right instead.
  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(6),
    bottomLeft: Radius.circular(6),
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    final t = (depth * 0.16).clamp(0.0, 0.6);
    final leatherLight = Color.lerp(AppColors.coverLeather, AppColors.coverLeatherDeep, t)!;
    final leatherDark = Color.lerp(AppColors.coverLeatherDeep, AppColors.coverLeatherEdge, t)!;
    final foil = depth == 0 ? AppColors.goldLight : AppColors.goldLight.withValues(alpha: 0.7);

    return Semantics(
      label: depth == 0
          ? 'Passport, ${volume.entries} ${volume.entries == 1 ? "entry" : "entries"}. '
                'Double-tap to open.'
          : null,
      excludeSemantics: depth != 0,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          // Radial gloss from the top-left, per the brief's "zachte
          // radiale glans linksboven" — a designed approximation of its
          // OKLCH color-mix gradient (see AppColors.coverLeather's own
          // doc comment for why these are plain hex, not OKLCH tokens).
          gradient: RadialGradient(
            center: const Alignment(-0.6, -0.7),
            radius: 1.3,
            colors: [leatherLight, leatherDark],
          ),
          border: Border.all(color: AppColors.coverLeatherEdge, width: 1),
          borderRadius: _radius,
          boxShadow: depth == 0
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            children: [
              // The gold saddle-stitch — the ONLY line/frame drawn on the
              // leather now (see this class's own doc comment for why the
              // old double gold border strokes are gone).
              Positioned.fill(
                child: CustomPaint(
                  painter: _SaddleStitchPainter(
                    radius: _radius,
                    color: AppColors.gold.withValues(alpha: depth == 0 ? 0.7 : 0.4),
                  ),
                ),
              ),
              // Spine shadow, same fake-inner-shadow technique PassportPage
              // already uses for its own left edge.
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 18,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0x40000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
              if (depth == 0) ...[
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CsMastheadLogo.cover(tint: AppColors.gold),
                      const SizedBox(height: 18),
                      Text(
                        'MANTELIER',
                        style: GoogleFonts.cormorantGaramond(
                          color: AppColors.gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 20 * 0.32,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Passeport gastronomique',
                        style: GoogleFonts.cormorantGaramond(
                          color: foil,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                // No more COMPLETE/year label here — there's only ever one
                // continuous booklet now, so the bottom corner shows just
                // the member number, right-aligned (previously the right
                // half of a spaceBetween row whose left half was the now-
                // removed volume label).
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        memberNumber == null ? 'NO. —' : 'NO. $memberNumber',
                        style: GoogleFonts.inter(
                          color: foil,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 10.5 * 0.14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // depth > 0 (a peeking sliver behind the front cover) never
              // happens any more — buildPassportVolumes always returns at
              // most one volume post-refactor, so PassportCoverStack's own
              // peekCount is always 0 — but depth stays a real parameter
              // (still drives the leather gradient's lerp above) rather
              // than being torn out, since a future product decision to
              // peek something else behind the cover again wouldn't need
              // to touch this widget at all, only PassportCoverStack.
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed gold "saddle stitch" — the only line drawn on the leather,
/// front or back (see [PassportCoverFace]/[PassportBackCoverFace]'s own
/// doc comments for why the old solid double border is gone). Follows
/// [radius]'s own rounded-rect shape, inset 10pt from the edge, so it
/// tracks whichever corner the caller mirrors the spine to. Dash 4 / gap 3
/// / stroke 1.5, per the brief.
class _SaddleStitchPainter extends CustomPainter {
  final BorderRadius radius;
  final Color color;
  const _SaddleStitchPainter({required this.radius, required this.color});

  static const double _inset = 10;
  static const double _dashLength = 4;
  static const double _gapLength = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _inset,
      _inset,
      size.width - _inset * 2,
      size.height - _inset * 2,
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    final path = Path()..addRRect(radius.toRRect(rect));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + _dashLength < metric.length
            ? distance + _dashLength
            : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SaddleStitchPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

/// The booklet's true outer back — reached by swiping one page past
/// [PassportBackCoverPage] (the ivory content page with the "View all
/// visits" link/filters; see passport_back_cover_page.dart), where the
/// booklet visually runs out of pages onto its own leather back. Same
/// chocolate leather and gold saddle-stitch as [PassportCoverFace],
/// mirrored: the spine sits on the RIGHT here (this is the back, so its
/// bound edge is the opposite side from the front cover's), corners 16
/// left / 6 right instead of 6 left / 16 right. No foil branding — the
/// brief is explicit this face carries only a blind (foil-free) embossed
/// "M" and a plain gold property-of footer, never the front's logo/
/// wordmark/tagline treatment.
class PassportBackCoverFace extends StatelessWidget {
  final String holderName;
  final int? memberNumber;
  final Size size;

  const PassportBackCoverFace({
    super.key,
    required this.holderName,
    required this.memberNumber,
    this.size = const Size(PassportCoverFace.baseWidth, PassportCoverFace.baseHeight),
  });

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    topRight: Radius.circular(6),
    bottomRight: Radius.circular(6),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Back cover.',
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment(-0.6, -0.7),
            radius: 1.3,
            colors: [AppColors.coverLeather, AppColors.coverLeatherDeep],
          ),
          border: Border.all(color: AppColors.coverLeatherEdge, width: 1),
          borderRadius: _radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SaddleStitchPainter(
                    radius: _radius,
                    color: AppColors.gold.withValues(alpha: 0.7),
                  ),
                ),
              ),
              // Spine shadow on the right — mirrored from the front
              // cover's own left-edge treatment.
              const Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 18,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0x40000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
              const Center(child: _BlindEmbossedM()),
              Positioned(
                left: 22,
                right: 22,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PROPERTY OF THE HOLDER',
                      style: GoogleFonts.inter(
                        color: AppColors.goldLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 9 * 0.12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      memberNumber == null
                          ? '$holderName · No. —'
                          : '$holderName · No. $memberNumber',
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.gold,
                        fontSize: 17,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'MANTELIER',
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 13 * 0.32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The back cover's own foil-free "M" — two overlapping tinted copies of
/// the same monochrome SVG mark ([CsMastheadLogo] ships no separate
/// embossed asset), the lighter one offset a touch lower so a sliver of it
/// catches "light" beneath the darker top copy: a cheap, dependency-free
/// stand-in for an actual emboss/shadow render, matching the brief's own
/// "donkerdere leertint met een 1px lichte onderrand."
class _BlindEmbossedM extends StatelessWidget {
  const _BlindEmbossedM();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 1.2),
          child: const CsMastheadLogo(size: 44, tint: AppColors.coverLeatherEmbossHighlight),
        ),
        const CsMastheadLogo(size: 44, tint: AppColors.coverLeatherEmboss),
      ],
    ),
  );
}

/// The landing state's cover: the one continuous passport's front face,
/// "Tap to open" beneath it. Formerly a genuine stack — a sliver per
/// yearly volume peeking behind the front cover, swipe/tap to bring one
/// forward, page dots showing which was selected — now that
/// [buildPassportVolumes] always returns at most one volume, [volumes]
/// here is always length ≤1, so [PassportCoverStackState]'s own peek/
/// swipe/dots machinery below is effectively inert (peekCount always 0,
/// the dots row's own `length > 1` guard never true) rather than removed
/// outright: nothing about this widget's CONTRACT changed (it still takes
/// a list, still exposes `onOpen(index)`), only what
/// [buildPassportVolumes] ever puts in that list — see this class's own
/// git history if the swipe-between-volumes behavior is ever wanted back
/// for something else.
class PassportCoverStack extends StatefulWidget {
  final List<PassportVolume> volumes;
  final int? memberNumber;
  final ValueChanged<int> onOpen;

  /// The front face's rendered size.
  final Size faceSize;

  const PassportCoverStack({
    super.key,
    required this.volumes,
    required this.memberNumber,
    required this.onOpen,
    this.faceSize = const Size(
      PassportCoverFace.baseWidth,
      PassportCoverFace.baseHeight,
    ),
  });

  @override
  State<PassportCoverStack> createState() => PassportCoverStackState();
}

class PassportCoverStackState extends State<PassportCoverStack> {
  int _selected = 0;

  static const int _maxPeek = 5;

  void _advance(int delta) {
    final next = (_selected + delta).clamp(0, widget.volumes.length - 1);
    if (next != _selected) setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.volumes.length - _selected;
    final peekCount = (visible - 1).clamp(0, _maxPeek);
    const peekStep = 24.0;
    final stackHeight = widget.faceSize.height + peekStep * peekCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -200) {
              _advance(1);
            } else if (v > 200) {
              _advance(-1);
            }
          },
          child: SizedBox(
            height: stackHeight,
            width: widget.faceSize.width + 20,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                for (var depth = peekCount; depth >= 0; depth--)
                  Positioned(
                    // Each step further back sits [peekStep]pt higher —
                    // same height as the front face, so raising it exposes
                    // only its own top edge above whatever's stacked in
                    // front of it. A front-anchored `bottom: 0` for every
                    // depth (what this used to say) stacked every face on
                    // top of each other with nothing peeking at all — a
                    // real bug caught only by actually looking at the
                    // rendered preview, not by analyze/tests.
                    bottom: peekStep * depth,
                    child: Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.diagonal3Values(
                        1 - depth * 0.025,
                        1,
                        1,
                      ),
                      child: depth == 0
                          ? GestureDetector(
                              onTap: () => widget.onOpen(_selected),
                              child: PassportCoverFace(
                                volume: widget.volumes[_selected],
                                memberNumber: widget.memberNumber,
                                size: widget.faceSize,
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _advance(depth),
                              child: PassportCoverFace(
                                volume: widget.volumes[_selected + depth],
                                memberNumber: widget.memberNumber,
                                depth: depth,
                                size: widget.faceSize,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to open',
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.secondaryOnDark,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (widget.volumes.length > 1) ...[
          const SizedBox(height: 10),
          PassportPageDots(count: widget.volumes.length, activeIndex: _selected),
        ],
      ],
    );
  }
}
