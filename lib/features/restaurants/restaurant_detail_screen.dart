import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/circular_score_badge.dart';
import '../../core/widgets/personal_photos_preview.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/award_history_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/passport_venue.dart';
import '../../models/restaurant.dart';
import '../../models/save_outcome.dart';
import '../../models/visit.dart';
import '../hotels/hotel_detail_screen.dart';
import '../planning/widgets/plan_venue_sheet.dart';
import '../visits/widgets/add_visit_sheet.dart';
import 'award_history_screen.dart';
import 'widgets/award_history_action.dart';
import 'widgets/detail_section.dart';
import 'widgets/restaurant_actions.dart';
import 'widgets/restaurant_awards_card.dart';
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
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  late final _photoRepo = PhotoRepository(Supabase.instance.client);
  late final _awardHistoryRepo = AwardHistoryRepository(
    Supabase.instance.client,
  );
  late final _plannedTripsRepo = PlannedTripsRepository(
    Supabase.instance.client,
  );

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  bool _loadingPersonalState = true;
  List<Visit> _visits = [];
  bool _isWishlisted = false;
  bool _wishlistSaving = false;
  bool _loadingHotel = false;

  // Catalogue data, not personal state — loaded regardless of sign-in.
  // Starts false (action hidden) rather than showing then hiding it, since
  // most restaurants resolve this within a single indexed round trip.
  bool _hasAwardHistory = false;

  bool get _isVisited => _visits.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadPersonalState();
    _checkAwardHistory();
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
      final visits = await visitsFuture;
      final wishlisted = await wishlistedFuture;
      if (!mounted) return;
      setState(() {
        _visits = visits;
        _isWishlisted = wishlisted;
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
          style: GoogleFonts.inter(
            color: isError ? AppColors.textPrimary : Colors.black,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.gold,
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          RestaurantHero(
            restaurant: restaurant,
            hasHotelBadge: hasHotelBadge,
            isWishlisted: _isWishlisted,
            wishlistSaving: _wishlistSaving,
            onTapWishlist: _toggleWishlist,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The hero is the single primary identity area — the
                  // venue name lives there only, never repeated here. Just
                  // city/country as light supporting context.
                  Text(
                    '${restaurant.flagEmoji}  ${restaurant.cityName}, '
                    '${restaurant.countryName}',
                    style: AppTypography.metadata,
                  ),
                  const SizedBox(height: 36),

                  // Current Michelin / World's 50 Best status.
                  RestaurantAwardsCard(restaurant: restaurant),
                  if (_hasAwardHistory)
                    AwardHistoryAction(onTap: _openAwardHistory),
                  const SizedBox(height: 36),

                  RestaurantActions(
                    isAuthenticated: isAuthenticated,
                    loadingPersonalState: _loadingPersonalState,
                    isVisited: _isVisited,
                    isWishlisted: _isWishlisted,
                    wishlistSaving: _wishlistSaving,
                    onTapVisited: _openAddVisitSheet,
                    onTapWishlist: _toggleWishlist,
                    onOpenMaps: _openMaps,
                    onOpenMichelin:
                        (michelinUrl != null && michelinUrl.isNotEmpty)
                        ? () => _openUrl(michelinUrl)
                        : null,
                    onOpenWebsite: (websiteUrl != null && websiteUrl.isNotEmpty)
                        ? () => _openUrl(websiteUrl)
                        : null,
                  ),
                  SubtleTextAction(label: 'Plan visit', onTap: _openPlanVisit),
                  const SizedBox(height: 28),

                  if (isAuthenticated && latestVisit != null) ...[
                    const SectionLabel('YOUR SCORE'),
                    const SizedBox(height: 14),
                    DetailCard(
                      child: Row(
                        children: [
                          CircularScoreBadge(
                            score: latestVisit.rating,
                            caption: 'Overall',
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Latest visit',
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(latestVisit.visitedOn),
                                  style: AppTypography.metadata,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],

                  const SectionLabel('YOUR VISITS'),
                  const SizedBox(height: 12),
                  RestaurantVisitsCard(
                    isAuthenticated: isAuthenticated,
                    loading: _loadingPersonalState,
                    visits: _visits,
                    restaurant: restaurant,
                    signInMessage: _signInMessage,
                    onReturn: _refreshVisits,
                  ),

                  if (latestVisit != null) ...[
                    const SizedBox(height: 36),
                    const SectionLabel('PERSONAL PHOTOS'),
                    const SizedBox(height: 12),
                    PersonalPhotosPreview(latestVisitId: latestVisit.id),
                  ],

                  const SizedBox(height: 36),
                  const SectionLabel('INFORMATION'),
                  const SizedBox(height: 12),
                  RestaurantInfoCard(
                    restaurant: restaurant,
                    hasHotelBadge: hasHotelBadge,
                    onTapHotel: canOpenHotel ? _openHotel : null,
                    hotelLoading: _loadingHotel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
