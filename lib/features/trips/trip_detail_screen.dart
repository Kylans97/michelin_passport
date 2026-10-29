import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/event.dart';
import '../../models/event_trip_match.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/resolved_planned_venue.dart';
import '../../models/trip_destination.dart';
import '../../models/trip_member.dart';
import '../../models/venue_country.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/event_card.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'trip_legs.dart';
import 'trip_schedule.dart';
import 'widgets/create_trip_sheet.dart';
import 'widgets/hotel_picker_sheet.dart';
import 'widgets/planned_venue_actions.dart';
import 'widgets/planned_venue_row.dart';
import 'widgets/restaurant_picker_sheet.dart';
import 'widgets/trip_card.dart' show formatTripDateRange, tripVenueCountsLine;
import 'widgets/trip_chrome.dart';
import 'widgets/trip_eyebrow.dart';
import 'widgets/trip_members_sheet.dart';

/// A single trip: its destinations, dates, notes, who's travelling, and
/// every planned restaurant/hotel on it. A typography-led header on the
/// deep-green canvas, then — for a single-destination trip — STAY, DINING
/// and WHAT'S ON as Explore-style sections over the same ivory
/// [CsPlaceCard]s Passport uses; for a multi-destination trip
/// (20261022120000) one section per leg, each with its own stays and
/// dining. Gold only on stars and Keys.
///
/// Shared trips: every member sees everyone's plans (planned_venues_select)
/// but edits only their own; only the owner edits the trip itself or its
/// destinations; any member invites their own friends; a member can leave.
/// Against a server without that migration the screen is the single-
/// destination, owner-only screen it was before
/// ([PlannedTripsRepository.sharedTripsAvailable]).
///
/// Pickers are scoped to the destinations (codes and ids, never names) —
/// the whole trip's, or one leg's when added from that leg.
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
  late final FriendshipRepository _friendsRepo = FriendshipRepository(
    Supabase.instance.client,
  );

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  late PlannedTrip _trip = widget.trip;
  bool _loading = true;
  List<ResolvedPlannedVenue> _venues = [];
  List<Event> _matchingEvents = [];
  List<TripMember> _members = [];

  // Country code -> country, for display only ("🇫🇷 France"). A missing
  // entry falls back to the bare code rather than failing the screen.
  Map<String, VenueCountry> _countries = {};

  bool get _isOwner => _trip.userId == _userId;
  bool get _sharing => _repo.sharedTripsAvailable;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trip = await _repo.loadTrip(_trip.id) ?? _trip;
      final legs = effectiveLegs(trip);
      final countriesFuture = _loadCountries();
      // Every plan on the trip, other members' included, once the server
      // has shared trips; before that, the caller's own plans only.
      final venuesFuture = _sharing
          ? _repo.loadResolvedPlannedVenuesForTrips([trip.id])
          : _repo
                .loadResolvedPlannedVenues(_userId)
                .then((v) => v.where((p) => p.plan.tripId == trip.id).toList());
      final membersFuture = _sharing
          ? _repo
                .loadTripMembers(trip.id)
                .catchError((Object _) => <TripMember>[])
          : Future.value(const <TripMember>[]);
      // Decision 2: events in every destination country, matched per leg
      // by eventsMatchingTrip — never a second matching definition.
      final eventCountries = {for (final l in legs) l.countryCode};
      final eventsFuture = Future.wait([
        for (final code in eventCountries)
          _eventsRepo.loadEventsForCountry(code),
      ]).then((lists) => [for (final l in lists) ...l]);

      final venues = await venuesFuture;
      final members = await membersFuture;
      final events = await eventsFuture;
      final countries = await countriesFuture;
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _venues = venues;
        _members = members;
        _matchingEvents = eventsMatchingTrip(events, trip);
        _countries = countries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<Map<String, VenueCountry>> _loadCountries() async {
    try {
      final countries = await _repo.loadAllCountries();
      return {for (final c in countries) c.code.toUpperCase(): c};
    } catch (_) {
      return {};
    }
  }

  String _countryLabel(String code) {
    final country = _countries[code.toUpperCase()];
    if (country == null) return code.toUpperCase();
    return country.flag.isEmpty
        ? country.name
        : '${country.flag} ${country.name}';
  }

  String _legName(TripDestination leg) => legLabel(leg, _countryLabel);

  /// The header's destination line: "🇫🇷 France · Paris" for one leg
  /// (keeping a legacy free-text city when there's no catalogue one),
  /// "Paris → 🇮🇹 Italy" across several.
  String get _destinationLine {
    final legs = effectiveLegs(_trip);
    if (legs.length > 1) return legs.map(_legName).join('  →  ');
    final leg = legs.first;
    if (leg.cityName != null) return _legName(leg);
    final city = _trip.city?.trim();
    final country = _countryLabel(leg.countryCode);
    return (city != null && city.isNotEmpty) ? '$country · $city' : country;
  }

  String? _addedBy(ResolvedPlannedVenue item) {
    if (item.plan.userId == _userId) return null;
    for (final m in _members) {
      if (m.userId == item.plan.userId) return m.label;
    }
    return 'a fellow traveller';
  }

  void _showSnack(String message, {bool isError = false}) =>
      showTripSnackBar(context, message, isError: isError);

  Future<void> _showTripActions() async {
    final action = await showTripActionSheet<String>(
      context,
      title: _trip.title,
      actions: [
        if (_isOwner)
          const TripSheetAction(
            value: 'edit',
            label: 'Edit trip',
            icon: Icons.edit_outlined,
          ),
        if (_sharing)
          TripSheetAction(
            value: 'members',
            label: _members.any((m) => m.userId != _userId)
                ? 'Travelling with'
                : 'Invite friends',
            icon: Icons.group_outlined,
          ),
        if (_isOwner)
          const TripSheetAction(
            value: 'delete',
            label: 'Delete trip',
            icon: Icons.delete_outline_rounded,
            destructive: true,
          )
        else
          const TripSheetAction(
            value: 'leave',
            label: 'Leave trip',
            icon: Icons.logout_rounded,
            destructive: true,
          ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _editTrip();
      case 'members':
        await _openMembers();
      case 'delete':
        await _deleteTrip();
      case 'leave':
        await _leaveTrip();
    }
  }

  Future<void> _openMembers() async {
    final changed = await showTripMembersSheet(
      context,
      tripId: _trip.id,
      ownerId: _trip.userId,
      currentUserId: _userId,
      repo: _repo,
      friendsRepo: _friendsRepo,
    );
    if (changed) _load();
  }

  Future<void> _editTrip() async {
    final saved = await showCreateTripSheet(
      context,
      userId: _userId,
      repo: _repo,
      existingTrip: _trip,
    );
    // Destinations/dates may have changed — _load re-reads the trip and
    // re-runs event matching against it, not the stale one.
    if (saved == true) await _load();
  }

  Future<void> _deleteTrip() async {
    final own = _venues.where((v) => v.plan.userId == _userId).length;
    final shared = _members.any((m) => m.status != TripMemberStatus.owner);
    final confirmed = await showTripConfirmDialog(
      context,
      title: 'Delete this trip?',
      message: [
        'This will permanently remove the trip',
        if (shared) ' for everyone on it',
        '.',
        if (own > 0)
          ' Your $own planned ${own == 1 ? 'venue' : 'venues'} will not be '
              'deleted — they\'ll just no longer belong to a trip.',
      ].join(),
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

  Future<void> _leaveTrip() async {
    final confirmed = await showTripConfirmDialog(
      context,
      title: 'Leave this trip?',
      message:
          'You\'ll no longer see it or its plans. Your own plans stay yours, '
          'no longer part of the trip.',
      confirmLabel: 'Leave trip',
    );
    if (!confirmed) return;
    try {
      await _repo.leaveTrip(_trip.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not leave the trip. Please try again.', isError: true);
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

  // [legs] is the picker's scope: one leg when added from that leg's
  // section, else every leg. A new stay/visit starts on its leg's dates.
  Future<void> _addHotel(
    List<TripDestination> legs,
    List<ResolvedPlannedVenue> existing,
  ) async {
    final scope = legScope(legs);
    final picked = await showHotelPickerSheet(
      context,
      repo: _hotelRepo,
      countryCodes: scope.countryCodes,
      cityIds: scope.cityIds,
      destinationLabel: legs.map(_legName).join(' · '),
      excludeIds: {
        for (final h in existing)
          if (h.venue case HotelVenue(:final hotel)) hotel.id,
      },
    );
    if (picked == null) return;
    final leg = legs.length == 1 ? legs.first : null;
    try {
      await _repo.createPlannedVenue(
        userId: _userId,
        entityType: 'hotel',
        entityId: picked.id,
        tripId: _trip.id,
        startDate: leg == null ? _trip.startDate : legStart(_trip, leg),
        endDate: leg == null ? _trip.endDate : legEnd(_trip, leg),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not add that hotel. Please try again.', isError: true);
    }
  }

  Future<void> _addRestaurant(
    List<TripDestination> legs,
    List<ResolvedPlannedVenue> existing,
  ) async {
    final scope = legScope(legs);
    final picked = await showRestaurantPickerSheet(
      context,
      repo: _restaurantRepo,
      countryCodes: scope.countryCodes,
      cityIds: scope.cityIds,
      destinationLabel: legs.map(_legName).join(' · '),
      excludeIds: {
        for (final r in existing)
          if (r.venue case RestaurantVenue(:final restaurant)) restaurant.id,
      },
    );
    if (picked == null) return;
    final leg = legs.length == 1 ? legs.first : null;
    try {
      await _repo.createPlannedVenue(
        userId: _userId,
        entityType: 'restaurant',
        entityId: picked.id,
        tripId: _trip.id,
        startDate: leg == null ? _trip.startDate : legStart(_trip, leg),
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

  // A planned venue card. The user's own plans get an always-visible
  // "remove from trip" glyph plus the long-press edit sheet; other
  // members' plans are read-only and say who added them.
  Widget _venueCard(ResolvedPlannedVenue item) {
    final mine = item.plan.userId == _userId;
    return PlannedVenueRow(
      item: item,
      onTap: () => _openVenue(item),
      onLongPress: mine ? () => _showVenueActions(item) : null,
      trailing: mine ? _RemoveGlyph(onTap: () => _removeVenue(item)) : null,
      addedBy: _addedBy(item),
    );
  }

  List<Widget> _venueList(List<ResolvedPlannedVenue> items, String empty) => [
    if (items.isEmpty)
      TripEmptyLine(empty)
    else
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(height: CsSpacing.md),
        _venueCard(items[i]),
      ],
  ];

  /// STAY and DINING for one leg (or the whole single-destination trip).
  /// [compact] uses small eyebrow headers under a leg's own title.
  List<Widget> _stayAndDining({
    required List<TripDestination> scope,
    required List<ResolvedPlannedVenue> plans,
    required bool compact,
  }) {
    final hotels = plans.where((v) => v.venue is HotelVenue).toList();
    final restaurants = plans.where((v) => v.venue is RestaurantVenue).toList();
    Widget header(String title, String subtitle, Widget action) => compact
        ? Row(
            children: [
              Expanded(child: TripSectionLabel(title)),
              action,
            ],
          )
        : TripSectionHeader(title: title, subtitle: subtitle, trailing: action);

    return [
      header(
        'STAY',
        hotels.isEmpty
            ? 'Where you\'ll rest.'
            : hotels.length == 1
            ? '1 stay'
            : '${hotels.length} stays',
        TripTextAction(
          label: 'Add stay',
          onTap: () => _addHotel(scope, hotels),
        ),
      ),
      SizedBox(height: compact ? CsSpacing.sm : CsSpacing.base),
      ..._venueList(hotels, 'No hotel planned here yet.'),
      SizedBox(height: compact ? CsSpacing.xl : CsSpacing.section),
      header(
        'DINING',
        restaurants.isEmpty
            ? 'Tables worth the journey.'
            : restaurants.length == 1
            ? '1 restaurant'
            : '${restaurants.length} restaurants',
        TripTextAction(
          label: 'Add',
          onTap: () => _addRestaurant(scope, restaurants),
        ),
      ),
      SizedBox(height: compact ? CsSpacing.sm : CsSpacing.base),
      ..._venueList(restaurants, 'No restaurants planned here yet.'),
    ];
  }

  List<Widget> _legSections() {
    final legs = effectiveLegs(_trip);
    if (legs.length == 1) {
      return _stayAndDining(scope: legs, plans: _venues, compact: false);
    }
    final byLeg = <int, List<ResolvedPlannedVenue>>{};
    final elsewhere = <ResolvedPlannedVenue>[];
    for (final v in _venues) {
      final i = legIndexForPlan(_trip, v);
      if (i == null) {
        elsewhere.add(v);
      } else {
        byLeg.putIfAbsent(i, () => []).add(v);
      }
    }
    return [
      for (var i = 0; i < legs.length; i++) ...[
        if (i > 0) const SizedBox(height: CsSpacing.section),
        TripSectionHeader(
          title: _legName(legs[i]),
          subtitle: formatLegDateRange(
            legStart(_trip, legs[i]),
            legEnd(_trip, legs[i]),
          ),
        ),
        const SizedBox(height: CsSpacing.lg),
        ..._stayAndDining(
          scope: [legs[i]],
          plans: byLeg[i] ?? const [],
          compact: true,
        ),
      ],
      if (elsewhere.isNotEmpty) ...[
        const SizedBox(height: CsSpacing.section),
        const TripSectionHeader(
          title: 'ELSEWHERE',
          subtitle: 'Planned outside this trip\'s destinations.',
        ),
        const SizedBox(height: CsSpacing.base),
        ..._venueList(elsewhere, ''),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final restaurantCount = _venues
        .where((v) => v.venue is RestaurantVenue)
        .length;
    final hotelCount = _venues.where((v) => v.venue is HotelVenue).length;
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
                          destination: _destinationLine,
                          dates: formatTripDateRange(_trip),
                          counts: tripVenueCountsLine(
                            restaurantCount: restaurantCount,
                            hotelCount: hotelCount,
                          ),
                        ),
                        if (_sharing) ...[
                          const SizedBox(height: CsSpacing.md),
                          TripCompanionsRow(
                            members: _members,
                            currentUserId: _userId,
                            onTap: _openMembers,
                          ),
                        ],

                        // Omitted outright when absent rather than an
                        // empty-state block — a trip with no notes
                        // shouldn't look "broken".
                        if (hasNotes) ...[
                          const SizedBox(height: CsSpacing.xl),
                          _TripNotes(notes: _trip.notes!.trim()),
                        ],

                        const SizedBox(height: CsSpacing.section),
                        ..._legSections(),

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
