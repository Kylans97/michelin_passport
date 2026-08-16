import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';
import 'venue_visit_row.dart' show formatVenueVisitDate;

/// The "SCORES (Your latest visit) ⋯ Visited 15 August 2026" header above
/// a [VenueScoreStrip] — folds what was previously a second "Latest visit
/// · {date}" line into one row instead of stating the date twice across
/// the section. [noun] is `'visit'` (Restaurant) or `'stay'` (Hotel); the
/// right-hand verb follows from it ("Visited"/"Stayed"), matching each
/// screen's own existing vocabulary (YOUR VISITS/YOUR STAYS).
///
/// UI Consistency Step 1G: a prior `Row(Expanded(flex: 3), Flexible(flex:
/// 2))` attempt still rendered the two halves on visually separate lines
/// on-device. Root cause: a *fixed* flex split allocates each side a
/// share of the width regardless of what its content actually needs — at
/// normal phone width, "SCORES  (Your latest visit)" alone is wider than
/// its flex-3 (60%) share, so the `Text.rich` wrapped internally to two
/// lines, and the date then sat beside only the first of those two lines.
/// Giving the split a fixed ratio was the mistake, not the use of `Row`
/// itself.
///
/// Fixed by measuring both halves' actual single-line width (via
/// [TextPainter], at the ambient [TextScaler]) against the space
/// available ([LayoutBuilder]): if they genuinely fit side by side, render
/// exactly that — [Expanded] on the left (so it, not the fixed-width
/// date, absorbs any leftover width or applies ellipsis under real
/// pressure) plus a plain, intrinsically-sized `Text` on the right,
/// pinned to the true right edge. Only when the two halves genuinely
/// cannot coexist on one line (found in practice at ~320px and reliably
/// at 1.6x text scale) does this fall back to a deliberate two-line stack
/// — left cluster on top, date right-aligned beneath it — never an
/// uncontrolled wrap and never a silent overflow.
///
/// Typographic hierarchy is deliberately three-tier: "SCORES" (eyebrow,
/// strongest), "(Your latest visit)" (12px secondary), "Visited {date}"
/// (11px, smaller still — pure metadata, never competing with the
/// heading).
class VenueScoreHeader extends StatelessWidget {
  final String noun;
  final DateTime date;
  const VenueScoreHeader({super.key, required this.noun, required this.date});

  @override
  Widget build(BuildContext context) {
    final verb = noun == 'stay' ? 'Stayed' : 'Visited';
    final leftSpan = TextSpan(
      children: [
        TextSpan(
          text: 'SCORES',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        TextSpan(
          text: '  (Your latest $noun)',
          style: CsTypography.metadata.copyWith(
            color: AppColors.taupe,
            fontSize: 12,
          ),
        ),
      ],
    );
    final rightStyle = CsTypography.metadata.copyWith(
      color: AppColors.taupe,
      fontSize: 11,
    );
    final rightText = '$verb ${formatVenueVisitDate(date)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final leftWidth = (TextPainter(
          text: leftSpan,
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout()).width;
        final rightWidth = (TextPainter(
          text: TextSpan(text: rightText, style: rightStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout()).width;
        final fitsOneLine =
            leftWidth + CsSpacing.sm + rightWidth <= constraints.maxWidth;

        final leftText = Text.rich(
          leftSpan,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        final rightTextWidget = Text(rightText, style: rightStyle);

        if (fitsOneLine) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: leftText),
              const SizedBox(width: CsSpacing.sm),
              rightTextWidget,
            ],
          );
        }

        // Deliberate stacked fallback — never reached at normal phone
        // width, only under genuine width/scale pressure.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leftText,
            const SizedBox(height: 2),
            Align(alignment: Alignment.centerRight, child: rightTextWidget),
          ],
        );
      },
    );
  }
}

