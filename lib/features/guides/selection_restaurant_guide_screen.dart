import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/country_filter_control.dart';
import '../../core/widgets/cs_search_field.dart';
import '../../core/widgets/star_row.dart';
import '../../data/repositories/editorial_selection_repository.dart';
import '../../models/venue_country.dart';
import '../explore/widgets/explore_discovery_cards.dart'
    show mantelierSelectionLabel;
import '../restaurants/restaurant_detail_screen.dart';
import 'widgets/guide_catalogue_layout.dart';
import 'widgets/guide_catalogue_states.dart';
import 'widgets/guide_venue_card.dart';

/// Every restaurant in our own editorial Selection, newest first — the
/// Guides counterpart to Explore's "Mantelier's latest". Same catalogue
/// layout as the MICHELIN/50 Best/Gault&Millau guides.
///
/// The Selection is small and chosen one restaurant at a time, so it loads
/// once and search/country narrow it on the device. The country list comes
/// from the Selection itself (country codes), never a fixed market list.
class SelectionRestaurantGuideScreen extends StatefulWidget {
  /// Overridable for tests; production passes nothing.
  final Future<List<SelectionEntry>> Function()? load;

  const SelectionRestaurantGuideScreen({super.key, this.load});

  @override
  State<SelectionRestaurantGuideScreen> createState() =>
      _SelectionRestaurantGuideScreenState();
}

class _SelectionRestaurantGuideScreenState
    extends State<SelectionRestaurantGuideScreen> {
  final _searchCtrl = TextEditingController();
  late final _repo = EditorialSelectionRepository(Supabase.instance.client);

  String _query = '';
  VenueCountry? _country;
  List<SelectionEntry>? _all;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final entries = await (widget.load ?? _repo.loadCurrent)();
      if (!mounted) return;
      setState(() => _all = entries);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  List<VenueCountry> get _countries {
    final byCode = <String, VenueCountry>{};
    for (final e in _all ?? const <SelectionEntry>[]) {
      final r = e.restaurant;
      byCode.putIfAbsent(
        r.countryCode,
        () => VenueCountry(
          name: r.countryName,
          code: r.countryCode,
          flag: r.flagEmoji,
        ),
      );
    }
    return byCode.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<SelectionEntry> get _results {
    final words = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return [
      for (final e in _all ?? const <SelectionEntry>[])
        if (_country == null || e.restaurant.countryCode == _country!.code)
          if (words.every(
            (w) => [
              e.restaurant.name,
              e.restaurant.cityName,
              e.restaurant.countryName,
            ].any((field) => field.toLowerCase().contains(w)),
          ))
            e,
    ];
  }

  void _open(SelectionEntry entry) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(restaurant: entry.restaurant),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final results = _results;
    return GuideCatalogueLayout(
      source: mantelierSelectionLabel.toUpperCase(),
      title: 'Restaurants',
      subtitle: 'Chosen by our own editors.',
      content: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.pageHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CsSearchField(
              controller: _searchCtrl,
              hintText: 'Search restaurants, cities & countries',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: CsSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: CountryFilterControl(
                selected: _country,
                countries: _countries,
                onChanged: (c) => setState(() => _country = c),
                surface: CsSurface.light,
              ),
            ),
            if (all != null) ...[
              const SizedBox(height: CsSpacing.base),
              Text(
                results.length == 1 ? '1 place' : '${results.length} places',
                style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
              ),
            ],
            const SizedBox(height: CsSpacing.sm),
            Expanded(
              child: _error && all == null
                  ? GuideCatalogueErrorState(onRetry: _load)
                  : all == null
                  ? const GuideCatalogueLoading()
                  : results.isEmpty
                  ? GuideCatalogueEmptyState(
                      hasActiveFilters:
                          _query.trim().isNotEmpty || _country != null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: CsSpacing.xxl),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const GuideVenueCardDivider(),
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        final r = entry.restaurant;
                        // A star is still a star — gold StarRow, the only
                        // gold here. Without one, the Selection label in
                        // forest green: never an empty star row.
                        return GuideVenueCard(
                          title: r.name,
                          imageUrl: r.cardImageUrl,
                          imageFraming: r.cardFraming,
                          inlineRecognition: r.hasMichelinStar
                              ? StarRow(count: r.michelinStars!, size: 12)
                              : null,
                          metadataLine: r.hasMichelinStar
                              ? null
                              : Text(
                                  mantelierSelectionLabel,
                                  style: CsTypography.metadata.copyWith(
                                    color: AppColors.forestGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          cityName: r.cityName,
                          countryName: r.countryName,
                          flagEmoji: r.flagEmoji,
                          recognitionSemanticLabel: mantelierSelectionLabel,
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
}
