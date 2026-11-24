-- The global wine estates database: villages, search names and server
-- search. Product owner, 2026-11-24: "Maybe we should first build an
-- extensive database with vineyards all across the globe", then, on the
-- plan (docs/Architecture/VINEYARDS_GLOBAL_DATABASE_PLAN.md), chose
-- "Migration + server search" as the first step. Written 2026-11-24 (branch
-- claude/vineyards-global). The number is sort order, not a date: named
-- after the highest migration on any branch (20261101730000, friends-cellar).
--
-- PREPARED -- NOT APPLIED until the product owner approves.
--
-- What it does, all additive (shipped builds select named columns from
-- vineyards_full and never see the new ones):
--
-- 1. wine_region_communes: the official commune lists already in the repo
--    (supabase/data/enrichment/wine_regions/outlines/communes/, 238
--    regions), one row per distinct unit per region, read only. The
--    "village" a wine or an estate points at. Outside Europe a unit is
--    whatever the region's official text is built from (a comuna, a
--    departamento, a ward, an AVA), so the column is called commune_code,
--    not gisco_id. Centre point nullable: filled by the outline script.
--
-- 2. vineyards gains:
--      commune_code    the estate's village, constrained to a unit of the
--                      estate's own wine_region_id by a composite FK, so a
--                      village can never sit in the wrong region;
--      aliases         other names on a label (Yquem, Château d'Yquem;
--                      a second wine), used for search only, never matched
--                      on to link anything;
--      inclusion_reason why the estate is in the catalogue;
--      source_url      the official page the estate was verified against;
--      search_text     folded name + aliases, maintained by a trigger,
--                      trigram indexed.
--    Village is set only where the region's list has two or more units:
--    in a one-unit region (Napa Valley, Stellenbosch, Margaret River) the
--    region is its own village and commune_code stays NULL.
--
-- 3. search_vineyards(): server-side search, so the picker no longer
--    needs every estate on the device. SECURITY INVOKER over a
--    world-readable table: it can read nothing the caller can't already
--    read. Revoked from public and granted explicitly anyway, so the grant
--    is a decision written here and not the instance default.
--
-- Not here (later, separate migrations once the scope is approved):
--   vineyard_recognitions (Bordeaux 1855, Saint-Émilion, VDP, Vinos de
--   Pago ...), shaped like worlds_50_best_vineyards; and the wine globe's
--   own columns on cellar_wines/visit_wines.

begin;

-- ============================================================
-- 1. wine_region_communes
-- ============================================================
create table public.wine_region_communes (
  region_id      uuid not null references public.wine_regions(id) on delete cascade,
  -- Unit id exactly as the commune list stores it: FR_33314 (GISCO LAU
  -- 2024), CL_COM_13202, AR_DEP_50063, ZA_ward_constantia ...
  commune_code   text not null,
  name           text not null,
  province       text,
  -- The official text includes only part of this unit (the list's own
  -- wording is kept in the repo file).
  is_partial     boolean not null default false,
  latitude       double precision check (latitude between -90 and 90),
  longitude      double precision check (longitude between -180 and 180),
  primary key (region_id, commune_code)
);

create index wine_region_communes_code_idx
  on public.wine_region_communes (commune_code);

alter table public.wine_region_communes enable row level security;
revoke all on public.wine_region_communes from public, anon, authenticated;
grant select on public.wine_region_communes to anon, authenticated;

-- Visible when its region is.
create policy wine_region_communes_public_read on public.wine_region_communes
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.wine_regions r
      where r.id = region_id and r.publication_status = 'published'
    )
  );

comment on table public.wine_region_communes is
  'The units (communes, comunas, departamentos, wards, AVAs) each wine '
  'region''s official text is built from. Loaded from the repo lists; '
  'read only. An estate''s or a wine''s village points here.';

-- ============================================================
-- 2. vineyards: village, aliases, why, source, search text
-- ============================================================
alter table public.vineyards
  add column commune_code     text,
  add column aliases          text[] not null default '{}',
  add column inclusion_reason text not null default 'worlds_50_best_vineyards'
    check (inclusion_reason in (
      'worlds_50_best_vineyards', 'official_classification',
      'editorial_selection', 'member_request')),
  add column source_url       text,
  add column search_text      text not null default '';

-- A village only together with its region, and only a unit of that
-- region. MATCH SIMPLE: a NULL commune_code is never checked. Deleting a
-- region clears both (the existing wine_region_id FK already sets it
-- NULL; this one clears the village with it).
alter table public.vineyards
  add constraint vineyards_commune_in_region
    foreign key (wine_region_id, commune_code)
    references public.wine_region_communes (region_id, commune_code)
    on delete set null (commune_code),
  add constraint vineyards_commune_needs_region
    check (commune_code is null or wine_region_id is not null);

