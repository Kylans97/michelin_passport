import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/country_filter_control.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/cs_search_field.dart';
import '../../core/widgets/star_row.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'guide_view_model.dart';
import 'models/guide_filters.dart';
import 'widgets/guide_catalogue_layout.dart';
import 'widgets/guide_catalogue_states.dart';
import 'widgets/guide_venue_card.dart';

/// Michelin Guide → Restaurants (Step 2B). A calm, filterable catalogue of
/// CURRENTLY Michelin-starred restaurants only — never a restaurant that
/// merely held a star historically (see RestaurantRepository.search()'s
/// `starsOnly`). No Year filter: this answers "which places can I
/// discover now?", not "browse the guide as it stood in 2019" (that's a
/// deliberately separate, not-yet-built question — see the Step 2B brief).
class MichelinRestaurantGuideScreen extends StatefulWidget {
  const MichelinRestaurantGuideScreen({super.key});

  @override
  State<MichelinRestaurantGuideScreen> createState() =>
      _MichelinRestaurantGuideScreenState();
}

class _MichelinRestaurantGuideScreenState
    extends State<MichelinRestaurantGuideScreen> {
  final _searchCtrl = TextEditingController();
  late final _repo = RestaurantRepository(Supabase.instance.client);

  String _query = '';
  Timer? _debounce;
  VenueCountry? _country;
  GuideStarFilter _starFilter = GuideStarFilter.all;

  // Stale-while-revalidating, mirroring ExploreScreen's _searchResults/
  // _searching/_searchError trio exactly: the last successful result set
  // stays on screen while a new one loads, so changing a filter never
  // blanks the list back to nothing.
  List<Restaurant>? _results;
  bool _loading = false;
  bool _error = false;

  late final Future<List<VenueCountry>> _countriesFuture = _repo.getCountries(
    starsOnly: true,
  );

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _country != null ||
      _starFilter != GuideStarFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await _repo.search(
        _query,
        stars: _starFilter.starsParam,
        starsOnly: true,
        countryCode: _country?.code,
      );
      if (!mounted) return;
      setState(() {
        _results = sortGuideRestaurants(results);
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _results == null;
      });
    }
  }

  // The mode/fetch-trigger split mirrors ExploreScreen's _onQueryChanged:
  // the query updates immediately (so the search field itself never lags),
  // but the actual catalogue re-fetch is debounced so fast typing doesn't
  // fire one request per keystroke.
  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _onCountryChanged(VenueCountry? country) {
    setState(() => _country = country);
    _load();
  }

  void _onStarFilterChanged(GuideStarFilter filter) {
    setState(() => _starFilter = filter);
    _load();
  }

  void _open(Restaurant restaurant) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
    ),
  );

  String _locationLabel(Restaurant restaurant) {
    final parts = <String>[
      if (restaurant.cityName.isNotEmpty) restaurant.cityName,
      if (restaurant.countryName.isNotEmpty) restaurant.countryName,
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) => GuideCatalogueLayout(
    source: 'MICHELIN GUIDE',
    title: 'Restaurants',
    subtitle: 'Exceptional restaurants recognised by the Michelin Guide.',
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CsSearchField(
            controller: _searchCtrl,
            hintText: 'Search restaurants, cities & countries',
            onChanged: _onQueryChanged,
          ),
          const SizedBox(height: CsSpacing.sm),
          FutureBuilder<List<VenueCountry>>(
            future: _countriesFuture,
            builder: (context, snap) => Align(
              alignment: Alignment.centerLeft,
              child: CountryFilterControl(
                selected: _country,
                countries: snap.data ?? const [],
                onChanged: _onCountryChanged,
                surface: CsSurface.dark,
              ),
            ),
          ),
          const SizedBox(height: CsSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < GuideStarFilter.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: CsSpacing.sm),
                  CsFilterChip(
                    label: GuideStarFilter.values[i].label,
                    selected: _starFilter == GuideStarFilter.values[i],
                    onTap: () =>
                        _onStarFilterChanged(GuideStarFilter.values[i]),
                  ),
                ],
              ],
            ),
          ),
          if (_results != null) ...[
            const SizedBox(height: CsSpacing.base),
            _ResultCountLine(count: _results!.length, loading: _loading),
          ],
          const SizedBox(height: CsSpacing.sm),
          Expanded(
            child: _error && _results == null
                ? GuideCatalogueErrorState(onRetry: _load)
                : _results == null
                ? const GuideCatalogueLoading()
                : _results!.isEmpty
                ? GuideCatalogueEmptyState(hasActiveFilters: _hasActiveFilters)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: CsSpacing.xxl),
                    itemCount: _results!.length,
                    separatorBuilder: (_, _) => const GuideVenueCardDivider(),
                    itemBuilder: (context, index) {
                      final restaurant = _results![index];
                      return GuideVenueCard(
                        title: restaurant.name,
                        locationLabel: _locationLabel(restaurant),
                        distinction: StarRow(
                          count: restaurant.michelinStars ?? 0,
                          size: 12,
                        ),
                        onTap: () => _open(restaurant),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _ResultCountLine extends StatelessWidget {
  final int count;
  final bool loading;

  const _ResultCountLine({required this.count, required this.loading});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        count == 1 ? '1 place' : '$count places',
        style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
      ),
      if (loading) ...[
        const SizedBox(width: CsSpacing.sm),
        const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            color: AppColors.secondaryOnDark,
            strokeWidth: 1.2,
          ),
        ),
      ],
    ],
  );
}
