import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../data/repositories/event_host_follow_repository.dart';
import '../../data/repositories/event_social_repository.dart';
import '../../data/repositories/event_tag_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../models/event.dart';
import '../../models/event_attendance_eligibility.dart';
import '../../models/event_confirmed_attendance.dart';
import '../../models/event_confirmed_attendance_analytics.dart';
import '../../models/event_discovery_filters.dart';
import '../../models/event_discovery_item.dart';
import '../../models/event_location_context.dart';
import '../../models/event_relevance_reason.dart';
import '../../models/event_tag.dart';
import '../../models/venue_country.dart';
import 'attendance_prompt_dismissal.dart';
import 'current_location_provider.dart';
import 'event_detail_screen.dart';
import 'event_discovery_filter_service.dart';
import 'event_discovery_service.dart';
import 'geolocator_current_location_provider.dart';
import 'location_settings_opener.dart';
import 'models/event_date_filter.dart';
import 'widgets/attendance_details_sheet.dart';
import 'widgets/attendance_prompt_card.dart';
import 'widgets/event_card.dart';
import 'widgets/event_date_control.dart';
import 'widgets/event_filter_sheet.dart';
import 'widgets/event_location_control.dart';

/// Culinary Events discovery — standalone events, multi-venue events,
/// festivals, tastings.
///
/// Events V2 Discovery Taxonomy Phase C Correction Pass: discovery state
/// is composed from FOUR independently-held pieces — [_query] (search),
/// [_location], [_datePreset]/[_dateRange], and [_advancedFilters]
/// (Social/Type/Theme only) — combined into one [EventDiscoveryFilters]
/// fresh on every fetch via [_effectiveFilters], never by mutating a
/// shared object in place. Changing any one of the four never touches
/// the other three; the order a user interacts with them in can never
/// change the resulting query. See this file's own doc comments below
/// and EVENTS_DISCOVERY_TAXONOMY_PHASE_C_PRE_FINAL.md's "Physical Device
/// Correction Pass" section for the full root-cause writeup of the bug
/// this design fixes.
class EventsScreen extends StatefulWidget {
  /// Events V2 Near Me Phase N2.3/N2.4 — exist ONLY so `test/` can
  /// substitute a deterministic fake [CurrentLocationProvider]/
  /// [LocationSettingsOpener] (mirrors
  /// [GeolocatorCurrentLocationProvider]'s own `gateway` parameter, same
  /// reasoning: `geolocator_current_location_provider.dart`'s own doc
  /// comment). No production call site passes either — every real screen
  /// instantiation gets the real, `geolocator`-backed adapter for both via
  /// [_EventsScreenState]'s own defaults.
  const EventsScreen({
    super.key,
    @visibleForTesting this.locationProvider,
    @visibleForTesting this.settingsOpener,
  });

  @visibleForTesting
  final CurrentLocationProvider? locationProvider;

  @visibleForTesting
  final LocationSettingsOpener? settingsOpener;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final EventsRepository _repo = EventsRepository(
    Supabase.instance.client,
  );
  late final EventAttendanceRepository _attendanceRepo =
      EventAttendanceRepository(Supabase.instance.client);
  late final EventConfirmedAttendanceRepository _confirmedRepo =
      EventConfirmedAttendanceRepository(Supabase.instance.client);
  // Events V2 Step 8A — personalized ranking is a layer on top of the same
  // base Events query above, never a replacement query. See
  // EventDiscoveryService's own doc comment for the per-signal failure
  // isolation this composes.
  late final EventDiscoveryService _discoveryService = EventDiscoveryService(
    attendanceRepo: _attendanceRepo,
    friendshipRepo: FriendshipRepository(Supabase.instance.client),
    tripsRepo: PlannedTripsRepository(Supabase.instance.client),
    hostFollowRepo: EventHostFollowRepository(Supabase.instance.client),
    socialRepo: EventSocialRepository(Supabase.instance.client),
  );
  late final EventTagRepository _tagRepo = EventTagRepository(
    Supabase.instance.client,
  );
  // Events V2 Discovery Taxonomy Phase C — the live wiring point for
  // Phase B's plumbing: filter first, then the SAME EventDiscoveryService
  // above ranks the filtered result. See loadFilteredDiscovery's own doc
  // comment for the exact sequencing and failure-isolation contract.
  late final EventDiscoveryFilterService _filterService =
      EventDiscoveryFilterService(
        eventsRepo: _repo,
        tagRepo: _tagRepo,
        attendanceRepo: _attendanceRepo,
        friendshipRepo: FriendshipRepository(Supabase.instance.client),
        hostFollowRepo: EventHostFollowRepository(Supabase.instance.client),
        discoveryService: _discoveryService,
      );
  final AnalyticsService _analytics = const NoopAnalyticsService();
  // Events V2 Near Me Phase N2.3 — the default here (never a parameter
  // passed by production code) is the only concrete CurrentLocationProvider
  // this codebase has: the real, geolocator-backed adapter. See
  // EventsScreen.locationProvider's own doc comment for why the seam
  // exists at all.
  late final CurrentLocationProvider _locationProvider =
      widget.locationProvider ?? const GeolocatorCurrentLocationProvider();
  // Events V2 Near Me Phase N2.4 — same default reasoning as
  // [_locationProvider] immediately above; a distinct field (not the same
  // instance re-typed) because [EventsScreen.settingsOpener] is
  // independently injectable for tests that only care about one
  // capability or the other.
  late final LocationSettingsOpener _settingsOpener =
      widget.settingsOpener ?? const GeolocatorCurrentLocationProvider();

