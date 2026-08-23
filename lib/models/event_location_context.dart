import 'event_near_me_location.dart';
import 'venue_country.dart';

/// Events V2 Discovery Taxonomy Phase C Correction Pass §4/§6/§24/§25 —
/// the Events screen's primary "where" discovery context, promoted out
/// of the advanced Filters sheet to its own first-class, always-visible
/// control (unlike Social/Type/Theme, which stay "advanced refinement").
///
/// As of Near Me Phase N1, exactly one of THREE mutually-exclusive
/// resolution modes is active at a time: none ("All locations"), an
/// explicit manually-selected country, or a resolved Near-me location.
/// Deliberately NOT named `EventCountryFilter`/`selectedCountryFilter`:
/// the long-term product vision wants Location to eventually also
/// resolve from a manually chosen city or an upcoming Trip's destination
/// (see "Future: trip destination" below) — none of which are "a
/// selected country." Naming the concept [EventLocationContext] means a
/// future mode can be added without renaming this type or touching every
/// call site that already reads [countryCodes].
///
/// Phase N1 introduces the [nearMe] field itself, plus the pure domain
/// types it resolves to ([EventNearMeLocation]/`GeoCoordinate`) and the
/// pure filtering logic that consumes it (`event_near_me_filtering.dart`)
/// — it does NOT introduce any GPS read, permission request, or visible
/// UI. Nothing in the shipped app constructs a non-null [nearMe] value
/// yet; [label] can already say "Near me" (harmless, unreachable in
/// production until a real caller exists), matching this codebase's own
/// established practice of a domain type being ready before its UI is
/// wired (see EVENTS_NEAR_ME_PHASE_N1_PRE_FINAL.md's "N2 Handoff").
///
/// ## Future: trip destination
///
/// Step 8A's Trip relevance ranking already knows a signed-in user's
/// upcoming trip destinations (see `event_discovery_ranking.dart`'s own
/// Trip tier) — completely unrelated to and untouched by this class. A
/// future Location UI could offer an upcoming trip's destination as a
/// one-tap shortcut (e.g. a closed-control label reading "Maastricht —
/// Upcoming trip"), which would resolve to exactly the same
/// `EventLocationContext.country(...)` (or a future city-level variant)
/// this class already supports today — selecting it would only ever set
/// discovery Location/Date context, never change Step 8A's own ranking
/// hierarchy or duplicate its Trip-matching logic.
class EventLocationContext {
  /// Non-null only in the manual-country mode.
  final VenueCountry? country;

  /// Non-null only in the resolved-Near-me mode.
  final EventNearMeLocation? nearMe;

  /// [country] and [nearMe] are structurally enforced to never both be
  /// set (see the assertion below) — a location context that somehow
  /// meant "Netherlands AND within 100km of some point" would be an
  /// incoherent, contradictory predicate no caller should ever be able
  /// to construct, let alone need to reason about downstream. Prefer the
  /// named [EventLocationContext.country]/[EventLocationContext.nearMe]/
  /// [any] constructors over this one directly.
  const EventLocationContext({this.country, this.nearMe})
    : assert(
        country == null || nearMe == null,
        'EventLocationContext cannot have both a manual country and a '
        'resolved Near-me location active at once — country selection '
        'and Near-me selection must always replace one another, never '
        'combine.',
      );

  /// No restriction — the default, and the one safe fallback every
  /// zero-result/failure-recovery path can always return to.
  static const any = EventLocationContext();

  /// Selecting a country always replaces any previously-active Near-me
  /// selection (Correction Pass's own "one dimension, selecting either
  /// replaces the other" contract, extended to Near Me) — a caller
  /// constructs a brand new [EventLocationContext] rather than mutating
  /// one, so there is no code path where the old [nearMe] value could
  /// leak through.
  factory EventLocationContext.country(VenueCountry country) =>
      EventLocationContext(country: country);

  /// Selecting Near Me always replaces any previously-active manual
  /// country selection — same reasoning as [EventLocationContext.country]
  /// above, mirrored.
  factory EventLocationContext.nearMe(EventNearMeLocation location) =>
      EventLocationContext(nearMe: location);

  bool get isAny => country == null && nearMe == null;

  bool get isCountry => country != null;

  bool get isNearMe => nearMe != null;

  /// The country-code restriction this context currently resolves to, in
  /// exactly the shape [EventDiscoveryFilters.countryCodes]/
  /// [EventsRepository.loadEvents] already understand — empty in both
  /// the [isAny] and [isNearMe] cases (Near Me is never expressed as a
  /// country-code set; see `event_near_me_filtering.dart`'s own separate
  /// distance predicate for how it actually narrows candidates).
  Set<String> get countryCodes => country == null ? const {} : {country!.code};

  /// The closed-control label (Phase C Correction Pass §9, extended by
  /// Near Me Phase N1): "Near me" when [isNearMe], the selected
  /// country's display name when [isCountry] (never the raw ISO code),
  /// otherwise "Location".
  String get label =>
      nearMe != null ? 'Near me' : (country?.name ?? 'Location');

  @override
  bool operator ==(Object other) =>
      other is EventLocationContext &&
      other.country?.code == country?.code &&
      other.nearMe == nearMe;

  @override
  int get hashCode => Object.hash(country?.code, nearMe);
}
