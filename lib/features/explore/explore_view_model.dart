import '../../models/venue_country.dart';

/// Explore's Discovery/Search mode switch — Search mode as soon as the
/// query has any non-whitespace content, Discovery mode otherwise
/// (including a query that's all whitespace, e.g. a stray leading space).
/// This one-line rule is the entire "mode switching" behavior the redesign
/// brief describes — extracted to its own pure, testable function rather
/// than living only as a private getter inline in [ExploreScreen], which
/// can't itself be widget-tested (it constructs
/// RestaurantRepository/HotelRepository/EventsRepository against
/// Supabase.instance.client unconditionally — the same limitation
/// documented for PassportScreen in passport_view_model_test.dart).
bool isExploreSearching(String query) => query.trim().isNotEmpty;

/// The countries present across the restaurant, hotel and event catalogues
/// combined, deduplicated by country code and sorted by name — Explore's
/// country filter in Search mode "All" (and, given the search type has its
/// own single-catalogue country lists too, reused for Restaurants/Hotels/
/// Events by passing only the relevant one/two lists and leaving the rest
/// empty). Kept as a single N-list merge rather than one function per
/// combination.
List<VenueCountry> mergeVenueCountries(List<List<VenueCountry>> catalogues) {
  final byCode = <String, VenueCountry>{
    for (final countries in catalogues)
      for (final country in countries) country.code: country,
  };
  final merged = byCode.values.toList();
  merged.sort((a, b) => a.name.compareTo(b.name));
  return merged;
}
