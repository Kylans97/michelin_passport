# EVENT DATE / TIME PRECISION — ARCHITECTURE AUDIT

Read-only architecture audit. No schema changes, no migrations, no Dart
changes, no production writes. Everything below is a recommendation for
human review before any implementation.

## PROBLEM CONFIRMED

Of Batch 1's 10 candidates, 6 were held specifically because an official
source confirmed the Event's DATE but never published an exact start
time, and the current schema has no way to store that honestly — every
`events.start_at`/`end_at` is a `timestamp with time zone`, `NOT NULL`,
with no "time unknown" representation. The only two options today are:
invent a time (rejected — this app's own standing rule is "never invent a
time to satisfy schema," proven in practice by every one of those 6
holds) or withhold the Event entirely. The second Batch-1 apply doc
already lived this exact tension: `Marchal x Seafood Gastro`'s `end_at`
was a disclosed *operational estimate*, not a sourced fact, because the
schema gave no other option once a start time WAS known. The problem is
real, confirmed by direct production evidence, not hypothetical.

## CURRENT DATABASE MODEL

Read directly from `information_schema`/`pg_catalog` on the linked
production database (not from memory or migration files alone):

| Column | Type | Nullable | Default |
|---|---|---|---|
| `start_at` | `timestamp with time zone` | **NO** | none |
| `end_at` | `timestamp with time zone` | **NO** | none |
| `timezone` | `text` | **NO** | none |
| `status` | `text` | NO | `'upcoming'` |
| `created_at` | `timestamp with time zone` | NO | `now()` |

**Constraints** (`pg_constraint` on `public.events`):
`events_dates_valid`: `CHECK (end_at >= start_at)` — the only cross-field
time constraint. `events_status_check`, `events_admission_type_check`,
`events_availability_status_check`, `events_event_type_check`,
`events_moderation_status_check` are unrelated taxonomy checks.

**Indexes**: `events_start_at_idx` (btree on `start_at`) is the only
time-related index — backs both the `ORDER BY start_at` sort every
repository method uses and the `.gte('end_at', ...)`/`.lte('start_at',
...)` range filters. `events_status_idx` and `events_country_idx` exist
separately.

**Trigger**: `events_validate_timezone` (`BEFORE INSERT OR UPDATE OF
timezone`) calls `validate_event_timezone()`, rejecting any non-IANA
`timezone` value — confirmed unrelated to `start_at`/`end_at`
themselves, so it needs no change under any option below.

**RLS**: `events_public_read` (`SELECT`, `qual: moderation_status =
'published'`) — no time-based logic in RLS at all; irrelevant to this
audit.

**Note on `timezone`'s Dart-vs-DB nullability mismatch**: the live DB
column is `NOT NULL`, but `Event.timezone` in Dart is still typed
`String?` (nullable) — a leftover from the Timezone Hardening migration's
own staged rollout (nullable in Dart to tolerate pre-hardening rows,
tightened to `NOT NULL` in the DB once backfilled). This is pre-existing,
unrelated to this audit, and not something this task proposes changing —
noted only because the same staged-tightening pattern is exactly what
this audit recommends reusing for `start_at`/`end_at` (see Migration
Strategy).

## CURRENT DART ASSUMPTIONS

`Event` (`lib/models/event.dart`): `startAt`/`endAt` are `final DateTime`
(non-nullable, `required`); `fromJson` does an unconditional
`DateTime.parse(json['start_at'] as String)` — a null/missing key would
throw at parse time, before any downstream Dart code runs at all. This is
the single most fundamental site that would need to change first.

A full codebase census (via a dedicated read-only search, not a partial
grep) found every `startAt`/`endAt` consumer. None of them null-check
today — every one assumes both fields are always present:

- **`Event.fromJson`** (`lib/models/event.dart`) — origin point.
- **`eventLocalDateTime`** (`lib/core/utils/event_time.dart`) — the one
  shared timezone-conversion helper; already tolerates a null
  *timezone*, but its `instant` parameter (i.e. startAt/endAt) is
  required non-null.
- **`formatEventDateRange`/`formatEventDateTime`**
  (`lib/features/events/event_date_format.dart`) — every card/detail
  display path funnels through these; both assume non-null instants.
- **`event_meta_section.dart`** — Event Detail's own "at a glance" block
  is the one site rendering `startAt` and `endAt` as two *separate*
  lines rather than one compact range string — the site most exposed to
  needing an explicit per-field fallback.
- **`canAttendEvent`** (`event_detail_screen.dart:66`) and the whole
  **attendance-eligibility subsystem**
  (`lib/models/event_attendance_eligibility.dart`: `_hasEnded`,
  `_withinPromptWindow`, the prompt-candidate sort comparator) — all
  keyed directly off `endAt.isAfter(now)`/`.compareTo`, unconditional.
