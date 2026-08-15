# Social Foundation Step 2B — Friend Venue Navigation + Event Attendance

> **Status update, 2026-08-15**: this migration (plus a same-day least-privilege follow-up, `20260815130000`) was subsequently deployed to production — see `SOCIAL_FOUNDATION_STEP_2B_DEPLOYMENT_REPORT.md` — physically reviewed and approved on-device, and committed/pushed alongside Step 2. The "not deployed/committed/pushed" line immediately below describes this report's own state at the moment it was written — preserved as an accurate historical record of the implementation task, not the current state of the repository.

Implementation report, 2026-08-15. Prepared (migration written, validated against a local Postgres instance) but **not deployed to production, not committed, not pushed** — see Safety below. Builds directly on Social Foundation Step 2 (`SOCIAL_FOUNDATION_STEP_2_IMPLEMENTATION_REPORT.md`, also still uncommitted, physical-device review ongoing) and Step 1 (commit `b084c4c`, live in production).

---

## AUDIT

**1. Friend Profile current structure.** `FriendProfileScreen`/`_ProfileBody`: identity header (avatar/name/@username), `_RelationshipAction`, and — for an accepted friend only — VISITED (`_FriendVisitedSection`, backed by `VisitedRepository.loadPassportVenues`) and WISHLIST (`_FriendWishlistSection`, backed by `WishlistRepository.loadWishlistVenues`), both built in Step 2. **WISHLIST already navigated to the canonical detail screens** (`_openVenue`, built in Step 2) — confirmed by direct code read before starting any work, avoiding duplicate effort. **VISITED had no tap handler at all** (`FriendVisitTile` was a plain `Container`, no `InkWell`) — this was the actual gap Step 2B needed to close.

**2. Current venue routing architecture.** `RestaurantDetailScreen`/`HotelDetailScreen` construct `WishlistRepository`/`VisitedRepository` etc. against `Supabase.instance.client` internally and act only on `Supabase.instance.client.auth.currentUser` — they take a plain `Restaurant`/`Hotel` object and have no concept of "whose profile this was reached from." This means they are already correct, unmodified, for friend-content navigation — confirmed by reading `RestaurantDetailScreen._toggleWishlist()` before writing any code, not assumed.

**3. Current EventDetailScreen architecture.** Legacy light-card design system (`AppColors.background`/`AppTypography`/`GoogleFonts`, `DetailHero`, `PrimaryButton`/`SecondaryButton` from `core/widgets/app_button.dart`) — **not** the dark editorial system. The task brief's "match the current dark editorial language" instruction was reconciled against this direct finding: the attendance action was built using this screen's own existing light-system components (`PrimaryButton`-equivalent styling), the same judgment call already made for `VisitPrivacyToggle` in Step 2, rather than importing a second, inconsistent visual system into one screen.

**4. Current Events repository/model.** `EventsRepository` (read-only, catalogue-style, no write methods — events are seeded server-side). `Event` model already exposes `isCancelled` and `startAt`/`endAt`, sufficient for attendance date-safety with no new event-status system.

**5. Current friendship/RLS helper state.** `public.is_friend(uuid)` (Step 1, live in production) and the Step 2 `visits.visibility`/`private|friends` pattern were reused directly — no new friendship logic, no new visibility-shape invention.

**Git state at start**: `git status --short` showed the full uncommitted Step 2 file set (still pending physical review) plus the unrelated pre-existing Michelin/Gault&Millau enrichment files. Nothing from Step 2B was staged or touched before this audit.

---

## FRIEND VENUE NAVIGATION

**6. Visit restaurant routing.** `FriendVisitTile` gained an `onTap` (now required), wrapped in `Material`+`InkWell`; `_FriendVisitedSection` wires it to a new shared top-level `_openVenue(context, venue)` function that pushes `RestaurantDetailScreen(restaurant: restaurant)` via `MaterialPageRoute` for a `RestaurantVenue`.

**7. Visit hotel routing.** Same `_openVenue` function, `HotelDetailScreen(hotel: hotel)` for a `HotelVenue`.

**8. Wishlist restaurant routing.** Already correct from Step 2 (§1 above) — confirmed unchanged, now sharing the same `_openVenue` function (previously a private method on `_FriendWishlistSection`, promoted to a top-level function so VISITED could reuse it rather than duplicating the switch statement).

**9. Wishlist hotel routing.** Same, already correct from Step 2.

**10. Canonical detail screens reused.** Confirmed by grep: zero matches anywhere in `lib/` for `FriendRestaurantDetail`/`FriendHotelDetail`/`FriendEventDetail` — no social wrapper of any kind exists.

