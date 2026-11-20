import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/impressions.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart' show CsSecondaryButton;
import '../../core/widgets/floating_nav_bar.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/booking_window.dart';
import '../../models/event.dart';
import '../../models/journey.dart';
import '../../models/passport_venue.dart';
import '../../models/restaurant.dart';
import '../events/events_screen.dart';
import '../passport/widgets/passport_empty_state.dart';
import 'event_wishlist_schedule.dart';
import 'planned_month_flow.dart';
import 'widgets/event_wishlist_card.dart';
import 'widgets/add_to_wishlist_sheet.dart';
import 'widgets/event_wishlist_empty_state.dart';
import 'widgets/wishlist_venue_cards.dart';
import 'wishlist_view_model.dart';
import '../../models/vineyard.dart';
import '../events/event_detail_screen.dart';
import '../hotels/hotel_detail_screen.dart';
import '../journeys/journey_detail_screen.dart';
import '../journeys/widgets/journey_card.dart';
import '../restaurants/restaurant_detail_screen.dart';
import '../vineyards/vineyard_detail_screen.dart';
import '../vineyards/widgets/vineyard_card.dart';
import 'widgets/wishlist_place_card.dart';
import 'widgets/wishlist_view_selector.dart';

/// My Wishlist: everything the member wants to go to someday —
/// restaurants, hotels, events, wine estates, trains and ships — distinct
/// from Planned Visits/Stays ("I intend to go around this date") and, for
/// Events, from Going/Interested (event_wishlist_schedule.dart).
///
/// "Wishlist, calmer" (product owner, 2026-11-20, option A with option B
/// as its first entry): the chip row and the large "YOUR WISHLIST" title
/// are gone — the Wishlist tab above already says where you are. One quiet
/// line ("Restaurants 18 ▾") opens a sheet listing each saved kind with
/// its count; its first entry, "Everything, by place", groups all of it by
/// region, with trains and ships together at the end. The + sits on the
/// same line.
///
/// Lives inside [PassportScreen] as one of its local subsections — no back
/// button, no own title. Saved venues render as [WishlistRestaurantCard]/
/// [WishlistHotelCard]; removing one updates the list at once and reverts
/// if the server call fails.
class WishlistBody extends StatefulWidget {
  const WishlistBody({super.key});

  @override
  State<WishlistBody> createState() => _WishlistBodyState();
}

class _WishlistBodyState extends State<WishlistBody> {
  late final WishlistRepository _repo = WishlistRepository(
    Supabase.instance.client,
  );

  WishlistView _view = WishlistView.everything;

  List<PassportVenue>? _venues; // null until the first load completes.
  // Restaurant id -> the member's month and when it opens.
  Map<String, WishlistPlan> _plans = const {};
  List<Event>? _events; // null until the first load completes.
  List<Journey> _journeys = const []; // trains and ships
  List<Vineyard> _vineyards = const []; // wine estates
  bool _loading = true; // true only for the very first, blocking load.
  bool _loadError = false;
  bool _refreshing = false; // guards overlapping refresh calls.

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  WishlistContents get _contents => WishlistContents(
    venues: _venues ?? const [],
    events: _events ?? const [],
    vineyards: _vineyards,
    journeys: _journeys,
  );

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
      final plansFuture = _repo.loadPlans().catchError(
        (_) => <String, WishlistPlan>{},
      );
      // Journeys and estates are enhancements: a failure (or, for
      // estates, the migration not yet applied) leaves them out rather
      // than putting the whole Wishlist in error.
      final journeysFuture = _repo
          .getWishlistJourneys(_userId)
          .catchError((Object _) => const <Journey>[]);
      final vineyardsFuture = _repo
          .getWishlistVineyards(_userId)
          .catchError((Object _) => const <Vineyard>[]);
      final venues = await venuesFuture;
      final events = await eventsFuture;
      final plans = await plansFuture;
      final journeys = await journeysFuture;
      final vineyards = await vineyardsFuture;
      if (!mounted) return;
      setState(() {
        _venues = venues;
        _plans = plans;
        _events = events;
        _journeys = List.of(journeys);
        _vineyards = List.of(vineyards);
        _loading = false;
        _loadError = false;
      });
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

