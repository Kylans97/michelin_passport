# EVENT TIME PRECISION — PHASE C NULLABLE EXACT-INSTANT MODEL PRE-APPLY

Phase A (deployed) added `start_date`/`end_date`/`start_time`/`end_time` as
the durable local-calendar anchor and backfilled every existing row. Phase
B (implemented, physically approved) made every Dart consumer of
`Event.startAt`/`endAt` null-safe and corrected the Event Detail
hierarchy. Phase C is the schema half of the original architecture
audit's third step: `start_at`/`end_at` become nullable, so a genuinely
date-only or start-known/end-unknown Event can be stored without ever
fabricating an exact instant that was never sourced. This document covers
Phase C's local-only implementation, pending human production-apply
review.

## FINAL SCHEMA MODEL

After Phase C: `start_date date NOT NULL`, `end_date date NOT NULL`,
`start_time time NULL`, `end_time time NULL`, `start_at timestamptz
NULL`, `end_at timestamptz NULL`, `timezone text NOT NULL`. Four
precision shapes are all legal: DATE ONLY (start_time/end_time/start_at/
end_at all null), START KNOWN/END UNKNOWN (start_time+start_at known,
end_time/end_at null), FULL TIME (everything known, today's only shape
in production), MULTI-DAY DATE ONLY (dates span multiple days, times/
instants null).

## MIGRATION

`supabase/migrations/20260822130000_events_v2_time_precision_phase_c.sql`
— exactly one file. Three steps: (1) `alter column start_at/end_at drop
not null`; (2) drop and recreate `events_dates_valid` as `start_at is
null or end_at is null or end_at >= start_at`; (3) `create index
events_start_date_idx on events (start_date)`. Nothing else touched.

## CONSTRAINTS

`events_local_dates_valid` (`end_date >= start_date`, Phase A) is
untouched — it is the one ordering guarantee that holds unconditionally,
known-time or not. `events_dates_valid` is rewritten rather than dropped:
ordering between the two exact instants is enforced only when *both* are
known; a one-sided-known or wholly-unknown exact instant is never, on its
own, a reason to reject a row. No new cross-field constraint (e.g.
correlating `start_time` with `start_at`, or `end_time` with `end_date`)
was added — per the task's own conservatism instruction, every such rule
considered breaks around DST, midnight boundaries, multi-day events, or
unknown times, and the application layer (Phase B's derivation helpers,
`Event.fromJson`) already owns that consistency at construction time.
`events_country_code_fkey`, the timezone trigger, and RLS are all
unchanged. Both directions were proven locally (§ Local Date-Only Insert
below, and a direct negative-path proof: an insert with both `start_at`
and `end_at` non-null but `end_at < start_at` was correctly rejected with
`events_dates_valid` violated).

## INDEX DECISION

Added: `events_start_date_idx` (single-column, btree, on `start_date`).
`start_date` is now the canonical browse/filter/order key for
`EventsRepository.loadEvents`/`loadEventsForCountry` (see below) — every
future date-only row has a null `start_at`, so `events_start_at_idx` can
no longer serve that query, and deferring an index "for now" would only
postpone a known future cost the Batch-1 backlog (30-50 Events, then
hundreds) will actually hit. `end_date` was deliberately left unindexed:
the `end_date >= X` half of `loadEvents`' conservative window is a
coarse "hasn't ended before the window" filter, not an `ORDER BY` key,
and the catalogue is small enough that this can be revisited
independently later if it ever becomes a bottleneck on its own (see
Query Scale below). `events_start_at_idx` is kept — see Database
Function Audit's sibling note below.

## DATABASE FUNCTION AUDIT

A fresh search of `pg_proc`/`prosrc` and `pg_views` for any reference to
`start_at`/`end_at` returned zero functions and zero views. No SQL
function/view compatibility changes were needed as part of this
migration. `events_start_at_idx` remains useful for exact-instant range
queries against full-time Events (today's only shape, and expected to
remain common even after Phase C) — cleanup is explicitly deferred, not
part of this phase.

## EVENTS REPOSITORY

