import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../models/event.dart';
import '../../../models/going_member_count.dart';
import '../../events/event_date_format.dart';
import '../../events/going_member_count_format.dart';
import 'community_shared.dart';

/// COMMUNITY V1 UI REFINEMENT — a compact, editorial "Upcoming Events"
/// preview reusing the existing Events infrastructure: [events] arrives
/// already fetched (via `EventsRepository.loadEvents`) and chronologically
/// sorted by the caller — this widget never queries or re-sorts. Each row
/// reuses the same canonical event image/placeholder policy as
/// `EventCard`/`VenueThumbnail` ([Event.imageUrl] when set, the branded
/// [CsImagePlaceholder] fallback otherwise — never a fabricated image).
///
/// [goingCounts] is the existing anonymous, platform-wide, privacy-capped
/// signal (`EventSocialRepository.getGoingMemberCount` /
/// `get_event_going_member_count`, capped at "100+") — a real signal,
/// reused as-is via [formatGoingMemberCount]'s own canonical copy. There
/// is deliberately no "N interested" count here: no equivalent anonymous
/// aggregate exists for Interested anywhere in the repository layer (see
/// this feature's own architecture note) — showing one would mean
/// fabricating it, which this pass explicitly must not do. A missing
/// entry in [goingCounts] for a given event (still loading, or the RPC
/// failed) simply omits that line, never a fake/zero placeholder.
///
/// This stays a preview, not a second Events catalogue — at most three
/// rows, with [onSeeAll] (when provided) linking to the existing, full
/// Events destination.
class CommunityEventsPreview extends StatelessWidget {
  final List<Event> events;
  final Map<String, GoingMemberCount> goingCounts;
  final ValueChanged<Event> onTapEvent;
  final VoidCallback? onSeeAll;

  const CommunityEventsPreview({
    super.key,
    required this.events,
    required this.goingCounts,
    required this.onTapEvent,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const CommunityEmptyNote(
        message: 'No upcoming events to show yet.',
      );
    }
    final preview = events.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < preview.length; i++) ...[
          if (i > 0) const SizedBox(height: CsSpacing.sm),
          _EventPreviewRow(
            event: preview[i],
            goingCount: goingCounts[preview[i].id],
            onTap: () => onTapEvent(preview[i]),
          ),
        ],
        if (onSeeAll != null) ...[
          const SizedBox(height: CsSpacing.sm),
          CommunityActionLink(label: 'See all', onTap: onSeeAll!),
        ],
      ],
    );
  }
}

class _EventPreviewRow extends StatelessWidget {
  final Event event;
  final GoingMemberCount? goingCount;
  final VoidCallback onTap;

  const _EventPreviewRow({
    required this.event,
    required this.goingCount,
    required this.onTap,
  });

  static const double _thumbnailSize = 64;

  @override
  Widget build(BuildContext context) {
    final going = goingCount == null ? null : formatGoingMemberCount(goingCount!);
    final location = [
      if (event.city != null && event.city!.isNotEmpty) event.city,
      event.countryCode,
    ].join(', ');

    return Semantics(
      button: true,
      label: '${event.name}. ${formatEventDateRange(event)}. $location.'
          '${going != null ? ' $going.' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CsRadius.medium),
          child: Container(
            padding: const EdgeInsets.all(CsSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.brandGreenLight,
              borderRadius: BorderRadius.circular(CsRadius.medium),
              border: Border.all(color: AppColors.subtleBorderDark),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _EventThumbnail(imageUrl: event.imageUrl),
                const SizedBox(width: CsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.placeTitle.copyWith(
                          color: AppColors.textOnDark,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatEventDateRange(event)} · $location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                      if (going != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          going,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.secondaryOnDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: CsSpacing.xs),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.secondaryOnDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The row's image slot — [Event.imageUrl] when set and loading
/// successfully, otherwise the same branded [CsImagePlaceholder]
/// `EventCard` already falls back to. No duplicated fallback policy: this
/// mirrors `EventCard`'s own `_EventImage` exactly, just at thumbnail
/// scale rather than a 16:9 banner.
class _EventThumbnail extends StatelessWidget {
  final String? imageUrl;
  const _EventThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CsRadius.small);
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CsImagePlaceholder(
        width: _EventPreviewRow._thumbnailSize,
        height: _EventPreviewRow._thumbnailSize,
        borderRadius: radius,
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        imageUrl!,
        width: _EventPreviewRow._thumbnailSize,
        height: _EventPreviewRow._thumbnailSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CsImagePlaceholder(
          width: _EventPreviewRow._thumbnailSize,
          height: _EventPreviewRow._thumbnailSize,
          borderRadius: radius,
        ),
      ),
    );
  }
}
