# Events Near Me / Current Location — Architecture + Product Audit

Status: **audit only — nothing implemented.** No code changed, no schema
changed, no packages added, no permissions requested, no production
writes. Written to inform a future human/product decision before any
Near Me implementation phase begins.

## Executive Decision

**Recommendation: build Near Me as a small, additive V1 — client-side
distance filtering over the existing `events.latitude`/`longitude`
columns, a generous non-adjustable radius (~100 km), filter-only (Step
8A ranking untouched), NULL-coordinate Events excluded (never proxied),
explicit opt-in permission requested only when the user taps "Near me."
No schema change, no new server-side infrastructure, no map UI. This is
achievable with one new package (`geolocator`) and no database work.**
Server-side spatial filtering (PostGIS, already installed and already
proven elsewhere in this database — see below) is the correct future
path once the catalogue is large enough to need it, not before.

Before implementation begins, four things need an explicit human/product
decision (see "Open Decisions"): the exact V1 radius value, whether to
invest in improving today's ~70% coordinate coverage first, whether the
Trip-destination shortcut is worth building at all, and the long-term
default-location precedence.

## Current Location Architecture

**No device-GPS infrastructure exists anywhere in this codebase today.**
Confirmed by full-repository search:

- `pubspec.yaml` contains no `geolocator`, `location`, or
  `permission_handler` package. The only geo-adjacent packages are
  `flutter_map` (^8.3.1) and `latlong2` (^0.10.1) — both used exclusively
  for the "My Map" screen's tile rendering, not for reading device
  position.
- No native location API (`CLLocationManager`, `FusedLocationProvider`,
  etc.) appears anywhere in `ios/`/`android/` source.
- `ios/Runner/Info.plist` has **no** `NSLocationWhenInUseUsageDescription`
  or any location usage-description key — only `NSPhotoLibraryUsageDescription`
  exists today.
- `android/app/src/main/AndroidManifest.xml` declares **zero**
  `<uses-permission>` entries of any kind — not just no location
  permission, no permissions at all are explicit in the manifest today.

**Every existing "latitude"/"longitude" in the app is a stored data
field, never a device reading:**

- `Event.latitude`/`Event.longitude` (`lib/models/event.dart:157-158`) —
  nullable `double`, parsed straight from `public.events`, with an
  explicit, load-bearing doc comment elsewhere (`lib/features/map/models/
  map_pin.dart:180-187`) that these are "the Event's OWN snapshotted
  coordinates... never inferred from a linked venue... never a city
  center, never a runtime geocoder."
- `Restaurant`/`Hotel` have **no** `latitude`/`longitude` Dart fields at
  all — those catalogue columns are deliberately excluded from every
  shared query (`restaurantFullColumns`/`hotelFullColumns`) because
  requesting them everywhere would be wasteful; they're loaded only by
  `MapRepository.loadRestaurantCoordinates`/`loadHotelCoordinates` for
  the Map feature specifically.
- "My Map" (`lib/features/map/visited_map_screen.dart`) has an explicit
  doc comment (lines 45-49): *"No GPS/location permission is used or
  requested: every coordinate shown comes from the venues/Events
  themselves... never from the device's current position."* It renders
  via `flutter_map` + OpenStreetMap tiles, defaults to a world view when
  there are no pins, and never centers on the user.

**Trip model and Trip-to-Event matching are purely date + destination
based, never coordinate based** — confirmed via `lib/models/
planned_trip.dart` (fields: `startDate`, `endDate`, `countryCode`,
`city?` — no coordinates at all) and `lib/models/event_trip_match.dart`'s
`eventMatchesTrip()` (calendar-date overlap, exact country match, then
optional case-insensitive city match). Step 8A's own Trip relevance
signal (`event_discovery_ranking.dart`) uses this same date/destination
match — no coordinates anywhere in the ranking hierarchy.