`EventsRepository.loadEvents`/`loadEventsForCountry`
(`lib/data/repositories/events_repository.dart`) were the entire
`MUST_CHANGE_BEFORE_NULLABLE` surface — confirmed by a fresh, full repo
grep for `startAt`/`endAt`/`'start_at'`/`'end_at'`, not by trusting
Phase B's earlier census. Every other consumer (`Event.fromJson`,
`event_time.dart`, `event_attendance_eligibility.dart`,
`event_attendance_repository.dart`, `event_detail_screen.dart`) was
already made null-safe in Phase B.

Both methods now filter/order on `start_date`/`end_date` — each event's
OWN local calendar date — never on `start_at`/`end_at`. SQL owns: the
free-text OR filter, the country filter, the conservative browse-window
bounds (below), and the primary sort (`start_date` ascending). Dart owns:
nothing further for `loadEvents`'s own window — see International
Date-Boundary Strategy for why no further trim runs client-side.
Downstream precision-aware refinement (exact lifecycle, chronological
tie-break) already happens in `compareEventChronology`/`eventHasEnded`
wherever a consumer needs an exact answer, unchanged from Phase B.

One consumer detail worth flagging: `EventDiscoveryService.rankForDiscovery`
returns items in the *raw repository order* when `userId` is null
(signed-out cold start) — it does not always re-sort via
`compareEventChronology`. This means `loadEvents`' own `ORDER BY` is not
merely a convenience default for every caller; for that specific path it
is the actual displayed order, which is why moving it off the
soon-nullable `start_at` was necessary, not optional.

## INTERNATIONAL DATE-BOUNDARY STRATEGY

`from`/`to` arrive at `loadEvents` as device-local `DateTime`s (see
`EventDateFilter.resolve()`). Comparing a device-local calendar day
directly against an event's own IANA-zone calendar day is exactly the
trap this phase must not fall into: a bare `end_date >= today` uses the
querying session's/device's own date, not each event's, and could
silently exclude a legitimate event near a midnight boundary for a
timezone meaningfully different from the viewer's.

Chosen strategy: widen the SQL window by exactly one calendar day on
each open end before sending it as the filter — `gte('end_date', from -
1 day)` / `lte('start_date', to + 1 day)`. Since any two IANA zones
differ by at most ~26 hours, "today" can disagree by at most one
calendar day between a viewer's device and an event's own zone; widening
by one day on each side is therefore always enough to avoid excluding a
legitimate boundary event, regardless of which zones are involved. This
was extracted as a standalone pure function, `eventBrowseWindowBounds`,
specifically so the arithmetic itself is unit-tested (see Repository
Tests below) without needing a live `SupabaseClient`.

No further "exact" trim runs afterward in Dart. This was a deliberate
choice, not an oversight: once two timezones genuinely differ, there is
no single correct answer to "is this event in the viewer's window,"
only "never silently hide it." Trimming the widened SQL result back down
to a device-local-exact boundary would reintroduce exactly the bug this
strategy exists to avoid — it would discard the very boundary events the
widening was added to keep. The accepted cost is a rare extra event
visible one day outside a device-local browse window's literal edge,
traded deliberately against the alternative of a legitimate event
silently vanishing near midnight.

## ATTENDANCE REPOSITORY

Re-audited fresh, not assumed: `EventAttendanceRepository.getFriendUpcomingEvents`/
`getPastGoingEvents` and `EventConfirmedAttendanceRepository`'s own
queries contain zero raw `start_at`/`end_at` SQL references (grep
confirmed; the only two hits in `event_attendance_repository.dart` are
doc comments already describing Phase B's own Dart-side
`eventHasEnded`-based filtering). No further change was needed here —
Phase B's move to Dart-side, null-safe lifecycle filtering already
covers a future date-only Going/Interested Event correctly.

## FRIENDS/SOCIAL

Friend Profile and Friend Activity List consume events exclusively
through `EventAttendanceRepository`/`EventConfirmedAttendanceRepository`,
both already confirmed clean above. No direct raw-timestamp query exists
on these surfaces that could exclude a date-only Event.

## EXPLORE

`ExploreScreen`'s "What's On" discovery card and its `events` search type
both go through `EventsRepository.loadEvents` (now date-based) and
`discovery_selectors.dart`'s `selectFeaturedEvent`, which already
re-sorts via `compareEventChronology` (Phase B) regardless of the
repository's own row order. A date-only Event is discoverable end to
end.

