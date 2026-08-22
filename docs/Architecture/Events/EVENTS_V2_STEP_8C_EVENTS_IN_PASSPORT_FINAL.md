# EVENTS V2 STEP 8C — FINAL REPORT

Physical-device-approved final record of Step 8C: confirmed-attendance
Events are now a first-class Passport content type. Supersedes nothing
in the audit (`EVENTS_V2_STEP_8C_EVENTS_IN_PASSPORT_AUDIT.md`) or the
pre-final report (`..._PRE_FINAL.md`) — both remain the historical
record of how this was designed and implemented; this document is the
closing summary once human approval was recorded.

## PHYSICAL DEVICE APPROVAL

**Physically verified now**: Passport shows the three intended filters
(RESTAURANTS/HOTELS/EVENTS); Restaurants behavior correct; Hotels
behavior correct; Events filter selectable; Events shows the intended
restrained empty state; filter switching works cleanly; Restaurant/Hotel
metrics correctly absent when Events is selected; no visual/layout
regressions; overall Passport interaction approved.

**Deferred real-data verification** (production has 0 confirmed Event
attendances — no Event has concluded yet): confirmed Event card
rendering with real content; the Event-year filter appearing from
genuine attendance data; Event attendance photo/rating rendering;
Passport Event → Event Detail → back navigation with real content;
removal/persistence of a genuine confirmed Event attendance. None of
these are failed tests — they are correctly untestable against real
data today, and automated coverage is the accepted approval gate for
them at this stage.

## FINAL PRODUCT CONTRACT

Re-verified directly against current HEAD, not assumed: `PassportVenue`
(`lib/models/passport_venue.dart`) has zero diff. `ExploreVenueType`
(`lib/features/explore/models/explore_filters.dart`) has zero diff. A
full diff scan found no reference to the `event_attendance` (intent)
table anywhere in the Step 8C change set. `lib/features/map`,
`lib/features/rankings`, `lib/features/friends`, `lib/features/trips`,
`lib/features/wishlist` all show zero diff. Every one of the approved
product-contract points holds exactly as implemented.

## PASSPORT-LOCAL FILTER

`PassportFilterType.restaurants/hotels/events` — no `all` value.
Passport's own filter state; `ExploreVenueType` is only referenced at
two narrow call sites (`PassportFilterResult.of`/`PassportMetricLabels
.forVenueType`, Restaurants/Hotels mapping only — Events never passes
through either).

## PASSPORTVENUE BOUNDARY

Untouched — reconfirmed via `git diff`, zero lines changed.

## EXPLOREVENUE BOUNDARY

Untouched — reconfirmed via `git diff`, zero lines changed. No `.events`
value was ever added.

## ELIGIBILITY

`event_confirmed_attendance` remains the sole source —
`EventAttendanceEntry` can only ever be constructed from a confirmed-
attendance row. Interested-only, Going-only, and Interested+Going all
remain structurally ineligible — there is no code path from
`event_attendance` into Passport at all. Attendance `source` (manual/
post_event_prompt/trip_completion) has no bearing on eligibility — no
source filter exists anywhere in the query or the new pure functions.

## EVENT SORTING

`sortEventAttendanceByEventDate` — `Event.startDate` descending, most
recent first, via `compareEventChronology` with operands swapped (no
second comparator). Deterministic same-date tie-break confirmed by
test (the swapped comparator's own tie-break, also reversed, which is
the honest consequence of reusing one canonical rule rather than
inventing a separate ordering for ties).

## YEAR FILTER

