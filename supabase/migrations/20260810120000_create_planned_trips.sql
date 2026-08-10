-- Planned Trips foundation: wishlist -> plan -> trip.
--
-- This is purely additive: two new tables, no changes to any existing
-- table, view, or column. Not applied remotely — see project instructions.
--
-- Design notes:
--
-- planned_venues mirrors the existing polymorphic entity_type/entity_id
-- pattern already used by public.visits/public.wishlist/public.award_history
-- (see production schema v1) rather than inventing a new shape — a planned
-- item addresses either a restaurant or a hotel via the same two columns,
-- with no foreign key on entity_id (restaurants/hotels live in separate
-- tables; see DATABASE_ARCHITECTURE.md section 4 for why entity_id is
-- deliberately not an FK anywhere in this schema).
--
-- One generic start_date/end_date pair covers both venue types rather than
-- separate restaurant_plans/hotel_plans tables: a restaurant visit uses
-- start_date only (end_date null), a hotel stay uses both (check-in/
-- check-out). This keeps a trip's planned items in one queryable list
-- instead of a union of two tables, and avoids duplicating the
-- entity_type/entity_id/status/notes/trip_id shape twice for no real
-- structural difference between the two venue types.
--
-- trip_id is ON DELETE SET NULL, not CASCADE: deleting a trip must detach
-- its planned venues, never delete them (see task's explicit "preferred
-- safe behavior"). A planned venue's own row is only ever removed by the
-- user explicitly deleting that planned venue.
--
-- Event-matching readiness (see report): planned_trips.country_code +
-- optional city + start_date/end_date already carry everything a future
-- event query needs to test
--   event.start/end overlaps trip.start/end
--   AND event.country_code = trip.country_code
--   AND (event.city is null OR trip.city is null OR event.city = trip.city)
-- with no schema change to this table.

create table public.planned_trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  start_date date not null,
  end_date date not null,
  country_code char(2) not null references public.countries(country_code),
  -- Free text, not a foreign key to public.cities: that table is a curated
  -- subset of Michelin-guide cities, and a trip destination must not be
  -- restricted to cities that happen to have catalogued restaurants/hotels.
  city text,
  notes text,
  created_at timestamptz not null default now(),
  constraint planned_trips_dates_valid check (end_date >= start_date)
);

create index planned_trips_user_idx
  on public.planned_trips (user_id, start_date);

create table public.planned_venues (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null check (entity_type in ('hotel', 'restaurant')),
  entity_id uuid not null,
  trip_id uuid references public.planned_trips(id) on delete set null,
  -- Restaurant: start_date only (a single planned visit date). Hotel:
  -- start_date/end_date as check-in/check-out. Not separately enforced by
  -- entity_type here (a hotel plan may still have a null end_date if the
  -- user hasn't decided check-out yet) — the UI drives which fields it
  -- shows per venue type, per the task's product rules.
  start_date date not null,
  end_date date,
  notes text,
  status text not null default 'planned'
    check (status in ('planned', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  constraint planned_venues_dates_valid
    check (end_date is null or end_date >= start_date)
);

create index planned_venues_user_idx
  on public.planned_venues (user_id, start_date);

create index planned_venues_trip_idx
  on public.planned_venues (trip_id);

create index planned_venues_entity_idx
  on public.planned_venues (entity_type, entity_id);

-- RLS: planned-trip data is private by default — unlike visits/wishlist
-- (which allow anon/authenticated read via profile_is_visible() for
-- social/community features), a future trip's dates and destination are
-- more sensitive than past visit history, so read is owner-only too. No
-- anon grant at all.

alter table public.planned_trips enable row level security;

create policy planned_trips_select on public.planned_trips
  for select to authenticated
  using (user_id = auth.uid());

create policy planned_trips_insert on public.planned_trips
  for insert to authenticated
  with check (user_id = auth.uid());

create policy planned_trips_update on public.planned_trips
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy planned_trips_delete on public.planned_trips
  for delete to authenticated
  using (user_id = auth.uid());

alter table public.planned_venues enable row level security;

create policy planned_venues_select on public.planned_venues
  for select to authenticated
  using (user_id = auth.uid());

create policy planned_venues_insert on public.planned_venues
  for insert to authenticated
  with check (user_id = auth.uid());

create policy planned_venues_update on public.planned_venues
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy planned_venues_delete on public.planned_venues
  for delete to authenticated
  using (user_id = auth.uid());
