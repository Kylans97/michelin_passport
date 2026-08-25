import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/cs_primary_button.dart' show CsSecondaryButton;
import '../../core/widgets/cs_section_title.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/event.dart';
import '../../models/passport_venue.dart';
import '../events/events_screen.dart';
import '../passport/widgets/passport_empty_state.dart';
import 'event_wishlist_schedule.dart';
import 'widgets/event_wishlist_card.dart';
import 'widgets/event_wishlist_empty_state.dart';
import 'widgets/wishlist_venue_cards.dart';
import 'wishlist_view_model.dart';

/// My Wishlist: restaurants, hotels and (EVENT WISHLIST V1) events the
/// user wants to go to someday — distinct from Planned Visits/Stays
/// ("I intend to go around this date") and, for Events specifically,
/// distinct from Going/Interested (see event_wishlist_schedule.dart's own
/// header comment — saving to Wishlist is a separate user action from
/// either). No All category (see [defaultWishlistVenueType] for the
/// default-selection rule). Restaurants/Hotels go through the shared
/// [PassportVenue] abstraction Explore/Passport use; Events are a
/// different canonical entity and are held/rendered separately (see
/// [_events] alongside [_venues]).
///
/// Passport Unified Experience V1: re-homed from a pushed, independently
/// scaffolded screen into one of [PassportScreen]'s four local
/// subsections — no back button, no separate title (the shared Passport
/// header above this body covers that), reached via the persistent
/// Passport/Wishlist/Ranking/Trips tab bar rather than
/// `Navigator.push`/pop. The previous "Trips" quick-link at the top of the
/// list was removed then — Trips is a sibling tab one tap away on the
/// shared bar, so the in-body shortcut was redundant; it has not been
/// reintroduced.
///
/// PASSPORT — WISHLIST UI POLISH V1: the content itself now follows the
/// same deep-green-environment/ivory-object grammar Passport's own
/// collection and Ranking's cards were finalized on, replacing the
/// previous large ivory content sheet with compact list rows. Saved
/// venues render as [WishlistRestaurantCard]/[WishlistHotelCard] — ivory
/// cards in the same family as Passport's collection cards — floating
/// individually on the persistent deep-green canvas, with visible
/// breathing room between them rather than one continuous surface.
/// Removing a card updates the in-memory list immediately (no full
/// reload/loading flash) and reverts if the server call fails.
class WishlistBody extends StatefulWidget {
  const WishlistBody({super.key});

  @override
  State<WishlistBody> createState() => _WishlistBodyState();
}

class _WishlistBodyState extends State<WishlistBody> {
  late final WishlistRepository _repo = WishlistRepository(
    Supabase.instance.client,
  );

  // Wishlist has no "All" category (unlike Explore/Passport) — Restaurants/
  // Hotels/Events (EVENT WISHLIST V1 adds the third).
  WishlistVenueType _venueType = WishlistVenueType.restaurants;
  bool _defaultApplied = false;

