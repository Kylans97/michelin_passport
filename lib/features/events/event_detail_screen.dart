import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/event_time.dart';
import '../../core/widgets/cs_image_placeholder.dart';
import '../../core/widgets/linked_venue_row.dart';
import '../../core/widgets/section_divider.dart';
import '../../core/widgets/venue_about_section.dart';
import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../data/repositories/event_social_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/event.dart';
import '../../models/event_attendance.dart';
import '../../models/event_attendance_eligibility.dart';
import '../../models/event_confirmed_attendance.dart';
import '../../models/event_confirmed_attendance_analytics.dart';
import '../../models/event_intent.dart';
import '../../models/friendship.dart';
import '../../models/going_member_count.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'friends_going_view_model.dart';
import 'going_member_count_format.dart';
import 'widgets/at_this_event_section.dart';
import 'widgets/attendance_details_sheet.dart';
import 'widgets/event_actions_row.dart';
import 'widgets/event_attendance_section.dart';
import 'widgets/event_detail_hero.dart';
import 'widgets/event_friends_going_section.dart';
import 'widgets/event_friends_interested_section.dart';
import 'widgets/event_intent_controls.dart';
import 'widgets/event_meta_section.dart';

// Smaller than CsImagePlaceholder's own 0.4 default: a hero is a much
// larger, wider area than a card thumbnail, so the same relative scale
// would make the monogram feel oversized.
const double _heroLogoScale = 0.22;

// EVENT WISHLIST V1 — matches RestaurantDetailScreen's/HotelDetailScreen's
// own sign-in-required copy convention exactly, worded for the Event
// entity rather than "visits and wishlist restaurants".
const _signInMessage = 'Sign in to save events to your wishlist.';

/// Whether "I'm going" should be offered at all — no new event-status
/// system (Step 2B §21's explicit instruction, unchanged by the Events UI
/// Consistency Step 1 redesign): reuses [Event.isCancelled] and
/// [eventHasEnded]. A top-level pure function, not inlined in build(), so
/// it's directly unit-testable without a live Supabase session.
///
/// Events V2 Time Precision Phase B: delegates to the same centralized
/// [eventHasEnded] the Attendance-eligibility subsystem uses — exact
/// [Event.endAt] instant when known (unaffected by Events V2 Timezone
/// Hardening; `.isAfter` compares the underlying absolute instant
/// regardless of zone tag, unchanged since before Phase B), else the
/// local-day-end of [Event.endDate] in [Event.timezone] when [Event.endAt]
/// is unknown — so Interested/Going stay offered through an unknown-end
/// Event's final local day, never cut off by a fabricated end time.
bool canAttendEvent(Event event, {DateTime? now}) =>
    !event.isCancelled &&
    !eventHasEnded(
      endAt: event.endAt,
      endDate: event.endDate,
      timezone: event.timezone,
      now: now ?? DateTime.now(),
    );

/// Full event details — Events UI Consistency Step 1: rebuilt onto the
/// same editorial design language Restaurant/Hotel Detail established
/// (ivory canvas, forest-green content, taupe secondary text, gold
/// reserved for Michelin stars only, [SectionDivider] hairlines), while
/// preserving every existing behavior: attendance, admission, linked
/// venues, and navigation are all unchanged in substance, only in
/// presentation. See docs/Architecture/EVENTS_UI_MICHELIN_PARTICIPATION.md
/// for the full before/after and the Michelin-participation architecture.
///
/// Events V2 Time Precision Phase B — Event Detail Hierarchy UX
/// correction, its hero/Essentials title follow-up, and the Editorial
/// Hero + Essentials/Actions polish pass (all three physical-device
/// findings on the real date-only pilot): HERO (image or branded
/// monogram fallback, a back action, and a subtle event-type editorial
/// eyebrow — no other text identity, still genuinely photography-ready)
/// → EVENT TITLE + ESSENTIALS ([EventMetaSection]: event title,
/// precision-aware date/time, venue + city, admission — event type moved
/// back into the hero, so it no longer appears here) → ACTIONS
/// ([EventActionsRow]: full-width Tickets/Official website rows,
/// conditional, moved up from the former LOCATION section) →
/// ATTENDANCE (if [canAttendEvent]) → ABOUT (conditional, reusing
/// [VenueAboutSection] outright) → AT THIS EVENT (conditional,
/// Michelin-starred linked restaurants only — Events V2 Step 3 renamed
/// this section's heading from "MICHELIN AT THIS EVENT"; see
/// [AtThisEventSection]'s own doc comment for why the section name is
/// entity-neutral even though its current content is unchanged) → HOTELS
/// (conditional, preserved existing functionality, reskinned) → LOCATION
/// (conditional; address only now — Tickets/Official website live in
/// ACTIONS instead, so this section is genuinely location-only).
class EventDetailScreen extends StatefulWidget {
  final String eventId;

