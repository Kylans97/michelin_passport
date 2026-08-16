import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/worlds_50_best_hotel_entry.dart';
import '../award_history/worlds_50_best_hotels_history_view_model.dart';

/// The Top 50 summary line ("4 appearances · Best ranking: #4") plus the
/// full ranked-year list, newest first — the hotel counterpart of
/// Worlds50BestHistorySection. No Hall of Fame block: there is nothing to
/// render because HotelWorlds50BestHistorySummary has no such field. Lives
/// on Award History's forest-green canvas (UI Consistency Step 1B): ivory
/// content throughout — World's 50 Best is explicitly NOT gold, that's
/// reserved for MICHELIN Keys alone.
class HotelWorlds50BestHistorySection extends StatelessWidget {
  final HotelWorlds50BestHistorySummary summary;
  const HotelWorlds50BestHistorySection({super.key, required this.summary});

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
  final HotelWorlds50BestEntry entry;
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
