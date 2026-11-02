-- Restaurant cuisines: up to two per restaurant, per source, grouped into
-- families for search and filtering. Written 2026-11-01.
--
-- Until now a restaurant had one `restaurants.cuisine_id`, against a
-- `cuisines` table mixing Dutch and English and our own descriptive labels
-- ("Japans" and "Japanese", "French-Japanese Umami"). MICHELIN gives one or
-- two cuisines per restaurant, and World's 50 Best describes its own in a
-- style line. This migration adds the shape; the data (the cleaned
-- vocabulary and every link, with evidence) is loaded separately by
-- supabase/data/enrichment/restaurant_cuisines_2026/prepared_restaurant_cuisines.sql.
--
--   cuisine_families      25 search groups (Japanese spans Sushi, Tempura,
--                         Kaiseki, ...). Seeded here because the app filters
--                         on these slugs.
--   cuisines.slug         derived from the canonical (MICHELIN English) name.
--   cuisines.family_id    exactly one family per cuisine.
--   restaurant_cuisines   restaurant ↔ cuisine, position 1–2, per source
--                         (michelin / worlds_50_best / legacy), with the
--                         source URL and the raw label as evidence.
--   restaurant_cuisines_effective
--                         the rows that count: MICHELIN where present, else
--                         World's 50 Best, else legacy. 50 Best rows for a
--                         MICHELIN restaurant stay stored as a cross-check.
--
-- restaurants.cuisine_id stays, and stays correct: a trigger keeps it equal
-- to the effective position-1 cuisine. No shipped build reads it (it is not
-- in restaurantFullColumns), but it is still exposed on restaurants_full, so
-- it is removed only later, under the three-step rule.
--
-- All three are catalogue: world-readable, no client write. No SECURITY
-- DEFINER function is created here.

begin;

create table public.cuisine_families (
  id smallint generated always as identity primary key,
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null unique,
  display_order smallint not null unique
);

insert into public.cuisine_families (slug, name, display_order) values
  ('modern-creative',           'Modern & creative',                1),
  ('classic-traditional',       'Classic & traditional',            2),
  ('seasonal-farm',             'Seasonal & farm-to-table',         3),
  ('belgian-dutch',             'Belgian & Dutch',                  4),
  ('french',                    'French',                           5),
  ('italian',                   'Italian',                          6),
  ('spanish',                   'Spanish',                          7),
  ('portuguese',                'Portuguese',                       8),
  ('british-irish',             'British & Irish',                  9),
  ('nordic',                    'Nordic',                          10),
  ('central-european',          'Central & Eastern European',      11),
  ('mediterranean-middle-east', 'Mediterranean & Middle Eastern',  12),
  ('japanese',                  'Japanese',                        13),
  ('chinese',                   'Chinese',                         14),
  ('korean',                    'Korean',                          15),
  ('southeast-asian',           'Southeast Asian',                 16),
  ('indian',                    'Indian & South Asian',            17),
  ('asian',                     'Asian',                           18),
  ('north-american',            'American',                        19),
  ('latin-american',            'Latin American',                  20),
  ('african',                   'African',                         21),
  ('fusion-international',      'Fusion & international',          22),
  ('seafood',                   'Seafood',                         23),
  ('grill-meat',                'Grill & meat',                    24),
  ('vegetarian',                'Vegetarian & plant-based',        25);

alter table public.cuisine_families enable row level security;
create policy cuisine_families_public_read on public.cuisine_families
  for select to anon, authenticated using (true);
grant select on public.cuisine_families to anon, authenticated;
-- RLS already refuses writes (no write policy); TRUNCATE bypasses RLS, so
-- the default write grants are taken away too.
revoke insert, update, delete, truncate on public.cuisine_families from anon, authenticated;

