-- Events V2 — Event Date/Time Precision, Phase C (nullable exact-instant
-- columns + canonical browse-key index). See
-- docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_C_PRE_APPLY.md for
-- the full rationale. Phase A (already deployed) added start_date/
-- end_date/start_time/end_time as the durable local-calendar anchor.
-- Phase B (Dart, already implemented) made every consumer of
-- Event.startAt/endAt null-safe. This migration is the schema half of
-- Phase C: it relaxes start_at/end_at themselves to nullable, so a
-- genuinely date-only or start-known/end-unknown Event can be stored
-- without ever fabricating an exact instant that was never sourced.
--
-- Deployment safety: this migration does not, by itself, change what any
-- currently-live row looks like — every existing row keeps its own
-- non-null start_at/end_at exactly as today. It is safe to deploy ahead
-- of a compatible app release specifically because no date-only row will
-- be inserted until a separate, later, explicitly-gated production-data
-- step confirms a Phase-B-compatible app build is live (see the
-- pre-apply doc's Release Sequencing section for the exact gate).

-- Step 1: start_at/end_at no longer required. A date-only Event has no
-- exact instant at all; a start-known/end-unknown Event has one but not
-- the other. Neither shape can be expressed while these stay NOT NULL.
alter table public.events
  alter column start_at drop not null,
  alter column end_at drop not null;

-- Step 2: events_dates_valid, as it stands today (`end_at >= start_at`),
-- would reject any row where either side is null — CHECK constraints
-- treat a null operand as "not proven false", i.e. NULL, which normally
-- passes, EXCEPT this exact comparison already only ever ran against
-- NOT NULL columns, so no currently-live behavior actually depended on
-- that null-handling. Rewritten explicitly rather than left implicit:
-- ordering is enforced only when BOTH exact instants are known; a
-- one-sided-known or wholly-unknown exact instant is never, on its own,
-- a reason to reject a row. events_local_dates_valid (Phase A, end_date
-- >= start_date) is untouched — it remains the one ordering guarantee
-- that always applies, known-time or not.
alter table public.events
  drop constraint events_dates_valid,
  add constraint events_dates_valid check (
    start_at is null or end_at is null or end_at >= start_at
  );

-- Step 3: start_date is now the canonical browse/filter/sort key for
-- EventsRepository.loadEvents/loadEventsForCountry (Phase C's own
-- repository migration — see the pre-apply doc's Events Repository
-- section) — every future date-only row has a null start_at, so
-- events_start_at_idx can no longer serve that query, and relying on a
-- full table scan "for now" only defers a known future cost that the
-- Batch-1 backlog (30-50 Events, then hundreds) will actually hit. A
-- single-column index on start_date is added; end_date is left
-- unindexed for now — the end_date >= X half of loadEvents' conservative
-- window is a coarse "hasn't ended before the window" check, not an
-- ORDER BY key, and the catalogue is small enough that this can be
-- revisited independently if it ever becomes a bottleneck on its own
-- (see the pre-apply doc's Index Decision / Query Scale sections).
create index events_start_date_idx on public.events (start_date);

-- Deliberately untouched by this migration: events_local_dates_valid,
-- the events_validate_timezone trigger, timezone's own NOT NULL, RLS
-- policies, events_start_at_idx (still useful for exact-instant queries
-- against full-time Events; cleanup deferred, not part of this phase),
-- and events_country_code_fkey.
