# Social Foundation Step 2B — Production Deployment Report

Deployment and verification report, 2026-08-15. Covers the controlled production deployment of Social Foundation Step 2B (Event Attendance + Friend Venue Navigation), described in `SOCIAL_FOUNDATION_STEP_2B_IMPLEMENTATION_REPORT.md`. Backend only — Step 2/2B Flutter source remains uncommitted, pending final physical-device review.

---

## Preflight (1–6)

1. **Production baseline** (fresh, not assumed): `profiles=2, friendships=1, visits=26, photos=8, wishlist=5, planned_trips=3, events=1, restaurants=1362, hotels=775, award_history=2168`. These differ from the counts recorded during the Step 2 deployment — genuine real activity from ongoing physical-device review (a second real profile, a real friendship, additional real visits/photos), not an anomaly.
2. **Step 1 state**: `friendships` table, `is_friend()` — confirmed present and unchanged.
3. **Step 2 state**: `visits.visibility` (NOT NULL, default `'private'`) present; `visits_read`/`wishlist_read`/`photos_read` all confirmed live with their Step 2 predicates unchanged; `storage.objects` friend-read policy (`visit_photos_read_friends`) present; `planned_trips` confirmed still owner-only on all four operations.
4. **Pending migration confirmed**: `supabase migration list --linked` showed exactly one pending — `20260815120000_social_foundation_step2b_event_attendance.sql`.
5. **Unrelated pending migration result**: none — 17 already synced, exactly one pending.
6. **Migration scope audit**: re-read in full; grepped for `visits`/`wishlist`/`photos`/`planned_trips`/`planned_venues`/`profiles`/`friendships`/`restaurants`/`hotels`/`award_history`/`community`/`activity_feed`/`geographic` — zero matches outside of comment references to the architecture doc's own filename. Scope confirmed exactly as reviewed: `event_attendance` table, RLS, indexes, table grant, one aggregate RPC.

## event_attendance schema (7–13)

7. **Table columns**: `id uuid pk, event_id uuid, user_id uuid, status text, visibility text, created_at timestamptz`.
8. **Status constraint**: `CHECK (status = 'going')` — single legal value, matching the reviewed design.
9. **Visibility constraint**: `CHECK (visibility = ANY ('private','friends'))`.
10. **Default visibility**: `'friends'` — reconfirmed as the still-implemented, still-documented decision (`FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` §17.3); not silently changed to `private` in this deployment.
11. **Unique constraint**: `UNIQUE (event_id, user_id)` — structural duplicate prevention, confirmed live.
12. **FK behavior**: `event_id → events(id) ON DELETE CASCADE`, `user_id → profiles(id) ON DELETE CASCADE` — both confirmed live.
13. **Indexes**: the unique constraint's own composite index, plus explicit `event_attendance_user_idx` and `event_attendance_event_idx`, both confirmed present.

## Security (14–23)

14. **RLS policies**: `event_attendance_select` (`owner OR (visibility='friends' AND is_friend(owner))`), `_insert` (`with check user_id=auth.uid()`), `_update` (`using/with check user_id=auth.uid()`), `_delete` (`using user_id=auth.uid()`) — all four confirmed live, scoped `to authenticated` only.
15. **Owner behavior**: A reads/creates/deletes own row — confirmed via live production test (insert → select → delete, full cycle).
16. **Friend behavior**: B (accepted friend) reads A's `friends`-visible row — confirmed (1 row).
17. **Stranger behavior**: C (no relationship) reads A's row — confirmed (0 rows).
18. **Pending behavior**: C (pending with A) reads A's row — confirmed (0 rows), tested as its own distinct relationship state from "stranger."
19. **Unfriend behavior**: A↔B friendship deleted → B's read → 0 rows, immediately, row itself untouched.
20. **Block behavior**: A blocks B → B's read → 0 rows.
21. **Spoof prevention**: B attempted to insert an attendance row with `user_id = A` → `ERROR 42501: new row violates row-level security policy` — confirmed at the database level, not merely relying on Flutter.
22. **Duplicate prevention**: A attempted a second `going` row for the same event → `ERROR 23505: duplicate key value violates unique constraint` — structural.
23. **Grants**: table-level GRANT carries an ambient `anon` entry (this hosted project's own schema-level default-privilege bootstrap, identical to what Step 1/Step 2 already found and documented for every new table) — confirmed **harmless**, verified directly: impersonating `anon` and querying `event_attendance` returns `count(*) = 0` for every row, since none of the four RLS policies are scoped to `anon`, and Postgres RLS defaults to deny-all when no policy applies. Not a stop condition, consistent with established precedent.

## Finding and fix: `anon` EXECUTE over-grant on the aggregate RPC (discovered and corrected during this deployment)

Unlike the harmless table-grant situation above, live ACL inspection (`pg_proc.proacl`) after the primary migration showed `get_event_attendance_count` carried an unintended `anon=X` EXECUTE grant — the identical root cause already found and fixed for Step 1's RPCs: the migration's own `revoke ... from public` never revoked from `anon` specifically, and this project's ambient default privileges auto-grant EXECUTE to `anon` on every new function regardless. **This one was not merely cosmetic**: `get_event_attendance_count` has no internal `auth.uid()` check (by design — the aggregate count is meant to be identity-free), so an `anon` caller genuinely could have executed it successfully, unlike the RLS-protected table reads. The data it would return is itself safe by design (never row-level, `NULL` below the 5-attendee threshold), but the grant was never intended (the migration's own header comment says "grant execute ... to authenticated" only) and violates this project's least-privilege discipline.

