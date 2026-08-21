# Events V2 Step 4.1 — Would-Recommend Feedback Pre-Apply Report

**Status: implemented locally, validated locally, NOT deployed to production and NOT committed.** Confirmed directly against production immediately before writing this report: `select would_recommend from event_confirmed_attendance` returns `42703: column does not exist`. Nothing in this report has touched production.

## AUDIT

`supabase/migrations/20260820160000_events_v2_would_recommend.sql` already existed locally (untracked) before this task and needed **no changes** — audited line-by-line against every requirement:

- `alter table public.event_confirmed_attendance add column would_recommend boolean null;` — nullable ✓, no default ✓, no backfill statement anywhere in the file ✓, single additive `ADD COLUMN` (no rewrite of existing rows) ✓.
- A `comment on column ...` documents the NULL/TRUE/FALSE semantics and the future `recommendation_rate` exclusion rule — no functional change, informational only.
- No RLS policy is touched. Re-confirmed directly against local Postgres (`\d public.event_confirmed_attendance`): all 4 policies (`_select`/`_insert`/`_update`/`_delete`) are unchanged, still keyed off `user_id`/`visibility` only.
- No other table, column, index, or constraint appears anywhere in the file.

**No correction was needed.**

## PRODUCT SEMANTICS

Implemented exactly as specified: `EventConfirmedAttendance.wouldRecommend` is `bool?` — `null` = not answered (never treated as No, anywhere in the Dart or SQL layers), `true` = Yes, `false` = No. No third "Maybe" state, no "would attend again" field, no new rating dimension. `rating` and `wouldRecommend` remain fully independent — neither model, repository, nor UI derives one from the other.

## MIGRATION

Unchanged (see AUDIT). File: `supabase/migrations/20260820160000_events_v2_would_recommend.sql`.

## MODEL

`lib/models/event_confirmed_attendance.dart` — added `final bool? wouldRecommend;` (positioned right after `rating`, before `comment`), threaded through the constructor as an optional named parameter, and `fromJson` reads `json['would_recommend'] as bool?` (yields `null` for both an explicit JSON `null` and a wholly absent key — verified by test, see VALIDATION).

**Equality/copy helpers**: not added. Audited first — no model in this codebase (`grep -rn "copyWith\|operator =="  lib/models/*.dart`) has a general `copyWith`/`operator==` convention (`Trophy.copyWithEarned` is a single unrelated precedent), and nothing in this feature ever mutates an in-memory `EventConfirmedAttendance` — every state update already goes through a fresh `EventConfirmedAttendance.fromJson(row)` returned by the repository after a round-trip write. Adding unused equality/copy machinery here would be exactly the kind of premature abstraction this codebase avoids elsewhere; "if applicable" in the task's own wording is read literally — it isn't.

## REPOSITORY

`lib/data/repositories/event_confirmed_attendance_repository.dart`:

- `_attendanceColumns` now selects `would_recommend` — every existing read method (`getConfirmedAttendance`, `confirmAttendance`, `loadPassportEventAttendance`) picks it up automatically, no per-method change needed.
- **New `WouldRecommendUpdate` class** — the explicit "provided vs not" mechanism the task asked for. `rating`/`comment` keep their pre-existing, unchanged "parameter left `null` = leave the DB column untouched" convention (via the `'key': ?value` map-entry-omission sugar already in this file). That convention cannot express "clear an existing answer back to null," so `wouldRecommend` gets its own type: **omit the `wouldRecommend` argument entirely** → column untouched; **`WouldRecommendUpdate(true)`/`WouldRecommendUpdate(false)`** → set Yes/No; **`WouldRecommendUpdate(null)`** → explicitly clear to NULL. Two independent axes (was a value provided at all vs. what that value is) map cleanly onto "wrapper present vs absent" × "wrapper's own inner nullability."
- **New `buildAttendanceDetailsUpdate(...)`** — the pure function that actually builds the Supabase `update` map, extracted out of `updateAttendanceDetails` specifically so this logic is unit-testable without a live Supabase client (this repository is Supabase-eager and cannot be exercised directly in this sandbox — the same, already-documented limitation as `PhotoRepository`/`AttendancePhotosSection`).
- `updateAttendanceDetails` gained the new `WouldRecommendUpdate? wouldRecommend` parameter and now delegates to `buildAttendanceDetailsUpdate`; doc comment updated to explain the split convention.