**`EventLocationContext`** (`lib/models/event_location_context.dart`,
finalized this phase) already anticipates and *documents, but does not
implement*, a future coordinate/radius mode — its own doc comment states
a future mode would need a *new field*, never reusing `countryCodes`
("nearby search is a fundamentally different SQL predicate... than
'country code equals one of N values'"), and states the product privacy
principle to follow: explicit permission, graceful fallback, manual
choice always available. This audit's domain recommendation (see below)
follows that seam exactly.

**Country resolution** (`lib/data/repositories/country_lookup.dart`,
`VenueCountry`) is name/flag/code only — no geographic dimension, cannot
be reused for distance calculations, only for country-level display/
fallback.

## Production Coordinate Coverage

Read-only census of all 27 production Events:

| | Count | % |
|---|---|---|
| With usable `latitude`/`longitude` | 19 | 70.4% |
| `NULL` coordinates | 8 | 29.6% |

By country: **NL** 17/23 with coordinates (73.9%); **non-NL** (SI, CH,
DK, PT — 1 each) 2/4 with coordinates (50%) — the Copenhagen (DK) and
Lamego (PT) Events are the two non-NL Events currently missing
coordinates.

The 8 NULL-coordinate Events, classified: all are legitimate,
intentional NULLs, consistent with this project's own established
enrichment discipline (documented in `DUTCH_EVENT_BATCH_2_FINAL.md`:
*"4 of 10... correctly remain `latitude`/`longitude = NULL`... all four
legitimate production Events with an external, uncatalogued host. No
city-centre or proxy coordinate was ever introduced."*). Coordinates are
populated only when an Event's host matches an already-catalogued
Restaurant/Hotel with its own verified coordinate; an Event whose host
isn't in the Michelin/Gault&Millau venue catalogue is left NULL rather
than guessed.

**Near Me would currently hide a meaningfully material portion of the
catalogue — nearly 3 in 10 Events.** This is flagged explicitly as a
factor in the V1 recommendation (exclude, never proxy) and as an open
question about whether to invest in coverage before shipping broadly
(see "Open Decisions").

## Near Me Definition

Mantelier Events are rare, destination-worthy, and often intentionally
worth travelling for — a generic "restaurants within 5 km" model would
be wrong for this catalogue and would likely return near-empty results
given current density (19 coordinate-bearing Events across mostly one
country). Evaluated:

- **A. Fixed radius** — simplest, most predictable, easiest to reason
  about and test.
- **B. Selectable radii** — adds real UI complexity (a control, its own
  state, its own tests) for a catalogue this sparse; premature.
- **C. Adaptive radius** (expand until N results) — appealing for a
  sparse catalogue, but adds non-trivial query/UX complexity (does the
  radius silently change? is that shown?) for a V1.
- **D. Region/city context instead of a literal radius** — conceptually
  closer to how a human describes "near me" for destination travel, but
  requires a geocoding/region-lookup capability this app doesn't have
  yet.
- **E. Hybrid** — worth revisiting once B or C's complexity is justified
  by real usage.

**Recommendation: A — a fixed, generous, non-user-adjustable V1 radius
(~100 km)**, deliberately wide enough to read as "this region" rather
than "walking distance," matching the catalogue's own destination-worthy
character. Selectable (B) or adaptive (C) radii are reasonable N3+
enhancements once real usage data exists to justify the added
complexity — not decided now.

## Radius Model

V1: one fixed constant, not exposed as a user control at all (`Near me`,
no visible "· 100 km" suffix needed initially, though the control could
still silently carry that value internally). Exact value (100 km
recommended, not finalized) is a product call — see "Open Decisions."
This mirrors the Date control's own "commit immediately, no configuration
UI" simplicity rather than the advanced-Filters sheet's richer draft
model.

## Distance vs Relevance

Evaluated: (A) filter only, Step 8A ranks unchanged; (B) filter and sort
by distance; (C) distance becomes a Step 8A signal; (D) other.

**Recommendation: A, unconditionally, for V1 — and this is a strong
recommendation, not a placeholder.** Step 8A's hierarchy (Trip > Friend
Going > Followed Host > Friend Interested > Popularity > Chronology)
encodes exactly the personal/social signals this product has already
decided are stronger predictors of "worth attending" than raw proximity.
Worked example, reasoned explicitly: an Event 20 km away that the user is
travelling to for a Trip, or that a friend is Going to, should
*absolutely* outrank an Event 5 km away with no such signal — a
destination-worthy dinner a user's friend is already attending is more
relevant than an anonymous nearby one, exactly the same logic Step 8A
already applies to city/country distance today (an Event isn't demoted
for being far from home if a friend is going). Turning proximity into a
new ranking tier (C) or even a same-tier distance tiebreak (B) would
silently re-order results in a way today's users have never experienced
and haven't approved — explicitly out of scope for this audit and for
any V1 implementation, per the task's own instruction. Near Me's only
job is **inclusion** (which Events are even candidates), identical in
kind to how Country/Type/Theme/Social already narrow the candidate set
before Step 8A ever runs.

## EventLocationContext Evolution

Do not build a premature `NONE/COUNTRY/CITY/CURRENT_LOCATION/TRIP` enum
now — City and Trip modes aren't approved features yet, and an enum with
unused arms is exactly the "invent structure for hypothetical future
requirements" pattern this project's own conventions warn against.

**Minimum required state for Near Me specifically**: a resolved query
predicate — center latitude, center longitude, radius — nothing more.
Recommended shape: add one new, optional, mutually-exclusive field
alongside `EventLocationContext.country` (e.g. a `nearMe` field carrying
a small `{latitude, longitude, radiusKm}` value object), so `country` and
`nearMe` are never both set — exactly mirroring the Date control's
already-established "one dimension, selecting either replaces the other"
contract (Correction Pass). `countryCodes` stays untouched for the
country mode; a parallel `resolvedNearMePredicate`-shaped getter would be
the seam a future server-side radius query reads from — never forcing
distance into the `countryCodes: Set<String>` shape, exactly as
`EventLocationContext`'s own existing doc comment already anticipates.

**Should precise coordinates live in UI state only, converted
immediately into a query, rather than retained broadly in application
models?** **Yes — this is the recommended direction, explicitly.**
Precise coordinates should be resolved once per lookup (a device read),
held only in the Events screen's own ephemeral session state (exactly
like `_query`/`_location`/`_dateRange` today — plain `State` fields, no
persistence), used immediately to build one query (a Dart-side Haversine
filter or, later, an RPC parameter), and never written into
`EventDiscoveryFilters` as a stored, retained value beyond that one
query's lifetime, never persisted to Supabase, never logged.

