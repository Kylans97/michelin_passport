# EVENTS V2 STEP 8A — PERSONALIZED EVENT RANKING — PRE-FINAL

Implements exactly the MVP recommended by
`EVENTS_V2_STEP_8_PERSONALIZED_DISCOVERY_AUDIT.md`: one unified Events list,
no section stack, no duplicate cards, at most one visible relevance reason
per card. No schema, RLS, or production-data changes. Not staged, not
committed, not pushed.

## PRODUCT CONTRACT

Events landing (`EventsScreen`) is still exactly one `SliverList`, driven by
the same `EventsRepository.loadEvents(...)` query as before (unchanged: same
filters, same chronological `start_at` ordering). Personalization is a
ranking layer applied on top of that list's results, never a second query
and never a second set of sections. A cold-start user (zero
trips/friends/follows/popularity) sees the identical chronological list the
screen already rendered pre-Step-8A — see "Cold Start" below.

## DOMAIN MODEL

- `lib/models/event_relevance_reason.dart` — `EventRelevanceReasonType`
  enum (`trip, friendGoing, followedHost, friendInterested, popular`, in
  hierarchy order — the enum's own `.index` IS the ranking tier) and a
  sealed `EventRelevanceReason` hierarchy (`TripRelevanceReason`,
  `FriendGoingRelevanceReason`, `FollowedHostRelevanceReason`,
  `FriendInterestedRelevanceReason`, `PopularRelevanceReason`), each with a
  typed `label` getter producing the exact card copy. Pure Dart, no Flutter
  import, matching every other `lib/models/` file.
- `lib/models/event_discovery_item.dart` — `EventDiscoveryItem(Event event,
  EventRelevanceReason? primaryReason)`.
- `lib/features/events/event_discovery_ranking.dart` — `EventRelevanceSignals`
  (the per-event input bundle: booleans/counts/optional display strings for
  all five signal types) and the pure functions `primaryReasonFor(signals)`
  and `rankEventsForDiscovery(events, signalsByEventId)`.

No arbitrary strings anywhere in the ranking path — every decision point
switches on the closed `EventRelevanceReasonType`/`EventRelevanceReason`
types.

## RELEVANCE HIERARCHY

Implemented exactly as specified: Trip > Friend Going > Followed Host >
Friend Interested > Popularity > Chronology (fallback, never a visible
reason). `primaryReasonFor` checks the five signals in that fixed order and
returns the first match; `rankEventsForDiscovery` sorts by
`EventRelevanceReasonType.index` (an absent reason sorts last, past the five
real tiers), then `Event.startAt` ascending, then `Event.id` ascending as a
purely mechanical final tiebreaker. See
`test/event_discovery_ranking_test.dart` for the full hierarchy proof
(every adjacent-tier pairing, same-tier chronological ordering, and
determinism under a repeated call).

## TRIP MATCH

`EventDiscoveryService._safeTripSignals` calls the canonical
`eventsMatchingTrip` (`lib/models/event_trip_match.dart`) against each of
the user's trips (`PlannedTripsRepository.loadTrips`) — no second matching
definition was created. Visible copy: `"During your {city} trip"` when the
trip has a city, else `"During your upcoming trip"`
(`TripRelevanceReason.label`). Trip data itself is never sent to analytics
(see Analytics below).

## FRIEND GOING

Resolved via the existing Step 7 `friendsGoingToEvent` pure function against
a single shared `FriendshipRepository.getFriends()` call and the new
batched `EventAttendanceRepository.getVisibleUserIdsForEvents(eventIds,
status: going)` (one query for ALL events, not one per event — see Data
Loading). Copy reuses the existing singular/plural convention: `"Ward is
going"` / `"2 friends are going"`.

## FOLLOWED HOST

New `lib/data/repositories/event_host_follow_repository.dart`
(`EventHostFollowRepository.getFollowedHostEventNames`) composes: the
caller's own followed restaurant/hotel/private-chef ids (3 queries against
`follows_*`), then the matching `event_restaurants`/`event_hotels`/
`event_chefs` rows for (followed ids × requested event ids) (up to 3
queries), then batched name lookups against `restaurants_full`/
`hotels_full`/`private_chefs` (up to 3 queries). The is_host/is_venue
qualification decision is a separate, pure, unit-tested function —
`eventHostFollowQualifies` in `lib/features/events/
event_host_qualification.dart` — deliberately NOT baked into the SQL filter,
so venue-only and participant-only exclusion is independently provable (see
`test/event_host_qualification_test.dart`). No `SECURITY DEFINER` needed:
`event_restaurants`/`event_hotels`/`event_chefs` already have `qual: true`
SELECT RLS, and `follows_*` is already scoped to `auth.uid()`. Copy:
`"Hosted by {name}"` when a name resolves, else the privacy-safe `"From a
place you follow"`.

