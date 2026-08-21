import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/analytics/analytics_properties.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/event_date_format.dart';
import '../../events/event_detail_screen.dart';
import '../models/map_pin.dart';

/// The bottom sheet shown when an Event pin is tapped — Events V2 Step 5
/// §9. Deliberately its own small component rather than folding Event into
/// [showVenuePreviewSheet]/`_VenuePreviewSheet`: that sheet's content
/// (award row, visit/stay count) doesn't apply to a confirmed Event
/// attendance, and forcing Event through PassportVenueStats's shape would
/// be the "awkward abstraction" this step was explicitly told to avoid.
/// Same visual chrome (card, radius, padding, deepGreen CTA, no gold) so it
/// still reads as the same map feature.
///
/// No Interested/Going controls here — this is a historical-attendance
/// surface, not an intent surface; the only action is "View event".
Future<void> showEventMapPreviewSheet(BuildContext context, EventMapPin pin) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EventMapPreviewSheet(pin: pin),
  );
}

class _EventMapPreviewSheet extends StatelessWidget {
  final EventMapPin pin;
  const _EventMapPreviewSheet({required this.pin});

  @override
  Widget build(BuildContext context) {
    final event = pin.entry.event;
    final rating = pin.entry.attendance.rating;
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;

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
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    event.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                event.name,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pin.subtitle,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatEventDateRange(event),
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (rating != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: AppColors.forestGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$rating/5',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    foregroundColor: AppColors.textOnDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(
                          eventId: event.id,
                          sourceSurface: AnalyticsSourceSurface.map,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'View event',
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
}
