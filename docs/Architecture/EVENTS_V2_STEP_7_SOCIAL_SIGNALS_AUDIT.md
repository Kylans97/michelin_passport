# EVENTS V2 STEP 7 — FRIENDS INTERESTED + FRIENDS GOING + MEMBER GOING COUNT ARCHITECTURE AUDIT

Read-only architecture audit. No Dart code, migrations, RLS, or production data were changed by this document.

> **STATUS: FINALIZED.** The implementation described as recommended below has been built exactly per this audit's conclusions (Interested visibility → friends, existing status-parameterized Friends Going queries reused for Interested, a new `get_event_going_member_count` function with a server-side 100 cap), deployed to production, independently re-verified there (function definition, grants, RLS, non-mutating smoke checks), and approved on physical device. See `EVENTS_V2_STEP_7_SOCIAL_SIGNALS_PRE_APPLY.md` for the full implementation/deployment/validation record. This document is otherwise unchanged, kept as the historical pre-implementation record.

## PRODUCT CONTRACT

1. Friends Going — unchanged, already shipped.
2. Friends Interested — new: accepted friends may see who is Interested, mirroring Friends Going.
3. Mantelier members going — new: an anonymous, platform-wide Going count. Display rule: `0` → hidden; `1–99` → exact number; `100+` → always literally `"100+"`, never the real number once it reaches 100.

## CURRENT EVENT ATTENDANCE

Re-verified live (not from memory), `public.event_attendance`:

| Column | Type | Default |
|---|---|---|
| `id` | uuid | `gen_random_uuid()` |
| `event_id` | uuid, FK → `events(id) ON DELETE CASCADE` | — |
| `user_id` | uuid, FK → `profiles(id) ON DELETE CASCADE` | — |
| `status` | text | `'going'` |
| `visibility` | text | `'friends'` |
| `created_at` | timestamptz | `now()` |

Constraints: `status_check` — `status IN ('interested','going')`; `visibility_check` — `visibility IN ('private','friends')`; `UNIQUE(event_id, user_id)` (one row per user per event — structurally guarantees a user is never simultaneously Interested and Going on the same event, since `status` is a single column on that one row). Indexes: `event_attendance_event_status_idx (event_id, status)`, `event_attendance_user_status_idx (user_id, status)`, plus `user_id`/`event_id` singles and the PK/unique.

RLS (re-verified live, all 4 policies):
- `SELECT`: `(user_id = auth.uid()) OR (visibility = 'friends' AND is_friend(user_id))`
- `INSERT`: `WITH CHECK (user_id = auth.uid())`
- `UPDATE`: `USING/WITH CHECK (user_id = auth.uid())`
- `DELETE`: `USING (user_id = auth.uid())`

**Confirmed directly (not assumed): the SELECT policy has no `status` reference at all.** It already supports `visibility = 'friends'` identically for `status = 'going'` and `status = 'interested'` — the moment an Interested row is written with `visibility = 'friends'`, an accepted friend can already read it under the exact same policy Going already uses. **No RLS change is needed for Friends Interested.**

## INTERESTED VISIBILITY

The Interested→`private` / Going→`friends` rule lives **exclusively in Dart**, in one pure function — `lib/models/event_intent.dart:25-29`:

```dart
AttendanceVisibility visibilityForIntent(EventIntentStatus status) =>
    switch (status) {
      EventIntentStatus.going => AttendanceVisibility.friends,
      EventIntentStatus.interested => AttendanceVisibility.private,
    };
```

`EventAttendanceRepository.setEventIntent` (`event_attendance_repository.dart:67-96`) calls this and writes the result into `visibility` on both the insert path (line 80) and the update/23505-recovery path (line 89) — the **only** place this value is ever set. The database itself has no trigger, no status-conditional DEFAULT, no CHECK coupling `visibility` to `status` — confirmed by re-reading both `20260815120000_social_foundation_step2b_event_attendance.sql` and `20260819141000_events_v2_attendance_interested_going.sql` in full: the second migration touches only the `status` CHECK and two indexes, nothing on `visibility`. Nothing in the schema currently prevents a client from writing any status/visibility combination — the pairing is a Dart-enforced convention only.

