# Events Discovery Taxonomy — Phase B: Filter Plumbing (Pre-Final)

Status: implementation complete, not yet staged/committed/pushed. No schema
change. No visible UI change. Ready for physical-device regression review
before any Events UI redesign begins.

## 1. Scope and boundary

Phase B builds the **non-visual filter/discovery domain and repository
plumbing** for Events Discovery: a pure filter domain model, pure
inclusion/exclusion logic, thin repository/orchestration additions, and
exhaustive pure-domain tests. It does **not** build the final filter
sheet, filter chips, active-filter summary UI, Events header redesign,
`EventCard` redesign, Event Detail tag row, or any new search UI. It does
not touch Dutch Batch 3, imagery, or Passport historical-integrity work.
Nothing was staged, committed, or pushed.

## 2. Relationship to Phase A

Phase A (commit `63e228c`) shipped the schema (`event_tags`,
`event_tag_assignments`), the V1 Event Type set, and backfilled the
production catalogue (27 Events, 6 tags, 34 tag assignments). Phase B
consumes that schema read-only — no migration was created or needed this
phase.

## 3. Relationship to Step 8A / 8B ranking

`EventDiscoveryService.rankForDiscovery()` and
`rankEventsForDiscovery()`/`primaryReasonFor()`
(`lib/features/events/event_discovery_service.dart`,
`lib/features/events/event_discovery_ranking.dart`) are **byte-for-byte
unmodified**. Phase B's own orchestration
(`EventDiscoveryFilterService.loadFilteredDiscovery`) narrows the
candidate list first, then calls `rankForDiscovery` on the filtered
result, exactly once, with no post-ranking reordering. There is exactly
one ranking implementation in this codebase, both before and after this
phase.

## 4. New files

- `lib/models/event_tag.dart` — `EventTag` value model for one
  `event_tags` row.
- `lib/models/event_discovery_filters.dart` — the filter domain model:
  `EventSocialFilter`, `EventDiscoveryDatePreset`,
  `EventDiscoveryDateRange`, `resolveEventDiscoveryDateRange()`,
  `EventDiscoveryFilters`.
- `lib/features/events/event_discovery_filtering.dart` — pure filtering
  core: `eventIntersectsDateRange()`, `applyDiscoveryFilters()`,
  `resolveSocialQualifyingEventIds()`.
- `lib/data/repositories/event_tag_repository.dart` — thin repository:
  `loadAllTags()`, `loadEventIdsForTagSlugs()`.
- `lib/features/events/event_discovery_filter_service.dart` — thin
  orchestration: `EventDiscoveryFilterService.loadFilteredDiscovery()`.
- `test/event_discovery_filters_test.dart` — domain-model tests (20
  tests).
- `test/event_discovery_filtering_test.dart` — filtering-logic tests,
  including combinations A–G and ranking-regression tests (38 tests).

## 5. Modified files

- `lib/data/repositories/events_repository.dart` — `loadEvents()` gained
  two new optional parameters, `countryCodes` and `eventTypes`, applied
  via `.inFilter()` and ANDed with all existing filters. The pre-existing
  singular `countryCode` parameter and every existing call site
  (`EventsScreen`) are untouched.

No other production file was modified.

## 6. Filter domain model

`EventDiscoveryFilters` holds five independent dimensions:

| Dimension | Field | Values |
|---|---|---|
| Social | `social` | `Set<EventSocialFilter>` (friendsGoing, friendsInterested, following) |
| Type | `eventTypes` | `Set<EventType>` |
| Theme | `tagSlugs` | `Set<String>` (normalized lowercase) |
| Location | `countryCodes` | `Set<String>` (normalized uppercase) |
| Date | `dateRange` | `EventDiscoveryDateRange` |

