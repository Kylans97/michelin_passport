# Events V2 Step 5 — Events × My Map Architecture Audit

**Status: READ-ONLY audit. No Dart code changed, no production data modified, no migration created, nothing staged/committed/pushed.** Confirmed at the start of this task: `git status --short` shows only the same 11 pre-existing unrelated untracked Michelin/Gault&Millau artifacts left over from prior workstreams; `HEAD` is `65506c89c74eecf4d020bd42541b245f13be5dab`, identical to `origin/main`.

## CURRENT MY MAP ARCHITECTURE

- **Screen**: `lib/features/map/visited_map_screen.dart` (`VisitedMapScreen`) — a `StatefulWidget` that constructs `VisitedRepository`/`MapRepository` eagerly against `Supabase.instance.client` (Supabase-eager, same established sandbox-test limitation as every other screen in this codebase).
- **Repositories**: `VisitedRepository.loadPassportVenues(userId)` (venue + visit data) and `MapRepository` (coordinate-only lookups, deliberately isolated — see below).
- **Domain models**: `PassportVenue` (sealed: `RestaurantVenue`/`HotelVenue` only), `VenueEntry` (one venue + its `List<Visit>`), `PassportVenueStats`/`PassportFilterResult` (from `passport_view_model.dart`) — **My Map reuses 100% of Passport's own model layer**, not a parallel one.
- **Marker/pin model**: `VenuePin` (`lib/features/map/widgets/venue_pin.dart`) — takes a `PassportVenue`, switches on its two cases for icon choice (`Icons.restaurant_rounded` / `Icons.vpn_key_rounded`).
- **Map package**: `flutter_map: ^8.3.1` + `latlong2: ^0.10.1` (OpenStreetMap tiles, `MapController`, `Marker`/`MarkerLayer`). **No clustering package** (`flutter_map_marker_cluster` or equivalent) is in `pubspec.yaml` — markers are plotted individually with no overlap handling beyond what per-venue collapsing already provides.
- **Coordinate handling**: coordinates are **not** part of `Restaurant`/`Hotel`/`PassportVenue` at all — `MapRepository` fetches them in a separate, minimal `select('id, latitude, longitude')` from `restaurants_full`/`hotels_full`, keyed by id, merged into the screen's own `Map<String, (double, double)>` state. Deliberately isolated (see the file's own header comment) so the coordinate migration's rollout state can never affect the shared `restaurantFullColumns`/`hotelFullColumns` every other feature depends on.
- **Marker tap → destination**: `VenuePin.onTap` → `showVenuePreviewSheet(context, stats)` (`venue_preview_sheet.dart`) — a bottom sheet showing name/location/award/visit-count/latest-visit, with a "View restaurant"/"View hotel" button that `Navigator.push`es to `RestaurantDetailScreen`/`HotelDetailScreen`.
- **Filtering**: `ExploreVenueType` (`all`/`restaurants`/`hotels`) — the **same enum Explore's own top-level selector uses**, rendered as `CsFilterChip`s, reused verbatim by both Passport and My Map.
- **Multiple visits to one venue**: collapsed to **one pin** — `PassportFilterResult.of` aggregates every `Visit` against a venue into one `PassportVenueStats` (`visitCount`, `latestVisit`, `averageRating`, `awardAtLatestVisit` — the venue's *most recent* award, not summed).
- **Missing coordinates**: silently excluded from `plottable` — `_coordsOf` returns `null`, the venue is filtered out of the marker list, but stays counted in `_visibleStats`/the empty-state logic (so "you have visited venues, some just don't have pins yet" never crashes or errors — it just renders fewer markers than entries).
- **`PassportVenue` dependency**: total — every model in the chain (`VenueEntry`, `PassportVenueStats`, `PassportFilterResult`, `VenuePin`, the preview sheet) is built around the sealed `RestaurantVenue`/`HotelVenue` pair.
- **Exhaustive switches over `PassportVenue`** found in **20 files**: `planned_trips_repository.dart`, `visited_repository.dart`, `wishlist_repository.dart`, `friend_profile_screen.dart`, `friend_visit_tile.dart`, `friend_wishlist_tile.dart`, `hotel_detail_screen.dart`, `visited_map_screen.dart`, `venue_pin.dart`, `venue_preview_sheet.dart`, `passport_screen.dart`, `passport_view_model.dart`, `plan_venue_sheet.dart`, `personal_rankings_tab.dart`, `restaurant_detail_screen.dart`, `planned_trips_screen.dart`, `trip_detail_screen.dart`, `planned_venue_row.dart`, `wishlist_venue_row.dart`, `wishlist_screen.dart`, plus `passport_venue.dart` itself. Dart's sealed-class exhaustiveness checking means **every one of these would need a new case at compile time** if `PassportVenue` grew an `EventVenue` variant.
- **Tests**: `test/visited_map_screen_test.dart` — covers `VenuePin` (colors, icon distinction, tap), the preview sheet's "View restaurant" button color, and a mirrored shell of the header (title/subtitle/filter chips/back button), matching this codebase's established "mirror the Supabase-eager screen's shell" convention.

## CURRENT DATA FLOW

```
Supabase (visits, restaurants_full, hotels_full)
  → VisitedRepository.loadPassportVenues(userId)   [visits table only — event_confirmed_attendance never touched]
  → List<VenueEntry>  (PassportVenue = RestaurantVenue | HotelVenue, + List<Visit>)
  → PassportFilterResult.of(...)  → List<PassportVenueStats>
  → MapRepository.loadRestaurantCoordinates / loadHotelCoordinates  [SEPARATE query, restaurants_full/hotels_full only]
  → VisitedMapScreen merges coords by id → LatLng
  → Marker(child: VenuePin(venue))
  → tap → showVenuePreviewSheet(stats) → Navigator.push(RestaurantDetailScreen | HotelDetailScreen)
```

**Passport and My Map do NOT share the same architecture as Events.** Passport's own Events section is already a second, fully independent, parallel path — confirmed directly from the committed code's own doc comment (`EventAttendanceEntry`, `event_confirmed_attendance_repository.dart`):

> *"Kept as a plain pair, not folded into a shared union with RestaurantVenue/HotelVenue's own PassportVenue/VenueEntry shape — Events V2 Step 4 deliberately keeps Passport's Event integration additive (its own section, its own load call) rather than extending the sealed PassportVenue type, so as not to force every one of that type's ~10 exhaustive switch sites (Rankings, Wishlist, Trips, **My Map**, Friend tiles) to grow an Events case as a side effect of this step."*

This sentence **already names My Map explicitly** as one of the sites Step 4 deliberately protected. Step 5 is not discovering a new constraint — it's the moment that already-anticipated decision gets acted on.

The parallel Events path already exists and is already committed:

```
Supabase (event_confirmed_attendance, events, photos)
  → EventConfirmedAttendanceRepository.loadPassportEventAttendance(userId)
  → List<EventAttendanceEntry>  (attendance: EventConfirmedAttendance, event: Event, coverPhotoUrl: String?)
  → PassportEventCard  (Passport's own additive Events section)
```

`Event.fromJson` already reads `latitude`/`longitude` (nullable `double?`), and `loadPassportEventAttendance`'s own `events` query is an unqualified `.select()` (all columns) — **the confirmed attendance's Event coordinates are already sitting in memory in `EventAttendanceEntry.event.latitude/longitude` every time Passport loads today.** Nothing new needs to be fetched for My Map to have this data — see PERFORMANCE.

## EVENT COORDINATE STATE

Live production query (read-only), all 4 events:

| id | name | venue_name | address | city | country_code | latitude | longitude | timezone | linked venue |
|---|---|---|---|---|---|---|---|---|---|
| `75d341a4-…` | 't Preuvenemint | Vrijthof | Vrijthof 25, 6211 LE Maastricht, Netherlands | Maastricht | NL | **null** | **null** | Europe/Amsterdam | 1 restaurant ("Tout a Fait"), `is_host=false` |
| `d09498ce-…` | Erloom x Henrique Sá Pessoa | Erloom (bio-boerderij 't Schop) | null | Hilvarenbeek | NL | **null** | **null** | Europe/Amsterdam | none |
| `eaad5729-…` | Wildfestival | Hotel Gastronomique De Echoput | null | Apeldoorn | NL | **null** | **null** | Europe/Amsterdam | none |
| `fd23d7f5-…` | Vergeet Mij Niet Gala | Hotel Okura Amsterdam (Grand Ballroom) | null | Amsterdam | NL | **null** | **null** | Europe/Amsterdam | none |

**All 4 of 4 production Events currently lack coordinates — 0% coverage, re-confirmed live, not assumed from an old report.** By contrast, `restaurants_full` is at **1362/1362 (100%)** coordinate coverage today (the Michelin bulk-location-enrichment workstream). This is a stark, real gap: **none of the 4 real Events can currently render a pin on My Map, even after Step 5 ships** — the very first confirmed Event Attendance (the physical-device test fixture, since removed) would also not have rendered a pin, since its Event had no coordinates either.

**Can currently render safely on My Map: 0 of 4.** "Safely" here means the coordinate-completeness rule (§MISSING COORDINATES below) — none would crash or error, they'd simply produce zero Event markers.

One linked-venue case is worth flagging concretely, since it's the exact scenario the location-snapshot rule exists to prevent: 't Preuvenemint links to restaurant "Tout a Fait" (`is_host=false`, itself fully geocoded at 50.8477/5.6921) — but 't Preuvenemint's own `venue_name` is "Vrijthof," a public square, not that restaurant. Falling back to the linked venue's coordinates here would silently plot the Event at the wrong location entirely (a participating restaurant's address instead of the square the festival is actually held in). No such fallback exists in any code today — confirmed by reading `event_confirmed_attendance_repository.dart` and `event.dart` in full.

## LOCATION SNAPSHOT RULE

**No implementation issue** — the rule is already fully honored by every relevant file:

- `Event.latitude`/`longitude` are already dedicated columns, populated (when present) at authoring/import time, never derived from a join.
- `EventConfirmedAttendanceRepository.loadPassportEventAttendance` already resolves `events` independently (`_client.from('events').select().inFilter('id', eventIds)`) — it has never joined through `event_restaurants`/`event_hotels` for location, and nothing about adding My Map requires it to start.
- The one production case with a linked venue (above) demonstrates *why* the rule matters, not a case where it's violated — no code path currently reads `event_restaurants`/`event_hotels` for coordinates at all.

The only real consequence of this rule for Step 5 is what it **rules out** as a shortcut: coordinates cannot be back-filled by reading a linked restaurant/hotel's own location, even where a link exists. Missing Event coordinates can only be closed by genuinely enriching `events.latitude`/`events.longitude` themselves (out of scope here — not performed).

## ARCHITECTURE OPTIONS

**A. Extend `PassportVenue` with an `EventVenue` case.**
Forces all **20 files** listed in CURRENT MY MAP ARCHITECTURE to gain a new exhaustive-switch arm at compile time, most of which (Wishlist, Trips, Rankings, Friend tiles, Restaurant/Hotel Detail's own switches) have **no relationship to Events at all** and would need an arm that's either dead code or a defensive `throw`/`SizedBox.shrink()`. `PassportVenueStats.awardAtLatestVisit` would need to invent a meaningless "award" for Events (they have no Michelin-star/Key equivalent); `visitCount`/`averageRating`/`List<Visit>` would need Events to either fake a `Visit` shape or special-case around it. This is precisely the shape of damage Step 4's own doc comment already predicted and avoided for Passport — doing it now for My Map would contradict a decision already made and shipped in this same codebase.

**B. Create/extend a dedicated My Map marker/domain model.**
A new, small, map-specific type — e.g. `MapMarkerEntry` or similar — built independently from `PassportVenue`, populated from **two already-separate sources** (`VisitedRepository.loadPassportVenues` for Restaurant/Hotel, `EventConfirmedAttendanceRepository.loadPassportEventAttendance` for Events), combined only at the screen/rendering layer. Zero new exhaustive-switch sites outside `lib/features/map/`. Every one of the 20 files above is completely untouched. Matches this codebase's own established "additive, own section" precedent exactly.

**C. Combine independent Restaurant/Hotel/Event datasets at the map layer only** (no shared domain type at all — `VisitedMapScreen` itself holds two parallel lists and a lightweight discriminated-union *only* for rendering, e.g. a `sealed class MapPin` with `VenueMapPin`/`EventMapPin` cases scoped entirely to `lib/features/map/`).
Effectively B taken one step further: instead of one shared "map entry" model consumed everywhere, the map screen assembles its own minimal pin list from the two existing repository calls it already has to make regardless. Still zero blast radius outside `map/`.

**D. No other architecture is strongly suggested by the current code.** The two live precedents in this codebase (Passport's own Events section, and the Restaurant/Hotel `VenueEntry` chain) are both single-purpose, feature-owned models — there is no existing generic "any Passport/Map-eligible thing" abstraction to extend, and inventing one now would itself be new, unrequested infrastructure.

## RECOMMENDED DOMAIN MODEL

**Option B/C combined, leaning C for the pin representation specifically**: keep `PassportVenue`/`VenueEntry` completely untouched, and give `lib/features/map/` its own small sealed pin type — e.g.:

```dart
sealed class MapPin {
  LatLng get point;
}
class VenueMapPin extends MapPin { final PassportVenueStats stats; ... }
class EventMapPin extends MapPin { final EventAttendanceEntry entry; ... }
```

— constructed in `VisitedMapScreen` from the **two already-existing repository calls** (`VisitedRepository.loadPassportVenues` + `EventConfirmedAttendanceRepository.loadPassportEventAttendance`, run in parallel, exactly like `MapRepository`'s coordinate futures already are). This is genuinely the smallest change: it reuses every existing model verbatim (`PassportVenueStats` for venues, `EventAttendanceEntry` for events — both already exist and are already tested), touches **zero files outside `lib/features/map/`**, and needs no new repository method (My Map calls two repositories that already exist, exactly as Passport itself already calls both today, just in two separate screen sections rather than one combined map).

**Downstream files affected by the recommended option**: only files under `lib/features/map/` (`visited_map_screen.dart`, `widgets/venue_pin.dart` → generalized or a new sibling `widgets/event_pin.dart`, `widgets/venue_preview_sheet.dart` → generalized or a sibling `event_preview_sheet.dart`) plus their tests. **Zero** files outside that directory.

## MARKER SEMANTICS

**Recommended: one confirmed Event Attendance → one Event marker** — directly supported by today's schema: `event_confirmed_attendance` has `unique(event_id, user_id)`, so at most one confirmed-attendance row can exist per (event, viewer) pair *today*. No new schema is needed to express this rule; it already holds structurally.

Working through the explicit edge cases:

- **Future multiple attendance records if uniqueness ever changes**: not possible without a migration removing/altering the `unique(event_id, user_id)` constraint — out of scope for Step 5, and if it ever happens, the natural extension is the same collapsing `VenueEntry` already does for repeat Restaurant visits (one marker, N attendances listed underneath) — no redesign needed later, just an aggregation step analogous to what already exists.
- **Multiple Events at identical coordinates** (e.g. two festivals at the same square in different years): each is its own confirmed attendance, its own marker — no dedup by coordinate, matching how two different restaurants that happen to share a building today already produce two separate pins (no precedent for coordinate-based merging anywhere in this codebase).
- **Event at the same coordinates as a Restaurant/Hotel** (plausible — a dinner event hosted at a Michelin restaurant, once that Event's own address is enriched to match): both markers render, independently, at the same point — visually overlapping, exactly as two Restaurant pins at the same address already can today. Not a new problem; this codebase has no clustering to begin with (see PERFORMANCE), so this is consistent with current behavior, not a regression.
- **Multiple Restaurant visits at the same coordinates**: already handled — one `VenueEntry`/one pin, unrelated to Events, unaffected by this change.
- **Clustering/overlap behavior**: none exists today for Restaurant/Hotel pins either — Step 5 does not need to invent it. If overlap ever becomes a real UX problem at scale, that's a pre-existing gap, not one Step 5 introduces.
- **Deleted confirmed attendance**: `EventAttendanceEntry` only exists because `loadPassportEventAttendance` found a row — deleting `event_confirmed_attendance` (already implemented, cascades `photos`) means the very next My Map load simply won't produce that entry. No special "remove pin" logic is needed beyond re-loading the same way Passport already does after a removal.
- **Cancelled Event that was genuinely attended**: the confirmed-attendance row is completely independent of `events.status` — a cancelled Event with a confirmed attendance still produces an `EventAttendanceEntry` and still has coordinates if they exist. **However**, see MARKER TAP below — a real, separate downstream issue exists here.
- **Historical Event whose canonical venue later changes**: zero effect, by the Location Snapshot Rule — the Event's own stored coordinates never change just because `event_restaurants`/`event_hotels` links change.

## MARKER TAP / NAVIGATION

Expected behavior (Restaurant → Restaurant Detail, Hotel → Hotel Detail, Event → Event Detail) is straightforward to implement: `EventDetailScreen` already exists, already takes an `eventId`, and is already the exact screen `PassportEventCard` navigates to today.

**One genuine, concrete navigation/lifecycle issue found — not caused by My Map, but directly relevant to a marker tapping through to it:**

`resolveAttendanceUiState` (`lib/models/event_attendance_eligibility.dart`, line 75) checks `event.isCancelled` **before** `hasConfirmedAttendance`:

```dart
if (event.isCancelled) return AttendanceUiState.none;
if (!_hasEnded(event, n)) return AttendanceUiState.none;
if (hasConfirmedAttendance) return AttendanceUiState.attended;
```

If an Event is ever marked `cancelled` **after** a user genuinely confirmed attendance to it, opening Event Detail (including via a future Event marker tap) renders `AttendanceUiState.none` — **the entire "Attended" management section (rating, would-recommend, photos, "Edit your experience," "Remove from Passport") silently disappears from Event Detail**, even though the underlying `event_confirmed_attendance` row (and therefore the Passport entry, and the future My Map marker) is completely unaffected and still fully present. The user could tap the marker, land on Event Detail, and see no trace of their own recorded attendance on that screen — while it's still correctly showing in Passport and (once built) on My Map. This is a pre-existing gap, currently unreachable in production (no Event is `cancelled` today — all 4 are `upcoming`), surfaced here because it would first become *reachable via a new entry point* once My Map can navigate to Event Detail. **Not fixed here** — read-only audit, reported per instruction.

Other checks:
- **Attendance state**: `_confirmedAttendance` is loaded independently in `EventDetailScreen.initState`-adjacent logic, not gated on how the screen was navigated to — a marker-driven navigation would load exactly the same way a Passport-card-driven navigation does today. No issue.
- **Edit your experience / rating / photos / removed attendance**: all keyed off `_confirmedAttendance`/`current.wouldRecommend`/`current.rating` — identical regardless of entry point. No issue.
- **Completed event behavior**: `canAttendEvent`/`_hasEnded` are both purely `endAt`-instant-based (never device-timezone-based, per the Step 4.1 timezone-hardening work) — a historical/completed Event opens correctly today via Passport already; a marker tap would exercise the identical code path. No issue beyond the cancelled-event gap above. Separately worth noting (not a blocker): `events.status` has no observed automatic transition to `'completed'` anywhere in this codebase — all 4 production Events are `status='upcoming'` despite the app's own `_hasEnded()` logic already treating "past `endAt`" as ended independently of the `status` column. This is an existing, unrelated data-lifecycle question, not something Step 5 needs to resolve.

## VISUAL LANGUAGE

Current `VenuePin`: 34px circle, `AppColors.deepGreen` fill, `AppColors.ivory` border (2px) + icon, drop shadow, `Icons.restaurant_rounded` (Restaurant) vs. `Icons.vpn_key_rounded` (Hotel) — the only visual differentiator between the two existing types is the icon glyph; fill/border/size are identical. No gold anywhere (confirmed by the existing test's own explicit "no gold" assertions).

**Recommendation for an Event marker**: follow the exact same pattern — same 34px circle, same `deepGreen`/`ivory` fill/border, a **third distinct icon** (e.g. `Icons.event_rounded` or `Icons.local_bar_rounded`/`Icons.celebration_outlined` depending on final taste — any glyph visually distinct from a fork/plate and a key at a glance). This is the minimum-viable differentiation that matches "distinguishable without a legend-heavy dashboard": three icon shapes inside one consistent pin treatment, no new color, no gold, no size change, no badge/label overlay. Explicitly **not recommended**: a differently-colored pin (would read as a second "system," undermining "understated luxury, one consistent visual language") or a text label under the pin (adds map clutter this codebase has consistently avoided elsewhere). This task does not redesign My Map — this is a recommendation for Step 5's own implementation to apply, not something built here.

## MISSING COORDINATES

Recommended behavior — directly extending the already-proven pattern `MapRepository`/`_coordsOf` use for Restaurant/Hotel today:

- The confirmed attendance still produces an `EventAttendanceEntry` (Passport is entirely unaffected — it never reads coordinates).
- No fake/placeholder/city-centroid coordinates are ever synthesized.
- No marker renders for that entry — the exact same silent-omission behavior `_coordsOf`/`plottable` already implement.
- No crash: `event.latitude`/`event.longitude` are already nullable in the model and already default to `null` via `fromJson`'s `(json['latitude'] as num?)?.toDouble()` — no new null-handling code is needed, only a null check at the marker-building step, mirroring `_coordsOf`'s existing shape exactly.
- **No user-facing error** is warranted or recommended — matching the task's own "do not expose a confusing user-facing error unless necessary" instruction, and matching Restaurant/Hotel's own current silent-omission precedent exactly.

**Diagnostics mechanism**: none exists today for this specific gap ("an entry has no coordinates"), for Restaurant/Hotel *or* Events. `MapRepository._loadCoordinates` only `debugPrint`s when the coordinate columns don't exist at all (migration-not-applied case) — it does not log/count *individual* venues missing coordinates once the column exists but is merely `null` for some rows. **No existing analytics event or internal diagnostic captures "N confirmed items have no coordinates."** This is a genuine, pre-existing measurement gap (not created by Events) — worth noting as a candidate for a future lightweight internal check (e.g. a one-off data-quality query against `events`/`restaurants_full`/`hotels_full`, exactly the kind of read-only audit this task itself performed), not a reason to build new production instrumentation now.

## PRIVACY

- **`VisitedMapScreen` is owner-only by call pattern, not by a dedicated "map visibility" concept.** `_load()` always queries `Supabase.instance.client.auth.currentUser?.id` — never a friend's id. There is no "view a friend's map" surface anywhere in this codebase (Friend Profile has its own separate `friend_activity_list_screen.dart`/visit-tile-based surfaces, architecturally distinct from `VisitedMapScreen`).
- `visits_read` RLS (`user_id = auth.uid() OR (visibility='friends' AND is_friend(user_id))`) and `event_confirmed_attendance_select` RLS are **structurally identical** — both already grant the row owner unconditional access to their own rows, **regardless of the row's own `visibility` value**. `visibility` (`private`/`friends`) only ever gates a *different* viewer's access; it has zero effect on what the owner sees.
- **Therefore**: for the user's own My Map, their own confirmed attendance is always visible to them, unconditionally, exactly matching the task's own stated expectation — this requires no new logic, since `EventConfirmedAttendanceRepository.loadPassportEventAttendance` already queries by `user_id = <the current viewer>` only, same as `VisitedRepository.loadPassportVenues` does today.
- **No broadening of friend/public visibility is implied or recommended.** My Map remains, after Step 5, exactly as owner-only as it is today for Restaurant/Hotel — Events would inherit that same boundary by construction (same call pattern: query only the current user's own id), not by any new privacy rule.

## PERFORMANCE

- **Current query count for My Map**: 3 today — one `visits` fetch, one batched `restaurants_full` resolve, one batched `hotels_full` resolve (per `VisitedRepository.loadPassportVenues`'s own doc comment) — **plus** 2 more from `MapRepository` (one `restaurants_full` coordinate fetch, one `hotels_full` coordinate fetch) = **5 total**, all already batched (`inFilter`), never one-per-venue.
- **Adding Events costs exactly the queries `EventConfirmedAttendanceRepository.loadPassportEventAttendance` already makes today for Passport**: one `event_confirmed_attendance` fetch, one batched `events` fetch, one batched `photos` fetch (for cover images — arguably unneeded for a map pin, could be skipped/parameterized off for the map's own call if cover photos aren't shown in an event marker's preview) = up to 3 more queries, run in parallel with the existing 5, not serially.
- **Coordinates can already be loaded in the same Event Attendance query** — confirmed directly: `loadPassportEventAttendance`'s `events` select has no explicit column list (`select()`), so `latitude`/`longitude` are already present on every `Event` object it returns, today, with zero additional query. **This is the single biggest performance win available**: unlike Restaurant/Hotel (which needed a deliberately separate `MapRepository` specifically because the shared `restaurantFullColumns`/`hotelFullColumns` constants don't include coordinates, to protect every non-Map feature from a not-yet-applied migration), Events' coordinate columns are **already deployed** and **already included** in the exact query Passport already runs — no `MapRepository`-style isolation is structurally necessary for Events, though mirroring the pattern for consistency is a reasonable stylistic choice, not a technical requirement.
- **Expected marker count scaling**: bounded by how many events a single user could plausibly confirm attendance to — realistically low tens at most for the foreseeable future (this is a curated, high-end events product, not a high-frequency feed). No pagination or virtualization concern at this scale.
- **Clustering**: none exists today, so it offers no protection either way — this is an existing characteristic of My Map, not something Step 5 changes.

**Recommended MVP query strategy**: run `VisitedRepository.loadPassportVenues(userId)` and `EventConfirmedAttendanceRepository.loadPassportEventAttendance(userId)` in parallel (two independent `Future`s, awaited together — the exact pattern `VisitedMapScreen._load()` already uses for its own `restaurantCoordsFuture`/`hotelCoordsFuture` pair), then build the map-specific pin list from both results once loaded. No new repository method, no N+1, no serial chain.

## ANALYTICS

Reviewed `docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md` in full. `AnalyticsSourceSurface.map` already exists as a controlled vocabulary *value* (usable to attribute e.g. a future `event_opened` fired from a marker tap as `sourceSurface: map`) — but **the taxonomy itself (§5) has no event for "My Map opened" and no event for "marker tapped"**, for Restaurant/Hotel *or* Events. Grepped `visited_map_screen.dart`/`venue_pin.dart`/`venue_preview_sheet.dart` directly: **zero analytics calls exist anywhere in current My Map code today.**

This means: **there is no asymmetry to fix.** My Map opening and marker-tapping are currently unmeasured for Restaurant/Hotel exactly as they would be for Events — adding Events does not create a new gap, it inherits the existing one. `event_opened` (already in the taxonomy, §5's Discovery section) is the one event that legitimately *would* fire once a marker tap navigates to `EventDetailScreen`, using the existing `sourceSurface: AnalyticsSourceSurface.map` value that's already defined and already unused for this exact purpose — no new event or property is needed for that specific step.

**No new analytics event is proposed.** If My Map's own open/marker-tap instrumentation is ever wanted, that is a pre-existing gap spanning Restaurant/Hotel too, reported here only as instructed, not acted on.

## WEB READINESS

The recommended architecture (Option B/C: a small map-specific pin type built from `PassportVenueStats` + `EventAttendanceEntry`, both already plain Dart data classes with no Flutter-widget dependency) is inherently web-portable in shape: "confirmed experience + coordinates → map representation" is exactly what it computes, with no Flutter/mobile-only state involved in the *decision* of what to plot — only the final `Marker`/rendering step touches Flutter. `Event.latitude`/`longitude`, `EventConfirmedAttendance`, and `PassportVenueStats` are all pure data models today, already reusable verbatim by a future web client's own business-logic layer (mirroring exactly how `photo_limits.dart`'s constants were placed under `core/` in Step 4 specifically for this reason).

**One web-readiness concern, not a blocker**: `flutter_map`/`latlong2` are Flutter-specific rendering packages — the map *widget* itself is obviously not portable, but that was never in question; the task's own framing ("not: Flutter widget state → map marker") is about the *decision logic*, which this recommendation keeps clean of Flutter dependencies. No other concern identified.

## DATABASE DECISION

**0 migrations required for Step 5's own scope.** Verified, not assumed:

- Marker semantics (one confirmed attendance → one marker) already hold via the existing `unique(event_id, user_id)` constraint — no new constraint needed.
- Coordinates already exist as columns on `events` (`latitude double precision`, `longitude double precision`, both nullable) — already deployed, already read by the existing Passport query.
- No new join, no new table, no new RLS policy — My Map's Event data would query `event_confirmed_attendance`/`events` exactly as Passport already does, under the exact same, already-deployed RLS.

**Separately, and explicitly out of scope for Step 5's implementation**: closing the *data* gap (0/4 production Events have coordinates) requires **enrichment, not schema** — writing real `latitude`/`longitude` values into the 4 existing `events` rows, using the same address/venue_name/city/country_code-driven geocoding methodology already proven extensively in this app's own Michelin bulk-location-enrichment workstream. This is a data-write task, not a migration, and is not performed here per explicit instruction ("Do NOT enrich or write coordinates yet").

## IMPLEMENTATION PLAN

Not building this now (read-only audit) — recorded here only as the audit's own conclusion, for the next task to execute against:

1. Add a small, map-owned sealed pin type in `lib/features/map/` (or a `models/map_pin.dart` if a non-widget file is preferred) wrapping `PassportVenueStats` and `EventAttendanceEntry` — zero changes to `PassportVenue`/`VenueEntry`/`ExploreVenueType`.
2. `VisitedMapScreen._load()` gains a third parallel future: `EventConfirmedAttendanceRepository.loadPassportEventAttendance(uid)`, awaited alongside the existing venue/coordinate futures.
3. Filter Event entries to those with non-null `event.latitude`/`event.longitude` before ever constructing a marker — mirroring `_coordsOf`'s existing null-safe pattern exactly, no new nullable-handling idiom invented.
4. Extend the marker-building loop to also emit one `Marker` per plottable Event entry, using a new `EventPin` (or a generalized `VenuePin` accepting the new sealed pin type) with a third icon.
5. Extend the tap handler to open a preview (either a generalized preview sheet or a new `event_preview_sheet.dart` sibling) → `Navigator.push(EventDetailScreen(eventId: ...))`.
6. Do **not** touch `ExploreVenueType`/the filter chips in this step unless a future task explicitly wants an "Events" filter tab — My Map's filter today is Restaurant/Hotel-only by design, and the task did not ask for a new filter category.
7. Data enrichment (writing real Event coordinates) is a separate, later task — until it happens, My Map will correctly show **zero Event markers** in production, safely, with no error state.

## TEST PLAN

Following this codebase's own established conventions (mirrored-shell tests for Supabase-eager screens, pure-function tests for eligibility/decision logic, real-widget tests for anything not Supabase-eager):

- **Restaurant markers unchanged** — re-run/extend `test/visited_map_screen_test.dart`'s existing `VenuePin`/preview-sheet/header groups unmodified; add a regression assertion that a Restaurant-only fixture set produces the same marker count/icon as today.
- **Hotel markers unchanged** — same, for `HotelVenue`.
- **Confirmed Event with coordinates appears** — pure test: given an `EventAttendanceEntry` with a non-null `event.latitude`/`longitude`, the new pin-building function includes it.
- **Going-only Event does not appear** — no `EventAttendanceEntry` is ever produced for a Going-only intent (confirmed by `loadPassportEventAttendance`'s own query, which reads `event_confirmed_attendance` exclusively — `event_attendance` rows are never touched) — assert the pin-building function only ever consumes `EventAttendanceEntry`, never `event_attendance`/intent data, so this is structurally guaranteed and should be asserted at the type level (no `EventIntentStatus` parameter exists on the new pin type).
- **Interested-only Event does not appear** — same reasoning/same test shape as Going-only.
- **Confirmed Event without coordinates safely omitted** — pure test: an `EventAttendanceEntry` with `event.latitude == null` is excluded from the pin list, and the overall entry count used for empty-state logic still reflects it was "attended," matching `_coordsOf`'s existing null-omission precedent.
- **Remove confirmed attendance → marker disappears** — reload-based: after `deleteConfirmedAttendance`, the next `loadPassportEventAttendance` call no longer returns that entry — assert at the repository/reload level, matching how Passport's own removal already works (no map-specific deletion logic needed).
- **Event marker tap → Event Detail** — widget test on the new pin/preview widget: tapping fires a callback that would navigate to `EventDetailScreen` with the correct `eventId` (mirroring `venue_preview_sheet_test.dart`'s existing "View restaurant" navigation-intent assertion shape).
- **Event at same coordinate as venue** — pure test: two pins (one `VenueMapPin`, one `EventMapPin`) at identical `LatLng` both appear in the built marker list — no silent dedup.
- **Multiple markers/overlap behavior** — pure test: N pins at/near the same point all appear in the list (no clustering exists to test against; assert only non-dedup, matching current Restaurant/Hotel behavior).
- **Completed historical Event opens correctly** — reuse/extend `event_attendance_eligibility_test.dart`'s existing `resolveAttendanceUiState` coverage with an explicit case asserting `AttendanceUiState.attended` for a long-past `endAt` with `hasConfirmedAttendance: true` — and add the new regression case this audit surfaced: `isCancelled: true` + `hasConfirmedAttendance: true` currently yields `AttendanceUiState.none`, which should be captured as a **documented known gap test** (`skip: true` with a comment referencing this audit, or an explicit "current behavior, flagged for follow-up" assertion) rather than silently left uncovered — matching this codebase's own practice of writing a regression guard for a known issue even before fixing it.
- **Owner can see private attendance on own map** — pure test: an `EventAttendanceEntry` with `attendance.visibility == private` still appears in the pin list when the query itself is scoped to the owner's own `userId` (i.e., assert the pin-building logic never filters on `visibility` at all — that filtering is RLS's job, already proven, not the Dart layer's).
- **No device-timezone dependency** — assert coordinate/pin-inclusion logic never touches `event.startAt`/`endAt`/`timezone` at all (it shouldn't — location and time are orthogonal); a companion assertion that `EventDetailScreen` navigation from a marker still renders the event-local time correctly (already proven by the Step 4.1 timezone-hardening test suite, not re-proven here).
- **Narrow/small-device behavior** — 320px width and 1.6x text scale for any new pin/preview-sheet widget, matching every other widget test in this codebase's own established pattern (`VenuePin`, `RecommendationSelector`, etc. all already do this).

## FILES

One audit document was written for this task: `docs/Architecture/EVENTS_V2_STEP_5_MY_MAP_AUDIT.md` (this file) — **left untracked, not staged, not committed**, per explicit instruction.

No other file was created or modified. No Dart source file was touched.

## GIT

Nothing staged, committed, or pushed. `git status --short` after this audit shows the same 11 pre-existing unrelated untracked artifacts from before this task plus this one new untracked audit document. `HEAD` remains `65506c89c74eecf4d020bd42541b245f13be5dab`, identical to `origin/main`. No `flutter test`/`flutter analyze`/`dart format` run was required or performed, since no code changed.

## RECOMMENDATION

Build Step 5 as **Option B/C**: a small, map-owned sealed pin type in `lib/features/map/`, populated from the two already-existing repository calls (`VisitedRepository.loadPassportVenues` + `EventConfirmedAttendanceRepository.loadPassportEventAttendance`) run in parallel — zero changes to `PassportVenue`, `VenueEntry`, `ExploreVenueType`, or any of the 20 files that exhaustively switch on `PassportVenue` today. This is the smallest, most consistent-with-precedent implementation, requires 0 migrations, and is correctly blocked on data (not code) from showing any real Event markers until at least one production Event is enriched with coordinates.

---

## Explicit answers

**1. Can Events be added to My Map without changing `PassportVenue`?**
**Yes.** A dedicated, map-owned pin type built from `PassportVenueStats` (existing) + `EventAttendanceEntry` (existing) requires zero changes to `PassportVenue`, `VenueEntry`, or any of their 20 dependent exhaustive-switch sites.

**2. Do we need a database migration?**
**No.** Coordinates, the one-attendance-per-event-per-user constraint, and the required RLS all already exist and are already deployed. Step 5's own scope needs 0 schema changes.

**3. Which production Events currently lack coordinates?**
**All 4 of 4** — 't Preuvenemint, Erloom x Henrique Sá Pessoa, Wildfestival, Vergeet Mij Niet Gala. 0% coverage, re-confirmed live against production, not assumed.

**4. What exact data enrichment is required before they can appear?**
Writing real `latitude`/`longitude` values into all 4 `events` rows, sourced from each Event's own `venue_name`/`address`/`city`/`country_code` (never a linked restaurant/hotel's coordinates, per the snapshot rule) — using the same geocoding methodology already proven in this app's Michelin bulk-location-enrichment workstream. Not performed in this task.

**5. What is the smallest safe implementation for Step 5?**
A new map-owned sealed pin type + one additional parallel repository call in `VisitedMapScreen._load()` + a null-coordinate filter (mirroring `_coordsOf`'s existing pattern) + a third pin icon + a marker-tap handler that pushes `EventDetailScreen` — entirely contained within `lib/features/map/`, 0 migrations, 0 changes to Passport/Rankings/Wishlist/Trips/Friends code, and correctly showing 0 Event markers today until coordinate enrichment happens separately.

---

**STOP.**
