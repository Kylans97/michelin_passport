import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/worlds_50_best_hotel_entry.dart';
import '../../restaurants/widgets/detail_section.dart';
import '../award_history/worlds_50_best_hotels_history_view_model.dart';

/// The Top 50 summary line ("4 appearances · Best ranking: #4") plus the
/// full ranked-year list, newest first — the hotel counterpart of
/// Worlds50BestHistorySection. No Hall of Fame block: there is nothing to
/// render because HotelWorlds50BestHistorySummary has no such field.
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
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (summary.bestRank != null) ...[
                Text(
                  '  ·  ',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                Text(
                  'Best ranking: #${summary.bestRank}',
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          DetailCard(
            child: Column(
              children: [
                for (var i = 0; i < summary.topFiftyYears.length; i++) ...[
                  _YearRankRow(entry: summary.topFiftyYears[i]),
                  if (i != summary.topFiftyYears.length - 1) ...[
                    const SizedBox(height: 10),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ],
        if (summary.extendedYears.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'ALSO LISTED, 51–100',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          DetailCard(
            child: Column(
              children: [
                for (var i = 0; i < summary.extendedYears.length; i++) ...[
                  _YearRankRow(entry: summary.extendedYears[i]),
                  if (i != summary.extendedYears.length - 1) ...[
                    const SizedBox(height: 10),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
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
        style: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const Spacer(),
      Text(
        entry.rank != null ? '#${entry.rank}' : '—',
        style: GoogleFonts.inter(
          color: AppColors.gold,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