**Single load-bearing call site to change**: `event_intent.dart:28` (`EventIntentStatus.interested => AttendanceVisibility.private` → `AttendanceVisibility.friends`). No other file combines `EventIntentStatus.interested` with a visibility literal — `event_attendance_repository.dart` only reads `visibilityForIntent()`'s output, never re-derives it. This is a **one-line change** when Step 7 is actually implemented (not now).

## EXISTING DATA / BACKFILL

Read-only production audit, `event_attendance` grouped by `(status, visibility)`:

| status | visibility | count |
|---|---|---|
| going | friends | 2 |

**Total rows: 2. Zero Interested rows exist in production today.** The backfill dilemma the task asks me to evaluate is currently moot in practice — there is no existing private Interested data to broaden or protect. I still answer the general question for when this matters (e.g. if Step 7 ships later, after more Interested rows accumulate under the old default):

**Recommendation: do not auto-broaden existing private Interested rows.** A user marked Interested under an explicit "this is private" default; silently exposing that historical row to friends after the fact is a real trust violation regardless of how few rows exist. Safer transition: the visibility rule change applies to **future writes only** — `visibilityForIntent` changes, existing rows keep whatever `visibility` they already have written. A user who re-taps Interested (removes and re-adds, which the existing `resolveIntentTap` state machine already supports as a normal transition) gets the new default going forward. No backfill script, no migration needed for this. Given production currently has 0 Interested rows, this recommendation costs nothing to apply cleanly whenever Step 7 actually ships.

## FRIENDSHIP MODEL

`public.friendships` (`20260813120000_social_foundation_step1_username_friendships.sql`): one row per **unordered pair**, enforced by a unique index on `(least(requester_id,addressee_id), greatest(...))`. `status CHECK IN ('pending','accepted','declined','blocked')`. All mutation goes through `SECURITY DEFINER` RPCs (`send_friend_request`, `accept_friend_request`, `decline_friend_request`, `block_user`) — re-verified live via `pg_proc`; the only direct table write from Dart is `removeFriendship`'s `DELETE`, matching the `friendships_delete` RLS policy (`(requester_id=auth.uid() OR addressee_id=auth.uid()) AND status IN ('pending','accepted')`). `friendships_select` restricts reads to rows the caller is a party to; there is no INSERT/UPDATE table-level policy — writes are RPC-only.

`is_friend(other_user_id)` (re-verified live): `STABLE SECURITY DEFINER, SET search_path = public`, returns `exists(... status='accepted' AND (requester=me AND addressee=other OR addressee=me AND requester=other))`. **Confirmed: "friend" means accepted friendship only** — not pending, not declined, not blocked, and there is no one-way "follow" concept anywhere in this schema (Follow, from Step 6, is a completely separate `follows_*` table system with no relationship to `friendships`). `friendships.status='blocked'` rows are excluded from `is_friend` by construction (only `'accepted'` matches), and separately excluded from `get_profile_identity`/`search_profiles`'s relationship-status surface entirely.

## FRIENDS GOING

`EventAttendanceRepository.getVisibleUserIds({eventId, status})` — one query, `event_attendance.select('user_id').eq('event_id',...).eq('status', status.dbValue)`, friend-filtering delegated entirely to RLS (no explicit friendship join in Dart — the RLS policy already does it). `getFriendUpcomingEvents({userId, status})` — two queries total (attendance rows → batched `events` select), explicitly documented as "never one query per event." **Both methods already take `status: EventIntentStatus` as an explicit parameter** — this was a deliberate Step 3 design choice per their own doc comments.

Event Detail's Friends Going load (`_loadFriendsGoing`, `event_detail_screen.dart:221-234`): `getVisibleUserIds` (1 query) + `getFriends()` RPC (1 call) = 2 total round trips.

