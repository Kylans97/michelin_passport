# Community / Friends UX — Architecture & Step 1

This document covers the social-discovery feature (`lib/features/friends/`):
its current data architecture, the privacy model it depends on, and the
Community/Friends UX Step 1 redesign — what changed, what stayed exactly as
it was, and what's deliberately deferred.

It does not duplicate the generic database architecture doc
(`docs/Architecture/DATABASE_GUIDE.md`) — only the tables/policies relevant
to social reads are covered here.

## 1. Screen → repository → table map

| Screen | Repository | Backing |
|---|---|---|
| `FriendsScreen` (Friends + Requests tabs) | `FriendshipRepository` | RPCs: `get_friends`, `get_incoming_friend_requests`, `get_outgoing_friend_requests` |
| `AddFriendScreen` | `FriendshipRepository` | RPC `search_profiles` |
| `FriendProfileScreen` | `FriendshipRepository`, `VisitedRepository`, `WishlistRepository`, `EventAttendanceRepository` | RPC `get_profile_identity` + direct-table reads on `visits`/`wishlist`/`event_attendance`, gated entirely by RLS |
| `FriendVisitedListScreen` / `FriendWishlistListScreen` / `FriendGoingListScreen` ("View all") | same repositories as above | independent, fresh fetch per screen — never cached data passed through navigation |

`VisitedRepository.loadPassportVenues(userId)` and
`WishlistRepository.loadWishlistVenues(userId)` are the **exact same
methods** the owner's own Passport/Wishlist screens call — there is no
"friend" variant. Authorization is entirely delegated to Postgres RLS (see
§2). This is deliberate: the app never has a second code path for "my data"
vs. "a friend's data," so there is no way for that split to drift out of
sync with the database's own access rules.

## 2. Privacy model (current, unchanged by Step 1)

| Table | Who can read a row that isn't their own | Governing column |
|---|---|---|
| `profiles` | anyone, if `is_public = true` (default) | `is_public` — discoverability only, **not** activity visibility |
| `visits` | an accepted friend, only if that visit's own `visibility = 'friends'` | `visits.visibility` (default `'private'`) |
| `photos` | an accepted friend, only if the photo is attached to a `visibility = 'friends'` visit | derived from the parent visit, not `photos.is_public` (that column still exists but is no longer read by any policy) |
| `wishlist` | **any** accepted friend, unconditionally — no per-item or per-user opt-out exists | none |
| `event_attendance` | an accepted friend, only if that row's `visibility = 'friends'` (the default) | `event_attendance.visibility` |

The shared predicate every friends-visibility policy above uses is
`public.is_friend(other_user_id)` — a live, uncached `SECURITY DEFINER` SQL
function that checks for a `friendships` row with `status = 'accepted'`
between the two users. Because it's a plain subquery re-evaluated on every
read, **unfriending or blocking takes effect on the very next query** — there
is no caching layer to invalidate.

Blocking: `block_user` (RPC) sets `friendships.status = 'blocked'` on the
existing row (or inserts one). Since `is_friend()` only returns true for
`status = 'accepted'`, a blocked pair is immediately excluded from every
friends-visibility policy above, and `search_profiles`/`get_profile_identity`
also exclude blocked-either-direction pairs. There is currently no "unblock"
RPC — this was a deliberate exclusion from the original Social Foundation
scope, not something Step 1 changes.

Trips (`planned_trips`/`planned_venues`) are never shown on Friend Profile —
that RLS remains strictly owner-only and Step 1 does not touch it.

**Nothing above changed in this step.** Step 1 is UI-only; every visibility
rule, RPC, and table listed here is exactly as it was before.

## 3. Community vs. Friends naming — decision

The task brief for this step asked whether the visible label should move
from "Friends" to "Community." **It stays "Friends" for this step.**

"Community" is already in active use elsewhere in the app for an unrelated
concept — `RankingsScreen`'s "Community" tab (aggregate/public restaurant
rankings, a completely different data source from the social graph). Renaming
the social feature's own label to "Community" right now would create a
product-vocabulary collision between two different meanings of the word in
the same app. Resolving that collision (e.g. renaming the Rankings tab)
wasn't in scope for this step, so — per the task's own instruction to
"document it as the intended future information architecture and leave
current navigation naming intact" when a rename would ripple broadly — the
label stays "Friends," and this note is that documentation. A future step
can revisit "Community" as the umbrella term once the Rankings naming
collision is deliberately resolved alongside it.

## 4. Community/Friends landing hierarchy

