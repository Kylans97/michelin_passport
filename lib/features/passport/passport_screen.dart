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
import 'passport_filter_type.dart';
import 'passport_view_model.dart';
import 'widgets/passport_collection_header.dart';
import 'widgets/passport_empty_state.dart';
import 'widgets/passport_event_card.dart';
import 'widgets/passport_hotel_card.dart';
import 'widgets/passport_restaurant_card.dart';

/// My Passport: the user's personal collection of visited restaurants,
/// stayed-at hotels, and attended Events. VISITS/STAYS are individual
/// historical records (see VisitedRepository / Restaurant/Hotel Detail's
/// own history); PASSPORT shows each unique venue once, however many
/// times it's actually been visited/stayed at. All Restaurant/Hotel
/// aggregation (grouping by venue, year filtering, averages, totals)
/// happens in [PassportFilterResult] — this screen only lays out what
/// that produces.
///
/// Step 2 of the Chasing Stars visual redesign — the first feature screen
/// migrated onto the Cs design-system foundation from Step 1.
///
/// Events V2 Step 8C — Events promoted to a genuine first-class Passport
/// content type: [PassportFilterType] (Restaurants/Hotels/Events) is
/// Passport's own local filter, exactly one selected at a time — never
/// merged, never an Events section appended below Restaurants/Hotels the
/// way Step 4 originally shipped it. Deliberately NOT
/// [ExploreVenueType] (shared with Explore/Wishlist/Rankings/My Map) and
/// Events deliberately does NOT become a third [PassportVenue] variant —
/// see the Step 8C architecture audit's own PassportVenue Boundary /
/// ExploreVenueType Boundary sections for why both would have a much
/// larger blast radius than useful here. Confirmed-attendance Events
/// (`event_confirmed_attendance`, via [EventConfirmedAttendanceRepository
/// .loadPassportEventAttendance]) are the ONLY Event content Passport
/// ever shows — Interested/Going intent never appears here.
///
/// This screen stays mounted for the whole app session — it lives inside
/// the bottom-tab IndexedStack (see `_MainNavigation` in app.dart), which
/// never disposes its children on tab switch. A one-time fetch would go
/// stale the moment a visit/stay/attendance is saved elsewhere, so the
/// source data is reloaded explicitly instead: on first mount, on
/// pull-to-refresh, and via [RouteAware.didPopNext] whenever a pushed
/// screen (Restaurant/Hotel/Event Detail) is popped back to the tab
/// shell. Changing the selected filter type or year never refetches —
/// both just re-run the relevant filter against data already held in
/// memory.
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
  // Events V2 Step 4 §14/§15, promoted to first-class in Step 8C —
  // confirmed Event history, kept structurally separate from
  // PassportVenue's sealed union (see EventAttendanceEntry's own doc
  // comment for why). Loaded alongside _entries but never blocks/fails
  // the rest of Passport — a failure here leaves this filter's own
  // content simply empty, same reasoning as EventsScreen's own
  // prompt-nudge load.
  List<EventAttendanceEntry> _eventEntries = [];
  bool _loading = true; // true only for the very first, blocking load.
  bool _loadError = false; // Restaurant/Hotel load failure only — see
  // _load's own doc comment: a failed Event load never sets this.
  bool _refreshing = false; // guards overlapping refresh calls.

  PassportFilterType _filterType = PassportFilterType.restaurants;
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

  // Fires when a screen pushed on top of the tab shell (Restaurant/Hotel/
  // Event Detail) is popped and this (permanently mounted) tab becomes
  // current again — so a visit/stay/attendance saved there shows up
  // immediately.
  @override
  void didPopNext() => _load();

  // Events V2 Step 8C — the Event load's own failure is already isolated
  // (own try/catch below, never sets _loadError); this only reports
  // whether the Restaurant/Hotel load itself failed, matching _loadError's
  // own unchanged meaning.
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
      final venueYears = availableVisitYears(
        entries.expand((entry) => entry.visits),
      );
      final eventYears = availableEventAttendanceYears(eventEntries);
      setState(() {
        _entries = entries;
        _eventEntries = eventEntries;
        _loading = false;
        _loadError = false;
        // Preserve the selected year only if it's still represented in
        // whichever filter is currently active; otherwise fall back to
        // "All time" — mirrors the pre-Step-8C behavior exactly, just
        // scoped to the active filter's own year list now that
        // Restaurants/Hotels and Events have independent year sets.
        final currentYears = _filterType == PassportFilterType.events
            ? eventYears
            : venueYears;
        if (_selectedYear != null && !currentYears.contains(_selectedYear)) {
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

  // Only ever called for the Restaurants/Hotels branches (never Events —
  // see _eventEmptyMessage for that filter's own copy), so this switches
  // on just the two relevant PassportFilterType values via _isHotel
  // rather than carrying a dead `events` arm.
  bool get _isHotel => _filterType == PassportFilterType.hotels;

  bool _matchesVenueType(PassportVenue venue) =>
      _isHotel ? venue is HotelVenue : venue is RestaurantVenue;

  String _venueEmptyMessage(List<VenueEntry> allEntries) {
    final hasAnyHistoryForType = allEntries.any(
      (e) => _matchesVenueType(e.venue),
    );
    if (!hasAnyHistoryForType) {
      return _isHotel ? 'No hotel stays yet.' : 'No restaurant visits yet.';
    }
    return _isHotel
        ? 'No hotel stays in $_selectedYear.'
        : 'No restaurant visits in $_selectedYear.';
  }

  // Events V2 Step 8C §14 — restrained, type-specific copy; never the old
  // venue-oriented "waiting for its first stamp" message, and never shown
  // merely because Restaurants/Hotels happens to be empty (this is gated
  // on _filterType == events, so it only ever appears when Events is the
  // active selection).
  String _eventEmptyMessage(List<EventAttendanceEntry> allEventEntries) {
    if (allEventEntries.isEmpty) return 'No events in your Passport yet.';
    return 'No events in your Passport in $_selectedYear.';
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = _entries ?? [];
    final isEvents = _filterType == PassportFilterType.events;

    // Events V2 Step 8C — each filter type has its own independent year
    // list: a year with only confirmed Event attendance, and no
    // Restaurant/Hotel visit at all, must still be selectable, and vice
    // versa — never a single merged set.
    final years = isEvents
        ? availableEventAttendanceYears(_eventEntries)
        : availableVisitYears(allEntries.expand((entry) => entry.visits));

    final restaurantOrHotel = _isHotel
        ? ExploreVenueType.hotels
        : ExploreVenueType.restaurants;
    final result = isEvents
        ? null
        : PassportFilterResult.of(
            allEntries,
            venueType: restaurantOrHotel,
            year: _selectedYear,
          );
    final metricLabels = isEvents
        ? null
        : PassportMetricLabels.forVenueType(restaurantOrHotel);
    final filteredEventEntries = isEvents
        ? eventAttendanceInYear(_eventEntries, _selectedYear)
        : const <EventAttendanceEntry>[];

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
                      for (final type in PassportFilterType.values) ...[
                        if (type != PassportFilterType.values.first)
                          const SizedBox(width: CsSpacing.sm),
                        CsFilterChip(
                          label: type.label,
                          selected: _filterType == type,
                          onTap: () => setState(() {
                            _filterType = type;
                            // Re-validate the selected year against the
                            // newly-active filter's own year list — never
                            // leave a year selected that this filter has
                            // no data for.
                            final newYears = type == PassportFilterType.events
                                ? availableEventAttendanceYears(_eventEntries)
                                : availableVisitYears(
                                    allEntries.expand((e) => e.visits),
                                  );
                            if (_selectedYear != null &&
                                !newYears.contains(_selectedYear)) {
                              _selectedYear = null;
                            }
                          }),
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
            // Events V2 Step 8C §28 — the Restaurant/Hotel metric strip
            // (places/countries/awards) has no natural Event equivalent
            // (an Event isn't a "place" the same way a venue is, and has
            // no stars/Keys award to sum) — hidden entirely rather than
            // showing stale/irrelevant Restaurant or Hotel numbers, or
            // inventing an Event vanity metric merely to fill the strip.
            if (!isEvents)
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
                        value: '${result!.summary.placesVisited}',
                        label: metricLabels!.visited,
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
            // Events V2 Step 8C §9/§15 — exactly one selected Passport
            // content type renders at a time now: no Events section is
            // ever appended below Restaurants/Hotels, and Restaurant/
            // Hotel's own loading/error/empty states can never hide
            // Event content (or vice versa) behind a SliverFillRemaining
            // belonging to a different filter — each branch below is
            // scoped entirely to the currently selected _filterType.
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textOnDark,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else if (isEvents)
              if (filteredEventEntries.isEmpty)
                SliverFillRemaining(
                  child: PassportEmptyState(
                    message: _eventEmptyMessage(_eventEntries),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        CsSpacing.pageHorizontal,
                        0,
                        CsSpacing.pageHorizontal,
                        i == filteredEventEntries.length - 1
                            ? 100
                            : CsSpacing.md,
                      ),
                      child: PassportEventCard(entry: filteredEventEntries[i]),
                    ),
                    childCount: filteredEventEntries.length,
                  ),
                )
            else if (_loadError)
              SliverFillRemaining(child: _ErrorState(onRetry: _load))
            else if (result!.entries.isEmpty)
              SliverFillRemaining(
                child: PassportEmptyState(
                  message: _venueEmptyMessage(allEntries),
                ),
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
