# EVENTS V2 STEP 5 — FINAL REPORT

## PHYSICAL DEVICE APPROVAL

Verified on-device and approved: My Map's All/Restaurants/Hotels/Events filters, confirmed-Attendance Events appearing as Event pins (Interested/Going-only Events correctly absent), visually distinguishable Event pins, Event pin tap → preview → Event Detail, correct historical confirmed-Attendance state on Event Detail, unchanged Restaurant/Hotel map behavior, unchanged zoom/pan, no layout regressions.

## CANCELLED ATTENDANCE BUGFIX

**Original bug**: `resolveAttendanceUiState()` (`lib/models/event_attendance_eligibility.dart`) checked `event.isCancelled`/`!_hasEnded` before `hasConfirmedAttendance`, so a genuinely-attended Event later marked cancelled incorrectly lost its "Attended" state on Event Detail (rating, would-recommend, photos, "Edit your experience," "Remove from Passport" all became inaccessible) even though the underlying `event_confirmed_attendance` row and Passport listing were untouched.

**Final behavior**: `hasConfirmedAttendance` is checked first, unconditionally.
- Confirmed Attendance + cancelled Event → attended/history state remains visible.
- Cancelled Event + no confirmed Attendance → no attendance prompt, no manual "Add to Passport".
- Normal completed-Event behavior → unchanged.

5 regression tests added to `test/event_attendance_eligibility_test.dart`; all 24 tests in that file pass.

## MY MAP ARCHITECTURE

My Map owns its own map-specific model: sealed `MapPin` (`lib/features/map/models/map_pin.dart`) with `RestaurantMapPin`/`HotelMapPin`/`EventMapPin`, plus a local `MapFilterType` enum (`lib/features/map/models/map_filter_type.dart`). Final supported types: **Restaurant, Hotel, Event**.

`PassportVenue` remains untouched (still exactly `RestaurantVenue`/`HotelVenue`) — it has ~20 exhaustive switch dependents across Rankings, Wishlist, Trips, and elsewhere; extending it for Events would force every one of those unrelated switches to grow a case they have no use for. `ExploreVenueType` (shared by Explore/Passport/Rankings/Wishlist) was likewise not expanded — My Map's filter is its own small local enum instead. Rankings/Wishlist/Trips were not pulled into the new map domain at all.

Restaurant/Hotel map behavior is unchanged: same `PassportFilterResult.of` aggregation (multi-visit collapse), same coordinate source (`MapRepository`), same preview sheet, same navigation.

## EVENT ELIGIBILITY

A pin renders only when **all** of the following hold:
- a confirmed `event_confirmed_attendance` row exists for the viewer (via `EventConfirmedAttendanceRepository.loadPassportEventAttendance` — the confirmed-history repository, never `EventAttendanceRepository`, which owns pre-event Going/Interested intent), **and**
- `event.latitude != null`, **and**
- `event.longitude != null`.

Going-only: not eligible. Interested-only: not eligible. No confirmed Attendance: not eligible. No runtime geocoding, no host/participant coordinate fallback, no city-center fallback exists anywhere in the map feature (confirmed by grep — the only "geocoder" reference in the codebase is a doc comment stating one is never used).

## FILTERS

`MapFilterType`: All / Restaurants / Hotels / Events — same `CsFilterChip` + horizontal-scroll interaction pattern as before, verified with no overflow at 320px width and 1.6x text scale with all 4 chips present.

## EVENT PIN

