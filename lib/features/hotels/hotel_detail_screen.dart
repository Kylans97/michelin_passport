import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/personal_photos_preview.dart';
import '../../core/widgets/section_divider.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../core/widgets/venue_about_section.dart';
import '../../core/widgets/venue_score_strip.dart';
import '../../core/widgets/venue_utility_actions.dart';
import '../../data/repositories/award_history_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/event.dart';
import '../../models/hotel.dart';
import '../../models/passport_venue.dart';
import '../../models/restaurant.dart';
import '../../models/save_outcome.dart';
import '../../models/visit.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/hosted_events_section.dart';
import '../planning/widgets/plan_venue_sheet.dart';
import '../restaurants/widgets/award_history_action.dart';
import '../stays/widgets/add_stay_sheet.dart';
import 'award_history_screen.dart';
import 'widgets/hotel_hero.dart';
import 'widgets/hotel_info_card.dart';
import 'widgets/hotel_restaurants_card.dart';
import 'widgets/hotel_stays_card.dart';

const _signInMessage = 'Sign in to save stays and wishlist hotels.';

/// Hotel detail screen: identity, location, external links, the Michelin
/// restaurants linked to this hotel (when any exist), the user's own stay
/// history, and wishlist/plan-a-stay personal state.
class HotelDetailScreen extends StatefulWidget {
  final Hotel hotel;

  const HotelDetailScreen({super.key, required this.hotel});

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _photoRepo = PhotoRepository(Supabase.instance.client);
  late final _wishlistRepo = WishlistRepository(Supabase.instance.client);
  late final _followRepo = FollowRepository(Supabase.instance.client);
  late final _plannedTripsRepo = PlannedTripsRepository(
    Supabase.instance.client,
  );
  late final _awardHistoryRepo = AwardHistoryRepository(
    Supabase.instance.client,
  );
  late final _eventsRepo = EventsRepository(Supabase.instance.client);
  late final Future<List<Restaurant>> _linkedRestaurantsFuture =
      widget.hotel.hasMichelinRestaurant
      ? _hotelRepo.getLinkedRestaurants(widget.hotel.id)
      : Future.value(const <Restaurant>[]);
  // Events V2 Step 6 — never wired into a constructor param (matching
  // EventDetailScreen's own established seam); no vendor is selected yet,
  // so this is always the production-safe no-op today.
  final AnalyticsService _analytics = const NoopAnalyticsService();

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  bool _loadingPersonalState = true;
  List<Visit> _stays = [];
  bool _isWishlisted = false;
  bool _wishlistSaving = false;
  bool _isFollowing = false;
  bool _followBusy = false;

  // Catalogue data, not personal state — loaded regardless of sign-in.
  // Starts false (action hidden) rather than showing then hiding it, since
  // most hotels resolve this within a single indexed round trip. Mirrors
  // RestaurantDetailScreen's _hasAwardHistory exactly.
  bool _hasAwardHistory = false;

  // Events V2 Step 8B — mirrors RestaurantDetailScreen's _hostedEvents
  // exactly. Production currently has zero event_hotels rows, so this
  // stays empty (section hidden) on every real device today — see the
  // Step 8B pre-final doc.
  List<Event> _hostedEvents = const [];

  @override
  void initState() {
    super.initState();
    _loadPersonalState();
    _checkAwardHistory();
    _loadHostedEvents();
  }

  // Events V2 Step 8B — mirrors RestaurantDetailScreen's
  // _loadHostedEvents exactly: a failed lookup (or zero qualifying
  // Events) silently leaves the section hidden, never surfaces an error.
  Future<void> _loadHostedEvents() async {
    try {
      final events = await _eventsRepo.loadHostedEventsForHotel(
        widget.hotel.id,
      );
      if (!mounted) return;
      setState(() => _hostedEvents = events);
    } catch (_) {
      // Leave the section hidden on a failed lookup.
    }
  }

