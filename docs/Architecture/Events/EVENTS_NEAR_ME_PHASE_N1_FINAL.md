# EVENTS NEAR ME — PHASE N1 FINAL REPORT

Status: finalized, committed, pushed. Domain and distance foundation
only — no GPS, no permission surface, no visible UI, no schema change,
no production writes.

## HUMAN APPROVAL

N1 has **no user-facing feature to physically approve** — it introduces
no visible Near-me UI, no GPS access, no permission prompt, and no
platform permission configuration. Human approval recorded for this
phase is **architecture/implementation approval**, based on: zero diff
to `EventsScreen`/the Location picker/any other visible UI (confirmed via
`git diff --stat`, empty); 57 new tests covering the domain, distance,
NULL-coordinate, cross-border, composition, and provider-contract
requirements; the full pre-existing 1606-test regression suite passing
unmodified; and confirmed zero native location dependency or platform
permission surface. **Near Me itself was not, and could not have been,
physically tested — it does not exist in the UI yet.** This approval
must never be represented as end-user validation of the Near-me feature.

## N1 SCOPE

A geographic coordinate value (`GeoCoordinate`), a resolved Near-me
location value (`EventNearMeLocation`), `EventLocationContext` evolved
to support a third, mutually-exclusive Near-me mode, pure Haversine
distance + radius-inclusion logic wired into the existing
`applyDiscoveryFilters`, and a `CurrentLocationProvider` abstraction with
a closed success/failure result type. Zero live caller, zero permission
request, zero UI change.

## 100 KM V1 CONTRACT

`defaultEventNearMeRadiusKm = 100.0` (`lib/models/event_near_me_location.dart`)
— the one canonical named constant, no scattered literal `100`/`100.0`
anywhere else in the codebase (confirmed via the diff — it appears only
in its own declaration and its use as `EventNearMeLocation`'s default
parameter value). `EventNearMeLocation.radiusKm` validates positivity
(`ArgumentError` for `<= 0`) regardless of whether the default or an
override is used. No radius UI, no user-adjustable control, anywhere.
Documented explicitly, in the constant's own doc comment, as a
**provisional V1 product decision** — changeable later by editing this
one constant, no architectural rewrite required.

## GEOGRAPHIC COORDINATE DOMAIN

`GeoCoordinate` (`lib/models/geo_coordinate.dart`): immutable,
`latitude`/`longitude` only, validated to `[-90, 90]`/`[-180, 180]`
respectively (`ArgumentError` on violation, confirmed by 4 invalid-input
tests), value-equal (`==`/`hashCode`), no user identity, no address/
city/country, no persistence behavior (no `toJson`/`fromJson`), no
Supabase coupling of any kind.

## NEAR-ME DOMAIN

`EventNearMeLocation` (`lib/models/event_near_me_location.dart`):
`{coordinate: GeoCoordinate, radiusKm: double}`, immutable,
value-comparable, radius validated positive. No permission/provider
concepts, no UI strings, no persistence. Represents already-resolved
location context only — acquiring a coordinate in the first place is
`CurrentLocationProvider`'s job, never this class's.

## EVENTLOCATIONCONTEXT

Exactly one of three mutually-exclusive modes at a time: none (`.any`),
manual country (`.country(...)`), or resolved Near-me
(`.nearMe(...)`). Country and Near me can **never** coexist — enforced
structurally via `assert(country == null || nearMe == null, ...)` in the
base constructor, not merely by convention; each named factory sets only
its own field. Replacement is deterministic by construction: since there
is no mutation API (no `copyWith`), a caller can only ever hold the
single most-recently-constructed instance — selecting Near me after
Country (or vice versa) produces a brand-new value with the old field
simply absent, never a lingering hidden predicate. The pre-existing Phase
C Country call site (`events_screen.dart`) required zero mechanical
edit — confirmed by `EventsScreen`'s own empty diff.

## DISTANCE

`eventGeoDistanceKm(GeoCoordinate, GeoCoordinate)`
(`lib/features/events/event_near_me_filtering.dart`) is the one
canonical Chasing Stars distance function — confirmed via `grep`, no
second distance formula exists anywhere in this codebase. Implemented via
`latlong2`'s own `DistanceHaversine` (already a dependency — the exact
package My Map already uses for tile rendering; no new dependency was
added for this). `latlong2`'s `LatLng`/`Distance`/`LengthUnit` types
never leak past this one file — every caller in this codebase speaks
`GeoCoordinate` exclusively. Returns kilometers explicitly, `roundResult:
false` (a genuine continuous value, not meter-rounded) — appropriate for
a 100 km discovery radius, not a high-precision/meter-level product
assumption.

