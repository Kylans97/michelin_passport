import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/event.dart';
import '../../models/event_trip_match.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/resolved_planned_venue.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/event_card.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import '../restaurants/widgets/detail_section.dart';
import 'widgets/create_trip_sheet.dart';
import 'widgets/hotel_picker_sheet.dart';
import 'widgets/planned_venue_actions.dart';
import 'widgets/planned_venue_row.dart';
import 'widgets/restaurant_picker_sheet.dart';
import 'widgets/trip_card.dart' show formatTripDateRange;

/// A single trip: destination, dates, notes, and every planned restaurant/
/// hotel attached to it. Editing/deleting the trip and each planned venue
/// all live here.
class TripDetailScreen extends StatefulWidget {
  final PlannedTrip trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final PlannedTripsRepository _repo = PlannedTripsRepository(
    Supabase.instance.client,
  );
  late final EventsRepository _eventsRepo = EventsRepository(
    Supabase.instance.client,
  );
  late final HotelRepository _hotelRepo = HotelRepository(
    Supabase.instance.client,
  );
  late final RestaurantRepository _restaurantRepo = RestaurantRepository(
    Supabase.instance.client,
  );

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  late PlannedTrip _trip = widget.trip;
  bool _loading = true;
  List<ResolvedPlannedVenue> _venues = [];
  List<Event> _matchingEvents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final venuesFuture = _repo.loadResolvedPlannedVenues(_userId);
      // Country-scoped fetch, then pure-function matching client-side (see
      // eventsMatchingTrip) — the user never has to manually attach an
      // event to a trip for it to show up here.
      final eventsFuture = _eventsRepo.loadEventsForCountry(_trip.countryCode);
      final venues = await venuesFuture;
      final events = await eventsFuture;
      if (!mounted) return;
      setState(() {
        _venues = venues.where((v) => v.plan.tripId == _trip.id).toList();
        _matchingEvents = eventsMatchingTrip(events, _trip);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: isError ? AppColors.textPrimary : Colors.black,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.gold,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editTrip() async {
    final saved = await showCreateTripSheet(
      context,
      userId: _userId,
      repo: _repo,
      existingTrip: _trip,
    );
    if (saved == true) {
      final trips = await _repo.loadTrips(_userId);
      final updated = trips.where((t) => t.id == _trip.id);
      if (updated.isNotEmpty && mounted) {
        setState(() => _trip = updated.first);
        // Country/dates may have changed — re-run event matching against
        // the updated trip, not the stale one.
        await _load();
      }
    }
  }

  Future<void> _deleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete this trip?',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        content: Text(
          _venues.isEmpty
              ? 'This will permanently remove the trip.'
              : 'This will permanently remove the trip. Your ${_venues.length} '
                    'planned ${_venues.length == 1 ? 'venue' : 'venues'} will '
                    'NOT be deleted — they\'ll just no longer belong to a trip.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete trip',
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteTrip(userId: _userId, tripId: _trip.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not delete trip. Please try again.', isError: true);
    }
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

  void _openEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
    );
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

  // "Change hotel" replaces rather than edits in place: planned_venues has
  // no column for which venue a row addresses other than entity_id itself,
  // and there is no update-entity_id method (see PlannedTripsRepository) —
  // editing a plan only ever changes its dates/notes/status, never which
  // venue it points to. Swapping hotels is therefore delete-old +
  // create-new, both against the same normalized entity_id/trip_id shape
  // Create Trip's own hotel picker writes.
  Future<void> _addOrChangeHotel(List<ResolvedPlannedVenue> hotels) async {
    final picked = await showHotelPickerSheet(context, repo: _hotelRepo);
    if (picked == null) return;
    try {
      for (final existing in hotels) {
        await _repo.deletePlannedVenue(
          userId: _userId,
          plannedVenueId: existing.plan.id,
        );
      }
      await _repo.createPlannedVenue(
        userId: _userId,
        entityType: 'hotel',
        entityId: picked.id,
        tripId: _trip.id,
        startDate: _trip.startDate,
        endDate: _trip.endDate,
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Could not update the hotel. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _addRestaurant(List<ResolvedPlannedVenue> restaurants) async {
    final picked = await showRestaurantPickerSheet(
      context,
      repo: _restaurantRepo,
      excludeIds: {
        for (final r in restaurants)
          if (r.venue case RestaurantVenue(:final restaurant)) restaurant.id,
      },
    );
    if (picked == null) return;
    try {
      await _repo.createPlannedVenue(
        userId: _userId,
        entityType: 'restaurant',
        entityId: picked.id,
        tripId: _trip.id,
        startDate: _trip.startDate,
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Could not add that restaurant. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _removeVenue(ResolvedPlannedVenue item) async {
    final isHotel = item.venue is HotelVenue;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          isHotel ? 'Remove this hotel?' : 'Remove this restaurant?',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        content: Text(
          'This only removes it from the trip — nothing is deleted from '
          'the catalogue.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deletePlannedVenue(
        userId: _userId,
        plannedVenueId: item.plan.id,
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not remove. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = _venues
        .where((v) => v.venue is RestaurantVenue)
        .toList();
    final hotels = _venues.where((v) => v.venue is HotelVenue).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.brandGreen),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textOnDark,
                            size: 18,
                          ),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.textOnDark,
                              ),
                              tooltip: 'Edit trip',
                              onPressed: _editTrip,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.textOnDark,
                              ),
                              tooltip: 'Delete trip',
                              onPressed: _deleteTrip,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _trip.title,
                            style: AppTypography.display.copyWith(
                              color: AppColors.textOnDark,
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatTripDateRange(_trip),
                            style: AppTypography.metadata.copyWith(
                              color: AppColors.textOnDark.withValues(
                                alpha: 0.75,
                              ),
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
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 1.5,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    children: [
                      if (_trip.city != null && _trip.city!.isNotEmpty ||
                          _trip.notes != null && _trip.notes!.isNotEmpty)
                        DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_trip.city != null && _trip.city!.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_city_rounded,
                                      color: AppColors.textSecondary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _trip.city!,
                                      style: GoogleFonts.inter(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              if (_trip.notes != null &&
                                  _trip.notes!.isNotEmpty) ...[
                                if (_trip.city != null &&
                                    _trip.city!.isNotEmpty)
                                  const SizedBox(height: 12),
                                Text(
                                  _trip.notes!,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      // Kept visually quiet when empty (omitted outright,
                      // per the task's explicit instruction) rather than
                      // showing an empty-state block — a trip with no
                      // matching events shouldn't look "broken".
                      if (_matchingEvents.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const SectionLabel('CULINARY EVENTS DURING YOUR TRIP'),
                        const SizedBox(height: 12),
                        for (var i = 0; i < _matchingEvents.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          EventCard(
                            event: _matchingEvents[i],
                            onTap: () => _openEvent(_matchingEvents[i]),
                          ),
                        ],
                      ],
                      const SizedBox(height: 28),

                      _SectionHeaderRow(
                        label:
                            'RESTAURANTS'
                            '${restaurants.isNotEmpty ? ' (${restaurants.length})' : ''}',
                        actionLabel: 'Add',
                        onAction: () => _addRestaurant(restaurants),
                      ),
                      const SizedBox(height: 12),
                      if (restaurants.isEmpty)
                        _EmptySlot(
                          message: 'No restaurants planned for this trip yet.',
                        )
                      else
                        for (var i = 0; i < restaurants.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _RemovableVenueRow(
                            item: restaurants[i],
                            onTap: () => _openVenue(restaurants[i]),
                            onLongPress: () =>
                                _showVenueActions(restaurants[i]),
                            onRemove: () => _removeVenue(restaurants[i]),
                          ),
                        ],
                      const SizedBox(height: 28),

                      _SectionHeaderRow(
                        label:
                            'HOTEL'
                            '${hotels.isNotEmpty ? ' (${hotels.length})' : ''}',
                        actionLabel: hotels.isEmpty ? 'Add' : 'Change',
                        onAction: () => _addOrChangeHotel(hotels),
                      ),
                      const SizedBox(height: 12),
                      if (hotels.isEmpty)
                        _EmptySlot(
                          message: 'No hotel planned for this trip yet.',
                        )
                      else
                        for (var i = 0; i < hotels.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _RemovableVenueRow(
                            item: hotels[i],
                            onTap: () => _openVenue(hotels[i]),
                            onLongPress: () => _showVenueActions(hotels[i]),
                            onRemove: () => _removeVenue(hotels[i]),
                          ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final String message;
  const _EmptySlot({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      message,
      style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
    ),
  );
}

/// A section label ("RESTAURANTS (2)") plus an explicit "Add"/"Change"
/// action — the incremental-editing entry point this task adds, so
/// building a trip's itinerary after creation is exactly as available as
/// doing it during creation (see Create Trip's own hotel/restaurant
/// pickers, which write to the same planned_venues shape).
class _SectionHeaderRow extends StatelessWidget {
  final String label;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeaderRow({
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      SectionLabel(label),
      TextButton.icon(
        onPressed: onAction,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: Text(actionLabel, style: GoogleFonts.inter(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ],
  );
}

/// [PlannedVenueRow] plus an explicit, always-visible remove action —
/// long-press (see PlannedVenueRow's own "edit/cancel behind onLongPress"
/// design) still opens the fuller action sheet, but "Remove restaurant"/
/// "remove hotel" no longer requires discovering that gesture first.
class _RemovableVenueRow extends StatelessWidget {
  final ResolvedPlannedVenue item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;
  const _RemovableVenueRow({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: PlannedVenueRow(
          item: item,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
      IconButton(
        onPressed: onRemove,
        icon: const Icon(
          Icons.remove_circle_outline_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        tooltip: 'Remove',
      ),
    ],
  );
}
