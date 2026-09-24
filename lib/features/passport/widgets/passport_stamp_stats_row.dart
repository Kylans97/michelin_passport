import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// One column of [PassportStampStatsRow].
class PassportStampStat {
  final String value;
  final String label;

  /// The stars/Keys column is the only one drawn gold — matching the
  /// spec's "the Stars numeral is gold" exactly (the Places/Countries
  /// numerals stay ivory).
  final bool gold;

  const PassportStampStat({
    required this.value,
    required this.label,
    this.gold = false,
  });
}

/// The stats row below the Passport stamp page: 3 columns separated by
/// hairlines, large serif numerals. A new, Passport-stamp-page-specific
/// widget rather than a restyle of [PassportStatsPanel] — that one is a
/// distinct, separately tested component (passport_stats_panel_test.dart)
/// with its own globe emblem this redesign doesn't carry forward, so
/// restyling it in place would have doubled as an unrelated behavior
/// change to a component this task didn't touch.
class PassportStampStatsRow extends StatelessWidget {
  final List<PassportStampStat> stats;
  const PassportStampStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0)
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: CsSpacing.base),
            color: AppColors.subtleBorderDark,
          ),
        Expanded(child: _StatColumn(stat: stats[i])),
      ],
    ],
  );
}

class _StatColumn extends StatelessWidget {
  final PassportStampStat stat;
  const _StatColumn({required this.stat});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        stat.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CsTypography.stampStatValue.copyWith(
          color: stat.gold ? AppColors.gold : AppColors.textOnDark,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        stat.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
      ),
    ],
  );
}
