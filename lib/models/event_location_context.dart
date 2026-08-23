import 'venue_country.dart';

/// Events V2 Discovery Taxonomy Phase C Correction Pass §4/§6/§24/§25 —
/// the Events screen's primary "where" discovery context, promoted out
/// of the advanced Filters sheet to its own first-class, always-visible
/// control (unlike Social/Type/Theme, which stay "advanced refinement").
///
/// V1 supports exactly one resolution mode: an explicit, manually
/// selected country, or none ("All locations" — no restriction).
/// Deliberately NOT named `EventCountryFilter`/`selectedCountryFilter`:
/// the long-term product vision wants Location to eventually also
/// resolve from a manually chosen city, the device's current location
/// (explicit permission, graceful fallback, manual choice always
/// remaining available — see "Future: current location" below), or an
/// upcoming Trip's destination (see "Future: trip destination" below) —
/// none of which are "a selected country." Naming the concept
/// [EventLocationContext] now, even though V1 only ever constructs the
/// country case, means a future mode can be added without renaming this
/// type or touching every call site that already reads [countryCodes].
///
/// No GPS, no location-permission request, no radius/coordinate search
/// is implemented anywhere in this class or its callers — seeing this
/// type does not mean that capability exists yet.
///
/// ## Future: current location
///
/// A later phase could add a resolved-current-location mode (e.g. a
/// `latitude`/`longitude`/`radiusKm` triple instead of a country code).
/// That would NOT reuse [countryCodes] — nearby search is a fundamentally
/// different SQL predicate (distance from a point) than "country code
/// equals one of N values" — so the natural extension point is a new
/// field on this class (or, once a second real mode exists, converting
/// this class into a small closed set of named variants) with its own
/// resolved-predicate getter, leaving [countryCodes] exactly as-is for
/// the manual-country mode it already correctly serves. The product
/// privacy principle for that future work (documented, not built here):
/// explicit user permission before any location read, a graceful
/// fallback when permission is denied or unavailable, and manual
/// location choice must always remain available as an alternative, never
/// replaced.
///
/// ## Future: trip destination
///
/// Step 8A's Trip relevance ranking already knows a signed-in user's
/// upcoming trip destinations (see `event_discovery_ranking.dart`'s own
/// Trip tier) — completely unrelated to and untouched by this class. A
/// future Location UI could offer an upcoming trip's destination as a
/// one-tap shortcut (e.g. a closed-control label reading "Maastricht —
/// Upcoming trip"), which would resolve to exactly the same
/// `EventLocationContext(country: ...)` (or a future city-level variant)
/// this class already supports today — selecting it would only ever set
/// discovery Location/Date context, never change Step 8A's own ranking
/// hierarchy or duplicate its Trip-matching logic.
class EventLocationContext {
  /// `null` means "All locations" — no restriction.
  final VenueCountry? country;

  const EventLocationContext({this.country});

  static const any = EventLocationContext();

  bool get isAny => country == null;

  /// The country-code restriction this context currently resolves to, in
  /// exactly the shape [EventDiscoveryFilters.countryCodes]/
  /// [EventsRepository.loadEvents] already understand — empty means no
  /// restriction. This is the one seam a future non-country mode would
  /// need to resolve through differently (e.g. nearby search would
  /// resolve to a coordinate+radius predicate instead — not built here).
  Set<String> get countryCodes => country == null ? const {} : {country!.code};

  /// The closed-control label (Phase C Correction Pass §9): "Location"
  /// when [isAny], otherwise the selected country's display name. Never
  /// the raw ISO code.
  String get label => country?.name ?? 'Location';

  @override
  bool operator ==(Object other) =>
      other is EventLocationContext && other.country?.code == country?.code;

  @override
  int get hashCode => country?.code.hashCode ?? 0;
}
