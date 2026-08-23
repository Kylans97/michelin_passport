# Events Discovery Taxonomy — Phase C: UI Redesign + Filter UI (Pre-Final)

Status: implementation complete (including the physical-device Correction
Pass below), not yet staged/committed/pushed. No schema change. No
production writes. Ready for physical-device RE-review before
finalization.

## Product Direction

Minimal Luxury: editorial, calm, dark forest green + ivory, no gold, no
chip wall, generous spacing, minimal chrome. The discovery engine (Step
8A ranking + Phase B filter plumbing) may be sophisticated; the UI stays
restrained. Search, Location and Date are primary discovery context —
always visible, immediately-committing controls; Social/Type/Theme are
deeper refinement, tucked behind one restrained Filters affordance.

## Previous Events UI

Before Phase C: `EventFilterBar` rendered a search field, then a
horizontally-scrolling row of date-mode chips (Upcoming/This week/Month/
Custom), then a `CountryFilterControl` row, then (in Month mode) a
month-stepper row — up to four stacked control rows, all permanently
visible, none of which touched Theme or Social at all. `EventCard`
already showed at most one relevance-reason row and never any taxonomy
chrome — it needed no changes throughout Phase C.

## PHYSICAL DEVICE CORRECTION PASS

The first Phase C implementation (Location/Date inside one advanced
"Filters" sheet, committed to a single `EventDiscoveryFilters` via a
draft+Apply flow) went through physical-device review before
finalization. Review surfaced two findings, both addressed in this
correction, described in full below.

### The Amsterdam + Date bug — root cause

**Reported behavior**: search "Amsterdam", then apply a Date filter —
the Amsterdam search context appeared lost / results did not behave as
the expected intersection.

**Investigation**: before writing any fix, the pre-correction code path
was traced exhaustively end to end — `EventsScreen._fetchDiscoveryList`
→ `EventDiscoveryFilterService.loadFilteredDiscovery` →
`EventsRepository.loadEvents` (search `ilike`-or-filter + date `gte`/
`lte` bounds, ANDed at the SQL level via PostgREST's default top-level-
parameter semantics) → `applyDiscoveryFilters` (the in-memory Date-
dimension check). At every step, `_query` (search) and the committed
`EventDiscoveryFilters` (including `dateRange`) were independently held
State fields that never overwrote one another — applying a Date filter
via the old sheet's Apply button never touched `_query`, and the
resulting composed query correctly intersected both. A dedicated
regression test (`test/events_discovery_composition_regression_test.
dart`) confirms this pure composition is and remains correct, including
order-independence (search-then-date and date-then-search produce
byte-identical committed state and results).

**Conclusion: this was not an incorrect AND-composition bug — it was an
architectural/UX one.** Date lived buried inside a "Filters" sheet
reached via a multi-tap, Apply-gated flow, with no visible connection to
the Search field above it, and nothing on screen told the user their
search was still active after applying a date. A real zero-result
outcome (a legitimate, correct intersection that simply happened to be
empty) was easy to misread as "my search got lost." The fix is
structural: Location and Date are promoted to their own always-visible,
immediately-committing controls, sitting in the same row as Search, so
their combined state is never hidden behind a sheet a user has to
remember they touched.

### The correction

- **Location** (country) and **Date** are removed from the advanced
  Filters sheet entirely and promoted to their own first-class controls,
  directly beside Search.
- **Advanced Filters** now covers only Social/Type/Theme — materially
  smaller, calmer, and conceptually distinct from "where/when" (Location/
  Date), which is primary discovery context, not refinement.
- **`Filters · N`** now counts only Social/Type/Theme
  (`EventDiscoveryFilters.advancedFilterDimensionCount`, new) — Location
  and Date have their own visible controls and would otherwise be
  double-reported.
- **The separate active-filter summary line is removed entirely**
  (`event_discovery_filter_summary.dart` and its test were deleted — see
  "Active Filter Summary" below for the full reasoning): Location and
  Date already communicate their own state in their own labels;
  repeating that underneath would be redundant.