Same 34px deepGreen/ivory circular `VenuePin` architecture as Restaurant/Hotel, generalized to accept `MapPinType` instead of `PassportVenue` (a Restaurant/Hotel-behavior-preserving change — the widget's only prior use of that parameter was an icon `switch`). Event uses `Icons.event_rounded` — distinguishable by icon alone, no legend, no new marker shape, no gold anywhere.

Tap → new `showEventMapPreviewSheet` (title, venue/city, date range, attendance rating if present, cover image if present, no Interested/Going controls) → "View event" → `Navigator.push(EventDetailScreen(eventId: ..., sourceSurface: AnalyticsSourceSurface.map))`.

## PRODUCTION EVENT LOCATIONS

| Event | Address | Coordinates |
|---|---|---|
| 't Preuvenemint | present (unchanged — already correct) | **50.849172, 5.688419** (Vrijthof square, verified) |
| Wildfestival | **applied** — Amersfoortseweg 86, 7346 AA Hoog Soeren, Netherlands | **52.233211, 5.877819** (De Echoput, verified) |
| Vergeet Mij Niet Gala | **applied** — Ferdinand Bolstraat 333, 1072 LH Amsterdam, Netherlands | **52.348611, 4.893611** (Hotel Okura Amsterdam, verified) |
| Erloom × Henrique Sá Pessoa | **applied** — Esbeekseweg 2, 5081 ED Hilvarenbeek, Netherlands | **NULL / NULL — MANUAL_REVIEW** (no building-level geocode found; intentionally omitted from My Map until verified) |

## DATA INTEGRITY

Read-only production verification (no writes this finalization pass):
- All 4 `events` rows re-read: coordinates/address match the approved apply exactly; `start_at`, `end_at`, `timezone`, `status`, `moderation_status`, `admission_type`, `official_url`, `ticket_url` all unchanged from the pre-apply baseline.
- `events` row count: 4 (unchanged).
- `event_restaurants`: 1, `event_hotels`: 0, `event_chefs`: 0 — host/participant relationships unchanged.
- `event_attendance`, `event_confirmed_attendance`, `photos`, `visits`, `planned_venues`, `follows` all read and consistent with organic app usage between turns — none affected by this workstream's writes, since every write this workstream made was scoped to `events.latitude`/`events.longitude`/`events.address` by exact `id` only.

## DATABASE

- Step 5 migrations: **0**
- Step 5 schema changes: **0**
- Finalization production writes: **0** (this pass was read-only verification only; the coordinate/address writes were applied and confirmed in the prior approval turn)
- Migration sync: `supabase migration list --linked` shows local == remote for all 35 migrations; `supabase db push --linked --dry-run` reports `"upToDate":true` — clean, nothing pending.

## VALIDATION

- `dart format --set-exit-if-changed .` — 0 files changed.
- `flutter analyze` — 0 issues.
- `flutter test` — **1299 passed**, 0 failed.

## FILES

**Added**:
- `lib/features/map/models/map_pin.dart`
- `lib/features/map/models/map_filter_type.dart`
- `lib/features/map/widgets/event_map_preview_sheet.dart`
- `test/map_pin_test.dart`
- `test/event_map_preview_sheet_test.dart`
- `docs/Architecture/EVENTS_V2_STEP_5_MY_MAP_AUDIT.md`
- `docs/Architecture/EVENTS_V2_STEP_5_MY_MAP_PRE_APPLY_REPORT.md`
- `docs/Architecture/EVENTS_V2_STEP_5_MY_MAP_FINAL_REPORT.md` (this file)

**Modified**:
- `lib/features/map/visited_map_screen.dart`
- `lib/features/map/widgets/venue_pin.dart`
- `lib/models/event_attendance_eligibility.dart`
- `test/event_attendance_eligibility_test.dart`
- `test/visited_map_screen_test.dart`

**Deleted**: none.

**Unrelated exclusions** (pre-existing, untouched, left unstaged): `docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md`, and everything under `supabase/data/enrichment/` (Michelin/Gault&Millau expansion, reconciliation, and location-enrichment research artifacts from separate workstreams).

## GIT

See commit hash / push confirmation in the chat response accompanying this report.

## NEXT

NEXT WORKSTREAM:
EVENTS V2 STEP 6 — FOLLOW
Restaurant / Hotel / Private Chef

Not started.