UI: `EventFriendsGoingSection` (`lib/features/events/widgets/event_friends_going_section.dart`) — heading `"FRIENDS GOING"`, shows avatars+names+usernames via `IdentityRow` (not count-only), preview cap 3, "View all" link (not "+N" text) when more than 3, navigating to `EventFriendsGoingListScreen` with the already-fetched friend list (no re-query). Hidden entirely (not an empty state) when zero friends — enforced by the `FutureBuilder` at `event_detail_screen.dart:765-786` returning `SizedBox.shrink()` for null/empty/error, and the section's own doc comment forbids ever being constructed with an empty list.

Friend Profile (`friend_profile_screen.dart`) already has a `GOING` section (`_FriendGoingSection`, gated on accepted-friend relationship), calling `getFriendUpcomingEvents(userId: friend, status: EventIntentStatus.going)` — same repository method, opposite query direction (one friend's events, not one event's friends), own preview cap of 4, own "View all" → `FriendGoingListScreen`. Same hide-entirely-when-empty behavior.

## FRIENDS INTERESTED

**Confirmed: the existing status-parameterized methods can be reused verbatim with `status: EventIntentStatus.interested`, with zero new repository code, once `visibilityForIntent` is changed.** RLS already supports it (proven above — the SELECT policy is status-agnostic). No `getFriendsInterested...`-named duplicate method should be added — that would be exactly the redundant API the task warns against; `getVisibleUserIds`/`getFriendUpcomingEvents` already ARE the type-safe, status-parameterized shape Step 3 built for this. Confirmed no other file needs new logic to make this work at the data layer — this is a **UI-and-one-line-Dart-default** change, not a new query architecture.

## EVENT DETAIL UX

Current hierarchy (`event_detail_screen.dart` `build()`): Hero → `EventMetaSection` → [divider] `EventAttendanceSection` (confirmed-attendance/prompt, conditional) → [divider] `EventIntentControls` (Interested/Going pills) → (same `canAttend` block, no divider) `EventFriendsGoingSection` via `FutureBuilder`, only if non-empty → [divider] `VenueAboutSection` → [divider] `AtThisEventSection` → [divider] Hotels → [divider] Location/Website/Tickets.

Friends Going currently sits **directly under the intent pills**, inside the same `canAttend`-gated block — not a sibling of "AT THIS EVENT." **Recommended Step 7 hierarchy**: keep Friends Going where it is, add Friends Interested as a second block immediately below it (same gating, same `canAttend` block, own `FutureBuilder`), and add the member-going count as a compact, always-independent line — not gated on `canAttend` at all (a past/cancelled event should still be able to show its historical Going count, whereas Interested/Going pills and Friends sections correctly disappear once `canAttend` is false). Concretely:

```
EventIntentControls (pills)
  ↓ (only if non-empty, only if canAttend)
EventFriendsGoingSection      "FRIENDS GOING"
  ↓ (only if non-empty, only if canAttend)
EventFriendsInterestedSection "FRIENDS INTERESTED"
  ↓ (independent of canAttend/friends; only if count > 0)
"37 Mantelier members going"   ← compact text line, no heading needed
```

Do not introduce a "SOCIAL SIGNALS" eyebrow/heading wrapper around all three — the two Friends sections already have their own eyebrow headings and visual language; the member-count line is small enough to read as a natural trailing line under the Friends sections (or under the pills if no friends qualify) rather than needing its own labeled block. This keeps the area from becoming visually noisy, per the task's own instruction.

## FRIEND PROFILE UX

`_FriendGoingSection` already exists; recommend a parallel `_FriendInterestedSection` added directly after it (both gated on `relationshipStatus == accepted`, same `_previewLimit`, same "View all" → a new `FriendInterestedListScreen` mirroring `FriendGoingListScreen` exactly). This directly answers your stated requirement ("I want to be able to see Friends Interested and Friends Going as a friend") — Friend Profile is the natural second surface, reusing 100% of the existing Going section's shape.

## MEMBER GOING COUNT

