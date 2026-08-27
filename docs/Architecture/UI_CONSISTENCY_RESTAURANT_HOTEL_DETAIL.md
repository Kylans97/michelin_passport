# UI Consistency Step 1 — Restaurant + Hotel Detail Redesign

Status: implemented, validated, and **physically approved on-device** (Steps 1B through 1G applied below). The Step 1E hotel-rating migration (`20260816120000_add_hotel_room_experience_ratings.sql`) is **deployed to production** — see the Backend Deployment section below for the full deployment record. This workstream is finalized and committed.

---

## RESTAURANT ENRICHMENT STEP 1D — PARKHEUVEL DETAIL COMPLETENESS + GENERIC CONTACT ACTIONS

Activates the `onCall` seam `VenueUtilityActions` gained back in its own Step 1D (below): `Restaurant` gained a nullable `phone` column (`restaurants` table + `restaurants_full` view, migration `20260819120000_add_restaurant_phone.sql` — the view is rebuilt with an explicit column enumeration rather than `select r.*`, since Postgres freezes a `SELECT *` expansion at view-creation time and a bare `r.*` cannot have a new base-table column inserted mid-sequence). Stored as human-readable international text (e.g. `"+31 (0)10 436 07 66"`), never a URI; `lib/core/utils/phone_utils.dart`'s `buildTelUri` derives a machine-safe `tel:` URI at call time, stripping formatting and the European `"(0)"` national trunk-prefix notation (dialed domestically, dropped when dialing with the country code — confirmed correct against a physical device: `tel:+31104360766` successfully reached Parkheuvel from Spain). `RestaurantDetailScreen` wires a real `onCall` callback whenever `buildTelUri` resolves one; `_openCall` only fires on explicit user tap, checks `canLaunchUrl` first, and hands off to the native Phone app (`LaunchMode.externalApplication`) — it never dials automatically. Hotel Detail still passes `onCall: null` — no `phone` field exists on `Hotel` yet, a natural future follow-up.

`RestaurantInfoCard`'s "LOCATION" section is renamed "PRACTICAL INFORMATION" and now shows the phone number (conditionally, trimmed, blank/whitespace treated as absent) alongside the address — the only place the number appears as text, since `VenueUtilityActions`' Call button is icon+label only. Website/Directions/Michelin Guide are deliberately not restated as text here, since they're already the tappable actions immediately above.

This is venue-*data* enrichment, not venue self-management — practical contact fields sourced and verified from primary sources (official site, official MICHELIN Guide page), applied by the same production-apply process as every other catalogue change. Mantelier's own verified recognition (MICHELIN stars, Gault&Millau, World's 50 Best) remains entirely separate data, untouched by this change.

### Files changed

**Modified:** `lib/models/restaurant.dart` (`phone` field), `lib/data/repositories/restaurant_repository.dart` (`restaurantFullColumns`), `lib/features/restaurants/restaurant_detail_screen.dart` (`_openCall`, `telUri` derivation), `lib/features/restaurants/widgets/restaurant_info_card.dart` (heading rename, phone line), `lib/core/widgets/venue_utility_actions.dart` (doc comment only — no behavior change, `onCall` API unchanged from its own Step 1D).
**Added:** `lib/core/utils/phone_utils.dart`, `supabase/migrations/20260819120000_add_restaurant_phone.sql`.

### Tests

`test/phone_utils_test.dart` (new, `buildTelUri` — formatting strip, leading-`+`-only-at-position-0, `"(0)"` trunk-prefix drop including the exact Parkheuvel value, a real area-code-in-parens is *not* mistaken for trunk notation, null-on-no-digits) and `test/restaurant_phone_test.dart` (new, `Restaurant.fromJson` — populated/null/missing-key `phone`) plus 4 new cases in `test/venue_detail_redesign_test.dart`'s `RestaurantInfoCard` group (heading text, phone shown, phone absent, blank phone treated as absent). Full suite: **1054 passing**, `flutter analyze` clean.

### Production deployment

Migration and the verified Parkheuvel `phone`/`website_url` values deployed to production; physically approved on-device (Call, Website, Directions, Michelin Guide all confirmed working, including a live international call from Spain reaching the restaurant) before this section was written.

---

## SCORE LABEL BASELINE + HEADER ALIGNMENT MICRO-FIX — STEP 1G

Applied on top of Step 1F after physical-device review surfaced two remaining alignment issues — the rings themselves were now correct and identical, but two things around them still weren't.

### Score labels — uniform typography, no independent scaling

Step 1F's fix (moving the ring outside any `FittedBox`) was necessary but not sufficient: each label was still individually wrapped in its own `FittedBox(fit: BoxFit.scaleDown)`, so "Experience" — the longest label — still picked a smaller scale factor than its siblings purely because of its own text width, independent of the other four columns. On-device this meant Experience visibly rendered smaller than Overall/Service/Room/Value even though every ring was now identical.

