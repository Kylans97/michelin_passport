import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/supabase_analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/utils/venue_lifecycle.dart';
import '../../core/widgets/linked_venue_row.dart';
import '../../core/widgets/personal_photos_preview.dart';
import '../../core/widgets/section_divider.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../core/widgets/venue_about_section.dart';
import '../../core/widgets/venue_team_section.dart';
import '../../core/widgets/venue_lifecycle_banner.dart';
import '../../core/widgets/venue_score_strip.dart';
import '../../core/widgets/venue_guide_links.dart';
import '../../core/widgets/venue_utility_actions.dart';
import '../profile/widgets/owner_preview_marker.dart';
import '../../data/repositories/award_history_repository.dart';
import '../../data/repositories/restaurant_gault_millau_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/venue_about_repository.dart';
import '../../data/repositories/venue_team_repository.dart';
import '../../models/venue_team_member.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/event.dart';
import '../../models/gault_millau_award.dart';
import '../../models/passport_venue.dart';
import '../../models/published_venue_photo.dart';
import '../../models/restaurant.dart';
import '../../models/save_outcome.dart';
import '../passport/stamp_ceremony.dart';
import '../../models/visit.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/hosted_events_section.dart';
import '../hotels/hotel_detail_screen.dart';
import '../planning/widgets/plan_venue_sheet.dart';
import '../passport/widgets/add_visit_flow.dart';
import 'award_history_screen.dart';
import 'widgets/award_history_action.dart';
import 'widgets/restaurant_hero.dart';
import 'widgets/restaurant_info_card.dart';
import 'widgets/restaurant_visits_card.dart';
import '../notifications/push_service.dart';
import '../friends/widgets/venue_friends_been_row.dart';

const _signInMessage = 'Sign in to save visits and wishlist restaurants.';

