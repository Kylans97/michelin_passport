import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/country_filter_control.dart';
import '../../core/widgets/cs_search_field.dart';
import '../../data/repositories/hotel_worlds_50_best_repository.dart';
import '../../models/hotel.dart';
import '../../models/venue_country.dart';
import '../hotels/hotel_detail_screen.dart';
import 'fifty_best_view_model.dart';
import 'widgets/guide_catalogue_layout.dart';
import 'widgets/guide_catalogue_states.dart';
import 'widgets/guide_venue_card.dart';
import 'widgets/guide_year_selector.dart';

/// The World's 50 Best → Hotels (Step 2C). The mirror of
/// [FiftyBestRestaurantGuideScreen] for hotels — one selected year at a
/// time, ranked ascending. Unlike restaurants, there is no Hall of Fame
/// concept for hotels (see HotelWorlds50BestListType) and 2025 already
/// reaches #1-#100 in one continuous list (no Top 50/Extended split shown
/// to the reader — see HotelWorlds50BestRepository.getRanking's
/// [listType]: null default).
class FiftyBestHotelGuideScreen extends StatefulWidget {
  const FiftyBestHotelGuideScreen({super.key});

  @override
  State<FiftyBestHotelGuideScreen> createState() =>
      _FiftyBestHotelGuideScreenState();
}

class _FiftyBestHotelGuideScreenState extends State<FiftyBestHotelGuideScreen> {
  final _searchCtrl = TextEditingController();
  late final _repo = HotelWorlds50BestRepository(Supabase.instance.client);

  String _query = '';
  Timer? _debounce;
  VenueCountry? _country;
  List<VenueCountry> _countryOptions = const [];

  List<int>? _years;
  int? _selectedYear;

  List<HotelWorlds50BestRankingEntry>? _results;
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

  void _open(Hotel hotel) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
  );

  @override
  Widget build(BuildContext context) => GuideCatalogueLayout(
    source: "THE WORLD'S 50 BEST",
    title: 'Hotels',
    subtitle: "The world's most remarkable stays.",
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
      return const GuideCatalogueEmptyState(hasActiveFilters: false);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CsSearchField(
          controller: _searchCtrl,
          hintText: 'Search hotels, cities & countries',
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
                  surface: CsSurface.light,
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
                      title: entry.hotel.name,
                      metadataLine: Text(
                        '#${entry.rank} · ${entry.year}',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.forestGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      cityName: entry.hotel.cityName,
                      countryName: entry.hotel.countryName,
                      flagEmoji: entry.hotel.flagEmoji,
                      recognitionSemanticLabel:
                          'ranked number ${entry.rank}, ${entry.year}',
                      onTap: () => _open(entry.hotel),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