  void _openEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          sourceSurface: AnalyticsSourceSurface.hostProfile,
        ),
      ),
    );
  }

  Future<void> _checkAwardHistory() async {
    try {
      final hasHistory = await _awardHistoryRepo.hasAnyHotelHistory(
        widget.hotel.id,
      );
      if (!mounted) return;
      setState(() => _hasAwardHistory = hasHistory);
    } catch (_) {
      // Leave the action hidden on a failed check rather than risk opening
      // HotelAwardHistoryScreen to a broken state.
    }
  }

  void _openAwardHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelAwardHistoryScreen(hotel: widget.hotel),
      ),
    );
  }

  Future<void> _loadPersonalState() async {
    final uid = _userId;
    if (uid == null) {
      // Not signed in: nothing to load, catalogue browsing stays available.
      setState(() => _loadingPersonalState = false);
      return;
    }
    try {
      // Started together so they run concurrently, then awaited in turn.
      final staysFuture = _visitedRepo.loadStaysForHotel(uid, widget.hotel.id);
      final wishlistedFuture = _wishlistRepo.isHotelWishlisted(
        userId: uid,
        hotelId: widget.hotel.id,
      );
      final followingFuture = _followRepo.isFollowingHotel(
        userId: uid,
        hotelId: widget.hotel.id,
      );
      final stays = await staysFuture;
      final wishlisted = await wishlistedFuture;
      final following = await followingFuture;
      if (!mounted) return;
      setState(() {
        _stays = stays;
        _isWishlisted = wishlisted;
        _isFollowing = following;
        _loadingPersonalState = false;
      });
    } catch (_) {
      // A failed personal-state load shouldn't block catalogue browsing —
      // fall back to "not yet" rather than showing an error for this.
      if (!mounted) return;
      setState(() => _loadingPersonalState = false);
    }
  }

  // Reloads just the stay history, e.g. after saving a new stay, so it
  // reflects the change immediately without leaving/reopening the screen.
  Future<void> _refreshStays() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final stays = await _visitedRepo.loadStaysForHotel(uid, widget.hotel.id);
      if (!mounted) return;
      setState(() => _stays = stays);
    } catch (_) {
      // Keep showing the previous list rather than clearing it on a
      // transient error.
    }
  }

  Future<void> _toggleWishlist() async {
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    if (_wishlistSaving) return;

    setState(() => _wishlistSaving = true);
    try {
      final nowWishlisted = await _wishlistRepo.toggleHotelWishlist(
        userId: uid,
        hotelId: widget.hotel.id,
      );
      if (!mounted) return;
      setState(() {
        _isWishlisted = nowWishlisted;
        _wishlistSaving = false;
      });
      _showSnack(nowWishlisted ? 'Added to wishlist' : 'Removed from wishlist');
    } catch (_) {
      if (!mounted) return;
      setState(() => _wishlistSaving = false);
      _showSnack('Could not update wishlist. Please try again.', isError: true);
    }
  }

  // Events V2 Step 6 — mirrors _toggleWishlist/RestaurantDetailScreen
  // ._toggleFollow exactly. Non-optimistic; analytics fires only after
  // the write succeeds.
  Future<void> _toggleFollow() async {
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    if (_followBusy) return;

    final wasFollowing = _isFollowing;
    setState(() => _followBusy = true);
    try {
      if (wasFollowing) {
        await _followRepo.unfollowHotel(userId: uid, hotelId: widget.hotel.id);
      } else {
        await _followRepo.followHotel(userId: uid, hotelId: widget.hotel.id);
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = !wasFollowing;
        _followBusy = false;
      });
      _showSnack(
        followSnackMessage(
          wasFollowing: wasFollowing,
          entityName: widget.hotel.name,
        ),
      );
      _analytics.track(
        wasFollowing
            ? AnalyticsEvent.followRemoved
            : AnalyticsEvent.followAdded,
        AnalyticsProperties(
          entityType: AnalyticsEntityType.hotel,
          entityId: widget.hotel.id,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _followBusy = false);
      _showSnack('Could not update. Please try again.', isError: true);
    }
  }

  Future<void> _openPlanStay() async {
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    final saved = await showPlanVenueSheet(
      context,
      venue: HotelVenue(widget.hotel),
      userId: uid,
      plannedTripsRepository: _plannedTripsRepo,
    );
    if (saved == true && mounted) _showSnack('Stay planned');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
        // Step 1B color rule: gold is reserved for MICHELIN Keys only —
        // this is a generic save/wishlist confirmation, not a Michelin
        // moment, so it reads forest-green rather than gold.
        backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAddStaySheet() async {
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    final result = await showAddStaySheet(
      context,
      hotel: widget.hotel,
      userId: uid,
      visitedRepository: _visitedRepo,
      photoRepository: _photoRepo,
    );
    if (result != null && mounted) {
      await _refreshStays();
      if (!mounted) return;
      final photoErrors = result == SaveOutcome.savedWithPhotoErrors;
      _showSnack(
        photoErrors
            ? 'Stay saved, but some photos could not be uploaded.'
            : 'Stay saved',
        isError: photoErrors,
      );
    }
  }

  Future<void> _openMaps() async {
    final hotel = widget.hotel;
    final Uri uri;
    if (hotel.googlePlaceId != null && hotel.googlePlaceId!.isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${hotel.googlePlaceId}&query_place_id=${hotel.googlePlaceId}',
      );
    } else {
      final query = Uri.encodeComponent('${hotel.name} ${hotel.cityName}');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final michelinUrl = hotel.michelinUrl;
    final websiteUrl = hotel.websiteUrl;
    final isAuthenticated = _userId != null;
    final latestStay = _stays.isEmpty ? null : _stays.first;
    final hasMichelinLink = michelinUrl != null && michelinUrl.isNotEmpty;
    final hasWebsiteLink = websiteUrl != null && websiteUrl.isNotEmpty;
    // No editorial-copy field exists on Hotel yet — see
    // VenueAboutSection's own doc comment and RestaurantDetailScreen's
    // matching note.
    final String? aboutText = null;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: CustomScrollView(
        slivers: [
          HotelHero(
            hotel: hotel,
            isWishlisted: _isWishlisted,
            wishlistSaving: _wishlistSaving,
            onTapWishlist: _toggleWishlist,
            isFollowing: _isFollowing,
            followBusy: _followBusy,
            onTapFollow: _toggleFollow,
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
                  // The hero is the single primary identity + recognition
                  // area — hotel name and MICHELIN Keys/World's 50 Best
                  // both live there only. Just city/country as light
                  // supporting context here, shown once.
                  Text(
                    '${hotel.flagEmoji}  ${hotel.cityName}, '
                    '${hotel.countryName}',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
                    ),
                  ),
                  if (_hasAwardHistory) ...[
                    const SizedBox(height: CsSpacing.sm),
                    AwardHistoryAction(onTap: _openAwardHistory),
                  ],

                  const SectionDivider(),

                  // ── Venue utilities — Directions/Website/Michelin only.
                  // Wishlist lives solely in the hero; there is no second
                  // Wishlist control here (UI Consistency Step 1E).
                  VenueUtilityActions(
                    onOpenMaps: _openMaps,
                    onOpenWebsite: hasWebsiteLink
                        ? () => _openUrl(websiteUrl)
                        : null,
                    // No `phone` field exists on Hotel today — a prepared
                    // seam, not a missing feature: see VenueUtilityActions'
                    // own doc comment.
                    onCall: null,
                    onOpenMichelin: hasMichelinLink
                        ? () => _openUrl(michelinUrl)
                        : null,
                  ),

                  const SectionDivider(),

                  // ── Planning — a distinct intent from recording a stay
                  // that already happened: creates a planned_venues row
                  // (future intention / trip planning), never a visits
                  // row. Kept in its own compact section rather than
                  // beneath the utility row, where it previously read as
                  // a disconnected, loose action.
                  Text(
                    'PLAN YOUR STAY',
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.taupe,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  SubtleTextAction(label: 'Plan stay', onTap: _openPlanStay),

                  if (isAuthenticated && latestStay != null) ...[
                    const SectionDivider(),
                    VenueScoreHeader(noun: 'stay', date: latestStay.visitedOn),
                    const SizedBox(height: CsSpacing.md),
                    VenueScoreStrip(
                      dimensions: [
                        ScoreDimension(
                          label: 'Overall',
                          value: latestStay.rating,
                        ),
                        ScoreDimension(
                          label: 'Service',
                          value: latestStay.serviceRating,
                        ),
                        ScoreDimension(
                          label: 'Room',
                          value: latestStay.roomRating,
                        ),
                        ScoreDimension(
                          label: 'Experience',
                          value: latestStay.experienceRating,
                        ),
                        ScoreDimension(
                          label: 'Value',
                          value: latestStay.valueRating,
                        ),
                      ],
                    ),
                  ],

                  if (aboutText != null) ...[
                    const SectionDivider(),
                    VenueAboutSection(text: aboutText),
                  ],

                  const SectionDivider(),

                  // ── History — recording a stay that already happened.
                  // "Add another stay"/"Add your first stay" lives here,
                  // beside the history it belongs to, never as a large
                  // top-of-screen CTA competing with venue navigation.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'YOUR STAYS',
                          style: CsTypography.eyebrow.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ),
                      SubtleTextAction(
                        label: _stays.isNotEmpty
                            ? 'Add another stay'
                            : 'Add your first stay',
                        onTap: _openAddStaySheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: CsSpacing.md),
                  HotelStaysCard(
                    isAuthenticated: isAuthenticated,
                    loading: _loadingPersonalState,
                    stays: _stays,
                    hotel: hotel,
                    signInMessage: _signInMessage,
                    onReturn: _refreshStays,
                  ),

                  if (latestStay != null) ...[
                    const SectionDivider(),
                    Text(
                      'PERSONAL PHOTOS',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.md),
                    PersonalPhotosPreview(latestVisitId: latestStay.id),
                  ],

                  if (hotel.hasMichelinRestaurant) ...[
                    const SectionDivider(),
                    Text(
                      'DINING',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.md),
                    HotelRestaurantsCard(future: _linkedRestaurantsFuture),
                  ],

                  // Events V2 Step 8B — same relative position DINING
                  // occupies: just before the closing Info/Location card.
                  if (_hostedEvents.isNotEmpty) ...[
                    const SectionDivider(),
                    HostedEventsSection(
                      events: _hostedEvents,
                      onTapEvent: _openEvent,
                    ),
                  ],

                  if (hotel.address.isNotEmpty) ...[
                    const SectionDivider(),
                    HotelInfoCard(hotel: hotel),
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