`FriendsScreen`: forest-green header (back arrow, add-friend action,
"Friends" title, Friends/Requests tab bar) over an ivory body — the same
canvas-split composition established by Guides' catalogue headers. The
empty state (no friends yet) is the one place in this feature that
deliberately keeps a full illustrated-copy treatment (task §43): "Find
friends and discover the places they loved" + a primary "Find friends" CTA
that opens `AddFriendScreen` directly, rather than a bare line of text.

## 5. Friend Profile hierarchy

```
PROFILE HERO (forest-green)
  back arrow · avatar · display name · @username · relationship action
↓
VISITED   (ivory, omitted entirely if empty)
↓
WISHLIST  (ivory, omitted entirely if empty)
↓
GOING     (ivory, omitted entirely if empty)
```

The hero and the activity sections both live inside **one** scrollable —
never a fixed hero with a separately-scrolling body. A user-generated
display name can be arbitrarily long, and for a non-friend/pending profile
there is no activity content below the hero to absorb overflow, so the hero
must be able to scroll away rather than being pinned. `test/
friend_profile_hero_test.dart`'s "long display name at 320px" case exists
specifically to guard this.

A follow-up safe-area polish pass changed the outer `Scaffold.
backgroundColor` from ivory to forest-green (fixing an iOS status-bar strip
that read as an ivory gap above the hero — the same fix applied to Guides'
`GuideCatalogueLayout` and to `FriendsScreen`) and, as part of the same
pass, swapped the scrollable itself from a plain `SingleChildScrollView` +
`Column` to a `CustomScrollView` with a `SliverFillRemaining
(hasScrollBody: false)` for the ivory content area. The reason: with the
Scaffold now forest-green everywhere, the ivory area needs to explicitly
paint itself rather than relying on the Scaffold's background, and it also
needs to visually reach the bottom of the screen when content is short
(a non-accepted profile, or a friend with little activity) — something a
plain `Column`+`Expanded` can't do without reintroducing the exact
overflow risk this section's opening paragraph describes.
`SliverFillRemaining` gives the ivory area a *minimum* height equal to
whatever's left in the viewport while still letting the whole page grow
and scroll normally if the hero or the activity sections end up taller
than the screen.

**Section omission** (task §18): VISITED/WISHLIST/GOING each render nothing
at all — no eyebrow, no "nothing here" line — once their future resolves to
zero items. A quiet new friend's profile is just the hero, not three empty
lines. The same omission also applies on a load *error* for a section
(rather than surfacing "Could not load…" inline in the middle of the
profile) — a deliberate simplification: there's no retry affordance wired to
an individual section anyway, and a silently-missing section reads calmer
than an error line sitting next to unrelated content.

**Preview limit + "View all"**: one shared constant
(`_previewLimit = 4` in `friend_profile_screen.dart`) caps every section's
preview, with a `"View all"` trigger (title left / "View all" right — one
pattern reused identically by all three sections) appearing only when the
real count exceeds it. "View all" opens the smallest possible dedicated
screen (`FriendVisitedListScreen` / `FriendWishlistListScreen` /
`FriendGoingListScreen`, all in `friend_activity_list_screen.dart`) — each
does its own fresh, independent fetch rather than receiving cached data
through navigation, matching this feature's existing "no caching, always a
live RLS-gated read" posture. There's no search/filter on these list
screens; a friend's full activity list is expected to stay short enough
that it isn't needed yet.

## 6. VISITED — what changed and why

Before this step, `FriendVisitTile` was a boxed card (dark canvas,
`brandGreenLight` fill, `subtleBorderDark` border) that also embedded the
visit's free-text notes and a horizontal photo strip (`FriendPhotoStrip`) —
effectively a condensed visit-detail view repeated once per row.

Step 1 replaces it with the same compact, hairline-separated editorial row
language Guides established for its own venue rows: a 52×52 `VenueThumbnail`
leading slot, the venue name with its Michelin recognition inline
(`StarRow`/`KeyRow`, via a `WidgetSpan` so it wraps together with a long
name rather than ever being pushed off-screen), a rating+date metadata line,
then city + flag.

**Notes and the photo strip are no longer shown on this row.** This is a
deliberate simplification, not a privacy change — RLS still grants exactly
the same read access to a friend's notes/photos as before (see §2); nothing
about who can query what changed. The reasoning: the task brief was explicit
that VISITED should be "a concise preview... not full visit details," and
repeated the "no résumé" instruction throughout (§9, §10, §22). A single-line
rating (`8/10`) is enough to convey "this venue mattered enough to log," and
free-text commentary + a photo strip reads as exactly the kind of "full
visit-detail" content the brief asked to keep out of a scannable discovery
list.

