# EVENTS DISCOVERY TAXONOMY — PHASE C FINAL REPORT

Status: finalized, committed, pushed. Location/Date-first discovery
approved on physical device. No schema change. No production writes.

## PHYSICAL DEVICE UI APPROVAL

The user tested the corrected Phase C experience (Location/Date promoted
to first-class controls, advanced Filters reduced to Social/Type/Theme,
old summary line removed) on a physical device and confirmed: **"het
werkt goed."** This is recorded as physical-device UI approval for the
**corrected** Phase C experience specifically — Search working
independently, Location and Date working as separate primary controls,
advanced Filters remaining refinement-only, the Amsterdam/date
composition concern resolved from the user's own perspective, and no
regression observed. This approval does **not** cover and must never be
read as covering GPS/current-location behavior, city filtering, or trip-
location shortcuts — none of which exist in the app; all three remain
documented-only future directions (see below).

## FINAL PRODUCT CONTRACT

Confirmed directly from code (`events_screen.dart`,
`event_filter_sheet.dart`, `event_discovery_filters.dart`,
`event_location_context.dart`, `event_date_control.dart`):

- **Top level**: Search, Location, Date, Filters — one calm row beneath
  Search.
- **Advanced Filters** (behind the one Filters entry point): Social,
  Type, Themes only.
- **Not present anywhere**: Location or Date inside the advanced sheet,
  City, Admission, Past-event browsing, a permanent quick-filter chip
  wall, a second Filters entry point.

## EVENTS SCREEN HIERARCHY

```
HEADER
SEARCH
LOCATION / DATE / FILTERS
EVENT FEED
```

No separate active-filter summary line. `EventCard`/Event Detail
unchanged.

## SEARCH

