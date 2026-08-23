# Events Near Me — Phase N1: Domain + Location Abstraction + Distance Logic (Pre-Final)

Status: implementation complete, not staged/committed/pushed. No GPS, no
permission surface, no visible UI, no new package, no platform config
change, no schema change, no production writes. Inert until a future N2
phase wires a real provider and UI.

## Scope

Phase N1 builds the non-user-facing foundation for Near Me: a geographic
coordinate value, a resolved Near-me location value, `EventLocationContext`
evolved to support it (mutually exclusive with manual Country), pure
Haversine distance + radius-inclusion logic, and a `CurrentLocationProvider`
abstraction with a closed success/failure result type — with zero live
caller, zero permission request, and zero UI change anywhere in this
phase.

## Current Architecture

Re-audited before writing any code (all files re-read in full this
phase): `EventLocationContext` (Phase C Correction Pass, already
documented the future Near-me seam), `EventDiscoveryFilters`/
`event_discovery_filtering.dart` (Phase B/C, `applyDiscoveryFilters` is
the one authoritative pure filtering pass), `EventsRepository`/`Event`
model (`latitude`/`longitude` already exist as nullable `double` fields,
confirmed never geocoded/inferred), `EventDiscoveryFilterService`
(Supabase-touching orchestration, deliberately left untouched this
phase), My Map's `flutter_map`/`latlong2` usage (confirmed `latlong2` is
already a real dependency, used only for tile-rendering coordinate types
today), Trip matching (confirmed date+destination only, no coordinates),
and Step 8A ranking (confirmed no coordinate/distance concept anywhere in
its hierarchy). No reusable coordinate/distance abstraction already
existed in Dart — `latlong2`'s own `Distance`/`LatLng` types are used
directly by the Map feature but were never wrapped behind an app-level
distance function before this phase.

## 100 km V1 Decision

`defaultEventNearMeRadiusKm = 100.0` (`lib/models/event_near_me_location.dart`)
— one named, centralized constant, never a scattered literal. Explicitly
documented in its own doc comment as a **provisional product decision**,
not an architectural constraint: changing the number later means
changing this one constant, nothing else. Not exposed as a user control
anywhere (no radius UI exists or is implied).

## Geographic Coordinate Domain

`GeoCoordinate` (`lib/models/geo_coordinate.dart`) — immutable,
value-comparable, `latitude`/`longitude` only. Validates `latitude ∈
[-90, 90]` and `longitude ∈ [-180, 180]` in the constructor, throwing
`ArgumentError` (not a silent clamp) for an out-of-range value — a
coordinate that far out of range can only be a caller bug, never a
legitimate reading. Deliberately generic, not `EventCoordinate`: this
codebase already has multiple independent "a venue has a lat/lng" call
sites (`Event.latitude`/`.longitude`, `MapRepository`'s restaurant/hotel
columns), so one shared, minimal point type is the cleaner design than
an Events-specific one — while staying small enough not to be
over-generalized (no altitude, no accuracy, no timestamp, no address/
city/country, no `toJson`/`toString`-for-persistence).

## Near-Me Domain

`EventNearMeLocation` (`lib/models/event_near_me_location.dart`) —
`{coordinate: GeoCoordinate, radiusKm: double}`, immutable, value-
comparable. `radiusKm` defaults to `defaultEventNearMeRadiusKm` but
validates positivity regardless (`ArgumentError` for `<= 0`) — the type
itself never hard-codes the 100 km assumption internally beyond that
default, so a future product decision to change it doesn't require
touching this class. Carries no permission/provider concerns — this is
already-resolved domain state; acquiring it is `CurrentLocationProvider`'s
job (see below), never this class's.

## EventLocationContext Evolution

Re-evaluated the architecture audit's own "one mutually-exclusive field,
not a premature enum" recommendation against the current Dart code, and
confirmed it as the smallest clean implementation: added
`EventLocationContext.nearMe` (`EventNearMeLocation?`) alongside the
existing `country` field, plus `EventLocationContext.country(...)`/
`.nearMe(...)` named factories (each setting only their own field) and
`isCountry`/`isNearMe` getters. `countryCodes` returns empty under Near
Me (never expressed as a country-code set — Near Me's own distance
predicate is entirely separate, see "Filter Pipeline" below). `label`
now returns `"Near me"` when `isNearMe` — a domain-string change only
(this class already mixed a UI label into itself before this phase, an
established, pre-existing pattern this phase continues rather than
introduces); nothing in the shipped app constructs a non-null `nearMe`
value, so this is unreachable in production today.

