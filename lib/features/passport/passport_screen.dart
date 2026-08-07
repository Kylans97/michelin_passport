import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/route_observer.dart';
import '../../core/utils/visit_years.dart';
import '../../core/widgets/year_filter_bar.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/passport_venue.dart';
import '../../models/venue_entry.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;
import '../explore/widgets/venue_type_selector.dart';
import '../map/visited_map_screen.dart';
import 'passport_view_model.dart';
import 'widgets/passport_empty_state.dart';
import 'widgets/passport_hotel_card.dart';
import 'widgets/passport_restaurant_card.dart';
import 'widgets/stat_card.dart';

/// My Passport: the user's personal collection of visited restaurants and
/// stayed-at hotels. VISITS/STAYS are individual historical records (see
/// VisitedRepository / Restaurant/Hotel Detail's own history); PASSPORT
/// shows each unique venue once, however many times it's actually been
/// visited/stayed at. All aggregation (grouping by venue, venue-type and
/// year filtering, averages, totals) happens in [PassportFilterResult] —
/// this screen only lays out what that produces.
///
/// This screen stays mounted for the whole app session — it lives inside
/// the bottom-tab IndexedStack (see `_MainNavigation` in app.dart), which
/// never disposes its children on tab switch. A one-time fetch would go
/// stale the moment a visit/stay is saved elsewhere, so the source data is
/// reloaded explicitly instead: on first mount, on pull-to-refresh, and via
/// [RouteAware.didPopNext] whenever a pushed screen (Restaurant/Hotel
/// Detail) is popped back to the tab shell. Changing venue type or year
/// never refetches — both just re-run [PassportFilterResult.of] against the
/// source already held in memory.
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> with RouteAware {
  late final VisitedRepository _repo = VisitedRepository(
    Supabase.instance.client,
  );

  List<VenueEntry>? _entries; // null until the first load completes.
  bool _loading = true; // true only for the very first, blocking load.
  bool _loadError = false;
  bool _refreshing = false; // guards overlapping refresh calls.

  ExploreVenueType _venueType = ExploreVenueType.all;
  int? _selectedYear; // null = "All time", the default.

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  // Fires when a screen pushed on top of the tab shell (Restaurant Detail,
  // Hotel Detail) is popped and this (permanently mounted) tab becomes
  // current again — so a visit/stay saved there shows up immediately.
  @override
  void didPopNext() => _load();

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final entries = await _repo.loadPassportVenues(uid);
      if (!mounted) return;
      final years = availableVisitYears(
        entries.expand((entry) => entry.visits),
      );
      setState(() {
        _entries = entries;
        _loading = false;
        _loadError = false;
        // Preserve the selected year only if it's still represented in the
        // freshly loaded data; otherwise fall back to "All time".
        if (_selectedYear != null && !years.contains(_selectedYear)) {
          _selectedYear = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Only surface an error screen when there's nothing to show yet —
        // a failed background refresh should leave existing content as-is.
        _loadError = _entries == null;
      });
    } finally {
      _refreshing = false;
    }
  }

  bool _matchesVenueType(PassportVenue venue) => switch (_venueType) {
    ExploreVenueType.all => true,
    ExploreVenueType.restaurants => venue is RestaurantVenue,
    ExploreVenueType.hotels => venue is HotelVenue,
  };

  String get _sectionTitle => switch (_venueType) {
    ExploreVenueType.all => 'Places',
    ExploreVenueType.restaurants => 'Restaurants',
    ExploreVenueType.hotels => 'Hotels',
  };

  (String, IconData) get _placesStat => switch (_venueType) {
    ExploreVenueType.all => ('PLACES', Icons.travel_explore_rounded),
    ExploreVenueType.restaurants => ('RESTAURANTS', Icons.restaurant_rounded),
    ExploreVenueType.hotels => ('HOTELS', Icons.hotel_rounded),
  };

  (String, IconData) get _awardsStat => switch (_venueType) {
    ExploreVenueType.all => ('AWARDS', Icons.emoji_events_rounded),
    ExploreVenueType.restaurants => ('STARS', Icons.star_rounded),
    ExploreVenueType.hotels => ('KEYS', Icons.vpn_key_rounded),
  };

  String _emptyMessage(List<VenueEntry> allEntries) {
    final hasAnyHistoryForType = allEntries.any(
      (e) => _matchesVenueType(e.venue),
    );
    if (!hasAnyHistoryForType) {
      return switch (_venueType) {
        ExploreVenueType.all => 'Your passport is waiting for its first stamp.',
        ExploreVenueType.restaurants => 'No restaurant visits yet.',
        ExploreVenueType.hotels => 'No hotel stays yet.',
      };
    }
    return switch (_venueType) {
      ExploreVenueType.all => 'No places visited in $_selectedYear.',
      ExploreVenueType.restaurants => 'No restaurant visits in $_selectedYear.',
      ExploreVenueType.hotels => 'No hotel stays in $_selectedYear.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = _entries ?? [];
    final years = availableVisitYears(
      allEntries.expand((entry) => entry.visits),
    );
    final result = PassportFilterResult.of(
      allEntries,
      venueType: _venueType,
      year: _selectedYear,
    );
    final (placesLabel, placesIcon) = _placesStat;
    final (awardsLabel, awardsIcon) = _awardsStat;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.card,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          _PassportHeader(
            onTapMap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VisitedMapScreen()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: VenueTypeSelector(
                selected: _venueType,
                onSelect: (type) => setState(() => _venueType = type),
              ),
            ),
          ),
          if (years.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: YearFilterBar(
                  years: years,
                  selectedYear: _selectedYear,
                  onSelect: (year) => setState(() => _selectedYear = year),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  StatCard(
                    value: '${result.summary.placesVisited}',
                    label: placesLabel,
                    icon: placesIcon,
                  ),
                  const SizedBox(width: 10),
                  StatCard(
                    value: '${result.summary.awardsExperienced}',
                    label: awardsLabel,
                    icon: awardsIcon,
                  ),
                  const SizedBox(width: 10),
                  StatCard(
                    value: '${result.summary.countriesVisited}',
                    label: 'COUNTRIES',
                    icon: Icons.public_rounded,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
              child: Row(
                children: [
                  Text(
                    _sectionTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(width: 10),
                  if (_loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 1.5,
                      ),
                    )
                  else
                    _CountBadge('${result.entries.length}'),
                ],
              ),
            ),
          ),
          if (_loadError)
            SliverFillRemaining(child: _ErrorState(onRetry: _load))
          else if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 1.5,
                ),
              ),
            )
          else if (result.entries.isEmpty)
            SliverFillRemaining(
              child: PassportEmptyState(message: _emptyMessage(allEntries)),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    i == result.entries.length - 1 ? 100 : 12,
                  ),
                  child: switch (result.entries[i].venue) {
                    RestaurantVenue(:final restaurant) =>
                      PassportRestaurantCard(
                        restaurant: restaurant,
                        stats: result.entries[i],
                      ),
                    HotelVenue(:final hotel) => PassportHotelCard(
                      hotel: hotel,
                      stats: result.entries[i],
                    ),
                  },
                ),
                childCount: result.entries.length,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Collapsible header ────────────────────────────────────────────────────────

class _PassportHeader extends StatelessWidget {
  final VoidCallback onTapMap;
  const _PassportHeader({required this.onTapMap});

  @override
  Widget build(BuildContext context) {
    final name =
        Supabase.instance.client.auth.currentUser?.userMetadata?['display_name']
            as String? ??
        'Passport';

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.background,
      actions: [
        IconButton(
          icon: const Icon(Icons.map_outlined, color: AppColors.gold),
          tooltip: 'My Map',
          onPressed: onTapMap,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1C1400),
                Color(0xFF110E00),
                AppColors.background,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CHASING STARS',
                        style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
        title: Text(
          'My Passport',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final String value;
  const _CountBadge(this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.goldMuted,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.goldBorder40, width: 0.5),
    ),
    child: Text(
      value,
      style: GoogleFonts.inter(
        color: AppColors.gold,
        fontSize: 12,
        fontWeight: FontWeight.w600,
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
          'Could not load data',
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
