-- Vineyards: wine estates as their own catalogue entity, starting with The
-- World's 50 Best Vineyards. Decided by the product owner on 2026-11-20
-- after reviewing the design canvas ("Wijngaarden in Mantelier"): vineyards
-- get their own table, start with the 50 Best Vineyards list, wines already
-- logged stay as they are. Written 2026-11-20 (branch claude/vineyards).
-- The number is sort order, not a date: named after the highest migration
-- on any branch, past the slots trains-and-ships claimed (..549999).
--
-- PREPARED -- NOT APPLIED until the product owner approves.
--
-- A vineyard is not a venue. Nothing here touches restaurants, hotels or
-- hotel_restaurants, and the hotel scope rules are unchanged. Every
-- relationship is a join table or a plain FK.
--
-- Recognition. The World's 50 Best Vineyards rank lives in its own
-- per-edition table, worlds_50_best_vineyards, shaped exactly like
-- worlds_50_best_hotels. Not in award_history: that table is MICHELIN
-- stars and Keys, an ordinal where higher is better, and a 50 Best rank
-- sorts the other way (DATABASE_ARCHITECTURE.md §3.6). One row per estate
-- per edition is the vineyard's award history; absence from an edition is
-- no row, never a zero or a null rank. Nothing is gold: gold stays
-- reserved for MICHELIN stars and Keys.
--
-- What we own. Only verified facts: the name as the list prints it, the
-- country, the region, the place and the location fields, the rank. An
-- estate's description and photos come from the estate itself after
-- review, as for every other venue; there is no description column here.
--
-- Identity. vineyard_code is the stable human key (vine_0001, ...), unique
-- across the table and therefore per country. Never match on name: two
-- estates in different countries can share one. Places are text plus a
-- country, not public.cities (scoped to guide editions), the reasoning
-- journeys and events.city already use.
--
-- Logged wines. visit_wines gains a nullable vineyard_id. The free-text
-- producer stays and keeps working. No backfill: the wines logged so far
-- stay unlinked (product owner: they are few and they are test data), and
-- nothing is ever matched to an estate by name -- a member picks the
-- estate. The existing visit_wines policies already decide who may write
-- the row; a vineyard_id is a pointer into a world-readable table, so it
-- needs no policy of its own. on delete set null: removing an estate never
-- removes a member's note.
--
-- Events. event_vineyards links an estate to an event with the same shape
-- as event_restaurants/_hotels/_chefs (is_host, is_venue, approved_at).
-- An estate is a participant only for now -- no estate has a manager and
-- an estate is not yet a place an event's timezone or address can come
-- from -- so a check holds both flags false. Allowing host or venue later
-- is a new migration that drops that check. Writes are service_role only
-- (admin-curated), as for every other catalogue link.
--
-- No function is created here, so there is no execute grant to revoke.

begin;

-- ============================================================
-- 1. vineyards
-- ============================================================
create table public.vineyards (
  id               uuid primary key default gen_random_uuid(),
  vineyard_code    text not null unique,
  name             text not null,
  country_code     char(2) not null references public.countries(country_code),
  -- The wine region as the list or the estate prints it ("Mendoza",
  -- "Douro Valley"), display only.
  region           text,
  -- Town or village of the estate's cellar door, as the estate gives it.
  city             text,
  address          text,
  -- NULL until verified from the estate's own site; never geocoded.
  location         geography(Point,4326),
  google_place_id  text unique,
  website_url      text,
  status           public.venue_status not null default 'open',
  status_since     date,
  status_note      text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint vineyards_code_format check (vineyard_code ~ '^vine_[0-9]{4,}$')
);

create trigger vineyards_updated_at
  before update on public.vineyards
  for each row execute function public.set_updated_at();

create index vineyards_country_idx on public.vineyards (country_code);
create index vineyards_location_gix on public.vineyards using gist (location);
create index vineyards_name_trgm_idx
  on public.vineyards using gin (name gin_trgm_ops);

comment on table public.vineyards is
  'Wine estates. Their own entity, not a kind of venue. Verified facts '
  'only; descriptions and photos come from the estate after review. '
  'vineyard_code is the key, never the name.';

