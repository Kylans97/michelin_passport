# EVENTS V2 STEP 5 — MY MAP IMPLEMENTATION + COORDINATE ENRICHMENT PRE-APPLY REPORT

> **STATUS: APPLIED.** All proposed writes in this report's PROPOSED PRODUCTION WRITES section were approved and executed exactly as written ('t Preuvenemint, Wildfestival, and Vergeet Mij Niet Gala received their verified coordinates + address fields; Erloom × Henrique Sá Pessoa received its verified address only, latitude/longitude remain `NULL`/`MANUAL_REVIEW`). Physical-device review passed. See `EVENTS_V2_STEP_5_MY_MAP_FINAL_REPORT.md` for the finalization record — this document is kept as the historical pre-apply record and is otherwise unchanged.

## CANCELLED ATTENDANCE BUG

**Root cause**: `resolveAttendanceUiState()` (`lib/models/event_attendance_eligibility.dart`) checked `event.isCancelled` and `!_hasEnded(event, now)` *before* `hasConfirmedAttendance`. A genuinely-attended Event later marked cancelled fell through to `AttendanceUiState.none`, hiding rating, would-recommend, photos, "Edit your experience," and "Remove from Passport" on Event Detail — even though the underlying `event_confirmed_attendance` row and Passport listing were untouched.

**Fix**: `hasConfirmedAttendance` is now checked first, unconditionally. A confirmed attendance is a record of a past fact; a later change to the Event's own lifecycle state (cancelled, or a since-edited `end_at`) can never retroactively erase it. A cancelled Event with **no** confirmed attendance still correctly resolves to `none` — cancellation only ever suppresses the *prompt*/*manual* paths, never an attendance that already happened. `canAttendEvent()` (Interested/Going gate) was not touched — it already excludes any past or cancelled event, which structurally guarantees "no Going resurrection" on a My-Map-opened historical Event regardless of this fix.

**Tests**: 5 new cases in `test/event_attendance_eligibility_test.dart` (completed+confirmed, cancelled-after-the-fact+confirmed, cancelled+no-confirmed, future-cancelled+no-confirmed, cancelled+confirmed-with-future-dates-edge-case). All 24 tests in that file pass.

## MAP ARCHITECTURE

New map-owned domain model in `lib/features/map/models/`:

- **`map_pin.dart`**: `MapPinType` (`restaurant`/`hotel`/`event`) + sealed `MapPin` (`id`, `type`, `title`, `subtitle`, `latitude`, `longitude`) with `RestaurantMapPin`/`HotelMapPin`/`EventMapPin` variants. Each variant wraps the exact already-loaded domain object its own tap-through needs (`PassportVenueStats` for Restaurant/Hotel, `EventAttendanceEntry` for Event) — never a replacement for those types, purely an adapter for shared iteration/filtering/plotting. No Flutter import — unit-testable without pumping a widget.
- **`map_filter_type.dart`**: `MapFilterType` (`all`/`restaurants`/`hotels`/`events`), My Map's own local filter enum.

