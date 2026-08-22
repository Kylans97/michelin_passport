# EVENT TIME PRECISION — PHASE A ADDITIVE SCHEMA PRE-APPLY

Phase A of the human-approved
`docs/Architecture/Events/EVENT_TIME_PRECISION_ARCHITECTURE_AUDIT.md`.
One additive migration, applied and verified against the **local**
development database only. **Not deployed to production.**

## MIGRATION

`supabase/migrations/20260822120000_events_v2_time_precision_phase_a.sql`
— full text in the migration file itself; summary:

1. `ALTER TABLE events ADD COLUMN start_date date, end_date date,
   start_time time, end_time time` (all nullable initially).
2. `UPDATE events SET ...` — backfills every existing row's
   `start_date`/`start_time`/`end_date`/`end_time` from its own
   `start_at`/`end_at` + `timezone`, applying the midnight-boundary rule
   to `end_date` (see below).
3. `ALTER TABLE events ALTER COLUMN start_date SET NOT NULL, ALTER
   COLUMN end_date SET NOT NULL` — now safe, every row has a value.
4. `ALTER TABLE events ADD CONSTRAINT events_local_dates_valid CHECK
   (end_date >= start_date)`.

`start_at`, `end_at`, `events_dates_valid`, `events_validate_timezone`,
RLS, and every existing index are **untouched** by this migration.

## BACKFILL SEMANTICS

```sql
start_date = (start_at at time zone timezone)::date
start_time = (start_at at time zone timezone)::time
end_time   = (end_at at time zone timezone)::time
end_date   = case
  when (end_at at time zone timezone)::time = '00:00:00'
    then ((end_at at time zone timezone)::date - 1)
  else (end_at at time zone timezone)::date
end
```

`end_date` represents the **last active Event date**, not the calendar
date containing the raw end instant — the one deliberate departure from a
naive cast, and the reason a plain `(end_at AT TIME ZONE
timezone)::date` was rejected during the architecture audit.

## MIDNIGHT BOUNDARY

Proven against the real, production-matching local row for 't
Preuvenemint (`end_at = 2026-08-30 22:00:00+00`, `timezone =
Europe/Amsterdam`):

| Field | Naive cast would give | Migration's actual result |
|---|---|---|
| `end_at` local | `2026-08-31 00:00:00` | (unchanged, same instant) |
| `end_date` | `2026-08-31` (wrong — implies the festival ran into a 5th day) | **`2026-08-30`** (correct — matches "through Sunday") |
| `end_time` | — | `00:00:00` (kept exactly as sourced — a real midnight boundary, not fabricated) |

`end_date` and `end_time` are allowed to name different calendar days on
purpose: `end_date` answers "which day does this Event's activity belong
to," `end_time` answers "what was the actual sourced clock reading" —
conflating the two would either lose the true `00:00:00` value or
misrepresent the festival's actual last active day. This distinction is
documented directly in the migration file's own comments, not only here.

## CONSTRAINTS

Only `events_local_dates_valid` (`end_date >= start_date`) was added.
**Deliberately no `end_time >= start_time` constraint** — invalid for an
overnight Event (`end_date > start_date`, `end_time` numerically less
than `start_time`), for a multi-day Event in general, and meaningless
whenever either time is unknown. A stricter-looking constraint here would
be actively incorrect, not merely unnecessary — matching the audit's own
explicit "prefer fewer truthful constraints" instruction.

## INDEX DECISION

**No index added on `start_date` in Phase A.** Current Flutter still
queries/sorts exclusively on `start_at` (`EventsRepository`,
`EventAttendanceRepository` — confirmed unchanged, zero Dart touched by
this task) — an index on a column nothing queries yet would be pure
overhead with no measurable benefit until Phase B actually migrates
sorting/filtering logic onto `start_date`. Deferred to Phase B/C, where
it can be added alongside the code that would actually use it, and sized
against real query plans at that time rather than guessed now.

## RLS