- **Location and Date commit immediately** on selection — no Apply step.
  Advanced Filters (Social/Type/Theme) keeps its draft+Apply model, since
  those remain genuine multi-step refinement a user composes before
  committing.
- A new **`EventLocationContext`** domain type (`lib/models/
  event_location_context.dart`) replaces raw `VenueCountry?` at the
  screen-state boundary — future-ready for city/current-location/trip-
  destination modes without renaming or restructuring (see "Future
  Readiness" below). No GPS, permission, or nearby-search code was
  written.
- Empty/failure states were unified into `_NoFilterResultsState`/
  `_DiscoveryFailureState` with ONE unambiguous **"Reset discovery"**
  action (clears all four dimensions), replacing the narrower, now
  potentially-ambiguous "Clear filters" wording once Location/Date/
  Search can also be the cause of a zero-result/failure state.

## New Events UI

Final hierarchy, top to bottom:

```
EVENTS HEADER (title + subtitle, unchanged)
  SEARCH (TextField, unchanged behavior)
  LOCATION  /  DATE  /  FILTERS  (one calm row, all always visible)
EVENT FEED (ranked EventCard list, unchanged)
```

No category-chip wall, no permanent row of Dinner/Wine/Following/etc.,
no separate active-filter summary line duplicating what Location/Date/
Filters already show.

## Search

Unchanged behavior — the same `TextField`/`_query`/`EventsRepository
.loadEvents(query: ...)` server-side search path as before Phase C.
Matches `name`/`city`/`venue_name` (confirmed via `buildIlikeOrFilter`
in `events_repository.dart` — unchanged, not expanded to tag/host search
in this correction, per its own explicit "bug fix is composition, not
search expansion" instruction). No FTS, vectors, or new RPC were added.

## Location

`lib/models/event_location_context.dart` (new) + the existing
`CountryFilterControl`/`showCountryPickerSheet` (reused verbatim — same
searchable single-select sheet Explore already uses, `allowAll: true`
gives the built-in "All countries" independent-clear option). V1
resolves to exactly one selected country or none — the task's own
explicit permission to keep the primary Location UX single-select while
retaining the underlying multi-country-capable domain field
(`EventDiscoveryFilters.countryCodes` is untouched, still a `Set<String>`
— `EventLocationContext.countryCodes` simply resolves to a one-element
or empty set). Commits immediately via `CountryFilterControl`'s own
`onChanged` callback — no Apply step. Closed-control label: "Location"
when unset, the country's display name otherwise (never the raw ISO
code).

### Future Readiness — current location

Documented, not implemented: `EventLocationContext`'s own doc comment
specifies the extension point — a future resolved-current-location mode
would NOT reuse `countryCodes` (nearby search is a distance-from-a-point
predicate, not "country code in N values") and would need its own field/
resolved-predicate getter, added without touching the country mode that
already works. Privacy principle for that future work: explicit user
permission before any location read, a graceful fallback when
permission is denied/unavailable, and manual location choice always
remaining available as an alternative, never replaced. No permission
code, no geolocation service, no radius/coordinate search exists
anywhere in this codebase as of this pass.

### Future Readiness — trip destination

Documented, not implemented: Step 8A's own Trip relevance ranking
(`event_discovery_ranking.dart`) already knows a signed-in user's
upcoming trip destinations — completely unrelated to and untouched by
this pass. A future Location control could offer an upcoming trip's
destination as a one-tap shortcut (e.g. "Maastricht — Upcoming trip"),
resolving to the same `EventLocationContext(country: ...)` shape this
pass already supports; selecting it would only ever set discovery
Location/Date context, never change Step 8A's own ranking hierarchy or
duplicate its Trip-matching logic.

## Date

`lib/features/events/widgets/event_date_control.dart` (new) —
`EventDiscoveryDatePreset`: Any date / Today / This weekend / This
month / Custom dates. One clean bottom sheet (not a permanently-visible
chip row); every option except Custom commits immediately and closes the
sheet — no Apply button exists in this control. "Any date" is the
sheet's own built-in independent-clear option. Custom uses the existing
`showDateRangePicker` mechanism (the same one the old base-window
control already used), normalized to calendar-date-only UTC midnights
via `EventDiscoveryDateRange.normalized` — never timestamps. Closed-
control label (`eventDateControlLabel`, pure, tested): "Date" when unset,
the preset name ("Today"/"This weekend"/"This month"), or a compact
"D–D Mon" / "D Mon – D Mon" form for a custom range — never a verbose
sentence.

## Filters Affordance

`_EventsFiltersButton` (in `events_screen.dart`) — "Filters" when
`EventDiscoveryFilters.advancedFilterDimensionCount == 0` (Social/Type/
Theme only — Location/Date never contribute, see the Correction Pass
above), "Filters · N" otherwise.

## Filter Sheet

`lib/features/events/widgets/event_filter_sheet.dart` — now covers ONLY
Social/Type/Theme (Location/Date groups removed entirely this
correction; the sheet no longer even accepts a `countries` parameter or
reads `committed.countryCodes`/`.dateRange`). Same established sheet
chrome as before: drag handle, "Filters" + "Clear all", scrollable
groups using `AppTypography.sectionHeading` small-caps labels, a fixed-
position `CsPrimaryButton` "Apply". `EventFilterSheetResult` is now just
`{EventDiscoveryFilters filters}` (the `datePreset` field was removed —
no longer meaningful once Date left this sheet).

## Social

`EventSocialFilter.friendsGoing`/`.friendsInterested`/`.following`,
labeled "Friends Going"/"Friends Interested"/"Following". Multi-select.
Hidden entirely when signed out (unchanged decision from the original
Phase C pass).

## Type

Exactly the 7 V1 types from `EventDiscoveryFilters.selectableEventTypes`,
human labels via `EventType.label`. Multi-select, OR within Type.

## Themes

Loaded live via `EventTagRepository.loadAllTags()` — no second,
hardcoded taxonomy. Multi-select, OR within Theme.

## Filter State

FOUR independently-held state dimensions on `_EventsScreenState`, none of
which can overwrite another when changed individually:

| Dimension | Field(s) | Commit model |
|---|---|---|
| Search | `String _query` | immediate (unchanged) |
| Location | `EventLocationContext _location` | immediate |
| Date | `EventDiscoveryDatePreset _datePreset` + `EventDiscoveryDateRange _dateRange` | immediate |
| Advanced | `EventDiscoveryFilters _advancedFilters` (Social/Type/Theme only) | draft + Apply |

`_effectiveFilters` — a getter, not stored state — composes the ONE
actual query object fresh on every fetch: `_advancedFilters.copyWith(
countryCodes: _location.countryCodes, dateRange: _dateRange)`. There is
no second, competing `EventDiscoveryFilters`-like model anywhere; the
existing domain type's own `countryCodes`/`dateRange` fields are simply
re-attached from their own independent owners at read time rather than
stored pre-merged, which is exactly what makes "changing one dimension
can never touch another" true by construction rather than by discipline.

## Apply / Clear Behavior

**Advanced Filters** keeps Phase C's original sheet-local draft + Apply
model — genuine multi-step refinement. **Location and Date commit
immediately** — selecting either updates `_EventsScreenState` and
reloads on the spot; there is no sheet-level Apply for either. **Clear
All** (inside the advanced sheet) still only resets that sheet's own
draft (Social/Type/Theme) — Location/Date/Search are entirely outside
its state and were already unreachable from it even before this
correction. **Independent, per-dimension clears already exist inside
each control**: Location's own "All countries" tile, Date's own "Any
date" option, the advanced sheet's own "Clear all" — each dimension can
be reset to its default without touching any other. **Reset discovery**
(new, screen-level) is the one broader, unambiguous action offered only
from zero-result/failure states, where it is often unclear which single
dimension to blame — it clears all four at once, never presented as the
only way to clear a single one.

## Active Filter Summary

**Removed entirely.** `event_discovery_filter_summary.dart` and
`test/event_discovery_filter_summary_test.dart` were deleted. Reasoning:
once Location and Date have their own always-visible, self-describing
controls, a summary line repeating "Netherlands · This month · Wine ·
Friends Going" underneath them is redundant — the task's own explicit
instruction was to choose the cleaner on-device result rather than
preserve the old summary merely because it existed, and duplicating
state already visible in three adjacent controls is not cleaner.
`Filters · N` remains sufficient for the advanced dimensions, which stay
invisible until the sheet is opened.

## Search + Location + Date + Filter Composition

The canonical equation, proved by `test/events_discovery_composition_
regression_test.dart`: **Search AND Location AND Date AND Advanced
Filters → Step 8A ranking**. Search narrows server-side via `ilike`;
Location/Type narrow server-side via `.inFilter`; Date narrows in-memory
via the unchanged `eventIntersectsDateRange`; Social/Theme narrow
in-memory via the unchanged `applyDiscoveryFilters`. No dimension can
silently disable or override another — proved concretely: Netherlands +
"Amsterdam" search returns only the Dutch Amsterdam-named event, never
silently dropping the Location constraint because the search text names
a city; Switzerland + "Amsterdam" search correctly returns zero (Location
is never overridden by a search term that happens to match a different
country). Order of interaction is provably irrelevant — constructing the
same four-dimension `EventDiscoveryFilters` via different `copyWith`
call orders produces value-equal results (a dedicated test asserts
this directly).

## Filter-First → Step 8A

Unchanged. `git diff` on `event_discovery_service.dart`/
`event_discovery_ranking.dart`: zero diff, reconfirmed after this
correction. `loadFilteredDiscovery` narrows first (now via
`_effectiveFilters`, composed exactly as above), then calls
`EventDiscoveryService.rankForDiscovery` exactly once.

## Relevance Reasons

Unchanged — filtering and ranking remain structurally separate. No card
ever shows a Wine/Dinner/etc. "reason."

## Failure Isolation

`EventFilterResolutionException` (unchanged from the original Phase C
pass) still wraps only the Theme/Social resolution calls inside
`EventDiscoveryFilterService.loadFilteredDiscovery`, reached only when
those dimensions are genuinely active. **Widened this correction**: the
screen's failure-state widget (renamed `_DiscoveryFailureState`, was
`_FilterFailureState`) now also handles the GENERIC base-load failure
case — which, in the corrected architecture, already legitimately
includes Location/Date/Type/Country as server-side predicates in the
same base query — with a Retry action, and a "Reset discovery" action
whenever any non-default discovery state might plausibly be the cause
(`_isDefaultDiscoveryState ? null : _resetDiscovery`, so a genuinely
default-state base failure doesn't offer a no-op reset button). This
satisfies the requirement that "Location/Date server filtering failure
→ clear recoverable discovery failure," not just Theme/Social. No raw
Supabase/PostgREST error is ever shown in either case.

## Loading / Race Protection

Unchanged mechanism, re-verified after separating the controls:
`FutureBuilder` discards a stale future's result once `_discoveryFuture`
is reassigned (Flutter's own `_activeCallbackIdentity` guard). A rapid
Location → Date → Search → Filters-Apply sequence each independently
calls `_reload()`, and only the newest request's result can ever reach
`setState`, regardless of network completion order — no new request-
token bookkeeping was needed.

## Empty States

Two distinct states now keyed off `_isDefaultDiscoveryState` (search,
location, date AND advanced filters all at their default):

1. **Cold start** (`_isDefaultDiscoveryState` true, zero results) —
   `_NoEventsState`, the exact unchanged pre-Phase-C copy, byte-
   identical.
2. **Narrowed to empty** (any of the four dimensions active, zero
   results) — `_NoFilterResultsState`: "Nothing matches right now" +
   "Try adjusting your search, location, date or filters." + ONE
   "Reset discovery" action (clears all four) — replacing the earlier,
   narrower "Clear filters" wording that this correction's own §22
   flagged as potentially ambiguous/insufficient once Location/Date/
   Search can also be active.

## Signed-Out Behavior

Unchanged: the Social group is hidden entirely from the advanced sheet
when signed out. Location and Date remain fully usable signed-out (no
change needed — neither ever depended on authentication).

## EventCard / Event Detail

Zero diff to either, this correction included. `EventCard` still renders
at most one relevance reason; Event Detail tags remain deferred (see the
original decision above — nothing about this correction changes that
reasoning).

## Navigation / State Preservation

Unchanged structural guarantee: `Navigator.push` on top of the same
`_EventsScreenState` preserves all four discovery dimensions (plus
`_discoveryFuture`) across an Event Detail visit and back, with no
manual save/restore code.

## Analytics

Unchanged event (`AnalyticsEvent.eventFilterApplied`), reused for BOTH
Advanced-Filters-Apply (as before, `eventCategory` populated only for a
single selected Type) and — new this correction — Location selection
(`countryCode` populated with the selected country's code), since the
analytics contract's own text explicitly covers "a controlled-vocabulary
filter (event type, country, etc.) is applied." No event fires for Date
changes (no existing property fits a date preset without expanding the
contract, deliberately deferred) or for Location/Filters clears. No new
`AnalyticsEvent`/property was added.

## Responsive / Accessibility

`test/event_filter_sheet_test.dart` (Social/Type/Theme only now),
`test/event_date_control_test.dart`, and manual review of the new
Location/Date/Filters row cover 320px width and 1.6x text scale with no
overflow. A second real defect was found and fixed during this
correction: `_EventDateSheet`'s `ListTile` rows sat inside a colored
`Container`/`DecoratedBox` with no `Material` ancestor between them,
which Flutter flags as "ListTile background color or ink splashes may be
invisible" — caught by the Date control's own tap-through widget tests.
Fixed by wrapping the sheet's content in `Material(type:
MaterialType.transparency)` positioned correctly INSIDE the decorated
Container (not outside it, which would have left the same DecoratedBox
sitting between the Material and the ListTiles). Accessibility: the
Location control retains `CountryFilterControl`'s own existing
Semantics; the Date control carries `Semantics(button: true, label:
'Date, <state>')`; the Filters button carries `Semantics(button: true,
label: 'Filters, N active')`; every advanced-sheet `_Option` carries
`Semantics(selected: ...)`. No control relies on color alone.

## Real Production Proof

Read-only `SELECT` queries only, via `supabase db query --linked`,
against the live 27-Event catalogue, re-run after this correction:

| Combination | Result |
|---|---|
| Netherlands + Wine | 5 |
| City search: "Amsterdam" (name/city/venue_name) | 6 |
| "Amsterdam" search + September 2026 date range | 2 |
| Netherlands + September 2026 date range | 11 |
| Netherlands + Wine + Dinner | 2 |
| "Amsterdam" search + Wine theme | 0 (a genuine, correct empty intersection — not a bug) |
| "Amsterdam" search + September 2026 + Dinner type | 0 (same) |

The two zero-result rows are deliberately included: they demonstrate
the exact class of outcome that was misread as "search lost" on device
before this correction — now, with Location/Date always visible next to
Search, that same zero-result outcome is legible as "these three
conditions together happen to match nothing," not as evidence of a
broken query.

## Database

`supabase migration list --linked`: 40/40 synced. `supabase db push
--linked --dry-run`: `"Remote database is up to date."` Zero migrations
this pass either — `EventLocationContext`/`EventDateControl` are pure
Dart/UI additions over the exact same `EventDiscoveryFilters.
countryCodes`/`.dateRange` fields Phase B already shipped.

## Validation

- `dart format --set-exit-if-changed .` — 412 files, 0 changed.
- `flutter analyze` — No issues found!
- `flutter test` — **1606 passed, 0 failed** (1598 prior Phase C baseline
  − 15 deleted summary tests − 2 net sheet-test change + 5 new
  `EventLocationContext` tests + 10 new `EventDateControl` tests + 4 new
  `advancedFilterDimensionCount` tests + 6 new composition-regression
  tests = 1606, exact arithmetic match). Nothing skipped or weakened.

## Files

New this correction:
- `lib/models/event_location_context.dart`
- `lib/features/events/widgets/event_date_control.dart`
- `test/event_location_context_test.dart`
- `test/event_date_control_test.dart`
- `test/events_discovery_composition_regression_test.dart`

Modified this correction:
- `lib/models/event_discovery_filters.dart` — added
  `advancedFilterDimensionCount` (Social/Type/Theme only); the original
  `activeDimensionCount` (all five) is untouched, still correct on its
  own terms, still passes every original Phase B test.
- `lib/features/events/widgets/event_filter_sheet.dart` — Location/Date
  groups removed; `EventFilterSheetResult` simplified to `{filters}`.
- `lib/features/events/event_discovery_filter_service.dart` — untouched
  this correction (failure-isolation logic already correct; only the
  screen-level widget consuming its exception was widened).
- `lib/features/events/events_screen.dart` — substantial rewrite: four
  independent state dimensions, `_effectiveFilters` composition getter,
  Location/Date/Filters row, unified `_DiscoveryFailureState`/
  `_NoFilterResultsState`/`_resetDiscovery`.
- `test/event_filter_sheet_test.dart` — updated for the reduced
  Social/Type/Theme-only sheet API.
- `test/event_discovery_filters_test.dart` — added
  `advancedFilterDimensionCount` coverage.

Deleted this correction:
- `lib/features/events/event_discovery_filter_summary.dart`
- `test/event_discovery_filter_summary_test.dart`

(The original Phase C pass's own file list — `event_filter_bar.dart`
deletion, `event_discovery_filter_service.dart`'s
`EventFilterResolutionException` addition, etc. — remains accurate and
is not repeated here.)

## Unrelated Exclusions

Same untracked research/enrichment artifacts noted throughout Phase B/C
remain present and untouched (`.claude/`, various European/Gault&Millau/
imagery-pilot docs, everything under `supabase/data/enrichment/`) — none
were created or modified by this correction, none were staged.

## Git

Nothing staged, committed, or pushed. `git status --short` shows exactly
the files listed above as modified/new/deleted, plus the same
pre-existing unrelated untracked files.

## Physical Device Checklist (Revised)

**CRITICAL — the reported bug**:
1. Search "Amsterdam" → select a Date → Amsterdam remains visibly active
   (search field unchanged) and results are the correct intersection.
2. Select a Date → search "Amsterdam" → identical semantic result to (1),
   regardless of order.

**LOCATION**: 3. Select Netherlands → Date → results restricted
correctly. 4. Netherlands + "Amsterdam" search → correct intersection
(never silently dropping Location).

**PRIMARY CONTROLS**: 5. Location / Date / Filters read clearly in one
row. 6. No clutter. 7. No redundant summary line underneath.

**ADVANCED**: 8. Wine. 9. Four Hands. 10. Friends Going. 11. Following.
12. Combined with Location/Date/Search.

**STATE**: 13. Open Event. 14. Back. 15. Search/Location/Date/Filters
all preserved.

**RESET**: 16. Clear Location only (via its own "All countries" tile).
17. Clear Date only (via its own "Any date" option). 18. Clear advanced
filters only (via the sheet's own "Clear all"). 19. Full recovery via
"Reset discovery" from a genuine zero-result state.

**RESPONSIVE**: 20. 320px / large text — the three-control row and both
sheets.

## Deferred Work

Unchanged from the original Phase C pass: Event Detail tag row, City
filtering, Admission filtering, past-Event browsing, `event_search_
performed` analytics wiring, a dedicated `events.event_type` index. This
correction adds no new deferrals beyond documenting (not implementing)
current-location and trip-destination Location modes.
