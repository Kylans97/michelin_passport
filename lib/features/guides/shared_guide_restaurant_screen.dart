import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/cs_header_drawing.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/country_filter_control.dart';
import '../../core/widgets/cs_search_field.dart';
import '../../data/repositories/guide_award_repository.dart';
import '../../models/guide_award.dart';
import '../../models/venue_country.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'widgets/guide_catalogue_layout.dart';
import 'widgets/guide_catalogue_states.dart';
import 'widgets/guide_venue_card.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/impressions.dart';

/// One guide from the shared guide tables (guides / guide_awards /
/// guide_coverage): the regional 50 Best lists and Guía Repsol. Its own
/// latest edition, searchable and filterable by country like the
/// Gault&Millau guide, in the guide's own order and measure. The coverage
/// note says plainly how much of the list we hold, so a short list never
/// reads as the whole guide.
class SharedGuideRestaurantScreen extends StatefulWidget {
  final String guideCode;
  final String source;
  final String title;
  final String subtitle;

  const SharedGuideRestaurantScreen({
    super.key,
    required this.guideCode,
    required this.source,
    required this.title,
    required this.subtitle,
  });

  @override
  State<SharedGuideRestaurantScreen> createState() =>
      _SharedGuideRestaurantScreenState();
}

class _SharedGuideRestaurantScreenState
    extends State<SharedGuideRestaurantScreen> {
  final _searchCtrl = TextEditingController();
  late final _repo = GuideAwardRepository(Supabase.instance.client);

  String _query = '';
  Timer? _debounce;
  VenueCountry? _country;

  List<SharedGuideEntry>? _results;
  bool _loading = false;
  bool _error = false;

  late final Future<List<VenueCountry>> _countriesFuture = _repo.getCountries(
    widget.guideCode,
  );
  late final Future<GuideCoverage?> _coverageFuture = _repo
      .loadLatestCoverage(widget.guideCode)
      .catchError((_) => null);

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
      final results = await _repo.getCurrentRestaurants(
        widget.guideCode,
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

  void _open(SharedGuideEntry entry) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(
        restaurant: entry.restaurant,
        openSource: AnalyticsOpenSource.guides,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => GuideCatalogueLayout(
    source: widget.source,
    title: widget.title,
    subtitle: widget.subtitle,
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
          FutureBuilder<GuideCoverage?>(
            future: _coverageFuture,
            builder: (context, snap) {
              final note = snap.data?.note;
              if (note == null || note.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: CsSpacing.xs),
                child: Text(
                  note,
                  style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                ),
              );
            },
          ),
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
                      trackImpression(
                        AnalyticsEntityType.restaurant,
                        entry.restaurant.id,
                        ImpressionSurface.guides,
                      );
                      final value = formatGuideAwardValue(entry.award);
                      final line = value == null
                          ? '${entry.award.editionYear}'
                          : '$value · ${entry.award.editionYear}';
                      return GuideVenueCard(
                        title: entry.restaurant.name,
                        imageUrl: entry.restaurant.cardImageUrl,
                        drawing: HeaderDrawing.restaurant(entry.restaurant.id),
                        imageFraming: entry.restaurant.cardFraming,
                        metadataLine: Text(
                          line,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.forestGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        cityName: entry.restaurant.cityName,
                        countryName: entry.restaurant.countryName,
                        flagEmoji: entry.restaurant.flagEmoji,
                        recognitionSemanticLabel: value,
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
