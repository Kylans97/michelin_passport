# Social Foundation Step 2 — Privacy & Friend Content

> **Status update, 2026-08-15**: this migration was subsequently deployed to production (re-verified live in `SOCIAL_FOUNDATION_STEP_2B_DEPLOYMENT_REPORT.md`'s own preflight, since Step 2's backend was deployed and confirmed working — including the PGRST204 fix — as a prerequisite before Step 2B's own deployment), physically reviewed and approved on-device, and committed/pushed alongside Step 2B. The "not deployed/committed/pushed" line immediately below describes this report's own state at the moment it was written — preserved as an accurate historical record of the implementation task, not the current state of the repository.

Implementation report, 2026-08-14. Prepared (migration written, validated against a local Postgres instance) but **not deployed to production, not committed, not pushed** — see Safety below. Builds directly on `SOCIAL_FOUNDATION_STEP_1_DEPLOYMENT_REPORT.md` (commit `b084c4c`, live in production) and the privacy model `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` §16 now documents as implemented.

---

## AUDIT

**1. Current visit schema/RLS (before this step).** `public.visits(id, user_id, entity_type, entity_id, visited_on, rating, notes, price_paid, currency, keys_at_visit, stars_at_visit, food_rating, service_rating, wine_rating, value_rating, menu_type)` — no visibility concept at all. `visits_read` (live in production): `for select to anon, authenticated using (profile_is_visible(user_id))` — public-by-default whenever the owner's `profiles.is_public` (defaults `true`) is set. Owner INSERT/UPDATE/DELETE already correctly scoped to `user_id = auth.uid()`.

**2. Current wishlist RLS.** Identical shape to visits: `wishlist_read for select to anon, authenticated using (profile_is_visible(user_id))`. No visibility column, no friends concept.

**3. Current photo row RLS.** `photos_read for select to anon, authenticated using (user_id = auth.uid() OR (is_public AND profile_is_visible(user_id)))`. `photos.is_public` defaults `true` and is never set/read anywhere else in the app (confirmed vestigial per the prior spike's own §1.3 finding).

**4. Current Storage policy.** Bucket `visit-photos`, private, path convention `{user_id}/{visit_id}/{filename}`. Live production audit found **two overlapping sets** of owner-only policies on `storage.objects` for this bucket: the migration-created `visit_photos_read`/`_insert`/`_delete` (role `authenticated`) and four **dashboard-created** policies with Supabase's own default template names — `"Users can read/upload/update/delete own stored visit photos"` (role `public`), including an UPDATE policy that exists live but was never part of any migration file. This is a genuine, real discrepancy from the expected migration-only state, found by live inspection, not assumed — documented here per the task's explicit instruction rather than silently worked around. Functionally harmless (both sets encode the identical owner-only predicate, and RLS policies OR together), but it means this bucket's authoritative security config is not fully captured in version control. Not fixed in this step (out of scope — a pre-existing configuration-drift issue, unrelated to what Step 2 needs to add) — flagged here as a recommended future cleanup.

**5. Current trip RLS.** `planned_trips`/`planned_venues`: owner-only read AND write, no anon/public grant of any kind — already exactly correct for "trips remain completely private." Confirmed unchanged by this step by construction: the new migration contains zero references to either table name (`grep -c` returns 0).

**6. `profiles.is_public` remaining usage.** Before this step, read by three policies: `visits_read`, `wishlist_read`, `photos_read` (via `profile_is_visible()`), plus directly (not via that function) by `profiles_read` itself (`using (is_public or id = auth.uid())` — profile-*row* discoverability, a Step 1-established, deliberately separate concern from activity visibility). **After this step**, `profile_is_visible()` has **zero remaining RLS callers** — `visits_read`/`wishlist_read`/`photos_read` are all rewritten to use `is_friend()` instead, never `profile_is_visible()`/`is_public`. `profiles.is_public` itself remains load-bearing for `profiles_read` only. Neither the column nor the function is dropped in this step — removing `profile_is_visible()` is a safe, genuinely-dead-code cleanup a future step could do without any behavior change, but wasn't required for correctness here, so it wasn't done (avoiding unrequested scope).

**7. Current friend-profile architecture (Step 1).** `FriendProfileScreen` + `_ProfileBody`: avatar/name/@username header, a `_RelationshipAction` switch over `RelationshipStatus` (none/pendingSent/pendingReceived/accepted/declined — `blocked` never surfaces as its own state; Step 1's RPCs already collapse it to `none`, preserved unchanged in this step per the task's own explicit instruction not to invent new blocked-handling). Deliberately rendered nothing beyond identity for every state, since Step 1 had no friends-visible content to show yet.

---

## VISIT PRIVACY

**8. Migration design.** `supabase/migrations/20260814120000_social_foundation_step2_visit_visibility.sql` — one migration, four parts: (a) `visits.visibility` column + CHECK; (b) `visits_read` rewrite; (c) `photos_read` rewrite; (d) `wishlist_read` rewrite; plus (e) one additive `storage.objects` SELECT policy. Kept as a single migration (unlike Step 1's two-migration apply-then-fix) since this was designed and fully verified before ever proposing it, with no post-hoc correction needed.

**9. `visibility` column definition.** `text not null default 'private' constraint visits_visibility_valid check (visibility in ('private', 'friends'))` — a CHECK constraint, matching this table's own existing convention (`visits_food_rating_valid` etc. from `20260805211243_add_visit_details.sql`), not a Postgres enum type (the project has no enum-type precedent anywhere, and CHECK is the smaller, already-idiomatic choice here).

**10. Default.** `'private'` — the deliberate protective default the task requires. No "public" value exists as a legal CHECK value at all, so a future accidental widening can't happen by merely changing a default; it would require a schema change.

**11. Existing-row backfill.** Achieved by the column default itself during the `ALTER TABLE ADD COLUMN ... NOT NULL DEFAULT 'private'` — a metadata-only operation on Postgres 11+ (no full-table rewrite, no separate UPDATE pass needed). Verified locally: all pre-existing rows read back as `'private'` immediately after the migration ran.

**12. New SELECT policy.** `visits_read for select to authenticated using (user_id = auth.uid() OR (visibility = 'friends' AND public.is_friend(user_id)))`. Narrowed from `anon, authenticated` to `authenticated` only — `anon` could never satisfy either clause (both key off `auth.uid()`, null for an unauthenticated caller), so this is a safe, behavior-preserving tightening, not a functional change for any real caller. Ratings/notes/menu_type/price_paid/keys_at_visit/stars_at_visit — every column on the row — inherit this exact policy automatically; no `rating_visibility`/`comment_visibility` fields were created.

**13. Owner write policies.** `visits_insert`/`visits_update`/`visits_delete` are **untouched** — still exactly `with check/using (user_id = auth.uid())`. A client can never write a visit on another user's behalf; unchanged and re-verified (forgery attempt in the test matrix below).

**14. Friendship helper usage.** Every new policy in this migration calls the Step 1 `public.is_friend(other_user_id uuid)` helper — a single `security definer` function checking a live `status = 'accepted'` friendship row, symmetric on either side. Not duplicated or reimplemented anywhere; this is the one and only place friendship-acceptance logic lives.

**15. Block/unfriend behavior.** Because every check is a live subquery (never a cached grant, never a copy of friendship state onto the content row), an unfriend or a block takes effect on the very next read of any visit/photo/wishlist row — verified directly, not assumed (see Security Tests below).

---

## VISIT UX

**16. Creation privacy control.** `VisitPrivacyToggle` (`lib/features/visits/widgets/visit_privacy_toggle.dart`) — a single row (label + description + a `Switch`), added to both `AddVisitSheet` (restaurant visits) and `AddStaySheet` (hotel stays, since stays are visits at the schema level and the privacy model applies uniformly — omitting stays would have left half of "visits" with no way to ever become friends-visible). Placed between Menu Type/Ratings and Notes — secondary to the actual recording, not a first-class section.

**17. Exact visible copy.** Label: **"Visible to friends"**. Supporting line: **"Friends can see this visit, your rating and photos."** No technical terms anywhere (no "RLS," "visibility," "row policy") — verified by an automated test that scans every rendered `Text` for those exact substrings.

**18. Default state.** OFF (`_friendsVisible = false`) on both sheets — maps to `VisitVisibility.private` on save, matching the column default.

**19. Edit-existing behavior.** Audited first: **no general visit-edit flow exists** (`VisitedRepository` only ever had insert + delete methods; `VisitDetailScreen`/`StayDetailScreen` only ever had a "Delete" action). Per the task's explicit instruction not to build a new edit architecture solely for this requirement, the smallest sensible seam was added instead: one new repository method, `VisitedRepository.updateVisitVisibility({userId, visitId, visibility})` (a single-column `UPDATE ... WHERE id = ? AND user_id = ?`), exposed as a second popup-menu item ("Make visible to friends" / "Make private") alongside the existing "Delete visit"/"Delete stay" action on both detail screens, plus a small restrained lock-icon + label badge next to the visit date showing current state. A user can freely toggle `private ↔ friends` on an existing visit without recreating it.

---

## PHOTOS

**20. Parent-visit inheritance.** Audited first: `photos.visit_id` is **nullable** (the table is polymorphic in principle, per its own `entity_type`/`entity_id` columns) — the new policy only extends friends-visibility for rows where `visit_id is not null`; a photo with no visit_id has no visibility signal to inherit and stays owner-only, matching the task's explicit "only modify the relevant visit-photo path" instruction.

**21. Photo row RLS.** `photos_read for select to authenticated using (user_id = auth.uid() OR (visit_id is not null AND exists(select 1 from visits v where v.id = photos.visit_id and v.visibility = 'friends' and is_friend(v.user_id))))`. `photos.is_public` is no longer referenced by this policy at all.

**22. Storage policy solution.** One new additive SELECT policy, `visit_photos_read_friends`, joining `public.photos.storage_path = name` to the same parent-visit-visibility check — deliberately **not** parsing `(storage.foldername(name))[2])::uuid` (would need an explicit UUID-format guard before casting, since a malformed path would otherwise throw and break the whole SELECT for unrelated callers; `photos.storage_path` is the actual source-of-truth link already relied on everywhere else in the app). The pre-existing owner-only policies (§4 above) are left untouched; Postgres RLS policies OR together, so this can only ever grant additional access, never remove any.

**23. URL/access strategy.** Unchanged: `PhotoRepository.resolveDisplayUrls` still calls `createSignedUrls` on the private bucket — no new RPC, no permanently-public URL, no client-side friendship decision. The signed-URL endpoint itself checks `storage.objects` SELECT RLS server-side before minting a URL, so the new policy is the actual enforcement point, exactly as intended.

**24. Owner upload/delete regression.** `photos_insert`/`photos_update`/`photos_delete` and the storage bucket's INSERT/DELETE policies are all untouched — confirmed by construction (migration never references them) and by the local test matrix (owner writes still succeed).

**25. Friend photo behavior.** Verified locally: an accepted friend viewing a friends-visible visit can read (a) the `photos` row and (b) the underlying storage object; the same friend reading a *private* visit's photo gets zero rows for both.

**26. Block/unfriend photo behavior.** Verified locally: after unfriending, and separately after blocking (even with the parent visit re-marked `friends`-visible specifically to prove this isn't just "no longer friends"), the same friend can read neither the photo row nor the storage object.

---

## WISHLIST

**27. New read rule.** `wishlist_read for select to authenticated using (user_id = auth.uid() OR public.is_friend(user_id))`.

**28. Owner behavior.** Unchanged — full read/write access to their own wishlist, verified.

**29. Friend behavior.** An accepted friend can read the owner's entire wishlist — verified locally (1 row visible to an accepted friend, matching the owner's own count).

**30. Non-friend behavior.** Zero rows — verified (a merely-pending relationship, tested explicitly, also returns zero).

**31. Block/unfriend behavior.** Zero rows immediately after either — verified locally, same live-subquery guarantee as visits/photos.

**32. Confirmation: no visibility column added.** `public.wishlist`'s own column list is untouched by this migration (confirmed by construction — the migration never issues `ALTER TABLE wishlist ADD COLUMN`). No per-item or per-user wishlist visibility setting exists anywhere in this implementation, per the explicit final MVP decision.

---

## FRIEND PROFILE

**33. Accepted-friend layout.** `FriendProfileScreen`'s existing header (avatar/name/@username) and `_RelationshipAction` are unchanged. For `relationshipStatus == accepted` only, two new sections are appended below the relationship action: **VISITED**, then **WISHLIST** — both built fresh for the dark editorial system (`AppColors.deepGreen`/`brandGreenLight`, `CsTypography`, `CsSpacing`), not by reusing the legacy light-card `RestaurantVisitsCard`/`WishlistCard` (which also carry an owner-only remove affordance that must never appear on someone else's content). No follower/following counts, likes, badges, post counts, or generic social metrics were added — the layout is exactly avatar → name → @username → relationship action → VISITED → WISHLIST, nothing else.

**34. VISITED.** Backed by `VisitedRepository.loadPassportVenues(friendUserId)` — **reused completely unchanged**; the friends-visibility rule lives entirely in `visits_read`/`photos_read`, never duplicated into this screen. Its `List<VenueEntry>` (grouped by venue, matching My Passport's own established grouping) is flattened to one row per visit and sorted newest-first *across* venues, per the task's explicit ordering instruction. The database's own RLS is the sole authority on which rows come back at all — this screen never fetches a broader set and filters client-side.

**35. WISHLIST.** Backed by `WishlistRepository.loadWishlistVenues(friendUserId)` — likewise reused completely unchanged, same RLS-is-the-authority guarantee.

**36. Rating/comment presentation.** `FriendVisitTile` shows exactly the visit's own `rating` (as "`n`/10") and `notes` (as a 3-line-max excerpt) — the same fields, the same values, as the owner's own Visit Detail screen. No separate "friend rating" concept was created; there is only ever one rating per visit.

**37. Photo presentation.** `FriendPhotoStrip` — a small read-only horizontal thumbnail row (not `VisitPhotoGrid`/`PhotoTile`, both of which always render an owner-facing delete badge that would be actively misleading here, since a friend can never delete another user's photo). Resolves signed URLs the same way the owner's own photo grid does; an empty/unauthorized result renders identically to "no photos," never an error that would let a viewer distinguish the two.

**38. Empty states.** VISITED: **"No shared visits yet."** — deliberately not "hasn't visited anywhere," since the friend may simply have only private visits (task's own explicit instruction). WISHLIST: **"Nothing saved yet."**

**39. Non-friend state.** Unchanged from Step 1 — identity only, `_RelationshipAction` shows "Add friend."

**40. Pending state.** Unchanged from Step 1 — identity only (`pendingSent`: "Request sent"; `pendingReceived`: Accept/Decline row). VISITED/WISHLIST futures are never even created for a non-accepted relationship (`_visitedFuture`/`_wishlistFuture` stay `null` until identity resolves as `accepted`), not merely hidden in the UI after being fetched.

**41. Blocked state.** Preserved exactly as Step 1 already established: `get_profile_identity` never surfaces `blocked` as a distinct status (it collapses to `none`/"Add friend" on both sides, an existing, already-reviewed Step 1 design decision this step does not revisit) — and since VISITED/WISHLIST are gated on `accepted` specifically, a blocked pair structurally can never see them, with no new blocked-handling code needed or added.

**42. Confirmation: no Trips exposure.** `planned_trips`/`planned_venues` are never queried, joined, or referenced anywhere in `FriendProfileScreen` or its new section widgets — confirmed by reading every new/changed file in this step; zero references exist.

---

## SECURITY TESTS

All run against a **local** Postgres instance (`docker exec supabase_db_michelin_passport`) with the migration applied, using three real local test profiles already present from prior Step 1 local testing (`usera`=A/owner, `userb`=B, `chef_c.28`=C), impersonated via Postgres's standard `set local role authenticated; set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';` inside explicit `BEGIN`/`COMMIT` blocks — the same technique used to verify Step 1 against production. Every result below is the actual query output, not an assumption; two false-positive runs (once from `SET LOCAL` outside a transaction block silently having no effect, once from re-running a non-idempotent setup script) were caught and corrected before accepting these results — see the mid-task narration for the exact detection.

**43. Private visit matrix.** A (owner) reads own private+friends visits → 2 rows. B (accepted friend) reads → 1 row (friends visit only). C (pending, not accepted) reads → 0 rows.

**44. Friends visit matrix.** Same run as above — B sees exactly the one `visibility='friends'` row, never the private one.

**45. Wishlist matrix.** A → 1 row. B (accepted) → 1 row. C (pending) → 0 rows.

**46. Photo matrix.** Mirrors parent visit visibility exactly: B (accepted) reads photos → 1 row (the photo on the friends visit only); the same for the storage object (`storage.objects` SELECT → 1 row, the friends-visit object only). C → 0 rows on both.

**47. Trip regression.** Proven by construction (§5) — zero references to `planned_trips`/`planned_venues` in the migration file. Not re-tested via live data this session because local `countries` reference data is empty (a pre-existing, unrelated, already-documented local seed-data gap — see §25 of the task/§Local verification below); the by-construction proof was judged sufficient and the strongest available given that constraint, per the task's own explicit "document the limitation, use static SQL review" instruction.

**48. Unfriend regression.** A and B's friendship deleted → B's subsequent reads of visits, wishlist, and photos all return 0 rows — verified in the same session, immediately after the friends-state matrix above, using the same fixture data (no rows rewritten; the friendship row's removal alone caused the change).

**49. Block regression.** A blocks B, **and** the previously-private visit was deliberately re-marked `visibility='friends'` again (specifically to prove blocking overrides the content's own visibility setting, not merely "no longer friends") → B's reads of visits, wishlist, and the storage object all return 0 rows.

**Additional, beyond the task's minimum matrix**: owner-write regression (A can still update their own visit's visibility: `UPDATE 1`) and a forgery attempt (B tries to update A's private visit's visibility: `UPDATE 0`, RLS silently matches zero rows rather than erroring) were also run and passed.

All local test fixture rows (visits, photos, wishlist entries, storage objects, the temporary friendship rows) were deleted after testing; the two pre-existing local friendship rows from before this task (unrelated pending/blocked relationships between the same three test accounts) were left exactly as found. Two harmless local-only `storage.objects` metadata rows could not be removed via raw SQL (Supabase's own `storage.protect_delete()` trigger requires the Storage API, not a direct `DELETE`) — flagged here rather than silently left undocumented; they reference no real file bytes and have no effect on anything.

---

## DATABASE

**50. Exact migration files prepared.** One: `supabase/migrations/20260814120000_social_foundation_step2_visit_visibility.sql`.

**51. Confirmation not applied to production.** No `supabase db push` (or any other write command) was run against `--linked` production at any point in this task — every production-facing command this task issued was read-only (`supabase db query "select ..." --linked`, `supabase migration list --linked`), used only for the preflight audit (§ AUDIT above). The migration exists solely as a local file plus a local-database test run.

**52. Local verification result.** Applied cleanly (`psql -v ON_ERROR_STOP=1 < migration.sql` → `BEGIN / ALTER TABLE / DROP POLICY / CREATE POLICY ×3 / CREATE POLICY / COMMIT`, zero errors). Full authorization matrix (§43-49) passed completely on the second, corrected run. Local database required a one-time local-only `GRANT SELECT/INSERT/UPDATE/DELETE ... TO authenticated` on `visits`/`wishlist`/`photos`/`planned_trips`/`storage.objects` before impersonated queries would even reach RLS — a known, previously-documented local-environment gap (this raw Docker Postgres instance lacks the ambient default-privilege bootstrap a hosted Supabase project's dashboard supplies automatically; production was already confirmed in Step 1 to have these grants). This grant is local-only, was not applied to production, and does not weaken or change anything about the RLS logic itself.

**53. Production read-only audit result.** Counts recorded before any change: `visits=23, wishlist=5, photos=6, planned_trips=3, profiles=1, friendships=0`. Live `visits_read`/`wishlist_read`/`photos_read`/`planned_trips`*/`storage.objects` policies inspected and matched exactly the expected post-Step-1 state, with the one documented exception (§4 above — the storage.objects dashboard-policy duplication, pre-existing and unrelated to Step 1 or Step 2's own changes).

**54. Migration ordering.** Single migration, self-contained — no ordering dependency on any other unapplied migration. Depends only on already-live Step 1 objects (`public.is_friend()`, `public.friendships`), confirmed present in production before this migration was even drafted.

---

## FLUTTER

**55. Exact files added.**
- `lib/features/visits/widgets/visit_privacy_toggle.dart`
- `lib/features/friends/widgets/friend_visit_tile.dart`
- `lib/features/friends/widgets/friend_wishlist_tile.dart`
- `lib/features/friends/widgets/friend_photo_strip.dart`
- `test/visit_visibility_test.dart`
- `test/visit_privacy_toggle_test.dart`
- `test/friend_visit_wishlist_tiles_test.dart`
- `test/friend_profile_visited_wishlist_sections_test.dart`
- `docs/Architecture/SOCIAL_FOUNDATION_STEP_2_IMPLEMENTATION_REPORT.md` (this file)
- `supabase/migrations/20260814120000_social_foundation_step2_visit_visibility.sql`

**56. Exact files modified.**
- `lib/models/visit.dart` (new `VisitVisibility` enum, `Visit.visibility` field)
- `lib/data/repositories/visited_repository.dart` (`visibility` in `_visitColumns`/insert path/`markVisited`/`markHotelStay`; new `updateVisitVisibility`)
- `lib/features/visits/widgets/add_visit_sheet.dart` (privacy toggle wired into save)
- `lib/features/visits/visit_detail_screen.dart` (visibility toggle menu item + badge)
- `lib/features/stays/widgets/add_stay_sheet.dart` (privacy toggle wired into save)
- `lib/features/stays/stay_detail_screen.dart` (visibility toggle menu item + badge)
- `lib/features/friends/friend_profile_screen.dart` (VISITED/WISHLIST sections for accepted friends)
- `docs/Architecture/FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` (new §16, implemented-status)

**57. Responsive results.** 320px and 390px widths, and 1.6× text scale, tested explicitly for `VisitPrivacyToggle` and `FriendVisitTile`/`FriendWishlistTile` (including deliberately long restaurant/hotel/city/country names) — one real overflow was found and fixed during this process (`FriendVisitTile`'s date+award-badge row at 1.6× scale; fixed by wrapping the date text in `Flexible` with ellipsis) rather than left unnoticed.

**58. Accessibility results.** `VisitPrivacyToggle` uses a standard Material `Switch` (native accessibility semantics); tap targets follow the existing sheet's established row-padding conventions; no color-only state indication (the visit-detail badge pairs an icon with a text label, never an icon alone).

**59. `flutter analyze`.** `No issues found!`

**60. `flutter test` + baseline comparison.** Baseline immediately before this task's changes: 473/473 (confirmed fresh, not assumed, from the Step 1 deployment task's own final validation pass, the most recent prior test run). Final count and pass/fail reported in Validation below, run fresh at the end of this task.

---

## DOCUMENTATION

**61. Architecture doc update.** `docs/Architecture/FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` §16 (new) documents the implemented shape for visits/ratings/photos/wishlist/trips/non-friend exactly as required, plus the Storage security solution and the storage-policy-duplication finding.

**62. Implementation report.** This document.

---

## SAFETY

**63. No production writes.** Confirmed — every command issued against `--linked` production this task was a read-only `select`/`migration list`.

**64. No migration applied remotely.** Confirmed — `supabase db push` was never invoked in this task.

**65. No restaurant/hotel/catalogue changes.** Confirmed — the migration touches only `visits`, `photos`, `wishlist`, and `storage.objects` policies/columns; zero references to `restaurants`, `hotels`, `restaurants_full`, `hotels_full`, or any catalogue/import table.

**66. No event/community changes.** Confirmed — zero references to `events`, `event_restaurants`, `event_hotels`, or any community/aggregate table or RPC.

**67. No trip visibility changes.** Confirmed by construction (§5, §47) — zero references to `planned_trips`/`planned_venues`.

**68. Nothing staged.** See Git Audit below.

**69. Nothing committed.** Confirmed — no `git commit` was run.

**70. Nothing pushed.** Confirmed — no `git push` was run.

---

SOCIAL FOUNDATION STEP 2 — PRIVACY & FRIEND CONTENT READY FOR PHYSICAL-DEVICE AND PRE-DEPLOYMENT REVIEW