  Future<void> _editPlan(Restaurant restaurant) async {
    final outcome = await askPlannedMonth(
      context,
      repository: _repo,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      initial: _plans[restaurant.id]?.plannedMonth,
    );
    if (!mounted) return;
    if (outcome.changed) {
      setState(() {
        _plans = {..._plans}..remove(restaurant.id);
        if (outcome.plan != null) _plans[restaurant.id] = outcome.plan!;
      });
    }
    if (outcome.isError && outcome.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(outcome.message!)));
    }
  }

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

  Future<void> _openAdd() async {
    final changed = await showAddToWishlistSheet(
      context,
      userId: _userId,
      savedIds: {
        for (final v in _venues ?? const <PassportVenue>[])
          switch (v) {
            RestaurantVenue(:final restaurant) => restaurant.id,
            HotelVenue(:final hotel) => hotel.id,
          },
        for (final e in _events ?? const <Event>[]) e.id,
        for (final v in _vineyards) v.id,
        for (final j in _journeys) j.id,
      },
      startWith: switch (_view) {
        WishlistView.everything ||
        WishlistView.restaurants => WishlistAddType.restaurant,
        WishlistView.hotels => WishlistAddType.hotel,
        WishlistView.events => WishlistAddType.event,
        WishlistView.estates => WishlistAddType.estate,
        WishlistView.trains => WishlistAddType.train,
        WishlistView.ships => WishlistAddType.ship,
      },
    );
    if (changed && mounted) await _load();
  }

  Future<void> _openSelector() async {
    final picked = await showWishlistViewSheet(
      context,
      contents: _contents,
      current: _view,
    );
    if (picked != null && mounted) setState(() => _view = picked);
  }

  void _openExploreEvents() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EventsScreen()),
  );

  // Opens a saved thing's own page, then reloads: its heart may have
  // taken it off the wishlist.
  Future<void> _openTarget(Object target) async {
    final Widget page = switch (target) {
      RestaurantVenue(:final restaurant) => RestaurantDetailScreen(
        restaurant: restaurant,
      ),
      HotelVenue(:final hotel) => HotelDetailScreen(hotel: hotel),
      Event(:final id) => EventDetailScreen(eventId: id),
      Vineyard(:final id) => VineyardDetailScreen(vineyardId: id),
      Journey(:final id) => JourneyDetailScreen(journeyId: id),
      _ => throw ArgumentError.value(target, 'target'),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final contents = _contents;
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
                  CsSpacing.xs,
                  CsSpacing.pageHorizontal - CsSpacing.sm,
                  CsSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: WishlistViewSelector(
                          view: _view,
                          count: _loading || _loadError
                              ? null
                              : contents.countOf(_view),
                          onTap: _loading || _loadError ? null : _openSelector,
                        ),
                      ),
                    ),
                    if (!_loading && !_loadError)
                      IconButton(
                        onPressed: _openAdd,
                        icon: const Icon(Icons.add_rounded, size: 26),
                        color: AppColors.textOnDark,
                        tooltip: 'Add to wishlist',
                      ),
                  ],
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
            else
              ..._viewSlivers(contents),
          ],
        ),
      ),
    );
  }

  List<Widget> _viewSlivers(WishlistContents contents) => switch (_view) {
    WishlistView.everything => _placeSlivers(contents),
    WishlistView.restaurants => _venueSlivers(
      contents.restaurants,
      empty: 'No restaurants saved yet.',
    ),
    WishlistView.hotels => _venueSlivers(
      contents.hotels,
      empty: 'No hotels saved yet.',
    ),
    WishlistView.events => _eventSlivers(
      scheduleEventWishlist(contents.events),
    ),
    WishlistView.estates => _cardSlivers([
      for (final v in contents.vineyards)
        VineyardCard(vineyard: v, onTap: () => _openTarget(v)),
    ], empty: 'No wine estates saved yet.'),
    WishlistView.trains => _cardSlivers([
      for (final j in contents.trains)
        JourneyCard(journey: j, onTap: () => _openTarget(j)),
    ], empty: 'No trains saved yet.'),
    WishlistView.ships => _cardSlivers([
      for (final j in contents.ships)
        JourneyCard(journey: j, onTap: () => _openTarget(j)),
    ], empty: 'No ships saved yet.'),
  };

  List<Widget> _placeSlivers(WishlistContents contents) {
    final groups = groupWishlistByPlace(contents);
    if (groups.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PassportEmptyState(
            message: 'Nothing saved yet. Tap + to add a place.',
          ),
        ),
      ];
    }
    return _cardSlivers([
      for (final group in groups)
        WishlistPlaceCard(group: group, onTapItem: _openTarget),
    ], empty: '');
  }

  List<Widget> _venueSlivers(
    List<PassportVenue> items, {
    required String empty,
  }) {
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PassportEmptyState(message: empty),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, i) {
          final item = items[i];
          final (type, id) = switch (item) {
            RestaurantVenue(:final restaurant) => (
              AnalyticsEntityType.restaurant,
              restaurant.id,
            ),
            HotelVenue(:final hotel) => (AnalyticsEntityType.hotel, hotel.id),
          };
          trackImpression(type, id, ImpressionSurface.wishlist);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              0,
              CsSpacing.pageHorizontal,
              i == items.length - 1
                  ? floatingNavClearance(context)
                  : CsSpacing.md,
            ),
            child: switch (item) {
              RestaurantVenue(:final restaurant) => WishlistRestaurantCard(
                restaurant: restaurant,
                onRemove: () => _remove(item),
                plan: _plans[restaurant.id],
                onEditPlan: _userId.isEmpty
                    ? null
                    : () => _editPlan(restaurant),
              ),
              HotelVenue(:final hotel) => WishlistHotelCard(
                hotel: hotel,
                onRemove: () => _remove(item),
              ),
            },
          );
        }, childCount: items.length),
      ),
    ];
  }

  /// A plain list of cards with the page gutter and the floating nav's
  /// clearance after the last one.
  List<Widget> _cardSlivers(List<Widget> cards, {required String empty}) {
    if (cards.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PassportEmptyState(message: empty),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              0,
              CsSpacing.pageHorizontal,
              i == cards.length - 1
                  ? floatingNavClearance(context)
                  : CsSpacing.md,
            ),
            child: cards[i],
          ),
          childCount: cards.length,
        ),
      ),
    ];
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
        delegate: SliverChildBuilderDelegate((context, i) {
          trackImpression(
            AnalyticsEntityType.event,
            events[i].id,
            ImpressionSurface.wishlist,
          );
          final card = Padding(
            padding: EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              0,
              CsSpacing.pageHorizontal,
              i == events.length - 1
                  ? floatingNavClearance(context)
                  : CsSpacing.md,
            ),
            child: EventWishlistCard(
              event: events[i],
              onRemove: () => _removeEvent(events[i]),
            ),
          );
          // Past events read as visually secondary to Upcoming — a
          // restrained opacity dip, not a different card treatment.
          return dimmed ? Opacity(opacity: 0.7, child: card) : card;
        }, childCount: events.length),
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
            child: CsSecondaryButton(
              label: 'Retry',
              onTap: onRetry,
              height: 44,
            ),
          ),
        ],
      ),
    ),
  );
}
