# Social Foundation Step 1 — Username, Profile & Friendships

Implementation report, 2026-08-13. Prepared (migration written, validated against a local Postgres instance) but **not deployed to production** — see `Safety` below. Companion to `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` (the read-only spike that preceded this step) and `UI_CONSISTENCY_AUDIT.md`.

---

## 0. Two confirmed pre-existing bugs, fixed as part of this step

1. **Signup never actually created a usable profile.** `handle_new_user()` (the `auth.users` insert trigger) has only ever read `username` out of signup metadata; `SignupScreen` has only ever sent `display_name`. Every profile created since the production schema v1 rebuild has `username = null` **and** `display_name = null`. Fixed: the trigger now reads both keys, and `SignupScreen` now sends both.
2. **The entire Profile screen has been broken for every user.** `ProfileRepository.getProfile` unconditionally queried a `user_tiers` view; `getCommunityStats` queried `tier_stats`; the old `FriendshipRepository`/`TrophyRepository` queried `friendships`/`trophies`/`user_trophies`. None of these exist in the live schema — confirmed via a live read-only `information_schema` query against the linked production project during this task's own audit (not assumed from the prior spike). Every load of the old Profile screen has been throwing "Could not load profile," unconditionally, for every user. Fixed by removing the dependency entirely (tiers/trophies are out of this step's scope, not merely hidden) — see §7 for exactly what that removed.

---

## 1. Username

### 1.1 Rule

3–30 characters, lowercase `a-z`/`0-9`/`_`/`.` only, must start and end with a letter or digit. Enforced identically in three places:

- **Database** (authoritative): `profiles_username_format` CHECK constraint — a single POSIX-ERE pattern, `^[a-z0-9]([a-z0-9]|[_.][a-z0-9])*$`, plus a length check. The "punctuation must be immediately followed by an alnum" shape rejects consecutive punctuation and trailing punctuation for free, without a lookahead (Postgres `~` is POSIX ERE, which has none).
- **Client, for UX** (`lib/core/utils/username_rules.dart`): the identical pattern, checked before ever hitting the network.
- **`username_available(candidate)` RPC**: same pattern again, plus a uniqueness check — a best-effort typing hint, never authoritative.

### 1.2 Canonical storage / case-insensitive uniqueness

The character class only ever accepts lowercase letters, so satisfying the CHECK constraint *is* canonical-lowercase storage — there's no separate `username = lower(username)` rule to keep in sync. The existing `profiles_username_key` unique index (already present in production schema v1, previously unpopulated) is therefore already race-safe, case-insensitive-effective uniqueness with no changes needed to it at all.

### 1.3 Existing users

`username IS NULL` is left null for every existing profile — no fabricated usernames. `ProfileScreen` shows a "Choose a username so friends can find you" banner when null; only Friends functionality is gated on it (the rest of the app works unchanged with no username set).

---

## 2. Friendship state machine

```
            send_friend_request
   (none) ─────────────────────────► pending
                                        │
                       ┌────────────────┼────────────────┐
              accept_friend_request  decline_friend_request  (either party)
                       │                │                block_user
                       ▼                ▼                     │
                  accepted         declined                   ▼
                       │                │                 blocked
              (either party)    (only the original
               DELETE / block    decliner may send a
                       │          fresh request —
                       ▼          the original requester
                (row removed)     gets a clear error)
```

Four states only: `pending | accepted | declined | blocked` — no `following`/`muted`/`close_friend`/`archived`. One row per unordered pair, ever; state transitions happen in place except the two genuinely-fresh-row cases (cancelling a pending request, removing an accepted friendship — both plain DELETEs).

**Why `declined` is kept, not deleted**: deleting it would let the original requester immediately re-send an identical request — exactly the "spammy re-request" the task asked to prevent. Kept as a row, `send_friend_request` blocks the original requester with a clear error. The one deliberate exception: if the person who *declined* later reaches out themselves, that's a genuine new request, not a re-request — the old row is deleted and a fresh one created with roles reversed.

---

## 3. Database design