**Critical finding, re-verified live via `pg_proc`: a function named `get_event_attendance_count(target_event_id uuid)` already exists in production**, from `20260815120000_social_foundation_step2b_event_attendance.sql` (a follow-up migration `20260815130000` already fixed an ambient anon-EXECUTE-grant leak on it). It is `SECURITY DEFINER`, `STABLE`, `SET search_path = public`, granted to `authenticated` only (revoked from `PUBLIC` and `anon`) — the exact security shape Step 7 needs. **It is never called from any Dart code today** (confirmed by `grep` — only referenced in two doc comments as a contrast point, never invoked).

**However, its SQL body does not match the Step 7 product contract and cannot be reused as-is**:
```sql
select case when count(*) >= 5 then count(*)::integer else null end
from public.event_attendance where event_id = target_event_id;
```
Two mismatches: (1) **no `status` filter** — it counts every `event_attendance` row for the event, Interested and Going mixed together. This was correct when it was written (at that time `status` was constrained to the single legal value `'going'` — re-confirmed from that migration's own now-superseded table definition), but became silently wrong the moment the later Interested/Going split migration widened the `status` CHECK constraint, since nothing updated this function to add `AND status = 'going'`. It has caused no live bug only because it's never called. (2) its privacy scheme is a **≥5-or-null anonymity threshold**, the opposite shape from Step 7's **0-hidden / 1–99-exact / 100+-capped** rule — it suppresses small real counts (1–4) that Step 7 explicitly wants shown exactly, and never caps large counts (would return `523` uncapped), which would violate the "never expose the exact count once it's ≥100" requirement outright.

## COUNT PRIVACY / 100+ CONTRACT

Confirmed this must be enforced server-side, not client-side, per the same reasoning the task states: if the API returns `523` and the client merely *renders* "100+", the exact number already left the server. **Recommended contract**: the SQL function itself computes and returns only the display-ready value, capped:

```sql
select case
  when count(*) = 0 then 0
  when count(*) >= 100 then 100
  else count(*)::integer
end
from public.event_attendance
where event_id = target_event_id and status = 'going';
```

Returning a single capped integer (`0`, `1`–`99`, or exactly `100` meaning "100 or more") is simpler than a `{count, capped}` struct and carries the identical guarantee — the client never needs to distinguish "is this literally 100" from "this is 100+", because the product rule is that `100` always renders as `"100+"` regardless. A struct return adds a field with no behavioral difference; I recommend the single-integer contract as the smallest correct API.

## PROPOSED RPC / AGGREGATE

**Recommend a new, distinctly-named function** — e.g. `get_event_going_member_count(target_event_id uuid)` — rather than silently redefining `get_event_attendance_count` in place. Reasoning: the old function's name doesn't even semantically match "going only" (ambiguous today, actively misleading once Interested exists), and its return contract (≥5-anonymity-threshold, uncapped) is a genuinely different shape from what Step 7 needs, not a superset. Reusing the same name for a materially different contract risks confusing anyone who reads the migration history later. The old, still-unused `get_event_attendance_count` can be left in place (harmless, still unused, still correctly access-controlled) or dropped in a future cleanup — that decision doesn't block Step 7 and shouldn't be made in this audit. New function, when implemented, should copy the exact security posture already proven safe here: `STABLE SECURITY DEFINER, SET search_path = public`, `REVOKE ... FROM PUBLIC`, explicit `REVOKE ... FROM anon` (the prior migration's own lesson: a bare `REVOKE FROM PUBLIC` does not stop Postgres's ambient anon default-privilege grant — anon must be revoked explicitly, confirmed by that migration's own post-deploy discovery), `GRANT EXECUTE ... TO authenticated` only.

## RLS / SECURITY

Threat model, each already prevented or to be prevented by the design above:

| Threat | Prevented by |
|---|---|
| User reads a friend's Interested identity | `event_attendance_select` RLS — already works once `visibility='friends'` is written (proven above) |
| User reads a non-friend's Interested/Going identity | Same RLS — `is_friend()` returns false, no row returned, `private` rows never match either branch |
| User reads a pending-friend-request's identity | `is_friend()` strictly checks `status='accepted'` — a pending row returns false |
| User enumerates all Going identities directly | RLS never permits reading rows where `visibility='friends'` unless `is_friend()` is true for the specific `user_id` on that row — no query can bulk-read others' identities |
| User calls the count aggregate to enumerate identities | The new function selects only `count(*)`, never `user_id`/any row-level column, mirroring `get_event_attendance_count`'s own already-audited "identity-free" design |
| SQL injection via the RPC | Single typed `uuid` parameter, no dynamic SQL, no string concatenation — same shape as every other function in this schema |
| Blocked/unfriended user | `friendships.status='blocked'` never satisfies `is_friend()`'s `status='accepted'` check |
| Private confirmed Attendance leaking via this work | Untouched — `event_confirmed_attendance.visibility` defaults `'private'` (re-verified live), a completely separate table/RLS policy set from `event_attendance`; Step 7 touches neither its schema nor its default |
| Anon calling the new count RPC | Must explicitly `REVOKE FROM PUBLIC` **and** `REVOKE FROM anon` (the ambient-grant lesson above) before `GRANT TO authenticated` |

## INDEXES

`event_attendance_event_status_idx (event_id, status)` already exists and already exactly matches the query shape both Friends Interested/Going (`WHERE event_id = ? AND status = ?`) and the new count RPC (`WHERE event_id = ? AND status = 'going'`) need. **No new index required** — confirmed via live `pg_indexes` re-verification, not assumed.

## ANALYTICS

`FriendSignalType` (`interested`/`going`/`attended`), `AnalyticsProperties.friendSignalType`, and `AnalyticsEvent.friendsSignalOpened` already exist in the canonical taxonomy (`analytics_event.dart`/`analytics_properties.dart`) but have **zero call sites anywhere in `lib/`** — fully defined, fully unused, same "documented ahead of implementation" pattern already found for `eventOpened`/`hostProfileOpened` in earlier steps. `AnalyticsSourceContext.friendSignal` IS used once, in `friend_profile_screen.dart:660`, tagging navigation into Event Detail from a friend's Going list — unrelated to viewing Friends Going/Interested sections themselves.

**No taxonomy change is required for Step 7.** Simply rendering counts (Friends Going/Interested lists, the member-going line) should not itself emit analytics — matching this codebase's consistent principle that passive rendering is not a trackable action. A future *tap* (e.g. "View all" on a Friends Interested list, or eventually opening a friend's profile from there) is a reasonable candidate to eventually fire `friendsSignalOpened` with `friendSignalType: FriendSignalType.interested` — but wiring that up is implementation work, correctly out of this audit's scope, reported as a gap only.

## MEMBER COUNT ANALYTICS

Should not be sent at all by default — the count RPC's own server-side cap (never returning the true value once ≥100) already means the client never *has* an exact number above 99 to accidentally leak through analytics, so there is no additional analytics-specific capping logic needed beyond simply never adding a property for this. Recommend: do not add any analytics property for the member-going count in Step 7.

## PERFORMANCE

Current Event Detail load (Step 3-era): Event + linked venues + personal intent + confirmed attendance + Friends Going (2 calls). Adding Step 7:
- Friends Interested: +2 calls (`getVisibleUserIds(status: interested)` + `getFriends()` — though `getFriends()` is already fetched for Friends Going and can be reused/shared rather than called twice; see below).
- Member-going count: +1 call (the new RPC, single scalar).

**Total incremental cost: +2 calls if `getFriends()` is deduplicated, +3 if not.** Recommend fetching `getFriends()` once and reusing the same friend list for both the Going and Interested visible-user-id intersections (both need "which of my friends" — the friend list itself doesn't depend on `status`), reducing the naive +3 to +2. All three new calls (Friends Interested's two, plus the count RPC) are independent of each other and of the existing Friends Going load — start all of them together (`Future`s created before any `await`), matching this codebase's established "start together, await in turn" convention used everywhere else in this session's work. No N+1 anywhere: the count is one scalar RPC call regardless of how many people are going; Friends Interested/Going are each capped at "however many accepted friends this user has," never per-row.

**Final expected query count if Step 7 were implemented**: existing Event Detail load (unchanged) + 1 shared `getFriends()` (reused for both Friends Going and Friends Interested, already existing) + `getVisibleUserIds(status: going)` (already existing) + `getVisibleUserIds(status: interested)` (new, same method) + 1 new count RPC call = **2 new round trips added to the current total**, all parallelizable with the existing load.

## WEB READINESS

Friends identities require an authenticated session regardless of platform — unchanged, no web-specific concern (RLS is the enforcement boundary, identical on any Supabase client). The member-going count RPC is a good candidate for eventual public/anon use on a future public Event page precisely because it is already identity-free and cap-enforced server-side — **recommend designing the new function so that a future migration can simply add `GRANT EXECUTE TO anon` without changing the function body at all** (no `auth.uid()` dependency inside the function itself, matching `get_event_attendance_count`'s own existing shape). For Step 7's app-only MVP, **recommend authenticated-only** (no anon grant) — matches the existing precedent exactly (anon was deliberately revoked from the sibling function after being found ambiently granted), and there is no current public/anon Event page to serve.

## DATABASE CHANGE DECISION

- **A. Interested visibility**: no schema/RLS migration — a one-line Dart default change (`visibilityForIntent`), confirmed by live RLS re-verification that the SELECT policy is already status-agnostic.
- **B. Platform member count**: **yes, one migration required** — a new `SECURITY DEFINER` function (recommended: `get_event_going_member_count`) with the exact `0`/`1–99`/`100`-capped SQL body above, plus the same `REVOKE FROM PUBLIC`/`REVOKE FROM anon`/`GRANT TO authenticated` sequence already proven necessary for its sibling function.
- **C. Backfill**: no — 0 existing Interested rows in production today; the general-case recommendation (don't auto-broaden existing private rows) is documented above for when it becomes relevant.
- **D. Missing indexes**: no — `event_attendance_event_status_idx (event_id, status)` already covers every query path Step 7 needs, re-verified live.

## TEST PLAN

**Visibility**: Interested written with `visibility=friends` → accepted friend can read via RLS; non-friend cannot; pending-friend cannot; owner can always read own row regardless of visibility. Going: existing friends-visible behavior unchanged (regression only). Confirmed Attendance: private-by-default behavior unchanged (regression only, proves Step 7 didn't touch it).

**Friend signals**: 0/1/many friends Going; 0/1/many friends Interested; a friend who switches Interested→Going disappears from Interested and appears in Going (guaranteed by the `UNIQUE(event_id,user_id)` + single-`status`-column schema, not just app logic); Going always ordered before Interested in the UI; each group independently hidden when empty; both empty ⇒ entire friends-signal area absent, but the member-count line may still render independently.

**Member count**: exact boundary table — `0`→hidden; `1`→"1 Mantelier member going" (singular); `2`→"2 Mantelier members going"; `99`→exact; `100`→"100+"; `101`→"100+"; `1000`→"100+". Critically: a unit/widget test on the display-formatting function alone cannot prove the *server* never sends the true value above 99 — that requires either an integration test against a live/staged Supabase instance with ≥100 seeded rows, or (more practically for this codebase's established testing conventions, which have no Supabase mocking harness) a close reading of the deployed SQL body itself as the enforcement point, plus a pure Dart formatter tested against the assumption that its input is already capped at 100.

## PHYSICAL DEVICE PLAN

Two friend accounts (A, B, accepted friendship), one non-friend account (C):
1. A marks Interested on Event X → B (friend) sees A under "Friends Interested." C (non-friend) never sees A's identity anywhere.
2. A switches to Going → B no longer sees A under Interested, now sees A under Going (single-row/single-status transition, not an add).
3. A removes intent entirely → B sees neither.
4. Member-going count updates correctly as real users go, while no non-friend or friend ever sees more than the capped display value — verify specifically that going from 99→100 real Going users flips the display from an exact number to "100+" and never regresses back to an exact number as more people join.
5. Singular "1 Mantelier member going" vs. plural, no overflow on a 320px device, friend avatar/name rows read as polished as the existing Friends Going section they mirror.

## DATABASE

Migrations performed by this audit: **0**. Schema changes: **0**. Production writes: **0** — every query this audit ran was read-only (`SELECT`, `information_schema`, `pg_policies`, `pg_constraint`, `pg_indexes`, `pg_proc`). Migration sync re-checked: `supabase migration list --linked` — local == remote for all 35 migrations, unchanged from the Step 6 finalization state.

## VALIDATION

- `flutter analyze` — 0 issues (unchanged; no code touched by this audit).
- `flutter test` — **1335 passed**, 0 failed — identical to the Step 6 finalization baseline, confirming no Dart change occurred.
- `git status --short` — only this new audit document is untracked-and-new from this task; every other entry is a pre-existing unrelated Michelin/Gault&Millau artifact already present before this task began.

## FILES

New: `docs/Architecture/EVENTS_V2_STEP_7_SOCIAL_SIGNALS_AUDIT.md` (this document) — **not staged, not committed**, per instruction. No other file was created, modified, or deleted.

## GIT

Not staged. Not committed. Not pushed.

## RECOMMENDED STEP 7 IMPLEMENTATION

**IN SCOPE (when this becomes an implementation task)**: one-line `visibilityForIntent` default change (Interested → friends, future writes only); a `EventFriendsInterestedSection` widget reusing `EventFriendsGoingSection`'s exact visual language, wired via the already-status-parameterized `getVisibleUserIds`/`getFriends()`; a parallel `_FriendInterestedSection` on Friend Profile mirroring `_FriendGoingSection`; one migration adding `get_event_going_member_count` (capped `0`/`1–99`/`100` SQL body, `authenticated`-only grant, anon explicitly revoked); a compact member-going text line on Event Detail, independent of the `canAttend` gate; Going-before-Interested ordering; empty-section hiding preserved exactly as today.

**OUT OF SCOPE**: any backfill of existing rows (none exist to backfill); a platform-wide Interested count; revealing any identity to non-friends; a drilldown/full-list screen for Interested beyond what mirrors the existing Going pattern unless product later asks for more; any new analytics event beyond what's already defined-but-unused; Events Discovery card-level member counts (Event Detail only, per the task's own default hypothesis); "Friends following this host" or any Follow-identity social proof; any change to Confirmed Attendance visibility.

**Explicit answers**:
1. Must Interested visibility change from private to friends? **Yes**, and it is a one-line Dart change (`visibilityForIntent`), with RLS already supporting it today.
2. Do existing Interested rows require a backfill? **No** — 0 exist in production; general-case recommendation is future-writes-only regardless.
3. Can existing Friends Going query architecture be reused for Interested? **Yes, verbatim** — `getVisibleUserIds`/`getFriendUpcomingEvents` are already status-parameterized; no new repository method needed.
4. What exact secure mechanism should provide member Going count? A new `SECURITY DEFINER` SQL function (`get_event_going_member_count`), `STABLE`, `SET search_path = public`, `authenticated`-only grant, body computing `status='going'` count capped to `0`/`1–99`/`100` — mirroring the already-deployed (but semantically stale and differently-thresholded) `get_event_attendance_count`'s security posture, not its business logic.
5. Does the client ever receive an exact count ≥100? **No, by design** — the function itself caps the returned integer at exactly `100`, never the true count.
6. Is a migration required? **Yes, one** — for the new count function only. Interested-visibility and Friends Interested need no migration.
7. Is a new index required? **No** — `event_attendance_event_status_idx (event_id, status)` already covers every new query path.
8. Which surfaces belong in Step 7? Event Detail (Friends Going + new Friends Interested + member-going line) and Friend Profile (new Friends Interested section paralleling the existing Going section). Not Event cards/feed, not Events Discovery, not a new drilldown screen beyond what already exists for Going.

---

EVENTS V2 STEP 7 —
SOCIAL SIGNALS ARCHITECTURE AUDITED,
READY FOR HUMAN REVIEW
