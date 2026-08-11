import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../models/event.dart';
import '../../events/event_date_format.dart';

/// A compact event row for Explore's Search-mode results — same shape and
/// scale as [RestaurantTile]/[HotelTile] (small square thumbnail, name,
/// one metadata line), not [EventCard]'s large 16:9 editorial treatment,
/// which belongs to Discovery's "What's On" and the full [EventsScreen]
/// browse, not a dense scannable search list. Deliberately a new,
/// Explore-specific widget rather than a variant bolted onto [EventCard]
/// itself — see this task's explicit "do not redesign EventCard globally
/// unless absolutely necessary".
class ExploreEventResultTile extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const ExploreEventResultTile({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = [
      if (event.city != null && event.city!.isNotEmpty) event.city!,
      event.countryCode,
    ].join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              child: SizedBox(
                width: 56,
                height: 56,
                child: CsImagePlaceholder(logoScale: 0.4),
              ),
            ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.editorialHeading.copyWith(
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (event.isCancelled) ...[
                        const SizedBox(width: 6),
                        Text(
                          'CANCELLED',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatEventDateRange(event),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metadata,
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