  /// Where the viewer was immediately before opening this screen — see
  /// `EVENTS_V2_ANALYTICS_CONTRACT.md` §9. Both null at every call site
  /// this screen doesn't yet attribute (documented per call site in Events
  /// V2 Step 3's own implementation report) rather than a fake/guessed
  /// value — analytics omits both fields entirely when null
  /// (AnalyticsProperties.toMap already drops null fields).
  final AnalyticsSourceSurface? sourceSurface;
  final AnalyticsSourceContext? sourceContext;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.sourceSurface,
    this.sourceContext,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventsRepository _repo = EventsRepository(
    Supabase.instance.client,
  );
  late final EventAttendanceRepository _attendanceRepo =
      EventAttendanceRepository(Supabase.instance.client);
  late final EventConfirmedAttendanceRepository _confirmedRepo =
      EventConfirmedAttendanceRepository(Supabase.instance.client);
  late final FriendshipRepository _friendshipRepo = FriendshipRepository(
    Supabase.instance.client,
  );
  late final EventSocialRepository _socialRepo = EventSocialRepository(
    Supabase.instance.client,
  );
  late final WishlistRepository _wishlistRepo = WishlistRepository(
    Supabase.instance.client,
  );

  // No vendor selected yet (Events V2 Step 2) — NoopAnalyticsService is
  // the production-safe default. Swapping the implementation here is the
  // one place a future provider gets wired in; no other line in this
  // screen would need to change.
  final AnalyticsService _analytics = const NoopAnalyticsService();

  bool _loading = true;
  bool _loadError = false;
  Event? _event;
  EventVenues _venues = const EventVenues(restaurants: [], hotels: []);

  // null = NONE (no intent recorded) — see event_intent.dart's own header
  // comment for why NONE is represented as a null status rather than a
  // third enum member.
  EventIntentStatus? _status;
  bool _intentBusy = false;

  // EVENT WISHLIST V1 — entirely independent of [_status]/Going/
  // Interested (see event_wishlist_schedule.dart's own header comment):
  // this screen never reads or writes [_status] when saving/removing a
  // Wishlist entry, and never reads or writes this state when handling
  // an intent tap.
  bool _isWishlisted = false;
  bool _wishlistSaving = false;
  // The status a mutation-in-flight is moving toward; null while a
  // removal is in flight (see EventIntentControls' own doc comment).
  EventIntentStatus? _pendingTarget;

  // Populated only for an upcoming/current, non-cancelled event with a
  // signed-in viewer (see canAttendEvent) — never awaited by _load itself,
  // so a slow or failed friends-going lookup can never block or break the
  // rest of Event Detail; EventFriendsGoingSection's own FutureBuilder
  // handles loading/error/empty by simply not rendering the section.
  Future<List<Friendship>>? _friendsGoingFuture;
  // Events V2 Step 7 — same gating/failure-isolation shape as
  // _friendsGoingFuture, one status over.
  Future<List<Friendship>>? _friendsInterestedFuture;
  // Events V2 Step 7 — the anonymous, capped platform-wide Going count.
  // Same failure-isolation shape: a failed/slow count must never block or
  // break the rest of Event Detail, or the Friends sections above it.
  Future<GoingMemberCount>? _goingMemberCountFuture;

