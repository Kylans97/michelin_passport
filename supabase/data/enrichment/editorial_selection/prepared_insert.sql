-- Adds Tacite and Petit Péché (Amsterdam) to the catalogue and to the
-- editorial Selection. Values from candidates.csv in this folder.
--
-- PREPARED — NOT APPLIED. Written 2026-10-28. Run only after:
--   1. 20261023120000_add_editorial_selection.sql is applied;
--   2. candidates.csv is reviewed (Petit Péché's spelling and seasonal
--      status especially);
--   3. the Google Place IDs are found and verified (find-place-id), and
--      filled in below — or deliberately left NULL.
--
-- Run the checks in step 0 first and read their output. The insert in
-- step 1 is one statement, so it adds both restaurants and both Selection
-- entries, or nothing.

-- ============================================================
-- 0. Checks — read before running step 1
-- ============================================================

-- Amsterdam's city row (id from the 2026-08-24 live export; confirm it).
select id, name, country_code from public.cities
where id = '3736b37d-e6b0-4786-b427-e85f5a47be16';

-- Nothing already in the catalogue within 50 m of either address. Never
-- matched on name (CLAUDE.md); proximity is the check. Expect zero rows.
select r.restaurant_code, r.name, r.address,
       round(st_distance(r.location, p.pt)::numeric) as metres
from public.restaurants r
join (values
  ('Tacite',      st_setsrid(st_makepoint(4.863229, 52.351151), 4326)::geography),
  ('Petit Péché', st_setsrid(st_makepoint(4.865458, 52.365859), 4326)::geography)
) as p(candidate, pt) on st_dwithin(r.location, p.pt, 50);

-- The highest restaurant_code. Codes have gaps, so the next one is
-- max + 1, never count(*) + 1.
select max(substring(restaurant_code from 6)::int) as highest
from public.restaurants
where restaurant_code ~ '^rest_[0-9]+$';

-- ============================================================
-- 1. Insert
-- ============================================================

with base as (
  select max(substring(restaurant_code from 6)::int) as n
  from public.restaurants
  where restaurant_code ~ '^rest_[0-9]+$'
),
candidates (ord, name, address, lon, lat, phone, website_url, google_place_id) as (
  values
    (1, 'Tacite', 'Cornelis Krusemanstraat 15, 1075 NB Amsterdam',
        4.863229, 52.351151, '+31627439207', 'https://tacite.nl/', null::text),
    (2, 'Petit Péché', 'Nicolaas Beetsstraat 51h, 1053 RJ Amsterdam',
        4.865458, 52.365859, '+31621186278', 'https://www.petitpecheamsterdam.nl/', null::text)
),
inserted as (
  insert into public.restaurants
    (restaurant_code, name, michelin_stars, inclusion_reason, city_id,
     country_code, address, location, google_place_id, website_url, phone,
     status)
  select 'rest_' || lpad((base.n + c.ord)::text, greatest(4, length((base.n + c.ord)::text)), '0'),
         c.name, null, 'editorial_selection',
         '3736b37d-e6b0-4786-b427-e85f5a47be16', 'NL', c.address,
         st_setsrid(st_makepoint(c.lon, c.lat), 4326)::geography,
         c.google_place_id, c.website_url, c.phone, 'open'
  from candidates c cross join base
  order by c.ord
  returning id, restaurant_code, name
)
insert into public.editorial_selections (restaurant_id, selected_on)
select id, date '2026-10-28' from inserted
returning restaurant_id, selected_on;

-- ============================================================
-- 2. Verify
-- ============================================================

select r.restaurant_code, r.name, r.michelin_stars, r.inclusion_reason,
       r.address, r.phone, es.selected_on
from public.restaurants r
join public.editorial_selections es on es.restaurant_id = r.id
where es.removed_on is null
order by r.restaurant_code;
