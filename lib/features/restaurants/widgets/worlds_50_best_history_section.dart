import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/award_history_entry.dart';
import '../award_history/worlds_50_best_history_view_model.dart';

/// The Top 50 summary line ("4 appearances · Best ranking: #4") plus the
/// full ranked-year list, newest first. Every real ranked year is shown —
/// this is not collapsed to transitions the way Michelin history is, since
/// each yearly ranking is meaningful on its own. Lives on Award History's
/// forest-green canvas (UI Consistency Step 1B): ivory content throughout
/// — World's 50 Best is explicitly NOT gold, that's reserved for Michelin
/// stars alone.
class Worlds50BestHistorySection extends StatelessWidget {
  final Worlds50BestHistorySummary summary;
  const Worlds50BestHistorySection({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.topFiftyYears.isEmpty && summary.extendedYears.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.topFiftyYears.isNotEmpty) ...[
          Row(
            children: [
              Text(
                '${summary.appearances} '
                '${summary.appearances == 1 ? 'appearance' : 'appearances'}',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (summary.bestRank != null) ...[
                Text(
                  '  ·  ',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
                Text(
                  'Best ranking: #${summary.bestRank}',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (var i = 0; i < summary.topFiftyYears.length; i++) ...[
                _YearRankRow(entry: summary.topFiftyYears[i]),
                if (i != summary.topFiftyYears.length - 1) ...[
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.subtleBorderDark, height: 1),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ],
        if (summary.extendedYears.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'ALSO LISTED, 51–100',
            style: CsTypography.eyebrow.copyWith(
              color: AppColors.secondaryOnDark,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (var i = 0; i < summary.extendedYears.length; i++) ...[
                _YearRankRow(entry: summary.extendedYears[i]),
                if (i != summary.extendedYears.length - 1) ...[
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.subtleBorderDark, height: 1),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _YearRankRow extends StatelessWidget {
  final Worlds50BestHistoryEntry entry;
  const _YearRankRow({required this.entry});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '${entry.year}',
        style: CsTypography.metadata.copyWith(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      const Spacer(),
      Text(
        entry.rank != null ? '#${entry.rank}' : '—',
        style: CsTypography.metadata.copyWith(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// A distinct Hall of Fame achievement badge — never a "#rank" row, since
/// Hall of Fame isn't a ranking. Ivory-themed, not gold: Hall of Fame is
/// not Michelin recognition (UI Consistency Step 1B's hard color rule).
class HallOfFameBadge extends StatelessWidget {
  final int? inductionYear;
  const HallOfFameBadge({super.key, required this.inductionYear});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.textOnDark.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.subtleBorderDark, width: 0.5),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.military_tech_rounded,
          color: AppColors.textOnDark,
          size: 26,
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HALL OF FAME',
              style: CsTypography.eyebrow.copyWith(color: AppColors.textOnDark),
            ),
            const SizedBox(height: 2),
            Text(
              inductionYear != null
                  ? 'Inducted $inductionYear'
                  : 'Induction year unavailable',
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