  List<PassportVenue>? _venues; // null until the first load completes.
  List<Event>? _events; // null until the first load completes.
  bool _loading = true; // true only for the very first, blocking load.
  bool _loadError = false;
  bool _refreshing = false; // guards overlapping refresh calls.

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final venuesFuture = _repo.loadWishlistVenues(_userId);
      final eventsFuture = _repo.getWishlistEvents(_userId);
      final venues = await venuesFuture;
      final events = await eventsFuture;
      if (!mounted) return;
      setState(() {
        _venues = venues;
        _events = events;
        _loading = false;
        _loadError = false;
      });
      _applyDefaultVenueType(venues, events);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _venues == null;
      });
    } finally {
      _refreshing = false;
    }
  }

  void _applyDefaultVenueType(List<PassportVenue> venues, List<Event> events) {
    if (_defaultApplied) return;
    _defaultApplied = true;
    final defaultType = defaultWishlistVenueType(venues, events);
    if (defaultType != _venueType && mounted) {
      setState(() => _venueType = defaultType);
    }
  }

  // Removes [venue] from the visible list immediately — no full reload, no
  // loading flash — and persists via the same WishlistRepository every
  // other wishlist entry point in the app already uses. Reverts (re-inserts
  // at its original position) if the server call fails, mirroring
  // PassportCollectionBody's own optimistic-toggle-then-revert pattern.
  Future<void> _remove(PassportVenue venue) async {
    final venues = _venues;
    if (venues == null) return;
    final index = venues.indexOf(venue);
    if (index == -1) return;
    setState(() => venues.removeAt(index));
    try {
      switch (venue) {
        case RestaurantVenue(:final restaurant):
          await _repo.remove(userId: _userId, restaurantId: restaurant.id);
        case HotelVenue(:final hotel):
          await _repo.removeHotel(userId: _userId, hotelId: hotel.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => venues.insert(index, venue));
    }
  }

  // Mirrors [_remove] exactly — optimistic removal from [_events],
  // reverted if the server call fails. Never deletes the Event itself,
  // never touches Going/Interested/Attendance (Wishlist and event social
  // status are separate concepts — see this feature's own spec).
  Future<void> _removeEvent(Event event) async {
    final events = _events;
    if (events == null) return;
    final index = events.indexOf(event);
    if (index == -1) return;
    setState(() => events.removeAt(index));
    try {
      await _repo.removeEvent(userId: _userId, eventId: event.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => events.insert(index, event));
    }
  }

  void _openExploreEvents() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EventsScreen()),
  );

  bool _matchesFilter(PassportVenue venue) => switch (_venueType) {
    WishlistVenueType.events => false,
    WishlistVenueType.restaurants => venue is RestaurantVenue,
    WishlistVenueType.hotels => venue is HotelVenue,
  };

  @override
  Widget build(BuildContext context) {
    final isEvents = _venueType == WishlistVenueType.events;
    final allVenues = _venues ?? [];
    final items = allVenues.where(_matchesFilter).toList();
    final isHotels = _venueType == WishlistVenueType.hotels;
    final events = _events ?? [];
    final schedule = scheduleEventWishlist(events);

    return ColoredBox(
      color: AppColors.deepGreen,
      child: RefreshIndicator(
        color: AppColors.textOnDark,
        backgroundColor: AppColors.forestGreen,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.md,
                  CsSpacing.pageHorizontal,
                  0,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < WishlistVenueType.values.length; i++) ...[
                      if (i > 0) const SizedBox(width: CsSpacing.sm),
                      CsFilterChip(
                        label: WishlistVenueType.values[i].label,
                        selected: WishlistVenueType.values[i] == _venueType,
                        onTap: () => setState(
                          () => _venueType = WishlistVenueType.values[i],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.xl,
                  CsSpacing.pageHorizontal,
                  CsSpacing.md,
                ),
                child: const CsSectionTitle(
                  'YOUR WISHLIST',
                  color: AppColors.textOnDark,
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textOnDark,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else if (_loadError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(onRetry: _load),
              )
            else if (isEvents)
              ..._eventSlivers(schedule)
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PassportEmptyState(
                  message: isHotels
                      ? 'No hotels saved yet.'
                      : 'No restaurants saved yet.',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  // Per-item padding (not a shared SliverPadding) — the
                  // same pattern PassportCollectionBody's own collection
                  // list uses: visible deep-green breathing room between
                  // each floating ivory card, with the last card getting
                  // extra bottom clearance for the bottom nav bar rather
                  // than sitting flush behind it.
                  (context, i) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      0,
                      CsSpacing.pageHorizontal,
                      i == items.length - 1 ? 100 : CsSpacing.md,
                    ),
                    child: switch (items[i]) {
                      RestaurantVenue(:final restaurant) =>
                        WishlistRestaurantCard(
                          restaurant: restaurant,
                          onRemove: () => _remove(items[i]),
                        ),
                      HotelVenue(:final hotel) => WishlistHotelCard(
                        hotel: hotel,
                        onRemove: () => _remove(items[i]),
                      ),
                    },
                  ),
                  childCount: items.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // EVENT WISHLIST V1 — UPCOMING (nearest first) then, only when non-empty,
  // PAST (most recently ended first, visually secondary). A saved Event is
  // never removed from this list just because it ended — see
  // event_wishlist_schedule.dart's own doc comment.
  List<Widget> _eventSlivers(EventWishlistSchedule schedule) {
    if (schedule.upcoming.isEmpty && schedule.past.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EventWishlistEmptyState(onExplore: _openExploreEvents),
        ),
      ];
    }
    final slivers = <Widget>[];
    if (schedule.upcoming.isNotEmpty) {
      slivers.add(_eventSectionHeader('UPCOMING'));
      slivers.add(_eventCardsList(schedule.upcoming, dimmed: false));
    }
    if (schedule.past.isNotEmpty) {
      slivers.add(_eventSectionHeader('PAST'));
      slivers.add(_eventCardsList(schedule.past, dimmed: true));
    }
    return slivers;
  }

  Widget _eventSectionHeader(String label) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.sm,
      ),
      child: Text(
        label,
        style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
      ),
    ),
  );

  Widget _eventCardsList(List<Event> events, {required bool dimmed}) =>
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final card = Padding(
              padding: EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                0,
                CsSpacing.pageHorizontal,
                i == events.length - 1 ? 100 : CsSpacing.md,
              ),
              child: EventWishlistCard(
                event: events[i],
                onRemove: () => _removeEvent(events[i]),
              ),
            );
            // Past events read as visually secondary to Upcoming — a
            // restrained opacity dip, not a different card treatment.
            return dimmed ? Opacity(opacity: 0.7, child: card) : card;
          },
          childCount: events.length,
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
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
            'Could not load your wishlist',
            textAlign: TextAlign.center,
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.md),
          SizedBox(
            width: 160,
            child: CsSecondaryButton(label: 'Retry', onTap: onRetry, height: 44),
          ),
        ],
      ),
    ),
  );
}
