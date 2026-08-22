# EVENTS V2 STEP 8C — EVENTS IN PASSPORT ARCHITECTURE + PRODUCT AUDIT

Read-only architecture and product audit for making confirmed-attendance
Events a first-class part of Passport. Nothing implemented, migrated,
staged, committed, or pushed — every finding below is derived from a
fresh read of current code and live production data.

## PASSPORT TODAY

`PassportScreen` (deep-green canvas): header (title + My Map icon) →
venue-type filter chips (`ExploreVenueType.all/restaurants/hotels`) →
year filter (`YearFilterControl`, only shown when
`availableVisitYears(...)` is non-empty) → a 3-metric strip
(`places`/`countries`/`awards`, computed only from the Restaurant/Hotel
`PassportFilterResult`) → "YOUR COLLECTION" section title → a
`SliverList` of `PassportRestaurantCard`/`PassportHotelCard` (via
`PassportFilterResult.of`, sorted by most-recent visit/stay date across
both types interleaved, tie-broken alphabetically) → **then, appended
after that entire list**, if `_eventEntries` is non-empty: its own
"EVENTS" eyebrow + its own `SliverList` of `PassportEventCard`. Loaded
via `VisitedRepository.loadPassportVenues` (Restaurant/Hotel) and
`EventConfirmedAttendanceRepository.loadPassportEventAttendance`
(Events) — two independent calls in the same `_load()`, the Event one
wrapped in its own try/catch so a failure never blocks Restaurant/Hotel
Passport. Reloads on first mount, pull-to-refresh, and
`didPopNext()` (returning from Restaurant/Hotel/Event Detail).

## EXISTING STEP 4 EVENT PASSPORT WORK

**Events are already technically present in Passport today** — this is
not a build-from-scratch task. What already exists and works: the
`EventConfirmedAttendanceRepository`/`EventAttendanceEntry` model, the
"EVENTS" section in `passport_screen.dart`, `PassportEventCard`
(cover-photo → official image → placeholder priority, rating display,
tap → `EventDetailScreen` with `sourceSurface: AnalyticsSourceSurface.
passport`), and the underlying `event_confirmed_attendance` writes/
reads/deletes (`confirmAttendance`/`updateAttendanceDetails`/
`deleteConfirmedAttendance`), all wired from `EventDetailScreen`.
What's missing for Events to feel genuinely first-class is enumerated
below (First-Class Definition / Implementation Options) — it is a set
of specific, bounded gaps, not a new feature.

## PASSPORTVENUE BOUNDARY