Fixed by removing every per-label `FittedBox` and replacing the per-column decision with one shared decision for the whole strip: `VenueScoreStrip` wraps itself in a `LayoutBuilder`, measures each dimension's label at the ambient `TextScaler` via `TextPainter` against the row's real per-column width, and — only if *any* label would overflow its column — sets one uniform `needsTwoLines` flag applied identically to every column (never per-label). The label style itself (`fontSize: 9`, weight 500, height 1.15, no letter-spacing) is a single `static final TextStyle` instance shared by every column, and the label-area height (`SizedBox(height: labelAreaHeight)`) is likewise computed once and applied uniformly. The net effect: all five labels — Hotel's Overall/Service/Room/Experience/Value, Restaurant's Overall/Food/Service/Wine/Value — are now visually indistinguishable in size, weight, and vertical position; only a genuine strip-wide width/scale constraint (not one label's own length) can ever change the shared layout, and when it does, it changes for all five at once.

### Score header — single-line alignment via measurement, not flex ratios

The Step 1D/1E header fix (`Row(Expanded(flex: 3), Flexible(flex: 2))`) was documented at the time as resolved, but physical-device review showed it still wasn't: a *fixed* 60/40 flex split allocates each side a share of the width regardless of what its content actually needs, so at normal phone width "SCORES  (Your latest stay)" alone exceeded its flex-3 share and wrapped internally to two lines — visually separating it from the date, which then sat beside only the first of those two lines.

Fixed by replacing the fixed ratio with a measurement-based decision, the same pattern used for the labels above: `VenueScoreHeader` uses `LayoutBuilder` + `TextPainter` to measure both halves' true single-line width at the ambient text scale, and renders a genuine single `Row` (`Expanded` left, plain right-aligned `Text`) only when they actually fit together in the available width. When they don't — reliably only at high text scale — it falls back to a deliberate `Column` stack (left cluster on top, date right-aligned beneath), never an uncontrolled wrap and never a silent overflow.

### Files changed (Step 1G, on top of Step 1F's own file list)

**Modified only:** `lib/core/widgets/venue_score_strip.dart` (`VenueScoreHeader` rewritten to measurement-based layout; `VenueScoreStrip`/`_ScoreColumn` rewritten to share one uniform label style/height instead of per-label `FittedBox`).

### Tests (Step 1G)

`test/venue_detail_redesign_test.dart` grew from 623 to **634 passing**: a new `VenueScoreStrip — uniform label typography` group (same `TextStyle` across all Hotel/Restaurant labels, Experience style == Overall style, no `FittedBox` remains anywhere in the strip, identical label-area height and vertical start position across all five columns, including under 1.6× text scale) and a new `VenueScoreHeader — single-line alignment` group (390px/1.0× single Row with the date anchored to the far-right edge and vertically centered with the left cluster, for both "visit" and "stay" vocabularies; 320px/1.0× right-edge anchoring preserved regardless of which layout is chosen; 390px/1.6× deliberate stacked fallback, never squeezed onto one line). `flutter analyze`: clean.

---

## SCORE RING GEOMETRY + NULL SCORE CONSISTENCY — STEP 1F

Applied on top of Step 1E after physical-device review found the Experience ring on Hotel Detail rendering visibly smaller than the other four rings.

### Root cause

`VenueScoreStrip` wrapped the *entire* `_ScoreColumn` (ring + label together) in one `FittedBox(fit: BoxFit.scaleDown)`. Since a `FittedBox` scales its whole child subtree by one uniform factor, the widest label in the row ("Experience") forced the smallest scale factor for its *own* column — shrinking that column's ring along with its label, even though only the label actually needed to shrink.

### Fix

The ring is now a fixed 40×40 `SizedBox` sitting entirely outside any `FittedBox` — it can never be affected by label width. Only the label itself is wrapped in its own `FittedBox` (superseded in Step 1G by a uniform, non-`FittedBox` approach — see above). This guarantees every ring in a strip is pixel-identical regardless of label length.

### Null-score geometry

Verified (not just assumed) that a `null` rating already renders with exactly the same 40×40 geometry as a populated one: `scoreProgress(null)` returns `0.0` (no foreground arc drawn — `ScoreRingPainter` only paints an arc when `progress > 0`), and the numeral renders as a centered `—` rather than a fabricated `0`, at the same position, same size, same column width as every other dimension.

### Files changed (Step 1F, on top of Step 1E's own file list)

**Modified only:** `lib/core/widgets/venue_score_strip.dart` (ring moved outside `FittedBox`, label given its own separate `FittedBox`).

### Tests (Step 1F)

`test/venue_detail_redesign_test.dart` grew from 616 to **623 passing**: a new `VenueScoreStrip — ring geometry independent of label length` group (Hotel and Restaurant rings all exactly 40×40 regardless of label; Experience ring size == Overall ring size; null-Room/null-Experience/null-Service rows preserve full ring geometry with no foreground arc; 320px/390px/1.6× text scale — ring size never changes, only the label may). `flutter analyze`: clean.

---

## PRODUCTION DEPLOYMENT — STEP 1E BACKEND DEPLOYMENT

Physical-device testing of Step 1E's five-dimension Hotel rating save path surfaced the anticipated `PGRST204: Could not find the "experience_rating" column of "visits" in the schema cache` — confirming the migration needed to go live before that path could work end-to-end. This task deployed `20260816120000_add_hotel_room_experience_ratings.sql` to production and verified it end-to-end, with git commit/push still explicitly out of scope (physical-device approval of the Step 1E UI changes was still pending at that point).

### Deployment protocol followed

1. **Read-only production preflight** — baseline schema/row counts recorded before any change.
2. **Migration state check** — `supabase migration list --linked` confirmed exactly one pending migration (`20260816120000`), no unrelated pending migration; STOP condition would have triggered otherwise.
3. **SQL re-audit** — the migration re-read in full immediately before applying, confirming it still matched the reviewed Step 1E version exactly (nullable smallint, `check between 1 and 10`, no default, no RLS/index changes).
4. **Rollback test** — the exact SQL run against production inside `BEGIN; … ROLLBACK;`, confirming the columns could be added and the schema verified as expected, then rolling back and re-confirming production was left byte-for-byte unchanged.
5. **Real apply** — `supabase db push --linked`, applied cleanly.
6. **Remote schema verification** — `room_rating`/`experience_rating` confirmed present, `smallint`, nullable, no default, with `visits_room_rating_valid`/`visits_experience_rating_valid` CHECK constraints exactly matching the migration.
7. **PostgREST schema-cache verification** — a direct REST API call using the shared repository's exact column list (`_visitColumns`) confirmed PostgREST had picked up the new columns (the specific failure class `PGRST204` represents), for both a Hotel-scoped and a Restaurant-scoped query.
8. **Controlled round-trip test** — insert/read/delete of a real five-dimension hotel-stay row on a disposable test account only; no real user data touched at any point.
9. **Existing-data regression check** — pre-existing rows confirmed to still read back correctly, both fields `NULL` as expected.
10. **Flutter runtime smoke test** — a release build launched on a physical device (`kylan`, UDID `00008140-001E09680CE2801C`); Xcode build and install succeeded.
11. **Hard stop before git** — no `git add`/`commit`/`push` performed; that authorization came only with this finalization task.

### Result

`supabase migration list --linked` now shows all 20 migrations synced local↔remote, including `20260816120000`. Production `public.visits.room_rating`/`experience_rating` are live, correctly typed and constrained, and confirmed reachable through the app's actual query path — not just the raw schema.

---

## HOTEL RATINGS + ACTION HIERARCHY — STEP 1E

Applied on top of Step 1D after a further physical-device review. Two categories of change: (1) Hotel gains the same five-dimension score presentation Restaurant already has, requiring a small additive schema change; (2) both screens' action hierarchy is restructured around four distinct intents that were previously all competing at the top of the screen.

### Audit findings (before any change)

- **Hotel rating persistence:** `public.visits` (polymorphic, `entity_type` discriminates) already carried `rating`/`service_rating`/`value_rating` for hotel stays, reusing the same columns restaurant visits use. No `room_rating`/`experience_rating` existed.
- **Restaurant rating persistence:** unchanged and untouched — `rating`/`food_rating`/`service_rating`/`wine_rating`/`value_rating`, all from the original schema + `20260805211243_add_visit_details.sql`.
- **Plan stay vs. Add stay — confirmed genuinely distinct, not duplicated:** `showPlanVenueSheet` creates/updates a `planned_venues` row via `PlannedTripsRepository` (future intention, optional trip association, check-in/check-out dates) — a completely different table and repository from `showAddStaySheet`, which creates a `visits` row via `VisitedRepository` (a completed historical record with ratings/notes/photos). Same audit performed for Restaurant (Plan visit vs. Add visit) — same conclusion. No STOP condition was hit; both actions are kept, in their new distinct hierarchy positions.
- **Duplicate Wishlist root cause:** `RestaurantActions`/`HotelActions` rendered a `ToggleActionButton` row containing *both* the visited/stayed toggle *and* a second Wishlist toggle, while `VenueDetailHero` already renders its own Wishlist icon in the top-right overlay. Two independent controls toggling the same underlying state.
- **Existing `SectionDivider` placement:** structurally correct (verified: exactly at named-section boundaries, never per-row) but the token itself, `AppColors.subtleBorderLight`, was found effectively invisible against the ivory canvas — see the color-fix note below.

### Hotel's five rating dimensions

Overall, Service, Room, Experience, Value — all on the existing 1-10 scale, matching every other rating column's exact shape (`smallint`, `check (... between 1 and 10)`, nullable, no default).

| Dimension | Product meaning |
|---|---|
| **Overall** | The guest's overall assessment of the stay. Entered independently — never algorithmically derived from the other four. |
| **Service** | Hospitality, attentiveness, professionalism, responsiveness, and quality of service throughout the stay. |
| **Room** | Quality of the room itself: comfort, design, finish, condition, overall room experience. |
| **Experience** | The broader hotel experience beyond the room: atmosphere, sense of place, facilities, design, character, how memorable the stay felt. |
| **Value** | Whether the experience justified the price paid. |

### Database migration — `20260816120000_add_hotel_room_experience_ratings.sql`

```sql
alter table public.visits
  add column room_rating smallint
    constraint visits_room_rating_valid
    check (room_rating between 1 and 10),
  add column experience_rating smallint
    constraint visits_experience_rating_valid
    check (experience_rating between 1 and 10);
```

- **Columns:** `room_rating`, `experience_rating`, both `smallint`.
- **Nullability:** nullable, no default — every existing row (restaurant and hotel alike) reads back `NULL` for both, exactly the historically correct state (nobody rated a dimension that didn't exist yet). No backfill.
- **Constraints:** identical shape to every existing sub-rating (`between 1 and 10`) — no new datatype, no new precision invented.
- **Existing-row impact:** none beyond the two new `NULL` columns — a metadata-only `ALTER TABLE`, safe on a populated table, no rewrite.
- **RLS impact:** none. `visits_read`/`visits_insert`/`visits_update`/`visits_delete` (see `production_schema_v1.sql` and `20260814120000_social_foundation_step2_visit_visibility.sql`) are all row-level policies keyed on `user_id`/`visibility` — they apply to every column on the row equally, exactly like `food_rating`/`wine_rating` needed no policy changes when they were added. Confirmed by reading both migrations in full before writing this one; no STOP condition was hit.
- **Indexes:** none added — these columns are never filtered or sorted on, only read back per-row, same as every existing rating column.
- **Deployment status: DEPLOYED to production.** Applied via `supabase db push --linked` in the Step 1E Backend Deployment task (see the section above) after a rollback-tested dry run; `supabase migration list --linked` confirms local and remote are synced for `20260816120000`.

### Local validation (production untouched)

The local Supabase stack was already running. `supabase migration up` (local-only, no `--linked`) was attempted first but hit the same pre-existing, unrelated seed failure this task anticipated: `20260810160000_create_events.sql` fails on a missing `countries` row for `'NL'` — nothing to do with this change, and per the task's explicit instruction, that seed data was **not** repaired. Instead, the migration's exact SQL was applied directly against the local database only (`supabase db query`, which the CLI confirmed connects to the local Postgres instance, not the linked project) — a narrow validation that doesn't require the full migration history to replay first:

1. `ALTER TABLE` applied cleanly.
2. Existing rows (0 locally) remain fully readable.
3. Inserted a real hotel-stay row with all five ratings (Overall 8, Service 9, Room 7, Experience 8, Value 7) — selected back with every value exactly round-tripped.
4. Attempted an out-of-range insert (`room_rating = 11`) — correctly rejected by `visits_room_rating_valid`.
5. Test row deleted; table confirmed back at 0 rows, exactly as found.

No production database was touched at any point (every `supabase db query` call logged "Connecting to local database..."). Unrelated finding surfaced by the CLI's own advisory output during these queries, reported here rather than acted on: `public.spatial_ref_sys` and `public.worlds_50_best_hotels` have RLS disabled locally — pre-existing, unrelated to this task, not fixed (the advisory tool itself warns not to auto-apply remediation without the user's own policy decisions).

### Historical-null score-ring behavior

Already correct without any change: `scoreProgress(null)` returns `0.0` (empty ring, no arc) and `_ScoreColumn` renders `'—'` for a `null` value — exactly the "intentional missing-rating state" the task calls for, verified rather than assumed, with a dedicated test (`ScoreRingPainter.progress == 0.0` for both Room and Experience on a historical stay, five-column geometry preserved, no fake `0`).

### Score header — true left/right separation

The Step 1D/1C `Wrap`-based header visually stuck the date to `"(Your latest visit)"` on-device. Root cause: `VenueScoreHeader` sits inside a `Column` with `crossAxisAlignment: start`, so `Wrap` was never stretched to the row's full available width — `WrapAlignment.spaceBetween` had no extra space left to distribute. Fixed by switching to a `Row` with two flex-bounded children (`Expanded(flex: 3)` left, `Flexible(flex: 2, textAlign: right)` right): an `Expanded`/`Flexible` child forces its `Row` to claim the full width offered by its parent regardless of the ancestor `Column`'s cross-axis alignment. Both sides remain flex-bounded rather than fixed-width, so each wraps internally instead of overflowing at any scale — no separate stacking fallback needed. Typography is now explicitly three-tier: "SCORES" (eyebrow) → "(Your latest visit)" (12px) → "Visited {date}" (11px, smallest, pure metadata).

### Action hierarchy — four distinct intents, one home each

| Intent | Control | Location |
|---|---|---|
| A. Save/Wishlist | Hero Wishlist icon (unchanged) | Hero only — the **one** canonical control |
| B. Venue utilities | `VenueUtilityActions` (Directions/Website/Michelin) | Own section, right after recognition |
| C. Planning | `SubtleTextAction` "Plan visit"/"Plan stay" | Own "PLAN YOUR VISIT"/"PLAN YOUR STAY" section |
| D. Recording a visit/stay | `SubtleTextAction` "Add another visit"/"Add your first visit" (or stay) | Inline, trailing the "YOUR VISITS"/"YOUR STAYS" eyebrow |

`RestaurantActions`, `HotelActions`, and `ToggleActionButton` are **deleted** — confirmed via grep to be fully unused anywhere else before removal. The large top-of-screen `[Add another stay] [Wishlist]` block is gone; Wishlist now exists in exactly one place per screen. First-visit/first-stay empty state uses "Add your first visit"/"Add your first stay" wording rather than hiding the action.

### Section order (both screens)

Hero → metadata/award-history → hairline → **Utility actions** → hairline → **Plan** → [hairline → **Scores** (if visited/stayed)] → [hairline → **About** (if data exists)] → hairline → **Your Visits/Stays** (+ inline Add) → [hairline → **Personal Photos** (if latest visit/stay)] → [hairline → **At This Hotel/Dining** (if applicable)] → [hairline → **Location** (if address exists)]. Every divider is unconditional relative to its own boundary, so no orphan hairline ever renders when an adjacent optional section is absent — verified structurally (§ tests below) and by re-reading the exact conditional nesting in both screens.

### Hairline visibility fix

`AppColors.subtleBorderLight` (`softStone`, `0xFFDED8CE`) was found nearly invisible against the ivory canvas (`0xFFF4F0E7`) on-device — both are light, low-saturation neutrals with barely any luminance gap. `SectionDivider` now uses `AppColors.taupe.withValues(alpha: 0.4)` — the app's own existing, already-accessible secondary-text token at reduced opacity, not a new arbitrary color. Thickness (0.75px) and placement (inset with the surrounding content margins, never full-bleed) are unchanged.

### VisitDetailScreen / StayDetailScreen

Not redesigned (out of scope, per the task). `StayDetailScreen` already displayed ratings via three repeated `RatingDisplayRow(label, value)` widgets (Overall/Service/Value) — a trivial, mechanical addition of two more (`Room`, `Experience`) was made so a saved rating is never invisible on that screen; this is the same widget, same pattern, not a redesign. `VisitDetailScreen` needed no change: Restaurant's dimensions are unchanged.

### Files changed (Step 1E, on top of Step 1D's own file list)

**Added:** `supabase/migrations/20260816120000_add_hotel_room_experience_ratings.sql`.

**Deleted:** `lib/features/restaurants/widgets/restaurant_actions.dart`, `lib/features/hotels/widgets/hotel_actions.dart`, `lib/core/widgets/toggle_action_button.dart` (all confirmed unused elsewhere before deletion).

**Modified:** `lib/models/visit.dart` (`roomRating`/`experienceRating` fields + `fromJson`), `lib/data/repositories/visited_repository.dart` (`_visitColumns`, `markHotelStay`, `_insertVisit`), `lib/features/stays/widgets/add_stay_sheet.dart` (five `RatingMeter`s), `lib/features/stays/stay_detail_screen.dart` (two more `RatingDisplayRow`s), `lib/core/widgets/section_divider.dart` (color fix), `lib/core/widgets/venue_score_strip.dart` (`VenueScoreHeader` layout fix), `restaurant_detail_screen.dart`/`hotel_detail_screen.dart` (full action-hierarchy restructure).

### Tests (Step 1E)

`test/venue_detail_redesign_test.dart` grew from 72 to 76 tests: a new `Visit model — Room/Experience ratings` group (historical-null deserialization, full round-trip deserialization, restaurant rows never carry the two hotel-only fields, a directly-constructed `Visit` defaults both to null); the Hotel score-strip test was corrected from its now-stale 3-dimension assertion to the real 5-dimension shape, plus a dedicated null-Room/null-Experience empty-ring test; the obsolete `ToggleActionButton` test group was replaced with a `SubtleTextAction` accessibility group (the control that actually ships now); the stale `SectionDivider` color assertion was updated to the new token; the gold-audit "Wishlist" test now targets the hero (the one remaining Wishlist control) instead of the deleted `ToggleActionButton`. Full suite: **616 passing** (612 baseline from before Step 1E), `flutter analyze` clean.

Full screen-level coverage of the action hierarchy (e.g. pumping `RestaurantDetailScreen` itself to assert "no body Wishlist CTA exists") remains blocked by this project's established constraint: those screens are `StatefulWidget`s that call `Supabase.instance.client` in `initState`, and there is no Supabase-mocking harness. The absence of a duplicate Wishlist control is instead verified by deletion (the only widget capable of rendering one, `ToggleActionButton`, no longer exists in the codebase) and by direct reading of both screens' current source.

### Deployment sequence (completed)

1. This migration and the Flutter changes were reviewed together (this report).
2. `20260816120000_add_hotel_room_experience_ratings.sql` was deployed to production (`supabase db push --linked`) — see the Backend Deployment section above for the full protocol and verification record.
3. The five-dimension Add Stay save path was then physical-device tested end-to-end and passed.

Testing the new Room/Experience save path against production before step 2 was completed did briefly fail with `PGRST204` (column not found) — the same failure class this codebase has hit before over a missing deployed column — which is exactly what prompted the Backend Deployment task. Everything else in this pass (layout, hierarchy, hairlines, Wishlist removal, existing historical-stay rendering) read correctly against production throughout, since it touched only already-deployed columns/screens.

---

## FINAL CLOVE CLUB SCORE + ACTION ALIGNMENT — STEP 1D

Applied on top of Step 1C after a positive physical-device review that flagged two remaining details: the score rings should visually communicate the score itself, and Michelin Guide belongs back in the compact action row (as Mantelier's answer to the reference's "Share").

### Proportional score ring

`_ScoreColumn`'s static-outline circle is replaced by a real progress ring, painted by a new `ScoreRingPainter` (`CustomPainter`, in `venue_score_strip.dart`) — a thin (3px) background circle in `AppColors.subtleBorderLight`, then a thin, rounded-cap `AppColors.forestGreen` arc starting at the top and sweeping clockwise for `progress` of the circumference. No gradient, no thick "dashboard" ring, no `CircularProgressIndicator` (built for indeterminate/animated use, not a static deterministic value — a hand-rolled `CustomPainter` was the smaller, cleaner fit, and no charting/progress package was added). Diameter stays 40px, unchanged from Step 1C.

The score→progress math is pulled into a standalone, unit-tested pure function:

```dart
double scoreProgress(num? value) {
  if (value == null) return 0.0;
  return (value / 10).clamp(0.0, 1.0).toDouble();
}
```

`ScoreDimension.value` widened from `int?` to `num?` so this stays correct for a decimal rating (`8.5 → 0.85`) even though every current `Visit` rating field is `int?` — nothing was changed on the model side, this is forward-safe typing only. Values are clamped to `[0, 1]`: a value above 10 or below 0 can never draw past a full circle or as a negative sweep, regardless of input. `ScoreRingPainter` was made a public (not library-private) class specifically so its `progress`/`foreground`/`background` fields are directly inspectable in tests, rather than needing a golden-image comparison for something this simple.

### Scores header

Replaced the two-line "SCORES" / "Latest visit · {date}" stack with a new `VenueScoreHeader` widget: left side "SCORES" (eyebrow) + "(Your latest visit)" (smaller, quieter), right side "Visited {date}" — using the app's own existing `formatVenueVisitDate` (full month name, e.g. "15 August 2026") rather than inventing a new abbreviated-date format just to match the reference screenshot literally, per the task's own "use actual current formatting conventions, do not hardcode the example" instruction. Hotel's header reads "(Your latest stay)" / "Stayed {date}", matching the screen's own existing YOUR STAYS vocabulary rather than reusing "visit" wording where it doesn't fit.

Layout uses `Wrap(alignment: WrapAlignment.spaceBetween)` rather than a `Row`: at normal width both halves sit on one line, right-aligned to the strip's own right edge (matching the reference); if the combined content doesn't fit — realistically only at 1.6× text scale — `Wrap` moves the right half to its own line beneath, a deliberate stacked fallback. This was chosen over manual breakpoint math because it's overflow-safe by construction: unlike a `Row`, whose non-flexible children never shrink and would throw a `RenderFlex` overflow if the fixed-width date text alone got too wide, `Wrap` never overflows in its cross axis and each child is free to wrap or reflow within its own given width.

### Utility actions — Michelin restored, Call prepared

Per the explicit product decision that Michelin Guide is more valuable to this app than Share, `VenueUtilityActions` gained back `onOpenMichelin` (icon `menu_book_rounded`, label `"Michelin"` — shortened from Step 1B/C's `"Michelin Guide"` to guarantee the one-line compact layout holds even at four items) and gained a new `onCall` parameter as a prepared seam: no `phone` field exists on `Restaurant`/`Hotel` today, so every call site passes `onCall: null` with an inline comment, mirroring the same "prepared, not built" pattern already established for `VenueAboutSection`. The row therefore renders 3 items today (Directions/Website/Michelin) and will automatically rebalance to 4 (Directions/Website/Call/Michelin) the day phone data lands — verified by a dedicated test pumping all four. Share was deliberately not added — lower priority than Michelin for this product, no existing share infrastructure, explicitly deferred per the task.

The standalone `SubtleTextAction("Michelin Guide")` link Step 1C introduced (when Michelin was temporarily pulled out of the row) is removed — Michelin lives in the row again, and "Plan visit"/"Plan stay" is the only remaining `SubtleTextAction` beneath it.

### Dividers — unchanged

Step 1C's `SectionDivider` placement (metadata/actions boundary, actions/scores boundary, scores/next-section boundary, etc.) is untouched — still exactly at named-section boundaries, never around the utility row itself (no box around it, per the task's explicit instruction).

### Files changed (Step 1D, on top of Step 1C's own file list)

**Modified only** (no files added or deleted this pass): `venue_score_strip.dart` (ring painter, `scoreProgress`, `VenueScoreHeader`), `venue_utility_actions.dart` (`onOpenMichelin`/`onCall` added back), `restaurant_detail_screen.dart`/`hotel_detail_screen.dart` (call sites updated, standalone Michelin link removed, header wired in).

### Tests (Step 1D)

`test/venue_detail_redesign_test.dart` grew from 54 to 72 tests: a new `scoreProgress` group unit-tests the pure calculation directly (10→1.0, 9→0.9, 7→0.7, 5→0.5, decimal 8.5→0.85, null→0, values above 10 and below 0 both clamped); the score-ring widget group replaced Step 1C's now-obsolete `Border`-based circle assertions with `ScoreRingPainter`-based ones (progress fraction per dimension, forest-green foreground, all rings identical diameter, no `CircularProgressIndicator` anywhere); a new `VenueScoreHeader` group covers both venue-type vocabularies and 320px/390px/1.6× responsiveness; the `VenueUtilityActions` group gained 3-item and 4-item layout tests plus a Michelin-specific tap/color test. Full suite: **612 passing** (594 baseline from before Step 1D), `flutter analyze` clean.

---

## CLOVE CLUB REFERENCE ALIGNMENT — STEP 1C

Applied on top of Step 1B after a second physical-device comparison directly against the Clove Club reference. Same rule as before: build on the existing implementation, never redesign from scratch, never copy the reference's data or bottom-nav labels.

### Score circles

`VenueScoreStrip` now renders each dimension inside its own small circular outline (`_ScoreColumn`, private to `venue_score_strip.dart` — genuinely shared between Restaurant's 5-dimension and Hotel's 3-dimension strip, so kept as one reusable primitive rather than duplicated per screen). Diameter is a fixed 40px, identical across every circle in a row; the border is a 1.2px `AppColors.forestGreen` outline — **never** a `CircularProgressIndicator`-style progress arc, and never gold. The numeral (17px, weight 600) is the visual focus inside the compact frame, with the label beneath in the same restrained eyebrow style as before. Public API (`ScoreDimension`, `VenueScoreStrip`) is unchanged from Step 1B, so both detail screens' call sites needed no edits.

Responsiveness is unchanged in mechanism from Step 1B — each column still sits in `Expanded` + `FittedBox(fit: BoxFit.scaleDown)`, so the circle+numeral+label scale down together rather than wrapping or overflowing. Re-verified at 320px, 390px, and 1.6× text scale for the 5-dimension restaurant case (the tightest fit).

### Editorial hairlines

New `SectionDivider` (`lib/core/widgets/section_divider.dart`) — a single reusable primitive (genuinely shared: identical treatment needed in both detail screens) carrying its own vertical spacing, so call sites insert one between sections rather than hand-stacking `SizedBox`+`Divider`+`SizedBox`. Always `AppColors.subtleBorderLight` at 0.75px, never gold. Placed at exactly the major-section boundaries, never between individual rows: metadata/award-history → actions cluster; actions cluster → Scores (or straight to Your Visits when Scores doesn't render — the divider before Scores/Your Visits is the same one, so no doubling); Scores → Your Visits; Your Visits → Personal Photos (conditional); → About (conditional); → At This Hotel/Dining (conditional); → Location (conditional on the venue actually having an address, so an empty-address venue never gets an orphan trailing hairline with nothing beneath it).

### Utility actions: Michelin Guide moved out

Per the task's explicit preference ("`Michelin Guide` may become an editorial text link elsewhere" rather than a fifth cramped action), `VenueUtilityActions` now takes only `onOpenMaps`/`onOpenWebsite` — strictly the reference's *universal* actions (Directions always, Website conditional; Call/Share still omitted, no phone data/share infra exists, confirmed unchanged from Step 1B). Michelin Guide is now a `SubtleTextAction` "Michelin Guide" link placed directly after the utility row (conditional on the venue having a Michelin URL) — same visual grammar already established for "Award history" and "Plan visit," reused rather than inventing a new link style. This also means the utility row is now at most 2 items, never at risk of the wrapping the previous "Michelin"/"Website" combination produced.

### Card chrome — re-verified, no further reduction needed

Scores, About, the utility row, and Location were already flat (no card) as of Step 1B. `VenueVisitRow`/`HotelStaysCard` rows and `LinkedVenueRow` keep their light `warmWhite`-filled containment, per the task's own explicit allowance ("Visit-history rows may remain lightly contained if that improves tap affordance"). `ToggleActionButton` keeps its filled/bordered shape because it is a literal button, not passive content — the task's chrome-reduction concern targets content sections, not interactive controls. No further changes were needed here.

### Awards summary — assessed, not added

The reference shows a compact Awards summary before Award History. Mantelier's hero already shows current Michelin recognition (primary) plus World's 50 Best/Hall of Fame (secondary badges) exactly once — adding a second on-page summary would violate the task's own explicit instruction not to show stars/W50B a third time (hero + a summary + Award History). Decision: **no new UI added** — the hero already is the "current snapshot," Award History already is the "chronology," and that two-part split was already correct. Verified by inspection, not by writing dead code.

### Bottom navigation — investigated, deferred with reasoning

Audited via a full read of `app.dart`'s `_MainNavigation` and a repo-wide grep of every `Navigator.push`/`Navigator(` call. Findings:

- **Architecture today:** one `Scaffold` holding an `IndexedStack` of the 5 tab roots (Passport/Explore/Rankings/Wishlist/Profile) plus a single persistent `NavigationBar` as `bottomNavigationBar`, all sitting at `MaterialApp.home`. No routing package (`go_router`/`auto_route`) is in `pubspec.yaml`, and **no nested `Navigator` widget exists anywhere in the app** (grep for `Navigator(` returns zero matches). Every screen — `RestaurantDetailScreen`, `HotelDetailScreen`, `AwardHistoryScreen`, `HotelAwardHistoryScreen`, and every other pushed screen in the app (~26 call sites total) — is pushed via `Navigator.push(context, MaterialPageRoute(...))` onto the single top-level `Navigator` that is an *ancestor* of `_MainNavigation` itself. That push therefore replaces the entire screen, nav bar included — there is no existing counter-example anywhere in the app of a pushed screen coexisting with the bottom nav.
- **What keeping the nav bar visible would require:** either (a) wrap each of the 5 tab roots in its own nested `Navigator`, and have every push that should stay "inside" a tab target that nested Navigator instead of the root one (Flutter's `Navigator.push(context, ...)` already resolves to the nearest ancestor Navigator, so this is architecturally sound, but requires restructuring `_MainNavigation` and auditing that none of the ~26 push call sites explicitly force `rootNavigator: true`), or (b) migrate to a shell-route-capable router — most cleanly `go_router`'s `StatefulShellRoute.indexedStack`, which gives the same nested-navigator-per-branch behavior with less hand-rolled plumbing.
- **Decision for this task: deferred, not implemented.** This is a change to the app's entire navigation architecture — every push in the app, not just these 4 screens — and the task's own instruction is explicit: "do not blindly refactor navigation if it risks breaking routing" and "if non-trivial, document the cleanest implementation and do not hack a duplicate nav bar." A migration of this size deserves its own dedicated task with its own review, not a drive-by change bundled into a visual-polish pass. **No duplicate/fake bottom nav bar was added anywhere** (confirmed by grep: no `BottomNavigationBar`/`NavigationBar` widget exists in `award_history_screen.dart`, `restaurant_detail_screen.dart`, or `hotel_detail_screen.dart`). Recommended path if/when this is picked up: option (a) above is the lower-risk incremental change; option (b) is the more durable long-term architecture if the app ever needs deep-linking too.

### Files changed (Step 1C, on top of Step 1B's own file list)

**Added:** `lib/core/widgets/section_divider.dart`.

**Modified:** `venue_score_strip.dart` (circle-based redesign), `venue_utility_actions.dart` (Michelin removed from the row), `restaurant_detail_screen.dart`/`hotel_detail_screen.dart` (dividers wired in, Michelin Guide moved to a compact link, utility-row call sites updated).

### Tests (Step 1C)

`test/venue_detail_redesign_test.dart` grew from 50 to 54 tests: the `VenueUtilityActions` group was rewritten for the Michelin-free API (plus a new "forest-green, never gold" check), a new `VenueScoreStrip — score circles` group asserts exactly one circular outline per dimension, all sharing one diameter, no `CircularProgressIndicator`, and a forest-green (never gold) border; a new `SectionDivider` group asserts the token color/thickness and that dividers appear only at intended boundaries, not per-row. Full suite: **594 passing** (590 baseline from before Step 1C), `flutter analyze` clean. Navigation itself has no new automated coverage — this project's established constraint (no Supabase mocking harness, documented since Step 1's own test strategy) already prevents pumping `RestaurantDetailScreen`/`AwardHistoryScreen` directly, and since no navigation code changed (the architecture change was deferred), there is nothing new to test; the "no duplicate/fake bottom nav" claim is verified by grep, stated above.

---

## PHYSICAL DEVICE POLISH — STEP 1B

Applied on top of Step 1 after the first physical-device review. Structural direction was approved; this pass is a visual-language refinement driven directly by on-device feedback, referencing the Clove Club design for information hierarchy, color balance, and score presentation only — never copied literally (no bottom nav, no fake data, no fabricated actions).

### Ivory / forest-green decision

Restaurant/Hotel Detail's main content area (everything below the hero) inverted from the Step 1 dark canvas to an **ivory canvas** (`AppColors.ivory`) with **forest-green** content (`AppColors.forestGreen` primary text/icons, `AppColors.taupe` secondary text, `AppColors.subtleBorderLight` hairlines, `AppColors.warmWhite` for the rare remaining tonal surface). The hero itself is unchanged — still the dark/gradient (or future-photo) treatment from Step 1, since §5 of the task explicitly allows the hero to "remain photograph/dark imagery-led." Award History inverts again, to a full **forest-green canvas with ivory content** (`AppColors.forestGreen` background, `AppColors.textOnDark`/`AppColors.secondaryOnDark` content), so navigating into it reads as a deliberate transition into a distinct "archive" experience.

### Michelin-only gold rule

A hard constraint audited across the entire touched scope: **gold appears nowhere except `StarRow` (Michelin stars) and `KeyRow` (MICHELIN Keys)**. Every other prior gold usage was reassigned:

| Element | Was | Now |
|---|---|---|
| Wishlist toggle (hero overlay) | `goldLight` active icon | `textOnDark`, state read via filled-vs-outline icon shape |
| `ToggleActionButton` (Wishlist/Add Visit/Add Stay active state) | `goldMuted` fill, `gold` icon/text | `forestGreen` fill, `textOnDark` icon/text |
| Success snackbar background | `AppColors.gold` | `AppColors.forestGreen` |
| Award History loading spinner / Retry link | `gold` | `textOnDark` |
| World's 50 Best "Best ranking"/rank text | `gold` | `textOnDark` (Award History) / removed with the rest of the old `*AwardsCard` (Detail) |
| `HallOfFameBadge` (fill/border/icon/label) | fully gold-themed | fully ivory-themed (`textOnDark` on a `textOnDark`-alpha-08 fill) |
| `MichelinAwardTimeline`'s timeline dot | `gold` | `textOnDark` — a structural marker, not a Michelin glyph itself |

A final grep across every touched file (`lib/features/restaurants`, `lib/features/hotels`, every new/modified `lib/core/widgets/venue_*` and shared narrow widget) confirms exactly two remaining gold references: `key_row.dart` and `star_row.dart`. `test/venue_detail_redesign_test.dart`'s "Color rule" group asserts this at the token level (never a pixel test) for the toggle, the linked-venue row, and both recognition rows.

### Utility action row

`VenueLinksRow` (boxed `CsSecondaryButton` pills — the previous generation's "Maps | Michelin | Website" that wrapped badly) is deleted, replaced by `VenueUtilityActions` (`lib/core/widgets/venue_utility_actions.dart`): a compact icon-above-label row, matching the reference's "DIRECTIONS · WEBSITE · CALL · SHARE" pattern. Only real, currently-available actions are ever shown — **Directions** (always), **Website** and **Michelin** (each conditional on the existing URL fields, unchanged logic). Call and Share are not offered: the app has no venue phone field on `Restaurant`/`Hotel`, and no share infrastructure (`share_plus` is not a dependency) — confirmed by reading both models and grepping for existing share code. No dead button, no fabricated data. Michelin Guide stays in the same row rather than being split into a separate editorial link, since three compact items never wrap at any tested width — verified by a dedicated 320px "no wrapping" test.

### Score-strip redesign

The single large `CircularScoreBadge` ring + "Latest visit" text block is replaced by `VenueScoreStrip` (`lib/core/widgets/venue_score_strip.dart`) — every actual rating dimension for the latest visit/stay, aligned on one horizontal row. Dimensions were read directly from the `Visit` model and both Add Visit/Add Stay sheets, not assumed:

- **Restaurant** (5 dimensions, matching `AddVisitSheet` exactly): Overall, Food, Service, Wine, Value.
- **Hotel** (3 dimensions, matching `AddStaySheet` exactly — hotels have no Food/Wine rating fields): Overall, Service, Value.

A missing optional dimension renders `—`, never a fabricated `0`. Each column is wrapped in its own `FittedBox(fit: BoxFit.scaleDown)` inside an `Expanded` — the numeral/label pair scales down together rather than wrapping or overflowing, so all dimensions stay on one row at every tested width/scale (320px, 390px, 1.6× — see Responsive below), rather than falling back to a second row or a horizontal scroll. `CircularScoreBadge` itself is deleted (confirmed unused anywhere else). The section header combines the eyebrow ("SCORES") with "Latest visit · {date}" on one line rather than repeating the date twice.

### About — product direction, no runtime scraping

Neither `Restaurant` nor `Hotel` has a `description`/`about`/`summary` column today (confirmed by reading both models in full — nothing exists to surface). `VenueAboutSection` (`lib/core/widgets/venue_about_section.dart`) is built and wired into both detail screens as a conditional seam: it takes `text: String?` and renders nothing (not a "No description available." placeholder) whenever the value is null/empty. Both screens currently call it with a local `aboutText = null` and an inline comment — the day a real editorial-copy field lands on the model, only that one line changes. **No migration was added in this task**, per the explicit instruction, and no runtime web scraping was introduced.

**Recommended future architecture** (documented, not built): official venue website → a controlled, offline enrichment pipeline → concise Mantelier-authored ABOUT copy → source URL/provenance stored alongside it → the app reads only from the database, same as every other field. Never: Flutter app → scrape the venue's own website on every page open. Reasons: performance (no per-view network fetch to a third party), reliability (venue sites change/break without warning), editorial control and consistent tone, copyright (scraped text is not ours to redistribute), and offline/cache behavior (a database field works with the app's existing caching; a live scrape does not).

### LOCATION section

`RestaurantInfoCard`/`HotelInfoCard` (previously an orphan icon+address line at the very bottom) now render as a proper editorial section — `LOCATION` eyebrow, then the address — matching every other section's treatment. City/country still lives exactly once, in the metadata line under the hero; this section is address alone, unchanged logic.

### Award History structure

`RestaurantAwardHistoryScreen`/`HotelAwardHistoryScreen` no longer use the shared `EditorialHeading`/`SectionLabel`/`DetailCard` (`detail_card.dart`) — those are hardcoded to the old ink-on-ivory typography and are still Category C (shared elsewhere: Events, Photos, Planning, Profile, Rankings, Trips, Visits, Restaurant/Hotel Detail's own remaining callers), so they were left untouched rather than modified for this one screen. Section headings ("MICHELIN HISTORY", "WORLD'S 50 BEST") now use the same inline `CsTypography.eyebrow` pattern established throughout Step 1/1B. Back navigation moved from `detail_hero.dart`'s shared `HeroIconButton` to `EditorialBackButton`, consistent with every other redesigned screen. `award_history_repository.dart`, its queries, and current/history semantics are completely unchanged — presentation only.

### Files changed (Step 1B, on top of Step 1's own file list)

**Added:** `lib/core/widgets/venue_utility_actions.dart`, `lib/core/widgets/venue_score_strip.dart`, `lib/core/widgets/venue_about_section.dart`.

**Deleted:** `lib/core/widgets/venue_links_row.dart` (superseded by `venue_utility_actions.dart`), `lib/core/widgets/circular_score_badge.dart` (superseded by `venue_score_strip.dart`).

**Modified:** `venue_detail_hero.dart` (wishlist gold removal), `toggle_action_button.dart` (full ivory-canvas reskin), `subtle_text_action.dart`, `personal_photos_preview.dart`, `venue_visit_row.dart`, `linked_venue_row.dart` (all ivory-canvas reskins, same API/behavior), `restaurant_info_card.dart`/`hotel_info_card.dart` (LOCATION treatment), `restaurant_detail_screen.dart`/`hotel_detail_screen.dart` (ivory hierarchy, new sections wired in, snackbar color fix), `restaurant_award_history_screen.dart`/`hotel_award_history_screen.dart` (forest-green inversion), `michelin_award_timeline.dart`, `worlds_50_best_history_section.dart`, `worlds_50_best_hotels_history_section.dart` (ivory-on-forest-green, gold removed except Michelin badges).

### Tests (Step 1B)

`test/venue_detail_redesign_test.dart` grew from 34 to 50 tests: the `VenueLinksRow` group was replaced by a `VenueUtilityActions` group (including a dedicated "no wrapping labels at 320px" test), plus new groups for `VenueScoreStrip` (real dimensions per venue type, em-dash for missing values, one-row-at-320/390/1.6× verification), `VenueAboutSection` (conditional rendering), and an explicit "Color rule" group asserting gold only ever appears via `StarRow`/`KeyRow`. Full suite: **590 passing** (574 baseline from before Step 1B), `flutter analyze` clean.

### Deferred / not addressed in this pass

- `VisitDetailScreen`/`StayDetailScreen` still use the old light `AppColors.background` canvas — unchanged, explicitly out of scope (Section 32).
- ABOUT has no real data source yet — UI is prepared, not populated; the enrichment pipeline above is a recommendation, not implemented.
- No Call/Share actions — no phone data, no share infrastructure; adding either is new functionality, out of scope for a polish pass.

## 1. Why

Restaurant Detail and Hotel Detail still belonged to the app's older visual
generation (`AppTypography`/`AppColors.card`/`AppSpacing`/`AppRadii`, the
light-card-on-dark-canvas treatment) while Explore, Guides, Trips,
Login/Signup, and the newer Profile/Friends work had already moved onto the
current dark-editorial system (`CsTypography`/`CsSpacing`/`CsRadius`,
`AppColors`' dark-canvas tokens, `EditorialBackButton`, `CsPrimaryButton`/
`CsSecondaryButton`). This pass brings both detail screens onto the current
system with **zero functional change** — no new database calls, no new
RPCs, no altered URL-generation logic, no new social/community features.

## 2. Previous visual issues (audit findings)

1. **Recognition shown twice.** Michelin stars/Keys and World's 50 Best
   appeared once as hero badges and again in a full duplicate
   `RestaurantAwardsCard`/`HotelAwardsCard`.
2. **City/country shown twice.** Once directly under the hero, once again
   inside `RestaurantInfoCard`/`HotelInfoCard`.
3. **Inconsistent primary-action styling.** Restaurant's "Mark as
   visited"/"Add another visit" used a toggle-styled `ToggleActionButton`;
   Hotel's "Add Stay" used a plain, non-toggle-styled `PrimaryButton` — for
   two behaviorally identical actions ("always allows multiple, opens a
   sheet").
4. **Inconsistent actions/links separation.** Hotel Detail already
   separated `HotelActions` (toggles) from `HotelLinks` (external links) as
   two distinct sections; Restaurant Detail combined both inside one
   `RestaurantActions` widget.
5. **Asymmetric relationship prominence.** Restaurant's related-hotel link
   was one row buried inside the generic `RestaurantInfoCard`; Hotel's
   linked restaurants ("RESTAURANTS AT THIS HOTEL") were already a
   first-class section.
6. `Restaurant.bookingUrl` exists on the model but is unused anywhere in
   the UI (confirmed via grep) — left as-is; wiring it up would be new
   functionality, out of scope.
7. No Gault&Millau data exists on either detail screen today (Guides-only)
   — nothing to preserve, confirmed via grep.

## 3. Widget audit (Section 1's classification)

| Category | Widgets | Disposition |
|---|---|---|
| **C — shared elsewhere, do not touch** | `DetailHero`/`HeroIconButton`/`HeroBadge` (`detail_hero.dart`) — also used by both Award History screens, Events, Trips, Friends, Signup. `SectionLabel`/`DetailCard`/`EditorialHeading` (`detail_section.dart`) — also used by Events, Photos, Planning, Profile, Rankings, Visits, Stays. | Left **completely untouched**. |
| **D — detail-screen-specific, safe to redesign** | `RestaurantHero`, `RestaurantActions`, `RestaurantAwardsCard`, `RestaurantInfoCard`, `RestaurantVisitsCard`, `HotelHero`, `HotelActions`, `HotelAwardsCard`, `HotelInfoCard`, `HotelLinks`, `HotelRestaurantsCard`, `HotelStaysCard` | Rebuilt/redesigned. |
| **Narrow-usage shared (confirmed via grep, safe to reskin in place)** | `ToggleActionButton`, `SubtleTextAction`, `CircularScoreBadge`, `PersonalPhotosPreview` | Reskinned onto Cs tokens, same API/behavior. |

`VisitDetailScreen`/`StayDetailScreen` were checked (Section 12 below) —
explicitly out of scope, left untouched.

## 4. Functional inventory (preserved in full)

**Restaurant:** name, city/country/flag, address, Michelin stars, World's
50 Best rank, Hall of Fame, award-history entry point, Michelin Guide
link, Google Maps link, website link, Wishlist (add/remove, saving/loading
states, sign-in gating), Add Visit (multiple visits, refreshes on save,
photo-error outcome messaging), Plan visit, latest-visit score highlight,
YOUR VISITS list (tap → `VisitDetailScreen`, unchanged), PERSONAL PHOTOS
preview, related-hotel navigation (resolves real `Hotel` before
navigating, loading state, error snack).

**Hotel:** mirrors all of the above with Keys instead of Stars, Add Stay
(never a strict toggle), YOUR STAYS, RESTAURANTS AT THIS HOTEL (own
loading/empty states), no related-hotel concept, no `bookingUrl`.

Nothing was silently dropped. The one genuine relocation: Hall of Fame and
World's 50 Best (with year, for hotels) moved from the now-deleted
`RestaurantAwardsCard`/`HotelAwardsCard` into the hero's secondary badges
— the underlying data and its visibility are unchanged, only where it's
shown.

## 5. New shared components (Section 20 — genuine reuse only)

| Component | File | Replaces |
|---|---|---|
| `VenueDetailHero` (+ `VenueHeroBadge`) | `lib/core/widgets/venue_detail_hero.dart` | The `DetailHero` wrapping inside `RestaurantHero`/`HotelHero` — a parallel, independent implementation, not a modification of the shared original. |
| `VenueLinksRow` | `lib/core/widgets/venue_links_row.dart` | `RestaurantActions`' inline link section + `HotelLinks`. |
| `VenueVisitRow` / `VenueVisitStatusRow` (+ `formatVenueVisitDate`) | `lib/core/widgets/venue_visit_row.dart` | The near-identical `_VisitTile`/`_StatusCard` (Restaurant) and `_StayTile`/`_StatusCard` (Hotel). |
| `LinkedVenueRow` | `lib/core/widgets/linked_venue_row.dart` | `HotelRestaurantsCard`'s `_LinkedRestaurantRow` and the buried hotel-link row inside `RestaurantInfoCard`. |

No "UniversalVenueDetailEngine" — each component is a small, genuinely
duplicated primitive, not an abstraction built ahead of need.

## 6. Restaurant Detail — new hierarchy

`EditorialBackButton` (in hero) → hero (name, Michelin stars as sole
primary recognition, Hall of Fame/World's 50 Best/hotel-name as secondary
badges, wishlist toggle) → city/country line → award-history subtle
action (conditional) → primary actions (visited/wishlist toggles) →
`VenueLinksRow` (Maps/Michelin/Website) → Plan visit → YOUR SCORE
(conditional, latest visit) → YOUR VISITS → PERSONAL PHOTOS (conditional)
→ AT THIS HOTEL (conditional, promoted to a first-class section via
`LinkedVenueRow`) → address.

`RestaurantAwardsCard` was deleted — its content (stars, W50B, Hall of
Fame) is now shown once, in the hero, never duplicated below.

## 7. Hotel Detail — new hierarchy

Mirrors Restaurant's structure with Hotel-specific sections, not a
find-replace copy: hero (name, MICHELIN Keys as sole primary recognition,
World's 50 Best — with ranking year preserved — as the only secondary
badge, hotels have no Hall of Fame equivalent) → city/country line →
award-history subtle action (conditional) → primary actions (Add
Stay/wishlist, both now `ToggleActionButton`-styled) → `VenueLinksRow` →
Plan stay → YOUR SCORE (conditional) → YOUR STAYS → PERSONAL PHOTOS
(conditional) → DINING (conditional, `HotelRestaurantsCard` via
`LinkedVenueRow`) → address.

`HotelAwardsCard` and `HotelLinks` were both deleted (superseded by the
hero and `VenueLinksRow` respectively).

### Add Stay / Mark as visited unification

`HotelActions.hasStays` now only changes the button's label/active
styling (mirrors `RestaurantActions.isVisited`) — tapping still always
opens a fresh Add Stay sheet regardless of state, exactly as before. Only
the visual treatment changed, not the interaction semantics.

## 8. Recognition treatment

Michelin stars/Keys are the single primary signal, rendered large and
alone in the hero (`StarRow`/`KeyRow`, size 20). Everything else —
World's 50 Best (with year for hotels), Hall of Fame, the linked-hotel
name — is a visually quieter secondary badge (`VenueHeroBadge`), never
competing with the primary signal. Recognition is read once, from the
existing `Restaurant`/`Hotel` models — no new queries, no new fields.

## 9. Future Friends seam (Section 9 — prepared, not built)

No RPCs, friend aggregation, friend-visit/wishlist queries, or placeholder
metrics were added. The section hierarchy (metadata → recognition →
actions → history sections) leaves an obvious, uncrowded slot beneath the
metadata line for a future compact Friends line, without any code
scaffolding for it today.

## 10. Photography architecture

No image infrastructure was added — no scraping, no external image API,
no schema change, no caching layer. `VenueDetailHero.backgroundImage`
exists as an optional slot (unused at every current call site, since no
catalogue table carries a photo today) so that wiring in real photography
later is additive. The no-photo state is a deliberate deep-green tonal
gradient with a bottom vignette, not a placeholder pretending to be a
photo.

## 11. Empty/partial data states

- No address → `RestaurantInfoCard`/`HotelInfoCard` render nothing
  (`SizedBox.shrink`), not an empty labeled section.
- No visits/stays → `VenueVisitStatusRow` (signed-out / loading / empty
  messaging, unchanged copy).
- No hotel relationship / no linked restaurants → section omitted
  entirely.
- No recognition at all → hero shows name alone, no empty badge row.
- Long names → hero title capped at 2 lines with ellipsis (previously
  unbounded); `LinkedVenueRow`/`VenueVisitRow` names single-line
  ellipsis.

## 12. Responsive & accessibility

Tested at 320px, 390px, and 1.6× text scale (see `test/
venue_detail_redesign_test.dart`). One real bug was found and fixed by
this testing, not just verified against: `VenueDetailHero`'s fixed
`expandedHeight` (previously 240) overflowed under a long title + 3-star
recognition + two wrapped badges at small widths / high text scale. Fixed
by raising the default to 300, capping the title to 2 lines, and wrapping
the hero's text content in a `SingleChildScrollView` (never-scrollable,
reverse-anchored) as a defensive second layer — the sizing is the real
fix, the scroll view guarantees no `RenderFlex` overflow is ever possible
even under a future pathological input.

Accessibility: `EditorialBackButton` carries an explicit `Semantics`
button/label; `ToggleActionButton` renders at ≥44 logical-pixel height
(verified by test); recognition (stars/Keys/badges) is backed by text/
icon semantics, not color alone.

### VisitDetailScreen / StayDetailScreen — known, deliberately unaddressed seam

Both screens still use the old `AppColors.background` (light) canvas —
confirmed via direct read, unchanged by this task per its explicit scope
boundary (only Restaurant/Hotel Detail are in scope). Tapping a YOUR
VISITS/YOUR STAYS row now visibly transitions from the new dark canvas
into the old light canvas. This is a pre-existing seam, not a regression
introduced here — flagged for a future pass, not fixed now.

## 13. Files changed

**Added:**
- `lib/core/widgets/venue_detail_hero.dart`
- `lib/core/widgets/venue_links_row.dart`
- `lib/core/widgets/venue_visit_row.dart`
- `lib/core/widgets/linked_venue_row.dart`
- `test/venue_detail_redesign_test.dart`

**Modified:**
- `lib/core/widgets/toggle_action_button.dart`, `subtle_text_action.dart`,
  `circular_score_badge.dart`, `personal_photos_preview.dart`
- `lib/features/restaurants/restaurant_detail_screen.dart`,
  `widgets/restaurant_hero.dart`, `widgets/restaurant_actions.dart`,
  `widgets/restaurant_info_card.dart`, `widgets/restaurant_visits_card.dart`
- `lib/features/hotels/hotel_detail_screen.dart`, `widgets/hotel_hero.dart`,
  `widgets/hotel_actions.dart`, `widgets/hotel_info_card.dart`,
  `widgets/hotel_stays_card.dart`, `widgets/hotel_restaurants_card.dart`
- `test/hotel_nullable_keys_test.dart` (three `HotelAwardsCard` widget
  tests ported to the new `HotelHero`, same assertions plus the ranking
  year preserved)

**Deleted:**
- `lib/features/restaurants/widgets/restaurant_awards_card.dart`
  (consolidated into the hero)
- `lib/features/hotels/widgets/hotel_awards_card.dart` (consolidated into
  the hero)
- `lib/features/hotels/widgets/hotel_links.dart` (superseded by
  `VenueLinksRow`)

**Untouched (confirmed, Category C):** `lib/core/widgets/detail_hero.dart`,
`lib/features/restaurants/widgets/detail_section.dart`.

## 14. Tests

34 new tests in `test/venue_detail_redesign_test.dart` plus 3 ported in
`test/hotel_nullable_keys_test.dart`, covering: header hierarchy,
recognition (including the found-and-fixed overflow), no-image state,
long names, visits/stays sections, related-venue relationships, action
accessibility, and 320px/390px/1.6× responsive behavior, for both
screens. Baseline was 540 passing tests before this task; final count is
**574**, all passing. `flutter analyze`: clean. `dart format` applied to
touched files only.

## 15. Physical-device review paths

**Restaurant:** Explore → restaurant → Detail. Passport → previous
restaurant → Detail. Wishlist → restaurant → Detail. Guides → restaurant
→ Detail. Friend Profile → VISITED → restaurant → Detail. Check:
hierarchy, spacing, hero (with/without stars), location, actions, links,
YOUR VISITS, related hotel, scroll behavior.

**Hotel:** Explore → hotel → Detail. Passport → previous hotel → Detail.
Wishlist → hotel → Detail. Guides → hotel → Detail. Friend Profile →
VISITED → hotel → Detail. Check: hierarchy, Keys, location, actions,
links, YOUR STAYS, DINING, scroll behavior.
