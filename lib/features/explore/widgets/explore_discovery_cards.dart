import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/event.dart';
import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';
import '../../events/event_date_format.dart';

String _locationOf({required String flagEmoji, required String cityName}) =>
    [if (flagEmoji.isNotEmpty) flagEmoji, cityName].join('  ');

/// The single large card leading "WHAT'S ON" — the soonest upcoming,
/// non-cancelled event (see [selectFeaturedEvent] in
/// ../discovery_selectors.dart). A real photo when [Event.imageUrl] is
/// populated, otherwise the branded [CsImagePlaceholder] — same fallback
/// EventCard already uses, just at a larger, more editorial scale here.
///
/// Deliberately leaves room to grow: a future "8 interested · 3 friends
/// going" line (see the task's event-social-readiness note) would slot in
/// directly below the date/location block as one more line in the same
/// Column, without restructuring anything above it. No placeholder or fake
/// count is rendered for that today.
class ExploreFeaturedEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const ExploreFeaturedEventCard({
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.card),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.ivory,
            borderRadius: BorderRadius.circular(CsRadius.card),
            border: Border.all(color: AppColors.subtleBorderLight, width: 0.5),
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
                padding: const EdgeInsets.all(CsSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.placeTitle,
                          ),
                        ),
                        if (event.isCancelled) ...[
                          const SizedBox(width: CsSpacing.sm),
                          const _CancelledBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      formatEventDateRange(event),
                      style: CsTypography.metadata,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.metadata,
                    ),
                    if (event.isFreeEntry) ...[
                      const SizedBox(height: CsSpacing.sm),
                      const _FreeEntryBadge(),
                    ],
                    // A future attendance line ("8 interested · 3 friends
                    // going") would be one more Text/Row here — see this
                    // widget's own doc comment.
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

class _EventImage extends StatelessWidget {
  final String? imageUrl;
  const _EventImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const CsImagePlaceholder(logoScale: 0.3);
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const CsImagePlaceholder(logoScale: 0.3),
    );
  }
}

class _FreeEntryBadge extends StatelessWidget {
  const _FreeEntryBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.deepGreen.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(CsRadius.pill),
      border: Border.all(color: AppColors.deepGreen.withValues(alpha: 0.25)),
    ),
    child: Text(
      'FREE ENTRY',
      style: CsTypography.eyebrow.copyWith(
        color: AppColors.deepGreen,
        fontSize: 9.5,
        letterSpacing: 0.6,
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
      borderRadius: BorderRadius.circular(CsRadius.pill),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Text(
      'CANCELLED',
      style: CsTypography.eyebrow.copyWith(
        color: AppColors.error,
        fontSize: 9.5,
        letterSpacing: 0.6,
      ),
    ),
  );
}

/// One "Worth the Journey" card — image on top, content below. Fixed width
/// for a horizontally-scrolling row. Shows only what's essential for a
/// discovery browse (name, location, Michelin distinction, World's 50 Best
/// where genuinely relevant) — never a dense catalogue-row treatment.
class ExploreDiscoveryRestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  static const double width = 200;

  const ExploreDiscoveryRestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = _locationOf(
      flagEmoji: restaurant.flagEmoji,
      cityName: restaurant.cityName,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.card),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: AppColors.ivory,
            borderRadius: BorderRadius.circular(CsRadius.card),
            border: Border.all(color: AppColors.subtleBorderLight, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AspectRatio(
                aspectRatio: 4 / 3,
                child: CsImagePlaceholder(logoScale: 0.32),
              ),
              Padding(
                padding: const EdgeInsets.all(CsSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.metadata,
                      ),
                    if (restaurant.hasMichelinStar) ...[
                      const SizedBox(height: CsSpacing.xs),
                      StarRow(count: restaurant.michelinStars!, size: 12),
                    ] else if (restaurant.isWorlds50Best) ...[
                      const SizedBox(height: CsSpacing.xs),
                      Text(
                        "World's 50 Best · #${restaurant.worlds50BestRank}",
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One "Stay a Little Longer" card — a horizontal row layout (image left,
/// content right) rather than "Worth the Journey"'s image-on-top layout,
/// so the two discovery sections read as visually distinct even though
/// both are horizontally-scrolling rows of ivory cards.
class ExploreDiscoveryHotelCard extends StatelessWidget {
  final Hotel hotel;
  final VoidCallback onTap;

  static const double width = 240;

  const ExploreDiscoveryHotelCard({
    super.key,
    required this.hotel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = _locationOf(
      flagEmoji: hotel.flagEmoji,
      cityName: hotel.cityName,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.card),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(CsSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.ivory,
            borderRadius: BorderRadius.circular(CsRadius.card),
            border: Border.all(color: AppColors.subtleBorderLight, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClipRRect(
                borderRadius: BorderRadius.all(
                  Radius.circular(CsRadius.medium),
                ),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CsImagePlaceholder(logoScale: 0.34),
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.metadata,
                      ),
                    if (hotel.hasMichelinKeys) ...[
                      const SizedBox(height: CsSpacing.xs),
                      KeyRow(count: hotel.michelinKeys!, size: 12),
                    ] else if (hotel.isWorlds50Best) ...[
                      const SizedBox(height: CsSpacing.xs),
                      Text(
                        "World's 50 Best · #${hotel.worlds50BestRank}",
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
