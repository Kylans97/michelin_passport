import 'package:flutter/material.dart';
import '../../../core/analytics/analytics_properties.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../events/event_date_format.dart';
import '../../events/event_detail_screen.dart';

/// One confirmed-attendance Event in the Passport list — Events V2 Step 4
/// §15. Built on the same [CsPlaceCard] shell as
/// PassportRestaurantCard/PassportHotelCard for visual consistency, but
/// deliberately NOT unified with them behind PassportVenue (see
/// EventAttendanceEntry's own doc comment for why). No awardRow: an Event
/// has no Michelin-star/Key concept of its own — §15's explicit "no
/// decorative gold except legitimate recognition treatment" is honored by
/// simply omitting the row entirely, never inventing a fake one.
class PassportEventCard extends StatelessWidget {
  final EventAttendanceEntry entry;

  const PassportEventCard({super.key, required this.entry});

  // Image priority (Step 4 photos pre-apply report §12): (1) the user's
  // own attendance photo, if one exists and resolved successfully, (2)
  // the official Event image, (3) the branded placeholder. Never the
  // reverse — an official Event image is never presented as if it were
  // the user's own experience, and a failed/unresolved attendance photo
  // URL falls through rather than showing a broken image.
  Widget _image() {
    final coverUrl = entry.coverPhotoUrl;
    final eventImageUrl = entry.event.imageUrl;
    const radius = BorderRadius.all(Radius.circular(CsRadius.medium));
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          coverUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackImage(eventImageUrl, radius),
        ),
      );
    }
    return _fallbackImage(eventImageUrl, radius);
  }

  Widget _fallbackImage(String? eventImageUrl, BorderRadius radius) {
    if (eventImageUrl != null && eventImageUrl.isNotEmpty) {
      return Image.network(
        eventImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CsImagePlaceholder(borderRadius: radius),
      );
    }
    return CsImagePlaceholder(borderRadius: radius);
  }

  @override
  Widget build(BuildContext context) {
    final event = entry.event;
    final attendance = entry.attendance;
    final location = [
      if (event.city != null && event.city!.isNotEmpty) event.city,
      event.countryCode,
    ].join(', ');

    return CsPlaceCard(
      image: _image(),
      eyebrow: event.eventType.label.toUpperCase(),
      title: event.name,
      subtitle: location,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatEventDateRange(event),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.metadata,
          ),
          if (attendance.rating != null) ...[
            const SizedBox(height: 2),
            Text(
              'Your rating: ${attendance.rating}/10',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.metadata.copyWith(
                color: AppColors.mutedBrassOnLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(
            eventId: event.id,
            sourceSurface: AnalyticsSourceSurface.passport,
          ),
        ),
      ),
    );
  }
}
