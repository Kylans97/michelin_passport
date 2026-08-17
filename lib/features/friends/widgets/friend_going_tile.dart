import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/event.dart';
import '../../events/event_date_format.dart';

/// One upcoming event a friend is going to (Community/Friends UX Step 1).
/// Same photo-ready editorial row language as [FriendVisitTile]/
/// [FriendWishlistTile] — [VenueThumbnail] reused for the leading slot
/// (Event.imageUrl is already a real field, unlike Restaurant/Hotel, so
/// this row is already fully photo-ready today, not just seam-ready), name
/// strongest, then date + city/country. Country is shown as plain text —
/// deliberately no flag glyph, since (unlike Restaurant/Hotel) [Event] has
/// no canonical flagEmoji field and one must never be hardcoded per venue
/// row (see docs/Architecture/COMMUNITY_FRIENDS_UX.md).
///
/// [onTap] opens the canonical, unmodified EventDetailScreen — never a
/// social wrapper, mirroring the venue-navigation rule exactly.
class FriendGoingTile extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const FriendGoingTile({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final location = [
      if (event.city != null && event.city!.isNotEmpty) event.city,
      event.countryCode,
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    final dateAndLocation = location.isEmpty
        ? formatEventDateRange(event)
        : '${formatEventDateRange(event)} · $location';

    final semanticLabel = [
      event.name,
      formatEventDateRange(event),
      if (location.isNotEmpty) location,
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                VenueThumbnail(imageUrl: event.imageUrl, size: 52),
                const SizedBox(width: CsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: CsTypography.placeTitle.copyWith(
                          fontSize: 17,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateAndLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.taupe,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
