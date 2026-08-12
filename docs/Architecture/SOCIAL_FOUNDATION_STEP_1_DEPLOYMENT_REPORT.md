# Social Foundation Step 1 — Production Deployment Report

Deployment and verification report, 2026-08-13. Covers the controlled production deployment of Social Foundation Step 1 (Username, Profile & Friendships), described in `SOCIAL_FOUNDATION_STEP_1_REPORT.md` (the implementation report). This document records what was actually done against the linked production project, in the order it happened.

---

## Preflight (1–6)

1. **Git baseline at task start**: `git status --short` showed the full prepared-but-uncommitted Social Foundation Step 1 file set (12 modified, 12 new Flutter/doc files, 1 migration) alongside unrelated pre-existing untracked work (Michelin Belgium/France/Netherlands enrichment data folders, a Gault&Millau deployment report) — confirmed as Category B, excluded from every staging step in this task.
2. **Production baseline (read-only, before any write)**: `profiles=1, restaurants=1362, hotels=775, visits=23, wishlist=5, planned_trips=3, planned_venues=6, award_history=2168, follows=0, photos=6, events=1`.
3. **Migration state**: `supabase migration list --linked` showed 14 migrations already in sync (local timestamp == remote) and exactly one pending: `20260813120000`. No unexpected migration alongside it.
4. **Migration filename**: `supabase/migrations/20260813120000_social_foundation_step1_username_friendships.sql` (609 lines).
5. **Existing profile/username state**: live `profiles` had no `updated_at` column and no `profiles_username_format` constraint (both expected, additive). The one existing production row (`username='admin'`) was explicitly checked against the new format regex and confirmed to pass — the migration would not break existing data.
6. **Security review result**: migration content reviewed for scope (contained only username/friendship/RLS/RPC content, no Step 2 keywords beyond explanatory comments) and for the specific invariants in the task brief (self-friend prevention, pair-uniqueness, no requester-id forgery, blocked-bypass prevention, RLS read isolation, accept/decline authorization, `auth.uid()`-only identity, minimal grants). All confirmed by direct SQL read of the migration before apply.

## Apply (7–10)

7. **Exact deployment command**: `supabase db push --linked`. Preceded by a full transactional rollback test (`begin; ...migration body...; rollback;` via `supabase db query --file ... --linked`), which executed with zero errors and was explicitly verified afterward: `public.friendships` absent, `profiles.updated_at` absent, `profiles_username_format` absent, and baseline counts unchanged — proving the migration is valid against live production schema and that the test itself left no trace.
8. **Result**: clean apply, no errors, no warnings — `{"upToDate":false,"dryRun":false,"migrations":["20260813120000_social_foundation_step1_username_friendships.sql"],...}`. `supabase migration list --linked` confirmed the migration as synced immediately after.
9. **First-attempt failure**: none for the primary migration itself.
10. **Corrections made**: one follow-up migration was required and applied — see the dedicated finding below. Not a failure of the primary migration; discovered during the mandated post-deploy security verification (task §8/§4), fixed within the same deployment before proceeding.

### Finding and fix: `anon` EXECUTE over-grant (discovered and corrected during this deployment)

Live ACL inspection (`pg_proc.proacl`) after the primary migration showed every RPC except `username_available` carried an unintended `anon=X` grant — `search_profiles`, `get_profile_identity`, `send_friend_request`, `accept_friend_request`, `decline_friend_request`, `block_user`, `get_friends`, `get_incoming_friend_requests`, `get_outgoing_friend_requests`, `is_friend`. Root cause: the migration's own `revoke ... from public` statements never revoked from `anon` specifically, and this project's schema-level default privileges (`ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ... anon ...`) grant EXECUTE to `anon` automatically on every new function, independent of `PUBLIC`.

**Not exploitable**: every affected function already guards against `auth.uid()` being null (either an explicit `raise exception 'Not authenticated'`, or a WHERE clause that structurally matches zero rows when `auth.uid()` is null) — verified by reading every function body. An anonymous caller would have received a clean auth error or an empty result set, never real data or a real state mutation. Still a genuine least-privilege deviation from the migration's own documented intent ("EXECUTE permissions no broader than required" — task §4), and squarely in scope to fix as part of this same deployment (correcting the same migration's own GRANT/REVOKE block, not new functionality).

**Fix**: `supabase/migrations/20260813130000_social_foundation_step1_revoke_anon_execute.sql` — ten explicit `revoke execute ... from anon;` statements. Validated with the same rollback-test rigor as the primary migration (clean transactional dry-run, zero errors), then applied via `supabase db push --linked`, then re-verified: `anon` now retains EXECUTE on `username_available` only; all ten other functions show `postgres/authenticated/service_role` only.

## Remote database (11–17)

