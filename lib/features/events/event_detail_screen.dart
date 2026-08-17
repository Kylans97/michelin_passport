import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../../models/friendship.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'event_date_format.dart';
import 'friends_going_view_model.dart';
import 'widgets/event_detail_hero.dart';
import 'widgets/event_friends_going_section.dart';
import 'widgets/event_going_button.dart';
import 'widgets/event_meta_section.dart';
import 'widgets/michelin_at_event_section.dart';

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
/// outright) → MICHELIN AT THIS EVENT (conditional, Michelin-starred
/// linked restaurants only) → HOTELS (conditional, preserved existing
/// functionality, reskinned) → LOCATION / practical info (address +
/// Website/Tickets, conditional as a whole).
class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

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

  bool _loading = true;
  bool _loadError = false;
  Event? _event;
  EventVenues _venues = const EventVenues(restaurants: [], hotels: []);

  bool _going = false;
  bool _attendanceBusy = false;

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
      final attendanceFuture = uid == null
          ? Future.value(null)
          : _attendanceRepo.getMyAttendance(
              userId: uid,
              eventId: widget.eventId,
            );
      final event = await eventFuture;
      final venues = await venuesFuture;
      final attendance = await attendanceFuture;
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
        _going = attendance != null;
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
    final attendeeIds = await _attendanceRepo.getVisibleAttendeeUserIds(
      eventId,
    );
    final friends = await _friendshipRepo.getFriends();
    return friendsGoingToEvent(
      attendeeUserIds: attendeeIds,
      friends: friends,
      selfUserId: uid,
    );
  }

  Future<void> _toggleGoing() async {
    final uid = _userId;
    if (uid == null || _attendanceBusy) return;
    setState(() => _attendanceBusy = true);
    try {
      if (_going) {
        await _attendanceRepo.removeAttendance(
          userId: uid,
          eventId: widget.eventId,
        );
      } else {
        await _attendanceRepo.markGoing(userId: uid, eventId: widget.eventId);
      }
      if (!mounted) return;
      setState(() {
        _going = !_going;
        _attendanceBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _attendanceBusy = false);
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
                    EventGoingButton(
                      going: _going,
                      busy: _attendanceBusy,
                      onTap: _toggleGoing,
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
                    MichelinAtEventSection(
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
