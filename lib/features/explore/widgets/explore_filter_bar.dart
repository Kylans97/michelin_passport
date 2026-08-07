import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/venue_country.dart';
import '../models/explore_filters.dart';
import 'venue_type_selector.dart';

/// Explore's whole filter stack: venue type, search, country, then a
/// context-dependent award row (Stars for Restaurants, Keys for Hotels,
/// nothing — deliberately — for All, so there's no confusing mixed
/// Stars/Keys filter).
class ExploreFilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ExploreVenueType venueType;
  final RestaurantAwardFilter restaurantAward;
  final HotelKeysFilter hotelKeys;
  final String? countryFilter;
  final List<VenueCountry> countries;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ExploreVenueType> onVenueTypeChanged;
  final ValueChanged<RestaurantAwardFilter> onRestaurantAwardChanged;
  final ValueChanged<HotelKeysFilter> onHotelKeysChanged;
  final ValueChanged<String?> onCountryChanged;

  const ExploreFilterBar({
    super.key,
    required this.searchCtrl,
    required this.venueType,
    required this.restaurantAward,
    required this.hotelKeys,
    required this.countryFilter,
    required this.countries,
    required this.onQueryChanged,
    required this.onVenueTypeChanged,
    required this.onRestaurantAwardChanged,
    required this.onHotelKeysChanged,
    required this.onCountryChanged,
  });

  String get _searchHint => switch (venueType) {
    ExploreVenueType.restaurants => 'Search restaurants, cities, countries…',
    ExploreVenueType.hotels => 'Search hotels, cities, countries…',
    ExploreVenueType.all => 'Search restaurants, hotels, cities…',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VenueTypeSelector(selected: venueType, onSelect: onVenueTypeChanged),
          const SizedBox(height: 12),
          TextField(
            controller: searchCtrl,
            onChanged: onQueryChanged,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: _searchHint,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
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
          ),
          if (venueType == ExploreVenueType.restaurants) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < RestaurantAwardFilter.values.length; i++)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: _Chip(
                        label: RestaurantAwardFilter.values[i].label,
                        selected:
                            restaurantAward == RestaurantAwardFilter.values[i],
                        onTap: () => onRestaurantAwardChanged(
                          RestaurantAwardFilter.values[i],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (venueType == ExploreVenueType.hotels) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < HotelKeysFilter.values.length; i++)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: _Chip(
                        label: HotelKeysFilter.values[i].label,
                        selected: hotelKeys == HotelKeysFilter.values[i],
                        onTap: () =>
                            onHotelKeysChanged(HotelKeysFilter.values[i]),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
