# EVENTS DISCOVERY TAXONOMY — PHASE B FINAL REPORT

Status: finalized, committed, pushed. No visible UI change. No schema
change. No production writes.

## PHYSICAL DEVICE REGRESSION APPROVAL

The user recorded regression-smoke approval prior to this finalization
task. Because Phase B introduced **no visible filter controls**, this is
a **regression approval** (confirming nothing about today's Events
experience broke), not an end-user filter UX approval (there is no
filter UX to approve yet — that is Phase C). Approved state: Events
screen opens normally; current layout is unchanged; current ranking/
relevance behavior is correct; Interested/Going remains functional;
Event Detail is correct; reverse hosted discovery is correct; Passport
is correct; no visible regression was observed.

## FINAL FILTER DOMAIN

`EventDiscoveryFilters` (`lib/models/event_discovery_filters.dart`) — 5
independent dimensions:

- `social: Set<EventSocialFilter>` (friendsGoing, friendsInterested, following)
- `eventTypes: Set<EventType>`
- `tagSlugs: Set<String>` (normalized lowercase)
- `countryCodes: Set<String>` (normalized uppercase)
- `dateRange: EventDiscoveryDateRange` (from `EventDiscoveryDatePreset`: none/today/thisWeekend/thisMonth/custom)

Immutable (`Set.unmodifiable` fields), value `==`/`hashCode`, `copyWith`,
`isEmpty`, `activeDimensionCount` (0–5). `static final empty` is the
canonical default. `static const selectableEventTypes` = the 7 V1 types.

## SOCIAL SEMANTICS

- **Friends Going** — `friendsGoingToEvent()` against `going`-status
  attendee ids (`EventAttendanceRepository.getVisibleUserIdsForEvents`).
- **Friends Interested** — same `friendsGoingToEvent()` function, against
  `interested`-status attendee ids. No second "is this a friend"
  definition — one function, two status-keyed inputs, exactly as
  `EventDiscoveryService`/`EventDetailScreen` already call it.
- **Following** — genuine host-only: an event id is qualifying iff it is
  a key in `EventHostFollowRepository.getFollowedHostEventNames()`'s
  result, which itself only includes an id when
  `eventHostFollowQualifies(isHost: true, ...)` — venue-only or
  participant-only relationships never qualify.

## OR-WITHIN / AND-ACROSS CONTRACT

Confirmed directly from `applyDiscoveryFilters()`
(`lib/features/events/event_discovery_filtering.dart`): each of the 5
dimensions is checked independently as its own `if (dimension active AND
NOT in the pre-resolved matching/qualifying set) → exclude`. Since
membership in a dimension's matching set already represents the union of
its selected values (OR resolved upstream by the repository/pure-logic
layer), and every dimension's check must pass for an Event to survive,
the composed contract is exactly:

```
(Friends Going OR Friends Interested OR Following)   [if Social active]
AND (Type_1 OR Type_2 OR ...)                        [if Type active]
AND (Tag_1 OR Tag_2 OR ...)                          [if Theme active]
AND (Country_1 OR Country_2 OR ...)                  [if Country active]
AND date-range intersects                            [if Date active]
```

Q4 Social OR: **yes**. Q5 Type OR: **yes**. Q6 Theme OR: **yes**. Q7
Country OR: **yes**. Q8 AND across dimensions: **yes**. Verified by 58
passing tests including all 7 named combination scenarios (A–G).

## DATE SEMANTICS

`eventIntersectsDateRange(event, from, to)`: Event qualifies iff
`event.endDate >= from` (when `from` set) AND `event.startDate <= to`
(when `to` set) — a true interval-overlap test, via zone-tag-agnostic
`compareCalendarDates`, never raw `DateTime.isAfter`/`isBefore`. Presets
resolve to concrete calendar-date ranges (`today`, `thisWeekend` —
correct on the weekend itself, `thisMonth` — correct across year
rollover, `custom`), never depending on non-null `start_at`/`end_at`.
Date-only Events (no clock time, only `startDate`/`endDate`) are fully
supported and tested, as are multi-day date-only Events and full-time
Events (filtering always uses calendar dates only, never clock time).

## TAXONOMY SOURCE

Tag filtering reads exclusively from `event_tags` +
`event_tag_assignments`, keyed by stable `slug`
(`EventTagRepository.loadEventIdsForTagSlugs`). No title inference, no
description inference, no keyword heuristics, no runtime AI tagging —
the Phase A stored taxonomy is the sole source of truth, unchanged.

## REPOSITORY QUERY STRATEGY