- **`eventMatchesTrip`/`eventsMatchingTrip`**
  (`lib/models/event_trip_match.dart`) — both fields feed
  `eventLocalDateTime` directly for Trip-date-overlap matching and
  chronological sort.
- **`selectFeaturedEvent`** (`lib/features/explore/discovery_selectors.dart`)
  and **`rankEventsForDiscovery`**
  (`lib/features/events/event_discovery_ranking.dart`) — both sort on
  `startAt` directly (Step 8A's own tie-breaker included).
- **`EventsRepository`/`EventAttendanceRepository`** — SQL-level
  `.gte('end_at', ...)`, `.lte('start_at', ...)`, `.order('start_at',
  ...)` — assumes a comparable, non-null column at the Postgres level too.
- **17 test fixture files** each define their own local `Event _event({
  required startAt, required endAt, ... })` factory — every one would
  need a nullable-aware update (or a single shared fixture to replace
  them, which does not exist today).

**Confirmed NOT touching `startAt`/`endAt` at all** (a genuinely useful
negative finding): `lib/features/map/` (My Map plots purely on
`latitude`/`longitude` — `event_map_preview_sheet.dart`'s date line is
display-only, not an eligibility filter), `lib/core/analytics/`
(`AnalyticsProperties` has no date/time field at all), and
`EventDiscoveryItem` itself (a pure wrapper, no field access).

`copyWith`/equality: `Event` has neither a `copyWith` nor a value-equality
override today — every "change" is a fresh `Event.fromJson` from a new
query result, so there's no separate equality-semantics risk to design
around here.

**What would break if `startAt`/`endAt` became nullable, unmodified**:
every unconditional access above would fail to compile (Dart's
null-safety forces this — a real advantage over a silent-sentinel
approach, see Options below) until each site is deliberately updated with
a defined "what happens when unknown" rule. This audit defines those
rules per-category in the sections that follow; none require guessing.

## REAL-WORLD TIME CASES

Six cases, as specified. The MVP recommendation covers **A, B, C, D** (all
"exact instant may be genuinely unknown" shapes) plus the existing,
already-fully-supported **E**; **F** is explicitly out of scope for time
precision — it's a session-identity problem, not a time-precision one
(see Session-Model Boundary).

| Case | Example | MVP support |
|---|---|---|
| A. Date only | "29 September 2026" | **Yes — new capability** |
| B. Start known, end unknown | "29 Sep 2026 · 18:30" | **Yes — new capability** |
| C. Start + end known | "29 Sep 2026 · 18:30–23:00" | Already supported (unchanged) |
| D. Multi-day, dates known, daily times unknown | "25–27 Sep 2026" | **Yes — new capability** |
| E. Multi-day, global open/close known | "25 Sep 12:00 → 27 Sep 23:00" | Already supported (unchanged) — every one of the 4 live Events is this shape today |
| F. Multiple distinct sessions | Couverts sur Mer's two weekends | **Explicitly out of scope** — needs a session-model (multiple Event or child-session rows), not a time-precision change |

## OPTIONS CONSIDERED

**Option A — nullable start_at/end_at + add date fields.** Two sources of
truth for the date component (the nullable timestamptz's date part, and a
separate always-present date column) that can drift. Rejected as the
final shape, though its instinct (add real date columns) is correct and
is folded into the recommendation below.

**Option B — keep `start_at` as an anchor + add a `time_precision`
enum.** Requires storing *some* wall-clock time in `start_at` even when
unknown (there's no "null hour" inside a single timestamptz), which is
either a disguised version of Option D (fake time, just now
enum-flagged) or requires every single one of the ~10 audited call sites
to check the enum before trusting `start_at`'s time-of-day component —
a silent-failure risk (forgetting the check compiles fine, just misuses
a meaningless hour) rather than the compile-time safety nullability gives.
Rejected.

**Option C — separate `start_date`/`end_date`/`start_time`/`end_time` +
`timezone`.** Dates always known and required; times nullable and
independent per side. Directly encodes the real-world truth this audit
exists to solve. Compared below.

**Option D — timestamptz only, with midnight/end-of-day placeholders.**
**Rejected, exactly as the task suspects.** A genuine event starting at
00:00 local is indistinguishable in storage from "we don't know the
time" — this is not a hypothetical: 't Preuvenemint's own `end_at`,
converted to Europe/Amsterdam, lands on `00:00` local (see Backfill's
midnight-boundary discussion) — a real production row that would become
ambiguous under this option. Directly violates the "never invent a time"
rule this whole audit exists to enforce, and reintroduces exactly the
silent-misuse risk Option B has, with no flag at all to even suspect it.

**Option E (recommended) — Option C, with `start_at`/`end_at` retained as
nullable, backfill-populated "exact instant, when known" convenience
columns, not the source of truth.** `start_date`/`end_date` (date,
`NOT NULL`) become the canonical anchor for every date-based
consumer (sorting, lifecycle, Trip matching, display). `start_time`/
`end_time` (time, nullable) capture the wall-clock time when actually
published. `start_at`/`end_at` remain as nullable `timestamptz` — present
(and equal to what they hold today) whenever a date+time+timezone combo
is fully known, `NULL` otherwise — so every exact-instant consumer that
genuinely needs one (SQL range filters, attendance-eligibility precision)
keeps a fast, simple path for the common case and falls back to
date-based logic only when the finer-grained value is missing.

| Dimension | Option A | Option B | Option C | Option D | **Option E (recommended)** |
|---|---|---|---|---|---|
| Truthfulness | Two sources of truth, drift risk | Silent misuse risk | Truthful | **Actively false** | Truthful, single source of truth per grain |
| Migration safety | Additive but ambiguous | Additive, risky | Additive | N/A (rejected) | Additive, phased (see below) |
| Timezone correctness | Unchanged | Unchanged | Unchanged | Unchanged | Unchanged |
| Sorting | Ambiguous (which column?) | Enum-gated, fragile | Clean (date, then time) | Falsely precise | Clean (date, then time) |
| UI formatting | Needs precision inference | Needs enum branch | Direct null-check | Wrong data | Direct null-check |
| Trip matching | Unclear which field | Enum-gated | Simpler than today (no truncation needed) | Falsely precise | Simpler than today |
| Attendance | Needs precision-aware rule | Enum-gated | Needs date-based fallback rule | Falsely precise (silently wrong) | Date-based fallback, exact-instant fast path when available |
| Future webapp | OK | Awkward | Clean | Wrong data | Clean |
| schema.org/Event | Ambiguous | Awkward | **Maps 1:1** (date-only or date-time string) | Wrong data | **Maps 1:1** |
| Host-created validation | App/server layer either way | App/server layer either way | App/server layer either way | N/A | App/server layer (see Host-Created Events) |
| Developer complexity | Medium-high (two sources) | Medium (enum everywhere) | Low-medium | Low but wrong | Low-medium, staged |
| Backward compatibility | OK | OK | OK | OK (no change) | **Best — existing timestamptz consumers keep working during the transition** |

**Recommendation: Option E.**

## DATE-ONLY EVENTS

`start_date = end_date`, `start_time = NULL`, `end_time = NULL`,
`start_at = NULL`, `end_at = NULL`, `timezone` still required. Display:
`"29 Sep 2026"` (exactly `formatEventDateRange`'s existing same-day
branch, just fed `start_date`/`end_date` instead of derived-from-instant
values). Lifecycle: active through end of `end_date` in `timezone` (see
Lifecycle).

## START-KNOWN / END-UNKNOWN

`start_date = end_date` (single day) or spans (multi-day), `start_time`
populated, `end_time = NULL`. `start_at` populated (date+time+timezone
combine cleanly since the start side is fully known); `end_at = NULL`
since the end side isn't. Display: `"29 Sep 2026 · 18:30"` — no trailing
dash, no "–??:??" placeholder. This is **exactly** `Marchal x Seafood
Gastro`'s real shape once its estimated `end_at` is honestly dropped
(see Batch-1 Impact) — the clearest concrete proof this case matters in
practice, not just in theory.

## MULTI-DAY EVENTS

Two genuinely different sub-shapes, both already distinguishable under
Option E without any new columns:

- **D (dates known, daily times unknown)**: `start_date` <
  `end_date`, both `start_time`/`end_time` null. Display:
  `"25–27 Sep 2026"` (multi-day, no times) — Toquicimes' actual shape.
- **E (global open/close known)**: `start_date` < `end_date`,
  `start_time`/`end_time` both populated (each in their own respective
  day's local wall-clock). Display uses the *existing*
  `formatEventDateRange` multi-day branches, now optionally suffixed with
  the known times — exactly what all 4 live Events already are.

Neither sub-shape needs the multi-*session* machinery — a genuinely
single continuous multi-day Event (one venue, one ticket, one
description) is still one row either way.

## DISPLAY RULES

| Precision | Rule | Example |
|---|---|---|
| Date only | Date range only, no time | `29 Sep 2026` |
| Multi-day, date only | Existing multi-day date format, no time | `25–27 Sep 2026` |
| Start known | Date + start time, no dash/placeholder | `29 Sep 2026 · 18:30` |
| Full | Existing date + time range | `29 Sep 2026 · 18:30–23:00` |
| Multi-day, full | Existing multi-day range formatting, both ends' times shown per the existing `event_meta_section.dart` two-line pattern | unchanged |

**Never render "Time unknown."** Absence of a time already communicates
"date-only" on its own — an explicit "unknown" label would read as a
data-quality complaint aimed at the user, not a calm editorial choice.
This directly answers §14's own instruction, and matches this app's
established convention of omitting rather than apologizing for absent
optional data (e.g. `VenueAboutSection`'s own "omit the section" rule
already cited elsewhere in this codebase).

## SORTING

Primary sort: `start_date` ascending (local calendar date, never a raw
instant — this is actually a *simplification* versus today's
`eventLocalDateTime`-then-truncate dance, since `start_date` already IS
the local calendar date, stored directly). Secondary sort within the same
`start_date`: **known start time before unknown start time.** Rationale:
a date-only Event with an unknown start time could start at any hour —
placing it after every Event with a *known* earlier-in-the-day time is
the only ordering that never implies false precision (it deliberately
does NOT sort at an arbitrary midnight position, which would falsely
imply "starts first"). Tertiary tie-break: `id` (unchanged, matches Step
8A's own existing deterministic tie-break precedent). Step 8A's own
`rankEventsForDiscovery` tier logic is unchanged — only its innermost
chronological tie-break comparator needs this same three-level rule
substituted for its current single `startAt.compareTo`.

## LIFECYCLE

**Upcoming → past transition, without ever storing a fake `end_at`:**

- Exact end known (`end_at` populated): unchanged — `!end_at.isAfter(now)`,
  exactly today's `_hasEnded` logic.
- Single-day, end time unknown: past once the current *local* calendar
  date (in `timezone`) is after `end_date` — i.e., active through the end
  of that local day.
- Multi-day, end time unknown: past once the current local calendar date
  (in `timezone`) is after `end_date` — same rule, just `end_date` may be
  several days after `start_date`.

Computed, not stored — this needs a new small pure helper (not built
here) that takes `(end_date, end_time, timezone, now)` and returns
whether the Event has ended, using `eventLocalDateTime`-style zone
conversion only on `now` (never inventing an `end_at`). This is a
genuinely small, independently-testable function, matching this
codebase's own established "pure function, no Supabase" convention.

## ATTENDANCE

Exact end known: unchanged — the existing `_hasEnded`/`_withinPromptWindow`
instant-based logic in `event_attendance_eligibility.dart` keeps working
exactly as today (this is `Option E`'s whole point — full-precision
Events, i.e. all 4 live rows today, are entirely unaffected).

End time unknown: **prompt eligibility begins only after the Event's
final local calendar day has fully ended** (i.e. the same Lifecycle rule
above, evaluated at the moment `_hasEnded` would otherwise fire). This is
explicitly *more conservative* than guessing an end time — a later prompt
is always safer than a premature one (matches the task's own stated
principle, and matches this module's own existing doc-comment philosophy
of "a later prompt beats a wrong one"). The `attendancePromptLookbackWindow`
(30 days) then applies from that same local-day-end boundary, unchanged
in duration.

## TRIPS

Trip matching actually gets **simpler**, not harder, under Option E:
today's `eventMatchesTrip` calls `eventLocalDateTime(event.startAt,
event.timezone)` then truncates to Y-M-D specifically *because* the only
available field is a full instant. With `start_date`/`end_date` stored
directly as the event's own local calendar dates, that
conversion-then-truncation step disappears entirely — the function
compares `event.startDate`/`event.endDate` straight against
`trip.startDate`/`trip.endDate`, no timezone math needed at match time at
all (the timezone-correctness work already happened once, at write time,
when `start_date` was derived). A date-only Event matches a Trip exactly
as precisely as a full-precision one — Trip matching was never actually
about time-of-day, only calendar dates, so nothing is lost. No device-
timezone leakage risk, same as today (if anything, less surface area for
it to leak through).

## PERSONALIZED DISCOVERY

Step 8A's relevance hierarchy (Trip > Friend Going > Followed Host >
Friend Interested > Popularity > Chronology) is completely unaffected —
none of those five signal types depend on time precision at all. Only the
innermost chronological tie-break (`rankEventsForDiscovery`'s
`startCompare`) needs the same `start_date`-then-known-time-first rule
described under Sorting, substituted in place of today's single
`startAt.compareTo`. No redesign of Step 8A itself, exactly as instructed.

## HOST-CREATED EVENTS

Recommend validation at the **application/submission-boundary layer**, not
a blanket table-level `CHECK` constraint on `events` itself — a table-wide
constraint requiring `start_time`/`end_time` `NOT NULL` would incorrectly
reject legitimate editorial date-only rows too, defeating the entire
point of this audit. Recommended shape: a future host-Event-submission
path (Flutter form validation for immediate UX feedback, backed by a
server-side function/RPC that actually performs the write) requires
`start_date`, `start_time`, `end_date`/`end_time`, and `timezone` all
non-null *at that specific boundary* — the same pattern this codebase
already uses to let import/enrichment scripts write catalogue rows with a
different (looser) shape than what client-side RLS would allow a regular
app user to write directly. The `events` table itself stays permissive
enough for both paths; the *host-submission RPC specifically* is where
the stronger rule lives.

## WEB / SCHEMA.ORG

This is a genuinely useful design test, and Option E passes cleanly:
`schema.org/Event.startDate`/`endDate` explicitly accept either a
date-only ISO 8601 string (`"2026-09-29"`) or a full date-time string
(`"2026-09-29T18:30:00+02:00"`) — precisely the two shapes Option E
naturally produces (date-only when `start_time` is null, full date-time
when it's populated). No web implementation is built here, but this
mapping working out this cleanly is a strong independent signal Option E
is the right shape, not an artifact of designing around today's Dart code
alone.

## EXISTING PRODUCTION EVENTS

Read directly, converted to local time via `timezone`:

| Event | Start (local) | End (local) | Classification |
|---|---|---|---|
| 't Preuvenemint | 2026-08-27 18:00 CEST | 2026-08-31 00:00 CEST | MULTI_DAY_FULL |
| Wildfestival | 2026-09-13 13:00 CEST | 2026-09-13 17:00 CEST | FULL_TIME |
| Erloom x Henrique Sá Pessoa | 2026-09-25 12:00 CEST | 2026-09-27 23:00 CEST | MULTI_DAY_FULL |
| Vergeet Mij Niet Gala | 2026-10-06 18:00 CEST | 2026-10-06 23:59 CEST | FULL_TIME |

Every one of the 4 has both `start_time` and `end_time` fully known — all
four would backfill to `start_date`/`end_date`/`start_time`/`end_time`
**exactly**, losing nothing, with `start_at`/`end_at` retained unchanged
under Option E (they're never dropped, only *also* mirrored into the new
columns). No production update is proposed or needed for the existing
rows.

**'t Preuvenemint's own end time is the concrete midnight-boundary case**
this audit's Backfill section had to solve explicitly — see below.

## BATCH-1 IMPACT

Re-evaluated against Option E, all 6 originally time-held candidates:

| Candidate | Time gate under Option E | Still held for another reason? |
|---|---|---|
| Bas van Kranen x Sang Hoon Degeimbre | **Unblocked** — start_date known, start_time unknown, honestly stored | No — becomes fully production-ready |
| Toquicimes | **Unblocked** for timing | Yes — venue/address still spread across the village with no single confirmed address (MANUAL_LOCATION_REVIEW) |
| San Sebastián Gastronomika | **Unblocked** for timing | Yes — the official page's own unresolved "días 9 y 10" conflict (HOLD_SOURCE_CONFLICT) |
| Douro to Table — Dinner III | **Unblocked** | No — becomes fully production-ready |
| Ugly Butterfly x Simon Hulstone | **Unblocked** | No hard schema blocker remains — imminent-date availability re-check is an editorial caution, not a data-model gate |
| Forces of Nature x Vildgaard | **Unblocked** | No — becomes fully production-ready |

**All 6 of the 6 time-held candidates clear the TIME gate specifically.**
Of those 6, **4 become genuinely fully production-ready** with no other
change (Bas van Kranen x Degeimbre, Douro to Table, Ugly Butterfly,
Forces of Nature); 2 remain held, but for an unrelated, already-identified
reason (Toquicimes' location, Gastronomika's source conflict) — the time
model doesn't manufacture readiness those candidates were never going to
have anyway.

**Marchal x Seafood Gastro** (already production-ready today): under
Option E, its `end_time` should be **removed entirely**, not estimated —
`start_time = 18:30 Europe/Copenhagen`, `end_time = NULL`. This is a real
improvement even for an already-shippable Event: today's pre-apply doc
had to disclose an *invented* ~3.5-hour estimate as a workaround; Option E
lets that honestly become "we know it starts at 18:30, we don't know when
it ends" — exactly the case this whole audit exists to support.

**Combined Batch-1 recovery: 2 (already ready) + 4 (newly unblocked, no
other gate) = 6 of 10 fully production-ready**, plus one already-ready
Event's data becomes more honest (Marchal's `end_time`). This is the
concrete, quantified answer to "how much does this change actually
solve" — not a projection, a direct re-application of the exact same
gates the Batch-1 pre-apply already used.

## SESSION-MODEL BOUNDARY

**Reconfirmed: time precision does NOT solve Couverts sur Mer or
DolomitiGourmet.** Both remain `HOLD_SESSION_MODEL`, untouched by this
audit:

- **Couverts sur Mer**: two genuinely separate, non-contiguous weekends
  (25-27 June / 2-4 July 2027) — even with perfect time precision on
  each, they'd still need two independent Event rows (different dates
  entirely, likely different chef line-ups per weekend once announced).
  Time precision is orthogonal to this.
- **DolomitiGourmet**: three sub-events at three different venues, three
  different prices, three different (overlapping but non-identical) chef
  rosters, each independently bookable. This is exactly the case §5/§20
  warn against stretching a time-precision fix to cover — it isn't a
  timing problem at all, and Option E doesn't pretend otherwise.

No schema change proposed here would or should touch either of these —
they need a genuine session/multi-row modeling decision, a separate,
larger design question this audit deliberately does not take on.

## MIGRATION STRATEGY

Not created — sequence only, designed to guarantee zero temporary broken
state for Flutter at any point:

**Phase 1 (schema, purely additive)**: `ALTER TABLE events ADD COLUMN
start_date date, ADD COLUMN end_date date, ADD COLUMN start_time time,
ADD COLUMN end_time time` (all initially nullable at the column level
during backfill, then `start_date`/`end_date` tightened to `NOT NULL` in
the same migration once backfilled — see Backfill). `start_at`/`end_at`
are **untouched** — still `NOT NULL`, still populated, still exactly what
every existing Dart consumer reads today. `EventsRepository.loadEvents`
already uses a bare `.select()` (not an explicit column list), confirmed
by direct file read — **new columns flow into the JSON response
automatically, with zero repository-layer changes required for reads to
start receiving them.** The app is unaffected the moment this migration
ships; nothing needs to deploy in lockstep.

**Phase 2 (Dart, no schema change)**: Update `Event`/`Event.fromJson` to
read the new columns (still also reading `start_at`/`end_at` where
present, for the exact-instant fast path); update every audited call site
(formatters, `canAttendEvent`, attendance eligibility, `eventMatchesTrip`,
Step 8A's ranking comparator, the 17 test fixtures) to the new
precision-aware rules defined in this doc. Ship this release **before**
Phase 3 — the app must already know how to render/sort/lifecycle a
date-only Event before the database is ever allowed to produce one.

**Phase 3 (schema, the actual constraint relaxation)**: `ALTER TABLE
events ALTER COLUMN start_at DROP NOT NULL, ALTER COLUMN end_at DROP NOT
NULL`; replace `events_dates_valid` (`end_at >= start_at`) with an
`end_date >= start_date` based constraint (see Constraints) that no
longer requires `start_at`/`end_at` to exist. Only after this phase can a
genuinely date-only Event actually be inserted — and by this point Dart
has already been ready for one release.

**Phase 4 (future, optional)**: host-submission-boundary validation (see
Host-Created Events) — independent of the above, can land any time after
Phase 2.

This is intentionally more granular than the task's own suggested
"migration → Dart → device check → re-run enrichment" 4-step sketch,
because the actual schema dependency graph splits cleanly into "add
columns" (safe anytime) vs. "relax the old NOT NULL" (only safe once Dart
is ready) — collapsing those two into one migration would risk exactly
the "temporary broken state" the task explicitly forbids.

## BACKFILL

For all 4 existing rows (and any future full-precision row), derive:

```sql
start_date = (start_at AT TIME ZONE timezone)::date
end_date   = (end_at AT TIME ZONE timezone)::date
start_time = (start_at AT TIME ZONE timezone)::time
end_time   = (end_at AT TIME ZONE timezone)::time
```

**The midnight-boundary case, made concrete with real production data:**
't Preuvenemint's `end_at` (`2026-08-30 22:00:00+00`) converts to
`2026-08-31 00:00:00` in Europe/Amsterdam — i.e. the raw instant's local
calendar date is **Aug 31**, even though the festival is described
(description text, official site) as running through **Sunday Aug 30**.
A naive `(end_at AT TIME ZONE timezone)::date` backfill would silently
produce `end_date = 2026-08-31`, one day past what the Event actually,
truthfully represents.

**Recommended rule, stated explicitly**: `end_date` represents the
**last active Event date**, not the raw calendar date containing the end
instant. When the local end time is exactly `00:00:00`, attribute the
date to the *preceding* calendar day:

```sql
end_date = CASE
  WHEN (end_at AT TIME ZONE timezone)::time = '00:00:00'
  THEN ((end_at AT TIME ZONE timezone)::date - 1)
  ELSE (end_at AT TIME ZONE timezone)::date
END
```

Applied to 't Preuvenemint: `end_date = 2026-08-30` (correct — matches
"through Sunday"), `end_time = 00:00:00` retained as-is (still an honest,
real value — an event legitimately ending at the stroke of midnight is
still a genuinely known time, just attributed to the day it closes out,
not the day it technically ticks over into). This distinction — "calendar
date containing the end instant" vs. "last active Event date" — is
exactly the ambiguity the task asked to be resolved explicitly, and this
is the concrete rule, backed by a real row, not a hypothetical.

## CONSTRAINTS

Recommended (not built):

- `end_date >= start_date` — replaces `events_dates_valid` as the
  primary ordering guarantee once `start_at`/`end_at` become optional.
- `start_time IS NOT NULL` requires nothing further — a start time can be
  known independent of whether an end time is (Case B is legitimate on
  its own).
- `end_time IS NOT NULL` without `start_time` known — legitimate but
  unusual (an event with a known finish but unpublished start). Not
  worth a hard `CHECK`; flag as an application-layer soft warning only,
  not a database rejection, since it isn't logically impossible.
- When `start_date = end_date` and both `start_time`/`end_time` are
  known: `end_time >= start_time` (same-day ordering) — scoped
  specifically to the same-day case, since a genuinely overnight Event
  (start 22:00, end 02:00 the next day) is legitimately represented by
  `end_date > start_date` instead, not by `end_time < start_time` on the
  same day.
- `start_at IS NOT NULL` should imply `start_date`/`start_time` are both
  also derivable/consistent (an application-layer invariant, not
  necessarily a DB-level generated-column relationship, given Postgres
  timezone conversions aren't `IMMUTABLE` and can't back a stored
  `GENERATED ALWAYS AS` column cleanly).

## TIMEZONE

**No change required.** `timezone` stays `NOT NULL`, the
`validate_event_timezone` trigger stays exactly as-is — date-only Events
need a timezone just as much as full-precision ones do, for exactly the
reasons the task itself lists: end-of-day lifecycle computation (Local
Date/Lifecycle above), Trip matching (still needs to know which
calendar the date belongs to), and any future web/local-scheduling
representation. This was already correctly anticipated; confirming it
needs no revisiting is itself the useful audit finding here.

## ANALYTICS

**No impact.** Confirmed by direct inspection of
`lib/core/analytics/analytics_properties.dart`: `AnalyticsProperties` has
no date/time field at all today (only `eventCategory`, `admissionType`,
city/country, host attribution, trip/friend-signal context, attendance
`source`, etc.). Nothing needs to change, and this audit does not
recommend introducing a precision value into analytics — there's no
existing consumer that would benefit from one.

## FUTURE NOTIFICATIONS

Documented only, not built. A date-only Event cannot support a
precise "Event starts in 1 hour" reminder — there is no hour to count
down to. It CAN support a coarser "Event is tomorrow" notification, keyed
off `start_date` alone. Any future notification-scheduling logic must
check `start_time`/`start_at` for non-null before ever scheduling a
precise-time reminder, and should fall back to date-only reminder copy
otherwise — this is a design constraint to carry forward, not something
this task builds.

## TEST PLAN

Designed, not implemented:

**PARSING**: date-only row, start-known/end-unknown row, full-datetime
row, multi-day date-only row — each round-trips through `Event.fromJson`
without throwing and without inventing a value.

**DISPLAY**: one test per precision state in `event_date_format_test.dart`
(new), covering every row of the Display Rules table above, explicitly
asserting the string never contains "unknown"/"TBD"/similar.

**SORTING**: date-only vs. exact-time event on the same calendar day
(known-time-first rule); cross-timezone same-UTC-day-different-local-day
case (proves `start_date` sorting, not a raw UTC comparison, drives
order).

**LIFECYCLE**: before `start_date`, during (`start_date <= today <=
end_date` in `timezone`), immediately after local day-end, multi-day
still-active-on-day-2, multi-day past-after-`end_date`.

**ATTENDANCE**: prompt eligibility begins only after the local final day
ends (date-only case); prompt eligibility uses the exact instant
(full-precision case, unchanged regression coverage for all 4 existing
Events' shape).

**TRIPS**: date-only Event correctly matches/doesn't-match a Trip's date
range using `start_date`/`end_date` directly, no timezone leakage.

**DST**: an Event whose `start_date` falls exactly on a DST transition
date (mirrors this session's own real `SHEf's Kitchen Party` case,
2026-10-25) — proves the local-day-boundary computation handles the
23-or-25-hour day correctly.

**MIGRATION**: all 4 existing production Events' `start_date`/`end_date`/
`start_time`/`end_time` backfill exactly matches manual computation
(including the midnight-boundary rule applied to 't Preuvenemint
specifically).

**REGRESSION**: every existing full-time-precision test (all 17 audited
fixture files) continues passing unchanged in behavior — only their
construction syntax needs updating, never their asserted outcomes.

## DATABASE DECISION

**Does the Event time model need a schema change? YES.**

Smallest recommended delta: `ALTER TABLE public.events ADD COLUMN
start_date date NOT NULL, ADD COLUMN end_date date NOT NULL, ADD COLUMN
start_time time, ADD COLUMN end_time time` (Phase 1), later followed by
relaxing `start_at`/`end_at` to nullable and replacing `events_dates_
valid` (Phase 3) — both described in full in Migration Strategy. **Not
created in this task.**

## IMPLEMENTATION SEQUENCE

If approved, in dependency order (see Migration Strategy for full
rationale of why this exact ordering is required, not merely suggested):

1. **TIME STEP A** — Phase 1 schema migration (additive: new nullable-
   during-backfill columns, backfilled, then `start_date`/`end_date`
   tightened to `NOT NULL`; `start_at`/`end_at` untouched).
2. **TIME STEP B** — Dart compatibility release: `Event` model + every
   audited call site updated to the precision-aware rules in this doc;
   all 17 test fixtures updated; new tests from the Test Plan added.
   Ship and verify in production BEFORE Phase 3.
3. **TIME STEP C** — Phase 3 schema migration (`start_at`/`end_at`
   become nullable; `events_dates_valid` replaced).
4. **TIME STEP D** — physical-device regression pass across all 4
   precision states (date-only, start-known, full, multi-day), plus a
   direct re-confirmation that all 4 existing live Events render
   identically to before.
5. **TIME STEP E** — re-run the Batch-1 pre-apply gate for the 4 newly
   unblocked candidates (Bas van Kranen x Degeimbre, Douro to Table,
   Ugly Butterfly, Forces of Nature) plus Marchal's corrected `end_time`
   — a fresh pre-apply pass, not an automatic promotion, since source
   facts may have moved on by then.

## NO WRITES

migrations created = 0, migrations deployed = 0, schema changes = 0,
production writes = 0, git staged = 0, committed = 0, pushed = 0.

## VALIDATION

`flutter analyze`: 0 issues. `flutter test`: 1401 passed, 0 failed —
unchanged, no Dart code touched by this audit. `supabase migration list
--linked`: local/remote identical, no drift. `supabase db push --linked
--dry-run`: "Remote database is up to date." `git status --short`: only
this task's one new file plus the same long-standing untracked artifacts
from prior sessions.

## FILES

New (this task):
- `docs/Architecture/Events/EVENT_TIME_PRECISION_ARCHITECTURE_AUDIT.md`
  (this file)

Left untracked/unstaged, matching this repository's established
convention for architecture/enrichment research artifacts.

## GIT

Nothing staged, nothing committed, nothing pushed.

## DECISION

1. **Should externally-sourced Events be allowed with date but no time?**
   Yes — this is the entire point confirmed by real Batch-1 evidence;
   Option E supports it truthfully via nullable `start_time`/`end_time`
   over an always-required `start_date`/`end_date`.
2. **Should host-created Events still require exact start/end time?**
   Yes — enforced at the future host-submission boundary (app + server
   function), not at the shared `events` table level, so editorial
   ingestion and host self-service can have genuinely different strictness
   without one weakening the other.
3. **Should unknown times ever be represented by fake timestamps?** No —
   never. This is the one non-negotiable rule the whole audit is built
   around, and Option D (rejected) is the concrete cautionary case for
   why.
4. **What exact fields should become nullable or be added?** Add
   `start_date date NOT NULL`, `end_date date NOT NULL`, `start_time time
   NULL`, `end_time time NULL`. Later (Phase 3 only, after Dart is ready):
   relax `start_at`/`end_at` from `NOT NULL` to nullable. `timezone`
   stays `NOT NULL`, unchanged.
5. **How should date-only Events become past?** Once the current local
   calendar date (in the Event's own `timezone`) is after `end_date` —
   computed at read time, never stored as a fake `end_at`.
6. **When should their Attendance prompt begin?** Only after the Event's
   final local calendar day has fully ended — later than a premature
   guess would be, which is the explicitly-endorsed safe direction.
7. **Can Trips match them correctly?** Yes — and more simply than today,
   since `start_date`/`end_date` are already the exact local calendar
   dates `eventMatchesTrip` currently has to derive via
   `eventLocalDateTime` + truncation.
8. **Does this map cleanly to schema.org/Event?** Yes —
   `startDate`/`endDate` natively accept either a date-only or a
   date-time ISO string, matching Option E's two producible shapes
   exactly.
9. **How many of Batch 1's six time-held Events would this unblock?**
   All 6 clear the TIME gate specifically; 4 of those 6 become fully
   production-ready with no other change (Bas van Kranen x Degeimbre,
   Douro to Table, Ugly Butterfly, Forces of Nature); 2 remain held for a
   separate, already-identified reason (Toquicimes' location, San
   Sebastián Gastronomika's source conflict).
10. **Does this require a migration?** Yes — see Database Decision and
    Migration Strategy; not created in this task.

EVENT TIME PRECISION — REAL-WORLD DATE-ONLY EVENTS ARCHITECTURE AUDITED,
READY FOR HUMAN REVIEW BEFORE IMPLEMENTATION

STOP.

Do not implement.
