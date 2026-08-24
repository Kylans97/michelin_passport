import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// One column of [PassportStatsPanel]: a large serif number and a small
/// uppercase label — no icon of its own (see [PassportStatsPanel]'s own
/// doc comment for why the per-metric icon circles were removed).
class PassportStat {
  final String value;
  final String label;
  const PassportStat({required this.value, required this.label});
}

/// Passport UI Polish V2 — the open, editorial statistics row from the
/// approved visual reference, replacing this pass's own previous bordered
/// panel-with-per-metric-icons treatment (itself already a departure from
/// the original bare [CsMetricStrip] row). The reference was explicit:
/// remove the dashboard-card container entirely, remove the icon circle
/// above each number, and use a single globe emblem to the left of the
/// whole row instead — "this area should breathe." No background, no
/// border, no per-metric icon. Deliberately a new, Passport-local widget
/// rather than a change to [CsMetricStrip] itself — that component is
/// shared with Profile's own Journey metrics, which were deliberately
/// de-iconified in an earlier pass and must not regress from a change
/// made here. Gold-free throughout, including the globe.
class PassportStatsPanel extends StatelessWidget {
  final List<PassportStat> stats;

  const PassportStatsPanel({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const _GlobeEmblem(),
      const SizedBox(width: CsSpacing.lg),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: CsSpacing.sm),
                  color: AppColors.subtleBorderDark,
                ),
              Expanded(child: _StatColumn(stat: stats[i])),
            ],
          ],
        ),
      ),
    ],
  );
}

/// The single emblem to the left of the stats row — elegant line art, not
/// the Cs monogram/laurels this replaced, not gamification, not gold.
/// Represents the user's journey across places/countries, matching the
/// approved reference's own framing.
class _GlobeEmblem extends StatelessWidget {
  const _GlobeEmblem();

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.subtleBorderDark),
    ),
    alignment: Alignment.center,
    child: const Icon(
      Icons.public_outlined,
      color: AppColors.textOnDark,
      size: 24,
    ),
  );
}

class _StatColumn extends StatelessWidget {
  final PassportStat stat;
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
        style: CsTypography.largeMetric.copyWith(color: AppColors.textOnDark),
      ),
      const SizedBox(height: 2),
      Text(
        stat.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
      ),
    ],
  );
}
