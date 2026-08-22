# EVENTS V2 STEP 8C — EVENTS IN PASSPORT PRE-FINAL

Implementation of the human-approved Step 8C architecture audit
(`EVENTS_V2_STEP_8C_EVENTS_IN_PASSPORT_AUDIT.md`): confirmed-attendance
Events promoted to a genuine first-class Passport content type. Nothing
staged, committed, or pushed; zero schema/RLS/migration changes; zero
production writes.

## APPROVED PASSPORT-LOCAL FILTER ARCHITECTURE

New `PassportFilterType` enum (`lib/features/passport/passport_filter_type.dart`):
`restaurants`, `hotels`, `events` — no `all` value, exactly one selected
at a time. Replaces `ExploreVenueType` as `PassportScreen`'s own filter
state entirely; `ExploreVenueType` is still used internally only where
`PassportFilterResult.of`/`PassportMetricLabels.forVenueType` require it
(mapped from the new type at the call site, restaurants/hotels only —
Events never passes through that API at all).

## WHY PASSPORTVENUE REMAINS UNTOUCHED

Per the approved audit: `PassportVenue`/`RestaurantVenue`/`HotelVenue`
are referenced across ~15 files and 6 features (Passport, Rankings, My
Map, Friends, Trips, Wishlist). No `EventVenue` was added, no new
`PassportVenue` subclass was created, and no exhaustive switch in any of
those other features was touched. `EventAttendanceEntry` remains its own
separate, additive type exactly as Step 4 established.

## WHY EXPLOREVENUE TYPE REMAINS UNTOUCHED

`ExploreVenueType.events` was never added. That enum is shared by
Explore, Wishlist, Rankings, and My Map — none of those files were
modified. Passport's own filter state is 100% `PassportFilterType` now;
`ExploreVenueType` only appears at the two narrow call sites that need
it for the unmodified `PassportFilterResult`/`PassportMetricLabels` APIs.

## ELIGIBILITY

Unchanged and reconfirmed: `EventConfirmedAttendanceRepository.
loadPassportEventAttendance` reads exclusively from
`event_confirmed_attendance` — the only place `EventAttendanceEntry` is
ever constructed. Interested/Going (`event_attendance`) is not
referenced anywhere in this diff. A new domain test
(`passport_event_attendance_domain_test.dart`, "eligibility neutrality"
group) confirms the two new pure functions never add or drop entries —
only reorder/filter by year — preserving whatever set the repository
already decided was eligible.

## EVENT SORTING

