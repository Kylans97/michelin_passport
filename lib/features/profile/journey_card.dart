import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surfaces.dart';
import '../../core/theme/cs_typography.dart';
import 'journey_metrics.dart';

/// PROFILE JOURNEY CARD — a compact, restrained card: a panel lifted off
/// the deep-green canvas ([CsSurfaces.greenElevated] — the same token
/// role Chasing Stars already uses for "content grouped on top of the
/// canvas," not a new color), showing exactly two numbers — Places and
/// Countries ([computeJourneyMetrics]'s own calculation logic is entirely
/// untouched by this file; this is presentation only) — side by side,
/// with no other copy. A very faint guilloché-style security-paper
/// pattern and a faint corner passport stamp are the only decoration;
/// both are deliberately low-contrast enough that Places/Countries stay
/// the clear visual focus.
///
/// The corner stamp carries the member's join date — the one place that
/// fact appears; see `profile_screen.dart`'s own `_IdentityHero`, which
/// doesn't repeat "Member since" as a separate line.
class JourneyCard extends StatelessWidget {
  final JourneyMetrics journey;

  /// Already-formatted "Month Year" (e.g. "August 2026") — the exact
  /// string `UserProfile.memberSince` already produces. Never a raw
  /// [DateTime]; this widget only ever abbreviates the month for the
  /// stamp via [journeyStampDateLabel], it doesn't reformat a date.
  final String memberSince;

  const JourneyCard({super.key, required this.journey, required this.memberSince});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CsRadius.card),
      child: Container(
        decoration: BoxDecoration(
          // A panel lifted off the canvas, not a new color — the same
          // role every other "content grouped on top of deepGreen"
          // surface in this app already uses. Unchanged by this pass —
          // explicitly kept as-is per product direction.
          color: CsSurfaces.greenElevated,
          border: Border.all(color: CsSurfaces.subtleGreenBorder),
          borderRadius: BorderRadius.circular(CsRadius.card),
        ),
        child: Stack(
          children: [
            // The security-paper texture is the backdrop: painted first,
            // full-bleed, beneath both the stamp and the real content.
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _SecurityPaperPainter()),
              ),
            ),
            // Partially clipped by the ClipRRect above — a corner of the
            // stamp extends past the card's own bounds, reading as
            // printed into the card rather than a badge sitting on it.
            Positioned(
              top: -18,
              right: -18,
              child: _PassportStamp(label: journeyStampLabel(memberSince)),
            ),
            Padding(
              padding: const EdgeInsets.all(CsSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YOUR JOURNEY',
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: _MetricColumn(
                            value: '${journey.places}',
                            label: 'PLACES',
                          ),
                        ),
                      ),
                      // DECORATIVE TREATMENT REFINEMENT — significantly
                      // shorter (a fixed height well under the metric
                      // block's own, not stretched to match it) and
                      // fainter than a standard hairline: a bare
                      // suggestion of a division, not a structural rule.
                      Container(
                        key: const ValueKey('journey-card-divider'),
                        width: 1,
                        height: 20,
                        color: AppColors.textOnDark.withValues(alpha: 0.08),
                      ),
                      Expanded(
                        child: Center(
                          child: _MetricColumn(
                            value: '${journey.countries}',
                            label: 'COUNTRIES',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "August 2026" → "AUG 2026". Defensive: `UserProfile.memberSince`
/// always produces a fixed "Month Year" shape (see its own
/// `_formatDate`), but this never throws even if that ever changes —
/// falls back to the raw string, uppercased, rather than crash a
/// decorative stamp over a formatting assumption.
String journeyStampDateLabel(String memberSince) {
  final parts = memberSince.trim().split(' ');
  if (parts.length != 2 || parts[0].length < 3) return memberSince.toUpperCase();
  final month = parts[0].substring(0, 3).toUpperCase();
  final year = parts[1];
  return '$month $year';
}

String journeyStampLabel(String memberSince) =>
    'CHASING STARS · ${journeyStampDateLabel(memberSince)}';

// Centered value-over-label, no icon — Places/Countries are the entire
// content of this card, so nothing should compete for attention above
// them.
class _MetricColumn extends StatelessWidget {
  final String value;
  final String label;
  const _MetricColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        value,
        textAlign: TextAlign.center,
        style: CsTypography.screenTitle.copyWith(color: AppColors.textOnDark),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
      ),
    ],
  );
}

// ── Security-paper guilloché texture ─────────────────────────────────