**Fix**: `supabase/migrations/20260815130000_social_foundation_step2b_revoke_anon_execute.sql` — one explicit `revoke execute ... from anon;` statement. Validated with the same rollback-test rigor as the primary migration (clean transactional dry-run, zero errors), applied via `supabase db push --linked`, then re-verified at two levels: (a) SQL ACL (`anon` no longer present), and (b) live PostgREST API — a direct `POST .../rpc/get_event_attendance_count` with the anon key now returns `HTTP 401 {"code":"42501","message":"permission denied for function get_event_attendance_count"}`, a genuine permission error, **not** a `PGRST204` schema-cache error — confirming the fix took effect at the actual API layer the app talks to, not just the raw database.

## Aggregate RPC (24–29)

24. **RPC signature**: `get_event_attendance_count(target_event_id uuid) returns integer`.
25. **SECURITY DEFINER status**: `true`, `search_path=public` explicit.
26. **Grants**: post-fix, `postgres/authenticated/service_role` only.
27. **≥5 threshold verification**: verified by direct definition review (`case when count(*) >= 5 then count(*)::integer else null end`) rather than mass-populating five more disposable production accounts to re-prove arithmetic already exhaustively verified in the prior local test pass (which confirmed `NULL` at 2 attendees and the exact integer `5` at the threshold) — per the task's own explicit permission to do so when production testing would be disproportionate.
28. **Identity-leak result**: none — the function selects only `count(*)`, never `event_id`/`user_id`/any row-level column, confirmed by reading the function body directly.
29. **Flutter UI remains unwired**: confirmed — `get_event_attendance_count` is not called from anywhere in the Flutter codebase (grep: zero matches outside the migration file and its own documentation).

## Apply (30–34)

30. **Rollback-test result**: both migrations (primary + anon-execute fix) were dry-run via `begin; ...; rollback;` against production before their real apply — both ran with zero errors; post-rollback checks confirmed `event_attendance` absent and all counts unchanged after the first test.
31. **Exact command**: `supabase db push --linked`, run twice (primary migration, then the follow-up fix).
32. **Migration result**: both applied cleanly, zero errors/warnings.
33. **Remote migration-list result**: `supabase migration list --linked` shows all 19 migrations synced (local timestamp == remote timestamp) after both applies.
34. **PostgREST schema-cache result**: confirmed via direct HTTP call — `GET .../rest/v1/event_attendance?select=id,event_id,user_id,status,visibility,created_at` → `HTTP 200`, empty array (correct: anon-role request, RLS-filtered to zero rows) — not `PGRST204`. Table schema is fully visible to the API layer.

## Production test (35–43)

