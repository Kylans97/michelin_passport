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

/// One trip in "UPCOMING" — title, date range, and a compact
/// restaurants/hotels count line resolved by the caller (see
/// PlannedTripsScreen, which groups ResolvedPlannedVenue by trip_id). A
/// dark editorial card — quiet elevated surface on the deep-green canvas,
/// rather than the light ivory card the rest of the app still uses —
/// matching the same "card floating on dark canvas" language Explore's
/// discovery cards already established.
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${trip.title}. ${formatTripDateRange(trip)}. $_countsLine',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.card),
        splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
        highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CsSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.brandGreenLight,
            borderRadius: BorderRadius.circular(CsRadius.card),
            border: Border.all(color: AppColors.subtleBorderDark, width: 0.5),
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
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      formatTripDateRange(trip),
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _countsLine,
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryOnDark,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
