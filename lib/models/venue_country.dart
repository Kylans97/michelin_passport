/// A country present in at least one venue catalogue (restaurants and/or
/// hotels), used for Explore's country filter chips. Not itself a
/// `public.countries` row — see RestaurantRepository.getCountries() and
/// HotelRepository.getCountries(), which each derive this by intersecting
/// the distinct country_code values actually present in their own
/// catalogue against the full public.countries reference table.
class VenueCountry {
  final String name;
  final String code;
  final String flag;

  const VenueCountry({
    required this.name,
    required this.code,
    required this.flag,
  });
}
