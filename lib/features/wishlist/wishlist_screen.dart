import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/cs_image_placeholder.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/passport_venue.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import '../trips/planned_trips_screen.dart';
import 'widgets/wishlist_venue_row.dart';
import 'wishlist_view_model.dart';

/// My Wishlist: restaurants and hotels the user wants to go to someday —
/// distinct from Planned Visits/Stays ("I intend to go around this date").
/// Restaurants/Hotels only (no All category — see [defaultWishlistVenueType]
/// for the default-selection rule), via the same [PassportVenue]
/// abstraction Explore/Passport use.
///
/// UI Consistency Step 1: deep-green masthead (title, supporting line,
/// Restaurants/Hotels selector) over an ivory body — the same editorial
/// composition established for Guides' catalogues and Friends (Green Token
/// Consistency Migration: AppColors.deepGreen, the canonical primary brand
/// dark surface — not forestGreen). Unlike those screens this one is a
/// permanent bottom-navigation tab (see app.dart's `_MainNavigation`), not
/// a pushed route: it owns no [Scaffold] of its own (the tab shell already
/// provides one) and needs no back affordance, so the safe-area
/// architecture is the same deep-green-through-the-status-bar / scoped
/// [AnnotatedRegion] / explicit
/// ivory-body pattern, just without the [Scaffold] wrapper other pushed
/// screens use.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late final WishlistRepository _repo = WishlistRepository(
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
        if (snap.connectionState == ConnectionState.done && !snap.hasError) {
          _applyDefaultVenueType(allItems);
        }
        final items = allItems.where(_matchesFilter).toList();
        final loading = snap.connectionState == ConnectionState.waiting;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          // Wishlist is a bottom-navigation tab body, not a pushed route —
          // unlike GuideCatalogueLayout/FriendProfileScreen/FriendsScreen,
          // it has no Scaffold(backgroundColor: deepGreen) of its own to
          // fall back on: _MainNavigation's Scaffold owns that, painted in
          // the legacy AppColors.background. This outer ColoredBox is the
          // substitute — it wraps the header AND the ivory body together
          // so the header's SafeArea(bottom: false) inserts its top-inset
          // padding *inside* an area already painted deep-green, rather
          // than exposing whatever sits behind it. Physical-device review
          // found the previous structure (ColoredBox nested *inside*
          // SafeArea) left that inset unpainted, showing an ivory/white
          // strip behind the iOS status bar — the same root cause already
          // documented and fixed on the screens named above.
          //
          // Green Token Consistency Migration: AppColors.deepGreen, not
          // forestGreen — the canonical primary brand dark surface.
          child: ColoredBox(
            color: AppColors.deepGreen,
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      CsSpacing.lg,
                      CsSpacing.pageHorizontal,
                      CsSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wishlist',
                          style: CsTypography.screenTitle.copyWith(
                            color: AppColors.ivory,
                          ),
                        ),
                        const SizedBox(height: CsSpacing.xs),
                        Text(
                          "Places you're saving for later.",
                          style: CsTypography.body.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                        const SizedBox(height: CsSpacing.lg),
                        Row(
                          children: [
                            for (var i = 0; i < _types.length; i++) ...[
                              if (i > 0) const SizedBox(width: CsSpacing.sm),
                              CsFilterChip(
                                label: _types[i].label,
                                selected: _types[i] == _venueType,
                                onTap: () =>
                                    setState(() => _venueType = _types[i]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.ivory,
                    child: SafeArea(
                      top: false,
                      child: RefreshIndicator(
                        color: AppColors.forestGreen,
                        backgroundColor: AppColors.warmWhite,
                        onRefresh: () async => _load(),
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  CsSpacing.pageHorizontal,
                                  CsSpacing.md,
                                  CsSpacing.pageHorizontal,
                                  0,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SubtleTextAction(
                                    label: 'Trips',
                                    onTap: _openPlannedTrips,
                                  ),
                                ),
                              ),
                            ),
                            if (snap.hasError)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _ErrorState(onRetry: _load),
                              )
                            else if (loading)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: _LoadingState(),
                              )
                            else if (items.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _EmptyState(venueType: _venueType),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  CsSpacing.pageHorizontal,
                                  CsSpacing.sm,
                                  CsSpacing.pageHorizontal,
                                  100,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (i > 0) const WishlistRowDivider(),
                                        WishlistVenueRow(
                                          venue: items[i],
                                          onTap: () => _openVenue(items[i]),
                                          onRemove: () => _remove(items[i]),
                                        ),
                                      ],
                                    ),
                                    childCount: items.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      color: AppColors.forestGreen,
      strokeWidth: 1.5,
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.taupe, size: 32),
          const SizedBox(height: CsSpacing.base),
          Text(
            'Could not load your wishlist',
            textAlign: TextAlign.center,
            style: CsTypography.body.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.md),
          TextButton(
            onPressed: onRetry,
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

class _EmptyState extends StatelessWidget {
  final ExploreVenueType venueType;
  const _EmptyState({required this.venueType});

  @override
  Widget build(BuildContext context) {
    final isHotels = venueType == ExploreVenueType.hotels;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CsImagePlaceholder(
              width: 56,
              height: 56,
              borderRadius: BorderRadius.all(Radius.circular(14)),
              logoScale: 0.5,
            ),
            const SizedBox(height: CsSpacing.lg),
            Text(
              isHotels ? 'No hotels saved yet' : 'No restaurants saved yet',
              textAlign: TextAlign.center,
              style: CsTypography.placeTitle.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: CsSpacing.xs),
            Text(
              isHotels
                  ? "Save hotels you'd like to stay at and they'll appear "
                        'here.'
                  : "Save restaurants you'd like to experience and they'll "
                        'appear here.',
              textAlign: TextAlign.center,
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
          ],
        ),
      ),
    );
  }
}
