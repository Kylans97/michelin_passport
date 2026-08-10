import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/event.dart';
import '../event_date_format.dart';

/// One event in the discovery list — photo-ready thumbnail (reusing the
/// same VenueThumbnail placeholder venues use, since neither has real
/// imagery yet) plus name, date range and city/country. A cancelled event
/// is still shown, clearly marked, rather than silently disappearing.
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final location = [
      if (event.city != null && event.city!.isNotEmpty) event.city,
      event.countryCode,
    ].join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VenueThumbnail(imageUrl: event.imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: AppTypography.editorialHeading.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (event.isCancelled) ...[
                          const SizedBox(width: 8),
                          const _CancelledBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatEventDateRange(event),
                      style: AppTypography.metadata,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
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

class _CancelledBadge extends StatelessWidget {
  const _CancelledBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Text(
      'CANCELLED',
      style: GoogleFonts.inter(
        color: AppColors.error,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );
}