`eventAttendanceInYear`/`availableEventAttendanceYears` — both key off
`Event.startDate.year`, never `confirmedAt.year`. Independent of
Restaurant/Hotel's own year list. **Why no Event year selector is
currently visible on a physical device**: the year control only renders
`if (years.isNotEmpty)`, and `availableEventAttendanceYears` correctly
returns an empty list when there are zero confirmed Event attendances
(production's actual current state) — this is the *correct* behavior,
not a bug: a meaningless empty year dropdown is exactly what this
condition is designed to prevent. Once a genuine confirmed attendance
exists, its Event's own year will appear in the selector automatically,
proven directly by `passport_event_attendance_domain_test.dart`'s
"a year with ONLY confirmed Event attendance... is still available" and
"every distinct year... descending" tests. Restaurant/Hotel year
behavior is completely unchanged.

## EVENT-ONLY EMPTY STATE FIX

Confirmed fixed and unchanged since pre-final: the Events branch is
checked immediately after the shared `_loading` check, before
`_loadError`/`result` (both Restaurant/Hotel-only) are ever consulted —
a user with 0 Restaurant/Hotel history and confirmed Event attendance
can never have that content hidden behind a Restaurant/Hotel
`SliverFillRemaining` again, structurally, not just in the currently-
zero-Events case verified on device.

## EVENT CARD

`PassportEventCard` — zero modifications, reconfirmed via `git diff`
(the file doesn't even appear in the Step 8C change set). Cover-photo →
official image → placeholder priority, rating display, date/date range,
city/country, tap → `EventDetailScreen` all unchanged. No Interested/
Going/Friends/member-count/Step-8A-reason/participant-recognition/Would-
Recommend was added.

## DATE-ONLY SUPPORT

Unaffected — every new function and the unmodified card both key off
`Event.startDate`/`formatEventDateRange`, the same canonical fields
every other Event-date display in this app already uses. No new date
logic, no fabricated timestamps, `confirmed_at` never substitutes for
Event occurrence time anywhere.

## PHOTOS / RATING

Unchanged — no gap, not touched.

## NAVIGATION

Unchanged — existing `EventDetailScreen`, `AnalyticsSourceSurface.
passport`. Back navigation is Flutter's default stack behavior;
`_filterType`/`_selectedYear` survive the round trip since the screen
stays mounted for the app session.

## EDIT / REMOVE

Unchanged — management remains exclusively via Event Detail, matching
Restaurant/Hotel Passport's own identical precedent. No card-level
action was added.

## PRIVACY

Unchanged — RLS (`user_id = auth.uid() OR (visibility='friends' AND
is_friend(user_id))`) already guarantees owner visibility regardless of
`visibility`. Not modified, not re-touched.

## CANCELLED / HISTORICAL

Unchanged — no `Event.status` filter exists anywhere in
`loadPassportEventAttendance` or the two new pure functions. A
confirmed attendance for a since-cancelled Event remains fully visible.

## MY MAP CONSISTENCY

Untouched (zero diff, reconfirmed). Still calls the identical
`loadPassportEventAttendance` method; `eventMapPins` is order-
independent, so the Dart-side sort change has no effect on My Map's own
rendering. Invariant reconfirmed: confirmed attendance → Passport;
confirmed attendance + coordinates → My Map; no attendance → neither.

## METRICS

Restaurant/Hotel metric strip hidden entirely (`if (!isEvents)`) — no
Event-specific metric was invented, confirmed on physical device.

## LOADING / FAILURE

`_loadError` scoped to the non-Events branch only; Event load failure
remains independently isolated (own try/catch), silently empties that
filter's own content, never surfaces a raw error.

## ANALYTICS

No new taxonomy. `AnalyticsSourceSurface.passport`,
`passportItemCreated`/`passportItemRemoved` all unchanged. Filter-chip
switching is not tracked, consistent with the pre-existing (also
untracked) Restaurant/Hotel chip behavior.

## PASSPORT HISTORICAL INTEGRITY FOLLOW-UP

Two real, unresolved findings, explicitly preserved and NOT addressed
in Step 8C:

**A. Hard delete**: `event_confirmed_attendance.event_id` is `ON DELETE
CASCADE` — deleting an Event row deletes every user's genuine confirmed
Passport history for it.

**B. Unpublish**: `loadPassportEventAttendance`'s `events` query is
gated by `events`' own RLS (`moderation_status = 'published'`). An
Event with confirmed attendance that's later archived/rejected silently
stops resolving — the `event_confirmed_attendance` row survives
untouched, but the user's own Passport entry for it disappears from
view, with no error.

No FK semantics, soft-delete, snapshotting, moderation, or RLS change
was made. **Recommended future workstream: EVENTS V2 — PASSPORT
HISTORICAL INTEGRITY** — not started here.

## DATABASE

migrations created = 0. migrations deployed = 0. schema changes = 0. RLS
changes = 0. production writes = 0. `event_confirmed_attendance` read
count at finalization: **0** — unchanged from pre-final, confirmed
read-only, not modified. 39/39 migrations synced; "Remote database is
up to date."

## VALIDATION

`dart format --set-exit-if-changed .`: clean. `flutter analyze`: no
issues. `flutter test`: **1506 passed, 0 failed** — matches the
pre-final baseline exactly, re-confirmed at finalization (re-run
verified this report's own numbers, not assumed from the prior turn).

## FILES

New: `lib/features/passport/passport_filter_type.dart`,
`test/passport_event_attendance_domain_test.dart`,
`test/passport_filter_type_test.dart`,
`docs/Architecture/Events/EVENTS_V2_STEP_8C_EVENTS_IN_PASSPORT_AUDIT.md`,
`docs/Architecture/Events/EVENTS_V2_STEP_8C_EVENTS_IN_PASSPORT_PRE_FINAL.md`,
`docs/Architecture/Events/EVENTS_V2_STEP_8C_EVENTS_IN_PASSPORT_FINAL.md`
(this file). Modified: `lib/features/passport/passport_screen.dart`,
`lib/data/repositories/event_confirmed_attendance_repository.dart`.

## UNRELATED EXCLUSIONS

Confirmed left untracked, untouched, unstaged:
`EVENTS_CONTENT_ENRICHMENT_4_EVENTS_PRE_APPLY.md`,
`GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md`,
`EUROPEAN_EVENT_ENRICHMENT_SPRINT_AUDIT.md`,
`EUROPEAN_EVENT_BATCH_1_PRE_APPLY.md`,
`EUROPEAN_EVENT_FIRST_DATE_ONLY_PILOT_PRE_APPLY.md`, and every file
under `supabase/data/enrichment/`.

## GIT

Commit hash, message, and push result recorded in the chat final report
accompanying this document's publication (this file is written before
staging, so the exact hash isn't yet known at write time).

## DEFERRED REAL-DATA VERIFICATION

Restated plainly: production has zero confirmed Event attendances and
no Event has concluded yet (earliest, 't Preuvenemint, ends
2026-08-30). Confirmed Event card rendering, the Event-year selector
with real data, attendance photo/rating display, Event navigation with
real content, and removal/persistence of a genuine confirmed attendance
all remain automated-coverage-only until a genuine confirmed attendance
occurs naturally. No production fixture was created to shortcut this.

## NEXT

NEXT WORKSTREAM:
EUROPEAN EVENT ENRICHMENT — CONTINUE PRODUCTION CATALOGUE EXPANSION

Return to the curated European Event inventory and continue inserting
verified Events now that date-only support, personalized discovery,
reverse hosted-event discovery, and first-class Passport integration
are all live.

Kept separately in backlog, not combined with enrichment work:
EVENTS V2 — PASSPORT HISTORICAL INTEGRITY (hard-delete preservation,
unpublish preservation).

EVENTS V2 STEP 8C — EVENTS IN PASSPORT FINALIZED, PHYSICAL-DEVICE
REGRESSION APPROVED, CONFIRMED-ATTENDANCE SEMANTICS PRESERVED,
COMMITTED AND PUSHED