Still **one repository** — no `RecommendationRepository` was introduced.

## UI

`lib/features/events/widgets/recommendation_selector.dart` (new) — `RecommendationSelector(value: bool?, onChanged: ValueChanged<bool?>)`. Two compact pills, "Yes"/"No", built from `AppColors.forestGreen`/`surface`/`cardBorder`/`textPrimary`/`textSecondary` only — no `AppColors.gold`/`accent` anywhere in the file (grepped to confirm). Selected state is never color-only: the selected pill also gets a leading `Icons.check_rounded` glyph and a heavier (1.0 vs 0.5) border, on top of the forestGreen fill — matching `RatingMeter`'s own established selected/unselected treatment in this same sheet. Tapping the already-selected choice again clears it back to `null` (the only clear affordance — no separate third button, mirroring `RatingMeter`'s compact shape rather than inventing a new idiom).

`lib/features/events/widgets/attendance_details_sheet.dart` — `RecommendationSelector` inserted between `RatingMeter` and the "Photos" label. New section order: **rating → recommend → photos → notes → save**. `AttendanceDetailsResult` gained `bool? wouldRecommend`; the Save button now always includes the sheet's current selection (including `null`) in the popped result. `showAttendanceDetailsSheet`/`_AttendanceDetailsSheet` gained `initialWouldRecommend`.

## EDIT EXPERIENCE