## STEP 8A

`rankEventsForDiscovery`'s own ordering (relevance tier, then
`compareEventChronology` within a tier) is unchanged — Phase B already
made the chronology tie-break precision-aware. One stale doc comment in
`event_discovery_ranking.dart` claiming the cold-start order matches
`loadEvents`' `start_at` order was corrected to say `start_date`, since
that claim is literally about this repository's own `ORDER BY` clause.
No ranking-logic change.

## LOCAL DATE-ONLY INSERT

Applied the migration to local Postgres (`supabase migration up
--local`) and verified the resulting schema/constraints/indexes exactly
match the design (see Database section). Inside a disposable,
manually-cleaned-up single-statement insert (the CLI's `db query` does
not support multi-statement transactions — an already-established
limitation from Phase A's own local verification):

```sql
insert into public.events (name, country_code, timezone, start_date, end_date)
values ('Phase C Fixture — Date Only', 'NL', 'Europe/Amsterdam', '2026-09-10', '2026-09-12')
returning id, start_at, end_at, start_time, end_time;
```

Succeeded: `start_at`/`end_at`/`start_time`/`end_time` all null,
`start_date`/`end_date` as given. A direct SQL replica of the redesigned
`loadEvents` WHERE clause (`end_date >= today - 1 day`) returned this
fixture alongside the existing 't Preuvenemint row, proving a date-only
Event is genuinely included by the new query shape. The fixture was then
deleted, restoring local Postgres to its original single-seed-row state.

## LOCAL START-KNOWN/END-UNKNOWN INSERT

Same disposable-insert pattern:

```sql
insert into public.events (name, country_code, timezone, start_date, end_date, start_time, start_at)
values ('Phase C Fixture — Start Known End Unknown', 'NL', 'Europe/Amsterdam', '2026-09-15', '2026-09-15', '19:00:00', '2026-09-15T17:00:00Z')
returning id, start_at, end_at, start_time, end_time;
```

Succeeded: `start_time`/`start_at` as given, `end_time`/`end_at` both
null — no invented end time. Deleted after verification.

## FULL-TIME REGRESSION

Not a new insert: the existing production-shaped 't Preuvenemint row
(full-time, all six fields populated) was still present, unmodified,
after the migration ran — and crucially, Postgres validates a newly
added `CHECK` constraint against every existing row by default, so the
migration's own successful application is itself a direct proof that
today's full-time shape satisfies the rewritten `events_dates_valid`
unchanged.

## MIDNIGHT BOUNDARY

Re-verified 't Preuvenemint's own row directly, untouched by this phase:
`end_date = 2026-08-30`, `end_time = 00:00:00`, `end_at =
2026-08-30T22:00:00Z` (`2026-08-31T00:00:00` Europe/Amsterdam local) —
Phase A's midnight-boundary backfill semantics (calendar end_date stays
the last *active* day, not the day the raw end instant technically rolls
into) hold exactly as before. Nothing in Phase C touches existing row
data.

## LIFECYCLE

`test/event_time_precision_test.dart` (Phase B, all still passing)
already proves the before/during/after-final-local-day lifecycle for a
date-only Event, multi-day date-only activity, and a DST-transition-date
Event, purely as unit tests against `eventHasEnded`/
`eventEndReferenceInstant` — no live DB needed for this layer. This
phase's own DB-level fixtures (above) are the first time those same
precision shapes were proven legally insertable against the actual
Phase-C-relaxed schema, closing the loop between "Dart can parse/display
this shape" and "Postgres will actually store this shape."

## QUERY SCALE

At 30-50 rows (current/near-term Batch-1 scale), Postgres will very
likely choose a sequential scan over `events_start_date_idx` regardless
— normal and harmless at this size, index or not. At ~500 rows the index
starts to matter: it avoids an in-memory sort for `ORDER BY start_date`
and helps the `start_date <= X` bound; still comfortably fast either
way. At ~5000 rows the index becomes clearly worthwhile — an index range
scan on `start_date` replaces a full-table sort, and combined with
`events_country_idx` for country-scoped browsing, query cost stays low.
The unindexed `end_date >= X` filter is a single sequential-scan
qualifier at every one of these sizes, which Postgres handles cheaply up
to tens of thousands of rows; if the catalogue eventually grows into
that range, an `end_date` index (or a composite) can be added
independently — deferred, consistent with Index Decision's own
conservative "index the actual current key, revisit the rest later"
approach. No artificial benchmarking was run; this is inference from
known index/query shapes, matching Postgres' standard cost-based
planning behavior.