**Boundary semantics, confirmed by dedicated tests**: `distance < radius`
→ included; `distance == radius` → included (tested via a boundary
derived from the function's own actual output, making the comparison
float-exact rather than a hand-calculated approximation); `distance >
radius` → excluded.

## NULL COORDINATE SEMANTICS

`eventQualifiesForNearMe` excludes an Event whenever `latitude` is
`null`, whenever `longitude` is `null`, and when both are `null` — all
three cases covered by dedicated tests. No fallback to city, country,
venue, host, or participant coordinates anywhere — confirmed by
inspecting the function body directly (a single early `return false`, no
alternate resolution path exists). No enrichment/coordinate-coverage
fix was made during finalization — the 8 of 27 production Events with
`NULL` coordinates remain exactly as they were.

## CROSS-BORDER SEMANTICS

`eventQualifiesForNearMe` never reads `Event.countryCode` — confirmed by
inspecting the function body. Purely geometric, proven by a dedicated
test: a Belgian Event well within a Dutch-centered radius qualifies
exactly like a Dutch Event at the same distance would. Entirely
independent from, and never silently combined with, manual Country
filtering (which remains a separate, mutually-exclusive Location mode).

## STEP 8A REGRESSION

`event_discovery_service.dart` and `event_discovery_ranking.dart`: zero
diff, reconfirmed via `git diff --stat` at finalization time. The
hierarchy (Trip > Friend Going > Followed Host > Friend Interested >
Popularity > Chronology) is untouched. Near Me determines inclusion
only — proven by a dedicated ranking-regression test: among two Near-me-
qualifying Events, a farther one with a Trip signal still outranks a
closer one with no signal, and the closer Event's `primaryReason` is
`null` (no fabricated "nearby" relevance reason was invented). Distance
is not used for sorting, does not create a distance score, and no
proximity relevance reason exists anywhere in the reason taxonomy.

## CURRENTLOCATIONPROVIDER

`abstract interface class CurrentLocationProvider { Future<CurrentLocationResult> getCurrentLocation(); }`
(`lib/features/events/current_location_provider.dart`) — pure Dart
abstraction, zero dependency on `geolocator`, any native location API, or
any concrete permission-check implementation, confirmed via `grep`.
One-shot only by construction — the interface has no `Stream`-returning
method and no `watchPosition` equivalent, so continuous/background
tracking isn't merely undocumented, it's unreachable through this API
surface. No concrete production implementation exists anywhere — the
only implementation in the entire diff is a hand-rolled, test-only fake
inside `test/current_location_provider_test.dart`.

## FAILURE TAXONOMY

`CurrentLocationFailureType` — exactly four values:
`permissionDenied`, `permissionDeniedForever`, `servicesDisabled`,
`unavailable`. No OS-specific enum leakage (confirmed: no `geolocator`
type, no platform error code, no raw string appears in this enum or its
containing sealed hierarchy). No fake/simulated real permission-checking
logic exists — the enum values are purely descriptive categories a
future adapter would map real outcomes onto.

## PRIVACY

Searched the full N1 diff (`lib/` and `test/`) for Supabase writes,
analytics properties, and debug logging containing coordinates — **zero
matches** in every category. No `toJson`/`fromJson` exists on
`GeoCoordinate` or `EventNearMeLocation` (deliberately omitted — a
resolved coordinate is meant to live in transient application state
only). No persistent storage, no serialization intended for persistence,
no background stream anywhere in this diff. `toString()` on both value
types exists solely for debugger/test-failure-message readability, not
as a production logging path — and since no production code constructs
a real device coordinate anywhere in this phase, there is nothing for
that `toString()` to expose even incidentally.

## PACKAGE / PLATFORM NON-CHANGES

Explicitly verified via `git diff --stat` at finalization time — empty
on all four: `pubspec.yaml`, `pubspec.lock`, `ios/Runner/Info.plist`,
`android/app/src/main/AndroidManifest.xml`. `grep -i "geolocator\|permission_handler"`
across `pubspec.yaml`/`pubspec.lock` — zero matches. No location usage-
description key was added to `Info.plist`; no location permission was
added to `AndroidManifest.xml`. **No native permission prompt can occur**
as a consequence of this phase — no code anywhere in `lib/` calls a
native location/permission API, and no platform configuration declares
the permission that would be required to request one even if something
tried.

## EVENTS UI NON-CHANGES

`git diff --stat` on `events_screen.dart`, `widgets/event_filter_sheet.dart`,
`widgets/event_date_control.dart`, and `widgets/event_card.dart` — all
empty. No "Near me" tile, label, loading indicator, GPS control,
permission state, or distance display exists anywhere a real user could
reach. The Location control remains exactly the Phase C Correction Pass
behavior.