**Zero RLS changes.** `events_public_read` is a table-level policy
(`moderation_status = 'published'`) with no column list — the four new
columns are automatically covered by the existing policy exactly like
every other column on the table, requiring no policy edit. Verified
directly by reading `pg_policies` before and after the migration; both
identical.

*(Unrelated note, surfaced by the local-database tooling and not part of
this task's scope: the local dev database reports `public.spatial_ref_sys`
— a PostGIS system table — has RLS disabled. This is pre-existing, not
introduced or touched by this migration, and not addressed here; flagging
only because the tooling requires surfacing it.)*

## LOCAL APPLY

Applied via `supabase migration up --local` against the local dev
database (`127.0.0.1:54322`), which was already fully synced with every
prior migration through `20260821120000` before this one was added.
Post-apply schema read directly confirms:

| Column | Type | Nullable |
|---|---|---|
| `start_at` | timestamptz | **NO** (unchanged) |
| `end_at` | timestamptz | **NO** (unchanged) |
| `timezone` | text | **NO** (unchanged) |
| `start_date` | date | **NO** (new) |
| `end_date` | date | **NO** (new) |
| `start_time` | time | **YES** (new) |
| `end_time` | time | **YES** (new) |

Both `events_dates_valid` and the new `events_local_dates_valid` exist
simultaneously post-migration.

## EXISTING EVENT VERIFICATION

The local dev database's own seed data contains exactly 1 of the 4
production Events (`'t Preuvenemint`, same values, different `id`) — the
other 3 are not part of the local seed script. To verify the backfill
logic against all 4 real production values (not merely 't
Preuvenemint), the other 3 were **temporarily inserted with their exact
production values** (single-statement transactions — the local CLI's
query tool does not support multi-statement/explicit
`BEGIN`/`ROLLBACK` scripts, confirmed empirically — see Transitional
Date-Only Test for how the "no-writes" requirement was still honored),
verified, then deleted, restoring the local database to its original
1-row state.

| Event | timezone | start_at | start_date | start_time | end_at | end_date | end_time |
|---|---|---|---|---|---|---|---|
| 't Preuvenemint | Europe/Amsterdam | 2026-08-27 16:00 UTC | **2026-08-27** | 18:00 | 2026-08-30 22:00 UTC | **2026-08-30** | **00:00** |
| Wildfestival | Europe/Amsterdam | 2026-09-13 11:00 UTC | 2026-09-13 | 13:00 | 2026-09-13 15:00 UTC | 2026-09-13 | 17:00 |
| Erloom x Henrique Sá Pessoa | Europe/Amsterdam | 2026-09-25 10:00 UTC | 2026-09-25 | 12:00 | 2026-09-27 21:00 UTC | 2026-09-27 | 23:00 |
| Vergeet Mij Niet Gala | Europe/Amsterdam | 2026-10-06 16:00 UTC | 2026-10-06 | 18:00 | 2026-10-06 21:59 UTC | 2026-10-06 | 23:59 |