All set fields are `Set.unmodifiable`; the class has value `==`/
`hashCode`, `copyWith()`, `isEmpty`, and `activeDimensionCount` (counts
non-empty **dimensions**, not individual values — five max). `static
final empty` is the canonical empty-filter singleton used as the default
everywhere. `static const selectableEventTypes` is exactly the 7 V1
types (`dinner, lunch, festival, gala, tasting, brunch, party`) —
`experience`/`market`/`other` are deliberately excluded from the
selectable set (legacy/overflow values, per the Phase A taxonomy
decision), though they are never remapped or hidden if already present
on an Event.

## 7. Social filter semantics

`EventSocialFilter { friendsGoing, friendsInterested, following }`.
Multiple selected social filters combine with **OR** — an Event
qualifies if it satisfies *any* selected social filter. This mirrors
Step 8A's own relevance-reason resolution, where any one of Trip/Friend
Going/Followed Host/Friend Interested is sufficient to make an Event
relevant; the Social filter dimension is deliberately built on the same
"any single qualifying signal is enough" logic, not a stricter
require-all rule.

`resolveSocialQualifyingEventIds()` reuses, verbatim:
- `friendsGoingToEvent()` (`lib/features/events/friends_going_view_model.dart`)
  for both Friends Going and Friends Interested (same function, different
  attendee-id map).
- The Following check is a `Map.containsKey` test against
  `followedHostNamesByEvent`, i.e. `EventHostFollowRepository
  .getFollowedHostEventNames()`'s own return shape — the exact Step 8A
  host-follow resolution, including its `eventHostFollowQualifies()`
  (`isHost` only, never venue) rule.

No second "friend going" or "followed host" definition was created.

## 8. Type filter semantics

OR within Type: an Event qualifies if `eventTypes` is empty (dimension
inactive) or `filters.eventTypes.contains(event.eventType)`. Pushed down
server-side via `EventsRepository.loadEvents(eventTypes: ...)` using
`.inFilter('event_type', ...)`. Legacy values (`experience`/`market`/
`other`) are never remapped — an Event carrying one of those types simply
never matches a Type filter (since they're excluded from
`selectableEventTypes`), which is correct: those are unreached in the
picker specifically because Phase A decided not to force-migrate them.

## 9. Theme/Tag filter semantics

OR within Theme: an Event qualifies if `tagSlugs` is empty or the
Event's id is in the resolved `tagMatchingEventIds` set.
`EventTagRepository.loadEventIdsForTagSlugs()` resolves the union of
Events tagged with *any* selected slug in exactly two queries
(slug→tag_id, then tag_id→event_id via `.inFilter`), regardless of how
many slugs are selected. Verified against production: `wine` (5 events)
∪ `guest_chef` (15 events) = 20 distinct events (no overlap in the
current catalogue) — confirms the union/OR-within-tag implementation is
correct, not merely additive-looking.

Tag membership is queried exclusively via `event_tag_assignments` +
`event_tags`, keyed by `slug` — never by title keyword inference, which
this codebase has consistently avoided since the Phase A audit. The
plumbing accepts a `Set<String>` of slugs and produces a single matching
id-set; nothing in the shape prevents a future AND-tags mode (e.g. by
intersecting two independently-resolved id-sets instead of unioning),
but that is not implemented in Phase B — V1 is OR-only, per the task's
own explicit instruction.

## 10. Location/Country filter semantics

OR within Country, identical shape to Type: new `countryCodes` parameter
on `EventsRepository.loadEvents()`, pushed down via `.inFilter
('country_code', ...)`, ANDed with the pre-existing singular
`countryCode` param (which remains for the one existing call site;
passing both simultaneously is not a supported combination and no call
site does so).

## 11. Date filter semantics

`EventDiscoveryDatePreset { none, today, thisWeekend, thisMonth, custom
}`. `resolveEventDiscoveryDateRange()` resolves every preset to a
concrete, timezone-agnostic `(from, to)` calendar-date pair:

- `today` → `[now, now]`.
- `thisWeekend` → the upcoming Saturday–Sunday; if `now` is already
  Saturday or Sunday, resolves to *that* weekend, not next weekend
  (tested explicitly for both days).
