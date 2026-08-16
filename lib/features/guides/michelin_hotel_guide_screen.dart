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
import '../../core/widgets/key_row.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../models/hotel.dart';
import '../../models/venue_country.dart';
import '../hotels/hotel_detail_screen.dart';
import 'guide_view_model.dart';
import 'models/guide_filters.dart';
import 'widgets/guide_catalogue_layout.dart';
import 'widgets/guide_catalogue_states.dart';
import 'widgets/guide_venue_card.dart';

/// Michelin Guide → Hotels (Step 2B). The mirror of
/// [MichelinRestaurantGuideScreen] for hotels — CURRENTLY Michelin Key
/// hotels only (see HotelRepository.search()'s `keysOnly`), no Year filter.
class MichelinHotelGuideScreen extends StatefulWidget {
  const MichelinHotelGuideScreen({super.key});

  @override
  State<MichelinHotelGuideScreen> createState() =>
      _MichelinHotelGuideScreenState();
}

class _MichelinHotelGuideScreenState extends State<MichelinHotelGuideScreen> {
  final _searchCtrl = TextEditingController();
  late final _repo = HotelRepository(Supabase.instance.client);

  String _query = '';
  Timer? _debounce;
  VenueCountry? _country;
  GuideKeyFilter _keyFilter = GuideKeyFilter.all;

  List<Hotel>? _results;
  bool _loading = false;
  bool _error = false;

  late final Future<List<VenueCountry>> _countriesFuture = _repo.getCountries(
    keysOnly: true,
  );

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _country != null ||
      _keyFilter != GuideKeyFilter.all;

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
        keys: _keyFilter.keysParam,
        keysOnly: true,
        countryCode: _country?.code,
      );
      if (!mounted) return;
      setState(() {
        _results = sortGuideHotels(results);
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

  void _onKeyFilterChanged(GuideKeyFilter filter) {
    setState(() => _keyFilter = filter);
    _load();
  }

  void _open(Hotel hotel) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
  );

  @override
  Widget build(BuildContext context) => GuideCatalogueLayout(
    source: 'MICHELIN GUIDE',
    title: 'Hotels',
    subtitle: 'Exceptional hotels recognised with Michelin Keys.',
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CsSearchField(
            controller: _searchCtrl,
            hintText: 'Search hotels, cities & countries',
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
          const SizedBox(height: CsSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < GuideKeyFilter.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: CsSpacing.sm),
                  CsFilterChip(
                    label: GuideKeyFilter.values[i].label,
                    selected: _keyFilter == GuideKeyFilter.values[i],
                    onTap: () => _onKeyFilterChanged(GuideKeyFilter.values[i]),
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
                      final hotel = _results![index];
                      final keys = hotel.michelinKeys ?? 0;
                      return GuideVenueCard(
                        title: hotel.name,
                        inlineRecognition: KeyRow(count: keys, size: 12),
                        cityName: hotel.cityName,
                        countryName: hotel.countryName,
                        flagEmoji: hotel.flagEmoji,
                        recognitionSemanticLabel:
                            '$keys ${keys == 1 ? 'Michelin Key' : 'Michelin Keys'}',
                        onTap: () => _open(hotel),
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
