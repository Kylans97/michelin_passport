# Friends, Privacy & Community Intelligence — Architecture Spike

Read-only architecture spike, 2026-08-13. No code was changed, no database was written to (one read-only `information_schema` query was run against the linked production database to verify a schema-drift finding below — nothing else), no migrations were created, nothing staged/committed/pushed. This document is a recommendation for a product decision, not an approved implementation plan.

> **Approved product decision, 2026-08-13 (post Social Foundation Step 1 deployment) — see §3.4a.** The product owner has approved the visibility model for Step 2 with one deliberate change from this document's own §3.4 recommendation: **wishlist is automatically visible to accepted friends, with no per-user or per-item visibility setting for MVP** — not "private only" as §3.4 below recommends. Visits remain `private | friends` per §3.2; ratings and photos inherit their parent visit's visibility per §3.2/§3.6; trips remain strictly private per §3.3; non-friends see no personal activity of any kind, per §4.2. **This note is documentation only — Social Foundation Step 1 does not implement any of §3–§7 below; wishlist RLS is unchanged, still public-if-profile-is-public, exactly as before Step 1.**

Companion document: `UI_CONSISTENCY_AUDIT.md` (§41–42 of the source task). Existing document this supersedes in part: `FUTURE_PRODUCT_ARCHITECTURE.md` — **not edited**; §14 below explains exactly what changes and why.

---

## 0. Headline findings

1. **The current architecture is more exposed than the product wants, by default, today.** `profiles.is_public` defaults to `true`. Every existing visit, wishlist item, and "public" photo of every current user is readable right now by any `anon` or `authenticated` client via `profile_is_visible()`. This isn't a bug introduced by this spike — it's the existing MVP-era default — but it is the exact opposite of the stated new direction ("no public individual activity for strangers") and needs explicit remediation before real testers arrive, not just new code for new users.
2. **A friend system was already attempted once, then orphaned.** `lib/data/repositories/friendship_repository.dart`, `lib/models/friendship.dart`, and part of `lib/features/profile/profile_screen.dart` (Friends section, friend search, pending requests) already exist in the Flutter codebase, querying a `friendships` table and a `profiles.tier` column. Neither exists in the live database — both were dropped by the `20260805141519_production_schema_v1.sql` schema rebuild (see its `DROP TABLE IF EXISTS public.friendships` and the absence of any `tier` column in the new `profiles`) and never recreated. Confirmed via a live read-only query against the linked project: `friendships`, `user_tiers`, `tier_stats`, `trophies`, `user_trophies` all return zero rows from `information_schema.tables`/`views`. **The Profile screen's Friends/Community Stats/tier sections will throw at runtime today, independent of anything in this spike.**
3. **The good news: the orphaned shape is almost exactly right.** `Friendship`'s `requester_id`/`addressee_id`/`status` (`pending`/`accepted`) and `FriendshipRepository`'s request/accept/decline/search methods are a close match for what this document independently recommends below. The smallest robust path is to **recreate the table this code already expects** (widened to add `declined`/`blocked`), fix the `profiles.tier` join (replace with `username`/`avatar_url` — `tier` doesn't exist and is out of this spike's scope), and add real RLS — not redesign the Flutter shape from scratch.
4. **Trips are already exactly right.** `planned_trips`/`planned_venues` are owner-only, no public read, by deliberate design already recorded in their migration's own comments. Nothing needs to change here for the new direction; it's the one place the "conservative by default" principle is already fully implemented.
5. **Photo visibility is currently two layers that don't agree.** `public.photos` row-level RLS already supports `is_public AND profile_is_visible(user_id)` sharing, but `storage.objects` RLS (the actual image bytes) is strictly owner-only — `(storage.foldername(name))[1] = auth.uid()::text`, full stop. A photo row can claim to be shareable while the underlying image is structurally unreachable by anyone but its owner. This must be resolved as part of any friends-visible photo work, not assumed already functional.
6. **The old `follows` table is exactly the model the product now explicitly rejects** (one-way, no acceptance step) and should be retired in favor of `friendships`, not extended.

---

## 1. Current-state audit

### 1.1 Auth / profile

