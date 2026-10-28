import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/event.dart';
import '../../models/event_trip_match.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/resolved_planned_venue.dart';
import '../../models/venue_country.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/event_card.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'trip_schedule.dart';
import 'widgets/create_trip_sheet.dart';
import 'widgets/hotel_picker_sheet.dart';
import 'widgets/planned_venue_actions.dart';
import 'widgets/planned_venue_row.dart';
import 'widgets/restaurant_picker_sheet.dart';
import 'widgets/trip_card.dart' show formatTripDateRange, tripVenueCountsLine;
import 'widgets/trip_chrome.dart';
import 'widgets/trip_eyebrow.dart';

/// A single trip: destination, dates, notes, and every planned restaurant/
/// hotel attached to it. Editing/deleting the trip and each planned venue
/// all live here.
///
/// Trips restyle (2026-10-28): a typography-led header on the deep-green
/// canvas (a start eyebrow, the trip name at display scale, then the
/// destination and dates), then STAY, DINING and WHAT'S ON as Explore-
/// style section headers over the same ivory [CsPlaceCard]s Passport
/// uses. No gold anywhere except stars and Keys on the cards themselves.
///
/// Stays: "Add stay" always adds — it no longer deletes every existing
/// hotel first ("Change"), which silently threw away stays a user had
/// planned through the venue's own Plan sheet. Each stay is removed on its
/// own, and its dates edited through its long-press sheet.
///
/// Pickers are scoped to the trip's own country (`country_code`, never a
/// name); see showHotelPickerSheet/showRestaurantPickerSheet.
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

  // The trip's country, resolved from its code for display ("🇫🇷 France")
  // — null until loaded, or if the lookup fails, in which case the header
  // and pickers fall back to the bare code rather than failing the screen.
  VenueCountry? _country;

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
      final countryFuture = _resolveCountry(_trip.countryCode);
      final venues = await venuesFuture;
      final events = await eventsFuture;
      final country = await countryFuture;
      if (!mounted) return;
      setState(() {
        _venues = venues.where((v) => v.plan.tripId == _trip.id).toList();
        _matchingEvents = eventsMatchingTrip(events, _trip);
        _country = country;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<VenueCountry?> _resolveCountry(String code) async {
    try {
      final countries = await _repo.loadAllCountries();
      for (final c in countries) {
        if (c.code.toUpperCase() == code.toUpperCase()) return c;
      }
    } catch (_) {
      // Display-only — never a reason to fail the trip itself.
    }
    return null;
  }

  String get _destinationLabel {
    final country = _country;
    if (country == null) return _trip.countryCode.toUpperCase();
    return country.flag.isEmpty
        ? country.name
        : '${country.flag} ${country.name}';
  }

  void _showSnack(String message, {bool isError = false}) =>
      showTripSnackBar(context, message, isError: isError);

  Future<void> _showTripActions() async {
    final action = await showTripActionSheet<String>(
      context,
      title: _trip.title,
      actions: const [
        TripSheetAction(
          value: 'edit',
          label: 'Edit trip',
          icon: Icons.edit_outlined,
        ),
        TripSheetAction(
          value: 'delete',
          label: 'Delete trip',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'edit') await _editTrip();
    if (action == 'delete') await _deleteTrip();
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
    final confirmed = await showTripConfirmDialog(
      context,
      title: 'Delete this trip?',
      message: _venues.isEmpty
          ? 'This will permanently remove the trip.'
          : 'This will permanently remove the trip. Your ${_venues.length} '
                'planned ${_venues.length == 1 ? 'venue' : 'venues'} will '
                'not be deleted — they\'ll just no longer belong to a trip.',
      confirmLabel: 'Delete trip',
    );
    if (!confirmed) return;
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
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          sourceSurface: AnalyticsSourceSurface.tripRecommendation,
        ),
      ),
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

  // A stay defaults to the trip's own dates; its own check-in/check-out
  // are edited afterwards through the long-press "Edit plan" sheet.
  Future<void> _addHotel(List<ResolvedPlannedVenue> hotels) async {
    final picked = await showHotelPickerSheet(
      context,
      repo: _hotelRepo,
      countryCode: _trip.countryCode,
      destinationLabel: _destinationLabel,
      excludeIds: {
        for (final h in hotels)
          if (h.venue case HotelVenue(:final hotel)) hotel.id,
      },
    );
    if (picked == null) return;
    try {
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
      _showSnack('Could not add that hotel. Please try again.', isError: true);
    }
  }

  Future<void> _addRestaurant(List<ResolvedPlannedVenue> restaurants) async {
    final picked = await showRestaurantPickerSheet(
      context,
      repo: _restaurantRepo,
      countryCode: _trip.countryCode,
      destinationLabel: _destinationLabel,
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
    final confirmed = await showTripConfirmDialog(
      context,
      title: isHotel ? 'Remove this stay?' : 'Remove this restaurant?',
      message:
          'This only removes it from the trip — nothing is deleted from '
          'the catalogue.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
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
    final city = _trip.city?.trim();
    final hasCity = city != null && city.isNotEmpty;
    final hasNotes = _trip.notes != null && _trip.notes!.trim().isNotEmpty;
    final startLabel = tripStartLabel(_trip.startDate);

    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.base,
                CsSpacing.sm,
                CsSpacing.base,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const EditorialBackButton(),
                  EditorialBackButton(
                    icon: Icons.more_horiz_rounded,
                    semanticLabel: 'Trip actions',
                    onTap: _showTripActions,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.textOnDark,
                      strokeWidth: 1.5,
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.textOnDark,
                    backgroundColor: AppColors.greenSurface,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        CsSpacing.pageHorizontal,
                        CsSpacing.lg,
                        CsSpacing.pageHorizontal,
                        CsSpacing.section,
                      ),
                      children: [
                        _TripHeader(
                          eyebrow: startLabel?.toUpperCase() ?? 'YOUR TRIP',
                          title: _trip.title,
                          destination: hasCity
                              ? '$_destinationLabel · $city'
                              : _destinationLabel,
                          dates: formatTripDateRange(_trip),
                          counts: tripVenueCountsLine(
                            restaurantCount: restaurants.length,
                            hotelCount: hotels.length,
                          ),
                        ),

                        // Omitted outright when absent rather than an
                        // empty-state block — a trip with no notes
                        // shouldn't look "broken".
                        if (hasNotes) ...[
                          const SizedBox(height: CsSpacing.xl),
                          _TripNotes(notes: _trip.notes!.trim()),
                        ],

                        const SizedBox(height: CsSpacing.section),
                        TripSectionHeader(
                          title: 'STAY',
                          subtitle: hotels.isEmpty
                              ? 'Where you\'ll rest.'
                              : hotels.length == 1
                              ? '1 stay'
                              : '${hotels.length} stays',
                          trailing: TripTextAction(
                            label: 'Add stay',
                            onTap: () => _addHotel(hotels),
                          ),
                        ),
                        const SizedBox(height: CsSpacing.base),
                        if (hotels.isEmpty)
                          const TripEmptyLine(
                            'No hotel planned for this trip yet.',
                          )
                        else
                          for (var i = 0; i < hotels.length; i++) ...[
                            if (i > 0) const SizedBox(height: CsSpacing.md),
                            _venueCard(hotels[i]),
                          ],

                        const SizedBox(height: CsSpacing.section),
                        TripSectionHeader(
                          title: 'DINING',
                          subtitle: restaurants.isEmpty
                              ? 'Tables worth the journey.'
                              : restaurants.length == 1
                              ? '1 restaurant'
                              : '${restaurants.length} restaurants',
                          trailing: TripTextAction(
                            label: 'Add',
                            onTap: () => _addRestaurant(restaurants),
                          ),
                        ),
                        const SizedBox(height: CsSpacing.base),
                        if (restaurants.isEmpty)
                          const TripEmptyLine(
                            'No restaurants planned for this trip yet.',
                          )
                        else
                          for (var i = 0; i < restaurants.length; i++) ...[
                            if (i > 0) const SizedBox(height: CsSpacing.md),
                            _venueCard(restaurants[i]),
                          ],

                        // Omitted outright when empty rather than an
                        // empty-state block — a trip with no matching
                        // events shouldn't look "broken".
                        if (_matchingEvents.isNotEmpty) ...[
                          const SizedBox(height: CsSpacing.section),
                          const TripSectionHeader(
                            title: "WHAT'S ON",
                            subtitle: 'Happening while you\'re there.',
                          ),
                          const SizedBox(height: CsSpacing.base),
                          for (var i = 0; i < _matchingEvents.length; i++) ...[
                            if (i > 0) const SizedBox(height: CsSpacing.md),
                            EventCard(
                              event: _matchingEvents[i],
                              onTap: () => _openEvent(_matchingEvents[i]),
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

  // A planned venue card plus an always-visible "remove from trip" glyph
  // in the card's own top-right slot — long-press still opens the fuller
  // edit/cancel/delete sheet, but removing never depends on discovering
  // that gesture first.
  Widget _venueCard(ResolvedPlannedVenue item) => PlannedVenueRow(
    item: item,
    onTap: () => _openVenue(item),
    onLongPress: () => _showVenueActions(item),
    trailing: _RemoveGlyph(onTap: () => _removeVenue(item)),
  );
}

class _TripHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String destination;
  final String dates;
  final String counts;

  const _TripHeader({
    required this.eyebrow,
    required this.title,
    required this.destination,
    required this.dates,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TripSectionLabel(eyebrow),
      const SizedBox(height: CsSpacing.sm),
      Text(
        title,
        style: CsTypography.displayHero.copyWith(color: AppColors.textOnDark),
      ),
      const SizedBox(height: CsSpacing.md),
      Text(
        destination,
        style: CsTypography.bodyMedium.copyWith(color: AppColors.textOnDark),
      ),
      const SizedBox(height: 2),
      Text(
        dates,
        style: CsTypography.metadata.copyWith(color: AppColors.secondaryOnDark),
      ),
      const SizedBox(height: CsSpacing.base),
      const Divider(height: 1, color: AppColors.hairlineOnGreen),
      const SizedBox(height: CsSpacing.md),
      Text(
        counts,
        style: CsTypography.metadata.copyWith(color: AppColors.secondaryOnDark),
      ),
    ],
  );
}

/// The trip's own notes — set off by a thin ivory rule on the left, like a
/// pull quote, rather than boxed in a card.
class _TripNotes extends StatelessWidget {
  final String notes;
  const _TripNotes({required this.notes});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: CsSpacing.base),
    decoration: const BoxDecoration(
      border: Border(
        left: BorderSide(color: AppColors.subtleBorderDark, width: 1),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TripSectionLabel('NOTES'),
        const SizedBox(height: CsSpacing.xs),
        Text(
          notes,
          style: CsTypography.body.copyWith(color: AppColors.textOnDark),
        ),
      ],
    ),
  );
}

class _RemoveGlyph extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveGlyph({required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      tooltip: 'Remove from trip',
      icon: const Icon(Icons.close_rounded, color: AppColors.taupe, size: 18),
    ),
  );
}
