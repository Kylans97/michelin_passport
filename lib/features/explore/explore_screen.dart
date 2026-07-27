import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/rating_dialog.dart';
import '../../core/widgets/trophy_popup.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../data/repositories/trophy_repository.dart';
import '../../models/restaurant.dart';
import 'widgets/restaurant_tile.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();

  late final _restaurantRepo = RestaurantRepository(Supabase.instance.client);
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _wishlistRepo = WishlistRepository(Supabase.instance.client);
  late final _trophyRepo = TrophyRepository(Supabase.instance.client);

  int _starFilter = 0;
  String? _countryFilter;
  String _query = '';

  late Future<List<Restaurant>> _restaurantFuture;
  late Future<List<RestaurantCountry>> _countriesFuture;

  Set<String> _visitedIds = {};
  Set<String> _wishlistIds = {};

  @override
  void initState() {
    super.initState();
    _countriesFuture = _restaurantRepo.getCountries();
    _restaurantFuture = _restaurantRepo.search('');
    _loadUserSets();
  }

  void _load() {
    setState(() {
      _restaurantFuture = _restaurantRepo.search(
        _query,
        stars: _starFilter == 0 ? null : _starFilter,
        countryCode: _countryFilter,
      );
    });
  }

  Future<void> _loadUserSets() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final visited = await _visitedRepo.getVisited(uid);
    final wishlist = await _wishlistRepo.getWishlist(uid);
    if (mounted) {
      setState(() {
        _visitedIds = visited.map((r) => r.id).toSet();
        _wishlistIds = wishlist.map((r) => r.id).toSet();
      });
    }
  }

  Future<void> _toggleVisited(Restaurant r) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (_visitedIds.contains(r.id)) {
      await _visitedRepo.removeVisit(userId: uid, restaurantId: r.id);
      if (mounted) setState(() => _visitedIds.remove(r.id));
    } else {
      // Show rating/log dialog before saving the visit.
      if (!mounted) return;
      final result = await showRatingDialog(context, r.name);
      if (!mounted) return;
      // If user dismissed the sheet (null), still log the visit without a rating.
      await _visitedRepo.addVisit(
        userId: uid,
        restaurantId: r.id,
        personalRating: result?.rating,
        notes: result?.notes,
      );
      if (mounted) setState(() => _visitedIds.add(r.id));

      // Check and award trophies.
      final allVisited = await _visitedRepo.getVisitedWithRatings(uid);
      if (!mounted) return;
      final earned = await _trophyRepo.checkAndAward(
        userId: uid,
        justVisited: r,
        personalRating: result?.rating,
        allVisited: allVisited,
      );
      if (earned.isNotEmpty && mounted) {
        await showTrophyPopups(context, earned);
      }
    }
  }

  Future<void> _toggleWishlist(Restaurant r) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (_wishlistIds.contains(r.id)) {
      await _wishlistRepo.remove(userId: uid, restaurantId: r.id);
      setState(() => _wishlistIds.remove(r.id));
    } else {
      await _wishlistRepo.add(userId: uid, restaurantId: r.id);
      setState(() => _wishlistIds.add(r.id));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _restaurantFuture,
      builder: (context, snap) {
        final results = snap.data ?? [];

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Explore'),
              pinned: true,
              backgroundColor: AppColors.background,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(152),
                child: _FilterBar(
                  searchCtrl: _searchCtrl,
                  starFilter: _starFilter,
                  countryFilter: _countryFilter,
                  countriesFuture: _countriesFuture,
                  onQueryChanged: (v) {
                    _query = v;
                    _load();
                  },
                  onStarChanged: (v) {
                    setState(() => _starFilter = v);
                    _load();
                  },
                  onCountryChanged: (v) {
                    setState(() => _countryFilter = v);
                    _load();
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: snap.connectionState == ConnectionState.waiting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 1.5,
                        ),
                      )
                    : Text(
                        '${results.length} restaurant${results.length == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),

            if (snap.hasError)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: AppColors.textSecondary,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load restaurants',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: Text(
                          'Retry',
                          style: GoogleFonts.inter(color: AppColors.gold),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (results.isEmpty &&
                snap.connectionState != ConnectionState.waiting)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        color: AppColors.textSecondary,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No restaurants found',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
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
                    padding: EdgeInsets.only(
                      bottom: i == results.length - 1 ? 88 : 0,
                    ),
                    child: RestaurantTile(
                      restaurant: results[i],
                      isVisited: _visitedIds.contains(results[i].id),
                      isWishlisted: _wishlistIds.contains(results[i].id),
                      onToggleVisited: () => _toggleVisited(results[i]),
                      onToggleWishlist: () => _toggleWishlist(results[i]),
                    ),
                  ),
                  childCount: results.length,
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final int starFilter;
  final String? countryFilter;
  final Future<List<RestaurantCountry>> countriesFuture;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onStarChanged;
  final ValueChanged<String?> onCountryChanged;

  const _FilterBar({
    required this.searchCtrl,
    required this.starFilter,
    required this.countryFilter,
    required this.countriesFuture,
    required this.onQueryChanged,
    required this.onStarChanged,
    required this.onCountryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchCtrl,
            onChanged: onQueryChanged,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              hintText: 'Search restaurants, cities, cuisines…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<RestaurantCountry>>(
            future: countriesFuture,
            builder: (context, snap) {
              final countries = snap.data ?? [];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip(
                      label: 'All countries',
                      selected: countryFilter == null,
                      onTap: () => onCountryChanged(null),
                    ),
                    ...countries.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _Chip(
                          label: '${c.flag}  ${c.name}',
                          selected: countryFilter == c.code,
                          onTap: () => onCountryChanged(c.code),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'All stars',
                  selected: starFilter == 0,
                  onTap: () => onStarChanged(0),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: '★',
                  selected: starFilter == 1,
                  onTap: () => onStarChanged(1),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: '★★',
                  selected: starFilter == 2,
                  onTap: () => onStarChanged(2),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: '★★★',
                  selected: starFilter == 3,
                  onTap: () => onStarChanged(3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.goldMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.goldBorder60 : AppColors.cardBorder,
          width: selected ? 1.0 : 0.5,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: selected ? AppColors.gold : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}