-- ============================================================
-- 2. worlds_50_best_vineyards -- one row per estate per edition
-- ============================================================
create table public.worlds_50_best_vineyards (
  id           uuid primary key default gen_random_uuid(),
  vineyard_id  uuid not null references public.vineyards(id) on delete cascade,
  -- The edition as the organisers label it, never the import year.
  year         smallint not null,
  rank         smallint check (rank > 0),
  list_type    text not null default 'top_50'
    check (list_type in ('top_50', 'extended_51_100')),
  -- The official page this row was verified against.
  source_url   text,
  announced_on date,
  unique (vineyard_id, year)
);

create unique index worlds_50_best_vineyards_year_rank_uidx
  on public.worlds_50_best_vineyards (year, rank)
  where rank is not null;

create index worlds_50_best_vineyards_vineyard_idx
  on public.worlds_50_best_vineyards (vineyard_id);

-- ============================================================
-- 3. vineyards_full -- what the app reads
-- ============================================================
-- Current rank = the row of the latest edition on the list as a whole, as
-- restaurants_full reads worlds_50_best: an estate that left the list has
-- no current rank. security_invoker, so the reader's own RLS applies.
create view public.vineyards_full
  with (security_invoker = true)
as
with latest as (
  select max(year) as year from public.worlds_50_best_vineyards
)
select
  v.id,
  v.vineyard_code,
  v.name,
  v.country_code,
  c.name as country_name,
  c.flag_emoji,
  v.region,
  v.city,
  v.address,
  st_y(v.location::geometry) as latitude,
  st_x(v.location::geometry) as longitude,
  v.google_place_id,
  v.website_url,
  v.status,
  w.year as worlds_50_best_year,
  w.rank as worlds_50_best_rank,
  w.list_type as worlds_50_best_list_type,
  w.source_url as worlds_50_best_source_url
from public.vineyards v
join public.countries c on c.country_code = v.country_code
left join public.worlds_50_best_vineyards w
  on w.vineyard_id = v.id
  and w.year = (select year from latest);

-- ============================================================
-- 4. visit_wines.vineyard_id -- the estate a member picked
-- ============================================================
alter table public.visit_wines
  add column vineyard_id uuid references public.vineyards(id) on delete set null;

create index visit_wines_vineyard_idx
  on public.visit_wines (vineyard_id)
  where vineyard_id is not null;

-- ============================================================
-- 5. event_vineyards -- an estate taking part in an event
-- ============================================================
create table public.event_vineyards (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events(id) on delete cascade,
  vineyard_id  uuid not null references public.vineyards(id) on delete cascade,
  is_host      boolean not null default false,
  is_venue     boolean not null default false,
  approved_at  timestamptz default now(),
  unique (event_id, vineyard_id),
  constraint event_vineyards_participant_only
    check (not is_host and not is_venue)
);

create index event_vineyards_event_idx on public.event_vineyards (event_id);
create index event_vineyards_vineyard_idx on public.event_vineyards (vineyard_id);

-- ============================================================
-- 6. ROW LEVEL SECURITY AND GRANTS
-- ============================================================
-- Catalogue tables: world-readable, no client write; only service_role
-- writes. The project's default privileges grant ALL on every new table to
-- anon and authenticated (20260918130000); the grant is narrowed to select
-- so these tables do not depend on RLS alone.
alter table public.vineyards                enable row level security;
alter table public.worlds_50_best_vineyards enable row level security;
alter table public.event_vineyards          enable row level security;

revoke all on public.vineyards, public.worlds_50_best_vineyards,
  public.event_vineyards, public.vineyards_full
  from public, anon, authenticated;
grant select on public.vineyards, public.worlds_50_best_vineyards,
  public.event_vineyards, public.vineyards_full
  to anon, authenticated;

create policy vineyards_public_read on public.vineyards
  for select to anon, authenticated
  using (true);

create policy worlds_50_best_vineyards_public_read
  on public.worlds_50_best_vineyards
  for select to anon, authenticated
  using (true);

-- Same visibility as event_restaurants/_hotels/_chefs: a published event's
-- approved links, and every link for an admin reviewing an event.
create policy event_vineyards_public_read on public.event_vineyards
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.moderation_status = 'published'
    )
    and approved_at is not null
  );

create policy event_vineyards_admin_read on public.event_vineyards
  for select to authenticated
  using (public.is_admin());

commit;