/// The pure `value / 10` progress calculation a [ScoreRingPainter] draws —
/// pulled out as its own top-level function (rather than inlined in
/// [_ScoreColumn]) so it's directly unit-testable without pumping a
/// widget: null → 0, clamped to [0, 1] so a value can never be drawn as
/// more than a full circle (or less than an empty one) regardless of
/// input, and safe for a decimal value (e.g. 8.5 → 0.85) even though every
/// current `Visit` rating field is `int?`.
double scoreProgress(num? value) {
  if (value == null) return 0.0;
  return (value / 10).clamp(0.0, 1.0).toDouble();
}

/// One rating dimension in a [VenueScoreStrip] — a label paired with its
/// value for the latest visit/stay. [value] is the raw stored rating (out
/// of 10, or null if that dimension wasn't rated) — never fabricated,
/// never coerced to 0. Typed `num?` rather than `int?` so this component
/// stays correct if a decimal rating is ever introduced — every current
/// `Visit` rating field is `int?`, but the progress-ring math below never
/// assumes that.
class ScoreDimension {
  final String label;
  final num? value;
  const ScoreDimension({required this.label, required this.value});
}

/// The latest-visit/stay score presentation: every actual rating dimension
/// the venue type supports, each as a compact proportional progress ring,
/// laid out on one aligned horizontal row. Restaurant visits carry five
/// dimensions (Overall/Food/Service/Wine/Value, see [Visit]); hotel stays
/// carry five as well (Overall/Service/Room/Experience/Value) — callers
/// pass only the dimensions that genuinely exist for that venue type,
/// nothing is fabricated here.
///
/// The ring visually represents `value / 10` — a score of 7 fills exactly
/// 70% of the circumference, clockwise from the top, clamped to [0, 1] so
/// a value is never drawn past a full circle even if a future data source
/// somehow exceeds 10. The arc is a thin, rounded-cap forest-green stroke
/// over a subtle taupe background ring — never gold (a personal rating is
/// not Michelin recognition — that's [StarRow]/[KeyRow]'s job alone) and
/// never a gradient or a thick dashboard-style ring. The numeral stays the
/// dominant, centered element; the ring is a quiet visual accent around it.
///
/// UI Consistency Step 1F: every ring is a fixed 40×40 [SizedBox], never
/// wrapped in a [FittedBox] — a longer label (e.g. "Experience" vs "Room")
/// must never influence ring size.
///
/// UI Consistency Step 1G: labels no longer scale independently either.
/// Step 1F's per-label `FittedBox` fixed the ring but left the *label*
/// itself shrinking in isolation — "Experience", the widest label, still
/// rendered visibly smaller than its siblings on physical device, since
/// each label's `FittedBox` picked its own scale factor based only on its
/// own text width. All five labels must share one literal `TextStyle`
/// instance and one label-area height; neither may vary per column.
///
/// This widget now measures once, for the whole strip: at the ambient
/// [TextScaler] and the row's actual per-column width ([LayoutBuilder]),
/// would *any* label's natural single-line width overflow its column? If
/// none would, every label renders on one line at the shared [_labelStyle]
/// — no scaling, no per-label decisions. If at least one would (typically
/// only at high accessibility text scale), every column uniformly reserves
/// a two-line-tall label area instead — the label text itself still uses
/// the same shared style and simply wraps if it needs to, never shrinks.
/// Either way the decision and the resulting height apply identically to
/// every column, so labels stay on one shared baseline and one shared
/// height regardless of how many lines a given label happens to need.
class VenueScoreStrip extends StatelessWidget {
  final List<ScoreDimension> dimensions;
  const VenueScoreStrip({super.key, required this.dimensions});

  static final TextStyle _labelStyle = CsTypography.metadata.copyWith(
    color: AppColors.taupe,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    height: 1.15,
    // No letter-spacing: CsTypography.eyebrow's heavy tracking (designed
    // for short, all-caps section labels) is what made "Experience" not
    // fit its column in the first place — a plain, compact style is the
    // uniform size that actually fits all five real labels.
  );