`lib/features/events/widgets/event_attendance_section.dart` — the overflow-menu CTA text changed from **"Edit rating, photos & notes"** to **"Edit your experience"** (task §6's explicit instruction). `lib/features/events/event_detail_screen.dart`'s `_editAttendanceDetails` now passes `initialWouldRecommend: current.wouldRecommend` alongside the existing `initialRating`/`initialComment` — opening the sheet pre-populates all three, and the shared `_saveAttendanceDetails` path (used by both the immediately-after-confirming flow and this management action — still one experience, not two, per §13/§7) persists whatever the user leaves selected, including clearing back to `null`. **No second edit UI was created.**

## ANALYTICS

**New in `lib/core/analytics/analytics_event.dart`**: `eventRecommendationAdded` (`event_recommendation_added`) and `eventRecommendationRemoved` (`event_recommendation_removed`) — the smallest clean extension, following the `_added`/`_removed` naming already established throughout this taxonomy (`follow_added/removed`, `event_going_added/removed`) rather than the task's own draft `event_recommendation_yes`/`_no` suggestion, which was explicitly ruled out.

**New in `lib/core/analytics/analytics_properties.dart`**: `bool? wouldRecommend` field + `would_recommend` wire key. The existing closed `AnalyticsProperties` bag supported this cleanly — one more nullable field, same `toMap()` null-omission pattern every other field already uses.

**New pure decision function**, `recommendationAnalyticsEvent({required bool? previous, required bool? next})` in `lib/models/event_confirmed_attendance_analytics.dart` (same file `attendanceSourceForAnalytics` already lives in):

| `previous` | `next` | Fires |
|---|---|---|
| any | non-null (Yes or No) | `eventRecommendationAdded` — first answer AND a changed answer both fire this one event, mirroring `event_rating_added`'s own "no separate updated event" rule |
| non-null | `null` | `eventRecommendationRemoved` — an existing answer was deliberately cleared |
| `null` | `null` | nothing — never a fake "removed" for an answer that was never given |

Wired into both save paths (`EventDetailScreen._saveAttendanceDetails`, `EventsScreen._confirmPromptAttendance`'s own inline update): each captures the attendance row's `wouldRecommend` **before** the write as `previous`, calls `updateAttendanceDetails(..., wouldRecommend: WouldRecommendUpdate(details.wouldRecommend))`, and only on that write's success calls `recommendationAnalyticsEvent(...)` and tracks the result if non-null — same successful-write-rule placement (§11) as the adjacent `eventRatingAdded`/`eventCommentAdded` calls it sits beside. `eventRecommendationAdded` is tracked with `wouldRecommend: details.wouldRecommend` attached; `eventRecommendationRemoved` reuses the base properties with no `wouldRecommend` value (per its own doc comment — there's nothing to report once cleared).

`docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md` updated in the same change: §5's Content-on-confirmed-attendance table (two new rows, including the explicit "not adopted: reporting a null update as added" note), §6's property table (`wouldRecommend` row), §18's client/server/derived classification table (both new events added to the existing `event_rating_added`-etc. bucket). §19's "adding a new event never requires a schema-version bump" rule already covers this addition — `analyticsSchemaVersion` stays `1`.

## PRIVACY

Only `entityId`/`entityType`/`sourceSurface`/`sourceContext`/`eventCategory`/`city`/`countryCode`/`admissionType`/`attendanceSource` (all pre-existing, already-approved fields) plus the new `wouldRecommend` boolean are ever sent. Grepped the full diff for every DO-NOT-TRACK item (notes, photo URLs, email, name, phone, friend ids, ticket URLs) — none appear; `AttendanceDetailsResult.comment`/photo state are never passed into any `AnalyticsProperties` construction, exactly as before this change. Every `track()` call added sits strictly after its corresponding `await` on the repository write succeeds, inside the existing `try` blocks — a thrown exception (caught by the surrounding `catch`) skips every analytics call below it, including the new ones.

## FUTURE METRICS

No aggregate UI was built (§10's explicit instruction). `would_recommend` stays a plain column on `event_confirmed_attendance`, joinable to `events` → host/category/location exactly like `rating` already is — nothing about this column was denormalized onto `events` or anywhere else. The future `recommendation_rate = count(would_recommend = true) / count(would_recommend is not null)` formula from the migration's own column comment remains directly computable with no schema change.

## LOCAL MIGRATION VALIDATION

The migration was **already applied to local Docker Postgres** (`supabase_db_michelin_passport`, confirmed via `supabase migration list --local` and `\d public.event_confirmed_attendance` — column present, nullable, no default, no CHECK constraint, all 4 RLS policies unchanged). Full validation performed in a single `BEGIN; ... ROLLBACK;` transaction (local dev DB confirmed empty of `event_confirmed_attendance` rows both before and after — zero residue):

1. **Existing/bare row stays valid, no default introduced** — an insert with `would_recommend` entirely omitted returned `would_recommend = NULL`.
2. **NULL works** alongside a populated `rating`/`comment` (8, `'great event'`) — inserted cleanly.
3. **TRUE works** — inserted cleanly, returned `t`.
4. **FALSE works** — inserted cleanly, returned `f`.
5. **TRUE → FALSE** and **FALSE → TRUE** updates both succeeded.
6. **Clear to NULL** (an existing `TRUE` row updated to `would_recommend = NULL`) succeeded.
7. **rating/comment stay unaffected** by a `would_recommend`-only update — updating `would_recommend` on the row with `rating=8, comment='great event'` left both exactly as they were.
8. **Rollback leaves clean local state** — confirmed: `select count(*) from event_confirmed_attendance` = 0 and no leftover synthetic `auth.users`/`profiles` rows, both post-rollback.

No migration has been applied to the linked/production database — reconfirmed immediately before writing this report (see the header line above).

## REGRESSION

- **Confirmed Attendance**: `confirmAttendance` (row creation) is completely untouched — its signature, behavior, and the 23505-idempotency retry path are unchanged.
- **Rating**: unaffected — `buildAttendanceDetailsUpdate`'s rating branch is byte-for-byte the pre-existing logic, proven by dedicated tests alongside the new `wouldRecommend` cases.
- **Comments**: same — unaffected, proven by the same test file.
- **Photos**: `AttendancePhotosSection` / `PhotoRepository` are untouched; the sheet's photo section still sits after (not before) the new recommend section, order proven by test.
- **Passport**: `PassportEventCard` was **not touched at all** (grepped first to confirm it had zero pre-existing `recommend` references) — no recommendation surface added there, per §7's explicit instruction.
- **Restaurant/Hotel visit flows**: nothing in this change touches `visits`, `VisitRepository`, or any Restaurant/Hotel screen.

## VALIDATION

- `dart format --set-exit-if-changed .` — **0 files changed** (a first pass auto-reformatted 4 files during development; re-run afterward confirms clean).
- `flutter analyze` — **No issues found!**
- `flutter test` — **1235 passed, 0 failed** (baseline 1194 + 41 new/changed assertions across model, repository, widget, and analytics-contract test files — no existing test was weakened to make this pass).
- New/updated test coverage:
  - **Model** (`event_confirmed_attendance_model_test.dart`): `wouldRecommend` parses `true`/`false`/explicit-JSON-`null`/a wholly missing key — all four, missing-key case explicitly asserted never to become `false`.
  - **Repository** (`event_confirmed_attendance_repository_test.dart`, new file): `buildAttendanceDetailsUpdate`'s full omit/set-true/set-false/clear-to-null matrix, plus proof that `rating`/`comment` are unaffected by a `wouldRecommend`-only call and vice versa.
  - **Analytics decision** (`event_confirmed_attendance_model_test.dart`): all 7 `recommendationAnalyticsEvent` branches (first Yes, first No, Yes→No, No→Yes, clear-an-existing-Yes, clear-an-existing-No, null→null-fires-nothing).
  - **Widget** (`recommendation_selector_test.dart`, new file): question text, no-selection/Yes-selected/No-selected icon states, tap-to-select both directions, switch-while-selected, tap-again-to-clear both directions, 320px, 1.6x text scale.
  - **Sheet shell** (`attendance_details_sheet_shell_test.dart`): recommend section present, new 5-section order (rating→recommend→photos→notes→save), pre-population from `initialWouldRecommend` (true/false), Save remains enabled/available with no selection made.
  - **Edit CTA** (`event_attendance_section_test.dart`): overflow menu reads "Edit your experience", not the old text; fires `onEdit`.
  - **Analytics contract** (`analytics_event_test.dart`, `analytics_properties_test.dart`): both new wire names present/unique/snake_case; `wouldRecommend` serializes `true`/`false` correctly and is omitted when `null`.
  - **Not covered by an automated test, and said so rather than claimed otherwise**: "failure fires no success analytics" for the two new events specifically. This is structurally guaranteed by call-site placement (the `track()` calls sit inside the same `try` block, after the same `await`, as the pre-existing `eventRatingAdded`/`eventCommentAdded` calls immediately beside them) but is not independently asserted by a test — because `EventDetailScreen`/`EventsScreen` are Supabase-eager and cannot be instantiated in this sandbox, which is the exact same, already-documented, pre-existing gap this codebase accepts for `eventRatingAdded`/`eventCommentAdded` today (no test file for either screen's attendance flow exists). This task did not introduce a new gap; it did not close the pre-existing one either.

## FILES

**New**: `lib/features/events/widgets/recommendation_selector.dart`, `test/event_confirmed_attendance_repository_test.dart`, `test/recommendation_selector_test.dart`, this report. (`supabase/migrations/20260820160000_events_v2_would_recommend.sql` already existed untracked before this task — audited, not modified.)

**Modified**: `lib/models/event_confirmed_attendance.dart`, `lib/models/event_confirmed_attendance_analytics.dart`, `lib/data/repositories/event_confirmed_attendance_repository.dart`, `lib/features/events/widgets/attendance_details_sheet.dart`, `lib/features/events/widgets/event_attendance_section.dart`, `lib/features/events/event_detail_screen.dart`, `lib/features/events/events_screen.dart`, `lib/core/analytics/analytics_event.dart`, `lib/core/analytics/analytics_properties.dart`, `docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md`, `test/event_confirmed_attendance_model_test.dart`, `test/attendance_details_sheet_shell_test.dart`, `test/event_attendance_section_test.dart`, `test/analytics_event_test.dart`, `test/analytics_properties_test.dart`.

## GIT

**Nothing staged, committed, or pushed.** `HEAD` and `origin/main` both remain `56bc57b2672fcb00c3fa34aef20a4a6b7699742d`. `git status --short` shows only unstaged modifications (`M`) and untracked (`??`) files. The working tree also contains pre-existing, unrelated untracked/modified artifacts from other in-progress work (Events V2 Step 4 confirmed-attendance/photos feature set awaiting its own commit, Michelin/Gault&Millau enrichment reports and data under `supabase/data/enrichment/`) — these predate this task, are outside its scope, and were left untouched.

---

## SAFE TO DEPLOY: YES

The migration is additive-only, nullable, has no default, requires no backfill, touches no RLS policy, and has been proven end-to-end against local Postgres (including the rollback-leaves-clean-state check). Production re-confirmed immediately before this report to still be exactly as expected (column absent, zero drift).

**Requesting approval for exactly one file:**

```
supabase/migrations/20260820160000_events_v2_would_recommend.sql
```

No other migration, no backfill, no data write, no code deploy is requested or implied by this approval ask.

**STOP.**