## RELEASE SEQUENCING

This migration is safe to deploy ahead of a compatible app release. The
one governing invariant: relaxing `start_at`/`end_at` alone does not
change what any *existing* row looks like — every currently-live row
keeps its own non-null exact instants exactly as today, and
`EventsRepository` has no write methods (events are seeded server-side,
never authored by app users), so no client-side path can insert a
date-only row. An old, pre-Phase-B production app reading these
unchanged rows via its own `start_at`-based query is therefore
unaffected by this schema change on its own.

Safe production order: (1) Phase A — already deployed; (2) Phase B —
Dart compatibility finalized/committed; (3) Phase C schema — this
migration, deployed; (4) a compatible app build verified live (device
verification, per the Physical Device Plan below); (5) only then, a
separate, explicitly-gated production-data step inserts the first
date-only Event. The exact gate: **no date-only or start-known/
end-unknown row may be inserted into production until step (4) is
confirmed** — before that point, Phase C's schema relaxation is present
but unused, which is precisely what keeps it safe to deploy early.

## BATCH-1 IMPACT

Re-run against Phase C's now-locally-proven capability, not assumed from
the earlier audit: of the 10 original candidates, 2 were already
`READY_TO_INSERT`/`READY_WITH_EXTERNAL_HOST` (SHEf's Kitchen Party,
Marchal x Seafood Gastro) — full-time, unaffected by this phase. Of the
6 candidates held only on `HOLD_DATE_OR_TIME_UNCLEAR`, 4 had *no
published time at all* (only the date itself, or nothing time-specific)
and now have a genuinely legal, non-fabricating shape: Bas van Kranen x
Sang Hoon Degeimbre (date-only/multi-day), Douro to Table — Dinner III
(date-only), Ugly Butterfly x Simon Hulstone (date-only), Forces of
Nature x Eric Vildgaard (date-only). The remaining 2 clear the *timing*
gate specifically but stay held on a separate, Phase-C-unrelated
blocker: Toquicimes 2026 (no single venue/address — a location gate) and
San Sebastián Gastronomika 2026 (an unresolved source date conflict —
Phase C makes *missing* data storable, not *conflicting* data
resolvable). Couverts sur Mer and DolomitiGourmet Festival remain held
on `HOLD_SESSION_MODEL` — each needs to be re-scoped into multiple
distinct Event rows, a modeling decision Phase C's per-row nullable-time
change does not touch.

Net: up to 6 of the 10 no longer have exact time as a blocker (2
already-ready + 4 newly time-unblocked), consistent with the original
audit's own "~6 production-ready" estimate — reconfirmed on the timing
axis specifically. This phase did **not** re-run the location/coordinate
verification these 4 still separately require (see Coordinates below);
that remains open, unrelated work. None of the 10 were inserted.

## COORDINATES

Unblocking on time does not unblock on location. Every Event, including
the 4 newly time-unblocked Batch-1 candidates, still requires a verified
real venue location per the enrichment gate the original Batch-1 audit
established — no fake coordinates, no city centroids. Phase C's schema
change is scoped to date/time precision only and does not touch, weaken,
or bypass that separate gate.

## HOST-CREATED FUTURE

No host-create feature exists today. Phase C's nullable table is
designed to support editorial uncertainty in first-party-sourced,
staff-curated Events — not to lower the bar for a future
host-submission flow. Reconfirmed: any future host-created-Event
submission boundary should still require an exact start, exact end, and
timezone at submission time, regardless of what the table itself now
tolerates.

## DATABASE

Migrations created: 1. Migrations applied locally: 1 (verified schema/
constraints/indexes match the design exactly — see below). Migrations
deployed to production: 0. Production schema changes: 0. Production
writes: 0.