### 3.1 `friendships`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `requester_id` | uuid → `profiles(id)` | `on delete cascade` |
| `addressee_id` | uuid → `profiles(id)` | `on delete cascade` |
| `status` | text | `pending\|accepted\|declined\|blocked` |
| `blocked_by` | uuid → `profiles(id)`, nullable | must be one of the two participants; must be set iff `status='blocked'` (two CHECK constraints) |
| `created_at` | timestamptz | |
| `responded_at` | timestamptz, nullable | set on every transition out of `pending`/into `blocked` |

**Normalized-pair uniqueness**: a unique index on `(least(requester_id, addressee_id), greatest(requester_id, addressee_id))` — an expression index, not generated columns — makes A→B and B→A structurally impossible to coexist, enforced by Postgres itself, not application logic that could lose a race. `requester_id <> addressee_id` is a table CHECK, mirroring the pre-existing (unused) `follows` table's own identical constraint.

**Indexes**: the pair index above, plus separate `requester_id`/`addressee_id` indexes for "my requests" lookups.

### 3.2 `profiles` (additive)

- `updated_at timestamptz` + the existing `set_updated_at()` trigger reused (already used by `hotels`/`restaurants`) — fixes a second pre-existing bug: `ProfileRepository.updateDisplayName` has always sent an `updated_at` value the table never had a column for.
- `profiles_username_format` CHECK (§1.1).

### 3.3 RLS

| Table | Policy | Rule |
|---|---|---|
| `friendships` | SELECT | `requester_id = auth.uid() OR addressee_id = auth.uid()` |
| `friendships` | DELETE | same, **and** `status in ('pending','accepted')` — cancels a sent request or removes a friendship; `declined`/`blocked` rows are not deletable this way |
| `friendships` | *(no INSERT/UPDATE policy)* | every state transition beyond delete goes through a SECURITY DEFINER RPC — see §4 |

Table-level `GRANT SELECT, DELETE ON friendships TO authenticated` is explicit in the migration (confirmed necessary by testing directly against a local database, not assumed — RLS alone is a no-op without the underlying table grant, and a fresh table doesn't automatically inherit whatever ambient default-privilege setup a hosted project's dashboard bootstrap configured).

### 3.4 Why RPCs, not more RLS

Two structural reasons, not just style:

