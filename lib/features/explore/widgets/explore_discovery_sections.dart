import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_section_title.dart';
import '../../../models/event.dart';
import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';
import 'explore_discovery_cards.dart';

/// A section heading shared by all three discovery sections: an eyebrow-
/// weight editorial title plus a short, restrained one-line subtitle — the
/// same "large Cormorant title, small Inter subtitle on secondaryOnDark"
/// pairing Explore's own header and Passport's header both already use.
/// Copy only (no data), so it's safe even when the section beneath it is
/// momentarily empty while loading.
class _DiscoverySectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _DiscoverySectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CsSectionTitle(
              title,
              color: AppColors.textOnDark,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ),
      ),
      if (trailing != null) Flexible(child: trailing!),
    ],
  );
}

class _ViewAllLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ViewAllLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.xs,
          vertical: CsSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.metadata.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textOnDark,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}

/// The most prominent discovery section — one large [ExploreFeaturedEventCard]
/// for the soonest upcoming, non-cancelled event (see
/// discovery_selectors.dart's selectFeaturedEvent), plus a "View all
/// events" link through to the existing, unmodified [EventsScreen]. Renders
/// nothing at all when there's no featured event yet (first load) or none
/// exists (selector returned null, or the events fetch failed — see this
/// section's call site in ExploreScreen for why a failed fetch degrades to
/// "nothing to feature" rather than an inline error box).
class WhatsOnSection extends StatelessWidget {
  final Event? featuredEvent;
  final ValueChanged<Event> onTapEvent;
  final VoidCallback onViewAll;

  const WhatsOnSection({
    super.key,
    required this.featuredEvent,
    required this.onTapEvent,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final event = featuredEvent;
    if (event == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.section,
        CsSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiscoverySectionHeader(
            title: "WHAT'S ON",
            subtitle: 'Things worth making plans for.',
            trailing: _ViewAllLink(label: 'View all events', onTap: onViewAll),
          ),
          const SizedBox(height: CsSpacing.base),
          ExploreFeaturedEventCard(
            event: event,
            onTap: () => onTapEvent(event),
          ),
        ],
      ),
    );
  }
}

/// The restaurant discovery section — a horizontally-scrolling row of
/// [ExploreDiscoveryRestaurantCard]s. [restaurants] is expected to already
/// be the selected/limited discovery subset (see
/// discovery_selectors.dart's selectDiscoveryRestaurants) — this widget
/// only renders what it's given. Renders nothing while the list is empty
/// (first load, or the catalogue fetch failed) rather than an empty-state
/// box — a non-critical discovery row silently omitting itself is the
/// right degrade here, not a visible error.
class WorthTheJourneySection extends StatelessWidget {
  final List<Restaurant> restaurants;
  final ValueChanged<Restaurant> onTapRestaurant;

  const WorthTheJourneySection({
    super.key,
    required this.restaurants,
    required this.onTapRestaurant,
  });

  @override
  Widget build(BuildContext context) {
    if (restaurants.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, CsSpacing.section, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CsSpacing.pageHorizontal,
            ),
            child: const _DiscoverySectionHeader(
              title: 'WORTH THE JOURNEY',
              subtitle: 'Tables carrying real distinction.',
            ),
          ),
          const SizedBox(height: CsSpacing.base),
          // Sized generously enough for a 2-line title plus every other
          // line at ~1.6x text scale (a ListView can't use IntrinsicHeight
          // to size itself, since a lazy/scrollable Viewport doesn't
          // support intrinsic-dimension queries) — comfortably above the
          // ~301px the tallest realistic card content needs at that scale.
          SizedBox(
            height: 340,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ),
              itemCount: restaurants.length,
              separatorBuilder: (_, _) => const SizedBox(width: CsSpacing.md),
              itemBuilder: (context, i) => ExploreDiscoveryRestaurantCard(
                restaurant: restaurants[i],
                onTap: () => onTapRestaurant(restaurants[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hotel discovery section — mirrors [WorthTheJourneySection] exactly,
/// with [ExploreDiscoveryHotelCard]'s image-left layout giving it a
/// distinct rhythm from the restaurant row above rather than repeating the
/// same card shape.
class StayALittleLongerSection extends StatelessWidget {
  final List<Hotel> hotels;
  final ValueChanged<Hotel> onTapHotel;

  const StayALittleLongerSection({
    super.key,
    required this.hotels,
    required this.onTapHotel,
  });

  @override
  Widget build(BuildContext context) {
    if (hotels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, CsSpacing.section, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CsSpacing.pageHorizontal,
            ),
            child: const _DiscoverySectionHeader(
              title: 'STAY A LITTLE LONGER',
              subtitle: 'Hotels worth extending your trip for.',
            ),
          ),
          const SizedBox(height: CsSpacing.base),
          // Same reasoning as WorthTheJourneySection's row height — sized
          // for a 2-line title at ~1.6x text scale (~151px), with margin.
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ),
              itemCount: hotels.length,
              separatorBuilder: (_, _) => const SizedBox(width: CsSpacing.md),
              itemBuilder: (context, i) => ExploreDiscoveryHotelCard(
                hotel: hotels[i],
                onTap: () => onTapHotel(hotels[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
