import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/passport_venue.dart';
import '../../../models/planned_venue.dart';
import '../../../models/resolved_planned_venue.dart';

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

String _formatPlanDate(ResolvedPlannedVenue item) {
  final start = item.plan.startDate;
  final end = item.plan.endDate;
  final startLabel =
      '${start.day} ${_monthNames[start.month - 1]} ${start.year}';
  if (end == null) return startLabel;
  return '$startLabel – ${end.day} ${_monthNames[end.month - 1]} '
      '${end.year}';
}

/// One planned restaurant visit / hotel stay — used both under
/// "PLANNED VISITS" (standalone, no trip) and inside Trip Detail's
/// restaurant/hotel lists. Tapping opens the venue's existing Detail
/// screen; [onTap] is the only required interaction, edit/cancel live
/// behind [onLongPress] to keep the row itself uncluttered.
class PlannedVenueRow extends StatelessWidget {
  final ResolvedPlannedVenue item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PlannedVenueRow({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final venue = item.venue;
    final location = switch (venue) {
      RestaurantVenue(:final restaurant) => restaurant.cityName,
      HotelVenue(:final hotel) => hotel.cityName,
    };
    final isCancelled = item.plan.status == PlannedVenueStatus.cancelled;
    final isCompleted = item.plan.status == PlannedVenueStatus.completed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
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
                    Text(
                      _formatPlanDate(item),
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${venue.name} · $location',
                      style: GoogleFonts.playfairDisplay(
                        color: isCancelled
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (isCompleted || isCancelled) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.plan.status.label,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
