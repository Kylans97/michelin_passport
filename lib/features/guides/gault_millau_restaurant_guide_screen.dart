import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/country_filter_control.dart';
import '../../core/widgets/cs_search_field.dart';
import '../../data/repositories/restaurant_gault_millau_repository.dart';
import '../../models/venue_country.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'widgets/guide_catalogue_layout.dart';
import 'widgets/guide_catalogue_states.dart';
import 'widgets/guide_gault_millau_mark.dart';
import 'widgets/guide_venue_card.dart';

/// Gault&Millau → Restaurants (Step 2D), the third Guide family. A
/// filterable index of restaurants with a CURRENT (latest-edition)
/// Gault&Millau recognition — no Hotels destination exists for this family
/// (Gault&Millau's production data is restaurant-only, see the Step 2D data
/// audit).
///
/// Deliberately no Year selector (unlike World's 50 Best) and no
/// score/toque filter chip row (unlike Michelin's star-tier chips): see the
/// Step 2D report's explicit "SECONDARY-FILTER DECISION" — production's
/// launch markets (Austria, Belgium, Switzerland, France, Netherlands; see
/// [RestaurantGaultMillauRepository.getCountries], which naturally excludes
/// Germany since no German rows exist yet) mix a 0-20 numeric score with an
/// independent toque count and, per the schema, structurally unscored tiers
/// in some markets — no single secondary filter could honestly represent
/// all of that without either lying about coverage or excluding whole
/// markets from view. Search + Country alone is the truthful MVP surface;
/// see guide_gault_millau_mark.dart for how the resulting mixed data still
/// renders truthfully on each card.
class GaultMillauRestaurantGuideScreen extends StatefulWidget {
  const GaultMillauRestaurantGuideScreen({super.key});

  @override
  State<GaultMillauRestaurantGuideScreen> createState() =>
      _GaultMillauRestaurantGuideScreenState();
}

class _GaultMillauRestaurantGuideScreenState
    extends State<GaultMillauRestaurantGuideScreen> {
  final _searchCtrl = TextEditingController();
  late final _repo = RestaurantGaultMillauRepository(Supabase.instance.client);

  String _query = '';
  Timer? _debounce;
  VenueCountry? _country;

  // Stale-while-revalidating, mirroring MichelinRestaurantGuideScreen's own
  // _results/_loading/_error trio exactly.
  List<RestaurantGaultMillauEntry>? _results;
  bool _loading = false;
  bool _error = false;

  late final Future<List<VenueCountry>> _countriesFuture = _repo.getCountries();

  bool get _hasActiveFilters => _query.trim().isNotEmpty || _country != null;

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
      final results = await _repo.getLatest(
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

  void _open(RestaurantGaultMillauEntry entry) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(restaurant: entry.restaurant),
    ),
  );

  @override
  Widget build(BuildContext context) => GuideCatalogueLayout(
    source: 'GAULT&MILLAU',
    title: 'Restaurants',
    subtitle: 'Distinctive restaurants recognised by Gault&Millau.',
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
                surface: CsSurface.light,
              ),
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
                      final entry = _results![index];
                      return GuideVenueCard(
                        title: entry.restaurant.name,
                        metadataLine: GuideGaultMillauMark(award: entry.award),
                        cityName: entry.restaurant.cityName,
                        countryName: entry.restaurant.countryName,
                        flagEmoji: entry.restaurant.flagEmoji,
                        recognitionSemanticLabel: formatGaultMillauDistinction(
                          entry.award,
                        ),
                        onTap: () => _open(entry),
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
        style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
      ),
      if (loading) ...[
        const SizedBox(width: CsSpacing.sm),
        const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            color: AppColors.taupe,
            strokeWidth: 1.2,
          ),
        ),
      ],
    ],
  );
}