  @override
  Widget build(BuildContext context) {
    if (dimensions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final gapCount = dimensions.length - 1;
        final totalGap = gapCount > 0 ? gapCount * CsSpacing.sm : 0.0;
        final columnWidth =
            (constraints.maxWidth - totalGap) / dimensions.length;

        var needsTwoLines = false;
        for (final d in dimensions) {
          final width = (TextPainter(
            text: TextSpan(text: d.label, style: _labelStyle),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
            maxLines: 1,
          )..layout()).width;
          if (width > columnWidth) {
            needsTwoLines = true;
            break;
          }
        }

        final lineHeight =
            textScaler.scale(_labelStyle.fontSize!) * _labelStyle.height!;
        final labelAreaHeight = lineHeight * (needsTwoLines ? 2 : 1);
        final labelMaxLines = needsTwoLines ? 2 : 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < dimensions.length; i++) ...[
              if (i > 0) const SizedBox(width: CsSpacing.sm),
              Expanded(
                child: _ScoreColumn(
                  dimension: dimensions[i],
                  labelStyle: _labelStyle,
                  labelAreaHeight: labelAreaHeight,
                  labelMaxLines: labelMaxLines,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One compact score ring + label — the reusable primitive genuinely
/// shared between Restaurant's and Hotel's 5-dimension strips (same
/// visual grammar, different dimension labels), kept private since
/// [VenueScoreStrip] is the only real call-site shape.
///
/// A missing rating ([ScoreDimension.value] is null — either never rated,
/// or a historical Hotel stay predating the Room/Experience columns)
/// renders with exactly the same ring geometry as a populated one: the
/// same 40×40 circle, the same background ring, just no foreground arc
/// (`scoreProgress(null) == 0.0`, and [ScoreRingPainter] only paints an
/// arc when `progress > 0`) and a centered `—` in place of a numeral —
/// never a fabricated `0`, never a shrunk or omitted column.
class _ScoreColumn extends StatelessWidget {
  final ScoreDimension dimension;
  final TextStyle labelStyle;
  final double labelAreaHeight;
  final int labelMaxLines;

  const _ScoreColumn({
    required this.dimension,
    required this.labelStyle,
    required this.labelAreaHeight,
    required this.labelMaxLines,
  });

  static const double _diameter = 40;
  static const double _strokeWidth = 3;

  @override
  Widget build(BuildContext context) {
    final value = dimension.value;
    final progress = scoreProgress(value);
    final numeral = value == null
        ? '—'
        // Whole ratings ("7") stay bare integers; a hypothetical future
        // decimal rating ("8.5") is shown as-is, never rounded away.
        : (value % 1 == 0 ? value.toInt().toString() : value.toString());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fixed size, never wrapped in a FittedBox — this is the one
        // element in the column that must never scale, regardless of how
        // wide the label beneath it is or how narrow its allotted column
        // width becomes.
        SizedBox(
          width: _diameter,
          height: _diameter,
          child: CustomPaint(
            painter: ScoreRingPainter(
              progress: progress,
              strokeWidth: _strokeWidth,
              foreground: AppColors.forestGreen,
              background: AppColors.subtleBorderLight,
            ),
            child: Center(
              child: Text(
                numeral,
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.forestGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: CsSpacing.xs),
        // Same style, same reserved height, same max line count as every
        // other column in the strip — decided once by VenueScoreStrip for
        // the whole row, never per-label.
        SizedBox(
          height: labelAreaHeight,
          child: Center(
            child: Text(
              dimension.label,
              textAlign: TextAlign.center,
              maxLines: labelMaxLines,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws the thin proportional ring: a full background circle, then a
/// clockwise foreground arc (starting at the top, `-pi/2`) covering
/// `progress` of the circumference. Deterministic, no animation — a
/// `CustomPainter` here is the smallest clean implementation, cheaper than
/// stacking two `CircularProgressIndicator`s (which are built for
/// indeterminate/animated use, not a static value) and without adding a
/// charting/progress package for something this small. Public (not
/// library-private) specifically so its configuration is directly
/// testable — `tester.widget<CustomPaint>(...).painter as ScoreRingPainter`
/// — without needing a golden-image comparison for something this simple.
class ScoreRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color foreground;
  final Color background;

  const ScoreRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.foreground,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress <= 0) return;
    final foregroundPaint = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.foreground != foreground ||
      oldDelegate.background != background ||
      oldDelegate.strokeWidth != strokeWidth;
}
