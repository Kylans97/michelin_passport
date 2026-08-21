import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/route_observer.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/visit_years.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/cs_metric_strip.dart';
import '../../core/widgets/cs_primary_button.dart' show CsSecondaryButton;
import '../../core/widgets/year_filter_control.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/passport_venue.dart';
import '../../models/venue_entry.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;
import '../map/visited_map_screen.dart';
import 'passport_view_model.dart';
import 'widgets/passport_collection_header.dart';
import 'widgets/passport_empty_state.dart';
import 'widgets/passport_event_card.dart';
import 'widgets/passport_hotel_card.dart';
import 'widgets/passport_restaurant_card.dart';

/// My Passport: the user's personal collection of visited restaurants and
/// stayed-at hotels. VISITS/STAYS are individual historical records (see
/// VisitedRepository / Restaurant/Hotel Detail's own history); PASSPORT
/// shows each unique venue once, however many times it's actually been
/// visited/stayed at. All aggregation (grouping by venue, venue-type and
/// year filtering, averages, totals) happens in [PassportFilterResult] —
/// this screen only lays out what that produces.
///
/// Step 2 of the Chasing Stars visual redesign — the first feature screen
/// migrated onto the Cs design-system foundation from Step 1. Every state/
/// data-loading concern below is UNCHANGED from before this pass; only
/// what [build] renders is new.
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
  late final EventConfirmedAttendanceRepository _eventAttendanceRepo =
      EventConfirmedAttendanceRepository(Supabase.instance.client);

  List<VenueEntry>? _entries; // null until the first load completes.
  // Events V2 Step 4 §14/§15 — confirmed Event history, additive to the
  // Restaurant/Hotel list above rather than folded into PassportVenue's
  // sealed union (see PassportEventCard's own doc comment for why). Loaded
  // alongside _entries but never blocks/fails the rest of Passport — a
  // failure here leaves this section simply empty, same reasoning as
  // EventsScreen's own prompt-nudge load.
  List<EventAttendanceEntry> _eventEntries = [];
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
      var eventEntries = <EventAttendanceEntry>[];
      try {
        eventEntries = await _eventAttendanceRepo.loadPassportEventAttendance(
          uid,
        );
      } catch (_) {
        // See _eventEntries' own doc comment — never fails the rest of
        // Passport.
      }
      if (!mounted) return;
      final years = availableVisitYears(
        entries.expand((entry) => entry.visits),
      );
      setState(() {
        _entries = entries;
        _eventEntries = eventEntries;
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
    final metricLabels = PassportMetricLabels.forVenueType(_venueType);

    // Explicit deep-green canvas for this whole tab, independent of the
    // shared tab-shell Scaffold's own (ivory) background — the shell itself
    // isn't touched in this step; this just makes sure nothing ivory shows
    // through Passport's own bounds (overscroll bounce, empty gaps, etc.).
    return ColoredBox(
      color: AppColors.deepGreen,
      child: RefreshIndicator(
        color: AppColors.textOnDark,
        backgroundColor: AppColors.forestGreen,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _PassportHeader(
                onTapMap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VisitedMapScreen()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  0,
                  CsSpacing.pageHorizontal,
                  0,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final type in ExploreVenueType.values) ...[
                        if (type != ExploreVenueType.values.first)
                          const SizedBox(width: CsSpacing.sm),
                        CsFilterChip(
                          label: type.label,
                          selected: _venueType == type,
                          onTap: () => setState(() => _venueType = type),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (years.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.md,
                    CsSpacing.pageHorizontal,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: YearFilterControl(
                      years: years,
                      selectedYear: _selectedYear,
                      onSelect: (year) => setState(() => _selectedYear = year),
                      surface: CsSurface.dark,
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.xl,
                  CsSpacing.pageHorizontal,
                  0,
                ),
                child: CsMetricStrip(
                  metrics: [
                    CsMetric(
                      value: '${result.summary.placesVisited}',
                      label: metricLabels.visited,
                    ),
                    CsMetric(
                      value: '${result.summary.countriesVisited}',
                      label: metricLabels.countries,
                    ),
                    CsMetric(
                      value: '${result.summary.awardsExperienced}',
                      label: metricLabels.awards,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.section,
                  CsSpacing.pageHorizontal,
                  CsSpacing.md,
                ),
                child: const PassportCollectionHeader(),
              ),
            ),
            if (_loadError)
              SliverFillRemaining(child: _ErrorState(onRetry: _load))
            else if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textOnDark,
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
                      CsSpacing.pageHorizontal,
                      0,
                      CsSpacing.pageHorizontal,
                      i == result.entries.length - 1 ? 100 : CsSpacing.md,
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
            if (!_loading && !_loadError && _eventEntries.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.section,
                    CsSpacing.pageHorizontal,
                    CsSpacing.md,
                  ),
                  child: Text(
                    'EVENTS',
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      0,
                      CsSpacing.pageHorizontal,
                      i == _eventEntries.length - 1 ? 100 : CsSpacing.md,
                    ),
                    child: PassportEventCard(entry: _eventEntries[i]),
                  ),
                  childCount: _eventEntries.length,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Editorial header ──────────────────────────────────────────────────────────

// Primary Tab Header Consistency Step 1: title/subtitle sit in a Row
// alongside the map action (matching ProfileScreen's own established
// title+action Row pattern) rather than stacked below a separate icon
// row — that previous stacked layout pushed "PASSPORT" well below where
// the other four tabs' titles start, since the icon row's own height
// added extra vertical offset before the title ever appeared. Wishlist
// is the reference position: SafeArea + CsSpacing.lg before the title,
// pageHorizontal as the only horizontal inset (the previous extra nested
// CsSpacing.sm indent around the title Column is removed so the title's
// left edge lines up with the other four tabs too).
class _PassportHeader extends StatelessWidget {
  final VoidCallback onTapMap;
  const _PassportHeader({required this.onTapMap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.lg,
          CsSpacing.pageHorizontal,
          CsSpacing.section,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Passport',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xs),
                  Text(
                    'Your collection of remarkable places.',
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppColors.textOnDark),
              tooltip: 'My Map',
              onPressed: onTapMap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

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
          'Could not load data',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.md),
        SizedBox(
          width: 160,
          child: CsSecondaryButton(label: 'Retry', onTap: onRetry, height: 44),
        ),
      ],
    ),
  );
}
