import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/restaurant.dart';
import '../../models/visit.dart';
import '../visits/widgets/add_visit_sheet.dart';
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

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  bool _loadingPersonalState = true;
  List<Visit> _visits = [];
  bool _isWishlisted = false;
  bool _wishlistSaving = false;

  bool get _isVisited => _visits.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadPersonalState();
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
    final saved = await showAddVisitSheet(
      context,
      restaurant: widget.restaurant,
      userId: uid,
      visitedRepository: _visitedRepo,
    );
    if (saved == true && mounted) {
      await _refreshVisits();
      if (!mounted) return;
      _showSnack('Visit saved');
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

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final hasHotelBadge =
        restaurant.isInHotel && (restaurant.hotelName?.isNotEmpty ?? false);
    final michelinUrl = restaurant.michelinUrl;
    final websiteUrl = restaurant.websiteUrl;
    final isAuthenticated = _userId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          RestaurantHero(restaurant: restaurant, hasHotelBadge: hasHotelBadge),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('INFORMATION'),
                  const SizedBox(height: 12),
                  RestaurantInfoCard(
                    restaurant: restaurant,
                    hasHotelBadge: hasHotelBadge,
                  ),
                  const SizedBox(height: 28),

                  const SectionLabel('ACTIONS'),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 28),

                  RestaurantAwardsCard(restaurant: restaurant),

                  const SizedBox(height: 28),
                  const SectionLabel('YOUR VISITS'),
                  const SizedBox(height: 12),
                  RestaurantVisitsCard(
                    isAuthenticated: isAuthenticated,
                    loading: _loadingPersonalState,
                    visits: _visits,
                    restaurant: restaurant,
                    signInMessage: _signInMessage,
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