`EventsRepository.loadEvents()` gained two additive, optional parameters
— `countryCodes: Set<String>?` and `eventTypes: Set<EventType>?` — both
applied via `.inFilter()`, ANDed with all pre-existing filters
(date-window, search, the original singular `countryCode`). The original
`countryCode` parameter and its one existing call site
(`EventsScreen`/`CountryFilterControl`) are byte-for-byte untouched.
Query counts: base list = 1 query; Theme resolution = 2 bounded queries
regardless of catalogue size; Social resolution = up to 4 batched,
parallel-started/sequentially-awaited queries (going, interested,
friends, followed-hosts), reusing Step 8A's own shape. No per-Event
query anywhere — no N+1.

## FILTER-FIRST STEP 8A COMPOSITION

`EventDiscoveryFilterService.loadFilteredDiscovery()`
(`lib/features/events/event_discovery_filter_service.dart`) narrows the
candidate list via `applyDiscoveryFilters()` first, then calls
`EventDiscoveryService.rankForDiscovery()` — completely unmodified —
exactly once, on the filtered list only. `git diff` confirms zero
changes to `event_discovery_service.dart` or `event_discovery_ranking.
dart` this phase; `rankEventsForDiscovery()` and `primaryReasonFor()`
are identical to their Phase A/8A/8B state.

## RELEVANCE REASONS

