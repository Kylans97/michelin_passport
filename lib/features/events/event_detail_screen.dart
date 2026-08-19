import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_image_placeholder.dart';
import '../../core/widgets/linked_venue_row.dart';
import '../../core/widgets/section_divider.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../core/widgets/venue_about_section.dart';
import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../models/event.dart';
import '../../models/event_attendance.dart';
import '../../models/event_intent.dart';
import '../../models/friendship.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'event_date_format.dart';
import 'friends_going_view_model.dart';
import 'widgets/at_this_event_section.dart';
import 'widgets/event_detail_hero.dart';
import 'widgets/event_friends_going_section.dart';
import 'widgets/event_intent_controls.dart';
import 'widgets/event_meta_section.dart';

// Smaller than CsImagePlaceholder's own 0.4 default: a hero is a much
// larger, wider area than a card thumbnail, so the same relative scale
// would make the monogram feel oversized.
const double _heroLogoScale = 0.22;

/// Whether "I'm going" should be offered at all — no new event-status
/// system (Step 2B §21's explicit instruction, unchanged by the Events UI
/// Consistency Step 1 redesign): reuses [Event.isCancelled] and the
/// event's own [Event.endAt]. A top-level pure function, not inlined in
/// build(), so it's directly unit-testable without a live Supabase
/// session.
bool canAttendEvent(Event event, {DateTime? now}) =>
    !event.isCancelled && event.endAt.isAfter(now ?? DateTime.now());

/// Full event details — Events UI Consistency Step 1: rebuilt onto the
/// same editorial design language Restaurant/Hotel Detail established
/// (ivory canvas, forest-green content, taupe secondary text, gold
/// reserved for Michelin stars only, [SectionDivider] hairlines), while
/// preserving every existing behavior: attendance, admission, linked
/// venues, and navigation are all unchanged in substance, only in
/// presentation. See docs/Architecture/EVENTS_UI_MICHELIN_PARTICIPATION.md
/// for the full before/after and the Michelin-participation architecture.
///
/// Hero (image or branded monogram fallback, name, city/country, date
/// range) → EVENT META (date/time, venue, admission) → ATTENDANCE (if
/// [canAttendEvent]) → ABOUT (conditional, reusing [VenueAboutSection]
/// outright) → AT THIS EVENT (conditional, Michelin-starred linked
/// restaurants only — Events V2 Step 3 renamed this section's heading
/// from "MICHELIN AT THIS EVENT"; see [AtThisEventSection]'s own doc
/// comment for why the section name is entity-neutral even though its
/// current content is unchanged) → HOTELS (conditional, preserved
/// existing functionality, reskinned) → LOCATION / practical info
/// (address + Website/Tickets, conditional as a whole).
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
  late final FriendshipRepository _friendshipRepo = FriendshipRepository(
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
  // The status a mutation-in-flight is moving toward; null while a
  // removal is in flight (see EventIntentControls' own doc comment).
  EventIntentStatus? _pendingTarget;

  // Populated only for an upcoming/current, non-cancelled event with a
  // signed-in viewer (see canAttendEvent) — never awaited by _load itself,
  // so a slow or failed friends-going lookup can never block or break the
  // rest of Event Detail; EventFriendsGoingSection's own FutureBuilder
  // handles loading/error/empty by simply not rendering the section.
  Future<List<Friendship>>? _friendsGoingFuture;

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
      final event = await eventFuture;
      final venues = await venuesFuture;
      final intent = await intentFuture;
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
        _loading = false;
        _friendsGoingFuture = (uid != null && canAttendEvent(event))
            ? _loadFriendsGoing(uid, event.id)
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<List<Friendship>> _loadFriendsGoing(String uid, String eventId) async {
    // Going-scoped, deliberately — see getVisibleUserIds' own doc comment.
    // Interested rows must never appear under a "Friends Going" heading.
    final attendeeIds = await _attendanceRepo.getVisibleUserIds(
      eventId: eventId,
      status: EventIntentStatus.going,
    );
    final friends = await _friendshipRepo.getFriends();
    return friendsGoingToEvent(
      attendeeUserIds: attendeeIds,
      friends: friends,
      selfUserId: uid,
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

    final cityCountryLine = [
      if (event.city != null && event.city!.isNotEmpty) event.city,
      event.countryCode,
    ].join(' · ');
    final hasWebsite =
        event.officialUrl != null && event.officialUrl!.isNotEmpty;
    final hasTickets = event.ticketUrl != null && event.ticketUrl!.isNotEmpty;
    final hasAddress = event.address != null && event.address!.isNotEmpty;
    final hasLocationSection = hasAddress || hasWebsite || hasTickets;
    final ticketButtonLabel = event.admissionType == EventAdmissionType.mixed
        ? 'Optional ticket'
        : 'Tickets';
    final canAttend = canAttendEvent(event);

    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;
    final backgroundImage = hasImage
        ? Image.network(
            event.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const CsImagePlaceholder(logoScale: _heroLogoScale),
          )
        : const CsImagePlaceholder(logoScale: _heroLogoScale);

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: CustomScrollView(
        slivers: [
          EventDetailHero(
            title: event.name,
            eventTypeLabel: event.eventType.label.toUpperCase(),
            cityCountryLine: cityCountryLine,
            dateRangeLine: formatEventDateRange(event).toUpperCase(),
            backgroundImage: backgroundImage,
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

                  if (hasLocationSection) ...[
                    const SectionDivider(),
                    Text(
                      'LOCATION',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.md),
                    if (hasAddress)
                      Text(
                        event.address!,
                        style: CsTypography.body.copyWith(
                          color: AppColors.forestGreen,
                        ),
                      ),
                    if (hasAddress && (hasWebsite || hasTickets))
                      const SizedBox(height: CsSpacing.md),
                    if (hasWebsite || hasTickets)
                      Row(
                        children: [
                          if (hasWebsite)
                            SubtleTextAction(
                              label: 'Website',
                              onTap: () => _openUrl(event.officialUrl!),
                            ),
                          if (hasWebsite && hasTickets)
                            const SizedBox(width: CsSpacing.xl),
                          if (hasTickets)
                            SubtleTextAction(
                              label: ticketButtonLabel,
                              onTap: () => _openUrl(event.ticketUrl!),
                            ),
                        ],
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