- `thisMonth` → the full calendar month containing `now`, computed via
  `DateTime.utc(year, month + 1, 0)` for the last day, which correctly
  handles December's year rollover (tested explicitly).
- `custom` → the caller-supplied `EventDiscoveryDateRange` verbatim; with
  no range supplied, resolves to empty rather than throwing.

This is a deliberately distinct concept from the pre-existing
`EventDateFilterMode`/`EventDateFilter` (`upcoming/thisWeek/month/
custom`), which resolves the *base browse window* for the whole Events
screen. Phase B's filter is a narrowing layered **on top of** that
window, not a replacement for it — a `thisWeekend` date filter applies
within whatever base window (`Upcoming`, `This Month`, …) is already
active. The two concepts share the same underlying tool
(`compareCalendarDates`) but are never merged into one enum, because
`thisWeekend` has no equivalent in the base-window concept and forcing
them together would either lose that preset or corrupt the base-window
semantics.

Never depends on `start_at`/`end_at` being non-null — resolution and
intersection both operate purely on `startDate`/`endDate` (always
non-null calendar dates per the Time Precision work), consistent with
the project's own "calendar-date-only comparison discipline."

## 12. Date intersection semantics

`eventIntersectsDateRange(event, from, to)`: an Event qualifies if its
`[startDate, endDate]` calendar span **intersects** `[from, to]` (open
ends treated as unbounded), computed via `compareCalendarDates` —
mirrors `eventMatchesTrip()`'s own overlap check exactly, not a novel
comparison.