The existing call site (`events_screen.dart`'s `EventLocationContext
(country: country)`) required **zero mechanical edit** — the base
constructor's signature is unchanged (`{this.country, this.nearMe}`,
both still optional), so the existing single-parameter call continues to
compile and behave identically.

## Mutual Exclusivity

Enforced structurally, not by convention: the base constructor carries
`assert(country == null || nearMe == null, ...)`, and the two named
factories (`EventLocationContext.country`/`.nearMe`) each construct with
only their own field set, so no code path in this codebase can ever
produce a `EventLocationContext` with both active. Tested explicitly (5
dedicated tests in `test/event_location_context_test.dart`): constructing
both throws; each factory leaves the other field `null`; selecting Near
Me after Country replaces it (and vice versa, symmetric); selecting
`.any` clears both. "Replacement" is structural, not a mutation API —
there is no `EventLocationContext.copyWith`, so a caller can only ever
hold the single, most-recently-constructed instance; there is no way for
a stale predicate to "remain active" underneath a new one.

## Haversine / Distance

`eventGeoDistanceKm(GeoCoordinate, GeoCoordinate)`
(`lib/features/events/event_near_me_filtering.dart`) is the one
canonical distance function in this codebase — no second formula exists
or is written anywhere else. Reuses `latlong2`'s own `DistanceHaversine`
(package already a dependency, already used by My Map for tile
rendering) rather than hand-rolling a second implementation, per the
task's own explicit evaluation instruction. `latlong2`'s `LatLng`/
`Distance`/`LengthUnit` types are used only internally in this one file
and never appear in the function's own public signature — every caller
in this codebase speaks `GeoCoordinate` exclusively, so a future change
of distance-calculation package would only ever touch this file.
`roundResult: false` avoids `latlong2`'s own default meter-rounding
(irrelevant at a 100 km radius, but keeps the result a genuine continuous
value). Verified via test vectors: same-coordinate → exactly 0; a known
spherical-Earth fact (1° of latitude ≈ 111.32 km, derived directly from
`latlong2`'s own Earth-radius constant, tolerance ±1 km) to prove this is
a genuine great-circle calculation, not a placeholder; Amsterdam↔Rotterdam
(well under 100 km) and Amsterdam↔Maastricht (clearly over 100 km) as
real-world sanity checks; and a symmetry check (A→B equals B→A).

## NULL Coordinate Semantics

`eventQualifiesForNearMe(Event, EventNearMeLocation)` returns `false`
whenever `Event.latitude` or `Event.longitude` is `null` — no fallback
to city, country, a venue proxy, or a participant's coordinate, matching
this project's own hard "never fabricate an Event's location" discipline
(documented in `DUTCH_EVENT_BATCH_2_FINAL.md`, reconfirmed in the Near Me
Location Architecture Audit's own coordinate census). Tested explicitly:
`NULL` latitude alone, `NULL` longitude alone, and both `NULL`, all
excluded regardless of what the other field or the configured radius is.

## Cross-Border Semantics

`eventQualifiesForNearMe` never reads `Event.countryCode` — purely
geometric. Tested explicitly: a Belgian Event well within a Dutch-
centered radius qualifies exactly like a Dutch one at the same distance
would; Near Me is never silently ANDed with an inferred country.

## CurrentLocationProvider

`lib/features/events/current_location_provider.dart` —
`abstract interface class CurrentLocationProvider { Future<CurrentLocationResult> getCurrentLocation(); }`.
Zero dependency on `geolocator`, any native location API, or any
concrete permission-check implementation — this interface is pure Dart.
One-shot only by design (no `Stream`-returning method, no
`watchPosition` equivalent) — the Near Me Location Architecture Audit's
own "No Location Caching"/"No Continuous Tracking" sections are
structurally impossible to violate through this interface, since it has
no API surface that would let a caller even attempt continuous
monitoring. No accuracy parameter either — this interface has exactly
one accuracy need (coarse/reduced, per the Audit's "Battery/Performance"
section), not a caller-configurable one; a real N2 adapter decides this
internally when it wraps `geolocator`.

## Failure Taxonomy

`CurrentLocationResult` is a sealed hierarchy (mirrors this codebase's
own established pattern, e.g. `MapPin` in `lib/features/map/models/
map_pin.dart`) with exactly two shapes: `CurrentLocationSuccess
(GeoCoordinate)` and `CurrentLocationFailure(CurrentLocationFailureType)`.
`CurrentLocationFailureType` has exactly four values —
`permissionDenied`, `permissionDeniedForever`, `servicesDisabled`,
`unavailable` — deliberately minimal (not "20 error cases"), each
mapping to a genuinely different future recovery action, never a raw
`geolocator` exception/error code/platform string. A future consumer can
`switch` over `CurrentLocationResult` exhaustively with no `default`
case (proven directly by a dedicated test) — a new case added later
would be a compile error everywhere it isn't handled, not a silent
runtime gap.

## Privacy

No `toJson`/`fromJson` exists on `GeoCoordinate` or `EventNearMeLocation`
— omitted deliberately (per this phase's own explicit privacy-boundary
instruction), since a resolved coordinate is meant to live in transient
application state only, never serialized for persistence or network
transmission by the domain layer itself. No coordinate value is written
to Supabase, sent to analytics, or `print`/`debugPrint`-logged anywhere
in this phase — there is no code path in Phase N1 that touches Supabase,
analytics, or logging at all (the entire phase is pure Dart domain
logic plus one interface with zero concrete implementation). `toString()`
on `GeoCoordinate`/`EventNearMeLocation` exists only for debugger/test-
failure-message readability (standard Dart practice on any value type in
this codebase), not for any production logging path.

## Search / Date / Filter Composition

Confirmed at the pure level (no live GPS/UI needed): `applyDiscoveryFilters`'s
new optional `nearMeLocation` parameter composes correctly alongside
every existing dimension — Near Me + Date (both must hold), Near Me +
Theme (the resolved tag-matching id set still applies), Near Me + Social
signed-out (still a deterministic empty result, unaffected by Near Me)
and signed-in (the resolved social-qualifying id set still applies) —
covered by 6 dedicated composition tests using resolved test coordinates,
mirroring exactly the fixture style Phase B/C's own composition-
regression tests already established. Search itself is a server-side
`ilike` predicate outside this pure layer's reach (unchanged from Phase
C) — its own AND-composition with Location was already proven in the
Phase C Correction Pass and is architecturally unaffected by Near Me
being a new Location *mode*, not a new dimension.

## Step 8A Regression

Near Me determines inclusion only — confirmed by a dedicated regression
test: among two Near-me-qualifying Events (one ~5 km away with no
signal, one ~40 km away — still within the 100 km radius — with a Trip
signal), the farther Trip-matched Event ranks first, and the closer
signal-less Event has a `null` primaryReason (no fabricated "5 km away"
relevance reason was ever invented). `rankEventsForDiscovery`/
`primaryReasonFor` (`event_discovery_ranking.dart`) are byte-for-byte
unmodified this phase — confirmed via `git diff`, zero changes.

## Performance

Pure Haversine over an already-bounded, already-server-filtered
candidate list is O(n) — trivial at 27 or 100 Events (a handful of
floating-point operations per Event, no measurable cost). At ~1,000
Events, still likely acceptable but a coarse SQL lat/lng bounding-box
pre-filter becomes a reasonable defensive addition (documented, not
built — see "Future Server-Side Seam"). At 10,000 Events, genuine
server-side spatial filtering becomes worthwhile. This matches the Near
Me Location Architecture Audit's own conclusion exactly — Phase N1
changes nothing about that analysis, only confirms the O(n) claim is
realized correctly in the actual pure function.

## Future Server-Side Seam

Not implemented, not designed as a schema change in this phase — the
seam is architectural: `EventDiscoveryFilterService.loadFilteredDiscovery`
(untouched this phase) is the one place a future N2/N4 caller would
extend to accept an optional `EventNearMeLocation?`, apply it via
`applyDiscoveryFilters`'s already-existing `nearMeLocation` parameter (no
further pure-logic change needed for that step), and — only once
catalogue scale genuinely warrants it — push a coarse bounding-box or
eventually a full `ST_DWithin` predicate into the base
`EventsRepository.loadEvents` SQL query instead of fetching every
candidate Event into Dart first. The database side of that future step
(a `geography` column + GIST index on `events`, mirroring the already-
proven `restaurants`/`hotels` pattern) remains exactly what the Near Me
Location Architecture Audit already documented — nothing new added here.

## UI Non-Changes

`EventsScreen`, `event_filter_sheet.dart`, `event_date_control.dart` —
zero diff (confirmed via `git diff`). No "Near me" tile, button, loading
state, error state, or new Location label was added anywhere a real user
could reach. `EventLocationContext.label` CAN return `"Near me"`, but no
production call site ever constructs a `nearMe`-populated context, so
this is unreachable, not merely "not shown."

## Package / Platform Non-Changes

Confirmed via direct diff and grep at the end of this phase (not
assumed): `git diff --stat pubspec.yaml pubspec.lock ios/Runner/
Info.plist android/app/src/main/AndroidManifest.xml` — empty, zero
changes to all four files. `grep -i "geolocator\|permission_handler"`
across `pubspec.yaml`/`pubspec.lock` — zero matches. No permission prompt
can possibly appear after this phase: no code anywhere in `lib/` calls
any native location/permission API (the entire location-acquisition
surface is the zero-implementation `CurrentLocationProvider` interface),
and no platform manifest/plist declares the permission that would be
required to request it even if something tried.

## Database

`supabase migration list --linked`: 40/40 synced, unchanged.
`supabase db push --linked --dry-run`: `"Remote database is up to date."`
No migration created. No `geography` column, no GIST index, no radius
RPC — all remain future-only, exactly as scoped.

## Tests

57 new tests across 5 new/extended files:

- `test/geo_coordinate_test.dart` (11) — valid construction, boundary
  values, invalid latitude, invalid longitude, equality.
- `test/event_near_me_location_test.dart` (7) — the default-radius
  constant, valid/invalid radius, equality.
- `test/event_location_context_test.dart` (+8 new, existing tests
  untouched) — Near-me mode's own isAny/isNearMe/isCountry/label/
  countryCodes/equality, plus the 5 mutual-exclusivity tests.
- `test/event_near_me_filtering_test.dart` (22) — distance vectors,
  radius-boundary inclusion (including a float-exact boundary case
  derived from the function's own output, not a hand-calculated
  approximation), NULL-coordinate exclusion (3 cases), cross-border
  inclusion, 6 `applyDiscoveryFilters` composition cases, and the Step
  8A ranking-regression test.
- `test/current_location_provider_test.dart` (11) — success, all 4
  failure types (parameterized), exhaustive sealed-switch proof,
  equality.

## Validation

- `dart format --set-exit-if-changed .` — clean (4 files auto-formatted
  during development, all committed to that formatting; final run
  clean).
- `flutter analyze` — No issues found!
- `flutter test` — **1663 passed, 0 failed** (1606 baseline + 57 new,
  exact match — nothing skipped or weakened).
- `supabase migration list --linked` / `db push --dry-run` — 40/40
  synced, remote up to date.

## Files

New:
- `lib/models/geo_coordinate.dart`
- `lib/models/event_near_me_location.dart`
- `lib/features/events/event_near_me_filtering.dart`
- `lib/features/events/current_location_provider.dart`
- `test/geo_coordinate_test.dart`
- `test/event_near_me_location_test.dart`
- `test/event_near_me_filtering_test.dart`
- `test/current_location_provider_test.dart`
- `docs/Architecture/Events/EVENTS_NEAR_ME_PHASE_N1_PRE_FINAL.md` (this
  file)

Modified:
- `lib/models/event_location_context.dart` — added `nearMe` field,
  `.country()`/`.nearMe()` factories, `isCountry`/`isNearMe` getters,
  updated `label`/equality/hashCode. Existing `country`-only call site
  unaffected.
- `lib/features/events/event_discovery_filtering.dart` — added optional
  `nearMeLocation` parameter to `applyDiscoveryFilters`; existing
  callers (none of which pass it) are behaviorally unaffected.
- `test/event_location_context_test.dart` — extended with the
  mutual-exclusivity/Near-me groups above.

Not modified (confirmed by audit, not assumption): `pubspec.yaml`,
`pubspec.lock`, `ios/Runner/Info.plist`,
`android/app/src/main/AndroidManifest.xml`,
`lib/features/events/events_screen.dart`,
`lib/features/events/widgets/event_filter_sheet.dart`,
`lib/features/events/widgets/event_date_control.dart`,
`lib/features/events/event_discovery_filter_service.dart`,
`lib/features/events/event_discovery_service.dart`,
`lib/features/events/event_discovery_ranking.dart`,
`lib/features/events/widgets/event_card.dart`,
`lib/features/events/event_detail_screen.dart`, any migration file.

## Git

Nothing staged, committed, or pushed, per the hard scope boundary.
`git status --short` shows exactly the new/modified files listed above,
plus the same pre-existing unrelated untracked research artifacts from
prior phases.

## N2 Handoff

Documented only — not started. N2's likely scope: add the `geolocator`
package; add `NSLocationWhenInUseUsageDescription` to `Info.plist`
(never `Always`); add `ACCESS_COARSE_LOCATION` to `AndroidManifest.xml`
(not `ACCESS_FINE_LOCATION`); write a concrete `CurrentLocationProvider`
adapter wrapping `geolocator`'s permission + position APIs, mapping its
results onto the N1 `CurrentLocationResult`/`CurrentLocationFailureType`
types (never leaking `geolocator`-specific types past that one adapter);
add a "Near me" tile to the Location sheet (prepended above the country
list, per the Near Me Location Architecture Audit's own UI
recommendation); wire the real on-tap permission-request flow; implement
loading, permission-denied, permission-denied-forever/Open-Settings,
services-disabled, and zero-nearby-results states; extend
`EventDiscoveryFilterService.loadFilteredDiscovery` to accept and apply
the resolved `EventNearMeLocation` (the pure `applyDiscoveryFilters`
seam already exists and needs no further change for this); add the
minimal `near_me_selected`/`location_permission_result`/
`near_me_zero_results` analytics (no coordinates); physical-device
testing (real location, manual country still available, denied
permission, services disabled, simulated different location).
