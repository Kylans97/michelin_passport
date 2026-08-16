import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

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

String formatVenueVisitDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// One logged visit/stay, in the MY VISITS / MY STAYS list on Restaurant/
/// Hotel Detail's ivory content canvas (Step 1B). Exactly the same fields
/// as before: date, overall rating, optional subtitle — no new information
/// added, no rating recalculated. Tapping still opens the existing,
/// unchanged VisitDetailScreen/StayDetailScreen.
class VenueVisitRow extends StatelessWidget {
  final DateTime date;
  final int? rating;
  final String? subtitle;
  final VoidCallback onTap;

  const VenueVisitRow({
    super.key,
    required this.date,
    required this.rating,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CsSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatVenueVisitDate(date),
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                    if (rating != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Overall $rating/10',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.taupe,
                        ),
                      ),
                    ],
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.taupe,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.taupe,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Restrained status card for the loading / signed-out / empty states of
/// MY VISITS / MY STAYS — the shared twin of the two screens'
/// near-identical `_StatusCard`.
class VenueVisitStatusRow extends StatelessWidget {
  final IconData icon;
  final String message;

  const VenueVisitStatusRow({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(CsSpacing.base),
    decoration: BoxDecoration(
      color: AppColors.warmWhite,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      border: Border.all(color: AppColors.subtleBorderLight),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.taupe, size: 18),
        const SizedBox(width: CsSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ),
      ],
    ),
  );
}
