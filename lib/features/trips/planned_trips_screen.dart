import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_section_title.dart';
import '../../core/widgets/detail_hero.dart' show HeroIconButton;
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../models/event.dart';
import '../../models/event_trip_match.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/resolved_planned_venue.dart';
import '../events/event_detail_screen.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'all_upcoming_trips_screen.dart';
import 'planned_visit_schedule.dart';
import 'trip_detail_screen.dart';
import 'trip_schedule.dart';
import 'widgets/create_trip_sheet.dart';
import 'widgets/planned_venue_actions.dart';
import 'widgets/planned_venue_row.dart';
import 'widgets/trip_card.dart';
import 'widgets/trip_eyebrow.dart';
import 'widgets/trip_hero_card.dart';

/// My Planned Trips: the single next upcoming trip (with its venue counts
/// and, if one overlaps, a matching event) as the clear focal point, then
/// any further upcoming trips one tap away, then any planned restaurant
/// visits/hotel stays that aren't attached to a trip — a trip is never
/// required just to plan one restaurant. Dark editorial canvas — a
/// personal planning surface, not a browsable catalogue.
///
/// Passport Unified Experience V1: re-homed from a pushed, independently
/// scaffolded screen into one of [PassportScreen]'s four local
/// subsections — no back button, no separate "Trips" title (the shared
/// Passport header above this body covers that); the "Create trip" action
/// moves from beside the old back button to beside this body's own "YOUR
/// TRIPS" heading. Opening a specific [TripDetailScreen] (or
/// [AllUpcomingTripsScreen]) remains a normal pushed screen with its own
/// back arrow — the "same page" rule applies only to the four Passport
/// subsections themselves, never to deeper navigation reached from within
/// one of them.
///
/// TRIPS HERO REDESIGN: previously every trip in [_trips] rendered as an
/// equally-sized [TripCard] under "UPCOMING," regardless of whether it
/// had actually already ended — [_trips] itself was never date-filtered.
/// Now [upcomingTrips] filters to trips that genuinely haven't ended yet
/// (calendar-date comparison, matching [eventMatchesTrip]'s own reasoning
/// for why that must not be a raw `DateTime` comparison), and only the
/// soonest of those renders, as [TripHeroCard] — an ivory card, the one
/// deliberate light object on this otherwise deep-green page, so it reads
/// as the clear focal point rather than another green block. Any further
/// upcoming trips stay reachable via a single "N more trips →" link
/// rather than disappearing; nothing about trip creation, editing,
/// deletion changes.
///
/// PLANNED VISITS REFINEMENT: the same "was never date-filtered" defect
/// existed here too — every untripped planned venue rendered regardless
/// of whether its visit/stay date had already passed. [upcomingPlannedVenues]
/// (see planned_visit_schedule.dart) now filters PLANNED VISITS down to
/// what's still upcoming or ongoing, nearest first; a section that would
/// otherwise render with a header and nothing under it shows a small
/// "Nothing planned yet." line instead. Filtering only changes what
/// renders here — it never deletes the underlying `planned_venues` row,
/// so a past visit remains exactly where Passport's own visit history
/// already reads it from.
class TripsBody extends StatefulWidget {
  const TripsBody({super.key});

  @override
  State<TripsBody> createState() => _TripsBodyState();
}

class _TripsBodyState extends State<TripsBody> {
  late final PlannedTripsRepository _repo = PlannedTripsRepository(
    Supabase.instance.client,
  );
  late final EventsRepository _eventsRepo = EventsRepository(
    Supabase.instance.client,
  );

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  bool _loading = true;
  bool _loadError = false;
  List<PlannedTrip> _trips = [];
  List<ResolvedPlannedVenue> _plannedVenues = [];

  // The soonest upcoming trip's own matching event, if any — see
  // eventsMatchingTrip, the exact function TripDetailScreen's "WHAT'S ON"
  // section already uses. Refetched from _load() whenever the featured
  // trip itself might have changed (a new trip added, dates edited).
  Event? _matchingEvent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final tripsFuture = _repo.loadTrips(_userId);
      final venuesFuture = _repo.loadResolvedPlannedVenues(_userId);
      final trips = await tripsFuture;
      final venues = await venuesFuture;

      Event? matchingEvent;
      final upcoming = upcomingTrips(trips);
      if (upcoming.isNotEmpty) {
        final featured = upcoming.first;
        try {
          final events = await _eventsRepo.loadEventsForCountry(
            featured.countryCode,
          );
          final matches = eventsMatchingTrip(events, featured);
          if (matches.isNotEmpty) matchingEvent = matches.first;
        } catch (_) {
          // The event overlay is a subtle bonus, never a reason to fail
          // the rest of Trips — same "never fails the rest of the
          // screen" precedent as PassportCollectionBody's own secondary
          // event-attendance fetch.
        }
      }