Independent, unchanged `TextField`/`_query` → `EventsRepository
.loadEvents(query: ...)` (`ilike` against `name`/`city`/`venue_name`).
Reconfirmed: Search survives Location changes, Date changes, and
advanced-Filters Apply — none of the three ever touch `_query`, and
`_query` never touches any of them. The originally-reported "Amsterdam +
Date" scenario is resolved: `test/events_discovery_composition_
regression_test.dart` proves both interaction orders (search-then-date,
date-then-search) produce byte-identical composed state and results, and
production read-only proof against the real catalogue confirms the same
query shapes.

## LOCATION

First-class, always-visible control reusing `CountryFilterControl`/
`showCountryPickerSheet` (single-select in V1), committing immediately
via `EventLocationContext`. Underlying domain field
(`EventDiscoveryFilters.countryCodes`) is unchanged from Phase B —
still a `Set<String>`, still multi-country-capable — only the V1 UI
surface is single-select. `EventLocationContext`'s own doc comment
documents (not implements) the extension seam for a future city mode, a
future current-location mode, and a future trip-destination shortcut.

## DATE

First-class, always-visible control (`EventDateControl`/
`showEventDateSheet`): Any date / Today / This weekend / This month /
Custom, committing immediately (no Apply step in this control). Custom
uses the existing `showDateRangePicker` mechanism, normalized to
calendar-date-only UTC midnights. Date-only Event compatibility is
unchanged from Phase B (`eventIntersectsDateRange`, untouched).

## ADVANCED FILTERS

`event_filter_sheet.dart` — Social (Friends Going/Interested/Following),
Type (7 V1 types), Themes (6 live tags from `event_tags`) only. Draft
state inside the sheet; committed only on Apply
(`EventFilterSheetResult{filters}` — no `datePreset` field anymore, since
Date left this sheet). Dismiss without Apply leaves committed state
unchanged (tested). Clear All resets only the sheet's own draft (Social/
Type/Theme) — Search/Location/Date are outside its state entirely and
were never reachable from it.

## FILTER COMPOSITION

Confirmed live pipeline: **Search AND Location AND Date AND Advanced
Filters → Step 8A ranking.** Within Advanced Filters: OR within Social,
OR within Type, OR within Theme, AND across those three dimensions.
Location and Date are ANDed on top via `_effectiveFilters`
(`_advancedFilters.copyWith(countryCodes: _location.countryCodes,
dateRange: _dateRange)`), composed fresh on every fetch, never stored
pre-merged — the architectural reason no dimension can silently
overwrite another. `EventDiscoveryService.rankForDiscovery` remains the
single, final, unmodified ranking layer applied only to the already-
filtered result.

## FILTERS COUNT

`EventDiscoveryFilters.advancedFilterDimensionCount` — Social/Type/Theme
only. Location and Date never contribute (they have their own visible
controls). Example reconfirmed: Netherlands + This month + Wine +
Friends Going → `Filters · 2` (Theme + Social), not 4. Covered by 4
dedicated tests in `event_discovery_filters_test.dart`. The original,
unrepurposed `activeDimensionCount` (all five dimensions) remains
unchanged and still passes every original Phase B test.

## ACTIVE SUMMARY DECISION

Deliberately removed. `event_discovery_filter_summary.dart` and its test
were deleted (git shows no trace of either, since both were created and
deleted within this same uncommitted workstream). Reasoning, unchanged
from the Pre-Final doc: Location and Date self-describe via their own
controls; `Filters · N` communicates advanced refinement; a fourth line
repeating all of that would be redundant, not calmer.

## STEP 8A RANKING

Zero functional change — reconfirmed via `git diff` on
`event_discovery_service.dart`/`event_discovery_ranking.dart` against
the last committed state (`fcdb50e`): no diff. Hierarchy unchanged: Trip
> Friend Going > Followed Host > Friend Interested > Popularity >
Chronology. Filtering never creates a new relevance reason — a Wine-
filtered Event can still show "During your trip"; a Friends-Going-
filtered Event can still show Trip if Trip is the stronger signal. No
card ever shows "Wine"/"Dinner"/"Netherlands" as a reason.

## FAILURE ISOLATION

`EventFilterResolutionException` (unchanged) wraps only the Theme/Social
resolution inside `EventDiscoveryFilterService.loadFilteredDiscovery`,
reached only when those dimensions are active — an inactive taxonomy/
social path is never even attempted, so cold start can never be broken
by an outage in either. Active-filter failures surface as a distinct,
friendly, recoverable `_DiscoveryFailureState` (Retry + conditional
Reset discovery) — never silently shown as an unfiltered or falsely-
empty result, never a raw Supabase/PostgREST error. The generic base-
load failure path (which now legitimately includes Location/Date/Type/
Country as server-side predicates) received the same recoverable
treatment during the correction pass.

## LOADING / RACE SAFETY

Unchanged `FutureBuilder` stale-future-discard mechanism
(`_activeCallbackIdentity`), re-verified for the four-independent-control
interaction pattern (Location → Date → Search → advanced Apply): only
the newest `_discoveryFuture` assignment can ever reach `setState`,
regardless of network completion order. No new request-token
bookkeeping was needed or added.

## EMPTY / FAILURE STATES

Two empty-result states keyed off `_isDefaultDiscoveryState` (Search,
Location, Date, and advanced Filters all at default): cold-start
(`_NoEventsState`, byte-identical pre-Phase-C copy) vs. narrowed-to-empty
(`_NoFilterResultsState`, restrained copy + one unambiguous "Reset
discovery" action). Two failure states share `_DiscoveryFailureState`:
the Theme/Social-specific message, or the generic "Could not load
events" message — both with Retry, and Reset discovery whenever
non-default state might plausibly be the cause.

## SIGNED-OUT

Search, Location, Date, Type, Theme all fully usable signed-out. Social
group hidden entirely from the advanced sheet (no zero-result trap). The
domain-level safe fallback (`applyDiscoveryFilters` returning `const []`
for an active Social filter with no signed-in user) remains as
defense-in-depth, unused in the normal UI path since Social is simply
never offered. No auth changes.

## NAVIGATION / STATE

Unchanged structural guarantee: `Navigator.push` to Event Detail sits on
top of the same, non-disposed `_EventsScreenState`, so Search, Location,
Date, and advanced Filters are all exactly as they were on return — no
manual save/restore code.

## EVENTCARD

Zero diff. No Type/Theme matching badges, no taxonomy chip clutter. Still
renders at most one Step 8A relevance reason.

## EVENT DETAIL

Zero diff. Tag row remains explicitly deferred (unchanged reasoning from
the original Phase C pass).

## FUTURE CURRENT LOCATION

Documented only, in `event_location_context.dart`'s own doc comment —
not implemented. Recommended shape when built: a new resolved-predicate
field/getter on `EventLocationContext` (distance-from-point, never
reusing `countryCodes`, which is a fundamentally different SQL
predicate), gated by explicit user permission, a graceful fallback when
permission is denied or unavailable, and manual location choice always
remaining available as an alternative — never replaced by the automatic
mode. No permission code, no geolocation service, no radius/coordinate
search exists anywhere in this codebase.

## FUTURE TRIP LOCATION

Documented only. Step 8A's own Trip relevance signal
(`event_discovery_ranking.dart`) already knows a signed-in user's
upcoming trip destinations, completely untouched by this work. A future
Location control could offer that destination as a one-tap shortcut
(e.g. "Maastricht — Upcoming trip"), resolving to the same
`EventLocationContext(country: ...)` shape already supported — it would
only ever set discovery Location/Date context, never change Step 8A's
own ranking hierarchy or duplicate its Trip-matching logic.

## FUTURE DEFAULT LOCATION STRATEGY (design note, not implemented)

Recommended precedence for a future "what location should Discovery
default to" decision, to be revisited as a real product decision rather
than treated as pre-approved:

1. **Explicit manual selection always wins** — if a user has picked a
   country (or, later, a city), nothing overrides it silently.
2. **An active/upcoming Trip may be offered as a one-tap shortcut** (see
   above), never auto-applied without the user choosing it.
3. **Current location, once built, applies only with explicit permission**
   — never a silent default, and only ever as a further alternative
   alongside manual selection, not a replacement for it.
4. **Last-used location may improve continuity** between sessions — a
   plausible enhancement, not decided here.
5. **A global/no-restriction default remains valid** — nothing in this
   architecture hardwires Netherlands (or any other country) as an
   assumed default; today's V1 simply starts at "All locations" (
   `EventLocationContext.any`) until a user picks one.

## PRODUCTION READ-ONLY PROOF

Re-run via `supabase db query --linked` (read-only `SELECT` only)
against the live 27-Event catalogue at finalization time:

| Combination | Result |
|---|---|
| "Amsterdam" search (name/city/venue_name) | 6 |
| Amsterdam + September 2026 | 2 |
| Netherlands + September 2026 | 11 |
| Netherlands + Wine | 5 |
| Netherlands + Wine + Dinner | 2 |
| Amsterdam + Wine | 0 |
| Amsterdam + September 2026 + Dinner | 0 |

The two zero-result rows are reported honestly as correct, genuine
intersections — not bugs. No production data was written.

## DATABASE

`supabase migration list --linked`: 40/40 synced. `supabase db push
--linked --dry-run`: `"Remote database is up to date."` Finalization
inserts/updates/deletes/schema changes/RLS changes/migrations deployed:
all 0.

## VALIDATION

- `dart format --set-exit-if-changed .` — 412 files, 0 changed.
- `flutter analyze` — No issues found!
- `flutter test` — **1606 passed, 0 failed**, both before and after
  staging (re-run identically post-stage, see Git section).

## FILES

Committed this workstream (the full Phase C diff against the last
commit, `fcdb50e`):

New:
- `lib/models/event_location_context.dart`
- `lib/features/events/widgets/event_date_control.dart`
- `lib/features/events/widgets/event_filter_sheet.dart`
- `test/event_location_context_test.dart`
- `test/event_date_control_test.dart`
- `test/event_filter_sheet_test.dart`
- `test/events_discovery_composition_regression_test.dart`
- `docs/Architecture/Events/EVENTS_DISCOVERY_TAXONOMY_PHASE_C_PRE_FINAL.md`
- `docs/Architecture/Events/EVENTS_DISCOVERY_TAXONOMY_PHASE_C_FINAL.md` (this file)

Modified:
- `lib/features/events/event_discovery_filter_service.dart`
- `lib/features/events/events_screen.dart`
- `lib/models/event_discovery_filters.dart`
- `test/event_discovery_filters_test.dart`

Deleted:
- `lib/features/events/widgets/event_filter_bar.dart`

(`event_discovery_filter_summary.dart` and its test were created and
deleted entirely within this uncommitted workstream — git has no record
of either, correctly.)

## UNRELATED EXCLUSIONS

Present in the working tree as untracked but deliberately not staged,
not committed, not deleted: `.claude/`, several European/Gault&Millau/
imagery-pilot docs, everything under `supabase/data/enrichment/`. None
were created or touched by Phase C.

## GIT

See the chat final-answers report for the exact commit hash, message,
and push confirmation recorded at finalization time.

## DEFERRED WORK

Unchanged: current-location/"Near me", city filtering, trip-location
shortcuts, Event Detail tag row, Admission filtering, past-Event
browsing, broader search expansion (tag/host-name search, FTS, vector
search), a dedicated `events.event_type` index if later warranted, Event
Hero Imagery, Passport Historical Integrity.

## NEXT

Phase C is complete and approved. Events now supports Search, Location,
Date, Social/Type/Theme filters, and Step 8A personalization, all
composing correctly. No Phase D is started or assumed. Recommended next
step: a human/product review of the complete 27-Event discovery
experience to choose the next priority from the deferred list, rather
than automatically expanding scope. Candidates for that future review
(not decided, not started): (A) Event Detail tag discovery, (B) current-
location/"Near me", (C) broader Event search, (D) additional Event
enrichment, (E) Event imagery, (F) Passport Historical Integrity.
