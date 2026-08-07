import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/passport_venue.dart';
import '../../passport/passport_view_model.dart' show PassportVenueStats;
import '../../restaurants/restaurant_detail_screen.dart';
import '../../hotels/hotel_detail_screen.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// The bottom sheet shown when a map pin is tapped. Gives enough context
/// (award, visit/stay count, latest visit/stay) to decide whether to open
/// the full detail screen, rather than navigating away immediately on
/// first tap.
Future<void> showVenuePreviewSheet(
  BuildContext context,
  PassportVenueStats stats,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _VenuePreviewSheet(stats: stats),
  );
}

class _VenuePreviewSheet extends StatelessWidget {
  final PassportVenueStats stats;
  const _VenuePreviewSheet({required this.stats});

  @override
  Widget build(BuildContext context) {
    final venue = stats.venue;
    final isHotel = venue is HotelVenue;
    final award = stats.awardAtLatestVisit;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                venue.name,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _locationLine(venue),
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              if (award > 0)
                isHotel ? KeyRow(count: award) : StarRow(count: award),
              if (award > 0) const SizedBox(height: 14),
              Text(
                isHotel
                    ? '${stats.visitCount} ${stats.visitCount == 1 ? 'stay' : 'stays'} · latest ${_formatDate(stats.latestVisit)}'
                    : '${stats.visitCount} ${stats.visitCount == 1 ? 'visit' : 'visits'} · latest ${_formatDate(stats.latestVisit)}',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    switch (venue) {
                      case RestaurantVenue(:final restaurant):
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RestaurantDetailScreen(restaurant: restaurant),
                          ),
                        );
                      case HotelVenue(:final hotel):
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HotelDetailScreen(hotel: hotel),
                          ),
                        );
                    }
                  },
                  child: Text(
                    isHotel ? 'View hotel' : 'View restaurant',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _locationLine(PassportVenue venue) => switch (venue) {
    RestaurantVenue(:final restaurant) =>
      '${restaurant.flagEmoji} ${restaurant.cityName}, ${restaurant.countryName}',
    HotelVenue(:final hotel) =>
      '${hotel.flagEmoji} ${hotel.cityName}, ${hotel.countryName}',
  };
}
