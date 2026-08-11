import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../models/event.dart';
import '../models/explore_search_results.dart';
import '../widgets/hotel_tile.dart';
import '../widgets/restaurant_tile.dart';
import 'explore_event_result_tile.dart';

/// Search mode's result list — RESTAURANTS / HOTELS / EVENTS as clearly
/// separated, labelled sections (never one flat alphabetically interleaved
/// list) rather than a lazy [SliverList]: a Search-mode result set is
/// already a small, filtered subset of the catalogue, the same "grouped
/// section, not virtualised" choice Explore's own previous All-mode
/// grouping and Trip/Event Detail's linked-venue sections already made.
/// Every section (and every tile inside it) is rendered in full for this
/// step rather than a capped "N of M, See all" subset — seeing every
/// matching result for a search this size is the simpler, safer choice,
/// and is reported as a trade-off rather than silently decided.
///
/// [RestaurantTile]/[HotelTile] are reused completely unmodified — both
/// already render as a warm ivory card, which reads correctly against
/// Explore's new deep-green canvas without any change. Notably, neither
/// takes an `onTap` callback: each already navigates to
/// RestaurantDetailScreen/HotelDetailScreen internally, exactly as it did
/// before this redesign — so there is deliberately no
/// onTapRestaurant/onTapHotel here to duplicate that. [ExploreEventResultTile]
/// is different: it's a new widget with no built-in navigation of its own
/// (events navigate by id, not by passing the whole model — see
/// EventDetailScreen), so [onTapEvent] is real and required.
class ExploreSearchResultsView extends StatelessWidget {
  final ExploreSearchResults results;
  final ValueChanged<Event> onTapEvent;

  const ExploreSearchResultsView({
    super.key,
    required this.results,
    required this.onTapEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (results.restaurants.isNotEmpty)
          _ResultSection(
            label: 'RESTAURANTS',
            count: results.restaurants.length,
            children: [
              for (final restaurant in results.restaurants)
                RestaurantTile(
                  restaurant: restaurant,
                  showWorlds50BestRank: true,
                ),
            ],
          ),
        if (results.hotels.isNotEmpty)
          _ResultSection(
            label: 'HOTELS',
            count: results.hotels.length,
            children: [
              for (final hotel in results.hotels)
                HotelTile(hotel: hotel, showWorlds50BestRank: true),
            ],
          ),
        if (results.events.isNotEmpty)
          _ResultSection(
            label: 'EVENTS',
            count: results.events.length,
            children: [
              for (final event in results.events)
                ExploreEventResultTile(
                  event: event,
                  onTap: () => onTapEvent(event),
                ),
            ],
          ),
        const SizedBox(height: 76),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String label;
  final int count;
  final List<Widget> children;

  const _ResultSection({
    required this.label,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.lg,
          CsSpacing.pageHorizontal,
          CsSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.eyebrow.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ),
            Text(
              '$count',
              style: CsTypography.eyebrow.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ),
      ),
      ...children,
    ],
  );
}

/// Search mode's "nothing matched" state — restrained copy on the deep-
/// green environment, never implying exhaustive worldwide coverage, and
/// never a generic Material empty-state box.
class ExploreSearchEmptyState extends StatelessWidget {
  const ExploreSearchEmptyState({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CsImagePlaceholder(
          width: 56,
          height: 56,
          borderRadius: BorderRadius.all(Radius.circular(14)),
          logoScale: 0.5,
        ),
        const SizedBox(height: CsSpacing.lg),
        Text(
          'No places found',
          textAlign: TextAlign.center,
          style: CsTypography.placeTitle.copyWith(color: AppColors.textOnDark),
        ),
        const SizedBox(height: CsSpacing.xs),
        Text(
          'Try another city, restaurant, hotel or event.',
          textAlign: TextAlign.center,
          style: CsTypography.metadata.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        ),
      ],
    ),
  );
}

/// Search mode's error state (the underlying repositories failed) — same
/// restrained deep-green treatment, distinct copy from
/// [ExploreSearchEmptyState] so "nothing matched" and "something broke"
/// never read the same way.
class ExploreSearchErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const ExploreSearchErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.secondaryOnDark,
          size: 32,
        ),
        const SizedBox(height: CsSpacing.base),
        Text(
          'Could not load results',
          textAlign: TextAlign.center,
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.md),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: CsTypography.bodyMedium.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
        ),
      ],
    ),
  );
}
