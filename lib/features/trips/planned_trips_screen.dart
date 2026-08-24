import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_section_title.dart';
import '../../core/widgets/detail_hero.dart' show HeroIconButton;
import '../../data/repositories/planned_trips_repository.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/resolved_planned_venue.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'trip_detail_screen.dart';
import 'widgets/create_trip_sheet.dart';
import 'widgets/planned_venue_actions.dart';
import 'widgets/planned_venue_row.dart';
import 'widgets/trip_card.dart';
import 'widgets/trip_eyebrow.dart';

/// My Planned Trips: upcoming trips (with their venue counts) plus any
/// planned restaurant visits/hotel stays that aren't attached to a trip —
/// a trip is never required just to plan one restaurant. Dark editorial
/// canvas — a personal planning surface, not a browsable catalogue.
///
/// Passport Unified Experience V1: re-homed from a pushed, independently
/// scaffolded screen into one of [PassportScreen]'s four local
/// subsections — no back button, no separate "Trips" title (the shared
/// Passport header above this body covers that); the "Create trip" action
/// moves from beside the old back button to beside this body's own "YOUR
/// TRIPS" heading. Content and data logic are otherwise unchanged. Opening
/// a specific [TripDetailScreen] remains a normal pushed screen with its
/// own back arrow — the "same page" rule applies only to the four Passport
/// subsections themselves, never to deeper detail navigation.
class TripsBody extends StatefulWidget {
  const TripsBody({super.key});

  @override
  State<TripsBody> createState() => _TripsBodyState();
}

class _TripsBodyState extends State<TripsBody> {
  late final PlannedTripsRepository _repo = PlannedTripsRepository(
    Supabase.instance.client,
  );

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  bool _loading = true;
  bool _loadError = false;
  List<PlannedTrip> _trips = [];
  List<ResolvedPlannedVenue> _plannedVenues = [];

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
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _plannedVenues = venues;
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

    final byTrip = <String, List<ResolvedPlannedVenue>>{};
    for (final v in _plannedVenues) {
      final tripId = v.plan.tripId;
      if (tripId != null) byTrip.putIfAbsent(tripId, () => []).add(v);
    }

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
                      color: AppColors.gold,
                      strokeWidth: 1.5,
                    ),
                  )
                : _loadError
                ? _ErrorState(onRetry: _load)
                : RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.brandGreenLight,
                    onRefresh: _load,
                    child: (_trips.isEmpty && untripped.isEmpty)
                        ? _EmptyState(onCreateTrip: _createTrip)
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              CsSpacing.pageHorizontal,
                              0,
                              CsSpacing.pageHorizontal,
                              CsSpacing.section,
                            ),
                            children: [
                              if (_trips.isNotEmpty) ...[
                                const TripSectionLabel('UPCOMING'),
                                const SizedBox(height: CsSpacing.md),
                                for (var i = 0; i < _trips.length; i++) ...[
                                  if (i > 0)
                                    const SizedBox(height: CsSpacing.md),
                                  TripCard(
                                    trip: _trips[i],
                                    restaurantCount:
                                        (byTrip[_trips[i].id] ?? [])
                                            .where(
                                              (v) => v.venue is RestaurantVenue,
                                            )
                                            .length,
                                    hotelCount: (byTrip[_trips[i].id] ?? [])
                                        .where((v) => v.venue is HotelVenue)
                                        .length,
                                    onTap: () => _openTrip(_trips[i]),
                                  ),
                                ],
                              ],
                              if (_trips.isNotEmpty && untripped.isNotEmpty)
                                const SizedBox(height: CsSpacing.xxl),
                              if (untripped.isNotEmpty) ...[
                                const TripSectionLabel('PLANNED VISITS'),
                                const SizedBox(height: CsSpacing.md),
                                for (var i = 0; i < untripped.length; i++) ...[
                                  if (i > 0)
                                    const SizedBox(height: CsSpacing.sm),
                                  PlannedVenueRow(
                                    item: untripped[i],
                                    onTap: () => _openVenue(untripped[i]),
                                    onLongPress: () =>
                                        _showVenueActions(untripped[i]),
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
                Semantics(
                  button: true,
                  label: 'Plan a trip',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onCreateTrip,
                      borderRadius: BorderRadius.circular(CsRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CsSpacing.xl,
                          vertical: CsSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(CsRadius.pill),
                        ),
                        child: Text(
                          'Plan a trip',
                          style: CsTypography.bodyMedium.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
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
            style: CsTypography.bodyMedium.copyWith(color: AppColors.gold),
          ),
        ),
      ],
    ),
  );
}