35. **Going create**: A's `insert` (mirroring `markGoing`) succeeded, full row returned.
36. **Going read-back**: A's own subsequent `select` (mirroring `getMyAttendance`) returned the row.
37. **Friend read**: B (accepted friend) read A's `friends`-visible row successfully.
38. **Private read**: A's row switched to `visibility='private'` → B's read → 0 rows; then restored to `friends` for the remaining tests.
39. **Stranger denial**: C (no relationship) → 0 rows.
40. **Unfriend revocation**: confirmed (§19 above).
41. **Block revocation**: confirmed (§20 above).
42. **Delete**: A's own `delete` (mirroring `removeAttendance`) succeeded; B's unauthorized delete attempt against A's row affected 0 rows, with the row's continued existence and correct ownership independently re-confirmed via the privileged connection (not merely inferred from B's own, RLS-blocked, read).
43. **Cleanup**: all four disposable test accounts (A/B/C plus a separate smoke-test account D) and the one temporary test friendship deleted via `auth.users` cascade; final counts re-confirmed to exactly match the pre-test baseline (`profiles=2, friendships=1, event_attendance=0`).

## Flutter runtime (44–53)

Not directly observable via an interactive on-device session in this environment — the same honest limitation as the Step 2 deployment task. Verified instead at the strongest available level: a real production write→read→delete cycle (§35–36, 42) using the exact column list and query shape `EventAttendanceRepository` issues, plus `flutter analyze`/`flutter test` confirming the calling code itself is correct. Live on-device confirmation of items 44–53 below is the user's own physical-device review, the explicit next step after this report.

44. **I'm going state**: verified at the repository-shape level (§35) — the exact insert `EventAttendanceRepository.markGoing` performs succeeds against production.
45. **Going state**: verified at the repository-shape level (§36) — `getMyAttendance` correctly reads back a created row.
46. **Remove attendance**: verified at the repository-shape level (§42) — `removeAttendance`'s exact delete shape succeeds and is confirmed gone.
47. **Past/cancelled behavior**: unchanged from the implementation report — `canAttendEvent` is a pure Dart function, already unit-tested (5 tests, `test/can_attend_event_test.dart`), not a backend concern; no schema/RLS involvement.
48. **VISITED → Restaurant Detail**: unchanged Flutter code from the implementation report; no backend dependency introduced by this deployment (`FriendVisitTile.onTap` navigation is pure client-side routing).
49. **VISITED → Hotel Detail**: same.
50. **WISHLIST → canonical detail**: same (already live since Step 2).
51. **Friend venue → viewer's own Wishlist flow**: unchanged reasoning — `RestaurantDetailScreen`/`HotelDetailScreen` only ever act on `Supabase.instance.client.auth.currentUser`; no backend change in this deployment touches `wishlist`/`visits` at all (confirmed by the migration scope audit, §6).
52. **GOING Friend Profile section**: backend now live in production (`event_attendance_select` correctly friend-gated, confirmed §16) — the Flutter section itself is unchanged from the implementation report.
53. **GOING → Event Detail**: pure client-side routing, no backend dependency.

## Step 2 regression (54–60)

54. **My Passport**: no backend change affecting `visits`/`photos`/`wishlist` reads — confirmed by migration scope audit (§6) and live policy re-read (§3).
55. **Visit privacy**: `visits_read` policy text re-confirmed byte-identical to the Step 2 deployment's own verified state.
56. **Wishlist friend access**: `wishlist_read` policy text re-confirmed unchanged.
57. **Photo friend access**: `photos_read` policy text re-confirmed unchanged; storage friend-read policy re-confirmed present.
58. **Trips private**: `planned_trips` policies re-confirmed owner-only on all four operations, unchanged.
59. **Add Visit close**: no backend or shared-widget dependency (`SheetDismissHandle`) touched by this deployment.
60. **Add Stay close**: same.

## Validation (61–63)

61. **`flutter analyze`**: `No issues found!`
62. **`flutter test`**: all pass.
63. **Test total**: 540 (the actual current baseline, confirmed fresh — not the 538 the implementation report last recorded; two additional tests were present at the start of this task, consistent with ordinary incremental test-suite growth, not a regression).

## Regression counts (64–73)

| Table | Before | After |
|---|---|---|
| profiles | 2 | 2 |
| friendships | 1 | 1 |
| visits | 26 | 26 |
| photos | 8 | 8 |
| wishlist | 5 | 5 |
| planned_trips | 3 | 3 |
| events | 1 | 1 |
| restaurants | 1362 | 1362 |
| hotels | 775 | 775 |
| award_history | 2168 | 2168 |

`event_attendance` began at 0 (table didn't exist), reached a temporary non-zero value only during controlled testing, and returned to exactly 0 after cleanup — the only table whose count changed at all during this deployment, and only transiently.

## Files / Safety (74–80)

74. **Deployment report created**: this file.
75. **Production write scope**: exactly two migrations applied (`20260815120000` primary, `20260815130000` follow-up fix) plus the controlled test data created/destroyed during verification (§43) — no other production write of any kind.
76. **Confirmation no canonical event changes**: the one real event row (`'t Preuvenemint`) was read-only throughout every test — never inserted, updated, or deleted; its own row was never touched, only `event_attendance` rows referencing it.
77. **Confirmation nothing staged**: `git diff --cached` empty.
78. **Confirmation nothing committed**: no `git commit` run.
79. **Confirmation nothing pushed**: no `git push` run.
80. **Final git status**: unchanged from before this task except for the two new migration files (`20260815120000...sql`, already present from the prior implementation task, and `20260815130000_social_foundation_step2b_revoke_anon_execute.sql`, newly added this task) and this report — see the final numbered report for the complete file list.

---

## Final status

**SOCIAL FOUNDATION STEP 2B — PRODUCTION DEPLOYED, READY FOR FINAL PHYSICAL-DEVICE REVIEW**