-- The village follows its region: whenever wine_region_id becomes NULL
-- (by hand, or by the existing on-delete-set-null when a region is
-- deleted), the village goes with it. Without this, deleting a region
-- that holds an estate with a village fails on the check above (found on
-- the scratch stack, 2026-11-24).
create or replace function public.vineyards_village_follows_region()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.wine_region_id is null then
    new.commune_code := null;
  end if;
  return new;
end;
$$;
revoke execute on function public.vineyards_village_follows_region() from public, anon;

create trigger vineyards_village_follows_region
  before update of wine_region_id on public.vineyards
  for each row execute function public.vineyards_village_follows_region();

create index vineyards_search_trgm_idx
  on public.vineyards using gin (search_text gin_trgm_ops);
create index vineyards_commune_idx
  on public.vineyards (wine_region_id, commune_code)
  where commune_code is not null;

-- Lower case, common Latin accents and punctuation folded: the same fold
-- the app's foldForSearch applies (lib/models/vineyard.dart), so a search
-- typed on the device and the stored text agree. No unaccent extension on
-- this project (2026-11-24), hence translate().
create or replace function public.fold_for_search(p text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select trim(regexp_replace(
    translate(lower(coalesce(p, '')),
      'àáâãäåçèéêëìíîïñòóôõöøùúûüýÿœæß''’-.',
      'aaaaaaceeeeiiiinoooooouuuuyyoas    '),
    '\s+', ' ', 'g'))
$$;
-- Pure and invoker: search_vineyards calls it as the caller, anon included.
revoke execute on function public.fold_for_search(text) from public;
grant execute on function public.fold_for_search(text) to anon, authenticated, service_role;

create or replace function public.vineyards_set_search_text()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.search_text := public.fold_for_search(
    new.name || ' ' || array_to_string(new.aliases, ' '));
  return new;
end;
$$;
revoke execute on function public.vineyards_set_search_text() from public, anon;

create trigger vineyards_search_text
  before insert or update of name, aliases on public.vineyards
  for each row execute function public.vineyards_set_search_text();

-- Fill it for the rows already there.
update public.vineyards set aliases = aliases;

-- ============================================================
-- 2b. vineyards_full gains the region and village, appended at the end
-- ============================================================
-- create or replace view may only add columns after the existing ones;
-- shipped builds select the old ones by name. security_invoker stays, so
-- a draft region (hidden by its own RLS) reads as NULL here.
create or replace view public.vineyards_full
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
  w.source_url as worlds_50_best_source_url,
  v.wine_region_id,
  r.name as wine_region_name,
  v.commune_code,
  rc.name as commune_name,
  v.aliases
from public.vineyards v
join public.countries c on c.country_code = v.country_code
left join public.worlds_50_best_vineyards w
  on w.vineyard_id = v.id
  and w.year = (select year from latest)
left join public.wine_regions r on r.id = v.wine_region_id
left join public.wine_region_communes rc
  on rc.region_id = v.wine_region_id and rc.commune_code = v.commune_code;

-- ============================================================
-- 3. search_vineyards -- what the picker calls
-- ============================================================
-- Ranked: whole-name prefix, then a word starting with the query, then
-- anywhere, then trigram similarity; ties by 50 Best rank, then name.
-- p_country narrows to one country (the wine sheet can pass the country
-- the member already chose). Never links anything: it returns candidates,
-- the member picks one.
create or replace function public.search_vineyards(
  p_query   text,
  p_country char(2) default null,
  p_limit   int default 20
)
returns setof public.vineyards_full
language sql
stable
security invoker
set search_path = ''
as $$
  with q as (select public.fold_for_search(trim(p_query)) as t)
  select f.*
  from public.vineyards_full f
  join public.vineyards v on v.id = f.id
  cross join q
  where length(q.t) >= 2
    and (p_country is null or v.country_code = p_country)
    and (v.search_text like '%' || q.t || '%'
         or v.search_text operator(public.%) q.t)
  order by
    case
      when v.search_text like q.t || '%' then 0
      when v.search_text like '% ' || q.t || '%' then 1
      when v.search_text like '%' || q.t || '%' then 2
      else 3
    end,
    public.similarity(v.search_text, q.t) desc,
    f.worlds_50_best_rank nulls last,
    f.name
  limit least(greatest(p_limit, 1), 50)
$$;
-- pg_trgm lives in public on this project (checked 2026-11-24), hence
-- public.similarity and operator(public.%) under an empty search_path.
revoke execute on function public.search_vineyards(text, char, int) from public, anon;
grant execute on function public.search_vineyards(text, char, int) to anon, authenticated;

commit;
