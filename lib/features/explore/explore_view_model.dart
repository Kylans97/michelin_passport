import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'models/explore_item.dart';

/// Combines a restaurant-catalogue query and a hotel-catalogue query into
/// one alphabetically sorted list for Explore's "All" mode. Neither list is
/// ranked above the other — this only interleaves them by name.
List<ExploreItem> combineExploreItems(
  List<Restaurant> restaurants,
  List<Hotel> hotels,
) {
  final items = <ExploreItem>[
    for (final restaurant in restaurants) RestaurantExploreItem(restaurant),
    for (final hotel in hotels) HotelExploreItem(hotel),
  ];
  items.sort((a, b) => a.name.compareTo(b.name));
  return items;
}

/// The countries present in either catalogue, deduplicated by country code
/// and sorted by name — Explore's country filter chips in "All" mode.
List<VenueCountry> mergeVenueCountries(
  List<VenueCountry> restaurantCountries,
  List<VenueCountry> hotelCountries,
) {
  final byCode = <String, VenueCountry>{
    for (final country in restaurantCountries) country.code: country,
    for (final country in hotelCountries) country.code: country,
  };
  final merged = byCode.values.toList();
  merged.sort((a, b) => a.name.compareTo(b.name));
  return merged;
}
