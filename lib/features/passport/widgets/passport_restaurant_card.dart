import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';
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

// "City, 🇳🇱 Country" — falls back to plain "City, Country" when
// flagEmoji is empty rather than inventing one from countryCode.
String _locationLabel(Restaurant restaurant) {
  final country = restaurant.flagEmoji.isNotEmpty
      ? '${restaurant.flagEmoji} ${restaurant.countryName}'
      : restaurant.countryName;
  return '${restaurant.cityName}, $country';
}

/// One unique restaurant in the Passport list, scoped to the active year
/// filter: visit count, latest visit and average rating all reflect only
/// the visits [stats] was built from. Tapping opens the existing
/// RestaurantDetailScreen, where every individual visit is still browsable
/// regardless of what Passport is currently filtered to.
class PassportRestaurantCard extends StatelessWidget {
  final PassportRestaurantStats stats;

  const PassportRestaurantCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final restaurant = stats.restaurant;
    final avg = stats.averageRating;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
          ),
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
                restaurant.name,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _locationLabel(restaurant),
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              if (restaurant.hasMichelinStar) ...[
                const SizedBox(height: 8),
                StarRow(count: restaurant.michelinStars!, size: 14),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (avg != null) ...[
                    Text(
                      '${avg.toStringAsFixed(1)} average',
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
                        ? '1 visit'
                        : '${stats.visitCount} visits',
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
                'Last visit ${_formatDate(stats.latestVisit)}',
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