**Why `PassportVenue` remains untouched**: it has ~20 exhaustive switch dependents (documented precedent from Step 4's `EventAttendanceEntry`, which explicitly names My Map as a reason to keep Events additive). Extending it would force every one of those switches to grow an Events case with no benefit to them. `MapPin` solves My Map's actual problem — "iterate one heterogeneous list of plottable points" — without touching that type.

**Why not `ExploreVenueType`**: that enum is shared by Explore, Passport, Rankings, and Wishlist (confirmed via `grep`, 8 non-map files + 3 test files depend on it), none of which have an Events concept and none of which this task is allowed to touch. `MapFilterType` is a small, local, map-only enum instead.

## DATA FLOW

- **Restaurant/Hotel**: unchanged — `VisitedRepository.loadPassportVenues` (3 queries: visits, batched `restaurants_full`, batched `hotels_full`) + `MapRepository.loadRestaurantCoordinates`/`loadHotelCoordinates` (2 queries). `restaurantAndHotelMapPins()` adapts the resulting `PassportVenueStats` + coordinate maps into pins — same `PassportFilterResult.of` aggregation (multi-visit collapse) as before, requested with `venueType: ExploreVenueType.all` and filtered by `MapFilterType` afterward instead of before, which is behaviorally identical.
- **Event**: `EventConfirmedAttendanceRepository.loadPassportEventAttendance(uid)` reused as-is (3 queries: `event_confirmed_attendance`, batched `events`, batched `photos` for cover images) — no new repository method. Its `events` query is an unqualified `.select()`, so `latitude`/`longitude` were already loaded with **zero extra query**. `eventMapPins()` adapts entries whose Event has both coordinates into pins.
- **Query count**: 8 total per My Map load (3 + 2 + 3), unchanged in structure from before except the +3 for events. The event-attendance load is kicked off at the very top of `_load()`, concurrently with the venue-entries load and the coordinate loads that follow it, and only awaited at the end — maximal parallelism without added complexity. Never one query per pin, never one query per row.
- **Resilience**: an Event-attendance load failure is caught locally (`_loadEventEntriesSafely`) and degrades to an empty list, exactly mirroring `MapRepository`'s own "never take down the whole screen" convention for coordinate failures — Restaurant/Hotel pins render regardless.

## FILTERS

`ExploreVenueType.values` (3 chips) → `MapFilterType.values` (4 chips: All/Restaurants/Hotels/Events), same `CsFilterChip` + horizontal `SingleChildScrollView` — unchanged interaction pattern. Verified no overflow at 320px width and 1.6x text scale with all 4 chips (both the real screen's own scrollable row and a stricter non-scrolled raw-`Row` check inherited from the pre-existing test).

## EVENT PIN

`VenuePin` generalized from taking `PassportVenue` to taking `MapPinType` (its only use of the old parameter was an icon `switch` — a clean, minimal generalization). Restaurant/Hotel icons and colors are pixel-identical to before (deepGreen fill, ivory border/icon, 34px circle, no gold — proven by the pre-existing recolored tests, updated only for the new call signature). Event adds `Icons.event_rounded`, same circle, same colors — distinguishable by icon alone, no legend needed, no new marker shape.

## PREVIEW / NAVIGATION

Restaurant/Hotel: `showVenuePreviewSheet` — **completely untouched**, still keyed on `PassportVenueStats`, still navigates to `RestaurantDetailScreen`/`HotelDetailScreen`.

Event: new `showEventMapPreviewSheet` (`lib/features/map/widgets/event_map_preview_sheet.dart`) — a separate small component rather than forcing Event through `PassportVenueStats`'s shape (award row / visit count don't apply to a confirmed Event attendance). Same visual chrome (card, radius, padding, deepGreen CTA, no gold). Shows title, venue/city subtitle, date range (`formatEventDateRange`, reused from Event Detail), attendance rating if present, cover image if present. **No Interested/Going controls** — historical-attendance surface only. CTA "View event" → `Navigator.push(EventDetailScreen(eventId: ..., sourceSurface: AnalyticsSourceSurface.map))`, using the screen's existing constructor shape.

`_onPinTap` in `VisitedMapScreen` is an exhaustive `switch` over the sealed `MapPin` (analyzer-enforced — a 4th variant would fail to compile until handled), dispatching Restaurant/Hotel pins to the existing sheet and Event pins to the new one.

**Historical Event Detail** (§10): confirmed by tracing `EventDetailScreen`'s own logic — `EventIntentControls` (Interested/Going) render only `if (canAttend)`, and `canAttendEvent = !event.isCancelled && event.endAt.isAfter(now)`, which is false for *any* past or cancelled event. A My-Map-opened historical Event therefore never shows Interested/Going, regardless of the cancelled-attendance fix. `resolveAttendanceUiState` (post-fix) always resolves such an event to `attended` (since `hasConfirmedAttendance` is true by construction — that's the only way it got a pin), never `promptable` — so no post-event prompt either. Both guarantees are structural, not new code.

