import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_masthead_logo.dart';
import '../passport_booklet_data.dart';

// Same oldstyle-figure fallback PassportDataPage's own [_liningFigures]
// documents and fixes — the year label on a peeking sliver is a Cormorant
// numeral too.
const _liningFigures = [FontFeature.enable('lnum')];

/// The closed cover of one [PassportVolume] — the complete passport or one
/// yearly volume, same face, only the bottom-left label differs
/// ("COMPLETE" vs. the year). Gold appears ONLY on the logo mark, the
/// MANTELIER wordmark, and the two border strokes — every other piece of
/// text (the italic tagline, the COMPLETE/year label, the member number)
/// is ivory, matching this app's app-wide "no gold text" rule (see
/// EDITORIAL_REDESIGN_TRACKING.md's friend-profile note on the same rule)
/// — the design spec's own enumerated gold-foil list ("logo, MANTELIER,
/// rand") doesn't include the tagline or the corner labels, so they follow
/// the general rule instead. A disclosed interpretive call, not asked
/// about explicitly for this screen.
class PassportCoverFace extends StatelessWidget {
  final PassportVolume volume;
  final String memberNumber;

  /// 0 = the true front cover (full color, full contrast). Each step back
  /// in the physical stack lightens the face slightly toward
  /// [AppColors.forestGreen] — see [PassportCoverStack]'s own doc comment
  /// for why depth is capped rather than unbounded.
  final int depth;

  const PassportCoverFace({
    super.key,
    required this.volume,
    required this.memberNumber,
    this.depth = 0,
  });

  static const double width = 270;
  static const double height = 410;

  @override
  Widget build(BuildContext context) {
    final t = (depth * 0.16).clamp(0.0, 0.6);
    final faceColor = Color.lerp(AppColors.darkGreen, AppColors.forestGreen, t)!;
    final ivory = depth == 0
        ? AppColors.secondaryOnDark
        : AppColors.secondaryOnDark.withValues(alpha: 0.7);

    return Semantics(
      label: depth == 0
          ? '${volume.year == null ? "Complete passport" : "${volume.year} volume"}, '
                '${volume.entries} ${volume.entries == 1 ? "entry" : "entries"}. '
                'Double-tap to open. Swipe for yearly volumes.'
          : null,
      excludeSemantics: depth != 0,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: faceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            bottomLeft: Radius.circular(6),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
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
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            bottomLeft: Radius.circular(6),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CoverBorderPainter(
                    outerColor: AppColors.stampInkDeepGold,
                    innerColor: AppColors.gold.withValues(
                      alpha: depth == 0 ? 1 : 0.6,
                    ),
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
                          color: ivory,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        volume.label,
                        style: GoogleFonts.inter(
                          color: ivory,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 10.5 * 0.14,
                        ),
                      ),
                      Text(
                        'NO. $memberNumber',
                        style: GoogleFonts.inter(
                          color: ivory,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 10.5 * 0.14,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                // Fixed 7pt inset from the card's own top edge, NOT a
                // fractional Alignment — the visible sliver band is only
                // ~[PassportCoverStackState._maxPeek]'s own peekStep
                // (24pt) regardless of the card's full 410pt height, so a
                // fractional y (e.g. -0.88) that happens to fall outside
                // that band renders the label but leaves it fully
                // occluded by the card in front. Confirmed missing this
                // way in this round's own preview-harness screenshot
                // before switching to a fixed inset.
                Positioned(
                  top: 7,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      volume.label,
                      style: GoogleFonts.cormorantGaramond(
                        color: depth == 1 ? AppColors.secondaryOnDark : ivory,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 13 * 0.12,
                        fontFeatures: _liningFigures,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverBorderPainter extends CustomPainter {
  final Color outerColor;
  final Color innerColor;
  const _CoverBorderPainter({required this.outerColor, required this.innerColor});

  static const _radii = BorderRadius.only(
    topLeft: Radius.circular(6),
    bottomLeft: Radius.circular(6),
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = (Offset.zero & size).deflate(1);
    canvas.drawRRect(
      _radii.toRRect(outerRect),
      Paint()
        ..color = outerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final innerRect = (Offset.zero & size).deflate(12);
    canvas.drawRRect(
      _radii.toRRect(innerRect).deflate(0),
      Paint()
        ..color = innerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _CoverBorderPainter oldDelegate) =>
      oldDelegate.outerColor != outerColor || oldDelegate.innerColor != innerColor;
}

/// The landing state's whole stack: the complete passport in front, one
/// sliver per yearly volume peeking above it, swipe/tap to bring a volume
/// forward, "Tap to open" + page dots below. Depth is capped at 5 peeking
/// slivers — a user with a longer history can still reach every volume by
/// swiping, but rendering an unbounded, ever-taller fan for e.g. 12 years
/// of visits would push the "Tap to open" caption and dots off whatever
/// screen height is available; 5 is generous for what this app's own
/// visit history realistically looks like today. A scaling simplification,
/// disclosed rather than silently assumed away.
class PassportCoverStack extends StatefulWidget {
  final List<PassportVolume> volumes;
  final String memberNumber;
  final ValueChanged<int> onOpen;

  const PassportCoverStack({
    super.key,
    required this.volumes,
    required this.memberNumber,
    required this.onOpen,
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
    final stackHeight = PassportCoverFace.height + peekStep * peekCount;

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
            width: PassportCoverFace.width + 20,
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
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _advance(depth),
                              child: PassportCoverFace(
                                volume: widget.volumes[_selected + depth],
                                memberNumber: widget.memberNumber,
                                depth: depth,
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
          _CoverDots(count: widget.volumes.length, activeIndex: _selected),
        ],
      ],
    );
  }
}

class _CoverDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  const _CoverDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: i == activeIndex ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == activeIndex
                ? AppColors.forestGreen
                : AppColors.secondaryOnDark.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    ],
  );
}
