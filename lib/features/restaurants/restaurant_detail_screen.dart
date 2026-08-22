import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/linked_venue_row.dart';
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
import '../../models/passport_venue.dart';
import '../../models/restaurant.dart';
import '../../models/save_outcome.dart';
import '../../models/visit.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/hosted_events_section.dart';
import '../hotels/hotel_detail_screen.dart';
import '../planning/widgets/plan_venue_sheet.dart';
import '../visits/widgets/add_visit_sheet.dart';
import 'award_history_screen.dart';
import 'widgets/award_history_action.dart';
import 'widgets/restaurant_hero.dart';
import 'widgets/restaurant_info_card.dart';
import 'widgets/restaurant_visits_card.dart';

const _signInMessage = 'Sign in to save visits and wishlist restaurants.';

class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _wishlistRepo = WishlistRepository(Supabase.instance.client);
  late final _followRepo = FollowRepository(Supabase.instance.client);
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  late final _photoRepo = PhotoRepository(Supabase.instance.client);
  late final _awardHistoryRepo = AwardHistoryRepository(
    Supabase.instance.client,
  );
  late final _plannedTripsRepo = PlannedTripsRepository(
    Supabase.instance.client,
  );
  late final _eventsRepo = EventsRepository(Supabase.instance.client);
  // Events V2 Step 6 — never wired into a constructor param (matching
  // EventDetailScreen's own established seam); no vendor is selected yet,
  // so this is always the production-safe no-op today.
  final AnalyticsService _analytics = const NoopAnalyticsService();

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  bool _loadingPersonalState = true;
  List<Visit> _visits = [];
  bool _isWishlisted = false;
  bool _wishlistSaving = false;
  bool _isFollowing = false;
  bool _followBusy = false;
  bool _loadingHotel = false;

  // Catalogue data, not personal state — loaded regardless of sign-in.
  // Starts false (action hidden) rather than showing then hiding it, since
  // most restaurants resolve this within a single indexed round trip.
  bool _hasAwardHistory = false;

  // Events V2 Step 8B — starts empty (section hidden) rather than showing
  // a loading/empty state, same "not yet resolved = hidden" convention as
  // _hasAwardHistory. Only ever set on a successful, non-empty load — see
  // _loadHostedEvents' own doc comment for why a failure leaves this
  // silently empty rather than surfacing an error.
  List<Event> _hostedEvents = const [];

  bool get _isVisited => _visits.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadPersonalState();
    _checkAwardHistory();
    _loadHostedEvents();
  }

  // Events V2 Step 8B — hosted Events are enhancement content: a failed
  // lookup (or simply zero qualifying Events) must never affect the rest
  // of this screen, so this leaves _hostedEvents at its empty default on
  // any error rather than showing a raw failure — matching
  // _checkAwardHistory's own established "leave hidden on failure"
  // pattern exactly.
  Future<void> _loadHostedEvents() async {
    try {
      final events = await _eventsRepo.loadHostedEventsForRestaurant(
        widget.restaurant.id,
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
      final hasHistory = await _awardHistoryRepo.hasAnyHistory(
        widget.restaurant.id,
      );
      if (!mounted) return;
      setState(() => _hasAwardHistory = hasHistory);
    } catch (_) {
      // Leave the action hidden on a failed check rather than risk opening
      // AwardHistoryScreen to a broken state.
    }
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
      final visitsFuture = _visitedRepo.loadVisitsForRestaurant(
        uid,
        widget.restaurant.id,
      );
      final wishlistedFuture = _wishlistRepo.isWishlisted(
        userId: uid,
        restaurantId: widget.restaurant.id,
      );
      final followingFuture = _followRepo.isFollowingRestaurant(
        userId: uid,
        restaurantId: widget.restaurant.id,
      );
      final visits = await visitsFuture;
      final wishlisted = await wishlistedFuture;
      final following = await followingFuture;
      if (!mounted) return;
      setState(() {
        _visits = visits;
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

  // Reloads just the visit history, e.g. after saving a new visit, so it
  // reflects the change immediately without leaving/reopening the screen.
  Future<void> _refreshVisits() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final visits = await _visitedRepo.loadVisitsForRestaurant(
        uid,
        widget.restaurant.id,
      );
      if (!mounted) return;
      setState(() => _visits = visits);
    } catch (_) {
      // Keep showing the previous list rather than clearing it on a
      // transient error.
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
        // Step 1B color rule: gold is reserved for Michelin stars only —
        // this is a generic save/wishlist confirmation, not a Michelin
        // moment, so it reads forest-green rather than gold.
        backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
        duration: const Duration(seconds: 2),
      ),
    );
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
      final nowWishlisted = await _wishlistRepo.toggleWishlist(
        userId: uid,
        restaurantId: widget.restaurant.id,
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

  // Events V2 Step 6. Non-optimistic, matching _toggleWishlist and
  // EventDetailScreen._handleIntentTap's own documented rationale: state
  // only flips after the write succeeds, so a failure never needs a
  // rollback — clearing _followBusy alone already restores the correct
  // (unchanged) state. Analytics fires only after the write succeeds, per
  // AnalyticsService.track's own mandatory successful-write rule.
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
        await _followRepo.unfollowRestaurant(
          userId: uid,
          restaurantId: widget.restaurant.id,
        );
      } else {
        await _followRepo.followRestaurant(
          userId: uid,
          restaurantId: widget.restaurant.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = !wasFollowing;
        _followBusy = false;
      });
      _showSnack(
        followSnackMessage(
          wasFollowing: wasFollowing,
          entityName: widget.restaurant.name,
        ),
      );
      _analytics.track(
        wasFollowing
            ? AnalyticsEvent.followRemoved
            : AnalyticsEvent.followAdded,
        AnalyticsProperties(
          entityType: AnalyticsEntityType.restaurant,
          entityId: widget.restaurant.id,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _followBusy = false);
      _showSnack('Could not update. Please try again.', isError: true);
    }
  }

  Future<void> _openAddVisitSheet() async {
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    final result = await showAddVisitSheet(
      context,
      restaurant: widget.restaurant,
      userId: uid,
      visitedRepository: _visitedRepo,
      photoRepository: _photoRepo,
    );
    if (result != null && mounted) {
      await _refreshVisits();
      if (!mounted) return;
      final photoErrors = result == SaveOutcome.savedWithPhotoErrors;
      _showSnack(
        photoErrors
            ? 'Visit saved, but some photos could not be uploaded.'
            : 'Visit saved',
        isError: photoErrors,
      );
    }
  }

  Future<void> _openMaps() async {
    final restaurant = widget.restaurant;
    final Uri uri;
    if (restaurant.googlePlaceId != null &&
        restaurant.googlePlaceId!.isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${restaurant.googlePlaceId}&query_place_id=${restaurant.googlePlaceId}',
      );
    } else {
      final query = Uri.encodeComponent(
        '${restaurant.name} ${restaurant.cityName}',
      );
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

  // Restaurant Enrichment Step 1D. Never called with an empty/unparseable
  // phone — the call site only wires this up when buildTelUri already
  // resolved a real tel: URI (see hasPhoneLink/telUri below), so a null
  // here would be a caller bug, not an expected runtime case; failing
  // silently (matching _openUrl/_openMaps' own established pattern) is
  // still the right behaviour if it ever happens.
  Future<void> _openCall(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPlanVisit() async {
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    final saved = await showPlanVenueSheet(
      context,
      venue: RestaurantVenue(widget.restaurant),
      userId: uid,
      plannedTripsRepository: _plannedTripsRepo,
    );
    if (saved == true && mounted) _showSnack('Visit planned');
  }

  void _openAwardHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AwardHistoryScreen(restaurant: widget.restaurant),
      ),
    );
  }

  // Resolves the actual Hotel via HotelRepository before navigating —
  // restaurants_full only carries hotel_id/hotel_name, never enough to
  // construct a real Hotel, so HotelDetailScreen always gets the genuine
  // hotels_full row rather than a partial stand-in.
  Future<void> _openHotel() async {
    final hotelId = widget.restaurant.hotelId;
    if (hotelId == null || _loadingHotel) return;
    setState(() => _loadingHotel = true);
    try {
      final hotel = await _hotelRepo.getById(hotelId);
      if (!mounted) return;
      setState(() => _loadingHotel = false);
      if (hotel == null) {
        _showSnack('Could not load this hotel.', isError: true);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHotel = false);
      _showSnack('Could not load this hotel. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final hasHotelBadge =
        restaurant.isInHotel && (restaurant.hotelName?.isNotEmpty ?? false);
    // Only a real Michelin Key hotel (an actual hotels_full row) is
    // tappable — a hotel_name sourced purely from property_name (no
    // hotel_id) stays a plain, non-interactive display, unchanged.
    final canOpenHotel = hasHotelBadge && restaurant.hotelId != null;
    final michelinUrl = restaurant.michelinUrl;
    final websiteUrl = restaurant.websiteUrl;
    final isAuthenticated = _userId != null;

    final latestVisit = _visits.isEmpty ? null : _visits.first;
    final hasMichelinLink = michelinUrl != null && michelinUrl.isNotEmpty;
    final hasWebsiteLink = websiteUrl != null && websiteUrl.isNotEmpty;
    // Restaurant Enrichment Step 1D. buildTelUri returns null for an
    // empty/unparseable phone (no digits at all), which doubles as the
    // "hide the Call action" signal — matching hasMichelinLink/
    // hasWebsiteLink's own "presence of a usable value" pattern, never a
    // separately-tracked boolean that could drift from the URI itself.
    final telUri = (restaurant.phone ?? '').isEmpty
        ? null
        : buildTelUri(restaurant.phone!);
    // No editorial-copy field exists on Restaurant yet (no `description`/
    // `about`/`summary` column on restaurants_full) — see
    // VenueAboutSection's own doc comment. Kept as a local so the day a
    // real field lands, only this line changes.
    final String? aboutText = null;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: CustomScrollView(
        slivers: [
          RestaurantHero(
            restaurant: restaurant,
            hasHotelBadge: hasHotelBadge,
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
                  // area — venue name, Michelin stars, World's 50 Best and
                  // Hall of Fame all live there only. Just city/country as
                  // light supporting context here, shown once.
                  Text(
                    '${restaurant.flagEmoji}  ${restaurant.cityName}, '
                    '${restaurant.countryName}',
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
                    onCall: telUri == null ? null : () => _openCall(telUri),
                    onOpenMichelin: hasMichelinLink
                        ? () => _openUrl(michelinUrl)
                        : null,
                  ),

                  const SectionDivider(),

                  // ── Planning — a distinct intent from recording a visit
                  // that already happened: creates a planned_venues row
                  // (future intention / trip planning), never a visits
                  // row. Kept in its own compact section rather than
                  // beneath the utility row, where it previously read as
                  // a disconnected, loose action.
                  Text(
                    'PLAN YOUR VISIT',
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.taupe,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  SubtleTextAction(label: 'Plan visit', onTap: _openPlanVisit),

                  if (isAuthenticated && latestVisit != null) ...[
                    const SectionDivider(),
                    VenueScoreHeader(
                      noun: 'visit',
                      date: latestVisit.visitedOn,
                    ),
                    const SizedBox(height: CsSpacing.md),
                    VenueScoreStrip(
                      dimensions: [
                        ScoreDimension(
                          label: 'Overall',
                          value: latestVisit.rating,
                        ),
                        ScoreDimension(
                          label: 'Food',
                          value: latestVisit.foodRating,
                        ),
                        ScoreDimension(
                          label: 'Service',
                          value: latestVisit.serviceRating,
                        ),
                        ScoreDimension(
                          label: 'Wine',
                          value: latestVisit.wineRating,
                        ),
                        ScoreDimension(
                          label: 'Value',
                          value: latestVisit.valueRating,
                        ),
                      ],
                    ),
                  ],

                  if (aboutText != null) ...[
                    const SectionDivider(),
                    VenueAboutSection(text: aboutText),
                  ],

                  const SectionDivider(),

                  // ── History — recording a visit that already happened.
                  // "Add another visit"/"Add your first visit" lives here,
                  // beside the history it belongs to, never as a large
                  // top-of-screen CTA competing with venue navigation.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'YOUR VISITS',
                          style: CsTypography.eyebrow.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ),
                      SubtleTextAction(
                        label: _isVisited
                            ? 'Add another visit'
                            : 'Add your first visit',
                        onTap: _openAddVisitSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: CsSpacing.md),
                  RestaurantVisitsCard(
                    isAuthenticated: isAuthenticated,
                    loading: _loadingPersonalState,
                    visits: _visits,
                    restaurant: restaurant,
                    signInMessage: _signInMessage,
                    onReturn: _refreshVisits,
                  ),

                  if (latestVisit != null) ...[
                    const SectionDivider(),
                    Text(
                      'PERSONAL PHOTOS',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.md),
                    PersonalPhotosPreview(latestVisitId: latestVisit.id),
                  ],

                  if (hasHotelBadge) ...[
                    const SectionDivider(),
                    Text(
                      'AT THIS HOTEL',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.md),
                    LinkedVenueRow(
                      name: restaurant.hotelName!,
                      loading: _loadingHotel,
                      onTap: canOpenHotel ? _openHotel : null,
                    ),
                  ],

                  // Events V2 Step 8B — genuinely hosted Events only
                  // (is_host = true), upcoming/active, already
                  // chronologically sorted by the repository. Same
                  // relative position "AT THIS HOTEL"/"DINING" already
                  // occupy on Restaurant/Hotel Detail: just before the
                  // closing Info/Location card.
                  if (_hostedEvents.isNotEmpty) ...[
                    const SectionDivider(),
                    HostedEventsSection(
                      events: _hostedEvents,
                      onTapEvent: _openEvent,
                    ),
                  ],

                  if (restaurant.address.isNotEmpty) ...[
                    const SectionDivider(),
                    RestaurantInfoCard(restaurant: restaurant),
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