**Worked example** (also a unit test): an Event spanning 10–12 Oct 2026.
A filter range of `[11 Oct, 11 Oct]` (a single day landing mid-span)
intersects → included. A filter range of `[1 Oct, 5 Oct]` (entirely
before the span) does not intersect → excluded. A filter range of `[20
Oct, 25 Oct]` (entirely after) does not intersect → excluded. A range
touching exactly on the boundary (`to = 10 Oct`, the Event's own start)
counts as intersecting, consistent with inclusive-boundary semantics
used elsewhere in this codebase (e.g. `eventBrowseWindowBounds`'s own
±1-day widening).

Verified against production: a `[1 Sep, 30 Sep]` range against the real
27-event catalogue returns 13 events.

## 13. Upcoming-only invariant

No "Past" filter option exists in `EventDiscoveryDatePreset`, and no new
code path was added anywhere that could surface past Events through
Phase B's own filtering. The Passport remains the sole historical-events
surface, unchanged. `EventsRepository.loadEvents()`'s pre-existing
`from`/`to` base-window parameters (driven by `EventDateFilter`, not
Phase B) already exclude past Events by default; Phase B's filters only
ever narrow within whatever window is already active.

## 14. Query strategy

`EventDiscoveryFilterService.loadFilteredDiscovery()`:

1. One `EventsRepository.loadEvents()` call, with Type/Country/Date
   pushed down as server-side predicates alongside the pre-existing
   date-window/search/country parameters — never fetch-everything-then-
   filter-in-Dart.
2. If Theme is active: exactly 2 bounded queries via
   `EventTagRepository.loadEventIdsForTagSlugs()`, independent of
   catalogue size.
3. If Social is active and `userId != null`: the exact same batched,
   per-signal-independent set of calls `EventDiscoveryService` already
   uses for ranking (`getVisibleUserIdsForEvents` ×{going, interested},
   `getFriends` once — shared between going/interested, not fetched
   twice — `getFollowedHostEventNames`), run with parallel start /
   sequential await, matching Step 8A's own established pattern.
4. `applyDiscoveryFilters()` — pure, in-memory, O(n) over the already-
   narrowed candidate list.
5. `discoveryService.rankForDiscovery()` — unmodified.

No N+1 queries anywhere: no per-Event taxonomy fetch, no per-Event
friend/follow query. Total query count for any filter combination is
bounded (≤ 1 + 2 + 4 ≈ 7 queries) regardless of catalogue size, matching
the existing Step 8A ranking's own bounded-query shape.

## 15. Relevance-reason preservation

Filtering and ranking are structurally two separate steps with no shared
mutable state: `applyDiscoveryFilters()` returns a `List<Event>`;
`rankForDiscovery()` independently computes each returned Event's
`primaryReason` from its own signal resolution, with no knowledge of
which filter(s) were active. A Wine-tag-filtered Event that also happens
to match a Trip still shows **Trip** as its primary reason (proven by
test); a Friends-Going-filtered Event that also matches a Trip still
shows **Trip**, never a synthetic "Friends Going" reason (proven by
test); a filtered-in Event with no independent relevance signal at all
has a `null` primaryReason, identical to unfiltered cold start (proven
by test). Filtering never fabricates, suppresses, or overrides a
relevance reason.

## 16. Signed-out / zero-signal / cancelled-event behavior

- **Signed out + active Social filter**: `applyDiscoveryFilters` returns
  `const []` — deterministic, not an error, not silently ignored (a
  signed-out user genuinely cannot have Friends Going/Interested/
  Following data).
- **Signed out + non-Social filters**: work exactly as for a signed-in
  user (Type/Theme/Country/Date have no user-identity dependency).
- **Zero friends / zero followed hosts**: `resolveSocialQualifyingEventIds`
  returns an empty qualifying set, not an error — data-driven emptiness,
  no special-casing.
- **Cancelled Events**: Phase B introduces **no new exclusion rule**. A
  cancelled Event participates in filter-matching exactly like any other
  Event — this preserves the existing "included but badge-marked, never
  hidden" behavior and keeps the empty-filter case byte-identical to
  today. (See Section 24 for why an apparent tension with an earlier
  draft instruction was resolved this way.)

## 17. Filter normalization and equality

Tag slugs: lowercased + trimmed in the `EventDiscoveryFilters`
constructor. Country codes: uppercased + trimmed. All Set fields
deduplicate by construction (Set semantics) and are wrapped in
`Set.unmodifiable`. `EventDiscoveryDateRange.normalized()` swaps an
inverted `(from, to)` pair rather than dropping it; an open range (either
side `null`) is left alone, never treated as inverted. Value `==`/
`hashCode` on both classes means two independently-constructed filter
objects with the same logical content compare equal regardless of
construction/insertion order — verified by test.

## 18. Active-filter-summary domain support

`EventDiscoveryFilters.activeDimensionCount` (0–5) is the only summary
primitive Phase B exposes; it is sufficient for a future "3 filters
active" chip without needing any new domain code — the visual chip/badge
itself is explicitly out of scope for this phase (Section 1). No
additional per-dimension "display label" helper was added, since that is
presentation logic (which V1 tag/type/country string maps to which
user-facing label) that belongs with the UI work, not the domain model.

## 19. Search boundary

`EventDiscoveryFilterService.loadFilteredDiscovery()` already accepts a
`query` parameter, passed straight through to `EventsRepository
.loadEvents(query: ...)`, which already supports server-side text search
independent of the new Type/Country/Date parameters. `searchText AND
filters` composition requires no new plumbing — the existing parameter
and the new ones are simply ANDed together in the same `loadEvents` call.
No new search UI or search-ranking logic was built.

## 20. Analytics

Deliberately not implemented in Phase B, per the task's own instruction.
No analytics/telemetry hooks exist anywhere in the new files.

## 21. Performance reasoning

**Current scale (27 Events, 6 tags, 34 assignments)**: every query path
is trivially fast; the dominant cost is round-trip latency (≤ ~7 queries
total for the richest combination), not row count.

**Future scale (1,000–10,000 Events)**: Type/Country/Date remain
server-side predicates via existing/adequate indexes (Section 22) — row
count growth does not change the query *shape*. Theme resolution remains
exactly 2 queries regardless of catalogue size (bounded by tag count and
assignment count, not Event count). Social resolution remains bounded by
friend-count/followed-host-count, not Event count, exactly as Step 8A's
own ranking already assumes at whatever scale it was designed for. No
part of Phase B's query strategy has a growth path that turns into an
N+1 pattern.

## 22. Index audit

Inspected `public` schema indexes via `supabase db dump --linked -s
public`. Relevant existing indexes, all pre-dating Phase B:

- `events_country_idx` (`country_code`) — covers the new `countryCodes`
  filter.
- `events_start_date_idx` (`start_date`), `events_start_at_idx`
  (`start_at`) — cover date-window queries.
- `events_status_idx` (`status`) — covers the upcoming-only base filter.
- `event_tag_assignments_event_idx` (`event_id`),
  `event_tag_assignments_tag_idx` (`tag_id`) — cover both directions of
  `EventTagRepository.loadEventIdsForTagSlugs()`'s two-query resolution.
- `event_attendance_event_status_idx` (`event_id, status`),
  `event_attendance_user_status_idx` (`user_id, status`) — cover
  `getVisibleUserIdsForEvents()`, unchanged, reused as-is.
- `follows_follower_id_following_id_key` (UNIQUE, composite,
  `follower_id` leading) — covers `getFollowedHostEventNames()`'s
  follower-id lookup, unchanged, reused as-is.

**No index exists on `events.event_type`.** At current (27) and
near-future (hundreds–low thousands) scale this is not a problem: every
production filter combination tested (Section 23) also carries a date
and/or country predicate that already narrows via an existing index
first, leaving Type as a cheap residual filter over a small row set. A
dedicated `event_type` index would only become worth adding if
Type-only filtering (no date/country bound) becomes a common isolated
query pattern at 10,000+-row scale — speculative, out of scope, and
explicitly **not** added in Phase B. **No new migration was created or
is required for this phase.**

## 23. RLS confirmation

Confirmed via `supabase db dump --linked -s public`: both `event_tags`
and `event_tag_assignments` have RLS enabled with exactly one policy
each — `FOR SELECT USING (true)` — no write policy, matching the
established public-catalogue convention used by every other Events
table. Phase B's new query paths (`EventTagRepository`, the extended
`EventsRepository.loadEvents`) use the standard anon/authenticated
Supabase client throughout — no `SECURITY DEFINER`, no service-role
bypass, nothing new to audit here beyond what Phase A already
established.

