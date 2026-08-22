import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../models/event.dart';
import '../../../models/event_relevance_reason.dart';
import '../event_date_format.dart';

/// One event in the discovery list — an atmospheric banner image (fixed
/// 16:9, BoxFit.cover) across the top when [Event.imageUrl] is populated,
/// falling back to the branded [CsImagePlaceholder] VenueThumbnail uses
/// elsewhere (so a missing/failed image never leaves a blank gap) — then
/// name, date range, city/country and admission below. A cancelled event
/// is still shown, clearly marked, rather than silently disappearing.
///
/// Events V2 Step 8A: [reason], when non-null, renders as one small,
/// understated icon+text row between location and the free-entry badge —
/// editorial context, not a promotional badge (§11/§12). Never more than
/// this one reason, regardless of how many the caller's ranking logic
/// internally knew about.
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final EventRelevanceReason? reason;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final location = [
      if (event.city != null && event.city!.isNotEmpty) event.city,
      event.countryCode,
    ].join(', ');
    final isFreeEntry = event.isFreeEntry;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _EventImage(imageUrl: event.imageUrl),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
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
                    if (reason != null) ...[
                      const SizedBox(height: 6),
                      _RelevanceReasonRow(reason: reason!),
                    ],
                    if (isFreeEntry) ...[
                      const SizedBox(height: 6),
                      const _FreeEntryBadge(),
                    ],
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

/// The card's banner slot — a real photo when [imageUrl] is set and loads
/// successfully, otherwise the branded [CsImagePlaceholder] in every other
/// case (null, empty, or a failed load via [errorBuilder]) — never a
/// broken-image icon or blank space.
class _EventImage extends StatelessWidget {
  final String? imageUrl;
  const _EventImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const CsImagePlaceholder();
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const CsImagePlaceholder(),
    );
  }
}

/// One consistent visual treatment for every [EventRelevanceReasonType] —
/// small icon + text, brand green, no per-reason color families and no
/// emoji (§12). Existing Material icons only, chosen to read as a plain
/// glyph rather than a decoration competing with the title/date/location
/// above it.
IconData _iconForReasonType(EventRelevanceReasonType type) => switch (type) {
  EventRelevanceReasonType.trip => Icons.card_travel,
  EventRelevanceReasonType.friendGoing => Icons.people_alt_outlined,
  EventRelevanceReasonType.followedHost => Icons.bookmark_outline,
  EventRelevanceReasonType.friendInterested => Icons.star_border,
  EventRelevanceReasonType.popular => Icons.trending_up,
};

class _RelevanceReasonRow extends StatelessWidget {
  final EventRelevanceReason reason;
  const _RelevanceReasonRow({required this.reason});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        _iconForReasonType(reason.type),
        size: 13,
        color: AppColors.brandGreen,
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          reason.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppColors.brandGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _FreeEntryBadge extends StatelessWidget {
  const _FreeEntryBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.brandGreen.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.3)),
    ),
    child: Text(
      'FREE ENTRY',
      style: GoogleFonts.inter(
        color: AppColors.brandGreen,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );
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