  // ── The four independent discovery-state dimensions ──────────────────
  final _searchCtrl = TextEditingController();
  String _query = '';
  EventLocationContext _location = EventLocationContext.any;
  EventDiscoveryDatePreset _datePreset = EventDiscoveryDatePreset.none;
  EventDiscoveryDateRange _dateRange = EventDiscoveryDateRange.none;
  // Social/Type/Theme ONLY — countryCodes/dateRange on this field are
  // always empty; Location/Date are never read from or written into it.
  // See event_filter_sheet.dart's own doc comment.
  EventDiscoveryFilters _advancedFilters = EventDiscoveryFilters.empty;

  /// The ONE composed query state (Correction Pass §2) —
  /// [_advancedFilters] plus [_location]/[_dateRange] re-attached, built
  /// fresh here rather than stored, so there is never a second object
  /// that could drift out of sync with the four fields above.
  EventDiscoveryFilters get _effectiveFilters => _advancedFilters.copyWith(
    countryCodes: _location.countryCodes,
    dateRange: _dateRange,
  );

  bool get _isDefaultDiscoveryState =>
      _query.isEmpty &&
      _location.isAny &&
      _dateRange.isEmpty &&
      _advancedFilters.isEmpty;

  // Fixed at "upcoming" — the base browse window (Phase B §13's own
  // upcoming-only invariant) is not a user-visible control; the Date
  // control (_datePreset/_dateRange) is the one user-facing date concept,
  // layered on top of this fixed window rather than replacing it.
  late final EventDateFilter _dateFilter = EventDateFilter(
    mode: EventDateFilterMode.upcoming,
  );

  late Future<List<EventDiscoveryItem>> _discoveryFuture;
  late final Future<List<VenueCountry>> _countriesFuture = _repo.getCountries();
  late final Future<List<EventTag>> _tagsFuture = _tagRepo.loadAllTags();