**Note on end-to-end navigation testing**: `EventDetailScreen`/`RestaurantDetailScreen`/`HotelDetailScreen` are all Supabase-eager (construct repositories against `Supabase.instance.client` in `initState`/field initializers), which throws in this sandbox without a live `Supabase.initialize()` — the same pre-existing limitation the codebase already accepts for the original Restaurant/Hotel preview sheet (its own "View restaurant" test checks label/color, never taps through). Full navigation is covered by the §27 physical-device checklist below, not a widget test.

## OVERLAP (§11/§24)

No clustering exists today and none was added — the task explicitly said not to invent complexity without evidence. `flutter_map`'s `MarkerLayer` renders one `Marker` per pin regardless of coordinate collisions; pins at an identical coordinate stack (last-in-list drawn topmost), and only the topmost intercepts taps until the user zooms/pans them apart. This is `flutter_map`'s own existing, unmodified behavior — verified at the model level (`test/map_pin_test.dart`'s "§24 overlapping coordinates" group: Restaurant+Event and two Events at the same coordinate both produce distinct, independently-addressable pins with no crash, no merge, no dropped pin). Documented here per the task's explicit "no clustering for MVP unless evidence shows pins are unusable" instruction; today's data (0 of 4 production Events currently plottable) gives no such evidence.

## PRIVACY (§12)

Not touched, and correctly so: `EventConfirmedAttendanceRepository.loadPassportEventAttendance` is always called with the current user's own `uid`, and RLS (`event_confirmed_attendance_select`) already scopes reads to `user_id = auth.uid() OR (visibility='friends' AND is_friend(user_id))` — since the caller and the row owner are the same person here, `visibility` never filters out the owner's own pin. No Friends/public map surface was built.

## ANALYTICS (§14)

No canonical `AnalyticsEvent` exists for "My Map opened" or "Event marker tapped" — none was added, per the explicit instruction to report the gap rather than invent one. Separately (pre-existing, not caused by this step): `AnalyticsEvent.eventOpened` — "fired once when a user explicitly navigates to and lands on Event Detail" — already exists in the contract but is **never actually called** anywhere in `event_detail_screen.dart` today (`grep` confirms zero `_analytics.track(AnalyticsEvent.eventOpened, ...)` call sites). My Map's navigation passes `sourceSurface: AnalyticsSourceSurface.map` into `EventDetailScreen`'s existing, already-unused `sourceSurface` constructor parameter — correct plumbing for when that gap is eventually closed, but it produces no signal today because the call site itself doesn't exist yet. Reported, not fixed — out of this step's scope.

## WEB READINESS

No platform-specific code added or touched. `flutter_map`/`latlong2`, `Image.network`, and every widget used here already run on web in this codebase's existing Restaurant/Hotel map path; nothing new was introduced that doesn't.

## COORDINATE ENRICHMENT

Current production `events` state (`supabase db query --linked`, 2026-08-21): all 4 events have `latitude = NULL`, `longitude = NULL` — confirmed unchanged since the prior audit.

| Event | Current venue_name | Proposed venue_name | Current address | Proposed address | City | Latitude | Longitude | Location evidence | Coordinate evidence | Classification |
|---|---|---|---|---|---|---|---|---|---|---|
| 't Preuvenemint | Vrijthof | *(unchanged)* | Vrijthof 25, 6211 LE Maastricht, Netherlands | *(unchanged)* | Maastricht | **50.849172** | **5.688419** | [Vrijthof — Wikipedia](https://en.wikipedia.org/wiki/Vrijthof) — public square, the event's own stated venue_name/address; explicitly **not** the linked "Tout à Fait" restaurant participant (a separate, nearby point) | Wikipedia infobox coordinate for the square itself | **VERIFIED_PRIMARY_LOCATION** |
| Wildfestival | Hotel Gastronomique De Echoput | *(unchanged)* | *(null)* | **Amersfoortseweg 86, 7346 AA Hoog Soeren, Netherlands** | Apeldoorn | **52.233211** | **5.877819** | Address corroborated by [Booking.com](https://www.booking.com/hotel/nl/gastronomique-de-echoput.html), [HotelPlanner](https://www.hotelplanner.com/Hotels/259556/Reservations-Hotel-De-Echoput-Apeldoorn-Amersfoortseweg-86-7346AA), [Veluwe.nl](https://veluwe.nl/en/location/hotel-de-echoput/) — "Hoog Soeren" is a hamlet within Apeldoorn municipality, consistent with the existing `city` value, no city change proposed | [De Echoput — Wikipedia](https://en.wikipedia.org/wiki/De_Echoput) infobox coordinate for the specific building | **VERIFIED_MAP_MATCH** |
| Erloom × Henrique Sá Pessoa | Erloom (bio-boerderij 't Schop) | *(unchanged)* | *(null)* | **Esbeekseweg 2, 5081 ED Hilvarenbeek, Netherlands** | Hilvarenbeek | *(withheld)* | *(withheld)* | Address corroborated by 5+ independent Dutch directory sources ([Huispedia](https://huispedia.nl/hilvarenbeek/5081ed/esbeekseweg/2), [Postcode.nl](https://www.postcode.nl/address/5081ED/2), [hetschop.nl](https://www.hetschop.nl/contact/), [AlleCijfers](https://allecijfers.nl/weg/esbeekseweg-hilvarenbeek/)) | No building-level geocode found — only a postcode-4 regional centroid (~2km precision), insufficient to place a farm building | **MANUAL_REVIEW** (address only — coordinates withheld) |
| Vergeet Mij Niet Gala | Hotel Okura Amsterdam (Grand Ballroom) | *(unchanged)* | *(null)* | **Ferdinand Bolstraat 333, 1072 LH Amsterdam, Netherlands** | Amsterdam | **52.348611** | **4.893611** | [Hotel Okura Amsterdam — Wikipedia](https://en.wikipedia.org/wiki/Hotel_Okura_Amsterdam), address confirmed by [HotelPlanner](https://www.hotelplanner.com/Hotels/125847/Reservations-Hotel-Okura-Amsterdam-Amsterdam-Ferdinand-Bolstraat-333-1072LH), [Yelp](https://www.yelp.com/biz/hotel-okura-amsterdam-amsterdam) | [Hotel Okura Amsterdam — Wikidata](https://www.wikidata.org/wiki/Q2065088) canonical coordinate (P625), cross-validated within ~20m by an independent Google Maps geocode of the same address | **VERIFIED_PRIMARY_LOCATION** |

No coordinates are guessed or interpolated. No participant/host/restaurant coordinates were substituted for any event's own location — 't Preuvenemint in particular uses the Vrijthof square coordinate, never "Tout à Fait"'s.

## PROPOSED PRODUCTION WRITES (pending approval — none applied)

```sql
-- 't Preuvenemint — VERIFIED_PRIMARY_LOCATION
update events set latitude = 50.849172, longitude = 5.688419
where id = '75d341a4-41d9-4e76-b47c-936048ae54a4';

-- Wildfestival — VERIFIED_MAP_MATCH
update events
set latitude = 52.233211, longitude = 5.877819,
    address = 'Amersfoortseweg 86, 7346 AA Hoog Soeren, Netherlands'
where id = 'eaad5729-e88c-47fa-b842-0343f6f794a2';

-- Vergeet Mij Niet Gala — VERIFIED_PRIMARY_LOCATION
update events
set latitude = 52.348611, longitude = 4.893611,
    address = 'Ferdinand Bolstraat 333, 1072 LH Amsterdam, Netherlands'
where id = 'fd23d7f5-ff7c-4caf-ba9b-a17e6397a607';

-- Erloom × Henrique Sá Pessoa — address only (MANUAL_REVIEW on coordinates,
-- withheld — no lat/lng write proposed)
update events
set address = 'Esbeekseweg 2, 5081 ED Hilvarenbeek, Netherlands'
where id = 'd09498ce-df42-4885-98d9-ec26fae5945c';
```

None of these have been run. All four remain `NULL`/unchanged in production as of this report.

## DATABASE

- Migrations: **0**
- Schema changes: **0**
- Production writes so far: **0**

## VALIDATION

- `dart format --set-exit-if-changed .` — clean (0 files would change).
- `flutter analyze` — 0 issues.
- `flutter test` — **1299 passed**, 0 failed (baseline 1266 + 33 new: 5 cancelled-attendance regression tests, 19 map-pin-model tests, 9 event-preview-sheet tests). No existing test was weakened; `test/visited_map_screen_test.dart` was updated only for the new `VenuePin`/`MapFilterType` signatures (same assertions, same coverage, plus new Event-pin/4-chip cases) and one now-unused fixture (`_hotel` in that file) was removed after the analyzer flagged it.

## FILES

**Modified**:
- `lib/models/event_attendance_eligibility.dart` — cancelled-attendance precedence fix.
- `lib/features/map/visited_map_screen.dart` — Event data source, unified pin list, 4-way filter, pin-type dispatch.
- `lib/features/map/widgets/venue_pin.dart` — generalized to `MapPinType`, added Event icon.
- `test/event_attendance_eligibility_test.dart` — 5 new regression tests.
- `test/visited_map_screen_test.dart` — updated for new signatures, extended for Event pin/4-chip coverage.

**New**:
- `lib/features/map/models/map_pin.dart`
- `lib/features/map/models/map_filter_type.dart`
- `lib/features/map/widgets/event_map_preview_sheet.dart`
- `test/map_pin_test.dart`
- `test/event_map_preview_sheet_test.dart`
- `docs/Architecture/EVENTS_V2_STEP_5_MY_MAP_PRE_APPLY_REPORT.md` (this report)

**Untouched, confirmed**: `PassportVenue`, Rankings, Wishlist, Trips, `ExploreVenueType`, navigation routing, every migration file.

## GIT

Nothing staged, nothing committed, nothing pushed. `git status`/`git diff --cached` confirm a clean staging area — all changes above are working-tree-only, exactly as instructed.

## §27 PHYSICAL-DEVICE REVIEW CHECKLIST

- [ ] My Map "All" filter shows Restaurants, Hotels, **and** Events together.
- [ ] "Events" filter shows only attended (confirmed) Events — never Interested/Going.
- [ ] Event pin is visually distinct from Restaurant/Hotel (calendar icon) without needing a legend.
- [ ] Tapping an Event pin opens the Event preview sheet (title, date, venue/city, rating if present).
- [ ] "View event" opens the correct `EventDetailScreen`.
- [ ] Historical confirmed Attendance state (rating, would-recommend, photos, "Edit your experience," "Remove from Passport") is visible and correct when opened from My Map.
- [ ] A cancelled-but-attended Event still shows as Attended, not none, when opened from My Map.
- [ ] An Event with missing coordinates never appears on the map, but its Attendance still shows correctly in Passport and Event Detail.
- [ ] Restaurant/Hotel pins, preview sheets, and navigation are pixel-identical to before this change.
- [ ] Map zoom/pan/camera-fit behavior is unchanged.
- [ ] No overflow at any device width or text-scale setting used during review.

## APPROVAL REQUEST

Requesting approval to apply the four `UPDATE` statements above (three full lat/lng writes classified `VERIFIED_PRIMARY_LOCATION`/`VERIFIED_MAP_MATCH`, plus one address-only write for Erloom × Henrique Sá Pessoa, whose coordinates remain `MANUAL_REVIEW` and are not proposed). No other production changes are requested.

---

EVENTS V2 STEP 5 — EVENTS × MY MAP IMPLEMENTED LOCALLY, COORDINATE ENRICHMENT VERIFIED, READY FOR HUMAN DATA-APPLY REVIEW