## COUNTRY REGRESSION

Not re-tested with new N1-specific tests (none were needed): the
complete pre-existing Phase B/C regression suite — `event_discovery_filters_test.dart`,
`event_discovery_filtering_test.dart`, `event_filter_sheet_test.dart`,
`events_discovery_composition_regression_test.dart` — passed unmodified
in the full 1663-test run, proving no-Location/Netherlands/another-
country/Clear-Location/Search+Country/Date+Country/advanced-Filters+
Country all remain exactly as Phase C left them. The one place Country's
own code could have been affected — `EventLocationContext`'s constructor
signature — is unchanged (`{this.country, this.nearMe}`, both still
optional), so `events_screen.dart`'s single existing call site needed no
edit at all.

## COMPOSITION

Confirmed at the pure level, no live GPS required: `applyDiscoveryFilters`'s
new optional `nearMeLocation` parameter composes correctly with Date,
Theme, and Social (6 dedicated tests, resolved test coordinates,
mirroring the exact fixture style Phase B/C's own composition tests
already established). The canonical model — Search AND Location AND
Date AND advanced Filters → Step 8A ranking — is preserved; Near Me is a
new Location *mode*, not a new dimension, so this composition required
no change to that model's own shape.

## PERFORMANCE

Unchanged assessment from the Pre-Final report: trivial O(n) Haversine
at 27/100 Events; still reasonable for bounded client-side filtering at
~1,000; a coarse server/bounding-box candidate-narrowing step becomes
worthwhile beyond that; full PostGIS/`geography`+spatial-index/radius
query is the correct answer only at genuine scale (10,000+). No
optimization work was performed or is needed at current production
scale (27 Events).

## DATABASE

`supabase migration list --linked`: 40/40 synced. `supabase db push
--linked --dry-run`: `"Remote database is up to date."` Finalization
production writes: 0. Schema changes: 0. RLS changes: 0. Migrations
created/deployed: 0.

## VALIDATION

- `dart format --set-exit-if-changed .` — 420 files, 0 changed.
- `flutter analyze` — No issues found!
- `flutter test` — **1663 passed, 0 failed**, both before and after
  staging (re-run identically post-stage, see Git section).

## FILES

Committed this workstream (the full N1 diff against the last commit,
`651e236`):

New:
- `lib/models/geo_coordinate.dart`
- `lib/models/event_near_me_location.dart`
- `lib/features/events/event_near_me_filtering.dart`
- `lib/features/events/current_location_provider.dart`
- `test/geo_coordinate_test.dart`
- `test/event_near_me_location_test.dart`
- `test/event_near_me_filtering_test.dart`
- `test/current_location_provider_test.dart`
- `docs/Architecture/Events/EVENTS_NEAR_ME_LOCATION_ARCHITECTURE_AUDIT.md`
- `docs/Architecture/Events/EVENTS_NEAR_ME_PHASE_N1_PRE_FINAL.md`
- `docs/Architecture/Events/EVENTS_NEAR_ME_PHASE_N1_FINAL.md` (this file)

Modified:
- `lib/models/event_location_context.dart`
- `lib/features/events/event_discovery_filtering.dart`
- `test/event_location_context_test.dart`

## UNRELATED EXCLUSIONS

Present in the working tree as untracked but deliberately not staged,
not committed, not deleted: `.claude/`, several European/Gault&Millau/
imagery-pilot docs, everything under `supabase/data/enrichment/`. None
were created or touched by Phase N1.

## GIT

See the chat final-answers report for the exact commit hash, message,
and push confirmation recorded at finalization time.

## N2 HANDOFF

Documented only, not started: add `geolocator`; add
`NSLocationWhenInUseUsageDescription` to `Info.plist` (never `Always`);
add `ACCESS_COARSE_LOCATION` to `AndroidManifest.xml`; a concrete
`CurrentLocationProvider` adapter wrapping `geolocator`; a "Near me" tile
prepended to the Location picker; permission requested only after the
user taps "Near me"; one-shot resolution using the already-fixed 100 km
radius; loading, permission-denied, permission-denied-forever/Open-
Settings, services-disabled, and explicit zero-nearby-results states;
manual Country remaining fully available throughout; minimal
`near_me_selected`/`location_permission_result`/`near_me_zero_results`
analytics (no coordinates); physical-device testing. **8 of 27
production Events currently have `NULL` coordinates and must remain
excluded under Near me in N2 — never given a proxy coordinate.**
