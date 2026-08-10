import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
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

/// My Planned Trips: upcoming trips (with their venue counts) plus any
/// planned restaurant visits/hotel stays that aren't attached to a trip —
/// a trip is never required just to plan one restaurant.
class PlannedTripsScreen extends StatefulWidget {
  const PlannedTripsScreen({super.key});

  @override
  State<PlannedTripsScreen> createState() => _PlannedTripsScreenState();
}

class _PlannedTripsScreenState extends State<PlannedTripsScreen> {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'My Planned Trips',
          style: AppTypography.editorialHeading.copyWith(fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create trip',
            onPressed: _createTrip,
          ),
        ],
      ),
      body: _loading
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
              backgroundColor: AppColors.card,
              onRefresh: _load,
              child: (_trips.isEmpty && untripped.isEmpty)
                  ? const _EmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      children: [
                        if (_trips.isNotEmpty) ...[
                          Text('UPCOMING', style: AppTypography.sectionHeading),
                          const SizedBox(height: 14),
                          for (var i = 0; i < _trips.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            TripCard(
                              trip: _trips[i],
                              restaurantCount: (byTrip[_trips[i].id] ?? [])
                                  .where((v) => v.venue is RestaurantVenue)
                                  .length,
                              hotelCount: (byTrip[_trips[i].id] ?? [])
                                  .where((v) => v.venue is HotelVenue)
                                  .length,
                              onTap: () => _openTrip(_trips[i]),
                            ),
                          ],
                        ],
                        if (_trips.isNotEmpty && untripped.isNotEmpty)
                          const SizedBox(height: 32),
                        if (untripped.isNotEmpty) ...[
                          Text(
                            'PLANNED VISITS',
                            style: AppTypography.sectionHeading,
                          ),
                          const SizedBox(height: 14),
                          for (var i = 0; i < untripped.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_travel_rounded,
            color: AppColors.textSecondary,
            size: 44,
          ),
          const SizedBox(height: 16),
          Text(
            'No trips planned yet',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Plan a visit from any restaurant or hotel, or create a trip '
            'to group them together.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
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
          color: AppColors.textSecondary,
          size: 40,
        ),
        const SizedBox(height: 16),
        Text(
          'Could not load your trips',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: GoogleFonts.inter(color: AppColors.gold)),
        ),
      ],
    ),
  );
}
