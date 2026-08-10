import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/event.dart';
import '../event_date_format.dart';

/// One event in the discovery list — an atmospheric banner image (fixed
/// 16:9, BoxFit.cover) across the top when [Event.imageUrl] is populated,
/// falling back to the same brand-green tonal treatment VenueThumbnail
/// uses elsewhere (so a missing/failed image never leaves a blank gap) —
/// then name, date range, city/country and admission below. A cancelled
/// event is still shown, clearly marked, rather than silently
/// disappearing.
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
/// successfully, otherwise the same brand-green tonal placeholder in every
/// other case (null, empty, or a failed load via [errorBuilder]) — deep
/// green is always the Chasing Stars fallback, never a broken-image icon
/// or blank space.
class _EventImage extends StatelessWidget {
  final String? imageUrl;
  const _EventImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const _EventImagePlaceholder();
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _EventImagePlaceholder(),
    );
  }
}

class _EventImagePlaceholder extends StatelessWidget {
  const _EventImagePlaceholder();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.brandGreenLight, AppColors.brandGreen],
      ),
    ),
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