  // Events V2 Step 4 — the "Did you make it?" ambient nudge. A separate
  // future from _eventsFuture: this must never block or delay the main
  // discovery list, and a failure here should never surface as an error
  // state for the whole screen — see _loadPromptEvent's own try/catch.
  Event? _promptEvent;
  bool _promptBusy = false;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _discoveryFuture = _fetchDiscoveryList();
    _loadPromptEvent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPromptEvent() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final pastGoing = await _attendanceRepo.getPastGoingEvents(userId: uid);
      if (pastGoing.isEmpty) return;
      final confirmedIds = await _confirmedRepo.getConfirmedEventIds(
        userId: uid,
        eventIds: [for (final e in pastGoing) e.id],
      );
      final candidate = mostRecentEligibleAttendancePromptEvent(
        pastGoingEvents: pastGoing,
        confirmedEventIds: confirmedIds,
      );
      if (!mounted ||
          candidate == null ||
          AttendancePromptDismissal.isDismissed(candidate.id)) {
        return;
      }
      setState(() => _promptEvent = candidate);
      _analytics.track(
        AnalyticsEvent.eventAttendancePrompted,
        AnalyticsProperties(
          entityType: AnalyticsEntityType.event,
          entityId: candidate.id,
          sourceSurface: AnalyticsSourceSurface.eventsFeed,
        ),
      );
    } catch (_) {
      // Silently omit the nudge on failure — never an error state on top
      // of the primary Events discovery screen for a secondary surface.
    }
  }

  AnalyticsProperties _promptProperties(
    Event event,
    EventAttendanceSource source, {
    bool? wouldRecommend,
  }) => AnalyticsProperties(
    entityType: AnalyticsEntityType.event,
    entityId: event.id,
    sourceSurface: AnalyticsSourceSurface.eventsFeed,
    attendanceSource: attendanceSourceForAnalytics(source),
    wouldRecommend: wouldRecommend,
  );

  Future<void> _confirmPromptAttendance() async {
    final uid = _userId;
    final event = _promptEvent;
    if (uid == null || event == null || _promptBusy) return;
    setState(() => _promptBusy = true);
    try {
      final confirmed = await _confirmedRepo.confirmAttendance(
        userId: uid,
        eventId: event.id,
        source: EventAttendanceSource.postEventPrompt,
      );
      if (!mounted) return;
      setState(() {
        _promptEvent = null;
        _promptBusy = false;
      });
      final properties = _promptProperties(
        event,
        EventAttendanceSource.postEventPrompt,
      );
      _analytics.track(AnalyticsEvent.eventAttendanceConfirmed, properties);
      _analytics.track(AnalyticsEvent.passportItemCreated, properties);
      try {
        await _attendanceRepo.removeEventIntent(userId: uid, eventId: event.id);
      } catch (_) {
        // Attendance remains authoritative regardless (§18/§19).
      }
      if (!mounted) return;
      final details = await showAttendanceDetailsSheet(
        context: context,
        eventName: event.name,
        attendanceId: confirmed.id,
        eventId: event.id,
        onPhotoUploaded: () => _analytics.track(
          AnalyticsEvent.eventPhotoAdded,
          _promptProperties(event, EventAttendanceSource.postEventPrompt),
        ),
      );
      if (details == null) return;
      // A row this method just created via confirmAttendance always starts
      // with would_recommend unset — never a stale prior answer to weigh
      // against.
      const previousRecommendation = null;
      final updated = await _confirmedRepo.updateAttendanceDetails(
        userId: uid,
        attendanceId: confirmed.id,
        rating: details.rating,
        comment: details.comment,
        wouldRecommend: WouldRecommendUpdate(details.wouldRecommend),
      );
      if (details.rating != null) {
        _analytics.track(
          AnalyticsEvent.eventRatingAdded,
          _promptProperties(event, updated.source),
        );
      }
      if (details.comment != null) {
        _analytics.track(
          AnalyticsEvent.eventCommentAdded,
          _promptProperties(event, updated.source),
        );
      }
      final recommendationEvent = recommendationAnalyticsEvent(
        previous: previousRecommendation,
        next: details.wouldRecommend,
      );
      if (recommendationEvent != null) {
        _analytics.track(
          recommendationEvent,
          _promptProperties(
            event,
            updated.source,
            wouldRecommend: details.wouldRecommend,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _promptBusy = false);
    }
  }

  Future<void> _denyPromptAttendance() async {
    final uid = _userId;
    final event = _promptEvent;
    if (uid == null || event == null || _promptBusy) return;
    setState(() => _promptBusy = true);
    try {
      await _attendanceRepo.removeEventIntent(userId: uid, eventId: event.id);
      if (!mounted) return;
      setState(() {
        _promptEvent = null;
        _promptBusy = false;
      });
      _analytics.track(
        AnalyticsEvent.eventAttendanceDenied,
        _promptProperties(event, EventAttendanceSource.postEventPrompt),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _promptBusy = false);
    }
  }

  void _dismissPrompt() {
    final event = _promptEvent;
    if (event == null) return;
    AttendancePromptDismissal.dismiss(event.id);
    setState(() => _promptEvent = null);
  }

  // Events V2 Discovery Taxonomy Phase C Correction Pass — the one live
  // call path: [_effectiveFilters] (freshly composed from all four
  // independent state pieces on every call — never a stored, potentially
  // stale object) plus the fixed "upcoming" base window feed
  // EventDiscoveryFilterService exactly as Phase B/C designed. A base-
  // load failure propagates here unwrapped; an active Theme/Social
  // filter's own resolution failure surfaces as
  // [EventFilterResolutionException] specifically — see that class's own
  // doc comment for why the two must never be conflated.
  Future<List<EventDiscoveryItem>> _fetchDiscoveryList() {
    final (from, to) = _dateFilter.resolve();
    return _filterService.loadFilteredDiscovery(
      filters: _effectiveFilters,
      userId: _userId,
      from: from,
      to: to,
      query: _query,
      nearMeLocation: _location.nearMe,
    );
  }

  // FutureBuilder itself discards a stale future's eventual result once
  // its `future` parameter is reassigned to a new instance (tracked via
  // Flutter's own `_activeCallbackIdentity` mechanism) — so simply
  // replacing _discoveryFuture on every reload is sufficient race
  // protection for a rapid Location -> Date -> Search -> Filters-Apply
  // sequence (Correction Pass §19): only the newest request's result can
  // ever reach setState, regardless of network ordering.
  void _reload() => setState(() => _discoveryFuture = _fetchDiscoveryList());

  // Clears ALL FOUR discovery dimensions at once (Correction Pass §21/
  // §22) — the one unambiguous, always-safe recovery action offered from
  // the zero-result and failure states, where it is often unclear which
  // single dimension a user would need to blame. Each control also has
  // its own independent, narrower clear built directly into itself
  // (Location's "All countries" tile, Date's "Any date" option, the
  // advanced sheet's own "Clear all" for Social/Type/Theme only) — this
  // is deliberately the one broader, unambiguous action layered on top,
  // never the only way to clear a single dimension.
  void _resetDiscovery() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _location = EventLocationContext.any;
      _datePreset = EventDiscoveryDatePreset.none;
      _dateRange = EventDiscoveryDateRange.none;
      _advancedFilters = EventDiscoveryFilters.empty;
    });
    _reload();
  }

  // Events V2 Near Me Phase N2.3 — the single handler for BOTH resolution
  // modes EventLocationControl's own onChanged can now report (previously
  // country-only). Constructing a brand-new EventLocationContext here
  // (never mutating the old one) is what gives Country<->Near-me
  // replacement its guarantee: a fresh `.country` value structurally
  // cannot carry a stale `.nearMe`, and vice versa (see
  // `event_location_context.dart`'s own assert). Analytics preserve their
  // exact pre-N2.3 shape: fired only for an explicit country selection,
  // never for "All locations", and — deliberately, per this phase's own
  // privacy scope — never for Near Me, which carries a coordinate this
  // event's own taxonomy has no safe place for.
  void _onLocationChanged(EventLocationContext location) {
    setState(() => _location = location);
    _reload();
    final country = location.country;
    if (country != null) {
      _analytics.track(
        AnalyticsEvent.eventFilterApplied,
        AnalyticsProperties(
          sourceSurface: AnalyticsSourceSurface.eventsFeed,
          countryCode: country.code,
        ),
      );
    }
  }

  void _onDateChanged(EventDateSelection selection) {
    setState(() {
      _datePreset = selection.preset;
      _dateRange = selection.range;
    });
    _reload();
  }

  Future<void> _openFilterSheet() async {
    final tags = await _tagsFuture;
    if (!mounted) return;
    final result = await showEventFilterSheet(
      context,
      committed: _advancedFilters,
      tags: tags,
      signedIn: _userId != null,
    );
    if (result == null || !mounted) return;
    setState(() => _advancedFilters = result.filters);
    _reload();
    // Minimal V1 filter analytics — reuses the pre-existing
    // AnalyticsEvent.eventFilterApplied taxonomy (declared, unused, since
    // Events V2 Step 2). Only fired when the applied advanced state is
    // genuinely non-empty; eventCategory is only populated when exactly
    // one Type is selected (a single-value typed property — sending one
    // of several selected values would misrepresent a multi-select).
    // Social/Theme selections are not individually reported (no existing
    // property fits them without expanding the analytics contract, which
    // is intentionally deferred, not silently attempted). No friend
    // identities, followed-entity names, or search text are ever
    // included.
    if (!result.filters.isEmpty) {
      _analytics.track(
        AnalyticsEvent.eventFilterApplied,
        AnalyticsProperties(
          sourceSurface: AnalyticsSourceSurface.eventsFeed,
          eventCategory: result.filters.eventTypes.length == 1
              ? result.filters.eventTypes.first.dbValue
              : null,
        ),
      );
    }
  }

  // Attributes the open to the item's PRIMARY visible relevance reason
  // where the existing AnalyticsSourceContext taxonomy has a clean match
  // (Step 8A §19) — a chronological/no-reason item, or a reason with no
  // clean existing match (e.g. Popularity, which isn't "featured" in the
  // editorial sense that value already carries), leaves sourceContext null
  // rather than force a misleading fit. No new taxonomy is introduced.
  void _openEvent(EventDiscoveryItem item) {
    _analytics.track(
      AnalyticsEvent.eventOpened,
      AnalyticsProperties(
        entityType: AnalyticsEntityType.event,
        entityId: item.event.id,
        sourceSurface: AnalyticsSourceSurface.eventsFeed,
        sourceContext: _analyticsContextFor(item.primaryReason),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: item.event.id,
          sourceSurface: AnalyticsSourceSurface.eventsFeed,
          sourceContext: _analyticsContextFor(item.primaryReason),
        ),
      ),
    );
  }

  AnalyticsSourceContext? _analyticsContextFor(EventRelevanceReason? reason) {
    if (reason == null) return null;
    return switch (reason.type) {
      EventRelevanceReasonType.trip => AnalyticsSourceContext.tripDestination,
      EventRelevanceReasonType.friendGoing =>
        AnalyticsSourceContext.friendSignal,
      EventRelevanceReasonType.followedHost =>
        AnalyticsSourceContext.followedHost,
      EventRelevanceReasonType.friendInterested =>
        AnalyticsSourceContext.friendSignal,
      EventRelevanceReasonType.popular => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventDiscoveryItem>>(
      future: _discoveryFuture,
      builder: (context, snap) {
        final items = snap.data ?? [];
        final loading = snap.connectionState == ConnectionState.waiting;

        return Scaffold(
          // The root cause of the reported "black background": this screen
          // used to return its CustomScrollView with no enclosing Scaffold
          // at all, so there was no opaque backdrop and the route rendered
          // whatever the default canvas is behind bare slivers — Material's
          // black default. Deep green (matching the hero above) instead of
          // AppColors.background's ivory is a deliberate choice for this
          // screen specifically, not a bug — Events reads as a chrome-first
          // discovery surface (event cards already carry their own
          // off-white AppColors.card background), same relationship
          // DetailHero screens have to their content below.
          backgroundColor: AppColors.brandGreen,
          body: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.card,
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.textOnDark,
                  toolbarHeight: 76,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Events',
                        style: AppTypography.editorialHeading.copyWith(
                          color: AppColors.textOnDark,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Culinary happenings worth planning a trip around',
                        style: AppTypography.metadata.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  // Correction Pass §2/§26 — Search, then Location / Date /
                  // Filters as one calm row. No separate active-filter
                  // summary line beneath it: Location and Date already
                  // communicate their own state directly in their own
                  // labels, and repeating that underneath would be
                  // redundant (§12) — Filters · N is sufficient for the
                  // advanced dimensions, which stay invisible until opened.
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(138),
                    child: Container(
                      color: AppColors.background,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (v) {
                              _query = v;
                              _reload();
                            },
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search events, cities…',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FutureBuilder<List<VenueCountry>>(
                                  future: _countriesFuture,
                                  builder: (context, countrySnap) =>
                                      EventLocationControl(
                                        location: _location,
                                        countries: countrySnap.data ?? [],
                                        locationProvider: _locationProvider,
                                        settingsOpener: _settingsOpener,
                                        onChanged: _onLocationChanged,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              EventDateControl(
                                preset: _datePreset,
                                range: _dateRange,
                                onChanged: _onDateChanged,
                              ),
                              const SizedBox(width: 8),
                              _EventsFiltersButton(
                                activeCount: _advancedFilters
                                    .advancedFilterDimensionCount,
                                onTap: _openFilterSheet,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_promptEvent != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: AttendancePromptCard(
                        eventName: _promptEvent!.name,
                        busy: _promptBusy,
                        onYes: _confirmPromptAttendance,
                        onNo: _denyPromptAttendance,
                        onNotNow: _dismissPrompt,
                        surface: CsSurface.dark,
                      ),
                    ),
                  ),
                if (snap.hasError)
                  SliverFillRemaining(
                    child: Center(
                      // Correction Pass §18 — a Theme/Social filter's own
                      // resolution failure keeps its distinct, honest
                      // message; every other failure (including a base
                      // query that now embeds Location/Date/Type/Country
                      // as server-side predicates) gets the same
                      // recoverable treatment — Retry always, plus Reset
                      // discovery whenever some non-default state might be
                      // the cause. Never silently shown as if the request
                      // had simply returned zero results.
                      child: snap.error is EventFilterResolutionException
                          ? _DiscoveryFailureState(
                              message:
                                  (snap.error as EventFilterResolutionException)
                                      .message,
                              onRetry: _reload,
                              onReset: _resetDiscovery,
                            )
                          : _DiscoveryFailureState(
                              message: 'Could not load events',
                              onRetry: _reload,
                              onReset: _isDefaultDiscoveryState
                                  ? null
                                  : _resetDiscovery,
                            ),
                    ),
                  )
                else if (loading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 1.5,
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      // Correction Pass §22 — differentiate "the catalogue
                      // itself is empty" (cold start, every dimension at
                      // its default — the exact, unchanged pre-Phase-C
                      // copy) from "this combination of search/location/
                      // date/filters matched nothing" (restrained copy +
                      // one unambiguous Reset discovery action, never the
                      // generic "no events exist" message for what is
                      // actually a narrowed result).
                      child: _isDefaultDiscoveryState
                          ? const _NoEventsState()
                          : _NoFilterResultsState(onReset: _resetDiscovery),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          i == 0 ? 20 : 0,
                          20,
                          i == items.length - 1 ? 100 : 12,
                        ),
                        child: EventCard(
                          event: items[i].event,
                          reason: items[i].primaryReason,
                          onTap: () => _openEvent(items[i]),
                        ),
                      ),
                      childCount: items.length,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The advanced-refinement entry point (Correction Pass §5/§10/§11) —
/// "Filters" when no Social/Type/Theme dimension is active, "Filters · N"
/// (N = [EventDiscoveryFilters.advancedFilterDimensionCount] — Social,
/// Type, Theme only; Location and Date have their own visible controls
/// and never contribute here) otherwise.
class _EventsFiltersButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const _EventsFiltersButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;
    return Semantics(
      button: true,
      label: active ? 'Filters, $activeCount active' : 'Filters',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.brandGreen.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? AppColors.brandGreen.withValues(alpha: 0.4)
                    : AppColors.cardBorder,
                width: active ? 1.0 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: active
                      ? AppColors.brandGreen
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  active ? 'Filters · $activeCount' : 'Filters',
                  style: GoogleFonts.inter(
                    color: active
                        ? AppColors.brandGreen
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The unchanged, pre-Phase-C cold-start empty state — extracted verbatim
/// (not reworded) so the every-dimension-default case stays byte-
/// identical, per §18's "no visible regression" requirement.
class _NoEventsState extends StatelessWidget {
  const _NoEventsState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.event_outlined,
          color: AppColors.textSecondary,
          size: 44,
        ),
        const SizedBox(height: 16),
        Text(
          'No events found',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textSecondary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Try a different date range or country.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

/// Correction Pass §22 — a narrowed-to-empty result (any of search/
/// location/date/advanced filters active) gets its own restrained copy
/// and ONE unambiguous recovery action that clears all four dimensions
/// at once — distinct from [_NoEventsState]'s "nothing in the catalogue
/// at all" message, and deliberately not a dimension-scoped "Clear
/// filters" (Correction Pass §22 explicitly flags that wording as
/// insufficient/ambiguous once Location/Date/Search can also be active).
class _NoFilterResultsState extends StatelessWidget {
  final VoidCallback onReset;
  const _NoFilterResultsState({required this.onReset});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.filter_alt_off_outlined,
          color: AppColors.textSecondary,
          size: 40,
        ),
        const SizedBox(height: 16),
        Text(
          'Nothing matches right now',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textSecondary,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Try adjusting your search, location, date or filters.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        CsSecondaryButton(
          label: 'Reset discovery',
          onTap: onReset,
          surface: CsSurface.light,
          height: 44,
        ),
      ],
    ),
  );
}

/// A recoverable discovery failure (Correction Pass §18) — friendly,
/// fixed copy (for an [EventFilterResolutionException], its own already-
/// safe [message]; otherwise the same unchanged generic text this app has
/// always shown for a base load failure — never a raw backend error
/// either way), with a Retry (the exact same query, unchanged) and,
/// whenever some non-default discovery state might plausibly be involved,
/// a Reset discovery action.
class _DiscoveryFailureState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onReset;
  const _DiscoveryFailureState({
    required this.message,
    required this.onRetry,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.textSecondary,
          size: 40,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onReset != null) ...[
              CsSecondaryButton(
                label: 'Reset discovery',
                onTap: onReset,
                surface: CsSurface.light,
                height: 44,
              ),
              const SizedBox(width: 12),
            ],
            CsPrimaryButton(
              label: 'Retry',
              onTap: onRetry,
              surface: CsSurface.light,
              height: 44,
            ),
          ],
        ),
      ],
    ),
  );
}
