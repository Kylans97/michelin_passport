# EVENT TIME PRECISION — PHASE B DART COMPATIBILITY PRE-FINAL

Phase B of the human-approved
`docs/Architecture/Events/EVENT_TIME_PRECISION_ARCHITECTURE_AUDIT.md`,
following Phase A's already-deployed additive migration
(`docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_A_PRE_APPLY.md`).
Dart-only: no schema change, no migration, no production write, nothing
staged/committed/pushed.

## RE-AUDIT

A fresh, direct search (not trusted from the earlier census) confirmed
every `startAt`/`endAt` consumer the architecture audit identified was
still accurate, with one addition the audit's own census had already
flagged as likely: `event_meta_section.dart` needed the most structural
change (two separate `formatEventDateTime` calls → one precision-aware
combined line). No previously-unknown consumer surfaced.

## EVENT MODEL

`Event` (`lib/models/event.dart`) now carries all three precision tiers:

- **Calendar** (always required): `startDate`/`endDate` — `DateTime`,
  UTC-tagged, midnight-zeroed, never derived from a bare `DateTime.parse`
  of a date-only string (which Dart resolves to the DEVICE's local zone —
  exactly the "accidental timezone semantics" the audit warned against).
- **Local clock** (known only when the source published a time):
  `startTime`/`endTime` — the new `EventLocalTime` value type
  (`lib/models/event_local_time.dart`), a pure wall-clock reading with no
  date/timezone of its own. Deliberately not Flutter's `TimeOfDay` — the
  models layer stays framework-free.
- **Exact instant** (known only when both sides above are known and
  source-confirmed): `startAt`/`endAt` — now `DateTime?`, nullable in
  Dart. Production still always sends both today (Phase A only); the type
  is honest about the future regardless.

`Event.fromJson` parses `start_date`/`end_date` via a small
`_parseCalendarDate` helper (never a bare `DateTime.parse`) and
`start_time`/`end_time` via `EventLocalTime.parse` — both confirmed
against real PostgREST serialization (`"2026-08-27"`, `"18:00:00"`,
verified directly against a live-queried row during Phase A). Malformed
required fields throw (`FormatException`), matching every other required
field on this model; malformed optional fields also throw rather than
silently defaulting.

**Backward-compatible construction** — the one design decision that kept
all 17 existing test-fixture files compiling and behaving identically
with zero edits: the constructor accepts `startDate`/`endDate`/
`startTime`/`endTime` as optional parameters and, when omitted, derives
them from `startAt`/`endAt` via the exact same `eventLocalDateTime` +
midnight-boundary rule Phase A's own migration backfill used. This
derivation only ever runs instant → date/time, never the reverse — the
constructor never fabricates `startAt`/`endAt` from a given
`startDate`/`startTime`, matching the audit's own "do not derive fake
exact instants" rule exactly. Supplying neither `startDate` nor `startAt`
(or the `end` equivalents) throws `ArgumentError` immediately.

Precision helper getters: `hasStartTime`, `hasEndTime`, `hasExactStart`,
`hasExactEnd`, `isDateOnly`, `hasFullTimePrecision` — every call site that
used to assume both instants exist now reads one of these instead of a
scattered null check.

## DATE / TIME DOMAIN

`compareCalendarDates(DateTime a, DateTime b)`
(`lib/core/utils/event_time.dart`) — a new zone-tag-agnostic comparator,
looking only at `(year, month, day)`. This exists specifically because
`Event.startDate` is always UTC-tagged but `PlannedTrip.startDate`/
`endDate` are parsed via a bare `DateTime.parse` (device-local-tagged, a
pre-existing `PlannedTrip` characteristic out of this phase's scope to
fix) — comparing the two via ordinary `DateTime.isAfter`/`.isBefore` would
silently leak the device's own UTC offset into a pure calendar-date
comparison. `compareCalendarDates` structurally rules that class of bug
out.

`compareEventChronology(Event a, Event b)`
(`lib/models/event_chronology.dart`) — the one canonical ordering,
replacing every previous `a.startAt.compareTo(b.startAt)` call site:
primary `compareCalendarDates` on `startDate`, secondary
known-time-before-unknown-time within the same date, tertiary `id`.