1. **State-transition rules aren't expressible as one RLS policy.** "Only the addressee of a still-*pending* row may accept it" is a rule about the combination of caller identity, current status, and target status — a single `USING`/`WITH CHECK` pair can't cleanly encode "old value was X, new value must be Y, caller must be Z" without a trigger or function underneath it anyway.
2. **Identity reads must bypass `profiles.is_public`.** `get_friends`/`get_incoming_friend_requests`/`get_outgoing_friend_requests`/`search_profiles`/`get_profile_identity` all need to show a counterpart's name/avatar *regardless* of whether that person's profile happens to be public — profile *discoverability* is deliberately not gated by that flag (see the architecture doc's identity-vs-activity split). Plain PostgREST embedding through the existing `profiles_read` RLS policy would silently null out a private-profile friend's name. A SECURITY DEFINER function reads `profiles` directly (bypassing RLS internally) and returns only the four safe identity columns — never email, never auth metadata, never anything activity-shaped.

---

## 4. RPCs

| RPC | Purpose | Caller-controlled input | What it returns |
|---|---|---|---|
| `username_available(candidate)` | Pre-signup availability hint | a candidate string, no auth required | boolean only |
| `send_friend_request(target_user_id)` | Create/resurrect a request | target id | the friendship row |
| `accept_friend_request(friendship_id)` | pending→accepted, addressee only | a friendship id the caller must be part of | the friendship row |
| `decline_friend_request(friendship_id)` | pending→declined, addressee only | same | the friendship row |
| `block_user(target_user_id)` | any state→blocked | target id | the friendship row |
| `get_friends()` | accepted friends, identity only | **none** — reads only `auth.uid()` | id/username/display_name/avatar_url per friend |
| `get_incoming_friend_requests()` | pending, caller is addressee | none | same shape + `created_at` |
| `get_outgoing_friend_requests()` | pending, caller is requester | none | same shape + `created_at` |
| `get_profile_identity(target_user_id)` | one profile's identity + relationship | target id | identity + relationship_status |
| `search_profiles(query)` | username prefix search | a query string | up to 20 rows, identity + relationship_status |
| `is_friend(other_user_id)` | forward-compat helper for Step 2 RLS | target id | boolean only; not referenced by any policy yet |

Every function: `SECURITY DEFINER`, explicit `set search_path = public`, `revoke ... from public` followed by an explicit `grant ... to authenticated` (`username_available` also grants `anon`, since it must work before an account/session exists). No function trusts a caller-supplied "who am I" — every identity check reads `auth.uid()` directly; `get_friends`/`get_incoming_friend_requests`/`get_outgoing_friend_requests` don't even accept a user-id parameter, so there is no way to request *someone else's* friend list even by construction.

**Blocked-pair behavior, consistently**: `send_friend_request` rejects with a clear error the moment either party has blocked the other, regardless of who's calling; `search_profiles`/`get_profile_identity` both exclude blocked-either-direction pairs from their results entirely, rather than surfacing a "blocked" status the UI would have to specifically hide.

---

## 5. UI

- `SignupScreen` — Name, **Username** (new, debounced availability hint), Email, Password.
- `ProfileScreen` — full redesign onto the dark editorial system: avatar, name, `@username`, "choose a username" banner (only if unset), Journey Stats (unchanged computation), a Friends entry row (count shown only when genuinely available), Account (Edit profile / Notifications / **Sign out**, unchanged `AuthRepository.signOut()` call, no second logout mechanism).
- `lib/features/friends/` (new) — `FriendsScreen` (Friends / Requests tabs, Add Friend action), `AddFriendScreen` (username search), `FriendProfileScreen` (one screen for both a friend's and a non-friend's profile — the only difference is which action `relationshipStatus` resolves to). **Identity only, everywhere** — no visit/rating/photo/wishlist/trip data is ever queried or rendered by any of these three screens.

---

## 6. Security decisions, restated plainly

- No client ever decides a friendship's status directly — every transition is a named, narrow RPC, never a generic "update friendship."
- No RPC accepts a user id and returns *that* user's friend list, request list, or anything beyond minimal identity + the caller's own relationship to them.
- `search_profiles`/`get_profile_identity` never return email or any column beyond `id, username, display_name, avatar_url, relationship_status` — `profiles` has no email column at all; email lives only in `auth.users`, never queried by any of this.
- Blocked pairs are excluded at the RPC level (server-decided), not left to client-side filtering.

---

## 7. What was deliberately removed, not fixed

`ProfileScreen`'s tier badge, "Community Stats" (tier distribution), and "Trophies" sections — all three depended on `user_tiers`/`tier_stats`/`trophies`/`user_trophies`, none of which exist in the live schema (§0.2). Rebuilding a tier/trophy system is out of this step's scope entirely, not deferred-but-implied. `TrophyRepository`/`models/trophy.dart` are untouched (still referenced by `rating_dialog.dart`, which itself is dead/unreachable code — `showRatingDialog` is called from nowhere in the app — and by `notifications_screen.dart`'s own friend-request UI, fixed to compile against the new `FriendshipRepository` API with its trophy side-effect removed, since that side effect also targeted the same nonexistent tables).

`lib/features/notifications/notifications_screen.dart` was fixed (its entire feature was already "pending friend requests, accept/decline inline" — a like-for-like API update, not new functionality) but **not visually redesigned** — out of this step's declared scope.

---

## 8. Deferred to Step 2 (see `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md`)

- `visits.visibility`/`wishlist` RLS tightening — friend-visible activity.
- The photo storage-layer fix (row RLS already supports sharing; `storage.objects` RLS is currently owner-only regardless).
- Friend activity feed, Community Intelligence aggregates, event attendance.
- Unblocking (no `unblock_user` RPC exists yet — blocking is one-way for now, matching the task's explicit "must-have before testers" scope and nothing more).