- **Signup**: `SignupScreen` collects Name, Email, Password only — no username, no avatar. `AuthRepository.signUp` calls `_client.auth.signUp(email:, password:, data: {'display_name': displayName})`.
- **Profile bootstrap**: `public.handle_new_user()` (a `security definer` trigger on `auth.users` insert) inserts `public.profiles(id, username)` — reading `username` from `raw_user_meta_data`, which **signup never actually sets** (only `display_name` is passed). Net effect: **every new profile today is created with `username = null`.** `display_name` is populated separately by the client (`ProfileRepository.updateDisplayName`, called somewhere in the signup flow or on first profile load — not confirmed to be wired automatically; `profile_screen.dart`'s "Edit Profile" row is a no-op today, per audit).
- **Profile model/table**: `profiles(id, username, display_name, avatar_url, home_country_code, is_public default true, created_at)`. `username` is `unique` but nullable — so it exists as a column but isn't populated at signup and isn't user-editable anywhere in the current UI.
- **Avatar**: column exists (`avatar_url`), **no upload UI or repository method exists anywhere** — Profile screen renders initials in a circle, never an image.
- **Visibility**: exactly one flag, `is_public` (boolean, default `true`), gating `visits`/`wishlist`/`photos` reads via `profile_is_visible(target uuid)` (`target = auth.uid() OR profiles.is_public`). No friends concept anywhere in the current visibility model.
- **Discovering another user**: no path exists in the current UI to view another user's profile at all (confirmed: no `onTap` navigation to a profile-detail screen anywhere, even from the — broken — friend search results).

**Can a new user today**: sign up (yes) → get a profile row automatically (yes, via trigger) → set a display name (column exists, but no working "Edit Profile" UI — the row is a no-op) → set a username (no UI at all) → upload an avatar (no) → make their profile private (no UI; defaults to public and stays public) → discover another user (no navigation path exists, and the one code path that tries — `FriendshipRepository.searchUsers` — is broken against the live schema).

### 1.2 Visits

`visits(id, user_id, entity_type, entity_id, visited_on, rating [overall, 1–10], food_rating, service_rating, wine_rating, value_rating [each 1–10, independently nullable], menu_type [tasting_menu|a_la_carte|both], notes, price_paid, currency, keys_at_visit, stars_at_visit)`. No `created_at`/`updated_at`, no `visibility` column. Multiple visits to the same venue are explicitly first-class (no unique constraint on `user_id, entity_type, entity_id` — confirmed by index shape, `visits_user_visited_idx`/`visits_entity_idx`, neither unique). RLS: read via `profile_is_visible(user_id)` — **public by default, today, for any user whose profile is public (the default)**; write strictly owner-only. `VisitedRepository`'s one method that doesn't filter by `user_id` (`loadVisitById`) is unused by any screen today, gated only by RLS.

### 1.3 Photos

`photos(id, user_id, visit_id [FK, not cascading — photos must be deleted before their visit], entity_type, entity_id, storage_path, caption, taken_at, is_public default true)`. **Two independent, currently-inconsistent visibility layers**:
- Row RLS: `user_id = auth.uid() OR (is_public AND profile_is_visible(user_id))` — same public-by-default exposure as visits.
- Storage RLS (`visit-photos` bucket, private): **strictly owner-only**, `(storage.foldername(name))[1] = auth.uid()::text`, for select/insert/delete alike. No exception for a shareable/public photo row at all.

The app always reads images via short-lived signed URLs (`PhotoRepository.resolveDisplayUrls`), never a public bucket URL — which is exactly why the storage-layer gap matters: **generating a signed URL for someone else's photo would fail today even for a row the row-level RLS says should be visible.** `is_public` is read into the `VisitPhoto` model but never set or acted on by any current repository method or UI — effectively vestigial.

### 1.4 Trips / planned visits

`planned_trips(id, user_id, title, start_date, end_date, country_code, city [free text], notes, created_at)`, `planned_venues(id, user_id, entity_type, entity_id, trip_id [nullable, `ON DELETE SET NULL`], start_date, end_date, notes, status, created_at)`. **RLS: owner-only for both tables, both read and write — no anon/public grant exists at all.** This is a deliberate, already-documented departure from visits/wishlist (see the migration's own comment: "a future trip's dates and destination are more sensitive than past visit history"). Nothing here needs to change for the new direction.

### 1.5 Wishlist

`wishlist(user_id, entity_type, entity_id, added_at, priority)`, `unique(user_id, entity_type, entity_id)`. RLS: same pattern as visits — read via `profile_is_visible(user_id)` (public by default today), write owner-only. Currently readable by anyone if the owner's profile is public (the default).

### 1.6 Events

`events`/`event_restaurants`/`event_hotels` are fully public-read catalogue content (`using (true)`), no client write policy at all — written only by import scripts. `admission_type`/`admission_note` exist (free/paid/mixed/unknown). **No attendance concept of any kind exists** — no table, no column, no UI. `eventMatchesTrip`/`eventsMatchingTrip` (pure, tested) already power Trip Detail's "WHAT'S ON" section by comparing dates/country/city — no schema involvement, nothing to change there.

### 1.7 The `follows` table (pre-existing, not asked about directly, but directly relevant)

`follows(follower_id, following_id, created_at)`, `unique(follower_id, following_id)`, `check (follower_id <> following_id)`. RLS lets either party read a row they're part of; insert as yourself; delete by either party. **This is precisely the one-way, no-acceptance-required following model the product now explicitly rejects.** No Flutter code references it at all (confirmed: zero hits for "follow" across `lib/`) — it exists in the schema, unused, a leftover from before the current product direction was set. Recommendation: retire it in favor of `friendships` (§8); do not extend it, do not build on it.

### 1.8 RLS patterns actually in use today

Three exist. Any new table should reuse one of these or the new fourth pattern this document adds (§9), never invent a fifth ad hoc shape:

1. **Public catalogue** (`restaurants`, `hotels`, `events`, `hotel_restaurants`, `award_history`, `worlds_50_best`) — public read, zero client write.
2. **Owner-visible-or-public-profile** (`visits`, `wishlist`, `photos`) — read via `profile_is_visible()`, write owner-only. **This is the pattern that needs to change** — see §11.
3. **Owner-only** (`planned_trips`, `planned_venues`) — both read and write restricted to `user_id = auth.uid()`. Already correct for the new direction.

---

## 2. Friends

### 2.1 Recommended model

Explicit, mutual, request/accept — exactly what the task asks for, and exactly what the orphaned `Friendship`/`FriendshipRepository` code already assumes. States: **`pending` → `accepted`**, plus **`declined`** and **`blocked`** as terminal/semi-terminal states on the *same row* (never delete-and-forget, see below).

**Should `declined` be stored or can it just delete the row?** Store it. Deleting on decline lets the declined requester immediately re-send an identical request (spam/pressure vector — exactly the kind of thing a "no open social network" product should avoid). Keeping the row in `declined` status means: the UI can simply not show a "send request" affordance again for a declined pair (or allow it only as a fresh, deliberate action after some cooldown — a product decision, not an architecture one), and the addressee is never repeatedly pestered by the same request. **Unfriending an *accepted* friendship**, by contrast, is fine to fully delete — there's no equivalent spam risk in "you're no longer friends," and both users may reasonably want a clean slate to re-request each other later without a lingering row implying history.

So: one row per unordered pair, ever (see §2.2's uniqueness design); status transitions in place; only `accepted → removed` is a hard delete, everything else stays as a row with its current status.

### 2.2 Table design (conceptual — no SQL)

`friendships`: `id`, `requester_id` (→ `profiles.id`), `addressee_id` (→ `profiles.id`), `status` (`pending | accepted | declined | blocked`), `created_at`, `accepted_at` (nullable, set only on the pending→accepted transition).

**Requirements and how each is met:**
- **No self-friending**: a check constraint `requester_id <> addressee_id`, identical in spirit to `follows`' own existing `check (follower_id <> following_id)` — same pattern, already precedented in this schema.
- **No duplicate/reverse-duplicate rows** (A→B and B→A both existing simultaneously): a unique constraint on the *unordered pair*, not on `(requester_id, addressee_id)` directly (which would still allow the reverse row). The standard, well-understood way to do this without application-level races is a generated column pair — e.g. `user_low` = `least(requester_id, addressee_id)`, `user_high` = `greatest(requester_id, addressee_id)` — with a unique index on `(user_low, user_high)`. This is schema design, not SQL syntax; the point is: enforce it in the database, not only in application code, so a race between two simultaneous requests can't create two rows.
- **Mutual once accepted**: a single row, `status = 'accepted'`, is read from *both* directions by query shape (`requester_id = me OR addressee_id = me`) — there is no separate "reverse" row to keep in sync, which is exactly why the single-row-per-pair design matters.
- **Either user can remove**: delete policy checks `requester_id = auth.uid() OR addressee_id = auth.uid()`.
- **Blocking prevents interaction**: `status = 'blocked'` on the same row, settable by either party from any prior state; while blocked, no new request may be created between the pair (checked in the insert path — see §9) and all friends-only content visibility checks (§11–12) simply stop matching, since they all require `status = 'accepted'`.

### 2.3 Friend discovery — MVP recommendation

**Unique username + partial search**, not display name, not email. `profiles.username` is *already* a unique column in the live schema — the infrastructure exists, it's just never populated (§1.1) or searchable in the UI. Recommendation:
- Require username at signup (or as a mandatory first-run step for existing/new accounts) — fixes the `handle_new_user()` trigger reading a field the signup form never actually sets (§1.1), a genuine existing bug independent of this spike's own recommendations.
- Search by `username ILIKE` partial match (mirroring `FriendshipRepository.searchUsers`'s existing shape, just searching `username` instead of the broken `display_name`/`tier` combination).
- **Do not make email publicly searchable.** No product reason surfaced in this brief justifies it, and it's a classic way to let strangers correlate real-world identity with in-app activity against a user's wishes.
- **Defer QR codes and contacts-list sync** for MVP — both are real, useful discovery mechanisms eventually, but neither is needed to validate the core friends+privacy model with a small tester cohort, and contacts-sync in particular carries its own separate privacy-review burden (reading a user's address book) that doesn't belong in this phase.

### 2.4 Blocking — must-have, not deferrable

Real strangers (MVP testers who don't already know each other) will be sending friend requests to each other for the first time. A basic block capability is cheap here specifically because it's just another `friendships.status` value plus a few RLS/RPC checks — not a new subsystem. Recommendation: **build it now**, alongside the friendship table itself, but explicitly **do not** build reporting/moderation-queue infrastructure yet (a human-reviewed report queue is a real, separate, deferrable project).

### 2.5 Unfriend behavior

Deleting an `accepted` friendship row must, by itself and immediately, cut off every friends-only visibility grant between the two users — visits, photos, trip content (if ever made friends-visible), event attendance. This happens automatically and dynamically **only if** every friends-visibility RLS check is a live subquery against `friendships` (§11–12), never a cached/duplicated permission. No content rows are rewritten; the next `SELECT` simply stops matching. This is a direct architectural consequence of the recommendation in §11, not extra work.

### 2.6 RLS semantics (§31 of the source task)

- **SELECT**: `requester_id = auth.uid() OR addressee_id = auth.uid()` — a user sees only relationships they're part of.
- **INSERT**: `with check (requester_id = auth.uid())`, plus the self-friend and pair-uniqueness constraints from §2.2 doing the rest. A raw client insert is fine for *creating a pending request* — there's no state-transition risk there.
- **State transitions (accept/decline/block/unfriend)**: recommend **thin RPCs**, not raw client `UPDATE` + RLS alone — `respond_to_friend_request(friendship_id, accept: bool)`, `block_user(other_user_id)`, `remove_friendship(friendship_id)`. Reason: "only the addressee may accept a *pending* request addressed to them" is a rule about the *combination* of caller identity, current status, and requested new status — awkward and error-prone to express as a single declarative RLS `USING`/`WITH CHECK` pair, and this project already has a precedent for exactly this situation (`FUTURE_PRODUCT_ARCHITECTURE.md` §5.4: stamp-claim state transitions are server-side, not client-writable, for the same class of reason). A thin `security definer` function that checks the rule explicitly, then performs the update, is simpler to audit than a clever RLS expression and avoids a client ever successfully accepting its own outgoing request or resurrecting a blocked row by crafting the right `UPDATE`.
- **DELETE** (unfriend): `requester_id = auth.uid() OR addressee_id = auth.uid()` — either party, no RPC needed (no state-machine rule to enforce, just ownership).

---

## 3. Privacy

### 3.1 Core visibility tiers — PRIVATE / FRIENDS, not PRIVATE / FRIENDS / PUBLIC

Recommend dropping a public individual-activity tier entirely for personal content (visits, ratings, photos, wishlist). This matches the stated product direction exactly ("no public individual activity feed for strangers") and removes an entire category of accidental-oversharing risk — there is no toggle a user can set that broadcasts a personal rating to strangers. **Aggregate/anonymous visibility remains a completely separate concept** (§5), reachable without any individual content ever being marked "public."

### 3.2 Visit visibility

Recommend an additive `visibility` column on `visits`: `private | friends`.

- **Default for new visits: `private`.** The conservative choice, consistent with the product's own stated bias throughout this brief. A user opts in to friends-visibility per visit (or via a profile-level default they can change, see below) rather than opting out — during an initial trust-building MVP phase with real testers who've never used the app before, defaulting to share-nothing is the safer failure mode than defaulting to share-everything.
- **Default for existing (historical) visits: `private`, applied as a one-time backfill.** Every visit currently in the database was created under the *old* model, where the actual behavior was "public to anyone if your profile happens to be public" — not an informed choice about friends-visibility, which didn't exist yet. Continuing to expose that history by any default other than the most conservative one would be inconsistent with the very principle motivating this spike. This is the one place this document recommends a *behavioral* backfill (not just a schema default) — flagged explicitly in §13/§20.
- **Can the user change it after saving?** Yes — same as any other visit field, non-destructive, no special-cased "can't undo" restriction.
- **Do ratings/comments/photos inherit visit visibility?** Yes. One visibility source of truth per visit; no independent visibility concept for its sub-fields.
- **Should venue aggregate calculations include private visits?** See §5 — yes, via a separate, decoupled `include_in_community_stats` flag, not via the `visibility` column itself. This is the single most important modeling decision in this document; see §5.1 for the full reasoning.

### 3.3 Trip visibility

**Recommend: strictly private, full stop, for MVP — no friends tier at all yet.** The schema already enforces this (§1.4) with zero public/friends read policy of any kind; recommend keeping it that way rather than adding a `visibility` column now. Trips reveal *future* location and time — meaningfully higher-stakes than a past visit — and nothing in the current product brief requires friends-visible trips to validate the MVP. **Public trips should be prohibited entirely, not just discouraged by a default** — i.e., don't even add `public` as a legal value if a `visibility` concept is ever added here.

If a friends tier is added later: `planned_venues` should **inherit** `planned_trips.visibility` rather than carry its own — one visibility source of truth per trip, matching the task's own stated preference. A planned venue detached from its trip (`trip_id` set to null, which the schema already supports on trip deletion) simply reverts to private-only, since it no longer has a trip to inherit from.

### 3.4 Wishlist visibility

**Recommend: private only, for MVP** — a real tightening from today's default-public behavior. "Aspirational travel behavior" (where you *want* to go, not where you've been) is arguably more revealing than a past visit in some ways (it signals intent, not just history), and nothing in the current product needs it shared yet. Defer a friends-visible wishlist entirely rather than building a visibility column for it now; if it's wanted later, it's the same additive pattern as visits (§3.2).

### 3.4a Approved direction, supersedes §3.4 — wishlist auto-visible to accepted friends

**2026-08-13, approved after Social Foundation Step 1 deployment.** The product owner has decided against §3.4's "private only" recommendation above. The approved MVP direction instead:

- **Wishlist is automatically visible to accepted friends** — no opt-in step, no separate visibility column, no per-item or per-user setting.
- **No per-user or per-item visibility setting is needed for wishlist at MVP.** This is a deliberate simplification versus visits (§3.2), which does get a real `private | friends` column — wishlist gets none. A friend simply sees the whole wishlist; a non-friend sees none of it, exactly as `profile_is_visible()`-gated content does today, except scoped to *friendship* rather than the `is_public` flag.
- **Visits**: `private | friends`, unchanged from §3.2 — this is the one content type that does get a real per-row visibility column.
- **Ratings inherit their parent visit's visibility** — unchanged from §3.2's existing recommendation.
- **Photos inherit their parent visit's visibility** — unchanged from §3.6's existing recommendation (including the storage-layer fix §3.6 already calls out as required).
- **Trips remain strictly private** — unchanged from §3.3; no friends tier for trips at MVP.
- **Non-friends see no personal activity of any kind** — no visits, no ratings, no photos, no wishlist, no trips — consistent with §4.2's existing "deliberately minimal" non-friend profile design.

**Implementation implication for whoever picks up Step 2** (not built by this note, not built by Social Foundation Step 1 — documentation only): `wishlist_read` RLS should be rewritten directly to an owner-or-accepted-friend check (mirroring the `is_friend()`-style helper §7.4 recommends), skipping §3.4's `private`-only tightening and skipping the "add a `visibility` column" pattern used for visits — wishlist needs neither, per this decision. Do not build a per-item wishlist visibility toggle; it was explicitly decided against.

### 3.5 Profile discoverability vs. activity visibility — two separate concepts, not one flag

The current `profiles.is_public` boolean tries to be both "can strangers find/friend-request this person" and "can strangers see this person's visits/wishlist/photos" at once — exactly the ambiguity the task warns against. Recommend splitting cleanly:

- **Profile discoverability** (minimal identity: `username`, `display_name`, `avatar_url`): visible to any *authenticated* user, always — not gated by a flag at all. You cannot send a friend request to, or be found by, someone whose basic identity you can't see; this is a "phonebook" level of visibility, not an activity-sharing decision, and doesn't need its own toggle for MVP. (A future "hide me from search" setting is a reasonable later addition, not required now.)
- **Activity visibility** (visits/photos/wishlist/trips): governed entirely by the new `visibility` columns (§3.2–3.4) plus accepted-friendship status — **`profiles.is_public` stops being read by any RLS policy that gates activity.** The column can remain in the table harmlessly unused, or be repurposed/renamed later; this document doesn't require dropping it, only recommends no new policy ever reference it for activity content again.

### 3.6 Photo inheritance (confirming the task's preferred direction)

**Photo inherits visit visibility — no independent per-photo visibility.** This requires two changes, not one: (a) `photos_read` RLS should check the *parent visit's* `visibility` + friendship status rather than `photos.is_public` (§11), and (b) the **storage-layer gap from §1.3 must be closed** — `storage.objects` RLS for the `visit-photos` bucket needs to allow a friend-with-accepted-status to read another user's folder when the corresponding visit is friends-visible, not just the owner. This is the one place a signed-URL approach genuinely needs care: either (i) extend the storage policy itself to run the same friendship+visibility check `photos_read` does (possible, but duplicates the visibility logic in two RLS policies that must stay in sync), or (ii) mint the signed URL via a `security definer` RPC that checks visibility once and returns a time-limited URL regardless of the requester's own storage permissions (cleaner single source of truth, consistent with this document's general preference for server-side logic over duplicated RLS — recommended).

### 3.7 Existing-data backfill summary

| Data | Backfill on ship |
|---|---|
| `visits.visibility` | All existing rows → `private` (deliberate protective default, §3.2) |
| `wishlist` (if ever given a visibility column) | Same — private |
| `photos` | No new column needed (inherits visit); existing `is_public` values become irrelevant once RLS stops reading them |
| `profiles.is_public` | Left as-is in the table; simply no longer consulted by activity RLS going forward |

---

## 4. Friend experience

### 4.1 Friend profile — what a friend can see

Avatar/name, Passport summary (counts), restaurants/hotels visited, ratings, photos (subject to each visit's own `visibility`, which for a friend will show everything marked `friends`), and trips/wishlist **only if** those are ever explicitly made friends-visible later (not at MVP, per §3.3–3.4).

### 4.2 Non-friend profile — deliberately minimal

Avatar, display name, username, and an "Add friend" action. **No visit counts, no ratings, no photos, no Passport summary, no trips, no wishlist** — nothing that would let a stranger learn anything about a person's activity before that person has chosen to accept them. This is the direct enforcement mechanism for "no public individual activity feed for strangers."

### 4.3 Feed architecture — no dedicated `posts`/`activity` table

Recommend deriving a friend feed by directly querying accepted-friends' own `visits`/`photos` (and later `event_attendance`, §6) where `visibility = 'friends'`, ordered by their natural timestamp, unioned across the small number of source tables — never a separately-authored "post." This matches the task's own explicit preference and avoids two copies of the same fact (a duplicated feed row can drift from the actual visit if the visit is later edited or deleted; a derived read cannot). At MVP scale (a handful of testers, a handful of friends each), this is a cheap, well-indexed set of queries — no materialized/denormalized activity table is justified yet. Revisit only if/when feed-read latency actually becomes a measured problem with real usage volume, not preemptively.

### 4.4 What non-friends can see, restated plainly

Their own basic identity (§4.2) and, separately, whatever anonymous aggregate numbers the Community Intelligence surfaces (§5) — which never reveal that this *specific* stranger did anything at all.

---

## 5. Community intelligence

### 5.1 The core decision: does a private visit still count toward aggregates? — **Yes, via a separate opt-out flag (Model C)**

This is the single decision the rest of this section depends on, so it's addressed first and explicitly. Of the three models the task poses:

- **Model A** (private = hidden individually, but always counted anonymously) makes the Community Intelligence feature actually useful from day one (most visits will default to `private`, per §3.2 — if private visits didn't count, the feature would be nearly empty during exactly the period it needs to prove itself) but risks feeling like a bait-and-switch if users aren't told clearly that "private" doesn't mean "excluded from everything."
- **Model B** (private = excluded from aggregates too) is the most intuitively "safe"-sounding but makes Community Intelligence nearly non-functional at MVP scale, since the conservative default (§3.2) means most content starts private.
- **Model C** (two independent flags: `visibility` controls *who sees this individually*, a separate `include_in_community_stats` controls *whether it counts anonymously*) is what this document recommends. It resolves the tension between A and B without picking a lesser evil: a user can be fully private to friends-and-strangers alike (`visibility='private'`) while still contributing an anonymous data point to the restaurant's community score, **or** opt all the way out of that too, independently. Two small, separately-understandable levers beat one overloaded one — directly matching the task's own instruction not to let one flag create privacy ambiguity.

**Trust framing matters as much as the architecture here.** Whatever UI ships around this must say, plainly, something like *"Your rating counts anonymously toward this restaurant's community score. Nobody can see that you personally visited unless you're friends."* — not bury the distinction in a settings screen no one reads.

### 5.2 Community-stat opt-out (§25 of the source task)

Recommend `profiles.include_in_community_stats boolean not null default true`. Default **included**, not excluded — reasoning: aggregation is anonymous by construction once the minimum-threshold rule (§5.7) is enforced, so the marginal privacy cost of inclusion is low, while the marginal product cost of excluding by default is high (an opt-in default would likely leave the feature short of the 5-unique-user threshold for most venues during exactly the small-cohort MVP period it most needs to prove out). **One flag, governing all aggregate participation** (visits, ratings, event attendance alike) — not a separate opt-out per feature, matching the task's own explicit instruction to avoid overly granular MVP privacy settings. Existing historical visits should be included in aggregates once this ships (they're already anonymized by the threshold rule regardless of when they were created); no separate backfill decision is needed here beyond the default itself.

### 5.3 Community score

**MVP metric: average of `visits.rating` (the existing overall 1–10 rating)**, computed per restaurant/hotel, filtered to visits from users who are both `include_in_community_stats = true` and meet the minimum threshold (§5.7). Do not touch or replace the underlying personal `rating` values — this is purely a derived, read-time aggregate. Sub-dimension averages (food/service/wine/value) are a natural, low-risk later extension using the identical pattern and the columns that already exist (`food_rating` etc.) — not required for MVP, since the overall rating alone already answers "is this place good."

### 5.4 Total visits vs. unique visitors

Both are useful and both are cheap to compute from the existing `visits` table (`count(*)` vs `count(distinct user_id)`) — **recommend computing both at read time via an RPC, not persisting either as a stored/materialized column**, at MVP data volumes. A materialized view refreshed on a schedule is the natural next step once real usage volume makes live aggregation measurably slow — not a day-one requirement given the small tester cohort this phase is aimed at. Persisting stored aggregate counters today would also reintroduce exactly the kind of staleness/consistency risk (keeping a counter in sync with row inserts/deletes/visibility changes) this document otherwise avoids by preferring live, RLS-safe reads.

### 5.5 Most visited

MVP: **all-time total visit count**, computed via the same read-time RPC/view, respecting §5.1–5.2's eligibility filters. Time-windowed variants (30-day, this-year) are the identical query shape with a `visited_on >=` filter — straightforward to add, but recommend **starting with all-time only**: a 30-day window is likely to be noisy or empty for most venues during an initial small-cohort test and wouldn't be a meaningful signal yet. Add windows once there's enough real data for them to say something true.

### 5.6 Most revisited

Recommend a **transparent, literal metric**: *"number of unique members with 2 or more visits to this venue."* This directly answers "do people come back," is trivially explainable in one sentence (no opaque weighting), and is genuinely distinctive — a restaurant with many first-time visitors but few return visits reads very differently from one with a smaller, devoted following, which "most visited" alone can't distinguish. Avoid any composite/weighted "loyalty score" for MVP; a single, honest count is more trustworthy and easier to build correctly.

### 5.7 Minimum aggregation threshold — recommend **≥5 unique qualifying users**

Below 5, show *"Not enough community data yet"*, never a specific small number (never "2 members visited" — a count that low can make a specific person identifiable, especially combined with other context like the venue's location or a friend knowing who else likes to go there). **Why 5, not higher**: it needs to be low enough that the feature isn't permanently blank during the exact early-testing period it most needs to be validated by real usage, while still being high enough that no single visit or rating can be confidently attributed to one person, and an averaged rating across 5+ people meaningfully obscures any one person's actual number. Raise it later (10+) once the user base is large enough that 5 stops being the binding constraint on the feature ever showing anything at all. Apply the **same threshold consistently** across visit-based stats, rating averages, and event attendance (§6.3) — one number, one rule, everywhere aggregate counts are shown, per the task's own explicit instruction.

### 5.8 Trending — recommend deferring past initial MVP testers

The mechanism itself is simple and doesn't need building now to be worth documenting: visits in the last 30 days vs. the prior 30 days, a velocity ratio. The reason to defer isn't complexity, it's data volume — with a small initial tester cohort, a "trending" signal computed from a handful of visits per venue would be noisy at best and actively misleading at worst (a single extra visit could make something look "3x trending"). Revisit once real usage volume makes the signal meaningful, not before.

### 5.9 Hotel metrics

Same pattern as restaurants, using the same polymorphic `entity_type/entity_id` rows already in `visits`: total stays, unique guests, average overall rating (hotels only ever populate `visits.rating`, never `food_rating`/`wine_rating`/etc., since those are already optional/nullable columns — nothing forces restaurant-specific dimensions onto a hotel stay, the schema already gets this right), repeat-stay rate using the identical "≥2 stays" metric as §5.6. No new columns, no new tables — purely a query-shape variation on the same underlying rows.

---

## 6. Event attendance

### 6.1 Table recommendation

New table, `event_attendance`: `event_id` (→ `events.id`), `user_id` (→ `profiles.id`), `status`, `created_at`, `unique(event_id, user_id)`.

### 6.2 Going vs. interested — recommend **`going` only for MVP**

The task asks directly whether `interested` is needed at MVP; recommend no. A single, unambiguous "I'm going" toggle is the smallest robust model that answers the actual product need (*"X members are going"*) without doubling the UI copy/states/query complexity for a distinction (going vs. merely interested) that isn't yet asked for anywhere else in this brief. `status` as a text+check column rather than a boolean still leaves room to add `interested` later as a pure additive value with zero migration pain, matching this schema's own established taxonomy convention (see `events.event_type`/`status`'s own doc comments).

### 6.3 Attendance privacy

- **Aggregate (public/community UI)**: count only, subject to the same §5.7 threshold (*"Not enough community data yet"* below 5, never a specific small number).
- **Friend feed**: *"Ruud is going to 't Preuvenemint"* — shown only if the attendance row itself is friends-visible. Recommend `event_attendance` carry its **own** `visibility` column (`private | friends`) mirroring `visits`, rather than blindly inheriting a separate, unrelated setting — but with a **different, more permissive default than visits**: recommend defaulting new attendance rows to `friends`, not `private`. Reasoning for the deliberate divergence: an event itself (unlike a personal dining rating) is already fully public catalogue content — "I'm going to a public festival" is a categorically lower-sensitivity disclosure than "I rated this specific restaurant on this specific night," and defaulting to share-with-friends here makes the feature actually work for testers without requiring an extra opt-in step for something this low-stakes. A user can still set it to `private` per event if they'd rather not even tell friends.
- **Consistency**: same threshold rule, same friendship-based visibility mechanism, same `include_in_community_stats`-style opt-out lever as visits (§5.2) — one privacy model applied uniformly across every content type this document covers, not a bespoke rule per feature.

---

## 7. Database, security, and RLS design

### 7.1 Views/RPCs vs. raw client aggregation — recommend **security-definer RPCs**, not client-side aggregation, not plain views, not materialized views (yet)

This is close to forced, not just preferred: standard row-level RLS on `visits`/`event_attendance` is per-row, owner-or-friends-scoped — a client attempting `GROUP BY entity_id` directly against those tables would only ever see rows it's individually allowed to read (its own, plus friends'), never the full community, so a correct aggregate is *structurally impossible* to compute client-side under the RLS this document recommends. A `security definer` function that runs with elevated privilege internally, applies the §5.1/§5.2/§5.7 eligibility and threshold logic itself, and returns **only the final aggregate numbers** (never row-level data) is the only shape that is simultaneously correct and safe. Plain (non-materialized) views are the right performance profile for MVP data volumes; materialized views/stored aggregate tables are a future optimization once real query volume justifies the added staleness/refresh complexity — not required now.

### 7.2 Required indexes

- `friendships`: an index on the normalized `(user_low, user_high)` pair (§2.2, doubles as the uniqueness constraint) covers "are these two people friends" lookups; a secondary index on `addressee_id` alone speeds "my pending requests" reads.
- `event_attendance`: `unique(event_id, user_id)` already covers "who's attending this event"; add a secondary index on `user_id` for "which events is this user attending" (e.g. a future personal "my events" view).
- `visits`: the existing `visits_entity_idx (entity_type, entity_id)` already supports the community-aggregate `GROUP BY` at MVP scale; revisit only if real query volume shows it's insufficient.

### 7.3 RLS implications summary

| Table | Change |
|---|---|
| `visits` | Add `visibility` column; `visits_read` policy rewritten to `owner OR (visibility='friends' AND accepted friendship exists)` — **public-profile read path removed entirely** |
| `photos` | `photos_read` policy rewritten to check the parent visit's visibility/friendship, not `photos.is_public`; storage RLS needs the §3.6 fix |
| `wishlist` | `wishlist_read` policy tightened to owner-only (no friends tier at MVP, §3.4) — **public-profile read path removed entirely** |
| `planned_trips`/`planned_venues` | No change — already correct |
| `friendships` (new) | Per §2.6 |
| `event_attendance` (new) | Owner-or-friends read (mirrors visits), owner-only write |
| `follows` | Recommend dropping once `friendships` ships (§1.7) — not required to keep, not referenced anywhere |

### 7.4 Highest-risk areas and mitigations

- **Direct object access** (guessing another user's `visit_id`/`photo_id`): already mitigated by RLS on every relevant table today; the friends-visibility rewrite must preserve this, never widen it accidentally to "any authenticated user."
- **Friendship spoofing** (claiming a friendship that doesn't exist, or claiming to be the addressee of someone else's pending request): mitigated by RLS `USING`/`WITH CHECK` always keying off `auth.uid()`, never a client-supplied user id, for every friendship state transition (§2.6).
- **Private visit/photo leakage through a friends-visibility bug**: the single highest-value mitigation is *one* subquery pattern reused everywhere friends-visibility is checked (visits, photos-via-visit, event attendance), rather than three subtly different hand-written policies that could drift out of sync — recommend a single reusable `is_friend(a uuid, b uuid) returns boolean` helper (mirroring the existing `profile_is_visible()` helper's own shape) that every friends-visibility policy calls, so there is exactly one place the friendship-acceptance logic can ever be wrong.
- **Aggregate re-identification**: mitigated by the §5.7 minimum-threshold rule enforced *inside* the security-definer RPC (never trusted to the client, never skippable by a clever query), plus never exposing row-level data from the same RPC.
- **Trip-location privacy**: already fully mitigated (owner-only, §1.4) — the main risk here is a *future* change accidentally loosening it; flag explicitly that any future "share this trip with a friend" feature must add a new, narrow policy rather than relaxing the existing owner-only one.
- **Event attendance leakage**: mitigated by the same friends-visibility pattern as visits, plus the same aggregate threshold rule for the public count.
- **Storage-layer bypass** (§3.6): the concrete, specific risk is that fixing `photos_read` at the row level without also fixing `storage.objects` RLS creates a false sense of "this is shareable now" while the image itself remains fetchable only by its owner — call this out explicitly in implementation review, since it's an easy thing to ship half of.

---

## 8. Community — revised role and geographic communities

### 8.1 What "Community" now means, and the naming collision this resolves

`FUTURE_PRODUCT_ARCHITECTURE.md` §7 designed "Community" as curated **geographic** groups (`communities` + `community_memberships`, e.g. "Netherlands," "Paris") with membership and a feed. That document's own §1.8 already flagged a *pending* naming collision with the existing `community_rankings_tab.dart` ("Community" meaning "aggregate crowd data"). **The new product direction resolves this collision in the opposite direction than that document anticipated**: instead of geographic communities needing to avoid colliding with "aggregate crowd" naming, "Community" now *means* aggregate/crowd data plus friend activity plus events — much closer to the *existing* Rankings usage than to the geographic-clustering concept. Recommended future Community tab composition:

- **Friend activity** — trusted, identifiable, derived (§4.3).
- **Community Intelligence** — anonymous aggregate (§5).
- **Events** — aggregate attendance + the existing curated What's On content, cross-linked with Explore's own What's On rather than duplicated.
- *(Later)* venue experiences, once venue profiles/claims exist.

**Explicitly not**: a public social feed of individual strangers' activity, and — per §8.2 — not geographic clustering, for now.

### 8.2 Geographic communities — recommend deferring, not deleting the concept

The task's own framing already answers this directly: Netherlands/Paris-style communities are not required for initial testers. This document agrees and goes one step further: building `communities`/`community_memberships` *before* Friends + Community Intelligence exist would add membership/geography complexity to a product surface that doesn't have the underlying Friends foundation yet to make "community" feel trustworthy rather than "open social network with extra steps." **Recommend explicitly**: Friends + Community Intelligence + Events first; geographic communities revisited only once those are live and real usage shows a genuine need for geography-scoped grouping beyond what a country/city filter on Community Intelligence already provides. `FUTURE_PRODUCT_ARCHITECTURE.md`'s own `communities` table design (§7.1 of that document) remains a reasonable starting point *if and when* this is revisited — nothing about the new direction invalidates that design, it only reorders it later in the sequence.

---

## 9. Database change plan

For every table/column below: purpose, default, migration safety, backfill, RLS impact, indexes, dependencies. All additive; nothing here drops or renames an existing column, matching §14.

| Change | Purpose | Default (new rows) | Backfill (existing rows) | RLS impact | Indexes | Depends on |
|---|---|---|---|---|---|---|
| `friendships` (new table) | Mutual friend relationships | — | N/A (no existing data) | New: owner-or-participant read; requester-only insert; RPC-mediated transitions (§2.6) | `(user_low, user_high)` unique; `addressee_id` | `profiles` |
| `visits.visibility` (new column) | Per-visit sharing control | `private` | **All existing rows set to `private`** (deliberate, §3.2) | `visits_read` rewritten (§7.3) | none new (existing entity index sufficient) | none |
| `visits.include_in_community_stats` — actually recommend this lives on `profiles`, not `visits` (§5.2) | See below | — | — | — | — | — |
| `profiles.include_in_community_stats` (new column) | One flag governing all aggregate participation | `true` | All existing profiles → `true` (§5.2 reasoning) | Read by the community-aggregate RPCs only, not by any table RLS policy | none needed | none |
| `photos_read` RLS (policy edit, no column change) | Inherit visibility from parent visit | — | N/A | Rewritten to join `visits.visibility` + friendship (§3.6) | none new | `visits.visibility`, `friendships` |
| `storage.objects` policy for `visit-photos` (policy edit) | Allow friends to actually fetch a shared photo's bytes | — | N/A | New select path for accepted friends of a visibility-eligible visit, or move to signed-URL-via-RPC (§3.6) | — | `friendships`, `visits.visibility` |
| `wishlist_read` RLS (policy edit, no column change) | Tighten to owner-only | — | N/A | Removes the `profile_is_visible()` public-read path (§3.4) | none | none |
| `event_attendance` (new table) | "Going" + attendance visibility | `status='going'`, `visibility='friends'` | N/A (no existing data) | Owner-or-friends read, owner-only write | `unique(event_id,user_id)`; `user_id` | `events`, `profiles`, `friendships` |
| `profiles.username` population + signup fix | Fix `handle_new_user()` reading a field signup never sets (§1.1, pre-existing bug) | — | Existing null-username profiles need a one-time prompt/backfill flow (product decision, not schema) | none | already unique-indexed | none |

**Not recommended in this pass**: dropping `follows`, `profiles.is_public`, or `photos.is_public` — all three can simply stop being referenced by new RLS/UI without a destructive migration; removing them outright is a later cleanup with no MVP urgency.

---

## 10. Migration sequence

Derived from actual dependencies above, not the task's own example ordering (which this mostly confirms, with one reordering: the friendship-table fix belongs before *any* visibility work, since visits/photos visibility policies need `friendships` to exist to reference it):

1. **`friendships` table + RLS + RPCs** (§2) — foundational; nothing else in this document can be built without it existing first. Also: fix the `handle_new_user()`/signup username gap (§1.1) in the same pass, since friend discovery depends on real usernames existing.
2. **`profiles.include_in_community_stats`** (§5.2) — trivial, independent, can ship anytime before the aggregate RPCs need it.
3. **`visits.visibility` + RLS rewrite** (§3.2, §7.3) — depends on `friendships` existing (step 1).
4. **`wishlist_read` RLS tightening** (§3.4) — independent of the above, can ship in parallel with step 3.
5. **Photo visibility fix** — row RLS + storage RLS/signed-URL-RPC (§3.6) — depends on step 3 (`visits.visibility` must exist first).
6. **Friend profile / non-friend profile UI** (§4.1–4.2) — depends on steps 1 and 3 both being live.
7. **Community-aggregate RPCs** (§5, §7.1) — depends on steps 2 and 3.
8. **`event_attendance` table + RLS + RPC** (§6) — depends on `friendships` (step 1); independent of the visits work otherwise.
9. **UI consistency pass on Profile** (see `UI_CONSISTENCY_AUDIT.md`) — best done alongside step 6, since the Friends section needs rebuilding against the real schema regardless of visual state.
10. *(Deferred, not sequenced here)* geographic communities, trending, windowed most-visited, editorial content, verified stamps, venue claims — per `FUTURE_PRODUCT_ARCHITECTURE.md` and §8.2/§5.8 above.

---

## 11. Backward compatibility

Every recommendation is additive: new nullable-or-sensibly-defaulted columns, new tables, and policy edits that are real, reviewed changes but never destructive. Nothing here requires deleting, renaming, or destructively rewriting existing `visits`, `photos`, `wishlist`, `planned_trips`/`planned_venues`, `events`, `profiles`, or catalogue data. The one genuinely behavioral change (as opposed to purely additive) is the `visits`/`wishlist` RLS tightening (§7.3) — existing rows aren't touched, but their *effective read access* narrows for anyone who isn't the owner, which is the explicit, intended point of this entire spike, not an accidental side effect to be worried about.

---

## 12. MVP tester scope

### 12.1 MUST BUILD BEFORE TESTERS

- **Fix the pre-existing broken Profile screen** (§0.2) — Friends/Community Stats/tier sections currently reference dropped tables and will error for real users today, independent of any new work.
- **`friendships` table, RLS, and RPCs** (§2) — the actual foundation; without it there's no way to add a friend at all.
- **Working username** — populate at signup, searchable for friend discovery (§2.3, §9 row 8) — currently broken (§1.1).
- **`visits.visibility` + RLS rewrite** (§3.2, §7.3) — without this, every existing/new visit stays exposed under the current public-by-default model, directly contradicting the stated product direction before a single tester even arrives.
- **`wishlist_read` RLS tightening** (§3.4) — same reasoning, smaller surface.
- **Basic friend profile / non-friend profile distinction** (§4.1–4.2) — the concrete UI enforcement of "friends see more than strangers."
- **Blocking** (§2.4) — minimum safety for strangers interacting for the first time.
- **UI consistency on the screens this work touches** (Profile at minimum, per `UI_CONSISTENCY_AUDIT.md`) — a rebuilt Friends section is a natural moment to fix its visual system too, not a separate later task.

### 12.2 SAFE AFTER INITIAL TESTERS

- Community Intelligence aggregates and the underlying RPCs (§5, §7.1) — genuinely useful, but the product functions without it; ship once there's a cohort large enough to clear the §5.7 threshold for at least a few venues.
- Event attendance (§6) — same reasoning; useful once there's an event with a real cohort of testers who might attend it.
- Photo friends-visibility + the storage-layer fix (§3.6) — real but more involved than the text-only visibility work; can trail slightly behind visits.
- Friend activity feed (§4.3) — depends on friends + visit-visibility both being live and populated with real data first.

### 12.3 DO NOT BUILD YET

- Geographic communities (`communities`/`community_memberships`) — §8.2.
- Trending (§5.8), windowed most-visited (§5.5) — need real data volume to mean anything.
- Trip friends-visibility (§3.3) — trips stay private-only.
- Interested-vs-going distinction on attendance (§6.2).
- Reporting/moderation queue beyond basic blocking (§2.4).
- Verified stamps, venue claims/profiles, editorial content — already correctly deferred by `FUTURE_PRODUCT_ARCHITECTURE.md`; nothing in this spike changes that.

### 12.4 Recommended next implementation step

Fix the `friendships`/username/Profile-screen gap first (§12.1, items 1–3) — it's simultaneously the highest-severity pre-existing bug found during this audit *and* the literal prerequisite every other recommendation in this document depends on. Everything else in §12.1 follows directly from having a working, real friendship table to build against.

---

## 13. Security/privacy review — risk summary

Restated compactly from §7.4, ranked by severity given the current state:

1. **Highest, pre-existing, live today**: `visits`/`wishlist` public-by-default via `is_public` defaulting `true` — real user data is more exposed right now than the product intends, independent of any new feature.
2. **High, pre-existing, live today**: Profile screen Friends/tier sections crash against dropped tables — a functional bug, not a privacy one, but blocking for real testers.
3. **High, must get right when built**: friends-visibility RLS correctness — recommend one shared `is_friend()` helper reused everywhere, never three hand-rolled equivalents (§7.4).
4. **Medium, must get right when built**: the photo storage-layer/row-RLS mismatch (§3.6) — easy to ship half of and end up with a false sense of security.
5. **Medium, architectural, addressed by design**: aggregate re-identification — mitigated structurally by security-definer RPCs + the §5.7 threshold, not left to convention.
6. **Low, already correctly mitigated**: trip-location privacy (already owner-only), direct object access (already RLS-protected everywhere), friendship spoofing (mitigated by `auth.uid()`-keyed policies + RPCs).

---

## 14. What changes in `FUTURE_PRODUCT_ARCHITECTURE.md` (not edited — see below)

That document is not modified by this spike, per instruction. Summary of what a future revision of it should account for, for anyone reading both documents together:

- **§7 ("Community")** described geographic, membership-based communities as the *near-term* Community tab content (step 3 of its own §9.2 "safe to build later" sequence, ahead of most other social work). This document reprioritizes: **Friends is now the foundational piece that must come first**, with geographic communities pushed later (§8.2 above) — a genuine sequencing change, not just an addition.
- **A "Friends" concept did not exist anywhere in that document** — this is the primary net-new content this spike adds, not a revision of anything that document already said.
- **§1.8's naming-collision concern** ("Community" tab vs. "Community Rankings") is resolved differently than that document anticipated — see §8.1 above. That document suggested renaming the *existing* Rankings tab to avoid the future collision; this document's redefinition of "Community" as aggregate-plus-friends-plus-events actually reduces the collision rather than requiring the Rankings rename, since both now mean roughly the same thing.
- **§5 (Verified stamps) and §6 (Venue profiles)** are untouched by this spike's findings and remain exactly as that document describes them — no interaction between this document's recommendations and those.
- **§9's "MUST PREPARE NOW: Nothing"** finding is superseded for the specific area this spike covers: this document's audit *did* find required prep work (the friendship/username/Profile-screen gaps, §12.1) — but that finding is scoped to Friends/Privacy/Community specifically, not a correction to that document's own (still-accurate) conclusion about Events/Trips readiness.

---

## 15. Safety confirmation (this spike, 2026-08-13)

No code was changed. No database was written to — one read-only `information_schema.tables`/`information_schema.columns` query was run against the linked production project to verify the `friendships`/`user_tiers`/`tier_stats`/`profiles.tier` schema-drift finding in §0.2/§1.1; nothing was inserted, updated, deleted, or altered. No migrations were created. Nothing was staged. Nothing was committed. Nothing was pushed.

---

## 16. Step 2 implementation status — Privacy & Friend Content

**2026-08-14, implemented; deployed to production and physically reviewed/approved 2026-08-15.** See `SOCIAL_FOUNDATION_STEP_2_IMPLEMENTATION_REPORT.md` for the audit/build/test record and `SOCIAL_FOUNDATION_STEP_2B_DEPLOYMENT_REPORT.md`'s own preflight for the live production re-verification of this exact state. This section documents what was actually built and is now live, superseding §3.2/§3.4a/§3.6/§7.3's own recommendations with the as-implemented shape (the two never materially diverge except where noted).

- **VISITS**: `visits.visibility text not null default 'private' check (in ('private','friends'))`. Every existing row backfilled to `'private'` by the column default itself (no separate UPDATE). No public tier exists or is planned. `visits_read` rewritten to `owner OR (visibility='friends' AND is_friend(owner))`, narrowed from `anon, authenticated` to `authenticated` only (anon could never satisfy either clause anyway). Owner INSERT/UPDATE/DELETE untouched.
- **RATINGS/COMMENTS**: no separate visibility field of any kind — they are columns on the visit row itself and inherit `visits_read` automatically, exactly as §3.2 already recommended.
- **PHOTOS**: `photos_read` rewritten to `owner OR (visit_id is not null AND parent visit is friends-visible AND viewer is_friend(visit owner))` — `photos.is_public` is no longer read by this policy at all. **Storage**: a new additive `storage.objects` SELECT policy (`visit_photos_read_friends`) joins through `public.photos.storage_path = name` to the same parent-visit check, rather than parsing `(storage.foldername(name))[2])::uuid` (which would need an explicit format guard before casting to avoid throwing on any malformed path). The bucket stays private; the app still resolves images via `PhotoRepository.resolveDisplayUrls`'s existing signed-URL call, unchanged — Postgres RLS (not a new RPC) is the enforcement point, per §3.6's own preferred option. The pre-existing owner-only policies (both the migration-created ones and four dashboard-created duplicates found during this step's own audit — see the implementation report) are left exactly as they are; RLS policies OR together, so this is purely additive.
- **WISHLIST**: `wishlist_read` rewritten to `owner OR is_friend(owner)` — no `wishlist.visibility` column exists or is planned, per the explicit final MVP decision (supersedes this document's own earlier, more cautious §3.4 "private only" recommendation, itself already superseded by §3.4a's "auto-visible to friends" direction — this section is that direction, implemented).
- **TRIPS**: `planned_trips`/`planned_venues` policies are untouched — confirmed by construction, not just by testing (the migration file contains zero references to either table).
- **NON-FRIEND / PENDING / DECLINED / BLOCKED**: identity-only, unchanged from Step 1 — Friend Profile only renders VISITED/WISHLIST when `relationshipStatus == accepted`; every other state renders exactly as Step 1 already built it.
- **Live authorization**: every check above is a live subquery against `public.friendships` via the Step 1 `is_friend()` helper — reused as the single shared predicate everywhere, never duplicated. An unfriend or a block takes effect on the very next read, with zero content rows ever rewritten — verified directly (not assumed) against a local Postgres instance: block correctly denied access even after the underlying visit was re-marked `friends`-visible, proving the check is genuinely live rather than cached at grant time.

---

## 17. Step 2B implementation status — Friend Venue Navigation + Event Attendance

**2026-08-15, implemented, deployed to production, and physically reviewed/approved.** See `SOCIAL_FOUNDATION_STEP_2B_IMPLEMENTATION_REPORT.md` for the audit/build/test record and `SOCIAL_FOUNDATION_STEP_2B_DEPLOYMENT_REPORT.md` for the production deployment/verification record, including the least-privilege follow-up migration (`20260815130000`) that revoked an unintended `anon` EXECUTE grant on `get_event_attendance_count` discovered during that deployment.

### 17.1 Canonical venue-detail navigation from friend content

Friend Profile's VISITED and WISHLIST rows both now navigate to the exact same `RestaurantDetailScreen`/`HotelDetailScreen` reached from Explore/Passport — no `FriendRestaurantDetailScreen`/social wrapper of any kind was built or is planned. This works correctly with zero extra plumbing because every action on those canonical screens (Wishlist toggle, Add Visit, external links) already reads/writes only `Supabase.instance.client.auth.currentUser` — the current viewer's own data — regardless of how the screen was reached; a friend's own Wishlist/visits are never touched by opening their content this way. Event attendance follows the identical rule: a friend's GOING row navigates to the canonical `EventDetailScreen`, never a wrapper.

### 17.2 Event attendance model

New table `public.event_attendance`: one row per `(event_id, user_id)` (enforced by a real UNIQUE constraint, not application logic), a single legal `status` value `'going'` for MVP (removing attendance is a DELETE, mirroring how unfriending is a DELETE rather than a `friendships.status` value), and a `visibility` column reusing the exact `private | friends` shape `visits.visibility` already established. INSERT/UPDATE/DELETE are plain client-side ownership writes (matching `wishlist`'s pattern), not RPC-mediated — there is no multi-party state machine here the way there is for `friendships`.

### 17.3 Attendance privacy

Default **`friends`**, not `private` — a deliberate divergence from `visits.visibility`'s own `private` default, reasoned through explicitly rather than copied by habit: an event is already fully public catalogue content (`events` is public-read, seeded server-side), so "I'm going to a public festival" is a materially lower-sensitivity disclosure than a personal dining rating on a specific night. Defaulting to friends-visible lets the feature work for testers with zero extra opt-in friction for something this low-stakes; a user can still mark a specific event's attendance `private`. No dedicated visibility-toggle control was built into the Event Detail UI for this step (the "I'm going" action always writes `friends`) — the schema/RLS/repository layer fully supports `private` regardless, so a future toggle needs no new migration, matching the task's own explicit "recommend a safer default rather than overbuilding the interaction" guidance. `event_attendance_select` enforces: owner always; an accepted friend only when the row is `friends`-visible; everyone else (stranger, pending, declined, blocked) never — the identical live-subquery-via-`is_friend()` pattern as visits/wishlist/photos, so unfriending or blocking revokes attendance visibility on the very next read.

### 17.4 Future aggregate attendance seam

A narrow, read-only `get_event_attendance_count(event_id)` RPC was implemented (not deferred — judged straightforward enough to include per the task's own stated preference) but is **not wired into any UI in this step**. It returns the exact count once ≥5 unique attendees exist (the same minimum-aggregation threshold §5.7 already established for Community Intelligence), `NULL` below that — never row-level data, never a specific small number that could make one attendee identifiable. This is deliberately the full extent of "Community" work in this step: no feed, no public attendee list, no Community tab, no geographic communities — those remain exactly as deferred as §8/§12.3 already recorded.
