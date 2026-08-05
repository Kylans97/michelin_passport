import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/restaurant.dart';
import 'widgets/restaurant_tile.dart';

// Catalogue-read-only Explore: browses public.restaurants_full. No visited,
// wishlist or trophy state yet — that is a later slice.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();

  late final _restaurantRepo = RestaurantRepository(Supabase.instance.client);

  int _starFilter = 0;
  String? _countryFilter;
  String _query = '';

  late Future<List<Restaurant>> _restaurantFuture;
  late Future<List<RestaurantCountry>> _countriesFuture;

  @override
  void initState() {
    super.initState();
    _countriesFuture = _restaurantRepo.getCountries();
    _restaurantFuture = _restaurantRepo.search('');
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
                    child: RestaurantTile(restaurant: results[i]),
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
              hintText: 'Search restaurants, cities, countries…',
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
                  // Includes unstarred World's 50 Best restaurants, so
                  // "All stars" would overpromise — this filter is just "all".
                  label: 'All',
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
