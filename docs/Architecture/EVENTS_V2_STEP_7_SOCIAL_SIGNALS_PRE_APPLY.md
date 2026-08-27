# EVENTS V2 STEP 7 — FRIENDS INTERESTED + FRIENDS GOING + MEMBER GOING COUNT — PRE-APPLY

Implemented locally, following `EVENTS_V2_STEP_7_SOCIAL_SIGNALS_AUDIT.md`'s conclusions exactly.

> **STATUS: FINALIZED.** Migration `20260821120000_events_v2_social_signals_going_member_count.sql` has been applied to production (`supabase db push --linked`) and independently re-verified there: function signature/owner/`SECURITY DEFINER`/`STABLE`/hardened `search_path` all match the migration exactly; grants confirmed `authenticated`-only (no `anon`, no bare `PUBLIC`, `service_role` present only as this schema's standard platform-wide default, cross-checked identical against `get_event_attendance_count`/`is_friend`); `event_attendance` RLS re-read byte-identical to pre-migration; non-mutating smoke checks passed (non-existent event → 0; real production events return correct counts) with zero rows written; `supabase db push --linked --dry-run` confirms zero remaining pending migrations. Physical-device validation (Friends Interested/Going visibility transition between two accepted-friend accounts, non-friend identity never exposed, member-count display boundaries, visual polish, failure isolation) has also been approved. This document's original PRE-APPLY content below is kept as the implementation record; nothing in it was altered by finalization beyond this status header and the APPROVAL REQUEST section at the end.

## FINAL PRODUCT SEMANTICS

- **Friends Going** — unchanged.
- **Friends Interested** — new: accepted friends can see who is Interested, identical mechanism to Friends Going.
- **Mantelier members going** — new: an anonymous, server-capped platform-wide Going count. `0` → hidden. `1–99` → exact. `100+` → always literally `"100+"`, and the server itself never discloses the true count once it reaches 100.

## INTERESTED VISIBILITY CHANGE

`lib/models/event_intent.dart`, `visibilityForIntent()`:

```dart
AttendanceVisibility visibilityForIntent(EventIntentStatus status) =>
    switch (status) {
      EventIntentStatus.going => AttendanceVisibility.friends,
      EventIntentStatus.interested => AttendanceVisibility.friends, // was .private
    };
```

The single load-bearing line the audit identified — no other file changed for this part. Future writes only; no backfill (production held 0 Interested rows at audit time — re-confirmed unchanged, see LOCAL DATABASE VALIDATION). `event_confirmed_attendance.visibility` (Confirmed Attendance) was not touched, remains `private` by default — a structurally separate table, separate RLS, separate concept from pre-event intent.

## FRIEND SIGNAL ARCHITECTURE

No new repository methods. `EventAttendanceRepository.getVisibleUserIds`/`getFriendUpcomingEvents` (already `status`-parameterized since Step 3) are now called a second time with `EventIntentStatus.interested` everywhere Going was already read:

- **Event Detail** (`event_detail_screen.dart`): `_loadFriendsForStatus` (renamed from the old Going-only `_loadFriendsGoing`, now status-parameterized) is called twice — once per status — both sharing a single `getFriends()` call (started once, awaited twice; Dart Futures cache their result, so this costs one RPC, not two).
- **Friend Profile** (`friend_profile_screen.dart`): `_load()` now also populates `_interestedFuture` via the same `getFriendUpcomingEvents` call, `status: EventIntentStatus.interested`.

`friendsGoingToEvent` (`friends_going_view_model.dart`) — reused verbatim for Interested, not renamed or duplicated; its doc comment now notes the dual use. It never depended on "Going" specifically, only on "a list of RLS-confirmed-visible attendee ids."

## FRIENDS INTERESTED UI

New, small, parallel components (deliberately not a generalized shared widget — matches this codebase's own "small parallel component for a genuinely different concept" precedent, e.g. `PrivateChefHero`'s doc comment):

- `EventFriendsInterestedSection` (`lib/features/events/widgets/event_friends_interested_section.dart`) — identical shape to `EventFriendsGoingSection` (preview cap 3, avatar+name+username rows via the existing `IdentityRow`, "View all" text link, never a bare count), heading `"FRIENDS INTERESTED"`.
- `EventFriendsInterestedListScreen` (`lib/features/events/event_friends_interested_list_screen.dart`) — identical shape to `EventFriendsGoingListScreen`.

`EventFriendsGoingSection`/`EventFriendsGoingListScreen` themselves are **byte-for-byte untouched**.

## FRIEND PROFILE

`_FriendInterestedSection` (private, `friend_profile_screen.dart`) added directly after `_FriendGoingSection`, identical shape (`_SectionHeader`, same `_previewLimit` of 4, reuses the existing generic `FriendGoingTile` — it has no Going-specific text baked in). `_FriendGoingSection` gained a trailing `SectionDivider()` (it's no longer the last section on the page — mirrors VISITED/WISHLIST's own existing trailing-divider convention exactly); `_FriendInterestedSection` has none (now last). New drilldown `FriendInterestedListScreen` added to `friend_activity_list_screen.dart`, mirroring `FriendGoingListScreen`. Both sections independently hide when empty, per the page's existing "omit rather than clutter" rule — unchanged.

## EVENT DETAIL — SOCIAL AREA

Kept inside the existing `canAttend`-gated block, directly under `EventIntentControls`, matching the task's own conceptual layout:

```
EventIntentControls (pills)
  ↓ (only if non-empty)
EventFriendsGoingSection        "FRIENDS GOING"
  ↓ (only if non-empty, independent of Going)
EventFriendsInterestedSection   "FRIENDS INTERESTED"
  ↓ (only if count > 0, independent of both Friends groups)
"37 Mantelier members going"   ← plain taupe metadata text, not tappable, not a labeled section
```

Going always precedes Interested (source order). Each of the three pieces is its own independent `FutureBuilder` — a slow/failed member count never blocks or hides the Friends sections, a slow/failed Friends Interested load never blocks or hides Friends Going, and vice versa (Events V2 Step 7's own explicit failure-isolation requirement). No empty headings are ever possible: every piece either renders its full content or `SizedBox.shrink()`.

## MEMBER GOING COUNT

**Dart**: `GoingMemberCount` (`lib/models/going_member_count.dart`) — `count` (0–100, where 100 means "100 or more") + a derived `isCapped` getter (`count >= 100`), never a separately-stored redundant flag. `EventSocialRepository.getGoingMemberCount(eventId)` (`lib/data/repositories/event_social_repository.dart`) — one RPC call, wraps the raw integer. `formatGoingMemberCount()` (`lib/features/events/going_member_count_format.dart`) — the single centralized copy function; returns `null` for 0 (hidden), the exact singular/plural string for 1–99, and always `"100+ Mantelier members going"` once capped — never the literal "100".

**SQL**: new migration `20260821120000_events_v2_social_signals_going_member_count.sql`, function `get_event_going_member_count(target_event_id uuid) returns integer`:

```sql
select least(count(*)::integer, 100)
from public.event_attendance
where event_id = target_event_id
  and status = 'going';
```

Counts only `status = 'going'` — Interested never counts. Visibility does **not** affect inclusion (both `private` and `friends` Going rows count identically — visibility governs identity disclosure, not aggregate membership; verified locally, see below). A non-existent `event_id` yields `0`, no exception, no distinguishable behavior from "a real event nobody has marked Going for yet."

**Does not touch, modify, or reuse** the pre-existing `get_event_attendance_count` (Interested+Going combined, ≥5-anonymity-threshold, no upper cap) — left in place untouched, per explicit instruction.

## SERVER-SIDE 100+ CAP

Enforced entirely inside the SQL function via `least(count(*), 100)` — the Flutter client never receives, computes, or has access to the true count once it reaches 100. Proven locally with real Postgres rows (not merely by reading the SQL): fixtures pushed the true Going count to 101 while the function continuously returned 100 — see LOCAL DATABASE VALIDATION below for the exact query and output. The Dart formatter's own defensive test (`GoingMemberCount(523)` → `"100+..."`) is belt-and-suspenders only; the actual privacy boundary is the SQL `least()`, not the Dart formatter.

## RPC SECURITY

Copied from the sibling `get_event_attendance_count`'s own already-audited posture, including the exact lesson its own follow-up migration learned: `REVOKE EXECUTE ... FROM PUBLIC` alone does **not** stop Postgres's ambient default-privilege grant to `anon` — `anon` must be revoked explicitly. Re-verified live on the local database after applying the migration:

```
proacl = {postgres=X/postgres,authenticated=X/postgres}
```

No `anon=X` entry — confirmed no ambient-grant leak this time. `SECURITY DEFINER`, `STABLE`, `SET search_path TO 'public'` (hardened, no search-path-hijack surface) — all re-verified live via `pg_proc`, not assumed from the migration text alone. The function selects only `count(*)` — no `user_id`, no `event_id` echoed back, no row-level column of any kind — there is no identity-enumeration surface. Single strongly-typed `uuid` parameter, no dynamic SQL, no string interpolation — no injection surface. `event_attendance_select`/`_insert`/`_update`/`_delete` RLS policies re-verified byte-identical to before this migration — **not weakened**.

## RLS

Unchanged — re-verified live, all 4 `event_attendance` policies identical to the pre-Step-7 state. The Interested-visibility change required no RLS edit because the existing `event_attendance_select` policy (`user_id = auth.uid() OR (visibility = 'friends' AND is_friend(user_id))`) has no `status` reference at all, so it already governs friends-visible Interested rows identically to friends-visible Going rows.

## INDEX

No new index created. `event_attendance_event_status_idx (event_id, status)` re-confirmed present on the local database after the migration — already covers every query path this step needs (`getVisibleUserIds`, `getFriendUpcomingEvents`, and the new count RPC all filter on `event_id` + `status`).

## ANALYTICS

No taxonomy change. `FriendSignalType`/`AnalyticsProperties.friendSignalType`/`AnalyticsEvent.friendsSignalOpened` already exist, fully defined, still fully unused (re-confirmed unchanged by this step) — passively rendering Friends Going, Friends Interested, or the member count fires no analytics event, matching this codebase's consistent "rendering is not a trackable action" principle. No friend user ids, names, or emails are sent anywhere by this step. No member count (capped or otherwise) is sent to analytics.

## PERFORMANCE

Final Event Detail social-load shape: 1 shared `getFriends()` call (reused for both Going and Interested resolution) + `getVisibleUserIds(status: going)` + `getVisibleUserIds(status: interested)` + 1 new `getGoingMemberCount` RPC = **4 calls**, all independent of each other and of the screen's existing Event/venues/intent/confirmed-attendance load, started together and awaited only where their own result is needed (no artificial serialization). Net new cost versus pre-Step-7: **+2 calls** (previously: `getFriends()` + `getVisibleUserIds(going)` = 2; now: 4), exactly matching the audit's own performance projection. No N+1 anywhere — the count is one scalar regardless of how many people are going; each Friends list is capped at however many accepted friends the user has.

## LOCAL DATABASE VALIDATION

Applied to the **local** Supabase instance only (`supabase migration up`, no `--linked`). Verified via `supabase migration list --local` (new migration present, applied) and `supabase migration list --linked` (production unchanged, migration shows as not yet applied there).

Disposable-fixture validation (`BEGIN ... ROLLBACK`, executed inside the local Postgres container directly — `supabase db query -f` does not support multi-statement scripts, so `docker exec supabase_db_michelin_passport psql` was used instead; `session_replication_role = replica` was used transiently inside the same transaction to insert fixture `profiles` rows without needing real `auth.users` rows, since `profiles.id` FKs to `auth.users(id)`):

| Case | Real Going rows | Function returned | Expected |
|---|---|---|---|
| Baseline | 0 | 0 | 0 |
| 1 Going, written `private` | 1 | 1 | 1 (private Going still counts) |
| + 1 Interested (`friends`) | 1 Going / 1 Interested | 1 | 1 (Interested never counts) |
| Fill to 99 Going (mixed visibility) | 99 | 99 | 99 |
| +1 → 100 Going | 100 | 100 | 100 |
| +1 → 101 Going | 101 | **100** | 100 (capped) |
| Sanity check | — | true count = 101, displayed = 100 | proves the cap is real, not coincidental |
| Non-existent event id | — | 0 | 0, no exception |

All 8 cases passed exactly as expected. Transaction rolled back; re-verified zero residue afterward (`profiles`/`events` fixture rows confirmed absent from the local database post-rollback — the one pre-existing local `events` row found, `'t Preuvenemint`, is local seed data unrelated to this test, not a fixture leak).

**Aside, unrelated to Step 7**: every `supabase db query` call against the local database (this validation included) surfaced a standing informational advisory that `public.spatial_ref_sys` (a PostGIS system reference table) has RLS disabled. This is pre-existing, unrelated to Step 7's tables, and the advisory itself explicitly instructs not to auto-apply its suggested remediation — noted here for visibility only, not acted on.

## REGRESSION

- `flutter test` — full suite, 0 failures, 0 weakened/removed tests.
- Existing Friends Going tests (`event_friends_going_section_test.dart`, `friends_going_view_model_test.dart`) — unchanged, all pass, `EventFriendsGoingSection`/`EventFriendsGoingListScreen` untouched.
- Existing Friend Profile tests (`friend_profile_hero_test.dart`, `friend_profile_no_activity_test.dart`, `friend_profile_visited_wishlist_sections_test.dart`) — unchanged, all pass.
- `friend_profile_going_section_test.dart` — updated only to mirror the new trailing `SectionDivider` GOING now renders (matching production code exactly) and to add one new assertion for it; every pre-existing assertion in that file is unchanged and still passes.
- `event_intent_test.dart` — `visibilityForIntent` test group updated to assert the new friends-visible rule for Interested; `resolveIntentTap`/`intentAnalyticsEvents` groups (unrelated to visibility) fully unchanged, still pass.
- `PassportVenue` — grep-confirmed untouched (still exactly `RestaurantVenue`/`HotelVenue`).
- No Follow (`follows_*`) code referenced or touched anywhere in this step.

## VALIDATION

- `dart format --set-exit-if-changed .` — 0 files changed.
- `flutter analyze` — 0 issues.
- `flutter test` — **1367 passed**, 0 failed (baseline 1335 + net new tests from this step: `event_intent_test.dart`'s visibility group, `event_friends_interested_section_test.dart`, `friend_profile_interested_section_test.dart`, `going_member_count_format_test.dart`, and one new assertion in `friend_profile_going_section_test.dart`).
- `supabase migration list --linked` — production unchanged (35 pre-existing migrations, local==remote; the new migration shows `remote: ""`, correctly not applied).
- `supabase db push --linked --dry-run` — reports exactly one pending migration (`20260821120000_events_v2_social_signals_going_member_count.sql`), `upToDate: false`, and confirms nothing was actually pushed (dry-run only).
- `git status --short` / `git diff --cached` — nothing staged; working-tree changes match the FILES list below exactly, plus the same pre-existing unrelated Michelin/Gault&Millau artifacts.

## FILES

**New**: `lib/models/going_member_count.dart`, `lib/data/repositories/event_social_repository.dart`, `lib/features/events/going_member_count_format.dart`, `lib/features/events/widgets/event_friends_interested_section.dart`, `lib/features/events/event_friends_interested_list_screen.dart`, `supabase/migrations/20260821120000_events_v2_social_signals_going_member_count.sql`, `test/event_friends_interested_section_test.dart`, `test/friend_profile_interested_section_test.dart`, `test/going_member_count_format_test.dart`, `docs/Architecture/EVENTS_V2_STEP_7_SOCIAL_SIGNALS_PRE_APPLY.md`.

**Modified**: `lib/models/event_intent.dart`, `lib/features/events/event_detail_screen.dart`, `lib/features/events/friends_going_view_model.dart` (doc comment only), `lib/features/friends/friend_profile_screen.dart`, `lib/features/friends/friend_activity_list_screen.dart`, `test/event_intent_test.dart`, `test/friend_profile_going_section_test.dart`, `docs/Architecture/EVENTS_V2_STEP_7_SOCIAL_SIGNALS_AUDIT.md` (status header only).

**Deleted**: none.

**Unrelated exclusions**: `docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md` and everything under `supabase/data/enrichment/` — untouched, unstaged.

## DATABASE

- Migrations created: **1**
- Migrations deployed locally: **1**
- Migrations deployed to production: **0**
- Production writes: **0**
- Production backfills: **0**

## GIT

Nothing staged, nothing committed, nothing pushed — `git status --short`/`git diff --cached` confirm.

## PHYSICAL DEVICE CHECKLIST

Two accepted-friend accounts (A, B), one non-friend account (C). To be run **after** production migration approval, since Friends Interested visibility and the member count both require the new migration/behavior live.

**Friends Interested/Going transition**:
- A marks Interested on an upcoming Event → B sees A under Friends Interested; C never sees A's identity anywhere.
- A switches to Going → B no longer sees A under Interested, now sees A under Going.
- A removes intent → B sees neither.

**Member count**:
- 0 → hidden entirely.
- 1 → "1 Mantelier member going" (singular).
- 2+ → plural, exact number.
- ≥100 real-device coverage: automated/local validation (above) is sufficient — do NOT create ~100 production rows merely to exercise the UI.

**Also verify**:
- Event Detail visual polish: Going before Interested, member count reads as a quiet trailing line (not a CTA, not tappable, no gold, no oversized styling).
- Friend Profile shows GOING then INTERESTED, each independently hidden when empty.
- No overflow at narrow width / large text scale.
- Existing Interested/Going pills still work exactly as before.
- Airplane mode / a failed social-signal load does not break the rest of Event Detail.

## APPROVAL REQUEST — FULFILLED

Approved and applied. `supabase/migrations/20260821120000_events_v2_social_signals_going_member_count.sql` was pushed to production via `supabase db push --linked` — creating the new `get_event_going_member_count` function only, no table change, no RLS change, no data write, confirmed by direct post-apply re-verification (function definition, grants, RLS, non-mutating smoke checks — see the PRODUCTION DEPLOYMENT VERIFICATION section below). The Interested-visibility change (`visibilityForIntent`) required no separate migration; it is live the moment this Dart code ships.

## PRODUCTION DEPLOYMENT VERIFICATION

- **Command**: `supabase db push --linked`, applying exactly `20260821120000_events_v2_social_signals_going_member_count.sql` (re-confirmed via an immediately-preceding `--dry-run` that no other migration was pending).
- **Migration list**: `supabase migration list --linked` shows `20260821120000` with `local == remote` — applied on production, matching every prior migration's own applied state.
- **Function re-verified live on production** (`pg_proc`/`pg_get_functiondef`): `get_event_going_member_count(target_event_id uuid) returns integer`, owner `postgres`, `SECURITY DEFINER` true, `STABLE`, `search_path` hardened to `'public'`, body byte-identical to the migration file.
- **Grants re-verified live**: `proacl = {postgres=X, authenticated=X, service_role=X}` — no `anon`, no bare `PUBLIC`; `authenticated` can execute; `service_role`'s presence cross-checked as this schema's standard platform-wide default (identical shape on `get_event_attendance_count` and `is_friend`), not specific to this function.
- **RLS re-verified unchanged**: all 4 `event_attendance` policies read back byte-identical to their pre-migration text.
- **Non-mutating smoke checks** (read-only `SELECT` calls only, zero rows written): non-existent event id → `0`; the 4 real production events returned `1/0/0/0`, consistent with the single pre-existing Going row.
- **Final dry-run**: `supabase db push --linked --dry-run` → `"upToDate": true`, zero remaining pending migrations.

## PHYSICAL DEVICE VALIDATION — APPROVED

Confirmed via human review using two accepted-friend accounts and one non-friend account, per the PHYSICAL DEVICE CHECKLIST above: Interested/Going visibility transitions correctly between friends, a non-friend never sees the identity, member-count display boundaries and visual polish read correctly, and existing Interested/Going controls and failure handling remain intact.

---

EVENTS V2 STEP 7 —
FRIENDS INTERESTED + SOCIAL SIGNALS FINALIZED,
PRODUCTION MIGRATION DEPLOYED AND VERIFIED,
PHYSICAL DEVICE APPROVED