class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  /// Owner preview only. When supplied, replaces the live approved about
  /// text (venue_about_current) and skips that fetch entirely — a
  /// manager's own pending submission, or a test's fixture text. Null
  /// (every existing call site) is the live page, unchanged.
  final String? aboutTextOverride;

  /// Owner preview only. When supplied, replaces the live approved team
  /// (venue_team_current) and skips that fetch — the manager's pending
  /// names and texts merged over the published ones. Null is the live
  /// page, unchanged.
  final List<VenueTeamMember>? teamOverride;

  /// Owner preview only. When supplied, replaces the venue's own
  /// published photo set and skips that fetch entirely — see
  /// mergePreviewPhotoOrder (venue_preview_photo_merge.dart) for how a
  /// preview caller builds this from published + pending photos. Null is
  /// the live page, unchanged. Typed as [PublishedVenuePhoto], not a bare
  /// url list — see RestaurantHero.photos' own doc comment: the Report
  /// action needs each photo's real id. The preview caller supplies the
  /// published photo's own id for an untouched entry, or the pending
  /// submission's own id for a swapped-in/appended one (never a
  /// fabricated one) — see mergePreviewPhotoOrder's own doc comment.
  /// Reporting is inert in preview regardless (isPreview below), so which
  /// id a pending entry carries never actually matters in practice.
  final List<PublishedVenuePhoto>? photosOverride;

  /// Owner preview only. Turns off what belongs to the *viewer*, not what
  /// belongs to the venue: personal state (visits, wishlisted, following)
  /// is meaningless when previewing your own page, so it's skipped
  /// entirely rather than fetched and shown. Venue-level content a real
  /// visitor genuinely sees — award history, hosted events — is
  /// deliberately NOT gated by this flag; hiding it would make the
  /// preview an inaccurate copy of the live page, which is the one
  /// failure mode this whole feature exists to avoid. The mutating
  /// personal-state actions (Wishlist, Follow, Add visit, Plan visit)
  /// stay visible — hiding them would be the same inaccuracy — but become
  /// inert: each early-returns before touching any repository, so a
  /// manager tapping their own Wishlist heart from inside a preview
  /// changes nothing. Defaults to false; every existing call site is
  /// unaffected.
  final bool isPreview;

  /// Owner preview only. True when the caller's own fresh re-fetch of
  /// this venue failed and it fell back to a cached model instead —
  /// [restaurant] above may then be minutes old. Rendered as a second
  /// line on the PREVIEW pill (OwnerPreviewMarker) so that's disclosed on
  /// the screen itself rather than silently shown as current. Ignored
  /// when [isPreview] is false.
  final bool previewIsStale;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
    this.aboutTextOverride,
    this.teamOverride,
    this.photosOverride,
    this.isPreview = false,
    this.previewIsStale = false,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _wishlistRepo = WishlistRepository(Supabase.instance.client);
  late final _followRepo = FollowRepository(Supabase.instance.client);
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  late final _restaurantRepo = RestaurantRepository(Supabase.instance.client);
  late final _awardHistoryRepo = AwardHistoryRepository(
    Supabase.instance.client,
  );
  late final _gaultMillauRepo = RestaurantGaultMillauRepository(
    Supabase.instance.client,
  );
  late final _plannedTripsRepo = PlannedTripsRepository(
    Supabase.instance.client,
  );
  late final _eventsRepo = EventsRepository(Supabase.instance.client);
  late final _venueAboutRepo = VenueAboutRepository(Supabase.instance.client);
  late final _venueTeamRepo = VenueTeamRepository(Supabase.instance.client);
  // Events V2 Step 6 — never wired into a constructor param (matching
  // EventDetailScreen's own established seam). SupabaseAnalyticsService
  // persists only its own narrow set (page opens, website/Call/Directions
  // taps here) — see that class's own doc comment; everything else this
  // screen tracks is still discarded.
  late final AnalyticsService _analytics = SupabaseAnalyticsService.ofInstance();

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  bool _loadingPersonalState = true;
  List<Visit> _visits = [];
  bool _isWishlisted = false;
  bool _wishlistSaving = false;
  bool _isFollowing = false;
  // Set once the member taps Follow / the heart on this screen; see
  // _loadPersonalState.
  bool _followTouched = false;
  bool _wishlistTouched = false;
  bool _followBusy = false;
  bool _loadingHotel = false;

  // Catalogue data, not personal state — loaded regardless of sign-in.
  // Starts false (action hidden) rather than showing then hiding it, since
  // most restaurants resolve this within a single indexed round trip.
  bool _hasAwardHistory = false;

  // The latest Gault&Millau edition (gault_millau_awards, its own table —
  // never on restaurants_full). Drives the hero badge and the Gault&Millau
  // utility action. Same "starts hidden, only set on success" shape as
  // _hasAwardHistory: null means nothing to show, never "no award".
  GaultMillauAward? _gaultMillauAward;

  // Events V2 Step 8B — starts empty (section hidden) rather than showing
  // a loading/empty state, same "not yet resolved = hidden" convention as
  // _hasAwardHistory. Only ever set on a successful, non-empty load — see
  // _loadHostedEvents' own doc comment for why a failure leaves this
  // silently empty rather than surfacing an error.
  List<Event> _hostedEvents = const [];

  // The venue's current, APPROVED about text — venue_about_current, not
  // venue_about_submissions directly (that view already resolves "latest
  // approved," see VenueAboutRepository's own doc comment). Same "starts
  // hidden, only ever set on a successful non-empty-implied load" shape
  // as _hasAwardHistory/_hostedEvents just above — an about-text lookup
  // failure must not affect the rest of this screen, and `null` here is
  // already exactly what VenueAboutSection itself treats as "nothing to
  // show," so no separate loading/error state is needed for this one
  // field.
  String? _aboutText;

  // The venue's approved team (venue_team_current). Same "starts empty,
  // only ever set on success" shape as _aboutText.
  List<VenueTeamMember> _team = const [];

  // The venue's full published-photo set, in display_order — one venue,
  // one query, independent of restaurant_hero.dart's coverImageUrl
  // fallback (see RestaurantHero.photos' own doc comment for why this
  // is a second query rather than something the view/model carries: it's
  // only ever needed for the single venue open here, never for a list).
  // Same "starts empty, only ever set on success" shape as _aboutText —
  // an empty list already reads correctly to RestaurantHero (falls back
  // to the single cover photo already known from widget.restaurant).
  List<PublishedVenuePhoto> _photos = const [];

  bool get _isVisited => _visits.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // A visitor's page open — never a manager's own preview.
    if (!widget.isPreview) {
      _analytics.track(
        AnalyticsEvent.venueDetailOpened,
        AnalyticsProperties(
          entityType: AnalyticsEntityType.restaurant,
          entityId: widget.restaurant.id,
        ),
      );
    }
    // Award history/hosted events are venue-level content a real visitor
    // sees, so they always load, preview or not — only _loadPersonalState
    // itself is gated (see its own doc comment for why: isPreview only
    // turns off what belongs to the viewer).
    _loadPersonalState();
    _checkAwardHistory();
    _loadGaultMillau();
    _loadHostedEvents();
    if (widget.aboutTextOverride != null) {
      _aboutText = widget.aboutTextOverride;
    } else {
      _loadAboutText();
    }
    if (widget.teamOverride != null) {
      _team = widget.teamOverride!;
    } else {
      _loadTeam();
    }
    if (widget.photosOverride != null) {
      _photos = widget.photosOverride!;
    } else {
      _loadPhotos();
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await _restaurantRepo.getPhotos(widget.restaurant.id);
      if (!mounted) return;
      setState(() => _photos = photos);
    } catch (_) {
      // Leave the hero on its single cover photo (or gradient) on a
      // failed lookup — same reasoning as every other enhancement-content
      // load on this screen.
    }
  }

  Future<void> _loadTeam() async {
    try {
      final team = await _venueTeamRepo.loadCurrent(
        venueType: 'restaurant',
        venueId: widget.restaurant.id,
      );
      if (!mounted) return;
      setState(() => _team = team);
    } catch (_) {
      // Leave the section hidden on a failed lookup, like the about text.
    }
  }

  Future<void> _loadAboutText() async {
    try {
      final text = await _venueAboutRepo.loadCurrentText(
        venueType: 'restaurant',
        venueId: widget.restaurant.id,
      );
      if (!mounted) return;
      setState(() => _aboutText = text);
    } catch (_) {
      // Leave the section hidden on a failed lookup — same reasoning as
      // _checkAwardHistory/_loadHostedEvents above.
    }
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

  Future<void> _loadGaultMillau() async {
    try {
      final awards = await _gaultMillauRepo.loadForRestaurant(
        widget.restaurant.id,
      );
      if (!mounted || awards.isEmpty) return;
      setState(() => _gaultMillauAward = awards.first);
    } catch (_) {
      // Leave the badge and action hidden on a failed lookup.
    }
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
    // Preview: personal state (visits/wishlisted/following) is meaningless
    // when previewing your own page — skipped entirely rather than
    // fetched, same treatment as not being signed in below.
    final uid = widget.isPreview ? null : _userId;
    if (uid == null) {
      // Not signed in (or previewing): nothing to load, catalogue browsing
      // stays available.
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
      // Each awaited on its own (2026-10-31, tester: "I follow a
      // restaurant, go back, and I'm not following it any more"). One
      // failing query used to drop all three to "not yet", so a visits
      // load error hid a real follow. And a tap on Follow or the heart
      // before this returns wins: the stale "not yet" from a query that
      // started before the tap must not overwrite it.
      final visits = await _orNull(visitsFuture);
      final wishlisted = await _orNull(wishlistedFuture);
      final following = await _orNull(followingFuture);
      if (!mounted) return;
      setState(() {
        if (visits != null) _visits = visits;
        if (wishlisted != null && !_wishlistTouched) {
          _isWishlisted = wishlisted;
        }
        if (following != null && !_followTouched) _isFollowing = following;
        _loadingPersonalState = false;
      });
    } catch (_) {
      // A failed personal-state load shouldn't block catalogue browsing —
      // fall back to "not yet" rather than showing an error for this.
      if (!mounted) return;
      setState(() => _loadingPersonalState = false);
    }
  }

  // A personal-state value that failed to load is null, not an error for
  // the whole page — see _loadPersonalState.
  Future<T?> _orNull<T>(Future<T> f) =>
      f.then<T?>((v) => v, onError: (Object _) => null);

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
    // Preview: the heart stays visible (a visitor sees it) but does
    // nothing — see widget.isPreview's own doc comment.
    if (widget.isPreview) return;
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    if (_wishlistSaving) return;

    _wishlistTouched = true;
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

  // Events V2 Step 6; optimistic since 2026-10-30 (the pill must read
  // as followed the moment it is tapped). Analytics fires only after the
  // write succeeds, per AnalyticsService.track's own successful-write
  // rule.
  Future<void> _toggleFollow() async {
    // Preview: same as _toggleWishlist — inert, not hidden.
    if (widget.isPreview) return;
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    if (_followBusy) return;

    // Optimistic: the pill flips now and flips back if the write fails,
    // so the state is visible the moment it is tapped. [_followBusy]
    // only blocks a second tap while the write is in flight.
    _followTouched = true;
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !wasFollowing;
      _followBusy = true;
    });
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
      setState(() => _followBusy = false);
      _analytics.track(
        wasFollowing
            ? AnalyticsEvent.followRemoved
            : AnalyticsEvent.followAdded,
        AnalyticsProperties(
          entityType: AnalyticsEntityType.restaurant,
          entityId: widget.restaurant.id,
        ),
      );
      if (!wasFollowing) {
        // The one place a follow can lead to notifications: a single
        // explanation the first time, nothing after (PushService).
        unawaited(PushService.instance.offerAfterFollow(context, widget.restaurant.name));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFollowing = wasFollowing;
        _followBusy = false;
      });
      _showSnack('Could not update. Please try again.', isError: true);
    }
  }

  Future<void> _openAddVisitSheet() async {
    // Preview: inert — no sheet, no write. Opening the sheet at all would
    // let a manager go on to actually save a visit from inside a preview,
    // which is exactly the "submit/edit/change" this screen must never
    // allow here.
    if (widget.isPreview) return;
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    // The same sheet as Passport → +, opened at this restaurant, so a
    // visit is logged on one screen wherever it starts.
    final result = await showAddVisitFlow(
      context,
      userId: uid,
      initialVenue: RestaurantVenue(widget.restaurant),
    );
    if (result != null && mounted) {
      // The stamp first, then this screen catches up underneath it
      // unchanged — the ceremony returns to exactly where the member was.
      await celebrateNewStamp(context, EarnedStamp.visit(result.visit));
      if (!mounted) return;
      await _refreshVisits();
      if (!mounted) return;
      final photoErrors = result.outcome == SaveOutcome.savedWithPhotoErrors;
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
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) _trackVenueAction(AnalyticsEvent.venueDirectionsOpened);
    }
  }

  // Call / Directions, after launchUrl returned true — the same boundary
  // as the website link below. Never from a manager's own preview.
  void _trackVenueAction(AnalyticsEvent event) {
    if (widget.isPreview) return;
    _analytics.track(
      event,
      AnalyticsProperties(
        entityType: AnalyticsEntityType.restaurant,
        entityId: widget.restaurant.id,
        sourceScreen: AnalyticsVenueDetailScreen.restaurantDetail,
      ),
    );
  }

  // [trackAs] null (the default, e.g. the Michelin link) means "never
  // track this open" — only a caller that explicitly names a
  // destination (the website link today; booking_url once its own
  // action exists) fires venueBookingLinkOpened. Fired only after
  // launchUrl itself returns true (Analytics Contract §15's exact
  // boundary) — canLaunchUrl only confirms capability, not that an
  // attempt was actually made.
  Future<void> _openUrl(String url, {AnalyticsLinkDestination? trackAs}) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched && trackAs != null && !widget.isPreview) {
        _analytics.track(
          AnalyticsEvent.venueBookingLinkOpened,
          AnalyticsProperties(
            entityType: AnalyticsEntityType.restaurant,
            entityId: widget.restaurant.id,
            linkDestination: trackAs,
            sourceScreen: AnalyticsVenueDetailScreen.restaurantDetail,
          ),
        );
      }
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
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) _trackVenueAction(AnalyticsEvent.venuePhoneTapped);
    }
  }

  Future<void> _openPlanVisit() async {
    // Preview: inert — see _openAddVisitSheet's own comment.
    if (widget.isPreview) return;
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
    final worlds50BestUrl = (restaurant.worlds50BestUrl?.isNotEmpty ?? false)
        ? restaurant.worlds50BestUrl!
        : null;
    // Only a stored, well-formed URL — the "not found" research
    // placeholders some rows carry read as no link (see profileUrl).
    final gaultMillauUrl = _gaultMillauAward?.profileUrl;
    // Venue lifecycle (DATA_UPDATE_PROCESS.md §7): Directions and the
    // Michelin link stay available in every state — you still want to
    // know where a closed venue was, and the guide listing is still the
    // historical record. Website survives a temporary closure (that's
    // exactly where someone checks for a reopening date) but not a
    // permanent one; Call is suppressed the moment a venue is closed at
    // all, temporary or permanent — there's nothing to call about.
    final lifecycleState = resolveLifecycleState(
      status: restaurant.status,
      isExpired: restaurant.isExpired,
    );
    final websiteSuppressed =
        lifecycleState == VenueLifecycleState.permanentlyClosed;
    final callSuppressed =
        lifecycleState == VenueLifecycleState.permanentlyClosed ||
        lifecycleState == VenueLifecycleState.temporarilyClosed;
    // Restaurant Enrichment Step 1D. buildTelUri returns null for an
    // empty/unparseable phone (no digits at all), which doubles as the
    // "hide the Call action" signal — matching hasMichelinLink/
    // hasWebsiteLink's own "presence of a usable value" pattern, never a
    // separately-tracked boolean that could drift from the URI itself.
    final telUri = (restaurant.phone ?? '').isEmpty || callSuppressed
        ? null
        : buildTelUri(restaurant.phone!);
    // Wired to venue_about_current (via _loadAboutText/_aboutText) — an
    // approved submission, or null/hidden when nothing has been approved
    // yet. See _aboutText's own doc comment.
    final aboutText = _aboutText;

    final guideLinks = VenueGuideLinks(
      onOpenMichelin: hasMichelinLink ? () => _openUrl(michelinUrl) : null,
      onOpenWorlds50Best: worlds50BestUrl == null
          ? null
          : () => _openUrl(worlds50BestUrl),
      onOpenGaultMillau: gaultMillauUrl == null
          ? null
          : () => _openUrl(gaultMillauUrl),
    );

    final scaffold = Scaffold(
      backgroundColor: AppColors.ivory,
      body: CustomScrollView(
        slivers: [
          RestaurantHero(
            restaurant: restaurant,
            hasHotelBadge: hasHotelBadge,
            photos: _photos,
            isPreview: widget.isPreview,
            isWishlisted: _isWishlisted,
            wishlistSaving: _wishlistSaving,
            onTapWishlist: _toggleWishlist,
            isFollowing: _isFollowing,
            followBusy: _followBusy,
            onTapFollow: _toggleFollow,
            gaultMillauAward: _gaultMillauAward,
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
                  VenueLifecycleBanner(
                    state: lifecycleState,
                    statusNote: restaurant.statusNote,
                  ),

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
                  // The venue's own guide pages, as quiet text links with
                  // the awards rather than in the practical action row.
                  if (guideLinks.hasAny) ...[
                    if (!_hasAwardHistory) const SizedBox(height: CsSpacing.sm),
                    guideLinks,
                  ],
                  // Friends who've been — faces only, no scores. Personal
                  // state, so left out of the manager's preview.
                  if (!widget.isPreview && isAuthenticated)
                    VenueFriendsBeenRow(
                      entityType: 'restaurant',
                      entityId: restaurant.id,
                    ),

                  const SectionDivider(),

                  // ── Venue utilities — Directions/Website/Call only.
                  // Wishlist lives solely in the hero; there is no second
                  // Wishlist control here (UI Consistency Step 1E).
                  VenueUtilityActions(
                    onOpenMaps: _openMaps,
                    onOpenWebsite: (hasWebsiteLink && !websiteSuppressed)
                        ? () => _openUrl(
                            websiteUrl,
                            trackAs: AnalyticsLinkDestination.website,
                          )
                        : null,
                    onCall: telUri == null ? null : () => _openCall(telUri),
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

                  if (_team.isNotEmpty) ...[
                    const SectionDivider(),
                    VenueTeamSection(members: _team, venueType: 'restaurant'),
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
    return widget.isPreview
        ? OwnerPreviewMarker(
            subtitle: widget.previewIsStale
                ? 'Showing your last saved details'
                : null,
            child: scaffold,
          )
        : scaffold;
  }
}