Every value independently cross-checked by re-running the exact backfill
expression live against the stored rows — all 8 derived values (4 events
× start+end) matched the recomputed formula exactly, zero discrepancies.
**'t Preuvenemint is the flagged midnight-boundary row** — `end_date
= 2026-08-30`, one day before what a naive cast would have produced. No
information loss on any of the 4: every original `start_at`/`end_at`
value is completely unchanged and still present.

## TRANSITIONAL DATE-ONLY TEST

Attempted, as a single statement (auto-rolled-back by Postgres on
failure — no explicit `ROLLBACK` needed since the statement never
succeeds):

```sql
insert into public.events (
  name, description, start_at, end_at, start_date, end_date, timezone,
  country_code, city, venue_name, event_type, status, moderation_status
) values (
  'Phase A date-only fixture test', 'transitional test, expected to fail',
  null, null, '2026-11-01', '2026-11-01', 'Europe/Amsterdam',
  'NL', 'Test City', 'Test Venue', 'dinner', 'upcoming', 'published'
);
```

**Result: rejected**, exactly as required —
`null value in column "start_at" of relation "events" violates not-null
constraint`. This proves two things at once: the new columns
structurally accept a genuinely date-only shape (`start_date`/`end_date`
supplied, `start_time`/`end_time` omitted/null — no error there), **and**
the legacy `start_at`/`end_at` requirement still actively blocks a truly
time-less insert — Phase A is intentionally transitional, not yet a
working date-only-Event feature. Nothing was written; no cleanup
required.

## BACKWARD COMPATIBILITY

`flutter analyze`: 0 issues. `flutter test`: 1401/1401 passing —
unchanged, since no Dart file was touched. `EventsRepository.loadEvents`
already uses a bare `.select()` (confirmed by direct file read, not
assumed) — the four new columns flow into every existing JSON response
automatically; `Event.fromJson` simply ignores unrecognized keys, so
nothing breaks on read.

**One operational nuance surfaced only by actually running this migration
locally, not knowable from the schema design alone**: this migration adds
**no trigger** to auto-derive `start_date`/`end_date` on new inserts —
confirmed directly when a test insert supplying only
`start_at`/`end_at`/`timezone` (no `start_date`/`end_date`) failed with a
`NOT NULL` violation on `start_date`. This does not affect the live
Flutter app at all (the app never inserts Events — `events` has no
client-facing `INSERT`/`UPDATE`/`DELETE` policy, confirmed by RLS read;
only service-role/import scripts write to this table). It does mean: any
future manual/service-role Event insert — including a future Batch-1
apply — must explicitly supply `start_date`/`end_date` (and optionally
`start_time`/`end_time`) going forward, not only `start_at`/`end_at`.
Deliberately not solved with an auto-populating trigger here — that would
be scope beyond what was requested ("add these four columns," not "add
new derivation logic") — flagged instead as a concrete Phase
B/operational note.

## BATCH-1 IMPACT

Not inserted — documented only, exactly as instructed. Current: 2/10
production-ready under the legacy full-timestamp model. Once Phase A
through C are fully rolled out (this task is Phase A only): all 6
originally time-held candidates clear the time gate; 4 are expected to
become otherwise fully production-ready (Bas van Kranen x Sang Hoon
Degeimbre, Douro to Table, Ugly Butterfly, Forces of Nature); SHEf's
Kitchen Party remains compatible/unaffected; Marchal x Seafood Gastro can
drop its invented `end_time` estimate in favor of a sourced start time
with a genuinely unknown end; Couverts sur Mer and DolomitiGourmet remain
held for their own, unrelated session-model reasons. This is unchanged
from the architecture audit's own quantification — Phase A's schema work
doesn't change the count on its own; Phase B (Dart) is what would let any
of this actually be re-applied.

## DATABASE

migration files created = **1**
production migrations deployed = **0**
production schema changes = **0**
production data writes = **0**
Dart changes = **0**
storage writes = **0**

## VALIDATION

`dart format --set-exit-if-changed .`: 0 files changed. `flutter
analyze`: 0 issues. `flutter test`: 1401 passed, 0 failed. `supabase
migration list --linked`: local list now shows the new
`20260822120000` migration with an **empty** `remote` value — every
prior migration remains in sync, only the new one is unapplied.
`supabase db push --linked --dry-run`: confirms **exactly one** pending
migration (`20260822120000_events_v2_time_precision_phase_a.sql`), not
pushed. `git status --short`: only this task's two new files (this doc +
the migration file) plus the same long-standing untracked artifacts from
prior sessions.

## FILES

New (this task):
- `supabase/migrations/20260822120000_events_v2_time_precision_phase_a.sql`
- `docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_A_PRE_APPLY.md`
  (this file)

Both untracked/unstaged.

## GIT

Nothing staged, nothing committed, nothing pushed.

## PHASE B CONTRACT

Must land BEFORE `start_at`/`end_at` are ever relaxed (Phase C). Phase B
must:

- Extend `Event`/`Event.fromJson` to read `start_date`/`end_date`/
  `start_time`/`end_time` (alongside, not instead of, `start_at`/`end_at`
  during the transition).
- Introduce precision-aware formatters (per the architecture audit's own
  Display Rules table) replacing the unconditional
  `formatEventDateRange`/`formatEventDateTime` calls.
- Migrate sorting: `start_date` primary, known-time-before-unknown-time
  secondary, `id` tertiary — replacing every raw `startAt.compareTo` site
  (Trip matching, Explore's featured-event selector, Step 8A's ranking
  tie-break, both repository `.order('start_at')` calls).
- Migrate lifecycle logic (`_hasEnded` and everywhere it's read) to the
  local-day-end rule when `end_time`/`end_at` is unknown, exact-instant
  fast path when known.
- Migrate Attendance eligibility
  (`event_attendance_eligibility.dart`) to the same local-day-end
  fallback, preserving the existing 30-day lookback window unchanged.
- Migrate Trip matching (`eventMatchesTrip`) to read `start_date`/
  `end_date` directly, dropping the `eventLocalDateTime`+truncation step
  entirely (a genuine simplification, not just a compatibility shim).
- Migrate repository date-range filters
  (`EventsRepository.loadEvents`'s `.gte`/`.lte`,
  `EventAttendanceRepository`'s upcoming/past split) to compare against
  `start_date`/`end_date` rather than assuming `start_at`/`end_at` always
  exist.
- Preserve full-time Event behavior exactly (all 4 live rows, and any
  future fully-precise row) — zero visible regression for the common
  case.
- Add fixtures/tests for date-only and start-known-end-unknown Events
  across all 17 currently-non-nullable-aware test files (or a new shared
  fixture helper replacing the per-file pattern), per the architecture
  audit's own Test Plan.

## PHASE C CONTRACT

Only after Phase B has shipped and been physically device-tested may
Phase C:

- `ALTER TABLE events ALTER COLUMN start_at DROP NOT NULL, ALTER COLUMN
  end_at DROP NOT NULL`.
- Replace `events_dates_valid` (`end_at >= start_at`) with a version that
  no longer requires `start_at`/`end_at` to exist (the new
  `events_local_dates_valid` already covers the date-level ordering
  guarantee independently).
- Revisit the Index Decision above now that `start_date` has real
  consumers.

**No Phase C migration exists or is proposed in this task.**

## DECISION

1. **Were start_date/end_date added and backfilled safely?** Yes —
   additive, zero data loss, verified against all 4 real production
   values.
2. **Are they NOT NULL after migration?** Yes.
3. **Are start_time/end_time nullable?** Yes.
4. **Were existing exact times preserved?** Yes — `start_at`/`end_at`
   completely untouched; the new columns are a faithful derivation
   alongside them, not a replacement.
5. **Was 't Preuvenemint's midnight boundary handled correctly?** Yes —
   `end_date = 2026-08-30` (not `2026-08-31`), proven against the real
   row, matching the architecture audit's rule exactly.
6. **Are start_at/end_at still NOT NULL?** Yes — confirmed both by schema
   read and by the transitional date-only insert test failing as
   required.
7. **Did any RLS change?** No — zero policy edits; the existing
   table-level policy already covers the new columns.
8. **Can current Flutter continue working unchanged?** Yes —
   `flutter analyze`/`flutter test` both fully green, zero Dart touched,
   the bare `.select()` read path already flows new columns through
   automatically.
9. **Is exactly one migration pending for production?** Yes — confirmed
   by both `supabase migration list --linked` and `supabase db push
   --linked --dry-run`.
10. **Is Phase A safe to deploy before Phase B?** Yes — every check in
    this report confirms the live app is unaffected either way; the one
    operational nuance (future inserts need `start_date`/`end_date`
    supplied explicitly) affects only manual/service-role writes, which
    already require the person performing them to be aware of the
    current schema before writing anything, exactly as every prior
    apply in this session already assumed.

**Requesting explicit human approval for deploying exactly this one
migration** (`20260822120000_events_v2_time_precision_phase_a.sql`) to
production — nothing else in this task is proposed for deployment.

EVENT TIME PRECISION — PHASE A ADDITIVE SCHEMA PREPARED AND LOCALLY
VERIFIED, READY FOR HUMAN PRODUCTION APPLY REVIEW

STOP.

Do not deploy.