## Search / Date / Filter Composition

Unchanged AND-composition principle, extended to include Near Me as
Location's new alternate mode:

- **Near me AND search "wine"** — search narrows within the radius-
  filtered candidate set, exactly as it already narrows within a country
  selection today.
- **Near me AND search "Amsterdam"** — same; the search text is never
  interpreted as an implicit location-context change (explicitly
  rejecting any "detect city names in search and auto-set Location"
  behavior — this would silently override an explicit Near Me selection,
  which the Correction Pass's own core principle already forbids for
  every other dimension pair).
- **Near me AND Date AND Wine AND Friends Going** — all four (five,
  counting Search) dimensions AND together exactly as today; Near Me
  simply supplies a different predicate shape (distance-from-point)
  where Country currently supplies `country_code IN (...)`.

## Manual Location Interaction

**Near Me and manual Country selection are the same dimension, mutually
exclusive** — selecting Near Me replaces a prior Country selection;
selecting a Country replaces an active Near Me selection. This is a
direct extension of the Location control's own existing single-active-
mode behavior (today: only Country exists; tomorrow: Country XOR Near
Me), and mirrors exactly the "tap a new Date preset replaces the old
one" contract already shipped and approved. No hidden, simultaneously-
active, contradictory location predicates are ever allowed.

## Trip Context