      if (!mounted) return;
      setState(() {
        _trips = trips;
        _plannedVenues = venues;
        _matchingEvent = matchingEvent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _createTrip() async {
    final saved = await showCreateTripSheet(
      context,
      userId: _userId,
      repo: _repo,
    );
    if (saved == true) _load();
  }

  void _openTrip(PlannedTrip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
    );
    _load();
  }

  void _openEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          sourceSurface: AnalyticsSourceSurface.tripRecommendation,
        ),
      ),
    );
  }

  void _openAllUpcomingTrips(List<UpcomingTripSummary> trips) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AllUpcomingTripsScreen(trips: trips)),
    );
    _load();
  }

  Future<void> _showVenueActions(ResolvedPlannedVenue item) async {
    final changed = await showPlannedVenueActions(
      context,
      item: item,
      userId: _userId,
      repo: _repo,
    );
    if (changed) _load();
  }

  void _openVenue(ResolvedPlannedVenue item) {
    switch (item.venue) {
      case RestaurantVenue(:final restaurant):
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        );
      case HotelVenue(:final hotel):
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final untripped = [
      for (final v in _plannedVenues)
        if (v.plan.tripId == null) v,
    ]..sort((a, b) => a.plan.startDate.compareTo(b.plan.startDate));
    // Planned Visits Refinement — PLANNED VISITS shows only genuinely
    // upcoming/ongoing entries; [untripped] itself stays the full,
    // unfiltered set (still used below purely to decide whether the
    // section exists at all vs. the page's own top-level empty state —
    // a user who has planned visits, just none upcoming right now, gets
    // the section's own small empty line, not the big "no trips" CTA).
    final upcomingUntripped = upcomingPlannedVenues(untripped);

    final byTrip = <String, List<ResolvedPlannedVenue>>{};
    for (final v in _plannedVenues) {
      final tripId = v.plan.tripId;
      if (tripId != null) byTrip.putIfAbsent(tripId, () => []).add(v);
    }

    int restaurantCountFor(String tripId) => (byTrip[tripId] ?? [])
        .where((v) => v.venue is RestaurantVenue)
        .length;
    int hotelCountFor(String tripId) =>
        (byTrip[tripId] ?? []).where((v) => v.venue is HotelVenue).length;

    final upcoming = upcomingTrips(_trips);
    final featuredTrip = upcoming.isEmpty ? null : upcoming.first;
    final remainingCount = upcoming.isEmpty ? 0 : upcoming.length - 1;

    // Passport Unified Experience V1 — no own Scaffold/SafeArea/back
    // button/title anymore: this body is embedded directly beneath the
    // shared Passport header + local tab bar. "Create trip" moves beside
    // this body's own "YOUR TRIPS" heading, in place of the old back
    // button row.
    return ColoredBox(
      color: AppColors.deepGreen,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.md,
              CsSpacing.pageHorizontal,
              0,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: CsSectionTitle(
                    'YOUR TRIPS',
                    color: AppColors.textOnDark,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tooltip(
                  message: 'Create trip',
                  child: HeroIconButton(
                    icon: Icons.add_rounded,
                    onTap: _createTrip,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CsSpacing.lg),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.textOnDark,
                      strokeWidth: 1.5,
                    ),
                  )
                : _loadError
                ? _ErrorState(onRetry: _load)
                : RefreshIndicator(
                    color: AppColors.textOnDark,
                    backgroundColor: AppColors.brandGreenLight,
                    onRefresh: _load,
                    child: (upcoming.isEmpty && untripped.isEmpty)
                        ? _EmptyState(onCreateTrip: _createTrip)
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              CsSpacing.pageHorizontal,
                              0,
                              CsSpacing.pageHorizontal,
                              CsSpacing.section,
                            ),
                            children: [
                              if (featuredTrip != null) ...[
                                const TripSectionLabel('UPCOMING'),
                                const SizedBox(height: CsSpacing.md),
                                TripHeroCard(
                                  trip: featuredTrip,
                                  restaurantCount: restaurantCountFor(
                                    featuredTrip.id,
                                  ),
                                  hotelCount: hotelCountFor(featuredTrip.id),
                                  matchingEvent: _matchingEvent,
                                  onTap: () => _openTrip(featuredTrip),
                                  onTapEvent: _matchingEvent == null
                                      ? null
                                      : () => _openEvent(_matchingEvent!),
                                ),
                                if (remainingCount > 0) ...[
                                  const SizedBox(height: CsSpacing.sm),
                                  MoreTripsLink(
                                    count: remainingCount,
                                    onTap: () => _openAllUpcomingTrips([
                                      for (final trip in upcoming)
                                        (
                                          trip: trip,
                                          restaurantCount: restaurantCountFor(
                                            trip.id,
                                          ),
                                          hotelCount: hotelCountFor(trip.id),
                                        ),
                                    ]),
                                  ),
                                ],
                              ],
                              if (featuredTrip != null && untripped.isNotEmpty)
                                const SizedBox(height: CsSpacing.xxl),
                              if (untripped.isNotEmpty) ...[
                                const TripSectionLabel('PLANNED VISITS'),
                                const SizedBox(height: CsSpacing.md),
                                if (upcomingUntripped.isEmpty)
                                  Text(
                                    'Nothing planned yet.',
                                    style: CsTypography.body.copyWith(
                                      color: AppColors.secondaryOnDark,
                                    ),
                                  )
                                else
                                  for (
                                    var i = 0;
                                    i < upcomingUntripped.length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      const SizedBox(height: CsSpacing.sm),
                                    PlannedVenueRow(
                                      item: upcomingUntripped[i],
                                      onTap: () =>
                                          _openVenue(upcomingUntripped[i]),
                                      onLongPress: () => _showVenueActions(
                                        upcomingUntripped[i],
                                      ),
                                    ),
                                  ],
                              ],
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTrip;
  const _EmptyState({required this.onCreateTrip});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No trips planned yet',
                  textAlign: TextAlign.center,
                  style: CsTypography.placeTitle.copyWith(
                    color: AppColors.textOnDark,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: CsSpacing.sm),
                Text(
                  'Start with a destination, then collect the places worth '
                  'travelling for.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
                const SizedBox(height: CsSpacing.xl),
                SizedBox(
                  width: 200,
                  child: CsPrimaryButton(
                    label: 'Plan a trip',
                    onTap: onCreateTrip,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.secondaryOnDark,
          size: 40,
        ),
        const SizedBox(height: CsSpacing.base),
        Text(
          'Could not load your trips',
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