Fixed the confirmed real gap. New pure function
`sortEventAttendanceByEventDate` (in
`event_confirmed_attendance_repository.dart`) sorts by each entry's
`Event.startDate`, most recent first — reusing the canonical
`compareEventChronology` with its two operands swapped (descending from
that same ascending rule, tie-break included, not a second invented
comparator). `loadPassportEventAttendance`'s SQL `.order('confirmed_at',
...)` was removed — it no longer reflects the final order — and the
method now sorts in Dart after the batched Event fetch resolves (the
Event's own date isn't known until then). Proven directly: a fixture
where confirmation order and Event-date order are deliberately
opposite sorts correctly by Event date; the exact "Event 31 Dec 2026,
confirmed 1 Jan 2027" scenario files under its own Dec 2026 date.

## YEAR FILTER

Fixed the confirmed gap. New pure functions `eventAttendanceInYear`
(filters by `Event.startDate.year`, never `confirmedAt.year`) and
`availableEventAttendanceYears` (the Event-attendance equivalent of
`availableVisitYears`, kept as its own independent function rather than
merged into that shared helper — a year with only confirmed Event
attendance, and zero Restaurant/Hotel visits, is still selectable).
`PassportScreen.build()` now computes `years` from whichever source
matches the active `_filterType`; switching filters re-validates
`_selectedYear` against the newly-active filter's own year list,
resetting to "All time" only if the currently selected year isn't
represented there — mirroring the pre-existing reload-time reset logic,
now filter-aware too.

## EVENT-ONLY EMPTY-STATE FIX

Fixed the confirmed real bug. The old single `if (_loadError) ... else
if (_loading) ... else if (result.entries.isEmpty) ... else ...` chain
(gating ALL content, including the appended Events section below it) is
replaced with a chain where `isEvents` is checked immediately after
`_loading`, before `_loadError`/`result` are even consulted — so a user
on the Events filter never has their content gated by a Restaurant/Hotel
`SliverFillRemaining` at all, regardless of R/H's own load/error/empty
state. Each filter branch owns its own empty state:
Restaurants/Hotels keep their existing messages
("No restaurant visits yet."/"No hotel stays yet." or the year-scoped
variants); Events gets new, restrained copy ("No events in your Passport
yet." / "No events in your Passport in $year.") — never the old
venue-oriented "waiting for its first stamp" message, and never shown
merely because a DIFFERENT filter happens to be empty.

## EVENT CARD

`PassportEventCard` was not modified at all — reused exactly as it was.
Still shows: Event title, `formatEventDateRange` (date/date range, no
fabricated time), city/country, cover image (attendance photo → official
Event image → placeholder), rating when present. Still has no
Interested/Going, no Friends signals, no member count, no Step 8A
reason, no participant award badges, no Would Recommend label — all
already correctly absent before this task and confirmed unchanged.

## DATE-ONLY SUPPORT

Unaffected — `PassportEventCard` and the new sort/year functions both
key off `Event.startDate`, the canonical field for every precision
shape (DATE_ONLY, START_KNOWN/END_UNKNOWN, FULL_TIME, MULTI-DAY
DATE_ONLY). No new date logic was introduced; `formatEventDateRange`
(unchanged) still owns all display formatting.

## PHOTOS / RATING

Unchanged. Cover-photo resolution, rating display, and photo/storage
architecture were not touched — outside this task's scope, no gap
found.

## NAVIGATION

Unchanged — `PassportEventCard`'s own `onTap` still opens
`EventDetailScreen` with `sourceSurface: AnalyticsSourceSurface.
passport`. Back navigation is Flutter's own default stack behavior;
`PassportScreen`'s `_filterType`/`_selectedYear` state naturally survive
the push/pop (the screen stays mounted the whole session, per its own
existing architecture).

## EDIT / REMOVE

Unchanged, confirmed still correct: no edit or remove control was added
to the Passport card. Management remains exclusively via Event Detail's
existing `AttendanceDetailsSheet`/`deleteConfirmedAttendance` flow —
matching Restaurant/Hotel Passport's own identical "manage via Detail,
not via the Passport card" precedent, reconfirmed rather than changed.

## PRIVACY

Unchanged. RLS (`user_id = auth.uid() OR (visibility='friends' AND
is_friend(user_id))`) already guarantees the owner sees their own row
regardless of `visibility` — not touched, not re-verified via a new
query this pass (already directly confirmed in the architecture audit).

## CANCELLED / HISTORICAL

Unchanged, confirmed no regression: neither `loadPassportEventAttendance`
nor the two new pure functions apply any `Event.status` filter. A
confirmed attendance for a since-cancelled Event still passes through
`sortEventAttendanceByEventDate`/`eventAttendanceInYear` untouched — the
functions operate purely on dates and identity, never status.

## MY MAP CONSISTENCY

My Map was not modified. `VisitedMapScreen` still calls the exact same
`loadPassportEventAttendance` method Passport calls — now returning a
Dart-sorted (not SQL-sorted) list, which is irrelevant to My Map since
`eventMapPins` doesn't depend on input order (it maps each qualifying
entry to a pin independently). The canonical invariant (confirmed
attendance → Passport; confirmed attendance + coordinates → My Map; no
attendance → neither) is unchanged.

## METRICS

The Restaurant/Hotel metric strip (`places`/`countries`/`awards`) is now
wrapped in `if (!isEvents)` — hidden entirely when the Events filter is
selected, per the audit's own "strong preference: hide" conclusion. No
Event-specific metric was invented to fill the gap.

## LOADING / FAILURE

`_loadError` keeps its exact pre-existing meaning (Restaurant/Hotel load
failure only) and is now only consulted inside the non-Events branch of
the content chain — a Restaurant/Hotel load failure no longer has any
bearing on the Events filter's own content at all. Event load failure
was already isolated (own try/catch, never sets `_loadError`) and
remains so — a failed Event load simply leaves `_eventEntries` (and
therefore the Events filter's own content) empty, rendering that
filter's own restrained empty-state copy, never a raw error.

## ANALYTICS

No new taxonomy. `AnalyticsSourceSurface.passport` unchanged.
`passportItemCreated`/`passportItemRemoved` unchanged (still fired only
from `EventDetailScreen`'s confirm/delete flows). Filter-chip switching
is not tracked — Restaurant/Hotel chip switching was never tracked
either, so this preserves, rather than breaks, existing consistency.

## HISTORICAL INTEGRITY FOLLOW-UP

**Not solved in this task, by design** — documented as a distinct
backlog item, exactly as instructed:

**A. Event hard-delete**: `event_confirmed_attendance.event_id` is
`ON DELETE CASCADE`. Deleting an Event row deletes every user's genuine
confirmed-attendance history for it.

**B. Event unpublication**: `loadPassportEventAttendance`'s `events`
query is subject to `events`' own RLS (`moderation_status =
'published'`). If an Event with confirmed attendance is later archived/
rejected, that query silently returns no row for it — the
`event_confirmed_attendance` row itself is untouched, but the user's own
Passport entry for it disappears from view with no error or indication.

Both require a separate, future architecture/product decision (any real
fix plausibly touches RLS or deletion semantics) — RLS and deletion
behavior were not modified in this task.

## DATABASE

migrations created = 0. migrations deployed = 0. schema changes = 0. RLS
changes = 0. production writes = 0.

## VALIDATION

`dart format --set-exit-if-changed .`: clean. `flutter analyze`: no
issues at every intermediate step. `flutter test`: **1506 passed, 0
failed** (1492 baseline + 14 new: 12 in
`passport_event_attendance_domain_test.dart`, 2 in
`passport_filter_type_test.dart`). All pre-existing Passport tests
(`passport_view_model_test.dart`, `passport_event_card_test.dart`,
`passport_cards_test.dart`, `passport_collection_header_test.dart`)
re-run and pass unchanged, confirming no regression to
`PassportFilterResult`/`PassportEventCard`/the collection header. No
test weakened.

## FILES

New: `lib/features/passport/passport_filter_type.dart`,
`test/passport_event_attendance_domain_test.dart`,
`test/passport_filter_type_test.dart`,
`docs/Architecture/Events/EVENTS_V2_STEP_8C_EVENTS_IN_PASSPORT_PRE_FINAL.md`
(this file). Modified:
`lib/features/passport/passport_screen.dart`,
`lib/data/repositories/event_confirmed_attendance_repository.dart`.

## PRODUCTION TEST LIMITATION

Unchanged from the audit: `event_confirmed_attendance` = 0 rows in
production; no Event has concluded yet. No production fixture was
created. Physical-device verification of the Events filter's real
content is deferred to a genuine, naturally-occurring confirmed
attendance.

## GIT

Nothing staged, committed, or pushed. Known unrelated enrichment/
research artifacts remain untouched.

## PHYSICAL DEVICE CHECKLIST

**A. Current device regression**: Restaurants Passport unchanged; Hotels
Passport unchanged; the three filter chips render cleanly; EVENTS can be
selected; the empty Events state looks intentional (not the old
"waiting for its first stamp" copy); switching Restaurants → Hotels →
Events → Restaurants shows no stale/mixed content; year filter doesn't
break when switching filters; no overflow at 320px/1.6x text scale.

**B. Later, once a real confirmed Event attendance exists**: it appears
under EVENTS; correct Event date (no fabricated time); attendance photo
cover (or official image / placeholder fallback); rating if present; tap
→ Event Detail; back → Passport with EVENTS still selected; remove
(via Event Detail) removes it from Passport on next load; reload
persistence.

## DECISION

Every approved product decision was implemented exactly as scoped: a
new Passport-local `PassportFilterType` (never `ExploreVenueType`,
never a `PassportVenue`/`EventVenue` change), Events sorted by their own
occurrence date, year filtering extended to Events using `startDate`,
the empty-state bug fixed by making each filter's content fully
independent, `PassportEventCard` reused verbatim, and the two known
historical-integrity risks documented as an explicit, unsolved backlog
item rather than silently patched. No schema, RLS, or migration work
was required or performed.

EVENTS V2 STEP 8C — EVENTS PROMOTED TO FIRST-CLASS PASSPORT EXPERIENCE,
CONFIRMED-ATTENDANCE SEMANTICS PRESERVED, READY FOR PHYSICAL-DEVICE
REGRESSION REVIEW