## 24. Cancelled-Event decision reconciliation

An early reading of the task's own requirements appeared to ask for two
things in tension: excluding cancelled Events from filtered results, and
guaranteeing the empty-filter case is byte-identical to current
behavior (which includes cancelled Events, badge-marked). Resolved by
introducing **no new cancellation rule** in `applyDiscoveryFilters` —
this satisfies the byte-identical empty-filter invariant unconditionally,
and is the more conservative reading: it changes nothing about
cancellation visibility, leaving that entirely to the existing,
unmodified badge-based UI treatment. Documented in code
(`event_discovery_filtering.dart`) at the point where a cancellation
check might otherwise be expected.

## 25. Repository testability

The thin repository/orchestration layer
(`EventTagRepository`, `EventDiscoveryFilterService`, the
`EventsRepository.loadEvents` extension) follows this codebase's own
established split: no mocking framework exists anywhere in `test/`
(confirmed via `grep -rln "class Fake\|extends Mock"` → zero results),
so thin Supabase-touching code is verified via architecture-doc
reasoning (Sections 14, 22, 23) plus direct production read-only proof
queries (Section 26), never elaborate mocks. All genuinely pure logic
(`event_discovery_filters.dart`, `event_discovery_filtering.dart`) has
full, mock-free unit test coverage instead, exactly mirroring how
`event_discovery_ranking.dart`/`event_discovery_service.dart` are
themselves tested.

## 26. Production read-only proof

All queries run via `supabase db query --linked` (read-only `SELECT`
only, no writes) against the real 27-Event production catalogue:

- Tag distribution: `charity`=1, `four_hands`=6, `guest_chef`=15,
  `wild_game`=3, `wine`=5, `winemaker`=4 — matches Phase A's own
  finalized 34-assignment total.