`eventEndReferenceInstant`/`eventHasEnded` (`lib/core/utils/event_time.dart`)
— the one centralized lifecycle layer: exact `endAt` instant when known
(byte-identical behavior to before Phase B), else the local-day-end of
`endDate` in `timezone`, computed via `tz.TZDateTime`'s own DST-aware
constructor — never manual "+24h" arithmetic, never a stored fake
`23:59:59`/`00:00:00`.

## JSON PARSING

Confirmed directly against a live-queried Phase A row (`supabase db query
--local`, not guessed): `date` → `"2026-08-27"`, `time` → `"18:00:00"`, no
offset, no fractional seconds on either. `Event.fromJson` parses both
defensively (throwing on malformation) and independently of `timezone`
(the calendar/clock fields carry no zone information of their own — they
already represent the event's own local reading, per Phase A's backfill).

## PRECISION HELPERS

See Event Model above — six boolean getters, no oversized enum. A
`time_precision` enum was considered (per the architecture audit's own
Option B) and rejected there for a documented reason (silent-misuse risk
vs. nullable fields' compile-time safety); Phase B's implementation
follows that recommendation.

## DISPLAY

`formatEventDateRange` (`lib/features/events/event_date_format.dart`) now
reads `Event.startDate`/`endDate` directly instead of deriving them
itself from `startAt`/`endAt` — a behavior-PRESERVING change for every
full-precision Event (identical output) that also makes the function safe
for a date-only Event with null instants.

New: `formatEventDateAndTime(Event event)` — the one canonical combined
date+time string, implementing the architecture audit's own Display Rules
exactly:

| Precision | Output |
|---|---|
| Date only | `29 Sep 2026` |
| Multi-day, date only | `16–18 Oct 2026` |
| Start known, end unknown | `29 Sep 2026 · 18:30` |
| Full, same day | `29 Sep 2026 · 18:30–23:00` |
| Full, multi-day ('t Preuvenemint's own shape) | `27–30 Aug 2026 · 18:00–00:00` |

Never renders "Time unknown"/"TBC" — absence of a time already
communicates "date only." `event_meta_section.dart` (Event Detail's "at a
glance" block) now calls this once, replacing its previous two separate
`formatEventDateTime(startAt)`/`formatEventDateTime(endAt)` calls — a
visible change from two lines to one for every existing full-precision
Event, but with identical underlying information, and the only way to
honor "no placeholder for the unknown side" once either side can
genuinely be absent.

## MIDNIGHT BOUNDARY

Reconfirmed end-to-end: 't Preuvenemint's `end_date` (2026-08-30, not
2026-08-31) and `end_time` (00:00:00, the true sourced boundary) are read
directly from the Phase A-backfilled columns, never re-derived by
Phase B's own display/lifecycle code — `formatEventDateAndTime` renders
`27–30 Aug 2026 · 18:00–00:00`, and `eventHasEnded` correctly treats the
exact `endAt` instant (2026-08-30T22:00:00Z) as the lifecycle boundary
when it's known, independent of the display-only date/time distinction.
Both are directly asserted in `test/event_time_precision_test.dart`'s own
regression group.

## SORTING

`compareEventChronology` replaces the raw `startAt` comparator in all
three call sites the architecture audit identified: `eventsMatchingTrip`
(`lib/models/event_trip_match.dart`), `selectFeaturedEvent`
(`lib/features/explore/discovery_selectors.dart`), and
`rankEventsForDiscovery`'s tie-break
(`lib/features/events/event_discovery_ranking.dart`, Step 8A — hierarchy
itself untouched, only the chronological tie-break beneath it).

## LIFECYCLE

`canAttendEvent` (`lib/features/events/event_detail_screen.dart`) and
`_hasEnded`/`_withinPromptWindow`
(`lib/models/event_attendance_eligibility.dart`) both now delegate to the
centralized `eventHasEnded`/`eventEndReferenceInstant` — exact instant
when known (unchanged behavior for every full-precision Event), local-day
boundary otherwise.

## CAN ATTEND

Unchanged rule, precision-aware implementation: cancelled → never;
exact-ended → uses `endAt`; unknown-end → Interested/Going remain offered
through the Event's final local day, cut off only once that local day
fully ends. Social/privacy semantics (visibility, friend-facing behavior)
untouched — this phase only ever touches the *lifecycle gate*, never who
can see what.

## ATTENDANCE

`resolveAttendanceUiState`/`mostRecentEligibleAttendancePromptEvent`
follow the same centralized rule. The 30-day lookback window now counts
from `eventEndReferenceInstant` (exact `endAt` when known, else the local
end-of-day of `endDate`) rather than a raw `endAt` that may not exist —
recommended and implemented per the architecture audit's own "a later
prompt is safer than a premature one" principle. New tests confirm: a
date-only Event does not prompt merely because its day has "started" in
UTC terms, waits until the local final day fully ends (single- and
multi-day), and the existing exact-instant behavior is completely
unaffected.

## EVENTS REPOSITORY

`EventsRepository.loadEvents`'s own `.gte('end_at', from)`/`.lte
('start_at', to)` browse-window filter and `.order('start_at')` sort are
**deliberately left unchanged** in Phase B — production has no null
`end_at`/`start_at` today, so nothing is broken, and migrating this
specific filter to `start_date`/`end_date` well would need an index
question the audit explicitly asked to be deferred, not decided
unilaterally (see Phase C Requirements).

`EventAttendanceRepository.getFriendUpcomingEvents`/`getPastGoingEvents`
**were** changed: the previous `.gte('end_at', now)`/`.lt('end_at', now)`
SQL filters are replaced with a single batched fetch (unchanged query
shape otherwise — still 2 queries total, never one per event) followed by
Dart-side `eventHasEnded` filtering, then `compareEventChronology`
sorting for the upcoming case. Rationale: a SQL `NULL` comparison is
neither true nor false, so once Phase C ever lets `end_at` be null, the
old filters would have silently excluded every date-only Event from these
two queries forever — including from Friend Profile's GOING/INTERESTED
sections and the "Did you make it?" prompt candidate pool. Production
still has `end_at NOT NULL` on every row today, so this produces
byte-identical results right now; Phase C needs zero further changes to
either method.

## FRIENDS / SOCIAL

Confirmed: `FriendGoingTile` and Friend Profile's Going/Interested
sections all route through `formatEventDateRange` (unchanged call sites,
now precision-aware for free) and the repository methods above — no
separate friend-specific date logic exists anywhere to update. A future
date-only Event will render and sort correctly on every friend-facing
surface with zero further Dart changes.

## TRIPS

`eventMatchesTrip` (`lib/models/event_trip_match.dart`) is simplified, not
just made compatible: it now reads `Event.startDate`/`endDate` directly
and compares them against `trip.startDate`/`endDate` via
`compareCalendarDates` — the previous `eventLocalDateTime` + `_dateOnly`
truncation dance is gone entirely (that logic already ran once, at
`Event` construction time, to produce `startDate`/`endDate` in the first
place). New tests cover a date-only Event matching within a Trip window,
overlapping exactly on the Trip's start/end boundary, a genuine
non-overlap, and confirm (by direct code reading, restated in the test's
own assertion) that the function never reads `DateTime.now()` or any
device-local value.

## STEP 8A

Relevance hierarchy (Trip > Friend Going > Followed Host > Friend
Interested > Popularity > Chronology) is completely untouched — none of
the five signal types depend on time precision. Only the innermost
chronological tie-break now calls `compareEventChronology` instead of
comparing raw `startAt` values. Regression-tested directly.

## EVENT DETAIL / CARDS

`EventCard` needed no change — it already only calls
`formatEventDateRange`, which is now precision-aware transparently.
`event_meta_section.dart` was updated as described under Display. Both
render every precision state without a null crash and without a
device-timezone leak (confirmed via the new widget-independent unit tests
plus the existing `event_detail_redesign_test.dart` regression, updated
only where its assertion depended on the old two-line format).

## DST

`test/event_time_precision_test.dart` includes a dedicated group testing
a date-only Event whose `start_date`/`end_date` fall exactly on
2026-10-25 — the actual EU DST transition date, where the local day is 23
hours, not 24. The lifecycle boundary is computed correctly (verified
against the real UTC offset either side of the transition), proving
`eventEndReferenceInstant`'s use of `tz.TZDateTime`'s own DST-aware
constructor — never manual `+24h` arithmetic — actually matters and
actually works.

## WEB READINESS

Not built. Confirmed as a design test only: `Event.startDate`/`endDate`/
`startTime`/`endTime` map cleanly to `schema.org/Event`'s own
`startDate`/`endDate` fields, which natively accept either a date-only
(`"2026-09-29"`) or full date-time (`"2026-09-29T18:30:00+02:00"`) ISO
string — exactly the two shapes `formatEventDateAndTime`'s own logic
already distinguishes.

## DATABASE

Migrations created: **0**. Migrations deployed: **0**. Schema changes:
**0**. Production writes: **0** — confirmed by `supabase migration list
--linked` (37/37 synced, unchanged since Phase A) and `supabase db push
--linked --dry-run` ("Remote database is up to date.").

## VALIDATION

`dart format --set-exit-if-changed .`: 0 files changed. `flutter
analyze`: 0 issues. `flutter test`: **1435 passed, 0 failed** (1401
baseline + 34 new: 30 in the new `event_time_precision_test.dart` + 4 new
in `event_attendance_eligibility_test.dart`). No test was weakened or
removed — 3 pre-existing assertions were updated to match the new,
correct combined-display behavior (`event_meta_section.dart`'s
single-line output), and 3 raw-JSON test fixtures gained the now-required
`start_date`/`end_date` keys; every other assertion, including every
regression case, is unchanged.

## FILES

New:
- `lib/models/event_local_time.dart`
- `lib/models/event_chronology.dart`
- `test/event_time_precision_test.dart`
- `docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_B_PRE_FINAL.md`
  (this file)

Modified:
- `lib/models/event.dart` (new fields, derivation, precision helpers,
  JSON parsing)
- `lib/core/utils/event_time.dart` (`compareCalendarDates`,
  `eventEndReferenceInstant`, `eventHasEnded`)
- `lib/features/events/event_date_format.dart` (`formatEventDateRange`
  refactored, `formatEventDateAndTime` added)
- `lib/features/events/widgets/event_meta_section.dart` (combined
  formatter)
- `lib/features/events/event_detail_screen.dart` (`canAttendEvent`)
- `lib/features/events/event_discovery_ranking.dart` (chronology
  tie-break)
- `lib/features/explore/discovery_selectors.dart`
  (`selectFeaturedEvent`)
- `lib/models/event_attendance_eligibility.dart` (`_hasEnded`,
  `_withinPromptWindow`, prompt-candidate sort)
- `lib/models/event_trip_match.dart` (simplified `eventMatchesTrip`)
- `lib/data/repositories/event_attendance_repository.dart`
  (`getFriendUpcomingEvents`, `getPastGoingEvents`)
- `test/event_attendance_eligibility_test.dart`,
  `test/event_detail_redesign_test.dart`, `test/event_time_test.dart`,
  `test/events_test.dart` (new-field-aware fixtures/assertions)

Not modified: `EventCard`, `EventDiscoveryItem`, My Map (`lib/features/
map/`), analytics (`lib/core/analytics/`) — all confirmed unaffected,
matching the architecture audit's own predictions exactly.

## GIT

Nothing staged, nothing committed, nothing pushed — the Phase A migration
and doc, and now Phase B's Dart changes and this doc, all remain
uncommitted working-tree files until the full time-precision workstream
is physically reviewed.

## PHYSICAL DEVICE CHECKLIST

Production still has only full-precision Events, so this is a regression
pass, not a live date-only test:

- [ ] All 4 existing Events display dates/times exactly as expected on
      Events feed, Event Detail, Passport, and Explore.
- [ ] 't Preuvenemint displays "27–30 Aug 2026" (card) and "27–30 Aug
      2026 · 18:00–00:00" (Event Detail) — correct final date, not the
      31st.
- [ ] Events ordering (Events feed, Step 8A ranking, Explore's "What's
      On") unchanged.
- [ ] Trip matching ("CULINARY EVENTS DURING YOUR TRIP") unchanged.
- [ ] Interested/Going controls appear/disappear at the same moments as
      before.
- [ ] "Did you make it?" prompt timing unchanged for a real past-Going
      event.
- [ ] Friend Profile GOING/INTERESTED sections unchanged.
- [ ] Step 8A relevance-reason badges and card layout unchanged.

True date-only behavior is covered by the 34 new automated
tests until Phase C actually lets production send one.

## PHASE C REQUIREMENTS

Not created, not migrated — the exact next-step contract:

- `ALTER TABLE events ALTER COLUMN start_at DROP NOT NULL, ALTER COLUMN
  end_at DROP NOT NULL`.
- Replace `events_dates_valid` (`end_at >= start_at`) with a version that
  tolerates null exact instants — `events_local_dates_valid` (`end_date
  >= start_date`, added in Phase A) already covers the date-level ordering
  guarantee independently, so the replacement can likely just drop the
  old constraint outright rather than rewrite it.
- Revisit whether `EventsRepository.loadEvents`'s browse-window filter
  should migrate from `start_at`/`end_at` to `start_date`/`end_date` —
  and, if so, whether an index on `start_date` is now justified (deferred
  from both Phase A and Phase B specifically so this decision is made
  deliberately, against real query patterns, not assumed).
- Confirm no other DB function/constraint assumes an exact timestamp —
  none were found in this phase's own schema re-audit, but Phase C's own
  pre-apply should re-verify directly against whatever the schema looks
  like at that time.

## DECISION

1. **Can `Event.fromJson` now parse a true date-only Event?** Yes —
   confirmed with dedicated parsing tests.
2. **Can it parse start-known/end-unknown?** Yes.
3. **Are `startAt`/`endAt` nullable in Dart?** Yes.
4. **Are `startDate`/`endDate` canonical for calendar behavior?** Yes —
   sorting, lifecycle, and Trip matching all read them directly now.
5. **Do existing full-time Events render unchanged?** Yes for the
   underlying information; `event_meta_section.dart`'s presentation moved
   from two lines to one combined line, a deliberate, tested, and
   necessary change (see Display) — every other display site is
   byte-identical.
6. **Does exact `endAt` still control lifecycle when known?** Yes,
   unchanged.
7. **Does local `endDate` control lifecycle when `endAt` is unknown?**
   Yes, DST-safe, tested directly.
8. **Are Attendance prompts safe for date-only Events?** Yes — wait until
   the local final day fully ends, never a premature or fabricated
   trigger.
9. **Does Trip matching use the canonical dates?** Yes, and more simply
   than before Phase B.
10. **Is Step 8A chronology precision-aware?** Yes — hierarchy unchanged,
    tie-break updated.
11. **Are future date-only Events excluded by any remaining Dart/
    repository query?** No known remaining exclusion —
    `getFriendUpcomingEvents`/`getPastGoingEvents` were specifically fixed
    for this; `EventsRepository.loadEvents`'s browse-window filter is
    the one deliberately deferred exception (see Phase C Requirements),
    safe today only because production has no null `end_at` yet.
12. **Does Phase C require an index?** Possibly, for
    `EventsRepository.loadEvents` specifically if its filter migrates to
    `start_date` — deferred to Phase C's own decision, not created here.
13. **Were any DB changes made?** No — 0 migrations, 0 schema changes, 0
    production writes.
14. **Is Phase B ready for physical-device regression review?** Yes.

EVENT TIME PRECISION — PHASE B DART COMPATIBILITY IMPLEMENTED, FULL-TIME
REGRESSION PRESERVED, READY FOR PHYSICAL-DEVICE REVIEW BEFORE PHASE C

---

## PHYSICAL DEVICE UX CORRECTION — EVENT DETAIL HIERARCHY

A separate, smaller pass, done after the above Phase B work had already
passed physical-device regression review. Time semantics, Step 8A, and
every social/attendance surface are completely untouched by this
correction — it only reorganizes WHERE existing information appears on
Event Detail, never what it says or how it's computed.

### Why the hero was simplified

Without photography, the hero's density was tolerable. Once Event
photography is introduced, a hero carrying event type + title + city/
country + date range leaves the actual photo very little room to read as
a photo. Simplifying now — before Phase C, before any imagery work — means
the hero is already photography-ready rather than needing a second pass
later.

### Old hierarchy

Hero (image, event type, title, city/country, date range) → Event Meta
(date/time, venue, admission) → Attendance → Interested/Going/Friends/
member-count → About → At This Event → Hotels → **Location (address +
Website + Tickets)**.

### New hierarchy

Hero (image, title, city/country **only**) → Event Essentials
(**event type**, date/time, venue, admission) → **Actions** (Tickets/
Official website, moved up) → Attendance → Interested/Going/Friends/
member-count → About → At This Event → Hotels → Location (**address
only**).

### Event-type move

`event.eventType.label` (unchanged taxonomy — festival/dinner/tasting/
market/experience/other) moved from the hero into `EventMetaSection`
("Event Essentials"), rendered as a small uppercase eyebrow
(`CsTypography.eyebrow`, taupe, no chip, no badge, no gold) directly above
the date/time row — exactly the "DINNER / 29 September 2026 · 18:30"
pairing specified. Renders nothing for `EventType.other` — the schema's
own "no real type known" fallback value, treated as "no type known" per
the correction's own "render nothing rather than a placeholder" rule,
rather than showing a generic "EVENT" label that would read as a
placeholder in substance even though the enum itself is never null.
`EventDetailHero`'s `eventTypeLabel` parameter is left in place (still
optional, unchanged behavior when supplied) — only the real call site
stops passing it, so the widget itself isn't forced into a wider API
change to serve one caller's new requirement.

### Action-link move

New `EventActionsRow` widget
(`lib/features/events/widgets/event_actions_row.dart`) renders directly
after Event Essentials, reusing the existing `SubtleTextAction` atom
unchanged (no new button style, no gold, "Chasing Stars, not a ticket
marketplace"). Tickets renders first when both exist — priority expressed
through left-to-right reading order, not a second, louder visual
treatment. Handles all four conditional states (both / tickets-only /
website-only / neither, rendering nothing for the last case) and one real
production edge case found during the correction: Vergeet Mij Niet Gala's
`official_url` and `ticket_url` are the identical string — when that
happens, only the Tickets action renders, never two links to the same
destination. Each action carries a descriptive Semantics label
(`"{label} for {event name}"` / `"Official website for {event name}"`)
via `Semantics` + `ExcludeSemantics`, so a screen reader announces
something meaningful rather than a bare "Tickets"/"Website" with no
context. `_openUrl`'s existing safe-launch behavior (`canLaunchUrl` guard,
`LaunchMode.externalApplication`, no raw exception surfaced) is reused
as-is — `EventActionsRow` only ever calls the same `onTapUrl` callback the
screen already owned; no second URL-launcher implementation was
introduced. No existing analytics call was attached to these links before
this correction, and none was added — nothing to preserve or move.

### Location cleanup

`LOCATION` now renders only the address line; `hasLocationSection` is
simply `hasAddress` (previously a three-way OR including the two URLs).
No "open in maps" action was found anywhere in the existing codebase to
preserve or relocate — none is added here, staying within this
correction's own scope (a reordering pass, not a new-feature pass).

### Responsive behavior

`EventActionsRow` tested explicitly at 320px width with a long event name
and both actions present, and at 1.6x text scale with both actions — no
overflow in either case, using `Row` + the existing `SubtleTextAction`
sizing rather than any new responsive machinery.

### Tests

New: `test/event_actions_row_test.dart` (14 tests — every conditional URL
state including the identical-URL dedup case, tap behavior, accessibility
labels, gold-free visual regression, narrow-width/large-text-scale
overflow). Updated: `test/event_detail_redesign_test.dart` (+4 tests —
`EventDetailHero` renders nothing for event type/date when omitted,
matching the real call site's new shape; `EventMetaSection` renders the
event-type eyebrow above date/time, omits it for `EventType.other`, and
conveys it through visible text). No existing test was weakened; every
pre-existing `EventDetailHero`/`EventMetaSection`/`AtThisEventSection`
assertion still passes unchanged, since both hero parameters stayed
supported (just optional) and every other section's own behavior was
untouched. Final count: **1453 passed, 0 failed** (1435 baseline + 18
new).

### Social/Attendance regression

Not touched. `EventIntentControls`, `EventFriendsGoingSection`,
`EventFriendsInterestedSection`, the Going-member-count line,
`EventAttendanceSection`, Follow, and Step 8A relevance signals all sit in
exactly the same relative order and read exactly the same state as
before — only `EventActionsRow`'s own new position (between Essentials
and Attendance) was inserted into the Column, with no other section's
`if`/gating logic modified.

EVENT TIME PRECISION — PHASE B EVENT DETAIL HIERARCHY CORRECTED, READY
FOR SHORT PHYSICAL-DEVICE RE-CHECK BEFORE PHASE C

STOP.
