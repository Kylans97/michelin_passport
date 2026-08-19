-- Events V2 — Timezone Hardening, part 1 of 2: adds the missing timezone
-- identity to events.
--
-- Confirmed by direct audit (docs/Architecture/EVENTS_V2_TIME_LOCATION_AUDIT.md)
-- before writing this migration: events.start_at/end_at are already
-- correct timestamptz instants — nothing here touches them. The one real
-- gap is that no column anywhere records WHICH IANA zone that instant was
-- originally intended in, which is what every event-local display (Event
-- Detail, cards, Explore, Trips, Friends Going) needs and currently lacks
-- — Event.fromJson today calls .toLocal(), silently rendering every event
-- in the VIEWER's device zone instead of the event's own. This migration
-- is the database-side half of the fix; the Dart-side half (removing
-- .toLocal(), adding a central event-local formatter) ships in the same
-- change set, both gated behind human apply review.
--
-- Nullable in this migration, deliberately — see part 2 of this pair
-- (20260820130000_events_v2_timezone_not_null.sql) for why NOT NULL is a
-- separate, later migration rather than bundled here: the 4 live events
-- must be backfilled and independently verified first, as its own
-- reviewed action, before the column can safely be tightened.
--
-- NOT applied to production by this migration file's authoring — prepared
-- for pre-deployment review only.

begin;

-- ============================================================
-- 1. EVENTS — timezone column
-- ============================================================

alter table public.events
  add column timezone text;

comment on column public.events.timezone is
  'IANA timezone identifier (e.g. Europe/Amsterdam, Asia/Tokyo) the event''s '
  'own start_at/end_at were intended in. Never an offset (UTC+2/CET/CEST) — '
  'offsets drift with daylight saving, IANA identifiers do not. Nullable '
  'until every existing row is backfilled and verified; see the Step 1 of 2 '
  'migration this comment lives in and its NOT NULL follow-up.';

-- ============================================================
-- 2. EVENTS — IANA validation
-- ============================================================
--
-- Confirmed empirically against local Postgres before writing this
-- function: `select now() at time zone 'Not/AZone'` raises SQLSTATE 22023
-- (invalid_parameter_value), "time zone ... not recognized" — this reuses
-- Postgres's own bundled, kept-current IANA tzdata as the source of
-- truth, rather than a hand-maintained regex/allowlist that could drift
-- out of sync with the real database. A regex could confirm a string
-- LOOKS like "Region/City" but can't confirm the identifier actually
-- exists (e.g. "Europe/Nowhereland" would pass a shape-only regex and
-- fail this trigger correctly).
create or replace function public.validate_event_timezone()
returns trigger
language plpgsql
as $$
begin
  if new.timezone is not null then
    -- Deliberately discarded via `perform` — this statement exists only
    -- to force Postgres to attempt the conversion and raise if the
    -- identifier isn't real; the result itself is never needed.
    perform now() at time zone new.timezone;
  end if;
  return new;
exception
  when invalid_parameter_value then
    raise exception 'events.timezone must be a valid IANA identifier '
      '(e.g. Europe/Amsterdam), got: %', new.timezone;
end;
$$;

drop trigger if exists events_validate_timezone on public.events;
create trigger events_validate_timezone
  before insert or update of timezone on public.events
  for each row
  execute function public.validate_event_timezone();

commit;
