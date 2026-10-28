import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
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

/// "1 restaurant · 1 hotel" — shared by [TripCard] and [TripHeroCard] so
/// both read the exact same wording rather than each growing their own
/// copy of this logic.
String tripVenueCountsLine({
  required int restaurantCount,
  required int hotelCount,
}) {
  final parts = <String>[
    if (restaurantCount > 0)
      '$restaurantCount restaurant${restaurantCount == 1 ? '' : 's'}',
    if (hotelCount > 0) '$hotelCount hotel${hotelCount == 1 ? '' : 's'}',
  ];
  return parts.isEmpty ? 'No venues planned yet' : parts.join(' · ');
}

/// One trip in the full upcoming-trips list — title, date range, and a
/// compact restaurants/hotels count line resolved by the caller (see
/// TripsBody, which groups ResolvedPlannedVenue by trip_id).
///
/// Trips restyle (2026-10-28): an ivory card on the deep-green canvas —
/// the same surface as [TripHeroCard] and every [CsPlaceCard], at a
/// quieter scale — rather than a green panel that blended into the page.
/// Deep green title, forest-green dates, taupe counts; never gold.
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

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${trip.title}. ${formatTripDateRange(trip)}. '
        '${tripVenueCountsLine(restaurantCount: restaurantCount, hotelCount: hotelCount)}',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.card),
        splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
        highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CsSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.ivory,
            borderRadius: BorderRadius.circular(CsRadius.card),
            border: Border.all(color: AppColors.subtleBorderLight, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.deepGreen,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      formatTripDateRange(trip),
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tripVenueCountsLine(
                        restaurantCount: restaurantCount,
                        hotelCount: hotelCount,
                      ),
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.forestGreen,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
