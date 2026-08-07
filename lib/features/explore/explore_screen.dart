import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/number_format.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/venue_country.dart';
import 'explore_view_model.dart';
import 'models/explore_filters.dart';
import 'models/explore_item.dart';
import 'widgets/explore_filter_bar.dart';
import 'widgets/explore_status_states.dart';
import 'widgets/hotel_tile.dart';
import 'widgets/restaurant_tile.dart';

// Catalogue-read-only Explore: browses public.restaurants_full and
// public.hotels_full. No visited, wishlist or trophy state for either yet —
// hotels in particular have no stays/visits at all yet (later slice).
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();

  late final _restaurantRepo = RestaurantRepository(Supabase.instance.client);
  late final _hotelRepo = HotelRepository(Supabase.instance.client);

  ExploreVenueType _venueType = ExploreVenueType.all;
  RestaurantAwardFilter _restaurantAward = RestaurantAwardFilter.all;
  HotelKeysFilter _hotelKeys = HotelKeysFilter.all;
  String? _countryFilter;
  String _query = '';

  late Future<List<ExploreItem>> _resultsFuture;

  // Fetched once: the country chip list doesn't depend on the current
  // search/filter state, only on which countries exist in each catalogue —
  // same pattern the previous single-catalogue Explore used.
  late final Future<(List<VenueCountry>, List<VenueCountry>)> _countriesFuture =
      _loadCountries();

  @override
  void initState() {
    super.initState();
    _resultsFuture = _fetchResults();
  }

  Future<(List<VenueCountry>, List<VenueCountry>)> _loadCountries() async {
    final restaurantsFuture = _restaurantRepo.getCountries();
    final hotelsFuture = _hotelRepo.getCountries();
    return (await restaurantsFuture, await hotelsFuture);
  }

  // All mode issues exactly one restaurant query + one hotel query (run
  // concurrently, awaited in turn) and combines them in Dart — never one
  // query per result and never N+1.
  Future<List<ExploreItem>> _fetchResults() async {
    switch (_venueType) {
      case ExploreVenueType.restaurants:
        final restaurants = await _restaurantRepo.search(
          _query,
          stars: _restaurantAward.starsParam,
          worlds50BestOnly: _restaurantAward.isWorlds50Best,
          hallOfFameOnly: _restaurantAward.isHallOfFame,
          countryCode: _countryFilter,
        );
        return [for (final r in restaurants) RestaurantExploreItem(r)];
      case ExploreVenueType.hotels:
        final hotels = await _hotelRepo.search(
          _query,
          keys: _hotelKeys.keysParam,
          countryCode: _countryFilter,
        );
        return [for (final h in hotels) HotelExploreItem(h)];
      case ExploreVenueType.all:
        final restaurantsFuture = _restaurantRepo.search(
          _query,
          countryCode: _countryFilter,
        );
        final hotelsFuture = _hotelRepo.search(
          _query,
          countryCode: _countryFilter,
        );
        return combineExploreItems(await restaurantsFuture, await hotelsFuture);
    }
  }

  void _load() {
    setState(() => _resultsFuture = _fetchResults());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _resultCountLabel(int count) {
    final formatted = formatThousands(count);
    return switch (_venueType) {
      ExploreVenueType.restaurants =>
        '$formatted restaurant${count == 1 ? '' : 's'}',
      ExploreVenueType.hotels => '$formatted hotel${count == 1 ? '' : 's'}',
      ExploreVenueType.all => '$formatted place${count == 1 ? '' : 's'}',
    };
  }

  String get _emptyMessage => switch (_venueType) {
    ExploreVenueType.restaurants => 'No restaurants found',
    ExploreVenueType.hotels => 'No hotels found',
    ExploreVenueType.all => 'No places found',
  };

  String get _errorMessage => switch (_venueType) {
    ExploreVenueType.restaurants => 'Could not load restaurants',
    ExploreVenueType.hotels => 'Could not load hotels',
    ExploreVenueType.all => 'Could not load places',
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExploreItem>>(
      future: _resultsFuture,
      builder: (context, snap) {
        final results = snap.data ?? [];
        final loading = snap.connectionState == ConnectionState.waiting;
        // Only meaningful while browsing Restaurants mode with the World's
        // 50 Best award filter selected — All mode never applies
        // _restaurantAward at all (see _fetchResults), so this is false
        // there regardless of leftover filter state.
        final highlightWorlds50Best =
            _venueType == ExploreVenueType.restaurants &&
            _restaurantAward.isWorlds50Best;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Explore'),
              pinned: true,
              backgroundColor: AppColors.background,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(
                  _venueType == ExploreVenueType.all ? 152 : 188,
                ),
                child: FutureBuilder<(List<VenueCountry>, List<VenueCountry>)>(
                  future: _countriesFuture,
                  builder: (context, countrySnap) {
                    final (restaurantCountries, hotelCountries) =
                        countrySnap.data ??
                        (const <VenueCountry>[], const <VenueCountry>[]);
                    final countries = switch (_venueType) {
                      ExploreVenueType.restaurants => restaurantCountries,
                      ExploreVenueType.hotels => hotelCountries,
                      ExploreVenueType.all => mergeVenueCountries(
                        restaurantCountries,
                        hotelCountries,
                      ),
                    };
                    return ExploreFilterBar(
                      searchCtrl: _searchCtrl,
                      venueType: _venueType,
                      restaurantAward: _restaurantAward,
                      hotelKeys: _hotelKeys,
                      countryFilter: _countryFilter,
                      countries: countries,
                      onQueryChanged: (v) {
                        _query = v;
                        _load();
                      },
                      onVenueTypeChanged: (v) {
                        setState(() => _venueType = v);
                        _load();
                      },
                      onRestaurantAwardChanged: (v) {
                        setState(() => _restaurantAward = v);
                        _load();
                      },
                      onHotelKeysChanged: (v) {
                        setState(() => _hotelKeys = v);
                        _load();
                      },
                      onCountryChanged: (v) {
                        setState(() => _countryFilter = v);
                        _load();
                      },
                    );
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 1.5,
                        ),
                      )
                    : Text(
                        _resultCountLabel(results.length),
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),

            if (snap.hasError)
              SliverFillRemaining(
                child: ExploreErrorState(
                  message: _errorMessage,
                  onRetry: _load,
                ),
              )
            else if (results.isEmpty && !loading)
              SliverFillRemaining(
                child: ExploreEmptyState(message: _emptyMessage),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: EdgeInsets.only(
                      bottom: i == results.length - 1 ? 88 : 0,
                    ),
                    child: switch (results[i]) {
                      RestaurantExploreItem(:final restaurant) =>
                        RestaurantTile(
                          restaurant: restaurant,
                          showWorlds50BestRank: highlightWorlds50Best,
                        ),
                      HotelExploreItem(:final hotel) => HotelTile(hotel: hotel),
                    },
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
