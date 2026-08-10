import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/key_row.dart';
import '../../../models/hotel.dart';
import '../../../models/ranking_entry.dart';
import '../../hotels/hotel_detail_screen.dart';

/// One unique hotel's row in "My Rankings": rank, identity, current
/// Michelin Keys (context only — never part of computing the ranking, just
/// like current Stars on [PersonalRankingCard]), and the selected
/// dimension's average with how many stays contributed to it. Tapping
/// opens the existing HotelDetailScreen — no separate ranking-detail
/// screen. [onReturn] fires once that screen is popped, so a stay saved
/// there is reflected in the ranking immediately.
class HotelRankingCard extends StatelessWidget {
  final Hotel hotel;
  final PersonalRankingEntry entry;
  final int rank;
  final VoidCallback onReturn;

  const HotelRankingCard({
    super.key,
    required this.hotel,
    required this.entry,
    required this.rank,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
          );
          onReturn();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '$rank',
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.name,
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${hotel.cityName} ${hotel.flagEmoji}',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (hotel.hasMichelinKeys) ...[
                          const SizedBox(width: 8),
                          KeyRow(count: hotel.michelinKeys!, size: 11),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          entry.averageScore.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            color: AppColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ' · ${entry.ratedVisitCount == 1 ? '1 stay' : '${entry.ratedVisitCount} stays'}',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }
}