Verified local schema after apply: `start_date`/`end_date` — `date`, NOT
NULL. `start_time`/`end_time` — `time`, NULL. `start_at`/`end_at` —
`timestamptz`, NULL. `timezone` — `text`, NOT NULL. Constraints:
`events_dates_valid` → `(start_at IS NULL) OR (end_at IS NULL) OR
(end_at >= start_at)`; `events_local_dates_valid` → `(end_date >=
start_date)`, unchanged; all other pre-existing constraints unchanged.
Indexes: `events_pkey`, `events_country_idx`, `events_status_idx`,
`events_start_at_idx` (kept), `events_start_date_idx` (new).

## VALIDATION

`dart format --set-exit-if-changed .` — 393 files, 0 changed.
`flutter analyze` — no issues found. `flutter test` — **1459 passed, 0
failed** (1453 baseline + 6 new `eventBrowseWindowBounds` tests; no test
weakened or removed). `supabase migration list --linked` — every prior
migration through `20260822120000` (Phase A) shows a matching remote
timestamp; `20260822130000` (this phase's migration) shows no remote
timestamp — confirmed not yet deployed. `supabase db push --linked
--dry-run` — reports exactly one migration would be pushed
(`20260822130000_events_v2_time_precision_phase_c.sql`), and confirms
nothing has actually been pushed. `git status --short` — the Phase C
migration, doc, `events_repository.dart`, `event_discovery_ranking.dart`,
and `events_repository_test.dart` all show as modified/untracked,
consistent with every other Phase A/B file still unstaged from this
workstream. `git diff --cached` — empty; nothing staged.

## FILES

New: `supabase/migrations/20260822130000_events_v2_time_precision_phase_c.sql`,
`test/events_repository_test.dart`,
`docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_C_PRE_APPLY.md`
(this file). Modified: `lib/data/repositories/events_repository.dart`
(query redesign — `eventBrowseWindowBounds`, `loadEvents`,
`loadEventsForCountry`), `lib/features/events/event_discovery_ranking.dart`
(one stale doc-comment correction).

## GIT

Nothing staged, committed, or pushed this phase, matching every prior
phase in this workstream. Phase A + B + C remain together, unstaged, for
final human workstream review.

## PHYSICAL DEVICE PLAN

**Stage A — before any date-only production data exists.** Regression
only: the four existing production Events render unchanged (card,
sorting, Event Detail hierarchy exactly as Phase B's UX correction
left it); Trips still match correctly; Friends Going/Interested still
show every existing Event; Step 8A ranking unchanged; attendance
prompts/eligibility unchanged. This stage can run today, before any
production deployment, purely to confirm zero regression from Phase C's
Dart changes alone.

**Stage B — after one human-approved date-only test Event exists in
production** (explicitly gated per Release Sequencing above; not created
as part of this task). Verify: the date-only card renders with no
invented time; Event Detail shows date-only precision correctly (no
fabricated clock time anywhere); sorting places it correctly among
full-time Events; Interested/Going both work; trip matching works
purely by calendar date; any location/media placeholder behaves as
designed; the ticket/website action row behaves identically to a
full-time Event; lifecycle (active-until-end-of-local-day) matches
expectation on-device across a real day boundary if feasible.

## DECISION

Local implementation is complete: the Phase C migration is designed,
applied to local Postgres only, and verified against the exact target
schema; `EventsRepository`'s query logic is redesigned off `start_at`/
`end_at` onto `start_date`/`end_date` with an explicit, documented
international-date-boundary strategy; every other Event-consuming
surface was freshly re-audited and confirmed clean; a true date-only row
and a start-known/end-unknown row were both proven insertable locally
with no fabricated data, then cleaned up; the full-time regression and
midnight-boundary shapes were reconfirmed unchanged; the full validation
suite passes at 1459/1459 with zero weakened tests; nothing is staged,
committed, or pushed.

**Do not deploy. Do not insert Batch-1 Events.**

EVENT TIME PRECISION — PHASE C NULLABLE EXACT-INSTANT MODEL IMPLEMENTED
LOCALLY, DATE-ONLY EVENTS PROVEN, READY FOR HUMAN PRODUCTION APPLY
REVIEW