## FRIEND INTERESTED

Same architecture as Friend Going, resolved a second time against
`EventIntentStatus.interested` (the new batched query is status-parametric,
so this is the same one method, called twice). Ranks below Trip/Friend
Going/Followed Host, above Popularity, exactly per §7. Copy: `"2 friends are
interested"`.

## POPULARITY

`EventSocialRepository.getGoingMemberCount` (Step 7's capped RPC) is called
once per event that reached the popularity check WITHOUT a stronger reason
already assigned — never for every event unconditionally. Threshold: **5**,
reusing the exact precedent number the sibling
`get_event_attendance_count` function already established for its own
k-anonymity cutoff (that function itself is not called or modified — only
its number is reused, a principled reuse rather than an arbitrary new
constant). Today's real Going counts (0–1) sit below this, so "Popular"
will rarely surface yet — accepted per §8 ("do not fake popularity").

## CHRONOLOGY

Unchanged: `Event.startAt` (absolute instant) drives both the base query's
`order('start_at')` and the ranking function's within-tier sort. No
device-timezone logic was touched or reintroduced.

## DEDUPLICATION

`rankEventsForDiscovery` iterates `events` exactly once, producing exactly
one `EventDiscoveryItem` per input `Event` — there is no code path that can
emit an event twice or drop one. Proven in
`test/event_discovery_ranking_test.dart` ("every event appears exactly once
regardless of signal strength").

## EVENT CARD UX

`EventCard` (`lib/features/events/widgets/event_card.dart`) gained one new
optional `reason` parameter and one new private `_RelevanceReasonRow`
widget, rendered between the location line and the free-entry badge only
when `reason != null`. One consistent visual treatment for all five
reasons: a 13px brand-green Material icon + a 12px brand-green semibold
label, single line with ellipsis overflow — no per-reason color families,
no emoji, no badge chrome. Existing metadata (name, date, location,
FREE ENTRY / CANCELLED badges) is untouched. See
`test/event_card_test.dart` for: no-reason baseline unchanged, exactly one
of five reasons rendered per case, never more than one reason icon
simultaneously, no gold anywhere, no overflow at 320px width or 1.6x text
scale.

## DATA LOADING

Per discovery-list load (N events, signed-in user), the query count is
**bounded and does not scale per event**:

| Signal | Queries | Scales with N events? |
|---|---|---|
| Base Events list | 1 (unchanged) | No |
| Trips | 1 (`loadTrips`) | No — matching is pure Dart against the already-fetched Trip list |
| Friends list | 1 (`getFriends`, shared across Going + Interested) | No |
| Friends Going | 1 (new batched `getVisibleUserIdsForEvents`, `event_id IN (...)`) | No |
| Friends Interested | 1 (same method, `status: interested`) | No |
| Followed Host | ≤6 (3 followed-id reads + ≤3 bounded host-link reads) | No — bounded by follow-list size × requested events, not by N alone |
| Followed-host names | ≤3 | No |
| Popularity | 1 RPC per event **still needing a reason** | **Yes — see flag below** |

**Explicit scalability flag (§14/§34):** `get_event_going_member_count` has
no batched/array variant. Popularity is therefore the one signal that is
O(k) in the number of events reaching the popularity check (k ≤ N, and k
shrinks for any user with real Trip/Friend/Follow personalization, since
those events skip the check entirely). At today's 4-event catalogue this is
free; per the task's explicit instruction, this is flagged rather than
silently building a new batched RPC — a future
`get_events_going_member_counts(uuid[])` would remove this the same way
`getVisibleUserIdsForEvents` removed the Friends Going/Interested N+1, but
that migration is NOT built here (§23 — no schema changes in this task).

## FAILURE ISOLATION

Every signal source in `EventDiscoveryService.rankForDiscovery` has its own
`try/catch` (`_safeTripSignals`, `_safeFriends`,
`_safeVisibleUserIdsForEvents` ×2, `_safeFollowedHostNames`, and each
individual popularity RPC call inside `_safePopularEventIds`) collapsing to
an empty/false result on failure — never a rethrow. `EventsScreen
._fetchDiscoveryList` wraps the whole ranking call in one more top-level
`try/catch` as defense-in-depth, falling back to the plain chronological
`EventDiscoveryItem` list built directly from the already-successful base
Events query. The base Events query itself is unchanged from before Step
8A — its own existing error UI (`"Could not load events"`) is untouched.

## ANALYTICS

No new taxonomy. `EventsScreen._openEvent` now fires the previously-unused
`AnalyticsEvent.eventOpened` and passes `sourceContext` derived from the
opened item's primary reason, reusing existing
`AnalyticsSourceContext` values: `trip → tripDestination`, `friendGoing →
friendSignal`, `followedHost → followedHost`, `friendInterested →
friendSignal`. **Popularity intentionally maps to `null`** — no existing
`AnalyticsSourceContext` value cleanly represents "the event has broad
platform popularity" (`featured` already carries a distinct editorial
meaning), and forcing a mismatched fit was judged worse than omitting
`sourceContext` for that one case; a chronological/no-reason open also
omits `sourceContext`. `EventDetailScreen` already accepted
`sourceContext` as a constructor parameter before this task (Step 3/7) —
this task is the first call site to actually populate it. No friend
names/ids, trip names/details, or followed-entity names are ever sent — only
the closed enum values.

## PRIVACY

- **Follow**: `EventHostFollowRepository` only ever reads the caller's own
  `follows_*` rows (RLS-enforced regardless of the `userId` parameter); the
  card's own-screen copy ("From a place you follow" / "Hosted by X") is
  never shown on any other user's surface.
- **Trip**: Trip matching only ever runs against the signed-in caller's own
  `loadTrips(userId)`; no friend-facing surface receives another user's
  Trip reason. Trip RLS untouched.
- **Friend**: Both Friend Going and Friend Interested route entirely through
  Step 7's existing `event_attendance_select` RLS boundary and the existing
  `friendsGoingToEvent` resolution function — no second friendship
  implementation.

## PERFORMANCE

See Data Loading above for the full table. Summary: 4 fixed-count query
groups (Events, Trips, Friends-list, Friends-Going/Interested) plus one
bounded Followed-Host group (≤9 queries regardless of N), plus one O(k)
popularity group explicitly flagged as the one gap remaining for a much
larger catalogue. Nothing here re-fetches per event except the flagged
popularity RPC.

## COLD START

`EventDiscoveryService.rankForDiscovery` short-circuits to
`[EventDiscoveryItem(event: e) for e in events]` (no signal sources even
attempted) whenever `userId == null` or `events.isEmpty`; for a signed-in
user with zero trips/friends/follows/popularity, every signal source
independently resolves to empty/false and `rankEventsForDiscovery` collapses
to plain chronological order (proven directly in
`test/event_discovery_ranking_test.dart`'s "no signals at all" group). No
"For You"/"Recommended"/"Because..." UI exists anywhere in this
implementation — there was never a second UI surface to hide.

## REGRESSION

`flutter analyze`: 0 issues. `flutter test`: 1401/1401 passing (1367
baseline + 34 new). No file outside
`lib/features/events/`,`lib/models/event_*.dart`,
`lib/data/repositories/event_*repository.dart` was modified — Trips,
Follow, Passport, My Map screens are untouched by this diff; Interested,
Going, Friends Going, Friends Interested, member count, and Event Detail
all still route through the exact same underlying repositories/RLS as
before, exercised indirectly by the full test suite passing unchanged.

## DATABASE

Zero migrations, zero schema changes, zero RLS changes, zero production
writes — confirmed by `supabase migration list --linked` (local list
matches remote exactly, no new entries) and `supabase db push --linked
--dry-run` (`"Remote database is up to date."`).

## VALIDATION

- `dart format --set-exit-if-changed .` — clean (0 files changed).
- `flutter analyze` — 0 issues.
- `flutter test` — 1401 passed, 0 failed.
- `supabase migration list --linked` — local/remote identical.
- `supabase db push --linked --dry-run` — up to date, no pending migrations.
- `git status --short` / `git diff --cached` — see Git below.

## FILES

New:
- `lib/models/event_relevance_reason.dart`
- `lib/models/event_discovery_item.dart`
- `lib/features/events/event_discovery_ranking.dart`
- `lib/features/events/event_host_qualification.dart`
- `lib/features/events/event_discovery_service.dart`
- `lib/data/repositories/event_host_follow_repository.dart`
- `test/event_discovery_ranking_test.dart`
- `test/event_host_qualification_test.dart`
- `test/event_card_test.dart`
- `docs/Architecture/EVENTS_V2_STEP_8A_PERSONALIZED_RANKING_PRE_FINAL.md` (this file)

Modified:
- `lib/data/repositories/event_attendance_repository.dart` (added
  `getVisibleUserIdsForEvents`)
- `lib/features/events/widgets/event_card.dart` (added `reason` param +
  `_RelevanceReasonRow`)
- `lib/features/events/events_screen.dart` (wired `EventDiscoveryService`,
  `eventOpened` analytics)

Untouched by this task: `docs/Architecture/
EVENTS_V2_STEP_8_PERSONALIZED_DISCOVERY_AUDIT.md` (no factual correction
was uncovered during implementation).

## GIT

Nothing staged, nothing committed, nothing pushed — `git diff --cached` is
empty and `git status --short` shows only the working-tree changes listed
under Files above, plus pre-existing, unrelated untracked Michelin/
Gault&Millau enrichment artifacts (`docs/Architecture/Michelin_Database/`,
`supabase/data/enrichment/`) left exactly as found.

## PHYSICAL DEVICE CHECKLIST

- [ ] Cold-start/no-signal account: Events screen shows the same
      chronological list as before Step 8A, no empty personalization UI.
- [ ] Trip match: a matching event moves up, shows exactly one "During your
      ... trip" reason, event still appears once.
- [ ] Friend Going: qualifying event ranks above Followed Host/Friend
      Interested cases, friend name/count copy correct.
- [ ] Followed Host: a followed entity's HOSTED event qualifies; a
      venue-only or participant-only link does not.
- [ ] Friend Interested: ranks below Friend Going, above Popularity.
- [ ] Multiple reasons: an event qualifying for several tiers shows only
      the strongest.
- [ ] Failure: airplane mode / a failed personalization signal still shows
      the full chronological Events list, no error state.
- [ ] Visual: card stays elegant at real device widths/text scales, no
      overflow, no more than one reason row, no gold on the reason row.

Production today has 0 events with any `event_restaurants`/`event_hotels`/
`event_chefs` `is_host = true` link, 0 accepted friendships, and 1 planned
trip whose country coarsely overlaps a live event's country — so on real
production data, most physical-device checks above will currently exercise
the *fallback* (cold-start-equivalent) path rather than a live personalized
reason; the ranking/host-semantics logic itself is exhaustively proven
against local fixtures instead (see Regression).