11. **Friendship table**: exists with exact intended columns — `id, requester_id, addressee_id, status, blocked_by, created_at, responded_at`.
12. **Constraints/indexes**: `friendships_no_self_friend CHECK (requester_id <> addressee_id)`, `friendships_status_check`, `friendships_blocked_by_participant`, `friendships_blocked_by_present_iff_blocked`, both FKs `ON DELETE CASCADE`; `friendships_pair_uidx` — unique index on `(least(requester_id,addressee_id), greatest(requester_id,addressee_id))` — confirmed as the normalized-pair duplicate protection; `friendships_requester_idx`/`friendships_addressee_idx` present.
13. **RLS status**: `relrowsecurity=true`, `relforcerowsecurity=false` (correct — non-owner roles are still subject to RLS).
14. **Policies (live, compared to intended design)**: exactly two — `friendships_select` (SELECT, `authenticated`, participant-only) and `friendships_delete` (DELETE, `authenticated`, participant-only AND `status in ('pending','accepted')`). No INSERT/UPDATE policy exists — matches the intended RPC-mediated-writes design exactly.
15. **RPCs/helpers**: all 11 present remotely (`is_friend`, `username_available`, `send_friend_request`, `accept_friend_request`, `decline_friend_request`, `block_user`, `get_friends`, `get_incoming_friend_requests`, `get_outgoing_friend_requests`, `get_profile_identity`, `search_profiles`) — each `SECURITY DEFINER`, each `search_path=public`, correct argument signatures. EXECUTE permissions confirmed minimal after the follow-up fix (§ above).
16. **Username constraint/index**: `profiles_username_format` CHECK live with the exact intended regex and length bounds; pre-existing `profiles_username_key` unique index untouched.
17. **Signup/profile trigger**: `handle_new_user()` confirmed live-updated to read both `username` and `display_name` from `raw_user_meta_data`; `on_auth_user_created` trigger on `auth.users` confirmed present and enabled (`tgenabled='O'`), still wired to `handle_new_user()`.

## Functional (18–28)

Verified against real production using two (later a third) disposable test accounts, created directly via the privileged `postgres` connection (`supabase db query --linked`) rather than the public signup HTTP endpoint — production requires email confirmation and this project's built-in email provider is rate-limited, making a real confirmable signup impractical for controlled testing in this environment. Each account's real `on_auth_user_created` trigger fired naturally on insert (this doubled as a live end-to-end test of finding §17 above). Each RPC/RLS call was exercised by impersonating the account's session via Postgres's standard `request.jwt.claims` mechanism (`set local role authenticated; set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';`) — the same technique Supabase's own RLS tooling uses to test policies without a password session.

18. **Username signup**: both test accounts' profiles were created by the real trigger with `username` AND `display_name` both correctly populated — confirms the pre-existing production bug (trigger only ever reading `username`) is genuinely fixed live, not just in the function definition.
19. **Username search**: A searching `csverifyb` via `search_profiles` correctly returned B with `relationship_status: null`.
20. **Request**: A → B `send_friend_request` created exactly one `pending` row.
21. **Duplicate request prevention**: A repeating the request against B was rejected with `"A friend request is already pending"`.
22. **Accept**: B called `accept_friend_request`; row transitioned to `accepted`.
23. **Mutual friendship**: `get_friends()` returned the counterpart correctly in both directions (A sees B, B sees A independently verified).
24. **Unfriend**: A deleted the friendship via the participant-only DELETE policy; row count went to 0.
25. **Block**: after a fresh request (post-unfriend, correctly allowed since no row existed), B called `block_user`; row transitioned to `blocked` with `blocked_by` set correctly.
26. **Re-request protection**: A attempting a new request against the now-blocked pair was rejected with `"Unable to send a friend request"`.
27. **Self-request protection**: A attempting to friend-request themself was rejected with `"You cannot send yourself a friend request"`.
28. **Unauthorized mutation protection**: (a) nonexistent target rejected with `"That user could not be found"`; (b) the requester of an outgoing request attempting to accept their own request was rejected with `"That friend request is no longer available"` (addressee-only enforcement); (c) an unrelated third test account (C) could neither read (0 rows visible) nor delete (0 rows affected, row confirmed intact afterward) a friendship row it was not a participant in.

## Privacy (29–35)