Step 8A already has full Trip awareness — untouched by any of this.
Evaluated: should Location eventually offer an explicit "Maastricht —
Upcoming trip" one-tap shortcut? **Plausible real value** (directly
serves the stated product goal — "a natural extension of the existing
Location control") **but not decided here, and explicitly deferred**
(N3, see "Implementation Phases"). If built, selecting it would set
Location (to the trip's destination — country, or city once City exists)
and optionally Date (the trip's own date range) — never Step 8A itself,
which already independently knows about the same Trip. This is a UI
convenience for setting discovery context faster, not a new ranking
concept.

## Default Location Strategy

Evaluated options A–F. **Recommendation: F, a hybrid precedence — not
implemented now, a design note only**:

1. **Explicit manual selection always wins.** If the user has picked a
   Country (or, later, City) or Near Me this session, nothing silently
   overrides it.
2. **An active/upcoming Trip may be offered as a one-tap suggestion**,
   never auto-applied without the user choosing it (see "Trip Context").
3. **Current location, once built, may become session-default only with
   prior explicit permission already granted** — never a silent first-
   time default; permission must always be requested contextually first
   (see "Permission UX").
4. **Last-used location may improve returning-user continuity** — a
   reasonable future enhancement, not decided here.
5. **The ultimate fallback is "All locations" (global), never a guessed
   country.** Mantelier's own stated international-appeal goal means
   silently narrowing new/returning users to Netherlands (today's data
   skew) by default would be actively wrong — nothing in this
   architecture should hardwire that, and V1's actual default
   (`EventLocationContext.any`) already correctly does not.

## Permission UX

**Recommendation: contextual request only (Option A)** — no permission
prompt at app launch or anywhere before the user explicitly taps "Near
me." A short, honest explanation of *why* ("to show Events happening
near you") should precede the system prompt, then the real OS dialog —
never manipulative copy, never a prompt disguised as something else.

States to handle explicitly (design only):
- **Denied once** — iOS/Android system permission dialogs are one-shot;
  a decline typically requires the user to open Settings for another
  chance. Show a calm message with a "Open Settings" affordance,
  alongside — always — full manual Location availability.
- **Location services disabled device-wide** — a distinct state from a
  per-app denial (no permission dialog even fires); same calm fallback
  messaging, correctly distinguished from a plain per-app denial.
- **Approximate-location-only** (iOS 14+ "Precise: Off") — fully
  acceptable and should be explicitly requested at reduced/coarse
  accuracy anyway (see "Battery/Performance") — city/region-radius
  discovery never needs precise location.
- **Permission revoked later** — the next Near Me attempt simply
  re-detects the current (denied) state and shows the same fallback; no
  special-casing needed beyond re-checking status each time.

## Privacy

- **Store user coordinates in Supabase?** No — V1's client-side model
  never needs to persist a coordinate server-side at all.
- **Coordinates in analytics?** Never, under any circumstance —
  recommended V1 telemetry (see "Analytics") carries no coordinate value
  of any precision.
- **Should exact coordinates ever leave the device?** Not in the
  recommended V1 (pure client-side Haversine over an already-fetched,
  bounded Event list). A future server-side radius RPC would need to
  receive the coordinate as a transient query parameter (unavoidable —
  the database must know where "near" is relative to) but should never
  store it.
- **Should coordinates be rounded?** Yes — recommend rounding to
  ~2–3 decimal places (roughly 100 m–1 km) before any use beyond the
  immediate on-device distance calculation, since nothing in this
  product needs meter-level precision.
- **How long does location state live?** Session/screen-lifetime only —
  an in-memory field on the Events screen's own state, discarded on app
  restart, never written to disk or Supabase. No persistence in V1.

## Client vs Server Filtering

Evaluated at four scales:

- **27 / 100 Events**: client-side Haversine, in Dart, over the already
  date-windowed candidate list `EventsRepository.loadEvents` already
  fetches — trivially sufficient, zero new query infrastructure, no
  schema change.
- **1,000 Events**: still likely fine functionally, but fetching every
  upcoming Event just to distance-filter in Dart becomes wasteful. A
  reasonable defensive addition: a coarse SQL bounding-box pre-filter
  (plain `latitude BETWEEN`/`longitude BETWEEN` range predicates on the
  existing `double precision` columns — no PostGIS required) to narrow
  the fetch before exact Haversine distance is computed in Dart.
- **10,000 Events**: this is where genuine server-side spatial filtering
  becomes worthwhile — fetching a bounding-box-narrowed set client-side
  no longer scales cleanly, and a real radius predicate pushed into
  Postgres is the correct answer.

## PostGIS / Database Capabilities

**Directly verified via `pg_extension` (not assumed): PostGIS 3.3.7 is
genuinely installed and enabled on this database** — this corrects any
assumption that it might only be nominally present. Moreover, **it is
already in active, proven use**: `restaurants`/`hotels` (and their
`_full` views) each have a `location geography` column, each with a
populated GIST spatial index (`restaurants_location_gix`,
`hotels_location_gix`), and **100% of the 1,362 production restaurant
rows have that column populated**. However, **no radius/nearby query has
ever been built on top of it** — a targeted search of every migration
file for `ST_DWithin` (PostGIS's radius-predicate function) and every
`nearby`/`radius`-named function returns zero results; this geography
data exists (almost certainly seeded for a future Map/Explore capability)
but is entirely dormant today. `events` itself has only plain
`latitude`/`longitude double precision` columns — no `geography` column,
no spatial index — the same shape as `Restaurant`/`Hotel` had before
their own coordinate migration.

**Practical implication**: when server-side spatial filtering for Events
eventually becomes worthwhile (see above), the correct migration is a
direct, already-proven-safe mirror of the existing
`restaurants`/`hotels` pattern — add a `geography(Point, 4326)` column to
`events` (populated from the existing `latitude`/`longitude`), a GIST
index, and an `ST_DWithin`-based query or RPC. This is a real future
migration, not created here.

## NULL Coordinate Semantics

**When Near Me is active and an Event has no coordinates: exclude it
(Option A) — never fabricate a proxy (never a city-centre or country-
centroid guess).** This is the only option consistent with this
project's own hard-won, explicitly documented "no fake location"
discipline (see "Production Coordinate Coverage"). Because Near Me is an
optional, explicit, opt-in filter — never the default — a NULL-
coordinate Event is only ever invisible *within that one specific view*;
it remains fully discoverable via Search, Country, Date, and the
advanced Filters at every other time.

**Should the UI ever say "some Events may not appear because location is
unavailable"?** Recommend **not** adding this as a permanent disclaimer —
at today's ~70% coverage it would read as a persistent apology/caveat,
undermining the calm editorial tone. It becomes worth reconsidering only
if the exclusion rate stays this high once Near Me actually ships and
usage data shows real user confusion — a decision to make later with
real evidence, not preemptively now.

## Location UI Options

Three options evaluated for how "Near me" enters the existing Location
sheet:

1. **Flat list** — prepend a single "Near me" tile above the existing
   country list, using the sheet's own established `allowAll`-style tile
   pattern (`showCountryPickerSheet` already has an "All countries" tile
   at the top — "Near me" would sit directly above or below that,
   unchanged sheet structure otherwise).
2. **Grouped sections** — "Near me" / "Suggested" (a future Trip
   shortcut) / "Countries" as visually distinct labeled groups — closer
   to the product goal's own illustrative sketch, but adds structure for
   a Trip-shortcut feature not yet approved.
3. **A separate, always-visible sub-control** next to the Location
   button — distinct from the country-picker sheet entirely.

**Recommendation: Option 1 for the initial Near Me ship** — the smallest
possible change to an already-shipped, tested, physically-approved
sheet. **Option 2's grouped structure is the natural next evolution**
specifically if/when a Trip shortcut is separately approved and built
(N3) — building the grouped structure now, before that shortcut exists,
would be premature.

## Zero Results

**Recommend explicit recovery, never a silent change to the active
filter** — "No Events nearby" + an explicit action the user must
deliberately tap (e.g. "Show all locations"), never an automatic radius
expansion or automatic fallback to the global feed. This directly
extends the Correction Pass's own established principle (no dimension
silently overrides another, no ambiguous "Clear filters" that leaves
hidden context behind) to Near Me's own empty-result case.

## Failure / Loading

**Failure**: "could not determine your location" (permission denied, GPS
timeout, location services disabled) must be a visibly distinct state
from "no Events nearby" (location resolved successfully, zero radius
matches) — conflating the two would misrepresent a technical failure as
a legitimate empty result, the same category of honesty problem Phase C
already solved for taxonomy/social filter failures.

**Loading**: recommend keeping the current feed visible while location
resolves (never blank the whole Events screen for what could be a
multi-second GPS fix) — a small, self-contained loading affordance
scoped to the Location control itself, mirroring how the Date/Filters
controls already behave as self-contained interactions rather than
full-screen transitions.

## Cache / Freshness

- **Session-only in-memory cache** of the resolved coordinate —
  avoids re-triggering a GPS read on every rebuild, discarded on app
  restart. Not persisted to disk in V1.
- **Manual location persistence across sessions** and **"prefers Near
  Me" persistence** are each separate, real future product decisions —
  neither is implemented or decided here.
- **Freshness**: resolve once per Events-screen open (or an explicit
  manual refresh), never continuously. App-resume re-resolution is a
  plausible refinement, not required for V1.
- **No background location monitoring, ever** — Mantelier does not
  need continuous tracking for a destination-Event-discovery feature,
  and building it would be a significant, unjustified privacy/battery
  cost for zero product benefit here.

## Battery / Performance

Explicitly reject continuous GPS monitoring, background tracking, and
high/best accuracy requests. **Recommend requesting reduced/coarse
accuracy only** (`geolocator`'s `LocationAccuracy.reduced`/`.low`-
equivalent, matching iOS's own "Precise: Off" affordance) — city/region-
level radius discovery has no meter-level precision requirement, and
coarse accuracy resolves faster and costs meaningfully less battery than
a high-accuracy fix.

## iOS / Android

Documented future requirement, **not added now**:

- **iOS**: add `NSLocationWhenInUseUsageDescription` to `Info.plist`
  with a clear, honest, non-manipulative description (never
  `NSLocationAlwaysUsageDescription` — this feature never needs
  background access).
- **Android**: add `ACCESS_COARSE_LOCATION` to `AndroidManifest.xml`
  (not `ACCESS_FINE_LOCATION` — coarse accuracy is sufficient and
  preferable per "Battery/Performance" above).

## Event Data Quality

At ~70% coverage today, and given this project's own correct refusal to
ever fabricate a coordinate, **recommend future Event inserts continue
under Option C — coordinates strongly desired, but remain optional** —
consistent with the existing enrichment discipline (an external,
uncatalogued host correctly stays NULL rather than blocking the Event or
forcing a guess). Separately, and not a schema/constraint decision:
**coordinate coverage is worth treating as a soft enrichment KPI** to
improve before or shortly after Near Me ships broadly, since today's
~30% gap would otherwise make the feature meaningfully less useful than
the catalogue itself. This is a workflow recommendation, not a database
constraint change.

## Host-Created Events

Future host-submitted Events should ideally auto-derive coordinates from
a canonical, already-catalogued venue (a Restaurant/Hotel with its own
populated, verified coordinate) whenever the host IS one of those
catalogued venues — directly reusing the exact "copy the matched host's
own coordinate, never guess" precedent already established for manual
enrichment batches. For a genuinely external/uncatalogued host,
coordinates should remain optional at submission time (matching current
policy exactly) — though the submission form could still invite them
voluntarily to improve future Near Me coverage. No implementation or
validation-rule change is proposed here.

## Analytics

Recommend, for a future implementation phase (not built now), a
minimal, conservative set consistent with the existing analytics
contract's DO-NOT-TRACK discipline:

- `near_me_selected` — fired on tap, no coordinate payload.
- `location_permission_result` — a controlled enum
  (granted/denied/unavailable), never the raw OS permission object.
- `near_me_zero_results` — a boolean/count only.

**Never**, under any of these: raw coordinates, rounded coordinates, or
anything from which a precise location could be reconstructed.

## Performance

Covered in "Client vs Server Filtering" above — no new performance risk
introduced at current (27) or near-future (~100) scale; the risk profile
only changes materially in the 1,000–10,000-Event range, which is the
trigger point for the staged server-side migration path, not a V1
concern.

## Tests

Future required coverage (not written now), matching this app's own
established pure-vs-thin testing convention:

- Permission granted / denied / permanently denied / services disabled
  (each a distinct, mockable outcome of the permission abstraction).
- Current location resolves successfully.
- An Event with NULL coordinates is correctly excluded.
- Radius boundary (an Event exactly at / just inside / just outside the
  radius).
- A cross-border Event within radius (proximity, not country, decides
  inclusion).
- A date-only Event (no clock time) still works correctly under Near Me
  + Date composition.
- Near Me + Search, Near Me + Date, Near Me + Theme, Near Me + Social —
  each combination composes correctly (AND semantics, order-independent,
  mirroring the existing composition-regression test's own pattern).
- Switching Near Me → Country and Country → Near Me each deterministically
  replaces the other (never both active).
- Zero-result state.
- Location-failure state (distinct from zero-result).
- Stale/cached location behavior.
- Signed-out behavior (Near Me has no auth dependency — should work
  signed-out exactly like Country does today).

## Physical Device Plan

Future device-testing matrix (not run now): real current location; a
manually selected Country while Near Me is also available; permission
denied; location services disabled device-wide; and, if it can be done
safely, a simulated different location (iOS Simulator/Xcode location
override or Android emulator location injection) to verify radius
behavior without physically travelling.

## Schema Decision

**No migration required for Near Me V1.** The existing
`events.latitude`/`events.longitude` (`double precision`, nullable)
columns are sufficient for client-side Haversine filtering at current
and near-future (~100–500 Event) scale. A migration becomes necessary
only for the future server-side PostGIS stage (a new `geography` column
+ GIST index on `events`, mirroring the already-proven
`restaurants`/`hotels` pattern) — not proposed or created in this audit.

## Implementation Phases

Recommended staging, smallest-first:

- **Phase N1 — domain + abstraction, no live GPS, no UI.** Extend
  `EventLocationContext` with the Near Me seam (a mutually-exclusive
  field alongside `country`); write a pure, Supabase-free, geolocation-
  free Haversine distance/radius filtering function with full test
  coverage (mirroring `applyDiscoveryFilters`'s own pure-logic
  convention); define a small permission/geolocation abstraction
  interface so the concrete `geolocator` dependency doesn't leak into
  every call site (enables the pure logic to be tested without any real
  device/package dependency). No real user ever sees or triggers a
  permission prompt in this phase.
- **Phase N2 — real UI integration.** Add the `geolocator` package;
  add the iOS/Android permission declarations; wire a real "Near me"
  tile into the Location sheet (Option 1 above); implement the real
  permission-request flow, loading/failure/zero-result states; wire into
  `_effectiveFilters`; add the minimal analytics events. This is the
  first phase real users would ever see Near Me or be asked for
  permission.
- **Phase N3 — Trip-destination shortcut** (only if separately approved
  as having real product value) + the grouped Location-sheet structure
  (Option 2) it would justify.
- **Phase N4 — server-side spatial scaling**, only once catalogue scale
  genuinely warrants it: `events.location geography` column + GIST index
  + `ST_DWithin` query/RPC, mirroring the already-proven
  `restaurants`/`hotels` schema pattern.

## Risks

- **Coverage gap**: ~30% of today's catalogue is invisible under Near Me
  as designed (NULL coordinates, correctly never proxied) — could
  disappoint early users if shipped before coverage improves.
- **Permission friction**: a single decline effectively removes the
  feature for that user until they visit Settings — needs calm,
  occasional, non-nagging re-offering, never aggressive re-prompting.
- **Radius/naming expectation mismatch**: a deliberately generous ~100 km
  radius may not match what "Near me" implies from other (denser,
  restaurant-directory-style) apps — worth explicit copy consideration,
  not just a technical default.
- **Privacy discipline drift**: any future contributor adding analytics
  or logging must not accidentally introduce a raw-coordinate leak —
  mitigated by the same explicit DO-NOT-TRACK contract discipline
  already proven elsewhere in this app.
- **Scope-creep temptation**: building a visual Event map alongside Near
  Me is a natural-feeling but explicitly rejected non-goal for this
  feature (see "Non-Goals").

## Open Decisions

Requiring explicit human/product sign-off before Phase N1 begins:

1. The exact V1 radius value (this audit recommends ~100 km, not final).
2. Whether to invest in improving today's ~70% coordinate coverage
   before or alongside shipping Near Me.
3. Whether the Trip-destination shortcut (N3) has enough standalone
   product value to build at all.
4. The long-term default-location precedence (this audit sketches a
   hybrid — see "Default Location Strategy" — not finalized).

## Non-Goals

Explicitly not part of Near Me V1, and not implemented in this audit:
GPS/current-location code of any kind; permission requests; City
filtering; Trip-location shortcuts; an Event map/map-toggle UI; distance
display on `EventCard`; a radius slider/selectable-radius control;
background or continuous location tracking; any server-side/PostGIS
migration; any schema or RLS change; any production write; coordinate
persistence to Supabase; coordinates in analytics.

## Recommended Next Step

A human/product review of the four "Open Decisions" above — radius
value, coverage-investment timing, Trip-shortcut value, and long-term
default-location precedence. Only after that review should Phase N1
(pure domain + permission abstraction + distance logic, no real GPS, no
UI, no user-visible permission prompt) begin.
