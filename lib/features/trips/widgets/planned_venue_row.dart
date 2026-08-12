import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
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
/// Dining/Stay lists. Tapping opens the venue's existing Detail screen;
/// [onTap] is the only required interaction, edit/cancel live behind
/// [onLongPress] to keep the row itself uncluttered. A dark editorial
/// card, matching [TripCard]'s surface — the Michelin star/Key distinction
/// shown below the name comes straight from [item.venue] (already a fully
/// resolved [Restaurant]/[Hotel]), no new query.
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
    final distinction = switch (venue) {
      RestaurantVenue(:final restaurant) when restaurant.hasMichelinStar =>
        StarRow(count: restaurant.michelinStars!, size: 12),
      HotelVenue(:final hotel) when hotel.hasMichelinKeys => KeyRow(
        count: hotel.michelinKeys!,
        size: 12,
      ),
      _ => null,
    };
    final statusSuffix = isCancelled
        ? '. Cancelled'
        : isCompleted
        ? '. Completed'
        : '';

    return Semantics(
      button: true,
      label: '${venue.name}, $location. ${_formatPlanDate(item)}$statusSuffix',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(CsRadius.card),
          splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
          highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(CsSpacing.base),
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
                        _formatPlanDate(item),
                        style: CsTypography.eyebrow.copyWith(
                          color: AppColors.secondaryOnDark,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${venue.name} · $location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.placeTitle.copyWith(
                          fontSize: 17,
                          color: isCancelled
                              ? AppColors.secondaryOnDark
                              : AppColors.textOnDark,
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (distinction != null) ...[
                        const SizedBox(height: 4),
                        distinction,
                      ],
                      if (isCompleted || isCancelled) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.plan.status.label,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.secondaryOnDark,
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
                  color: AppColors.secondaryOnDark,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