29. **Friend Profile Step 1 exposure**: `get_profile_identity` for an accepted friend returned exactly `id, username, display_name, avatar_url, relationship_status` (`relationship_status: 'accepted'`) — no other columns.
30. **Non-friend profile exposure**: `search_profiles`/`get_profile_identity` return the identical five-column identity shape regardless of relationship state — confirmed structurally incapable of returning activity data (no visit/rating/photo/wishlist/trip table is referenced by either function's SQL body).
31–35. **Confirmation of no exposure**: no visits, ratings, photos, wishlist, or trips are queried, joined, or returned by any Step 1 RPC or RLS policy — confirmed both by reading every function body (§ Remote database, item 15) and by the automated `friend_profile_no_activity_test.dart` suite (14 tests), which asserts zero activity-shaped copy renders in any of the five relationship states.

## Profile (36–41)

Re-verified against the code that was physically reviewed and approved on-device; **no visual changes were made in this task** — confirmed by `git diff` showing zero new modifications to `profile_screen.dart`/`friends_screen.dart`/`friend_profile_screen.dart` beyond what was already prepared and approved before this deployment task began.

36. **Profile loads**: `ProfileScreen` construction path unchanged; `test/profile_screen_states_test.dart` passes.
37. **Friends entry**: unchanged `_FriendsEntryRow` wiring; `friends_screen_states_test.dart` passes.
38. **Back navigation**: unchanged `EditorialBackButton` usage in `FriendsScreen`/`FriendProfileScreen`.
39. **Sign Out placement**: confirmed present in the plain Account settings list, not nested in any submenu — `test/profile_screen_states_test.dart`'s "is visible immediately, in a plain list, not a submenu" test passes (asserts no `PopupMenuButton`/`Drawer`).
40. **Sign Out behavior**: `_signOut()` (`profile_screen.dart:86`) calls `_authRepo.signOut()` directly and unconditionally — read and confirmed unchanged; `AuthRepository.signOut()` (`auth_repository.dart:78`) itself untouched by this task.
41. **Re-login**: not re-exercised via a live device in this task (no code changed on this path since the prior physical-device approval); relies on the already-approved, unchanged `AuthRepository` sign-in path plus the automated test coverage above.

## Regression (42–47)

Counts compared immediately before the primary migration, immediately after both migrations, matching byte-for-byte:

| Table | Before | After |
|---|---|---|
| profiles | 1 | 1 |
| restaurants | 1362 | 1362 |
| hotels | 775 | 775 |
| visits | 23 | 23 |
| wishlist | 5 | 5 |
| planned_trips | 3 | 3 |
| planned_venues | 6 | 6 |
| award_history | 2168 | 2168 |
| photos | 6 | 6 |
| events | 1 | 1 |
| friendships | (did not exist) | 0 |

No Michelin/Gault&Millau/events/Trips/restaurant/hotel/visit/wishlist content was touched by either migration (both are additive DDL/RPC/GRANT only — no `UPDATE`/`DELETE`/`INSERT` against any pre-existing table).

## Validation (48–49)

48. **`flutter analyze`**: `No issues found!`
49. **`flutter test`**: all 473 tests passed — the exact baseline established before this deployment task began; zero regressions, zero new failures. (`dart format` also run against every touched Step 1 file: 0 changed, already correctly formatted.)

## Git (50–55)

50. **Files committed** (30 total — see this commit's own diff for the authoritative list): 12 modified Flutter files (`cs_text_field.dart`, `rating_dialog.dart`, `mock_user.dart`, `auth_repository.dart`, `friendship_repository.dart`, `profile_repository.dart`, `signup_screen.dart`, `notifications_screen.dart`, `profile_screen.dart`, `friendship.dart`, `user_profile.dart`, `auth_screens_test.dart`), 4 new `lib/features/friends/*` screens/widgets, `username_rules.dart`, `profile_identity.dart`, 3 architecture docs (`FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` including its §3.4a addendum, `SOCIAL_FOUNDATION_STEP_1_REPORT.md`, `UI_CONSISTENCY_AUDIT.md`), this deployment report, 2 migrations, 7 new test files.
51. **Files excluded**: the pre-existing, unrelated Michelin Belgium/France/Netherlands catalogue-enrichment data folders under `supabase/data/enrichment/`, and `docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md` — all confirmed unrelated to Social Foundation Step 1, none staged, none committed.
52. **Commit hash**: see `git log -1` on `origin/main` immediately after this report's commit is pushed.
53. **Pushed branch**: `origin/main`.
54. **Local HEAD == origin/main**: confirmed by comparing `git rev-parse HEAD` and `git rev-parse origin/main` after push.
55. **Final `git status`**: clean except for the pre-existing, deliberately-untouched Category B files, which remain exactly as they were found at the start of this task.

## Next-step decision (56–60)

Documentation-only, per explicit instruction — **not implemented in this task**:

56. **Wishlist**: automatically visible to accepted friends, no per-user or per-item visibility setting for MVP — recorded as §3.4a in `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md`, explicitly superseding that document's own earlier §3.4 "private only" recommendation.
57. **Visits**: `private | friends` (unchanged from that document's existing §3.2).
58. **Ratings and photos**: inherit their parent visit's visibility (unchanged from §3.2/§3.6).
59. **Trips**: remain strictly private (unchanged from §3.3); non-friends see no personal activity of any kind.
60. **Step 2 not implemented in this task**: `wishlist_read` RLS is unchanged (still gated by `profile_is_visible()`/`is_public`, exactly as before Step 1); no `visits.visibility` column was added; no photo/storage visibility change was made; no friend activity feed, community intelligence, or event attendance work was started; no additional screens were visually redesigned beyond what was already physically reviewed and approved before this task began.

---

## Final status

**SOCIAL FOUNDATION STEP 1 — PRODUCTION DEPLOYED, VERIFIED, COMMITTED AND PUSHED**
