import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/widgets/country_filter_control.dart';
import '../../core/widgets/cs_search_field.dart';
import '../../data/repositories/restaurant_worlds_50_best_repository.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'fifty_best_view_model.dart';
import 'widgets/guide_catalogue_layout.dart';
import 'widgets/guide_catalogue_states.dart';
import 'widgets/guide_rank_mark.dart';
import 'widgets/guide_venue_card.dart';
import 'widgets/guide_year_selector.dart';

/// The World's 50 Best → Restaurants (Step 2C). Unlike Michelin, this
/// catalogue is fundamentally about rank/year, not a current-recognition
/// award tier — a premium ranking index for one selected year at a time,
/// never a merged "all years" list (a restaurant ranked in both 2024 and
/// 2025 would otherwise appear twice in one flat list, which is confusing,
/// not useful — see the Step 2C brief's explicit reasoning for why a
/// nullable "All time" model, like Passport/My Rankings use, doesn't fit
/// here). Hall of Fame rows are excluded from the ranked list entirely
/// (they carry no numeric rank — see
/// RestaurantWorlds50BestRepository.getRanking).
class FiftyBestRestaurantGuideScreen extends StatefulWidget {
  const FiftyBestRestaurantGuideScreen({super.key});

  @override
  State<FiftyBestRestaurantGuideScreen> createState() =>
      _FiftyBestRestaurantGuideScreenState();
}

class _FiftyBestRestaurantGuideScreenState
    extends State<FiftyBestRestaurantGuideScreen> {
  final _searchCtrl = TextEditingController();
  late final _repo = RestaurantWorlds50BestRepository(Supabase.instance.client);

  String _query = '';
  Timer? _debounce;
  VenueCountry? _country;
  List<VenueCountry> _countryOptions = const [];

  // Null until the initial years fetch resolves — see build()/_init(). Once
  // set, [_selectedYear] is always the head of this list (the latest
  // available year) unless the user picks a different one.
  List<int>? _years;
  int? _selectedYear;

  List<RestaurantWorlds50BestRankingEntry>? _results;
  bool _loading = true;
  bool _error = false;

  bool get _hasActiveFilters => _query.trim().isNotEmpty || _country != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final years = await _repo.getAvailableYears();
      if (!mounted) return;
      if (years.isEmpty) {
        // Genuinely no ranking data at all — distinct from a search/filter
        // returning no matches, see GuideCatalogueEmptyState.
        setState(() {
          _years = years;
          _loading = false;
        });
        return;
      }
      final year = years.first;
      List<VenueCountry> countries;
      try {
        countries = await _repo.getCountries(year);
      } catch (_) {
        countries = const [];
      }
      if (!mounted) return;
      setState(() {
        _years = years;
        _selectedYear = year;
        _countryOptions = countries;
      });
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _load() async {
    final year = _selectedYear;
    if (year == null) return;
    setState(() => _loading = true);
    try {
      final results = await _repo.getRanking(
        year: year,
        query: _query,
        countryCode: _country?.code,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
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

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _onCountryChanged(VenueCountry? country) {
    setState(() => _country = country);
    _load();
  }

  // Query is preserved unconditionally (text search isn't year-scoped, so
  // it's always still meaningful). Country is preserved only if it's still
  // among the new year's options — see preserveCountrySelection — so
  // switching from a year where "Peru" has entries to one where it
  // doesn't can't silently leave the list looking broken.
  Future<void> _onYearChanged(int year) async {
    setState(() => _selectedYear = year);
    List<VenueCountry> newCountries;
    try {
      newCountries = await _repo.getCountries(year);
    } catch (_) {
      newCountries = _countryOptions;
    }
    if (!mounted) return;
    setState(() {
      _countryOptions = newCountries;
      _country = preserveCountrySelection(_country, newCountries);
    });
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
    source: "THE WORLD'S 50 BEST",
    title: 'Restaurants',
    subtitle: 'The restaurants shaping global dining.',
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: _years == null
          ? (_error
                ? GuideCatalogueErrorState(onRetry: _init)
                : const GuideCatalogueLoading())
          : _content(),
    ),
  );

  Widget _content() {
    final years = _years!;
    final year = _selectedYear;
    if (year == null) {
      // years fetched successfully but came back empty — a genuinely
      // data-free catalogue, not a filtered miss.
      return const GuideCatalogueEmptyState(hasActiveFilters: false);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CsSearchField(
          controller: _searchCtrl,
          hintText: 'Search restaurants, cities & countries',
          onChanged: _onQueryChanged,
        ),
        const SizedBox(height: CsSpacing.sm),
        Row(
          children: [
            GuideYearSelector(
              years: years,
              selectedYear: year,
              onSelect: _onYearChanged,
            ),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: CountryFilterControl(
                  selected: _country,
                  countries: _countryOptions,
                  onChanged: _onCountryChanged,
                  surface: CsSurface.dark,
                ),
              ),
            ),
          ],
        ),
        if (_results != null) ...[
          const SizedBox(height: CsSpacing.base),
          GuideResultCountLine(count: _results!.length, loading: _loading),
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
                    final entry = _results![index];
                    return GuideVenueCard(
                      title: entry.restaurant.name,
                      locationLabel: _locationLabel(entry.restaurant),
                      leading: GuideRankMark(rank: entry.rank!),
                      onTap: () => _open(entry.restaurant),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