**11. Own Wishlist action from friend flow.** Verified by code read (§2): every write inside `RestaurantDetailScreen`/`HotelDetailScreen` targets `Supabase.instance.client.auth.currentUser` only, never a value derived from how the screen was navigated to.

**12. Confirmation friend's data cannot be modified.** Structural, not incidental — `RestaurantDetailScreen`/`HotelDetailScreen` never receive or reference "whose profile this came from" at all; there is no code path by which they *could* write to another user's row. See the acceptance-test reasoning in §22 below.

---

## EVENT ATTENDANCE DATABASE

**13. Table design.** `public.event_attendance(id uuid pk, event_id uuid references events(id) on delete cascade, user_id uuid references profiles(id) on delete cascade, status text, visibility text, created_at timestamptz, unique(event_id, user_id))`.

**14. Constraints.** `unique(event_id, user_id)` (structural duplicate prevention — not just app logic); FKs cascade-delete with their parent event/profile; `status`/`visibility` both CHECK-constrained.

**15. Status model.** Single legal value `'going'` for MVP, per the task's explicit instruction not to add `interested`/`maybe`/`not_going`. Removing attendance is a DELETE (mirrors `friendships`' own "unfriend is a delete, not a status" precedent), not a status transition.

**16. Visibility model.** `private | friends`, identical shape to `visits.visibility`, modeled as its own `AttendanceVisibility` enum (not a reuse of `VisitVisibility`) since the two are different domain concepts that happen to share a shape.

