import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/cs_primary_button.dart' show CsSecondaryButton;
import '../../core/widgets/cs_section_title.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/passport_venue.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;
import '../passport/widgets/passport_empty_state.dart';
import 'widgets/wishlist_venue_cards.dart';
import 'wishlist_view_model.dart';

/// My Wishlist: restaurants and hotels the user wants to go to someday —
/// distinct from Planned Visits/Stays ("I intend to go around this date").
/// Restaurants/Hotels only (no All category — see [defaultWishlistVenueType]
/// for the default-selection rule), via the same [PassportVenue]
/// abstraction Explore/Passport use.
///
/// Passport Unified Experience V1: re-homed from a pushed, independently
/// scaffolded screen into one of [PassportScreen]'s four local
/// subsections — no back button, no separate title (the shared Passport
/// header above this body covers that), reached via the persistent
/// Passport/Wishlist/Ranking/Trips tab bar rather than
/// `Navigator.push`/pop. The previous "Trips" quick-link at the top of the
/// list was removed then — Trips is a sibling tab one tap away on the
/// shared bar, so the in-body shortcut was redundant; it has not been
/// reintroduced.
///
/// PASSPORT — WISHLIST UI POLISH V1: the content itself now follows the
/// same deep-green-environment/ivory-object grammar Passport's own
/// collection and Ranking's cards were finalized on, replacing the
/// previous large ivory content sheet with compact list rows. Saved
/// venues render as [WishlistRestaurantCard]/[WishlistHotelCard] — ivory
/// cards in the same family as Passport's collection cards — floating
/// individually on the persistent deep-green canvas, with visible
/// breathing room between them rather than one continuous surface.
/// Removing a card updates the in-memory list immediately (no full
/// reload/loading flash) and reverts if the server call fails.
class WishlistBody extends StatefulWidget {
  const WishlistBody({super.key});

  @override
  State<WishlistBody> createState() => _WishlistBodyState();
}

class _WishlistBodyState extends State<WishlistBody> {
  late final WishlistRepository _repo = WishlistRepository(
    Supabase.instance.client,
  );

  // Wishlist has no "All" category (unlike Explore/Passport) — just
  // Restaurants/Hotels.
  static const _types = [ExploreVenueType.restaurants, ExploreVenueType.hotels];
  ExploreVenueType _venueType = ExploreVenueType.restaurants;
  bool _defaultApplied = false;

  List<PassportVenue>? _venues; // null until the first load completes.
  bool _loading = true; // true only for the very first, blocking load.
  bool _loadError = false;
  bool _refreshing = false; // guards overlapping refresh calls.

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final venues = await _repo.loadWishlistVenues(_userId);
      if (!mounted) return;
      setState(() {
        _venues = venues;
        _loading = false;
        _loadError = false;
      });
      _applyDefaultVenueType(venues);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _venues == null;
      });
    } finally {
      _refreshing = false;
    }
  }

  void _applyDefaultVenueType(List<PassportVenue> items) {
    if (_defaultApplied) return;
    _defaultApplied = true;
    final defaultType = defaultWishlistVenueType(items);
    if (defaultType != _venueType && mounted) {
      setState(() => _venueType = defaultType);
    }
  }

  // Removes [venue] from the visible list immediately — no full reload, no
  // loading flash — and persists via the same WishlistRepository every
  // other wishlist entry point in the app already uses. Reverts (re-inserts
  // at its original position) if the server call fails, mirroring
  // PassportCollectionBody's own optimistic-toggle-then-revert pattern.
  Future<void> _remove(PassportVenue venue) async {
    final venues = _venues;
    if (venues == null) return;
    final index = venues.indexOf(venue);
    if (index == -1) return;
    setState(() => venues.removeAt(index));
    try {
      switch (venue) {
        case RestaurantVenue(:final restaurant):
          await _repo.remove(userId: _userId, restaurantId: restaurant.id);
        case HotelVenue(:final hotel):
          await _repo.removeHotel(userId: _userId, hotelId: hotel.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => venues.insert(index, venue));
    }
  }

  bool _matchesFilter(PassportVenue venue) => switch (_venueType) {
    ExploreVenueType.all => true,
    ExploreVenueType.restaurants => venue is RestaurantVenue,
    ExploreVenueType.hotels => venue is HotelVenue,
  };

  @override
  Widget build(BuildContext context) {
    final allVenues = _venues ?? [];
    final items = allVenues.where(_matchesFilter).toList();
    final isHotels = _venueType == ExploreVenueType.hotels;

    return ColoredBox(
      color: AppColors.deepGreen,
      child: RefreshIndicator(
        color: AppColors.textOnDark,
        backgroundColor: AppColors.forestGreen,
        onRefresh: _load,
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
                child: Row(
                  children: [
                    for (var i = 0; i < _types.length; i++) ...[
                      if (i > 0) const SizedBox(width: CsSpacing.sm),
                      CsFilterChip(
                        label: _types[i].label,
                        selected: _types[i] == _venueType,
                        onTap: () => setState(() => _venueType = _types[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.xl,
                  CsSpacing.pageHorizontal,
                  CsSpacing.md,
                ),
                child: const CsSectionTitle(
                  'YOUR WISHLIST',
                  color: AppColors.textOnDark,
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textOnDark,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else if (_loadError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(onRetry: _load),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PassportEmptyState(
                  message: isHotels
                      ? 'No hotels saved yet.'
                      : 'No restaurants saved yet.',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  // Per-item padding (not a shared SliverPadding) — the
                  // same pattern PassportCollectionBody's own collection
                  // list uses: visible deep-green breathing room between
                  // each floating ivory card, with the last card getting
                  // extra bottom clearance for the bottom nav bar rather
                  // than sitting flush behind it.
                  (context, i) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      0,
                      CsSpacing.pageHorizontal,
                      i == items.length - 1 ? 100 : CsSpacing.md,
                    ),
                    child: switch (items[i]) {
                      RestaurantVenue(:final restaurant) =>
                        WishlistRestaurantCard(
                          restaurant: restaurant,
                          onRemove: () => _remove(items[i]),
                        ),
                      HotelVenue(:final hotel) => WishlistHotelCard(
                        hotel: hotel,
                        onRemove: () => _remove(items[i]),
                      ),
                    },
                  ),
                  childCount: items.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
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
          const Icon(
            Icons.wifi_off_rounded,
            color: AppColors.secondaryOnDark,
            size: 32,
          ),
          const SizedBox(height: CsSpacing.base),
          Text(
            'Could not load your wishlist',
            textAlign: TextAlign.center,
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.md),
          SizedBox(
            width: 160,
            child: CsSecondaryButton(label: 'Retry', onTap: onRetry, height: 44),
          ),
        ],
      ),
    ),
  );
}