Unchanged, and proven never overridden by a filter selection: a Wine-tag
-filtered Event that also independently matches Trip still shows Trip as
`primaryReason` (test: "an Event qualifying under a Wine filter can
still rank first because it independently matches Trip"). A
Friends-Going-filtered Event that also matches Trip still shows Trip,
never a synthetic "Friends Going" reason (test: "a Friends-Going-filtered
result set can still show Trip as its primary relevance reason"). A
filtered-in, signal-less Event has `primaryReason == null`, identical to
unfiltered cold start (test: "no fake Type/Tag relevance reason is ever
created"). No taxonomy-derived relevance reason exists anywhere in the
ranking hierarchy — filtering and ranking remain structurally separate.

## SIGNED-OUT / ZERO-SIGNAL

- Signed-out + active Social filter → `applyDiscoveryFilters` returns
  `const []` deterministically (no exception, no fallback to "All").
  Non-Social filters are unaffected by signed-out state.
- Zero accepted friends → `resolveSocialQualifyingEventIds` returns an
  empty result for Friends Going/Interested (data-driven, no special
  case).
- Zero followed hosts → empty result for Following, same mechanism.
All three confirmed by dedicated tests in
`test/event_discovery_filtering_test.dart`.

## PERFORMANCE

At current scale (27 Events/6 tags/34 assignments) every query path is
latency-bound, not row-count-bound. At future scale (hundreds to low
thousands of Events), Type/Country/Date remain server-side predicates
over existing indexes; Theme resolution remains exactly 2 queries
regardless of Event count (bounded by tag/assignment count); Social
resolution remains bounded by friend/follow count, not Event count. No
part of the query strategy degrades to N+1 as the catalogue grows.

## INDEX / RLS

Read-only schema inspection via `supabase db dump --linked -s public`:
`events_country_idx`, `events_start_date_idx`, `events_start_at_idx`,
`events_status_idx`, `event_tag_assignments_event_idx`,
`event_tag_assignments_tag_idx`, `event_attendance_event_status_idx`,
`event_attendance_user_status_idx`, and the `follows` composite
`UNIQUE(follower_id, following_id)` all pre-date Phase B and fully cover
every new query path. No index exists on `events.event_type`; not needed
at current/near-future scale since every tested combination is co-
filtered by date/country first. **Migrations added = 0. New indexes = 0.
RLS changes = 0. SECURITY DEFINER = 0.** `event_tags`/
`event_tag_assignments` RLS: one `FOR SELECT USING (true)` policy each,
no write policy — unchanged from Phase A.

## PRODUCTION PROOF

Re-run via `supabase db query --linked` (read-only `SELECT` only)
against the live 27-Event catalogue at finalization time:

| Combination | Count |
|---|---|
| Netherlands + Wine | 5 |
| Guest Chef + Dinner | 11 |
| Wine OR Guest Chef | 20 |
| September 2026 date range | 13 |
| Lunch | 3 |
| Gala | 2 |
| Wild Game (tag) | 3 |
| Four Hands (tag) | 6 |

All values consistent with the Pre-Final proof run. No production writes
were made.

## UI NON-CHANGES

Confirmed via `git diff`/`git status`: `EventsScreen`, `EventCard`, and
`EventDetailScreen` have **zero** Phase B diff. No filter button, no
filter sheet, no active-filter summary, no chips, no EventCard taxonomy
chrome, no Event Detail tag row, no search redesign. The only production
code change is the additive `EventsRepository.loadEvents()` signature
extension, which is inert until a caller passes non-null values — no
existing caller does.

## FAILURE-ISOLATION PHASE C HANDOFF

`EventDiscoveryFilterService` currently has no live `EventsScreen`
caller, so per-signal failure isolation (matching
`EventDiscoveryService.rankForDiscovery`'s own try/catch-per-signal
resilience) was **not** implemented in Phase B — there is no caller to
exercise a failure path yet, and adding it now would be speculative,
untested-in-context code. **Required for Phase C**: when
`EventDiscoveryFilterService` gains its first live UI caller, tag/social
resolution failures must degrade to "that dimension not applied" rather
than failing the whole discovery load; the empty-filter path must remain
fully resilient; no raw backend error may reach the UI.

## DATABASE

`supabase migration list --linked`: 40/40 local/remote synced.
`supabase db push --linked --dry-run`: `"Remote database is up to date."`
No migration created or applied this phase. Zero production writes
during finalization.

## VALIDATION

- `dart format --set-exit-if-changed .` — 406 files, 0 changed.
- `flutter analyze` — No issues found!
- `flutter test` — **1564 passed, 0 failed.**
- Re-run identically after staging (Section "Git" below) with the same
  result.

## FILES

Committed (Phase B only):

- `lib/models/event_tag.dart` (new)
- `lib/models/event_discovery_filters.dart` (new)
- `lib/features/events/event_discovery_filtering.dart` (new)
- `lib/data/repositories/event_tag_repository.dart` (new)
- `lib/features/events/event_discovery_filter_service.dart` (new)
- `lib/data/repositories/events_repository.dart` (modified, additive only)
- `test/event_discovery_filters_test.dart` (new)
- `test/event_discovery_filtering_test.dart` (new)
- `docs/Architecture/Events/EVENTS_DISCOVERY_TAXONOMY_PHASE_B_PRE_FINAL.md` (new)
- `docs/Architecture/Events/EVENTS_DISCOVERY_TAXONOMY_PHASE_B_FINAL.md` (new, this file)

## UNRELATED EXCLUSIONS

Present in the working tree as untracked but deliberately **not**
staged, **not** committed, **not** deleted — left exactly as found:

- `.claude/`
- `docs/Architecture/EVENTS_CONTENT_ENRICHMENT_4_EVENTS_PRE_APPLY.md`
- `docs/Architecture/Events/EUROPEAN_EVENT_BATCH_1_PRE_APPLY.md`
- `docs/Architecture/Events/EUROPEAN_EVENT_BATCH_1_PRODUCTION_APPLY.md`
- `docs/Architecture/Events/EUROPEAN_EVENT_BATCH_1_REVALIDATION_PRE_APPLY.md`
- `docs/Architecture/Events/EUROPEAN_EVENT_ENRICHMENT_SPRINT_AUDIT.md`
- `docs/Architecture/Events/EUROPEAN_EVENT_FIRST_DATE_ONLY_PILOT_PRE_APPLY.md`
- `docs/Architecture/Events/EVENT_HERO_IMAGERY_PILOT_RESEARCH.md`
- `docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md`
- `supabase/data/enrichment/` (all subpaths: `MICHELIN_EXPANSION_REVIEW_CHECKPOINT.md`, `MICHELIN_PARTIAL_EXPANSION_CONTROL_REPORT.md`, `MICHELIN_PARTIAL_EXPANSION_IMPORT_PLAN.md`, `event_participants/mvp_2026/`, `events/european_event_batch_1_pre_apply.json`, `events/european_event_candidates_2026_2027.csv`, `events/event_hero_imagery_candidates.json`, `gault_millau/PRODUCTION_IMPORT_FINAL_REPORT.md`, `michelin_belgium_expansion/`, `michelin_bulk_location_enrichment/`, `michelin_catalogue_reconciliation/`, `michelin_france_manual_source/`, `michelin_history_netherlands/`, `michelin_location_spike/`)

None of these were created by Phase B work; none relate to Events
Discovery Taxonomy. `git add .` / `git add -A` were never used at any
point — every staged file was added by explicit path.

## GIT

See the chat final-answers report for the exact commit hash, commit
message, and push confirmation recorded at finalization time.

## NEXT

**Phase C — Events UI Redesign + Filter UI** (not started, document-only
per this task's own instruction): wire the approved Phase B filter
plumbing into a calm, editorial Events discovery UI — prominent search,
one Filters affordance (no permanent chip wall), an active-filter
summary line, a filter sheet covering Social/Type/Theme/Country/Date (no
City, no Admission yet), filter-first → existing Step 8A ranking
(unchanged), and — as a hard requirement of that phase, not optional
polish — proper failure isolation added at the point
`EventDiscoveryFilterService` gains its first live caller.