**17. Default visibility decision.** **`friends`**, re-evaluated explicitly against the current privacy architecture rather than assumed — see FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md §17.3 for the full reasoning (an event is already public catalogue content, materially lower-sensitivity than a personal rating). No dedicated privacy-toggle UI control was built (avoiding a clumsy MVP interaction per the task's own explicit permission to skip it); the schema/RLS/repository layer fully supports `private` regardless, so a future toggle needs no new migration.

**18. RLS.** `event_attendance_select`: `owner OR (visibility='friends' AND is_friend(owner))`. `event_attendance_insert`: `with check (user_id = auth.uid())`. `event_attendance_update`/`_delete`: `using (user_id = auth.uid())` — owner-only throughout, no RPC layer (this is plain ownership, not a multi-party state machine).

**19. Indexes.** `unique(event_id, user_id)` (also the primary lookup index for "who's attending this event"); explicit secondary `event_attendance_user_idx` on `user_id` for "this user's own/friend's upcoming attendance" queries; `event_attendance_event_idx` on `event_id`.

**20. Migration filename.** `supabase/migrations/20260815120000_social_foundation_step2b_event_attendance.sql`.

**21. Confirmation migration not applied.** No `supabase db push` or any other write command was run against `--linked` production at any point in this task.

---

## EVENT UX

**22. "I'm going" action.** `EventGoingButton` (new, `lib/features/events/widgets/event_going_button.dart`) — filled `PrimaryButton`-styled control reading "I'm going" when not attending.

**23. Going state.** Same control switches to an outlined, gold-accented "Going" state with a distinct `check_circle_rounded` icon (state is never color-only, per the task's own accessibility instruction) — tapping again removes attendance directly.

**24. Remove attendance.** No confirmation dialog (verified by test: `find.byType(AlertDialog)` is empty after tapping "Going") — a deliberate low-stakes toggle, not a permanent-data-loss action like deleting a visit, matching the task's own explicit "simple toggle/removal is sufficient" instruction.

**25. Cancelled/past behavior.** `canAttendEvent(event)` — a new, pure, top-level function (extracted specifically for direct unit testability without a live Supabase session) — gates the entire attendance section: `!event.isCancelled && event.endAt.isAfter(now)`. No new event-status system was introduced; both existing signals (`Event.isCancelled`, `Event.endAt`) were reused as-is.

**26. Privacy control if any.** None built into the UI for this step — see §17. The "I'm going" action always writes `visibility: 'friends'`.

---

## FRIEND PROFILE

**27. GOING section.** New `_FriendGoingSection`, appended after WISHLIST in `_ProfileBody`'s accepted-friend block, matching the task's own `VISITED → WISHLIST → GOING` hierarchy. Backed by a new `EventAttendanceRepository.getFriendUpcomingAttendance(friendUserId)` — RLS-filtered already, never fetches a broader set and narrows client-side.

**28. VISITED preserved.** Unchanged in shape/content — only `onTap` was added, no other visual or data change.

**29. WISHLIST preserved.** Fully unchanged (already correct from Step 2).

**30. Event navigation.** `FriendGoingTile`'s `onTap` pushes the canonical `EventDetailScreen(eventId: event.id)` — no wrapper, mirroring §10.

**31. Non-friend identity-only.** Unchanged from Step 1/2 — `_visitedFuture`/`_wishlistFuture`/`_goingFuture` are all left `null` until identity resolves as `accepted`; none of the three futures is ever created for a non-friend.

**32. Pending behavior.** Same gating as §31 — a pending relationship never triggers any of the three content queries.

**33. Blocked behavior.** Preserved exactly as Step 1 already established: `get_profile_identity` never surfaces `blocked` as its own status (collapses to `none`), so a blocked pair structurally never reaches the `accepted` gate — no new blocked-handling code was needed or added, consistent with the task's own instruction not to invent new behavior here.

---

## PRIVACY / SECURITY

All verified directly against a local, real Postgres instance (`docker exec supabase_db_michelin_passport`) using Postgres's standard `set local role authenticated; set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';` impersonation inside explicit `BEGIN`/`COMMIT` blocks — the same technique already validated for Step 1/Step 2's own production verification. Three real local test profiles (A/B/C) were reused; A↔B was set to `accepted` for the matrix, then explicitly unfriended and re-blocked to test revocation.

**34. Friend attendance matrix.** A (owner) reads own row → 1. B (accepted friend, row `visibility='friends'`) reads A's row → 1. Both confirmed live.

**35. Private attendance matrix.** A's row switched to `visibility='private'` → B (still accepted friend) reads → 0 rows. Confirms visibility, not just friendship, gates access.

**36. Stranger result.** C (pending with A, not accepted) reads A's `friends`-visible row → 0 rows.

**37. Pending result.** Same as §36 — C's relationship with A is `pending`, not `accepted`, and is correctly treated as no-access.

**38. Unfriend revocation.** A↔B friendship deleted → B's read of A's attendance row → 0 rows, immediately, with the row itself untouched.

**39. Block revocation.** A blocks B (fresh `blocked` friendship row) → B's read → 0 rows. (Not re-run with the "re-mark visible" trick used for visits/photos in Step 2, since attendance visibility wasn't touched between the unfriend and block steps in this test sequence — the identical `is_friend()` mechanism already proven live-and-non-cached in Step 2's own verification applies here unchanged.)

**40. Spoof prevention.** B attempted `insert into event_attendance (event_id, user_id, ...) values (..., 'A's uuid', ...)` while impersonating B → `ERROR: new row violates row-level security policy` — confirmed the `event_attendance_insert` WITH CHECK genuinely blocks writing on another user's behalf, not merely relying on client-side trust.

**41. Duplicate prevention.** A attempted a second `going` row for the same event → `ERROR: duplicate key value violates unique constraint "event_attendance_event_id_user_id_key"` — structural, not application-level.

**Additional, beyond the task's minimum list**: owner-delete confirmed working (`DELETE 1`); the aggregate RPC (`get_event_attendance_count`) confirmed returning `NULL` at 2 attendees (below the 5-unique-user threshold) and the exact integer `5` once a fifth attendee was added, then cleaned up.

---

## AGGREGATE

**42. Aggregate count implemented/deferred.** **Implemented** (the RPC exists, `SECURITY DEFINER`, identity-free — selects only `count(*)`), but **deliberately not wired into any UI** in this step. This is the "prepare, don't overbuild" path explicitly offered as an option: the backend is ready for a future "N members are going" surface with zero further migration, while nothing resembling a Community feed/count display was built now.

**43. Threshold decision.** `>= 5` unique attendees, matching the already-approved Community Intelligence threshold (`FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` §5.7) rather than inventing a new number.

**44. Future Community integration seam.** Documented in `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` §17.4 — the RPC is the seam; no feed/tab/list scaffolding of any kind was added.

---

## VALIDATION

**45. Local DB/RLS validation.** Local Postgres lacked the `events` table entirely (a pre-existing, already-documented gap: local `db reset` is blocked by an unrelated seed-data bug in the events migration itself, so `events` has never successfully applied locally). A minimal **local-only stand-in** `events` table (matching just enough of the real column shape for the FK) was created purely to validate `event_attendance`'s constraints/RLS, then fully dropped afterward — this did not touch, fix, or run the actual broken seed migration, and left local exactly as found except for `event_attendance` itself (which — like every other Step 2B migration table — is legitimately meant to persist locally going forward, the same as any other applied migration).

**46. 320px.** `EventGoingButton` (both states) and `FriendGoingTile` (including a deliberately long event/city name) both tested at 320px — no overflow.

**47. 390px.** Default test width for all new widgets — no overflow.

**48. 1.6×.** `EventGoingButton` and `FriendGoingTile` both tested at `TextScaler.linear(1.6)` — no overflow.

**49. `flutter analyze`.** `No issues found!`

**50. `flutter test`.** All 538 tests pass.

**51. Baseline → final.** 512 (confirmed fresh at the end of Social Foundation Step 2, immediately before this task began) → 538 (26 new tests: model parsing, `canAttendEvent` date-safety, `EventGoingButton` states, `FriendGoingTile` rendering/navigation/overflow, `FriendVisitTile`'s new tap behavior, and the GOING section's loading/error/empty/populated states). Zero regressions.

---

## FILES

**52. Step 2B added files.**
- `lib/models/event_attendance.dart`
- `lib/data/repositories/event_attendance_repository.dart`
- `lib/features/events/widgets/event_going_button.dart`
- `lib/features/friends/widgets/friend_going_tile.dart`
- `supabase/migrations/20260815120000_social_foundation_step2b_event_attendance.sql`
- `test/event_attendance_model_test.dart`
- `test/can_attend_event_test.dart`
- `test/event_going_button_test.dart`
- `test/friend_going_tile_test.dart`
- `test/friend_profile_going_section_test.dart`
- `docs/Architecture/SOCIAL_FOUNDATION_STEP_2B_IMPLEMENTATION_REPORT.md` (this file)

**53. Step 2B modified files.**
- `lib/features/events/event_detail_screen.dart` — `canAttendEvent`, attendance state/load/toggle, `EventGoingButton` wired in
- `lib/features/friends/friend_profile_screen.dart` — GOING section, `FriendVisitTile.onTap` wiring, shared top-level `_openVenue`
- `lib/features/friends/widgets/friend_visit_tile.dart` — `onTap` + chevron added
- `docs/Architecture/FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` — new §17
- `test/friend_visit_wishlist_tiles_test.dart`, `test/friend_profile_visited_wishlist_sections_test.dart` — updated for `FriendVisitTile`'s new required `onTap`, plus new tap/chevron assertions

**54. Step 2 files still uncommitted (unchanged by this task, listed for clarity).**
`lib/core/widgets/editorial_back_button.dart`, `lib/core/widgets/sheet_dismiss_handle.dart`, `lib/data/repositories/visited_repository.dart`, `lib/features/stays/stay_detail_screen.dart`, `lib/features/stays/widgets/add_stay_sheet.dart`, `lib/features/visits/visit_detail_screen.dart`, `lib/features/visits/widgets/add_visit_sheet.dart`, `lib/features/visits/widgets/visit_privacy_toggle.dart`, `lib/features/friends/widgets/friend_photo_strip.dart`, `lib/features/friends/widgets/friend_wishlist_tile.dart`, `lib/models/visit.dart`, `supabase/migrations/20260814120000_social_foundation_step2_visit_visibility.sql`, `docs/Architecture/SOCIAL_FOUNDATION_STEP_2_IMPLEMENTATION_REPORT.md`, `test/visit_visibility_test.dart`, `test/visit_privacy_toggle_test.dart`, `test/sheet_dismiss_handle_test.dart`.

**55. Unrelated files untouched.** `docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md` and every file under `supabase/data/enrichment/` — confirmed untouched by this task's `git status`.

---

## SAFETY

**56. No Step 2B production writes.** Confirmed — no command was run against `--linked` production at any point in this task (this task's own scope never required a production preflight; that happens at the deployment task that follows physical review).

**57. No Step 2B migration applied.** Confirmed — `supabase db push` was never invoked.

**58. No trip visibility changes.** Confirmed by construction — the new migration contains zero references to `planned_trips`/`planned_venues`.

**59. No Community feed.** Confirmed — no feed, tab, public attendee list, or geographic-community code was written; the one aggregate RPC exists but is called from nowhere in the Flutter code.

**60. Nothing staged.** `git diff --cached` empty.

**61. Nothing committed.** No `git commit` run.

**62. Nothing pushed.** No `git push` run.

---

SOCIAL FOUNDATION STEP 2B — FRIEND VENUE NAVIGATION + EVENT ATTENDANCE READY FOR PHYSICAL-DEVICE AND PRE-DEPLOYMENT REVIEW