-- Generated, so a slug can never drift from its name. MICHELIN's English
-- labels are ASCII ("Cuisine from the Aosta Valley" ->
-- "cuisine-from-the-aosta-valley").
--
-- Not unique yet: two pairs of today's legacy labels collide ("French /
-- Asian" and "French-Asian", "French / Classic" and "French Classic"). The
-- prepared data load merges them away; 20261101160000 then adds the unique
-- index.
alter table public.cuisines
  add column slug text generated always as (
    trim(both '-' from regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g'))
  ) stored,
  add column family_id smallint references public.cuisine_families (id);
create index cuisines_slug_idx on public.cuisines (slug);
create index cuisines_family_id_idx on public.cuisines (family_id);

create table public.restaurant_cuisines (
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  cuisine_id smallint not null references public.cuisines (id),
  position smallint not null check (position between 1 and 2),
  source text not null check (source in ('michelin', 'worlds_50_best', 'legacy')),
  -- The page the cuisine was read from (MICHELIN or 50 Best); null for
  -- legacy rows, whose original source was never recorded.
  source_url text,
  -- Exactly what the source said: MICHELIN's "Cuisine:" label, the 50 Best
  -- style line, or the old cuisines.name for legacy rows.
  source_label text not null,
  verified_on date not null,
  primary key (restaurant_id, source, position),
  unique (restaurant_id, source, cuisine_id)
);
create index restaurant_cuisines_cuisine_id_idx on public.restaurant_cuisines (cuisine_id);

alter table public.restaurant_cuisines enable row level security;
create policy restaurant_cuisines_public_read on public.restaurant_cuisines
  for select to anon, authenticated using (true);
grant select on public.restaurant_cuisines to anon, authenticated;
revoke insert, update, delete, truncate on public.restaurant_cuisines from anon, authenticated;

create view public.restaurant_cuisines_effective
  with (security_invoker = true)
  as
select restaurant_id, cuisine_id, position, source, source_url, source_label, verified_on
from (
  select rc.*,
         min(case rc.source when 'michelin' then 1 when 'worlds_50_best' then 2 else 3 end)
           over (partition by rc.restaurant_id) as best_rank,
         case rc.source when 'michelin' then 1 when 'worlds_50_best' then 2 else 3 end as source_rank
  from public.restaurant_cuisines rc
) ranked
where source_rank = best_rank;
grant select on public.restaurant_cuisines_effective to anon, authenticated;

-- Keeps restaurants.cuisine_id equal to the effective position-1 cuisine
-- (null when a restaurant has no cuisine rows left). Invoker rights: only
-- privileged roles can write restaurant_cuisines at all.
create function public.sync_restaurant_cuisine_id()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  rid uuid := coalesce(new.restaurant_id, old.restaurant_id);
begin
  update public.restaurants r
     set cuisine_id = e.cuisine_id
    from (select (select cuisine_id from public.restaurant_cuisines_effective
                   where restaurant_id = rid and position = 1) as cuisine_id) e
   where r.id = rid
     and r.cuisine_id is distinct from e.cuisine_id;
  if tg_op = 'UPDATE' and old.restaurant_id <> new.restaurant_id then
    update public.restaurants r
       set cuisine_id = (select cuisine_id from public.restaurant_cuisines_effective
                          where restaurant_id = old.restaurant_id and position = 1)
     where r.id = old.restaurant_id;
  end if;
  return null;
end;
$$;
revoke execute on function public.sync_restaurant_cuisine_id() from public, anon;

create trigger restaurant_cuisines_sync_cuisine_id
  after insert or update or delete on public.restaurant_cuisines
  for each row execute function public.sync_restaurant_cuisine_id();

-- restaurants_full: four new columns appended at the end (existing columns
-- unchanged, so every shipped build's select keeps working).
--   cuisine_names         'Japanese, Sushi', in source order
--   cuisine_slugs         {japanese,sushi}
--   cuisine_family_slugs  {japanese} — what the Explore filter overlaps on
--   cuisine_search        names plus family names — what free search ilikes
create or replace view public.restaurants_full
  with (security_invoker = true)
  as
select
  r.id,
  r.restaurant_code,
  r.name,
  r.michelin_stars,
  r.inclusion_reason,
  r.cuisine_id,
  r.city_id,
  r.country_code,
  r.address,
  r.location,
  r.google_place_id,
  r.michelin_url,
  r.website_url,
  r.booking_url,
  r.property_name,
  r.status,
  r.status_since,
  r.status_note,
  r.created_at,
  r.updated_at,
  hr.id is not null or r.property_name is not null as is_in_hotel,
  coalesce(h.name, r.property_name) as hotel_name,
  h.id as hotel_id,
  ci.name as city_name,
  ci.region,
  co.name as country_name,
  co.flag_emoji,
  w.rank as worlds_50_best_rank,
  st_y(r.location::geometry) as latitude,
  st_x(r.location::geometry) as longitude,
  exists (
    select 1 from public.worlds_50_best hof
    where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame'
  ) as is_hall_of_fame,
  r.phone,
  r.ends_on is not null and r.ends_on < current_date as is_expired,
  r.starts_on,
  r.ends_on,
  r.parent_venue_type,
  r.parent_venue_id,
  r.opening_weekdays,
  r.missing_listing_report_id,
  cover.image_url as cover_photo_url,
  cover.focus_x as cover_focus_x,
  cover.focus_y as cover_focus_y,
  cover.zoom as cover_zoom,
  card.image_url as card_photo_url,
  card.card_focus_x,
  card.card_focus_y,
  card.card_zoom,
  r.worlds_50_best_url,
  cu.cuisine_names,
  cu.cuisine_slugs,
  cu.cuisine_family_slugs,
  cu.cuisine_search
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null)
left join lateral (
  select rp.image_url, rp.focus_x, rp.focus_y, rp.zoom
  from public.restaurant_photos rp
  where rp.restaurant_id = r.id
  order by rp.display_order
  limit 1
) cover on true
left join lateral (
  select rp.image_url, rp.card_focus_x, rp.card_focus_y, rp.card_zoom
  from public.restaurant_photos rp
  where rp.restaurant_id = r.id
  order by rp.is_card desc, rp.display_order
  limit 1
) card on true
left join lateral (
  select string_agg(c.name, ', ' order by e.position) as cuisine_names,
         array_agg(c.slug order by e.position) as cuisine_slugs,
         array_agg(distinct f.slug) filter (where f.slug is not null) as cuisine_family_slugs,
         string_agg(c.name || coalesce(' ' || f.name, ''), ' ' order by e.position) as cuisine_search
  from public.restaurant_cuisines_effective e
  join public.cuisines c on c.id = e.cuisine_id
  left join public.cuisine_families f on f.id = c.family_id
  where e.restaurant_id = r.id
) cu on true;

commit;
