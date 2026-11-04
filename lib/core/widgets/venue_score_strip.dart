import 'package:flutter/material.dart';
import '../../models/visit.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';
import 'venue_visit_row.dart' show formatVenueVisitDate;

/// The "SCORES (Your latest visit) ⋯ Visited 15 August 2026" header above
/// a [VenueOverallScore] — folds what was previously a second "Latest visit
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

/// One score behind the overall: a label and what was given, null when it
/// was left blank. Never coerced to 0.
class ScoreDimension {
  final String label;
  final int? value;
  const ScoreDimension({required this.label, required this.value});
}

/// A visit's or stay's scores as one number: the overall, and on a tap what
/// it is made of, highest first. Replaces a row of one ring per score, which
/// at six on a restaurant read as a dashboard (product owner, 2026-11-04).
///
/// Scores left blank are not listed: they are not part of the overall
/// (20261101340000). An overall with nothing behind it, from a build that
/// let a member pick one, has nothing to open, so it is not tappable.
/// Forest green, never gold: a personal score is not MICHELIN recognition.
class VenueOverallScore extends StatefulWidget {
  final double? overall;
  final List<ScoreDimension> scores;
  const VenueOverallScore({
    super.key,
    required this.overall,
    required this.scores,
  });

  @override
  State<VenueOverallScore> createState() => _VenueOverallScoreState();
}

class _VenueOverallScoreState extends State<VenueOverallScore> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final overall = widget.overall;
    if (overall == null) {
      return Text(
        'No scores given',
        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
      );
    }

    // List.sort is not stable; the index keeps equal scores in the order
    // the venue type lists them.
    final given = widget.scores.where((s) => s.value != null).toList();
    final order = {for (var i = 0; i < given.length; i++) given[i]: i};
    given.sort((a, b) {
      final byValue = b.value!.compareTo(a.value!);
      return byValue != 0 ? byValue : order[a]!.compareTo(order[b]!);
    });
    final count = given.length;
    final canOpen = count > 0;
    final label = canOpen
        ? 'Overall · $count ${count == 1 ? 'score' : 'scores'}'
        : 'Overall';

    final summary = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Text(
            formatOverall(overall),
            style: CsTypography.largeMetric.copyWith(
              color: AppColors.forestGreen,
              fontSize: 32,
            ),
          ),
          const SizedBox(width: CsSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
          ),
          if (canOpen)
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: AppColors.taupe,
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canOpen)
          Semantics(
            button: true,
            expanded: _open,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: summary,
            ),
          )
        else
          summary,
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open && canOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: CsSpacing.sm),
                  child: Column(
                    children: [
                      for (var i = 0; i < given.length; i++) ...[
                        if (i > 0) const SizedBox(height: CsSpacing.sm),
                        _ScoreBar(score: given[i]),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final ScoreDimension score;
  const _ScoreBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final style = CsTypography.metadata.copyWith(
      color: AppColors.forestGreen,
      fontSize: 13,
    );
    return Row(
      children: [
        SizedBox(width: 84, child: Text(score.label, style: style)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: score.value! / 10,
              minHeight: 4,
              color: AppColors.forestGreen,
              backgroundColor: AppColors.hairlineOnPaper,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '${score.value}',
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
      ],
    );
  }
}
