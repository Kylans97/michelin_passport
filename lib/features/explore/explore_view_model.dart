import '../../models/journey.dart';
import '../../models/venue_country.dart';
import '../../models/vineyard.dart';

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

// ── Wine estates, trains and ships (2026-11-20) ──────────────────────────
// Small catalogues, read whole and searched on the device. A place typed
// ("Bordeaux", "Douro") matches the stored region and town as well as the
// name — stored fields only, nothing inferred.

bool _matchesFolded(Iterable<String?> fields, String typed) {
  final q = foldForSearch(typed.trim());
  if (q.length < 2) return false;
  for (final field in fields) {
    if (field != null && foldForSearch(field).contains(q)) return true;
  }
  return false;
}

/// The estates matching [query] by name, region or town, optionally in
/// one country, in the collection's own order.
List<Vineyard> filterExploreVineyards(
  List<Vineyard> vineyards, {
  required String query,
  String? countryCode,
}) => [
  for (final v in vineyards)
    if ((countryCode == null || v.countryCode == countryCode) &&
        _matchesFolded([v.name, v.region, v.city], query))
      v,
];

/// The trains and ships matching [query] by name, operator, or where they
/// run; [kind] narrows to trains or ships, [countryCode] to journeys whose
/// home country or any route touches it.
List<Journey> filterExploreJourneys(
  List<Journey> journeys, {
  required String query,
  JourneyKind? kind,
  String? countryCode,
}) => [
  for (final j in journeys)
    if ((kind == null || j.kind == kind) &&
        (countryCode == null ||
            j.primaryCountryCode == countryCode ||
            j.routeCountryCodes.contains(countryCode)) &&
        _matchesFolded([
          j.name,
          j.operatorName,
          j.regionsText,
          j.countryName,
        ], query))
      j,
];

/// The country filter's options for wine estates: every country an estate
/// is in, sorted by name.
List<VenueCountry> vineyardCountries(List<Vineyard> vineyards) =>
    mergeVenueCountries([
      [
        for (final v in vineyards)
          if ((v.countryName ?? '').isNotEmpty)
            VenueCountry(
              name: v.countryName!,
              code: v.countryCode,
              flag: v.flagEmoji ?? '',
            ),
      ],
    ]);

/// The country filter's options for trains or ships: each journey's home
/// country, sorted by name.
List<VenueCountry> journeyCountries(List<Journey> journeys, JourneyKind kind) =>
    mergeVenueCountries([
      [
        for (final j in journeys)
          if (j.kind == kind &&
              j.primaryCountryCode != null &&
              (j.countryName ?? '').isNotEmpty)
            VenueCountry(
              name: j.countryName!,
              code: j.primaryCountryCode!,
              flag: j.flagEmoji ?? '',
            ),
      ],
    ]);
