-- Events V2 — Event Date/Time Precision, Phase A (additive local-date/
-- time columns + backfill). See
-- docs/Architecture/Events/EVENT_TIME_PRECISION_ARCHITECTURE_AUDIT.md
-- (human-approved) and
-- docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_A_PRE_APPLY.md for
-- the full rationale. This migration is Phase A only: it adds the new
-- canonical local-date/time columns and backfills every existing row's
-- exact values from start_at/end_at + timezone. It does NOT touch
-- start_at/end_at's own NOT NULL constraint, does NOT touch the
-- events_dates_valid check, and does NOT change RLS or the existing
-- timezone-validation trigger — every one of those stays exactly as
-- today so the currently-shipped Flutter app keeps working completely
-- unchanged. Relaxing start_at/end_at is Phase C, a separate migration,
-- gated on a compatible Dart release (Phase B) landing first.
--
-- Why start_date/end_date, not just reading start_at/end_at's own date
-- component at query time: a genuinely date-only Event (Phase C's whole
-- point) will eventually have NULL start_at/end_at, so the local
-- calendar date needs its own durable column — it can't always be
-- derived from a timestamp that may not exist. start_time/end_time are
-- nullable from the start, on purpose: today's 4 rows all have known
-- times (backfilled below), but Phase C's entire premise is that a
-- future row legitimately might not.

-- Step 1: add the four new columns, all nullable initially — start_date/
-- end_date only reach NOT NULL below, once every existing row has been
-- backfilled; a bare ADD COLUMN ... NOT NULL would fail immediately
-- against the existing 4 (produciton) / however-many (other environments)
-- rows with no default to satisfy it.
alter table public.events
  add column start_date date,
  add column end_date date,
  add column start_time time,
  add column end_time time;

-- Step 2: backfill every existing row from its own start_at/end_at +
-- timezone — the exact values already sourced and stored, never a
-- fabricated one.
--
-- end_date uses "last active local calendar date" semantics, not "the
-- calendar date containing the raw end instant": when the local end time
-- is exactly 00:00:00, the Event's own end instant has already rolled
-- into the next calendar day even though the Event itself is understood
-- (by its own organizer, in its own description) to run through the
-- PRECEDING day. 't Preuvenemint's own end_at is the concrete proof this
-- matters: 2026-08-30 22:00:00+00 in Europe/Amsterdam is
-- 2026-08-31 00:00:00 local — attributing that to Aug 31 would silently
-- claim the festival ran one calendar day longer than it actually did.
-- end_time is left as the true sourced value (00:00:00) regardless —
-- only end_date shifts; the two are allowed to describe different
-- calendar days on purpose (see this migration's own doc comment on that
-- column, and the architecture audit's Backfill section for the full
-- worked example).
update public.events
set
  start_date = (start_at at time zone timezone)::date,
  start_time = (start_at at time zone timezone)::time,
  end_date = case
    when (end_at at time zone timezone)::time = '00:00:00'
      then ((end_at at time zone timezone)::date - 1)
    else (end_at at time zone timezone)::date
  end,
  end_time = (end_at at time zone timezone)::time;

-- Step 3: now that every row has a value, start_date/end_date become the
-- durable NOT NULL contract Phase C's date-only Events will eventually
-- rely on as their one guaranteed anchor. start_time/end_time stay
-- nullable — that nullability IS the whole feature; nothing here ever
-- tightens them.
alter table public.events
  alter column start_date set not null,
  alter column end_date set not null;

-- Step 4: the one constraint that is unconditionally true across every
-- case this audit approved (single-day, multi-day, full-time, and the
-- future date-only/start-known cases alike) — end_date can never
-- precede start_date. Deliberately NOT adding an end_time >= start_time
-- constraint: that comparison is meaningless/wrong for an overnight
-- Event (end_date > start_date, end_time numerically less than
-- start_time) and for either time being unknown — a stricter-looking
-- constraint here would be actively incorrect, not merely unnecessary.
alter table public.events
  add constraint events_local_dates_valid check (end_date >= start_date);

-- Deliberately untouched by this migration, and expected to remain so
-- until Phase C: start_at/end_at nullability, events_dates_valid,
-- events_validate_timezone trigger, RLS policies, all indexes other than
-- the new columns having none of their own yet (see the Phase A
-- pre-apply doc's Index Decision section for why one is not added here).