  // Events V2 Step 4 — Confirmed Attendance / "Did you make it?" state.
  EventConfirmedAttendance? _confirmedAttendance;
  bool _attendanceBusy = false;
  // "Not now" hides the prompt for the rest of this screen visit only —
  // never persisted, never applied to the Events-screen ambient surface
  // (see AttendancePromptDismissal's own doc comment for why that's a
  // deliberately separate, session-scoped mechanism).
  bool _promptDismissedLocally = false;
  // Guards event_attendance_prompted from firing more than once per screen
  // visit — build() re-runs on every setState, but the prompt's own
  // *impression* only happens once (EVENTS_V2_ANALYTICS_CONTRACT.md's
  // event_opened uses the identical "once per landing, not per render"
  // rule this mirrors).
  bool _promptedAnalyticsFired = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final eventFuture = _repo.loadEventById(widget.eventId);
      final venuesFuture = _repo.loadLinkedVenues(widget.eventId);
      final uid = _userId;
      final intentFuture = uid == null
          ? Future.value(null)
          : _attendanceRepo.getMyEventIntent(
              userId: uid,
              eventId: widget.eventId,
            );
      final confirmedFuture = uid == null
          ? Future.value(null)
          : _confirmedRepo.getConfirmedAttendance(
              userId: uid,
              eventId: widget.eventId,
            );
      // EVENT WISHLIST V1 — loaded regardless of [canAttendEvent]: unlike
      // Going/Interested (only offered while an event can still be
      // attended), Wishlist state must remain visible/toggleable for a
      // past event too — Wishlist is user intent/history, not gated by
      // the calendar (see event_wishlist_schedule.dart's own header
      // comment).
      final wishlistedFuture = uid == null
          ? Future.value(false)
          : _wishlistRepo.isEventWishlisted(userId: uid, eventId: widget.eventId);
      final event = await eventFuture;
      final venues = await venuesFuture;
      final intent = await intentFuture;
      final confirmed = await confirmedFuture;
      final wishlisted = await wishlistedFuture;
      if (!mounted) return;
      if (event == null) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
        return;
      }
      setState(() {
        _event = event;
        _venues = venues;
        _status = intent?.status;
        _confirmedAttendance = confirmed;
        _isWishlisted = wishlisted;
        _loading = false;
        if (uid != null && canAttendEvent(event)) {
          // getFriends() is started once and shared between the Going and
          // Interested resolutions below — Dart Futures cache their
          // result, so awaiting the same Future instance from two call
          // sites costs one RPC call total, not two (Events V2 Step 7
          // performance requirement: no duplicate friend-list fetch).
          final friendsFuture = _friendshipRepo.getFriends();
          _friendsGoingFuture = _loadFriendsForStatus(
            uid,
            event.id,
            EventIntentStatus.going,
            friendsFuture,
          );
          _friendsInterestedFuture = _loadFriendsForStatus(
            uid,
            event.id,
            EventIntentStatus.interested,
            friendsFuture,
          );
          _goingMemberCountFuture = _socialRepo.getGoingMemberCount(event.id);
        } else {
          _friendsGoingFuture = null;
          _friendsInterestedFuture = null;
          _goingMemberCountFuture = null;
        }
      });
      _maybeFirePromptedAnalytics(event, intent?.status, confirmed);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  // Events V2 Step 7 — status-parameterized (reused for both Friends
  // Going and Friends Interested; see getVisibleUserIds' own doc comment
  // for why the status filter is mandatory, not cosmetic). [friendsFuture]
  // is the caller's own shared getFriends() call — never fetched again
  // here, so calling this twice (once per status) never doubles the
  // friend-list RPC cost.
  Future<List<Friendship>> _loadFriendsForStatus(
    String uid,
    String eventId,
    EventIntentStatus status,
    Future<List<Friendship>> friendsFuture,
  ) async {
    final attendeeIds = await _attendanceRepo.getVisibleUserIds(
      eventId: eventId,
      status: status,
    );
    final friends = await friendsFuture;
    return friendsGoingToEvent(
      attendeeUserIds: attendeeIds,
      friends: friends,
      selfUserId: uid,
    );
  }

  // EVENT WISHLIST V1 — mirrors RestaurantDetailScreen's/HotelDetailScreen's
  // own _toggleWishlist exactly: non-optimistic (state only flips after
  // the write succeeds), same sign-in/busy/error handling shape. Never
  // reads or writes [_status]/[_confirmedAttendance] — Wishlist and
  // attendance intent are independent user actions (see this feature's
  // own spec).
  Future<void> _toggleWishlist() async {
    final uid = _userId;
    if (uid == null) {
      _showWishlistSnack(_signInMessage, isError: true);
      return;
    }
    if (_wishlistSaving) return;

    setState(() => _wishlistSaving = true);
    try {
      final nowWishlisted = await _wishlistRepo.toggleEventWishlist(
        userId: uid,
        eventId: widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _isWishlisted = nowWishlisted;
        _wishlistSaving = false;
      });
      _showWishlistSnack(
        nowWishlisted ? 'Added to wishlist' : 'Removed from wishlist',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _wishlistSaving = false);
      _showWishlistSnack(
        'Could not update wishlist. Please try again.',
        isError: true,
      );
    }
  }

  void _showWishlistSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.textOnDark),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Handles a tap on either intent pill. [tapped] is always the status
  /// the tapped pill represents, regardless of current state —
  /// [resolveIntentTap] (event_intent.dart) is the single place that
  /// decides whether this is a selection or a removal. The Supabase write
  /// always happens first and must succeed before any local state or
  /// analytics changes — see this method's own ordering, matching Events
  /// V2 Step 3's non-negotiable successful-write rule.
  Future<void> _handleIntentTap(EventIntentStatus tapped) async {
    final uid = _userId;
    final event = _event;
    // Unreachable in practice — this app requires a session for the whole
    // shell (AuthGate), so Event Detail is never reached signed out — kept
    // as defensive dead-code safety, matching this screen's own existing
    // convention rather than inventing a new one.
    if (uid == null || event == null || _intentBusy) return;

    final previous = _status;
    final next = resolveIntentTap(current: previous, tapped: tapped);
    setState(() {
      _intentBusy = true;
      _pendingTarget = next;
    });
    try {
      if (next == null) {
        await _attendanceRepo.removeEventIntent(
          userId: uid,
          eventId: widget.eventId,
        );
      } else {
        await _attendanceRepo.setEventIntent(
          userId: uid,
          eventId: widget.eventId,
          status: next,
        );
      }
      if (!mounted) return;
      setState(() {
        _status = next;
        _intentBusy = false;
        _pendingTarget = null;
      });
      // Analytics only after the write above has already succeeded — see
      // the method-level doc comment. intentAnalyticsEvents already
      // encodes the exact contract-derived decision for a switch firing
      // two events (a removed echo, then an added echo) rather than one.
      final properties = _intentProperties(event);
      for (final analyticsEvent in intentAnalyticsEvents(
        previous: previous,
        next: next,
      )) {
        _analytics.track(analyticsEvent, properties);
      }
    } catch (_) {
      if (!mounted) return;
      // No local state changed above the try block, so simply clearing
      // the busy flags already restores the last confirmed state — no
      // separate rollback step is needed (non-optimistic UI, by design).
      setState(() {
        _intentBusy = false;
        _pendingTarget = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update. Please try again.',
            style: GoogleFonts.inter(color: AppColors.textOnDark),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Only data already in hand from this screen's own load — never an
  /// extra query solely to populate an analytics property. `hostCount`
  /// and `availabilityStatus` were evaluated and deliberately left
  /// unpopulated in this step (see the Step 3 implementation report) —
  /// neither is reliably available here without new data-fetching
  /// plumbing this step doesn't otherwise need.
  AnalyticsProperties _intentProperties(Event event) => AnalyticsProperties(
    entityType: AnalyticsEntityType.event,
    entityId: event.id,
    sourceSurface: widget.sourceSurface,
    sourceContext: widget.sourceContext,
    eventCategory: event.eventType.dbValue,
    city: event.city,
    countryCode: event.countryCode,
    admissionType: event.admissionType.dbValue,
  );

  /// Fires `event_attendance_prompted` at most once per screen visit, only
  /// when the resolved state is actually [AttendanceUiState.promptable] —
  /// never for the plain manual CTA or the attended state, which are not
  /// "prompts" in the analytics-contract sense (see
  /// EVENTS_V2_ANALYTICS_CONTRACT.md's Attendance section: "the prompt is
  /// shown").
  void _maybeFirePromptedAnalytics(
    Event event,
    EventIntentStatus? intent,
    EventConfirmedAttendance? confirmed,
  ) {
    if (_promptedAnalyticsFired) return;
    final state = resolveAttendanceUiState(
      event: event,
      intent: intent,
      hasConfirmedAttendance: confirmed != null,
    );
    if (state != AttendanceUiState.promptable) return;
    _promptedAnalyticsFired = true;
    _analytics.track(
      AnalyticsEvent.eventAttendancePrompted,
      _intentProperties(event),
    );
  }

  AnalyticsProperties _attendanceProperties(
    Event event,
    EventAttendanceSource source, {
    bool? wouldRecommend,
  }) => AnalyticsProperties(
    entityType: AnalyticsEntityType.event,
    entityId: event.id,
    sourceSurface: widget.sourceSurface,
    sourceContext: widget.sourceContext,
    eventCategory: event.eventType.dbValue,
    city: event.city,
    countryCode: event.countryCode,
    admissionType: event.admissionType.dbValue,
    attendanceSource: attendanceSourceForAnalytics(source),
    wouldRecommend: wouldRecommend,
  );

  /// Yes (from the prompt) and the plain manual "Add to Passport" CTA both
  /// funnel through this one method — §7's "reuse one Attendance
  /// confirmation flow" — differing only in [source]. Ordering matches
  /// §19 exactly: (1) insert confirmed Attendance, (2) confirm success,
  /// (3) remove Going intent IF one exists — in its own try/catch so a
  /// cleanup failure never undoes the already-successful Attendance write
  /// — (4) update UI, (5) analytics, (6) the optional rating/comment sheet
  /// (itself a second, independent write — see attendance_details_sheet's
  /// own header comment for why dismissing it has no effect on whether
  /// attendance is recorded).
  Future<void> _confirmAttendance(EventAttendanceSource source) async {
    final uid = _userId;
    final event = _event;
    if (uid == null || event == null || _attendanceBusy) return;

    setState(() => _attendanceBusy = true);
    late final EventConfirmedAttendance confirmed;
    try {
      confirmed = await _confirmedRepo.confirmAttendance(
        userId: uid,
        eventId: widget.eventId,
        source: source,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _attendanceBusy = false);
      _showAttendanceError();
      return;
    }
    if (!mounted) return;
    setState(() {
      _confirmedAttendance = confirmed;
      _attendanceBusy = false;
    });
    final properties = _attendanceProperties(event, source);
    _analytics.track(AnalyticsEvent.eventAttendanceConfirmed, properties);
    _analytics.track(AnalyticsEvent.passportItemCreated, properties);

    // Stale Going intent should no longer remain as active upcoming intent
    // once history exists — but a failure here must never roll back the
    // Attendance write above, which stays authoritative regardless (§18).
    if (_status == EventIntentStatus.going) {
      try {
        await _attendanceRepo.removeEventIntent(
          userId: uid,
          eventId: widget.eventId,
        );
        if (mounted) setState(() => _status = null);
      } catch (_) {
        // Silently leave the stale Going row in place — Attendance is
        // already the authoritative record regardless of whether this
        // best-effort cleanup succeeded.
      }
    }

    if (!mounted) return;
    final details = await showAttendanceDetailsSheet(
      context: context,
      eventName: event.name,
      attendanceId: confirmed.id,
      eventId: event.id,
      onPhotoUploaded: () => _analytics.track(
        AnalyticsEvent.eventPhotoAdded,
        _attendanceProperties(event, confirmed.source),
      ),
    );
    if (details == null || !mounted) return;
    await _saveAttendanceDetails(details, event);
  }

  Future<void> _saveAttendanceDetails(
    AttendanceDetailsResult details,
    Event event,
  ) async {
    final uid = _userId;
    final current = _confirmedAttendance;
    if (uid == null || current == null) return;
    // Captured before the write — the analytics decision below (§21/Step
    // 4.1) needs to know what was on the row BEFORE this save to tell a
    // genuine "cleared an existing answer" apart from "never answered."
    final previousRecommendation = current.wouldRecommend;
    try {
      final updated = await _confirmedRepo.updateAttendanceDetails(
        userId: uid,
        attendanceId: current.id,
        rating: details.rating,
        comment: details.comment,
        wouldRecommend: WouldRecommendUpdate(details.wouldRecommend),
      );
      if (!mounted) return;
      setState(() => _confirmedAttendance = updated);
      final properties = _attendanceProperties(event, updated.source);
      if (details.rating != null) {
        _analytics.track(AnalyticsEvent.eventRatingAdded, properties);
      }
      if (details.comment != null) {
        _analytics.track(AnalyticsEvent.eventCommentAdded, properties);
      }
      final recommendationEvent = recommendationAnalyticsEvent(
        previous: previousRecommendation,
        next: details.wouldRecommend,
      );
      if (recommendationEvent != null) {
        _analytics.track(
          recommendationEvent,
          recommendationEvent == AnalyticsEvent.eventRecommendationAdded
              ? _attendanceProperties(
                  event,
                  updated.source,
                  wouldRecommend: details.wouldRecommend,
                )
              : properties,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showAttendanceError();
    }
  }

  /// "No" — removes Going intent, creates no Attendance row, no schema
  /// change: Going is disposable current intent, not a historical record
  /// worth persisting a "declined" state for (§4's own reasoning). Denied
  /// analytics fires only after the removal actually succeeds (§21/§19).
  Future<void> _denyAttendance() async {
    final uid = _userId;
    final event = _event;
    if (uid == null || event == null || _attendanceBusy) return;
    setState(() => _attendanceBusy = true);
    try {
      await _attendanceRepo.removeEventIntent(
        userId: uid,
        eventId: widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _status = null;
        _attendanceBusy = false;
      });
      _analytics.track(
        AnalyticsEvent.eventAttendanceDenied,
        _attendanceProperties(event, EventAttendanceSource.postEventPrompt),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _attendanceBusy = false);
      _showAttendanceError();
    }
  }

  /// "Not now" — purely local, purely visual, no write, no analytics (no
  /// dismissal event exists in the canonical taxonomy — §21's explicit
  /// "do not invent one casually"). Hides the section for the rest of
  /// this screen visit only; reopening Event Detail later re-evaluates
  /// eligibility from scratch.
  void _dismissPromptLocally() =>
      setState(() => _promptDismissedLocally = true);

  Future<void> _editAttendanceDetails() async {
    final event = _event;
    final current = _confirmedAttendance;
    if (event == null || current == null) return;
    final details = await showAttendanceDetailsSheet(
      context: context,
      eventName: event.name,
      attendanceId: current.id,
      eventId: event.id,
      initialRating: current.rating,
      initialWouldRecommend: current.wouldRecommend,
      initialComment: current.comment,
      onPhotoUploaded: () => _analytics.track(
        AnalyticsEvent.eventPhotoAdded,
        _attendanceProperties(event, current.source),
      ),
    );
    if (details == null || !mounted) return;
    await _saveAttendanceDetails(details, event);
  }

  /// §16 — removing history is deliberate and final: it never recreates a
  /// Going row, it only deletes `event_confirmed_attendance` (photos
  /// cascade automatically at the database level).
  Future<void> _removeAttendance() async {
    final uid = _userId;
    final current = _confirmedAttendance;
    final event = _event;
    if (uid == null || current == null || event == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Passport?'),
        content: const Text(
          'This removes your confirmed attendance, rating, notes and photos '
          'for this event. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _confirmedRepo.deleteConfirmedAttendance(
        userId: uid,
        attendanceId: current.id,
      );
      if (!mounted) return;
      setState(() => _confirmedAttendance = null);
      _analytics.track(
        AnalyticsEvent.passportItemRemoved,
        _attendanceProperties(event, current.source),
      );
    } catch (_) {
      if (!mounted) return;
      _showAttendanceError();
    }
  }

  void _showAttendanceError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not update. Please try again.',
          style: GoogleFonts.inter(color: AppColors.textOnDark),
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openRestaurant(Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  void _openHotel(Hotel hotel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.textOnDark,
            strokeWidth: 1.5,
          ),
        ),
      );
    }
    final event = _event;
    if (_loadError || event == null) {
      return Scaffold(
        backgroundColor: AppColors.ivory,
        appBar: AppBar(
          backgroundColor: AppColors.ivory,
          elevation: 0,
          foregroundColor: AppColors.forestGreen,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.taupe,
                size: 40,
              ),
              const SizedBox(height: CsSpacing.base),
              Text(
                'Could not load this event',
                style: CsTypography.body.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: CsSpacing.md),
              TextButton(
                onPressed: _load,
                child: Text(
                  'Retry',
                  style: CsTypography.bodyMedium.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasWebsite =
        event.officialUrl != null && event.officialUrl!.isNotEmpty;
    final hasTickets = event.ticketUrl != null && event.ticketUrl!.isNotEmpty;
    final hasAddress = event.address != null && event.address!.isNotEmpty;
    // Events V2 Time Precision Phase B — Event Detail Hierarchy UX
    // correction: LOCATION is now location-only (Tickets/Official website
    // moved to the new ACTIONS area, above) — hasLocationSection is simply
    // hasAddress now, not a three-way OR.
    final hasLocationSection = hasAddress;
    final ticketButtonLabel = event.admissionType == EventAdmissionType.mixed
        ? 'Optional ticket'
        : 'Tickets';
    final canAttend = canAttendEvent(event);
    final attendanceState = _promptDismissedLocally
        ? AttendanceUiState.none
        : resolveAttendanceUiState(
            event: event,
            intent: _status,
            hasConfirmedAttendance: _confirmedAttendance != null,
          );

    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;
    final backgroundImage = hasImage
        ? Image.network(
            event.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const CsImagePlaceholder(logoScale: _heroLogoScale),
          )
        : const CsImagePlaceholder(logoScale: _heroLogoScale);
    // Editorial Hero + Essentials/Actions polish pass: the one piece of
    // Event identity the hero carries again — a subtle editorial eyebrow,
    // never the generic "EVENT" fallback (EventType.other renders no
    // label at all, same "no type known" treatment EventMetaSection
    // always used for this case).
    final heroEventTypeLabel = event.eventType == EventType.other
        ? null
        : event.eventType.label.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: CustomScrollView(
        slivers: [
          // Events V2 Time Precision Phase B — Event Detail Hierarchy UX
          // correction, hero/Essentials title correction, editorial Hero
          // polish: the hero carries only the subtle event-type eyebrow —
          // title, date, venue/city, and admission all live in
          // EventMetaSection ("Event Essentials") directly below, so the
          // hero stays otherwise photography-ready (no title/date/venue/
          // admission competing with future Event photography).
          EventDetailHero(
            eventTypeLabel: heroEventTypeLabel,
            backgroundImage: backgroundImage,
            isWishlisted: _isWishlisted,
            wishlistSaving: _wishlistSaving,
            onTapWishlist: _toggleWishlist,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.xl,
                CsSpacing.pageHorizontal,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventMetaSection(event: event),

                  // Events V2 Time Precision Phase B — Event Detail
                  // Hierarchy UX correction: ACTIONS moved up from the
                  // former LOCATION section, directly after Essentials —
                  // Tickets/Official website are actionable, practical
                  // information and belong near the top, not buried near
                  // the bottom of the screen. EventActionsRow itself
                  // renders nothing when neither URL exists, so no empty
                  // divider/section appears for an Event with no links.
                  if (hasWebsite || hasTickets) ...[
                    const SectionDivider(),
                    EventActionsRow(
                      ticketUrl: event.ticketUrl,
                      officialUrl: event.officialUrl,
                      ticketLabel: ticketButtonLabel,
                      eventName: event.name,
                      onTapUrl: _openUrl,
                    ),
                  ],

                  if (attendanceState != AttendanceUiState.none) ...[
                    const SectionDivider(),
                    EventAttendanceSection(
                      state: attendanceState,
                      attendance: _confirmedAttendance,
                      eventName: event.name,
                      busy: _attendanceBusy,
                      onYes: () => _confirmAttendance(
                        EventAttendanceSource.postEventPrompt,
                      ),
                      onNo: _denyAttendance,
                      onNotNow: _dismissPromptLocally,
                      onManualAttend: () =>
                          _confirmAttendance(EventAttendanceSource.manual),
                      onEdit: _editAttendanceDetails,
                      onRemove: _removeAttendance,
                    ),
                  ],

                  if (canAttend) ...[
                    const SectionDivider(),
                    EventIntentControls(
                      status: _status,
                      busy: _intentBusy,
                      pendingTarget: _pendingTarget,
                      onTap: _handleIntentTap,
                    ),
                    FutureBuilder<List<Friendship>>(
                      future: _friendsGoingFuture,
                      builder: (context, snap) {
                        final friends = snap.data;
                        if (snap.connectionState != ConnectionState.done ||
                            snap.hasError ||
                            friends == null ||
                            friends.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionDivider(),
                            EventFriendsGoingSection(
                              eventTitle: event.name,
                              friends: friends,
                            ),
                          ],
                        );
                      },
                    ),
                    // Events V2 Step 7. Going before Interested — the
                    // stronger intent leads, matching the task's own
                    // explicit product hierarchy. Independently gated:
                    // Interested friends render (or don't) regardless of
                    // whether the Going section above rendered anything.
                    FutureBuilder<List<Friendship>>(
                      future: _friendsInterestedFuture,
                      builder: (context, snap) {
                        final friends = snap.data;
                        if (snap.connectionState != ConnectionState.done ||
                            snap.hasError ||
                            friends == null ||
                            friends.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionDivider(),
                            EventFriendsInterestedSection(
                              eventTitle: event.name,
                              friends: friends,
                            ),
                          ],
                        );
                      },
                    ),
                    // Events V2 Step 7. Anonymous social proof — a plain
                    // text line, not a labeled section, not tappable
                    // (there is no identity list behind it), independent
                    // of whether either Friends group above rendered
                    // anything. formatGoingMemberCount returns null for a
                    // 0 count, which this FutureBuilder already treats
                    // the same as "nothing to show" alongside loading/
                    // error/null-data.
                    FutureBuilder<GoingMemberCount>(
                      future: _goingMemberCountFuture,
                      builder: (context, snap) {
                        final memberCount = snap.data;
                        final copy = memberCount == null
                            ? null
                            : formatGoingMemberCount(memberCount);
                        if (snap.connectionState != ConnectionState.done ||
                            snap.hasError ||
                            copy == null) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: CsSpacing.sm),
                          child: Text(
                            copy,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.taupe,
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  if (event.description != null &&
                      event.description!.isNotEmpty) ...[
                    const SectionDivider(),
                    VenueAboutSection(text: event.description),
                  ],

                  if (_venues.restaurants.isNotEmpty) ...[
                    const SectionDivider(),
                    AtThisEventSection(
                      restaurants: _venues.restaurants,
                      onTapRestaurant: _openRestaurant,
                    ),
                  ],

                  if (_venues.hotels.isNotEmpty) ...[
                    const SectionDivider(),
                    Text(
                      'HOTELS',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.md),
                    for (var i = 0; i < _venues.hotels.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      LinkedVenueRow(
                        name: _venues.hotels[i].name,
                        onTap: () => _openHotel(_venues.hotels[i]),
                      ),
                    ],
                  ],

                  // Events V2 Time Precision Phase B — Event Detail
                  // Hierarchy UX correction: LOCATION is now genuinely
                  // location-only — Tickets/Official website moved up to
                  // ACTIONS, above. hasLocationSection/hasAddress below
                  // reflect that (see this build method's own local
                  // variable definitions).
                  if (hasLocationSection) ...[
                    const SectionDivider(),
                    Text(
                      'LOCATION',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.md),
                    Text(
                      event.address!,
                      style: CsTypography.body.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
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