`PassportVenue` (`lib/models/passport_venue.dart`) is a small sealed
class, exactly 2 variants: `RestaurantVenue`, `HotelVenue`. A fresh grep
(not trusting the Step 4 audit's own earlier count) found it referenced,
pattern-matched, or exhaustively switched on in **at least 15 files
across 6 different features**: Passport (`passport_screen.dart`,
`passport_view_model.dart`), Rankings (`rankings_view_model.dart`,
`personal_rankings_tab.dart`), My Map (`map_pin.dart`,
`visited_map_screen.dart`, `venue_preview_sheet.dart`), Friends
(`friend_profile_screen.dart`, `friend_visit_tile.dart`,
`friend_wishlist_tile.dart`), Trips (`trip_detail_screen.dart`,
`planned_trips_screen.dart`, `planned_venue_row.dart`,
`plan_venue_sheet.dart`), Wishlist (`wishlist_screen.dart`,
`wishlist_view_model.dart`, `wishlist_venue_row.dart`) — plus the
repositories that construct these objects in the first place
(`VisitedRepository`, `PlannedTripsRepository`, `WishlistRepository`).
This is a materially larger blast radius than the original Step 4
estimate ("~10 exhaustive switch sites") — closer to 30 individual
pattern-match/switch expressions.

**A second, independent finding strengthens the same conclusion from a
different angle**: the venue-type filter chips on Passport today
(`ExploreVenueType.all/restaurants/hotels`) are not a Passport-local
type — `ExploreVenueType` is shared across **Explore, Wishlist,
Rankings, My Map, and Passport** (confirmed by a fresh grep of every
consumer). Adding `.events` to *that* enum, to give Passport a
literal third filter value, would force Explore's own venue-type
selector, Wishlist, Rankings, and My Map's filter model to all handle a
new case too — none of which have any conceptual relationship to
Events.

**Recommendation: Option A, keep Events additive and separate from
`PassportVenue`** — reconfirmed, more strongly than the original Step 4
reasoning. Option B (fold Event into `PassportVenue`) would ripple
through Rankings, My Map, Friends, Trips, and Wishlist — none of which
have any product reason to handle an "Event" case (My Rankings doesn't
rank Events; Wishlist doesn't wishlist Events; a Trip doesn't plan an
Event visit the way it plans a Restaurant reservation). Option C (a new
`PassportItem` abstraction above Restaurant/Hotel/Event) would only be
justified if Passport itself needed uniform polymorphic handling across
all three types for many operations — it doesn't: Passport's own
Restaurant/Hotel and Event code paths are already, and can remain,
two independently simple lists rendered on one screen. Introducing a
third abstraction layer to unify two already-small, already-working
list-rendering blocks is complexity with no corresponding benefit.

## CONFIRMED ATTENDANCE SOURCE

Live schema, `event_confirmed_attendance`: PK `id`; `event_id uuid NOT
NULL FK → events(id) ON DELETE CASCADE`; `user_id uuid NOT NULL FK →
profiles(id) ON DELETE CASCADE`; `confirmed_at timestamptz NOT NULL
DEFAULT now()`; `rating smallint NULL CHECK (1-10)`; `comment text
NULL`; `visibility text NOT NULL DEFAULT 'private' CHECK (private/
friends)`; `source text NOT NULL DEFAULT 'manual' CHECK (manual/
post_event_prompt/trip_completion)`; `converted_from_planned_venue_id
uuid NULL UNIQUE FK → planned_venues(id) ON DELETE SET NULL` (a Trip-
completion-conversion field, not otherwise relevant to this audit's
scope); `created_at timestamptz NOT NULL DEFAULT now()`;
`would_recommend boolean NULL`. `UNIQUE(event_id, user_id)`. RLS:
`SELECT` → `user_id = auth.uid() OR (visibility='friends' AND
is_friend(user_id))`; `INSERT`/`UPDATE`/`DELETE` → owner-only. **Every
field Passport needs already exists — no migration required.**

## PRODUCTION DATA

Read live, right now: `event_confirmed_attendance` = **0 rows**.
Attendance photos (`photos` where `attendance_id IS NOT NULL`) = **0**.
All 5 production Events remain `status = 'upcoming'` — none has
concluded yet (the earliest, 't Preuvenemint, runs 2026-08-27 to
2026-08-30). **There is currently no real confirmed Event attendance to
test Step 8C against on a physical device, and none can honestly exist
yet** — `resolveAttendanceUiState` (below) already gates the
manual-confirm UI behind the Event having ended, so the app itself
offers no path to create one before then, for any Event. No production
fixture was created by this audit.

## CURRENT EVENT PASSPORT UX

Rendered unconditionally below the Restaurant/Hotel list whenever
`_eventEntries.isNotEmpty` — **not gated by the `ExploreVenueType`
filter chips at all** (selecting "Restaurants" still leaves the EVENTS
section visible below, since its render condition never checks
`_venueType`). Not included in the year filter (`availableVisitYears`
is computed only from Restaurant/Hotel `visits`). Not included in the
metric strip. Has no own empty state (simply absent when there are zero
confirmed Events — consistent with this codebase's established
"omit rather than clutter with a placeholder" convention elsewhere, see
First-Class Definition below for why this is judged correct, not a gap).

## FIRST-CLASS DEFINITION

Evaluated against the task's own suggested standard:

- **Directly selectable/discoverable alongside Restaurants/Hotels** —
  partially: always visible (not hidden behind a filter), but not
  reachable via the venue-type chips the way Restaurants/Hotels are; a
  user filtering to "Restaurants" still sees an unrelated EVENTS
  section below, which reads as slightly inconsistent with what
  selecting a filter chip implies elsewhere in this app.
- **Own empty state** — judged correct AS IS, not a gap: an explicit
  "No events attended yet" message on every Restaurant/Hotel-only
  Passport (the overwhelming majority of users, especially before
  Batch-1 ships) would be exactly the kind of low-value clutter this
  codebase has deliberately avoided everywhere else (`HostedEventsSection`,
  `AtThisEventSection`, `VenueAboutSection`). The real problem isn't
  "Events lacks its own empty state" — it's the confirmed layout bug
  below.
- **Own count if current tabs use counts** — the metric strip currently
  shows 0 Event-derived numbers; not necessarily a gap (see Search /
  Counts below).
- **Consistent card design** — already true: `PassportEventCard` already
  shares `CsPlaceCard` with `PassportRestaurantCard`/`PassportHotelCard`.
- **Historical sorting** — **a real, confirmed gap**: Events currently
  sort by `confirmed_at DESC` (when the attendance row was created),
  while Restaurant/Hotel Passport sorts by `latestVisit` (when the
  experience itself happened). A post-event-prompt confirmation logged
  weeks after an Event, or a manually back-logged confirmation, would
  sort out of true chronological order relative to when it actually
  occurred — inconsistent with how Restaurant/Hotel Passport already
  represents "experience history."
- **Direct Event navigation** — already correct.
- **Rating/photo persistence** — already correct.
- **Remove from Passport** — already correct, via the established
  precedent, not a gap (see Remove From Passport below).
- **No dependence on scrolling past Restaurant/Hotel's own empty
  state** — **a real, confirmed bug** (see Empty State below).

## OPTIONS CONSIDERED

**Option 1 (minimal fix)**: keep the existing separate EVENTS section,
fix the empty-state bug, fix Event sort order to use the Event's own
date. **Option 2**: add Events as a third Passport-local tab/filter
(a NEW enum, never `ExploreVenueType`), `EventAttendanceEntry` stays
separate from `PassportVenue`. **Option 3**: a new `PassportItem`
abstraction — rejected above (Passport Boundary section). **Option 4**:
fold Event into `PassportVenue` — rejected above.

## RECOMMENDED PRODUCT UX

**Option 1, with one addition from Option 2's own thinking**: keep the
EVENTS section as its own additive block (not forced through
`PassportVenue`), but stop showing it unconditionally regardless of the
selected filter — instead, treat "Events" as a genuine fourth choice in
Passport's OWN filter row, using a **new Passport-local enum**
(explicitly not `ExploreVenueType`, for the reasons above), so
selecting "Restaurants" correctly hides Events and vice versa, and
selecting "Events" shows only the EVENTS section (empty state judgment
call: still omit an explicit placeholder when truly nothing has ever
been attended, matching the rest of this codebase, but the currently-
selected-filter's own emptiness should not read as "Passport has
nothing" when another filter has content — see Empty State). This is
the smallest structural change that makes Events genuinely equivalent
to Restaurants/Hotels as a first-class, filterable Passport lane,
without touching `PassportVenue`, `ExploreVenueType`, or any of
Rankings/My Map/Friends/Trips/Wishlist.

## SORTING

Recommend switching `loadPassportEventAttendance`'s order from
`confirmed_at DESC` to the Event's own chronological date — `event.
startDate` (canonical, per Event Time Precision), consistent with
Restaurant/Hotel Passport's own "sort by when it happened" convention.
For Passport specifically (history, most-recent-first — the same
direction Restaurant/Hotel already use), that means descending by
`startDate`, tie-broken by `compareEventChronology`'s own existing
same-date logic (known-time-before-unknown, then id) reversed, or a
locally inverted comparator — either is fine; the important invariant
is: never introduce a second, independently-invented chronological
rule, only ever this same canonical helper, direction-reversed for
"most recent first" the way `PassportFilterResult` already reverses its
own venue sort.

## YEAR FILTER

Not currently participating at all — `availableVisitYears` only scans
Restaurant/Hotel `visits`. If Recommended Product UX's Events filter
lane ships, Events should participate in the SAME year control using
`event.startDate`'s year (never `confirmed_at`'s year — an Event
attended in December but confirmed in January must file under the year
it happened, not the year it was logged) — matching the task's own
explicit instruction. This is a real but bounded addition:
`availableVisitYears` (or an Event-aware sibling) needs to also
consider `_eventEntries`.

## EVENT CARD

`PassportEventCard` re-confirmed directly from source, unchanged since
Step 4: cover-photo → official Event image → branded placeholder
priority; `CsPlaceCard` shell (same as Restaurant/Hotel); eyebrow =
event type; title = Event name; subtitle = city, country; footer = date
range (`formatEventDateRange`) + rating if present ("Your rating: X/10",
`mutedBrassOnLight`); tap → `EventDetailScreen`. No award row (correct
— Events have no Michelin/Key concept of their own). Nothing here needs
to change for first-class integration beyond the sort-key fix above (a
repository-level change, not a card change).

## PHOTOS / RATING / RECOMMENDATION

Photos: cover-photo resolution already correct (most-recent attendance
photo, signed URL, graceful fallback via `errorBuilder`). Max-6 and
storage cleanup live in `PhotoRepository`/`deleteAllPhotosForAttendance`
— unaudited in detail here since Step 8C doesn't touch photo
architecture, no gap surfaced. Rating: shown when present, omitted
otherwise — correct. **Would Recommend**: not currently shown on
`PassportEventCard` at all. Recommend leaving it off the card — a
Yes/No badge next to a numeric rating risks reading as two competing
signals on a small card; it remains fully visible/editable on Event
Detail, which is where nuance belongs.

## EDIT EXPERIENCE

**Already resolved, no gap**: Passport has no card-level edit action
for Events — and neither does Restaurant/Hotel Passport (`CsPlaceCard`
itself has no overflow-menu slot; visit/stay management already lives
exclusively in Restaurant/Hotel Detail's own history section, never on
the Passport card). Event Detail already owns rating/would-recommend/
photo/comment editing via its existing `AttendanceDetailsSheet`/`onEdit`
flow. Recommend Option A explicitly: Passport navigates to Event
Detail for all management, matching the exact precedent Restaurant/
Hotel Passport already set — not "the smallest MVP," but the *already-
established, consistent* pattern.

## REMOVE FROM PASSPORT

Re-audited directly: `EventConfirmedAttendanceRepository.
deleteConfirmedAttendance` — deletes Storage photo objects first
(while still queryable via `attendanceId`), then deletes the attendance
row, which cascades `photos` rows automatically
(`photos.attendance_id ... ON DELETE CASCADE`), scoped by both `id` and
`user_id`. Confirmed: does NOT recreate a Going intent row. **Currently
called only from `EventDetailScreen`** (line 639) — not from Passport
at all, which, per Edit Experience above, matches Restaurant/Hotel's own
identical pattern (no direct remove action on the Passport card
itself). No change recommended.

## PRIVACY

Confirmed directly from RLS: `SELECT` policy is `user_id = auth.uid()
OR (visibility='friends' AND is_friend(user_id))` — the owner clause is
independent of `visibility`, so a user's own `private` confirmed
attendance is always visible to themselves. No gap.

## CANCELLED / HISTORICAL EVENTS

Confirmed: `loadPassportEventAttendance` applies no `status` filter of
any kind — a confirmed attendance for a since-cancelled Event remains
in the query result and renders normally. Matches the required rule
exactly ("confirmed attendance remains in Passport regardless of
current Event status") with zero additional code needed.

## MODERATION / DELETION RISK

Two distinct, both real, findings from live schema — reported, not
solved (no schema/RLS change is in scope for this audit):

1. **Event deletion**: `event_confirmed_attendance.event_id` is `ON
   DELETE CASCADE`. If an Event row is ever hard-deleted from
   `events`, every confirmed attendance pointing at it — genuine
   personal Passport history — is deleted too, silently, with no
   separate confirmation step.
2. **Event unpublication**: `loadPassportEventAttendance`'s second
   query reads `events` directly, which carries RLS `moderation_status
   = 'published'`. If an Event a user has genuine confirmed attendance
   for is later archived/rejected/unpublished, that `events` query
   returns no row for it, `eventsById[...]` is null, and
   `loadPassportEventAttendance`'s own `if (eventsById[...] != null)`
   guard silently drops that entry from the result — **the
   `event_confirmed_attendance` row itself is untouched in the
   database, but the user's own Passport entry for it disappears from
   view, with no error and no indication anything changed.**

Both are real risks to genuine personal history and worth a deliberate
human product decision (e.g., should a user's own confirmed-attendance
read path see their own row regardless of the linked Event's
moderation status?) — not something this audit resolves or recommends
a specific fix for, since any fix plausibly touches RLS/query shape,
explicitly out of this audit's scope.

## MY MAP CONSISTENCY

Confirmed directly in code, not merely by convention:
`VisitedMapScreen` calls the exact same
`EventConfirmedAttendanceRepository.loadPassportEventAttendance` method
Passport itself calls, then adapts the same `EventAttendanceEntry` list
via `eventMapPins` (coordinate-gated: an Event pin renders only when
the Event's own `latitude`/`longitude` are both non-null — never
substituted from a linked venue). One canonical source, two
renderings. No separate attendance definition exists anywhere.

## DATE-ONLY SUPPORT

Already correct: `PassportEventCard` renders `formatEventDateRange
(event)` — the same canonical, precision-aware Phase B/C formatter
every other Event-date display in this app uses. All four precision
shapes (date-only, start-known/end-unknown, full-time, multi-day
date-only) already render correctly with no fabricated time, since this
is the identical function already proven for Event Detail/`EventCard`/
`HostedEventsSection`.

## EMPTY STATE

**Confirmed, real bug, still present**: `passport_screen.dart`'s empty-
state branch checks `result.entries.isEmpty` — the Restaurant/Hotel
`PassportFilterResult` alone; it does not consider `_eventEntries` at
all. A user with zero restaurant/hotel history but genuine confirmed
Event attendance would see `SliverFillRemaining(child: PassportEmptyState
(message: "Your passport is waiting for its first stamp."))` — a
factually wrong message, since they DO have Passport content — with
their actual EVENTS section still technically reachable by scrolling
past that full-viewport message (`SliverFillRemaining` doesn't block
further scrolling), but not remotely obvious that it's there. This
should be fixed as part of Step 8C: the empty-state condition must
consider both Restaurant/Hotel AND Event content together (or, under
Recommended Product UX's per-filter-lane approach, each filter lane
gets its own correctly-scoped empty check).

## SEARCH / COUNTS

Passport has no search today (confirmed by absence — no search field/
controller anywhere in `passport_screen.dart`), so Event searchability
is not a gap relative to existing functionality; nothing to build.
Counts: the 3-metric strip (`places`/`countries`/`awards`) is explicitly
computed only from Restaurant/Hotel stats today. Recommend NOT folding
Events into those same 3 numbers (an Event isn't a "place" the same way
a venue is, and it has no stars/Keys "award" to sum) — if Events
becomes its own filter lane, that lane can show its own small,
genuinely meaningful metric set (e.g. events attended, countries) or
none at all; do not invent a metric merely to fill the strip.

## REPOSITORY / QUERY SHAPE

`loadPassportEventAttendance` re-read directly: **3 queries total,
regardless of row count** — (1) `event_confirmed_attendance` for the
user, ordered; (2) one batched `events` lookup (`inFilter('id', ...)`);
(3) one batched `photos` lookup for cover images
(`inFilter('attendance_id', ...)`). No N+1. Explicit column lists
throughout (`_attendanceColumns`), never `select('*')`. RLS is the only
security boundary — no `SECURITY DEFINER` anywhere. The only repository
change Step 8C's own recommendations require is the sort-key switch
(order by `events.start_date` instead of `event_confirmed_attendance.
confirmed_at` — note this moves the `ORDER BY` onto a column in the
*second* query's own table, which PostgREST can't do directly across
two separate `.from()` calls the way this method is currently
structured, so the actual sort would need to happen in Dart, after both
batched fetches, mirroring `upcomingHostedEvents`'s own "fetch, then
sort in Dart" shape from Step 8B).

## PERFORMANCE

At 10/100/1000 confirmed attendances, the 3-query shape stays flat —
no O(n) query pattern exists (every batch is `inFilter`, never a
per-row query). Sorting in Dart post-fetch (per the recommendation
above) is O(n log n) on an in-memory list, trivial at any of these
sizes. No SQL RPC is remotely justified yet.

## ANALYTICS

`AnalyticsSourceSurface.passport` already exists and is already used by
`PassportEventCard`'s own `EventDetailScreen` navigation — no gap.
`AnalyticsEvent.passportItemCreated`/`passportItemRemoved` already
exist AND are already fired, from `EventDetailScreen`'s
`confirmAttendance`/`deleteConfirmedAttendance` flows and
`events_screen.dart` — the state-changing action sites, which is the
correct place for them, not Passport itself (which only displays
already-confirmed state). No new taxonomy needed anywhere.

## DATABASE DECISION

No migration. No schema change. No RLS change. No new SQL function. No
new index. Every field and every access pattern Step 8C's own
recommendations need already exists.

## IMPLEMENTATION SCOPE

Smallest safe shape for a future implementation pass: (1) fix the
empty-state condition to account for Event content; (2) switch
`loadPassportEventAttendance`'s ordering from `confirmed_at` to the
Event's own `startDate` (sorted in Dart, per Repository/Query Shape);
(3) extend `availableVisitYears` (or an Event-aware sibling) so the
year filter includes Event dates; (4) introduce one small, new,
Passport-local enum/filter value for "Events" (never `ExploreVenueType`)
if the team wants Events as a genuine fourth filter lane, plus wiring
the EVENTS section's visibility to that filter the same way Restaurant/
Hotel cards already respect it. No `PassportVenue` change. No Rankings/
My Map/Friends/Trips/Wishlist change. No production data writes.

## TEST PLAN

**Eligibility**: confirmed attendance → included; no attendance row at
all → excluded (already implicitly true — the query only reads rows
that exist). **Source**: manual/post_event_prompt/trip_completion all
included equally (no source filter exists — verify no filter is ever
added). **Sort**: multiple Events, mixed precision, sorted by Event
date descending (once implemented) — not `confirmed_at`. **Date
precision**: date-only, full-time, multi-day date-only all render via
`formatEventDateRange` with no fabricated time (already covered
elsewhere; a Passport-specific card test would reconfirm no regression
from the sort-key change). **Card**: attendance photo priority,
official-image fallback, placeholder fallback, rating shown/omitted,
long title. **Privacy**: own private entry visible; own friends-visible
entry visible. **Status**: cancelled Event + confirmed attendance still
visible. **Remove**: unchanged existing behavior, reconfirm no
regression. **Empty state**: zero R/H + nonzero Events → Events still
correctly reachable/visible, not hidden by a misleading full-viewport
message (the actual bug fix's own regression test). **Navigation**: card
→ Event Detail → back → Passport.

## PHYSICAL DEVICE PLAN

Cannot be executed against real production data today — zero confirmed
attendances exist, and the app itself offers no path to create one
before an Event has concluded (earliest: 't Preuvenemint, ends
2026-08-30). Recommend: implement and verify via automated fixture
tests first (as this entire workstream has consistently done for
every zero-production-data case — Step 8B's Hotel/Chef paths being the
most recent precedent). Physical-device verification should wait for a
genuine confirmed attendance to occur naturally once 't Preuvenemint
concludes and either the post-event prompt or manual confirmation flow
is used for real — do not manufacture one as a shortcut.

## DATABASE

migrations created = 0. migrations deployed = 0. schema changes = 0.
production writes = 0. Every finding above came from read-only
production queries.

## VALIDATION

`flutter analyze`: no issues (unchanged — no Dart was modified this
pass). `flutter test`: 1492 passed, 0 failed (baseline unchanged).
`supabase migration list --linked`: 39/39 `local == remote`. `supabase
db push --linked --dry-run`: "Remote database is up to date."
`git status --short`: unchanged except for this new, untracked
documentation file.

## FILES

New: `docs/Architecture/Events/EVENTS_V2_STEP_8C_EVENTS_IN_PASSPORT_AUDIT.md`
(this file). No Dart file created or modified.

## GIT

Nothing staged, committed, or pushed.

## DECISION

Events are already technically present in Passport (Step 4's own
additive architecture) — Step 8C is a bounded set of fixes and one
small structural addition, not new construction: fix the confirmed
empty-state bug, switch Event sorting to the Event's own date, extend
the year filter to include Events, and (if the team wants Events as a
genuine fourth filter lane rather than an always-visible appended
section) introduce one small Passport-local filter enum — explicitly
never `ExploreVenueType`, and explicitly never folding Event into
`PassportVenue`, both confirmed to have a much larger blast radius than
useful here. No schema, RLS, or migration work is required. No real
production confirmed attendance exists yet to verify physically against
— automated coverage is the correct next step, with physical
verification deferred to a genuine, naturally-occurring confirmed
attendance.

EVENTS V2 STEP 8C — EVENTS-IN-PASSPORT ARCHITECTURE AUDITED, FIRST-
CLASS PASSPORT EXPERIENCE DEFINED, READY FOR HUMAN REVIEW BEFORE
IMPLEMENTATION