This does mean a friend's notes/photos aren't currently reachable from
*anywhere* in the UI (there was no separate friend-visit-detail screen
before this step either, and Step 1 doesn't add one — see §11 of the task
brief's own guidance against building duplicate venue-detail architecture).
**This is the one deliberately deferred piece of previously-visible
content** — a future step could reintroduce it as its own lightweight
"friend visit detail" surface if real usage shows the loss matters, without
touching RLS at all (the data access is already there).

`FriendPhotoStrip` itself was deleted (`lib/features/friends/widgets/
friend_photo_strip.dart`) as a result — it had exactly one caller, and that
caller no longer exists.

## 7. WISHLIST — what changed

Same visual treatment as VISITED, minus the metadata line (a wishlist entry
has no date/rating to show). Answers "where does this person want to go?"
using only venue name, recognition, city, and flag — no technical labels.
Never editable by the viewer (no remove/plan action) — unchanged from
before.

## 8. GOING — what changed

Same editorial row language. Unlike Restaurant/Hotel, `Event` already
carries a real `imageUrl` field, so `FriendGoingTile`'s `VenueThumbnail` is
already fully photo-ready today, not just seam-ready. Country is shown as
plain text (city, country code) — deliberately no flag glyph, since `Event`
has no canonical `flagEmoji` field the way `Restaurant`/`Hotel` do, and one
must never be hardcoded per-row. Still upcoming-events-only (unchanged;
`EventAttendanceRepository.getFriendUpcomingAttendance` already filtered to
future/current before this step).

## 9. Canonical navigation (unchanged, reconfirmed)

Every venue row → `RestaurantDetailScreen`/`HotelDetailScreen`. Every event
row → `EventDetailScreen`. There is no `FriendRestaurantDetail`/
`FriendHotelDetail`/`FriendEventDetail` and Step 1 does not introduce one —
`openFriendVenue`/`openFriendEvent` (now exported from
`friend_profile_screen.dart` so `friend_activity_list_screen.dart` shares
the exact same navigation logic rather than a second copy of it) are the
only two navigation entry points social rows ever call.

## 10. Venue row reuse decision

`GuideVenueCard` (`lib/features/guides/widgets/guide_venue_card.dart`) has
almost exactly the row shape this feature needed — but it lives inside the
Guides feature's own `widgets/` folder, and this codebase has no existing
precedent of one feature importing another feature's feature-scoped
widgets (only `core/widgets/` is shared across features). Promoting it to
`core/widgets/` and renaming it would have meant touching Guides' own
already-shipped, physically-reviewed screens and tests purely to serve a
new consumer — a real risk for a purely cosmetic gain.

Per the task brief's own instruction ("do NOT force reuse if the semantics
are wrong... prefer a small social-specific shared row if needed"), Step 1
instead rebuilt the same visual language directly in
`FriendVisitTile`/`FriendWishlistTile`/`FriendGoingTile`, reusing the
*design tokens* (same `VenueThumbnail`, same taupe/0.75px/55%-alpha hairline
value `GuideVenueCardDivider` uses, same `CsTypography` roles) without
sharing widget *code* across the feature boundary. If a third feature needs
this exact row shape later, that's the point at which promoting it to
`core/widgets/` (with a proper rename) becomes worth the Guides-touching
risk.

## 11. Gold audit

`grep -rn "AppColors\.\(gold\|starFilled\|goldLight\|accent\)\b" lib/features/friends/`
returns nothing. `StarRow`/`KeyRow` (used only for genuine Michelin
star/Key recognition inline with a venue name) remain the only gold
producers anywhere in this feature — the relationship action ("Friends"
label, Accept button), the avatar, loading spinners, and every hairline are
all forest-green/ivory/taupe.

## 12. Social venue/event intelligence — feasibility audit (all deferred)

The task brief asked for an audit of four potential future signals before
building any of them. None are implemented in Step 1 — see task priority
P2 ("do not let P2 features destabilize P0"). Findings, for a future step:

**"X friends visited" (Restaurant/Hotel Detail).** Feasible with zero new
RPCs or migrations. `visits_read` RLS already restricts a `SELECT` on
`visits` to the caller's own rows plus friends'
`visibility = 'friends'` rows — so
`select count(*) from visits where entity_type = ? and entity_id = ? and user_id != auth.uid()`
already returns exactly "how many of my friends visited this venue," with
no N+1 and no risk of leaking a non-friend's data (RLS filters it before the
count ever sees it). Same reasoning applies to
**"X friends want to visit"** against `wishlist` (whose RLS is even simpler
— unconditional friend access, no visibility column to check).

