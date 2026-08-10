import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/planned_trip.dart';

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

String formatTripDateRange(PlannedTrip trip) {
  final s = trip.startDate;
  final e = trip.endDate;
  if (s.year == e.year && s.month == e.month) {
    return '${s.day}–${e.day} ${_monthNames[s.month - 1]} ${s.year}';
  }
  if (s.year == e.year) {
    return '${s.day} ${_monthNames[s.month - 1]} – ${e.day} '
        '${_monthNames[e.month - 1]} ${s.year}';
  }
  return '${s.day} ${_monthNames[s.month - 1]} ${s.year} – ${e.day} '
      '${_monthNames[e.month - 1]} ${e.year}';
}

/// One trip in "UPCOMING" — title, date range, and a compact
/// restaurants/hotels count line resolved by the caller (see
/// PlannedTripsScreen, which groups ResolvedPlannedVenue by trip_id).
class TripCard extends StatelessWidget {
  final PlannedTrip trip;
  final int restaurantCount;
  final int hotelCount;
  final VoidCallback onTap;

  const TripCard({
    super.key,
    required this.trip,
    required this.restaurantCount,
    required this.hotelCount,
    required this.onTap,
  });

  String get _countsLine {
    final parts = <String>[
      if (restaurantCount > 0)
        '$restaurantCount restaurant${restaurantCount == 1 ? '' : 's'}',
      if (hotelCount > 0) '$hotelCount hotel${hotelCount == 1 ? '' : 's'}',
    ];
    return parts.isEmpty ? 'No venues planned yet' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.cardBorder.withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.title, style: AppTypography.editorialHeading),
                  const SizedBox(height: 4),
                  Text(
                    formatTripDateRange(trip),
                    style: AppTypography.metadata,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _countsLine,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}
