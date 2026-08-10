import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/number_format.dart';
import '../../core/widgets/detail_card.dart' show SectionLabel;
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/event.dart';
import '../../models/venue_country.dart';
import '../events/event_date_format.dart';
import '../events/events_screen.dart';
import 'explore_view_model.dart';
import 'models/explore_filters.dart';
import 'models/explore_item.dart';
import 'widgets/explore_filter_bar.dart';
import 'widgets/explore_status_states.dart';
import 'widgets/hotel_tile.dart';
import 'widgets/restaurant_tile.dart';

// Catalogue-read-only Explore: browses public.restaurants_full and
// public.hotels_full. No visited, wishlist or trophy state for either yet —
// hotels in particular have no stays/visits at all yet (later slice).
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

  ExploreVenueType _venueType = ExploreVenueType.all;
  RestaurantAwardFilter _restaurantAward = RestaurantAwardFilter.all;
  HotelKeysFilter _hotelKeys = HotelKeysFilter.all;
  VenueCountry? _country;
  String _query = '';

  late Future<List<ExploreItem>> _resultsFuture;

  // Fetched once: the country picker's list doesn't depend on the current
  // search/filter state, only on which countries exist in each catalogue —
  // same pattern the previous single-catalogue Explore used.
  late final Future<(List<VenueCountry>, List<VenueCountry>)> _countriesFuture =
      _loadCountries();

  // A lightweight, one-time fetch for the "What's on" banner — soonest few
  // upcoming events, independent of every restaurant/hotel filter above.
  // Not re-fetched as search/filters change: this is a discovery nudge, not
  // a filtered result set (see task's explicit "do not overbuild event
  // recommendation logic yet").
  late final Future<List<Event>> _upcomingEventsFuture = _eventsRepo.loadEvents(
    from: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _resultsFuture = _fetchResults();
  }

  Future<(List<VenueCountry>, List<VenueCountry>)> _loadCountries() async {
    final restaurantsFuture = _restaurantRepo.getCountries();
    final hotelsFuture = _hotelRepo.getCountries();
    return (await restaurantsFuture, await hotelsFuture);
  }

  // All mode issues exactly one restaurant query + one hotel query (run
  // concurrently, awaited in turn) and combines them in Dart — never one
  // query per result and never N+1. Search text and country are independent
  // filters on both queries (see RestaurantRepository.search()/
  // HotelRepository.search()) — country is never required for a city/
  // country text query to return matches.
  Future<List<ExploreItem>> _fetchResults() async {
    switch (_venueType) {
      case ExploreVenueType.restaurants:
        final restaurants = await _restaurantRepo.search(
          _query,
          stars: _restaurantAward.starsParam,
          worlds50BestOnly: _restaurantAward.isWorlds50Best,
          hallOfFameOnly: _restaurantAward.isHallOfFame,
          countryCode: _country?.code,
        );
        return [for (final r in restaurants) RestaurantExploreItem(r)];
      case ExploreVenueType.hotels:
        final hotels = await _hotelRepo.search(
          _query,
          keys: _hotelKeys.keysParam,
          worlds50BestOnly: _hotelKeys.isWorlds50Best,
          countryCode: _country?.code,
        );
        return [for (final h in hotels) HotelExploreItem(h)];
      case ExploreVenueType.all:
        final restaurantsFuture = _restaurantRepo.search(
          _query,
          countryCode: _country?.code,
        );
        final hotelsFuture = _hotelRepo.search(
          _query,
          countryCode: _country?.code,
        );
        return combineExploreItems(await restaurantsFuture, await hotelsFuture);
    }
  }

  void _load() {
    setState(() => _resultsFuture = _fetchResults());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openEventsScreen() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EventsScreen()),
  );

  String _resultCountLabel(int count) {
    final formatted = formatThousands(count);
    return switch (_venueType) {
      ExploreVenueType.restaurants =>
        '$formatted restaurant${count == 1 ? '' : 's'}',
      ExploreVenueType.hotels => '$formatted hotel${count == 1 ? '' : 's'}',
      ExploreVenueType.all => '$formatted place${count == 1 ? '' : 's'}',
    };
  }

  String get _emptyMessage => switch (_venueType) {
    ExploreVenueType.restaurants => 'No restaurants found',
    ExploreVenueType.hotels => 'No hotels found',
    ExploreVenueType.all => 'No places found',
  };

  String get _errorMessage => switch (_venueType) {
    ExploreVenueType.restaurants => 'Could not load restaurants',
    ExploreVenueType.hotels => 'Could not load hotels',
    ExploreVenueType.all => 'Could not load places',
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExploreItem>>(
      future: _resultsFuture,
      builder: (context, snap) {
        final results = snap.data ?? [];
        final loading = snap.connectionState == ConnectionState.waiting;
        // Only meaningful while browsing Restaurants mode with the World's
        // 50 Best award filter selected — All mode never applies
        // _restaurantAward at all (see _fetchResults), so this is false
        // there regardless of leftover filter state.
        final highlightWorlds50Best =
            _venueType == ExploreVenueType.restaurants &&
            _restaurantAward.isWorlds50Best;
        final highlightHotelWorlds50Best =
            _venueType == ExploreVenueType.hotels && _hotelKeys.isWorlds50Best;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.brandGreen,
              foregroundColor: AppColors.textOnDark,
              toolbarHeight: 76,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.event_outlined,
                    color: AppColors.textOnDark,
                  ),
                  tooltip: 'Culinary Events',
                  onPressed: _openEventsScreen,
                ),
              ],
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Explore',
                    style: AppTypography.editorialHeading.copyWith(
                      color: AppColors.textOnDark,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "The world's finest tables and stays",
                    style: AppTypography.metadata.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(
                  _venueType == ExploreVenueType.all ? 152 : 188,
                ),
                child: FutureBuilder<(List<VenueCountry>, List<VenueCountry>)>(
                  future: _countriesFuture,
                  builder: (context, countrySnap) {
                    final (restaurantCountries, hotelCountries) =
                        countrySnap.data ??
                        (const <VenueCountry>[], const <VenueCountry>[]);
                    final countries = switch (_venueType) {
                      ExploreVenueType.restaurants => restaurantCountries,
                      ExploreVenueType.hotels => hotelCountries,
                      ExploreVenueType.all => mergeVenueCountries(
                        restaurantCountries,
                        hotelCountries,
                      ),
                    };
                    return ExploreFilterBar(
                      searchCtrl: _searchCtrl,
                      venueType: _venueType,
                      restaurantAward: _restaurantAward,
                      hotelKeys: _hotelKeys,
                      countryFilter: _country,
                      countries: countries,
                      onQueryChanged: (v) {
                        _query = v;
                        _load();
                      },
                      onVenueTypeChanged: (v) {
                        setState(() => _venueType = v);
                        _load();
                      },
                      onRestaurantAwardChanged: (v) {
                        setState(() => _restaurantAward = v);
                        _load();
                      },
                      onHotelKeysChanged: (v) {
                        setState(() => _hotelKeys = v);
                        _load();
                      },
                      onCountryChanged: (v) {
                        setState(() => _country = v);
                        _load();
                      },
                    );
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: FutureBuilder<List<Event>>(
                future: _upcomingEventsFuture,
                builder: (context, eventSnap) {
                  final events = eventSnap.data ?? const <Event>[];
                  if (events.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _WhatsOnBanner(
                      events: events,
                      onTap: _openEventsScreen,
                    ),
                  );
                },
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 1.5,
                        ),
                      )
                    : Text(
                        _resultCountLabel(results.length),
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),

            if (snap.hasError)
              SliverFillRemaining(
                child: ExploreErrorState(
                  message: _errorMessage,
                  onRetry: _load,
                ),
              )
            else if (results.isEmpty && !loading)
              SliverFillRemaining(
                child: ExploreEmptyState(message: _emptyMessage),
              )
            else if (_venueType == ExploreVenueType.all)
              SliverToBoxAdapter(
                child: _AllResultsSections(
                  results: results,
                  highlightWorlds50Best: highlightWorlds50Best,
                  highlightHotelWorlds50Best: highlightHotelWorlds50Best,
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: EdgeInsets.only(
                      bottom: i == results.length - 1 ? 88 : 0,
                    ),
                    child: switch (results[i]) {
                      RestaurantExploreItem(:final restaurant) =>
                        RestaurantTile(
                          restaurant: restaurant,
                          showWorlds50BestRank: highlightWorlds50Best,
                        ),
                      HotelExploreItem(:final hotel) => HotelTile(
                        hotel: hotel,
                        showWorlds50BestRank: highlightHotelWorlds50Best,
                      ),
                    },
                  ),
                  childCount: results.length,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "All" mode's result list, split into a RESTAURANTS section and a HOTELS
/// section rather than one flat alphabetically-interleaved list — a text
/// query like "Maastricht" now shows matching places from both catalogues
/// immediately, grouped so it's obvious what's a restaurant and what's a
/// hotel, per the task's explicit suggested presentation. Built as a plain
/// Column (not a lazy SliverList) — same "grouped section, not virtualised"
/// choice already used for Trip Detail's/Event Detail's restaurant/hotel
/// sections, appropriate here since "All" mode is a combined, already
/// filtered result set, not a raw multi-hundred-row catalogue browse (that
/// case is Restaurants-only/Hotels-only mode, which keeps the true
/// SliverList above).
class _AllResultsSections extends StatelessWidget {
  final List<ExploreItem> results;
  final bool highlightWorlds50Best;
  final bool highlightHotelWorlds50Best;

  const _AllResultsSections({
    required this.results,
    required this.highlightWorlds50Best,
    required this.highlightHotelWorlds50Best,
  });

  @override
  Widget build(BuildContext context) {
    final restaurants = [
      for (final item in results)
        if (item is RestaurantExploreItem) item.restaurant,
    ];
    final hotels = [
      for (final item in results)
        if (item is HotelExploreItem) item.hotel,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (restaurants.isNotEmpty) ...[
            SectionLabel('RESTAURANTS (${restaurants.length})'),
            const SizedBox(height: 12),
            for (var i = 0; i < restaurants.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              RestaurantTile(
                restaurant: restaurants[i],
                showWorlds50BestRank: highlightWorlds50Best,
              ),
            ],
          ],
          if (restaurants.isNotEmpty && hotels.isNotEmpty)
            const SizedBox(height: 28),
          if (hotels.isNotEmpty) ...[
            SectionLabel('HOTELS (${hotels.length})'),
            const SizedBox(height: 12),
            for (var i = 0; i < hotels.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              HotelTile(
                hotel: hotels[i],
                showWorlds50BestRank: highlightHotelWorlds50Best,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Lightweight "contextual discovery" nudge toward Culinary Events — never
/// a sixth tab, never folded into Wishlist (per the task's explicit
/// positioning). Deliberately minimal: soonest event's name/date plus a
/// count, one tap through to the full Events screen. No per-event
/// recommendation logic, no filtering by Explore's own search/country
/// state — see task's "do not overbuild" instruction.
class _WhatsOnBanner extends StatelessWidget {
  final List<Event> events;
  final VoidCallback onTap;

  const _WhatsOnBanner({required this.events, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final next = events.first;
    final subtitle = events.length > 1
        ? '${events.length} upcoming · next: ${next.name}, '
              '${formatEventDateRange(next)}'
        : '${next.name}, ${formatEventDateRange(next)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.brandGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "WHAT'S ON",
                      style: GoogleFonts.inter(
                        color: AppColors.textOnDark.withValues(alpha: 0.65),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textOnDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textOnDark,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
