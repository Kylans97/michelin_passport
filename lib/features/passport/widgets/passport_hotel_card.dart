import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/key_row.dart';
import '../../../models/hotel.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../passport_view_model.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

// "City, 🇬🇧 Country" — falls back to plain "City, Country" when
// flagEmoji is empty rather than inventing one from countryCode.
String _locationLabel(Hotel hotel) {
  final country = hotel.flagEmoji.isNotEmpty
      ? '${hotel.flagEmoji} ${hotel.countryName}'
      : hotel.countryName;
  return '${hotel.cityName}, $country';
}

/// One unique hotel in the Passport list, scoped to the active
/// venue-type/year filter: stay count, latest stay and average rating all
/// reflect only the stays [stats] was built from. Tapping opens the
/// existing HotelDetailScreen, where every individual stay is still
/// browsable regardless of what Passport is currently filtered to.
class PassportHotelCard extends StatelessWidget {
  final Hotel hotel;
  final PassportVenueStats stats;

  const PassportHotelCard({
    super.key,
    required this.hotel,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final avg = stats.averageRating;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hotel.name,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _locationLabel(hotel),
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 8),
              KeyRow(count: hotel.michelinKeys, size: 14),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (avg != null) ...[
                    Text(
                      avg.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' · ',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  Text(
                    stats.visitCount == 1
                        ? '1 stay'
                        : '${stats.visitCount} stays',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Last stay ${_formatDate(stats.latestVisit)}',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
