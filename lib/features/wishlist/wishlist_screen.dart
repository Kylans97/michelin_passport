import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/passport_venue.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;
import '../explore/widgets/venue_type_selector.dart';
import '../hotels/hotel_detail_screen.dart';
import '../planning/widgets/plan_venue_sheet.dart';
import '../restaurants/restaurant_detail_screen.dart';
import '../trips/planned_trips_screen.dart';
import 'widgets/wishlist_card.dart';
import 'wishlist_view_model.dart';

/// My Wishlist: restaurants and hotels the user wants to go to someday —
/// distinct from Planned Visits/Stays ("I intend to go around this date").
/// Restaurants/Hotels only (no All category — see [defaultWishlistVenueType]
/// for the default-selection rule), via the same [PassportVenue]
/// abstraction and [VenueTypeSelector] styling Explore/Passport use.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late final WishlistRepository _repo = WishlistRepository(
    Supabase.instance.client,
  );
  late final PlannedTripsRepository _plannedTripsRepo = PlannedTripsRepository(
    Supabase.instance.client,
  );

  // Wishlist has no "All" category (unlike Explore/Passport) — just
  // Restaurants/Hotels. Starts on restaurants; _load() below switches this
  // to hotels once data first arrives IF the user's existing wishlist is
  // hotels-only, so the default view is never empty-by-construction for
  // someone who has only ever wishlisted hotels.
  static const _types = [ExploreVenueType.restaurants, ExploreVenueType.hotels];
  ExploreVenueType _venueType = ExploreVenueType.restaurants;
  bool _defaultApplied = false;

  late Future<List<PassportVenue>> _future;

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _future = _repo.loadWishlistVenues(_userId);
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _defaultApplied = false;
      _future = _repo.loadWishlistVenues(_userId);
    });
  }

  void _applyDefaultVenueType(List<PassportVenue> items) {
    if (_defaultApplied) return;
    _defaultApplied = true;
    final defaultType = defaultWishlistVenueType(items);
    if (defaultType != _venueType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _venueType = defaultType);
      });
    }
  }

  Future<void> _remove(PassportVenue venue) async {
    switch (venue) {
      case RestaurantVenue(:final restaurant):
        await _repo.remove(userId: _userId, restaurantId: restaurant.id);
      case HotelVenue(:final hotel):
        await _repo.removeHotel(userId: _userId, hotelId: hotel.id);
    }
    _load();
  }

  void _openVenue(PassportVenue venue) {
    switch (venue) {
      case RestaurantVenue(:final restaurant):
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        );
      case HotelVenue(:final hotel):
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
        );
    }
  }

  Future<void> _planVenue(PassportVenue venue) async {
    final uid = _userId;
    if (uid.isEmpty) return;
    final saved = await showPlanVenueSheet(
      context,
      venue: venue,
      userId: uid,
      plannedTripsRepository: _plannedTripsRepo,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            venue is HotelVenue ? 'Stay planned' : 'Visit planned',
            style: GoogleFonts.inter(color: Colors.black),
          ),
          backgroundColor: AppColors.gold,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openPlannedTrips() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlannedTripsScreen()),
    );
  }

  bool _matchesFilter(PassportVenue venue) => switch (_venueType) {
    ExploreVenueType.all => true,
    ExploreVenueType.restaurants => venue is RestaurantVenue,
    ExploreVenueType.hotels => venue is HotelVenue,
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PassportVenue>>(
      future: _future,
      builder: (context, snap) {
        final allItems = snap.data ?? [];
        if (snap.connectionState == ConnectionState.done) {
          _applyDefaultVenueType(allItems);
        }
        final items = allItems.where(_matchesFilter).toList();

        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.card,
          onRefresh: () async => _load(),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Wishlist'),
                pinned: true,
                backgroundColor: AppColors.background,
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.card_travel_rounded,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'My Planned Trips',
                    onPressed: _openPlannedTrips,
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: VenueTypeSelector(
                    types: _types,
                    selected: _venueType,
                    onSelect: (v) => setState(() => _venueType = v),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Text(
                        'Dream Destinations',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 10),
                      if (snap.connectionState == ConnectionState.waiting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldMuted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.goldBorder40,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${items.length}',
                            style: GoogleFonts.inter(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (snap.hasError)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Could not load wishlist',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else if (snap.connectionState == ConnectionState.waiting)
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_border_rounded,
                          color: AppColors.textSecondary,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allItems.isEmpty
                              ? 'Your wishlist is empty'
                              : 'Nothing here yet',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allItems.isEmpty
                              ? 'Tap ♥ on any restaurant or hotel to save it here'
                              : 'Try a different filter',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        i == items.length - 1 ? 100 : 12,
                      ),
                      child: WishlistCard(
                        venue: items[i],
                        onTap: () => _openVenue(items[i]),
                        onPlan: () => _planVenue(items[i]),
                        onRemove: () => _remove(items[i]),
                      ),
                    ),
                    childCount: items.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
