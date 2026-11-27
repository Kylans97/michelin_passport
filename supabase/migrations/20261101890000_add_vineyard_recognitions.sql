-- Renumbered again 2026-11-27, twice (was 20261101800000, then 20261101830000) before
-- anything applied it: 20261101810000 (website sign ins), then
-- 20261101850000 to 20261101870000 (visit companions, Chapeau,
-- challenges) reached production first, so this file moved after the
-- highest migration to keep filename order equal to apply order.
-- Renumbered 2026-11-25 (was 20261101770000) before anything applied it: the vineyard
-- claims migration 20261101780000 went to production first, so this
-- prepared file moved after it to keep filename order equal to apply order.
-- Official classifications of wine estates: Bordeaux 1855 (Médoc and
-- Sauternes), Graves, Saint-Émilion, and later VDP, Vinos de Pago and the
-- like. Written 2026-11-25 (branch claude/vineyards-global) for batch 4.
-- Product owner, 2026-11-24: the Wine Estates collection shows only "the
-- top recognised estates", the rest is found through search; a
-- classification is such a recognition. The number is sort order, not a
-- date: named after the highest migration on any branch (20261101790000).
--
-- Applied to production 2026-11-27 (product owner: "Yes, apply both").
--
-- One row per estate per scheme: the class as the official list prints it,
-- the edition, and the official page it was verified against. Shaped like
-- worlds_50_best_vineyards and kept apart from award_history (MICHELIN
-- only). A classification is a verified fact we own; nothing is gold.
-- class_order sorts within a scheme (1 = the highest class) so the app
-- never parses the printed class.
--
-- vineyards_full gains recognitions (a JSON array, appended at the end, so
-- shipped builds that select named columns are unaffected).
--
-- RLS: world readable, no client write; select granted to anon and
-- authenticated only. No function is created, so no execute grant to
-- revoke.

begin;

create table public.vineyard_recognitions (
  id           uuid primary key default gen_random_uuid(),
  vineyard_id  uuid not null references public.vineyards(id) on delete cascade,
  scheme       text not null check (scheme in (
                 'bordeaux_1855_medoc', 'bordeaux_1855_sauternes',
                 'graves_1959', 'saint_emilion')),
  -- As the official list prints it: "Premier Cru", "Grand Cru Classé".
  class        text not null,
  class_order  smallint not null check (class_order between 1 and 9),
  edition      smallint not null,
  source_url   text not null,
  created_at   timestamptz not null default now(),
  unique (vineyard_id, scheme)
);

create index vineyard_recognitions_vineyard_idx
  on public.vineyard_recognitions (vineyard_id);
create index vineyard_recognitions_scheme_idx
  on public.vineyard_recognitions (scheme, class_order);

alter table public.vineyard_recognitions enable row level security;
revoke all on public.vineyard_recognitions from public, anon, authenticated;
grant select on public.vineyard_recognitions to anon, authenticated;

create policy vineyard_recognitions_public_read on public.vineyard_recognitions
  for select to anon, authenticated
  using (true);

comment on table public.vineyard_recognitions is
  'Official classifications of an estate (1855, Graves, Saint-Émilion ...), '
  'one row per scheme, class as printed, verified against source_url.';

-- vineyards_full: the same view as 20261101740000 plus recognitions.
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
  v.aliases,
  coalesce((
    select jsonb_agg(jsonb_build_object(
             'scheme', x.scheme, 'class', x.class,
             'class_order', x.class_order, 'edition', x.edition)
           order by x.scheme)
    from public.vineyard_recognitions x
    where x.vineyard_id = v.id
  ), '[]'::jsonb) as recognitions
from public.vineyards v
join public.countries c on c.country_code = v.country_code
left join public.worlds_50_best_vineyards w
  on w.vineyard_id = v.id
  and w.year = (select year from latest)
left join public.wine_regions r on r.id = v.wine_region_id
left join public.wine_region_communes rc
  on rc.region_id = v.wine_region_id and rc.commune_code = v.commune_code;

commit;