**"Friends going" (Event Detail).** Same pattern against `event_attendance`.
Note this is a *different* concept from the existing
`get_event_attendance_count` RPC (defined in `20260815120000_social_
foundation_step2b_event_attendance.sql`, still deliberately unwired into any
UI) — that RPC returns a *global*, k-anonymized count (null unless ≥5
people total are going), useful for "this event is popular," not "my
friends are going." Both could coexist; they answer different questions.

**"Friends score" (average rating).** Feasible to *query* the same way as
the count signals above (`avg(rating)` instead of `count(*)`), but the task
brief was explicit not to invent the product definition silently, and a
real ambiguity exists: if a friend visited the same venue three times with
three different ratings, does "friends score" average all three visits, use
only the latest, or something else? This needs an actual product decision
before implementation, not an architecture decision — flagged here rather
than guessed at.

None of the four require a migration, a new RPC, or any RLS change — the
existing policies already compute exactly the right answer for a
straightforward `count`/`avg` query. The only real blocker for three of the
four is scope discipline (P0 first); the fourth (Friends score) additionally
needs a product-definition decision.

## 13. What Step 1 implements vs. defers

**Implemented:**
- Forest-green hero / ivory body composition for `FriendsScreen`,
  `AddFriendScreen`, `FriendProfileScreen`, and the three "View all" list
  screens.
- Photo-ready `VenueThumbnail`-based rows for VISITED/WISHLIST/GOING,
  replacing the previous boxed-card treatment.
- Section omission when empty; shared preview limit + "View all" pattern.
- Non-gold relationship action, avatar, loading states throughout.
- Discovery-oriented empty state for a friendless account.
- Fixed a latent hero-overflow risk (see §5) uncovered while building this
  step's own responsive tests.

**Deferred (see §12):** "X friends visited," "Friends score," "X friends
want to visit," "friends going" on Event Detail. "Community" as the visible
label (see §3). Per-visit notes/photos on Friend Profile (see §6) — data
access unchanged, just not currently surfaced in any screen.

**Explicitly not built, per the task brief:** activity feed, "X visited Y"
timeline, likes/comments/reactions, posts, follower-count vanity metrics,
gamified badges, DMs.

## 14. Step 1A — Friends Going on Event Detail

Implements the "Friends going" signal §12 scoped out of Step 1. Zero
migrations, zero new RPCs — the feasibility audit's finding held.

**Query path.** `EventAttendanceRepository.getVisibleAttendeeUserIds
(eventId)` does a plain, unfiltered `select user_id from event_attendance
where event_id = ?`. `event_attendance_select` RLS
(`user_id = auth.uid() or (visibility = 'friends' and is_friend(user_id))`)
already decides exactly who belongs in the result — the repository never
re-derives that filter client-side. This is the *event → its visible
attendees* direction, the inverse of the existing
`getFriendUpcomingAttendance` (*one friend → their events*); the two are
not interchangeable.

Those ids are resolved against the caller's own already-fetched
`FriendshipRepository.getFriends()` list (one call, not one query per
attendee — no N+1) by the pure `friendsGoingToEvent` function
(`lib/features/events/friends_going_view_model.dart`), which:
- excludes the viewer's own id (presentation only — RLS is still the
  actual authority; the viewer's own state is already shown via the
  "I'm going" button),
- silently drops any id with no matching entry in `friends` (defensive;
  should not occur if RLS is behaving as documented),
- sorts alphabetically, case-insensitive, by `Friendship.label`.

**Distinct from `get_event_attendance_count`.** That RPC (§12) returns a
global, identity-free, k-anonymized number and is not called, modified, or
repurposed anywhere in this feature — FRIENDS GOING only ever shows named
friends, never a total headcount.

**Visibility gating.** The section is fetched and shown only when
`canAttendEvent(event)` is true (upcoming/current, not cancelled — the
same gate `EventGoingButton` already uses) and a friend is signed in;
omitted entirely (not "0 friends going") when the resolved list is empty,
still loading, or the query errors — the rest of Event Detail is
unaffected either way.

**UI.** `EventFriendsGoingSection` sits directly under `EventGoingButton`,
before ABOUT. Shows up to 3 friends (`IdentityRow` — avatar, name,
`@username`, no counts/scores/timestamps); a fourth-plus triggers "View
all" → `EventFriendsGoingListScreen`, a new screen (not
`friend_activity_list_screen.dart`'s shell, which predates the UI Polish
safe-area fix) built with the corrected forest-green/AnnotatedRegion
pattern from the start. Both tap targets push the canonical
`FriendProfileScreen` — no event-specific friend detail screen.
