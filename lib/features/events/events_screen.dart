import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../models/event.dart';
import '../../models/event_attendance_eligibility.dart';
import '../../models/event_confirmed_attendance.dart';
import '../../models/event_confirmed_attendance_analytics.dart';
import '../../models/venue_country.dart';
import 'attendance_prompt_dismissal.dart';
import 'event_detail_screen.dart';
import 'models/event_date_filter.dart';
import 'widgets/attendance_details_sheet.dart';
import 'widgets/attendance_prompt_card.dart';
import 'widgets/event_card.dart';
import 'widgets/event_filter_bar.dart';

/// Culinary Events discovery — standalone events, multi-venue events,
/// festivals, tastings. Country + date filtering; city stays in the data
/// model (see Event) without a prominent UI control yet, per the task's
/// explicit "can become visible later" instruction.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

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
  final AnalyticsService _analytics = const NoopAnalyticsService();

  final _searchCtrl = TextEditingController();
  String _query = '';

  EventDateFilter _dateFilter = EventDateFilter(
    mode: EventDateFilterMode.upcoming,
  );
  VenueCountry? _country;

  late Future<List<Event>> _eventsFuture;
  late final Future<List<VenueCountry>> _countriesFuture = _repo.getCountries();

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
    _eventsFuture = _fetchEvents();
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

  Future<List<Event>> _fetchEvents() {
    final (from, to) = _dateFilter.resolve();
    return _repo.loadEvents(
      from: from,
      to: to,
      countryCode: _country?.code,
      query: _query,
    );
  }

  void _reload() => setState(() => _eventsFuture = _fetchEvents());

  void _openEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          sourceSurface: AnalyticsSourceSurface.eventsFeed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Event>>(
      future: _eventsFuture,
      builder: (context, snap) {
        final events = snap.data ?? [];
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
                  bottom: PreferredSize(
                    preferredSize: Size.fromHeight(
                      _dateFilter.mode == EventDateFilterMode.month ? 224 : 170,
                    ),
                    child: Container(
                      color: AppColors.background,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      child: FutureBuilder<List<VenueCountry>>(
                        future: _countriesFuture,
                        builder: (context, countrySnap) {
                          return EventFilterBar(
                            searchCtrl: _searchCtrl,
                            onQueryChanged: (v) {
                              _query = v;
                              _reload();
                            },
                            dateFilter: _dateFilter,
                            onDateFilterChanged: (filter) {
                              setState(() => _dateFilter = filter);
                              _reload();
                            },
                            country: _country,
                            countries: countrySnap.data ?? [],
                            onCountryChanged: (country) {
                              setState(() => _country = country);
                              _reload();
                            },
                          );
                        },
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
                      child: Text(
                        'Could not load events',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                        ),
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
                else if (events.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
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
                      ),
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
                          i == events.length - 1 ? 100 : 12,
                        ),
                        child: EventCard(
                          event: events[i],
                          onTap: () => _openEvent(events[i]),
                        ),
                      ),
                      childCount: events.length,
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