/// Fine, closely-spaced concentric ellipses — the actual engraved-line
/// motif real passport/banknote guilloché backgrounds use, not a handful
/// of large sine waves (which read as topographic contour lines instead
/// of security printing — the earlier version of this painter). Two
/// clusters only, anchored at the card's lower-left and upper-right
/// corners, each ring capped well short of the card's centre so the
/// pattern genuinely fades out toward the middle rather than being
/// clipped there — nothing is ever drawn across the centre at all, where
/// Places/Countries need to stay the unambiguous focus. green-on-green
/// only: [AppColors.darkGreen] (a genuinely darker green token than the
/// card's own [CsSurfaces.greenElevated] fill) at very low, per-ring
/// fading opacity — never ivory, never gold, no dots, no hatching. Still
/// a single paint call (a fixed, small number of `drawOval`s — cheap
/// canvas primitives, no per-pixel work), [shouldRepaint] always false,
/// wrapped in a [RepaintBoundary] by the caller.
class _SecurityPaperPainter extends CustomPainter {
  const _SecurityPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final scale = math.min(size.width, size.height);

    _paintCluster(
      canvas,
      center: Offset(size.width * 0.10, size.height * 0.95),
      maxRadius: scale * 0.62,
      ringCount: 15,
      rotation: -0.35,
      aspectRatio: 0.6,
    );
    _paintCluster(
      canvas,
      center: Offset(size.width * 0.96, size.height * 0.05),
      maxRadius: scale * 0.55,
      ringCount: 13,
      rotation: 0.5,
      aspectRatio: 0.68,
    );
  }

  // One corner's worth of fine, overlapping concentric ellipses, rotated
  // as a group so they read as engraved linework rather than a flat
  // target/bullseye. Ring spacing is deliberately tight (many thin rings
  // packed into a modest max radius) for the "closely spaced" engraved
  // look the wave version lacked.
  void _paintCluster(
    Canvas canvas, {
    required Offset center,
    required double maxRadius,
    required int ringCount,
    required double rotation,
    required double aspectRatio,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;
    final step = maxRadius / ringCount;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    for (var i = 1; i <= ringCount; i++) {
      final radius = step * i;
      // Fades as rings grow outward from the corner — i.e. as they
      // reach toward the card's centre — never a hard-edged cluster
      // boundary, and never reaching the centre at meaningful opacity.
      final t = i / ringCount;
      final alpha = 0.09 * (1 - t) * (1 - t);
      if (alpha <= 0.002) continue;
      paint.color = AppColors.darkGreen.withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2,
          height: radius * 2 * aspectRatio,
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SecurityPaperPainter oldDelegate) => false;
}

// ── Passport stamp watermark ─────────────────────────────────────────

/// Decorative only: excluded from semantics (a screen reader has nothing
/// useful to read here — the real values are already announced by the
/// metrics themselves) and never tappable. Two concentric rings plus a
/// restrained globe glyph, drawn with plain canvas primitives — no
/// character-by-character text-on-a-curve geometry, which would be
/// fragile for very little visual gain at this opacity/size. `label`
/// (the member's join date) sits as ordinary horizontal text in the
/// lower part of the circle instead.
class _PassportStamp extends StatelessWidget {
  final String label;
  const _PassportStamp({required this.label});

  static const double _diameter = 92;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: Transform.rotate(
        angle: -10 * math.pi / 180,
        child: SizedBox(
          width: _diameter,
          height: _diameter,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: const _PassportStampPainter(),
              child: Align(
                alignment: const Alignment(0, 0.55),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.12),
                      fontSize: 7,
                      letterSpacing: 1.0,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PassportStampPainter extends CustomPainter {
  const _PassportStampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = AppColors.textOnDark.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, outerRadius, ringPaint);
    canvas.drawCircle(center, outerRadius - 6, ringPaint);

    // A restrained globe glyph, shifted slightly above center so the
    // date label (rendered separately, lower in the circle) has room —
    // never a gold star, never the visual lead of the card.
    final globeCenter = center - Offset(0, outerRadius * 0.18);
    final globeRadius = outerRadius * 0.2;
    final globePaint = Paint()
      ..color = AppColors.textOnDark.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    canvas.drawCircle(globeCenter, globeRadius, globePaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: globeCenter,
        width: globeRadius * 2,
        height: globeRadius * 0.85,
      ),
      globePaint,
    );
    canvas.drawLine(
      Offset(globeCenter.dx, globeCenter.dy - globeRadius),
      Offset(globeCenter.dx, globeCenter.dy + globeRadius),
      globePaint,
    );
  }

  // The stamp never changes after first paint (a fixed member-since
  // date, a fixed geometry) — never repaints.
  @override
  bool shouldRepaint(covariant _PassportStampPainter oldDelegate) => false;
}
