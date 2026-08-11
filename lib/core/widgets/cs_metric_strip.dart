import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// One number in a [CsMetricStrip] — a value and its eyebrow label, e.g.
/// value "42", label "PLACES".
class CsMetric {
  final String value;
  final String label;
  const CsMetric({required this.value, required this.label});
}

/// An editorial row of key numbers — "42 / PLACES", "9 / COUNTRIES", "61 /
/// STARS" — sitting directly on the canvas with thin dividers between
/// them, deliberately NOT one rounded card per metric: a private
/// members-club annual report, not a dashboard widget grid. First built
/// for Passport's collection summary; written generically (any list of
/// value/label pairs, either [CsSurface]) so later screens needing the
/// same "a few key numbers, quietly" treatment can reuse it.
class CsMetricStrip extends StatelessWidget {
  final List<CsMetric> metrics;
  final CsSurface surface;

  const CsMetricStrip({
    super.key,
    required this.metrics,
    this.surface = CsSurface.dark,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;
    final valueColor = onDark ? AppColors.textOnDark : AppColors.charcoal;
    final labelColor = onDark ? AppColors.secondaryOnDark : AppColors.taupe;
    final dividerColor = onDark
        ? AppColors.subtleBorderDark
        : AppColors.subtleBorderLight;

    final children = <Widget>[];
    for (var i = 0; i < metrics.length; i++) {
      if (i > 0) {
        children.add(
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: CsSpacing.md),
            color: dividerColor,
          ),
        );
      }
      children.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metrics[i].value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.largeMetric.copyWith(color: valueColor),
              ),
              const SizedBox(height: 2),
              Text(
                metrics[i].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.eyebrow.copyWith(color: labelColor),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
