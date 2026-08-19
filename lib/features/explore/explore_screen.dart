import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/country_filter_control.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/cs_search_field.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/event.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import '../events/event_detail_screen.dart';
import '../events/events_screen.dart';
import '../guides/guides_screen.dart';
import '../guides/widgets/guide_destination_row.dart';
import '../hotels/hotel_detail_screen.dart';
import '../private_chefs/private_chefs_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'discovery_selectors.dart';
import 'explore_view_model.dart';
import 'models/explore_filters.dart'
    show RestaurantAwardFilter, HotelKeysFilter;
import 'models/explore_search_results.dart';
import 'models/explore_search_type.dart';
import 'widgets/explore_discovery_sections.dart';
import 'widgets/explore_search_results_view.dart';

/// Explore — Chasing Stars' discovery front door. Two mutually exclusive
/// modes, switched purely by whether the search query is empty (see
/// [_isSearching]), never shown at once:
///
/// DISCOVERY MODE (query empty): a permanent "Browse the Guides" entry
/// (Navigation Step 1 — routes to the existing GuidesScreen, never a
/// duplicate landing page rendered inline here), then an editorial browse —
/// What's On (the soonest upcoming event), Worth the Journey (a restaurant
/// selection), Stay a Little Longer (a hotel selection). The three
/// catalogue sections are loaded once per screen lifetime via three
/// independent futures, so one catalogue failing (e.g. Events) never
/// blocks the other two sections from rendering.
///
/// SEARCH MODE (query non-empty): universal search across the restaurant,
/// hotel and event catalogues at once ("All"), or narrowed to one via the
/// [ExploreSearchType] chips. Country is an independent, optional
/// refinement on top of the text query — never a prerequisite for it (see
/// RestaurantRepository.search()/HotelRepository.search()/
/// EventsRepository.loadEvents(), and buildIlikeOrFilter's own note on the
/// untrimmed-query bug this already fixed).
///
/// Catalogue-read-only, same as before this redesign: no visited,
/// wishlist or trophy state surfaces here.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();

  late final _restaurantRepo = RestaurantRepository(Supabase.instance.client);
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  late final _eventsRepo = EventsRepository(Supabase.instance.client);

  String _query = '';
  Timer? _debounce;

  ExploreSearchType _searchType = ExploreSearchType.all;
  RestaurantAwardFilter _restaurantAward = RestaurantAwardFilter.all;
  HotelKeysFilter _hotelKeys = HotelKeysFilter.all;
  VenueCountry? _country;

  // The last successfully loaded search result set, kept on screen (stale)
  // while a new one is in flight — see _runSearch: a keystroke never
  // blanks the list back to nothing, only a small inline indicator appears
  // alongside what's already showing, avoiding the flicker a full
  // spinner-replaces-everything approach would cause on every keystroke.
  ExploreSearchResults? _searchResults;
  bool _searching = false;
  bool _searchError = false;

  // Discovery content — each independent, loaded once at first mount, not
  // re-fetched while typing (Discovery mode has no filters of its own).
  late final Future<List<Event>> _discoveryEventsFuture = _eventsRepo
      .loadEvents(from: DateTime.now());
  late final Future<List<Restaurant>> _discoveryRestaurantsFuture =
      _restaurantRepo.getAll();
  late final Future<List<Hotel>> _discoveryHotelsFuture = _hotelRepo.getAll();

  // Search mode's country picker options — doesn't depend on the query or
  // any other filter, only on which countries exist in each catalogue.
  late final Future<
    (List<VenueCountry>, List<VenueCountry>, List<VenueCountry>)
  >
  _countriesFuture = _loadCountries();

  bool get _isSearching => isExploreSearching(_query);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<(List<VenueCountry>, List<VenueCountry>, List<VenueCountry>)>
  _loadCountries() async {
    final restaurantsFuture = _restaurantRepo.getCountries();
    final hotelsFuture = _hotelRepo.getCountries();
    final eventsFuture = _eventsRepo.getCountries();
    return (await restaurantsFuture, await hotelsFuture, await eventsFuture);
  }

  // The mode switch itself (Discovery ↔ Search) happens synchronously,
  // right here, on every keystroke — no debounce, no network dependency,
  // exactly the "immediate, no submit button" behavior the redesign
  // requires. Only the actual catalogue re-fetch behind Search mode is
  // debounced (see below), so the discovery feed disappearing and a
  // (possibly still-loading) search view appearing is instant either way.
  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    setState(() => _searching = true);
    try {
      final results = await _fetchSearchResults();
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
        _searchError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        // A failed background refresh leaves any existing stale results on
        // screen — only surface the error state when there's nothing at
        // all to show yet, mirroring PassportScreen's own _load().
        _searchError = _searchResults == null;
      });
    }
  }

  // Exactly one restaurant query + one hotel query + one event query for
  // "All" (run concurrently, awaited in turn) — never one query per
  // result, never N+1. Query text and country are independent filters on
  // every one of the three catalogue searches.
  Future<ExploreSearchResults> _fetchSearchResults() async {
    final query = _query;
    switch (_searchType) {
      case ExploreSearchType.restaurants:
        final restaurants = await _restaurantRepo.search(
          query,
          stars: _restaurantAward.starsParam,
          worlds50BestOnly: _restaurantAward.isWorlds50Best,
          hallOfFameOnly: _restaurantAward.isHallOfFame,
          countryCode: _country?.code,
        );
        return ExploreSearchResults(
          restaurants: restaurants,
          hotels: const [],
          events: const [],
        );
      case ExploreSearchType.hotels:
        final hotels = await _hotelRepo.search(
          query,
          keys: _hotelKeys.keysParam,
          worlds50BestOnly: _hotelKeys.isWorlds50Best,
          countryCode: _country?.code,
        );
        return ExploreSearchResults(
          restaurants: const [],
          hotels: hotels,
          events: const [],
        );
      case ExploreSearchType.events:
        final events = await _eventsRepo.loadEvents(
          query: query,
          countryCode: _country?.code,
        );
        return ExploreSearchResults(
          restaurants: const [],
          hotels: const [],
          events: events,
        );
      case ExploreSearchType.all:
        final restaurantsFuture = _restaurantRepo.search(
          query,
          countryCode: _country?.code,
        );
        final hotelsFuture = _hotelRepo.search(
          query,
          countryCode: _country?.code,
        );
        final eventsFuture = _eventsRepo.loadEvents(
          query: query,
          countryCode: _country?.code,
        );
        return ExploreSearchResults(
          restaurants: await restaurantsFuture,
          hotels: await hotelsFuture,
          events: await eventsFuture,
        );
    }
  }

  void _onSearchTypeChanged(ExploreSearchType type) {
    setState(() => _searchType = type);
    if (_isSearching) _runSearch();
  }

  void _onCountryChanged(VenueCountry? country) {
    setState(() => _country = country);
    if (_isSearching) _runSearch();
  }

  void _onRestaurantAwardChanged(RestaurantAwardFilter filter) {
    setState(() => _restaurantAward = filter);
    if (_isSearching) _runSearch();
  }

  void _onHotelKeysChanged(HotelKeysFilter filter) {
    setState(() => _hotelKeys = filter);
    if (_isSearching) _runSearch();
  }

  void _openRestaurant(Restaurant restaurant) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
    ),
  );

  void _openHotel(Hotel hotel) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
  );

  void _openEvent(Event event) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: event.id,
        sourceSurface: AnalyticsSourceSurface.discover,
      ),
    ),
  );

  void _openEventsScreen() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EventsScreen()),
  );

  // Navigation Step 1: a permanent entry point into the already-built
  // GuidesScreen (Michelin/World's 50 Best/Gault&Millau) — previously
  // reachable only via a temporary, uncommitted device-review harness. This
  // is deliberately just a route push to the EXISTING screen, not a second
  // Guides landing page rendered inline here.
  void _openGuides() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const GuidesScreen()),
  );

  // Private Chefs Step 2: a second compact, permanent navigation row,
  // directly mirroring "Browse the Guides" — a distinct destination
  // (PrivateChefsScreen), never a Guide masquerading as one, never chef
  // results folded into the main restaurant/hotel/event search below.
  void _openPrivateChefs() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PrivateChefsScreen()),
  );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.deepGreen,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _ExploreHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ),
              child: CsSearchField(
                controller: _searchCtrl,
                hintText: 'Search places, cities & events',
                onChanged: _onQueryChanged,
              ),
            ),
          ),
          if (_isSearching) ..._searchSlivers() else ..._discoverySlivers(),
        ],
      ),
    );
  }

  List<Widget> _discoverySlivers() => [
    // A compact, permanent navigation row into Guides — sits above the
    // heavier editorial sections (What's On/Worth the Journey/Stay a
    // Little Longer) so it reads as quick access to a reference catalogue,
    // not as another curated content section competing with them.
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.lg,
          CsSpacing.pageHorizontal,
          0,
        ),
        child: Column(
          children: [
            GuideDestinationRow(
              label: 'Browse the Guides',
              descriptor: "Michelin, World's 50 Best & Gault&Millau.",
              onTap: _openGuides,
              surface: CsSurface.dark,
            ),
            GuideDestinationRow(
              label: 'Private Chefs',
              descriptor: 'Exceptional chefs, selected for private dining.',
              onTap: _openPrivateChefs,
              surface: CsSurface.dark,
            ),
          ],
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: FutureBuilder<List<Event>>(
        future: _discoveryEventsFuture,
        builder: (context, snap) => WhatsOnSection(
          featuredEvent: selectFeaturedEvent(snap.data ?? const []),
          onTapEvent: _openEvent,
          onViewAll: _openEventsScreen,
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: FutureBuilder<List<Restaurant>>(
        future: _discoveryRestaurantsFuture,
        builder: (context, snap) => WorthTheJourneySection(
          restaurants: selectDiscoveryRestaurants(snap.data ?? const []),
          onTapRestaurant: _openRestaurant,
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: FutureBuilder<List<Hotel>>(
        future: _discoveryHotelsFuture,
        builder: (context, snap) => StayALittleLongerSection(
          hotels: selectDiscoveryHotels(snap.data ?? const []),
          onTapHotel: _openHotel,
        ),
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 88)),
  ];

  List<Widget> _searchSlivers() {
    final results = _searchResults;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.base,
            CsSpacing.pageHorizontal,
            0,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final type in ExploreSearchType.values) ...[
                  if (type != ExploreSearchType.values.first)
                    const SizedBox(width: CsSpacing.sm),
                  CsFilterChip(
                    label: type.label,
                    selected: _searchType == type,
                    onTap: () => _onSearchTypeChanged(type),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.sm,
            CsSpacing.pageHorizontal,
            0,
          ),
          child:
              FutureBuilder<
                (List<VenueCountry>, List<VenueCountry>, List<VenueCountry>)
              >(
                future: _countriesFuture,
                builder: (context, snap) {
                  final (restaurantCountries, hotelCountries, eventCountries) =
                      snap.data ??
                      (
                        const <VenueCountry>[],
                        const <VenueCountry>[],
                        const <VenueCountry>[],
                      );
                  final countries = switch (_searchType) {
                    ExploreSearchType.restaurants => restaurantCountries,
                    ExploreSearchType.hotels => hotelCountries,
                    ExploreSearchType.events => eventCountries,
                    ExploreSearchType.all => mergeVenueCountries([
                      restaurantCountries,
                      hotelCountries,
                      eventCountries,
                    ]),
                  };
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: CountryFilterControl(
                      selected: _country,
                      countries: countries,
                      onChanged: _onCountryChanged,
                      surface: CsSurface.dark,
                    ),
                  );
                },
              ),
        ),
      ),
      if (_searchType == ExploreSearchType.restaurants)
        SliverToBoxAdapter(child: _awardFilterRow())
      else if (_searchType == ExploreSearchType.hotels)
        SliverToBoxAdapter(child: _keysFilterRow()),
      if (results != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.base,
              CsSpacing.pageHorizontal,
              CsSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  results.totalCount == 1
                      ? '1 result'
                      : '${results.totalCount} results',
                  style: CsTypography.eyebrow.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
                if (_searching) ...[
                  const SizedBox(width: CsSpacing.sm),
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      color: AppColors.secondaryOnDark,
                      strokeWidth: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      if (_searchError && results == null)
        SliverFillRemaining(
          // hasScrollBody: false — these three branches all render a
          // fixed-height, non-scrolling widget (empty state / error state
          // / a small spinner), never a scrollable body. With the default
          // `true`, the sliver forces its child into a *tight* box equal
          // to whatever viewport height remains after the header/search
          // field/filter rows above — and that remaining height shrinks
          // whenever the keyboard is open (the ancestor Scaffold's
          // default resizeToAvoidBottomInset already subtracts the
          // keyboard height from the body). A tight box smaller than the
          // empty/error state's own content threw a RenderFlex bottom
          // overflow. `false` instead fills the remaining space when
          // there's room (identical look to before) and gracefully
          // defers to the child's own larger size when there isn't,
          // which — because this sliver lives inside the screen's own
          // CustomScrollView — simply makes the whole search view
          // scrollable instead of overflowing. Applies identically to
          // every search type (All/Restaurants/Hotels/Events); nothing
          // here is mode-specific.
          hasScrollBody: false,
          child: ExploreSearchErrorState(onRetry: _runSearch),
        )
      else if (results == null)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.textOnDark,
              strokeWidth: 1.5,
            ),
          ),
        )
      else if (results.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: ExploreSearchEmptyState(),
        )
      else
        SliverToBoxAdapter(
          child: ExploreSearchResultsView(
            results: results,
            onTapEvent: _openEvent,
          ),
        ),
    ];
  }

  Widget _awardFilterRow() => Padding(
    padding: const EdgeInsets.fromLTRB(
      CsSpacing.pageHorizontal,
      CsSpacing.sm,
      CsSpacing.pageHorizontal,
      0,
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < RestaurantAwardFilter.values.length; i++) ...[
            if (i > 0) const SizedBox(width: CsSpacing.sm),
            CsFilterChip(
              label: RestaurantAwardFilter.values[i].label,
              selected: _restaurantAward == RestaurantAwardFilter.values[i],
              onTap: () =>
                  _onRestaurantAwardChanged(RestaurantAwardFilter.values[i]),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _keysFilterRow() => Padding(
    padding: const EdgeInsets.fromLTRB(
      CsSpacing.pageHorizontal,
      CsSpacing.sm,
      CsSpacing.pageHorizontal,
      0,
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < HotelKeysFilter.values.length; i++) ...[
            if (i > 0) const SizedBox(width: CsSpacing.sm),
            CsFilterChip(
              label: HotelKeysFilter.values[i].label,
              selected: _hotelKeys == HotelKeysFilter.values[i],
              onTap: () => _onHotelKeysChanged(HotelKeysFilter.values[i]),
            ),
          ],
        ],
      ),
    ),
  );
}

// ── Editorial header ────────────────────────────────────────────────────

// Primary Tab Header Consistency Step 1: top padding is CsSpacing.lg,
// matching Wishlist's reference title position — was CsSpacing.sm, which
// started "EXPLORE" noticeably higher than the other primary tabs.
class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader();

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore',
            style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            'Places worth travelling for.',
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
        ],
      ),
    ),
  );
}