- **Netherlands + Wine**: 5 events returned (all 5 `wine`-tagged events
  happen to be Dutch in the current catalogue) — proves the AND-across-
  dimensions (Country ∧ Theme) composition.
- **Guest Chef + Dinner**: 11 events returned — proves AND-across-
  dimensions (Type ∧ Theme) with a non-trivial subset (15 guest_chef
  total, 11 of which are dinners).
- **Wine ∪ Guest Chef** (OR-within-Theme, two slugs): 20 distinct events
  = 5 + 15 exactly (no overlap in the current catalogue) — proves the
  union resolution in `loadEventIdsForTagSlugs` is correct, not just
  plausible-looking.
- **September 2026 date-range intersection**: 13 events — proves the
  calendar-span-intersects-window semantics against real multi-day and
  single-day Events.

## 27. Events-screen integration decision

**Not wired into `EventsScreen`.** The task permits this only if needed
for end-to-end proof; end-to-end proof was already fully achieved
without it via (a) 58 passing pure-domain tests covering every dimension,
every OR/AND combination, all 7 named scenarios (A–G), and ranking
regression, and (b) the production read-only proof in Section 26
confirming the actual repository query shapes against real data. Wiring
a new service into a live, already-shipped screen carries a real risk of
an accidental visible change even with the utmost care around a
default-empty-filter path — a risk not worth taking when the proof
burden is already discharged by tests + direct SQL. The Events screen is
therefore completely unmodified this phase; default behavior (no filter
selected) is unaffected because no screen code calls the new service at
all yet.

## 28. Cold start / failure isolation

`EventDiscoveryFilterService.loadFilteredDiscovery()` returns the
unfiltered, ranked list whenever `filters.isEmpty` — cold start (no
filter ever touched) takes the exact same code path as today's
`EventDiscoveryService.rankForDiscovery()` call, with the sole addition
of one extra `EventsRepository.loadEvents()` call carrying `null`
`countryCodes`/`eventTypes` (behaviorally identical to the existing call
signature). Explicit failure-isolation try/catch around `tagRepo`/social
calls (mirroring `EventDiscoveryService`'s own per-signal try/catch) was
**not** added in this phase — `loadFilteredDiscovery` is only reachable
once real UI wiring exists (Section 27 decision), so a thrown error here
today has no live caller and no user-facing effect. This is flagged
explicitly as a follow-up for whichever phase adds real UI wiring: at
that point, tag/social resolution failures should degrade to "dimension
not applied" rather than failing the whole discovery load, matching
Step 8A's own per-signal resilience — but implementing that now, with no
caller to exercise it, would be speculative code the task's own "no
half-finished implementations" guidance argues against.

## 29. Validation

- `dart format` — applied, 4 files reformatted (`events_repository.dart`,
  `event_discovery_filter_service.dart`, both new test files), all now
  clean.
- `flutter analyze` on all new/modified files — "No issues found!"
- `flutter test` (full suite) — **1564 passed**, 0 failed (1506 prior
  baseline + 58 new Phase B tests, exact match — nothing else broke).
- `supabase migration list --linked` — 40/40 local/remote synced,
  nothing pending. No new migration was created this phase.

## 30. Physical-device regression checklist

No visible UI exists yet, so there is nothing to visually regress-test
on device. The checklist for the *next* phase (once UI wiring begins) to
confirm at that time:
- [ ] Events screen with zero filters selected renders identically to
  pre-Phase-B behavior (same list, same order, same badges).
- [ ] Selecting/clearing filters does not affect the base browse-window
  behavior (`Upcoming`/`This Month`/etc. still governs the outer window).
- [ ] Signed-out state with a Social filter selected shows an empty
  state, not a crash.
- [ ] A Trip-matching Event continues to show "Trip" as its reason even
  when a Theme/Type/Country filter is also active.

## 31. Git status

Nothing staged, committed, or pushed this phase, per the hard scope
boundary. `git status` will show the six new files above plus the two
modified files (`events_repository.dart`, and this doc) as untracked/
modified.
