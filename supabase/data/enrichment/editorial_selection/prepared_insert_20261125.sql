-- Adds Candeal (Marbella) and Onglet (Maastricht) to the catalogue and to
-- the editorial Selection. Values from candidates_20261125.csv in this
-- folder. Requested by the product owner on 2026-11-25.
--
-- NOT APPLIED. Written 2026-11-25. QA-563, QA-564.
--
-- Run the checks in step 0 first and read their output. Step 1 is one
-- statement: both restaurants, their Selection entries and their MICHELIN
-- cuisines, or nothing.

-- ============================================================
-- 0. Checks — read before running step 1
-- ============================================================

-- The city rows. Expect Marbella (ES) and Maastricht (NL).
select id, name, country_code from public.cities
where id in ('84838200-c23e-4af4-ba53-773c5bd207d7', '79d78599-a1b5-471d-ac90-12fecba8caf0');

-- Nothing already in the catalogue with the same Place ID, phone or
-- website, or within 150 m. Never matched on name (CLAUDE.md). Expect one
-- row only: Studio (rest_0101, Kesselskade 66, Maastricht), a different
-- venue within 150 m of Onglet.
select r.restaurant_code, r.name, r.address, r.google_place_id, r.phone
from public.restaurants r
where r.google_place_id in ('ChIJLXtQ8tLZcg0RivybYFNutqI', 'ChIJ3VdunDTpwEcRBpCyA1tRV5M')
   or r.phone in ('+34608888006', '+31438528847')
   or r.website_url ilike any (array['%restaurantecandeal.com%', '%onglet.nl%'])
   or exists (
     select 1 from (values
       (st_setsrid(st_makepoint(-4.8821173, 36.5096998), 4326)::geography),
       (st_setsrid(st_makepoint(5.69970385, 50.84939015), 4326)::geography)
     ) as p(pt) where st_dwithin(r.location, p.pt, 150));

-- The highest restaurant_code. Expect 4215, so the two get
-- rest_4216 and rest_4217.
select max(substring(restaurant_code from 6)::int) as highest
from public.restaurants
where restaurant_code ~ '^rest_[0-9]+$';

-- The cuisines. Expect 308 Creative, 392 Mediterranean Cuisine,
-- 395 Modern Cuisine.
select id, name from public.cuisines where id in (308, 392, 395) order by id;

-- ============================================================
-- 1. Insert
-- ============================================================

with base as (
  select max(substring(restaurant_code from 6)::int) as n
  from public.restaurants
  where restaurant_code ~ '^rest_[0-9]+$'
),
candidates (ord, name, city_id, country_code, address, lon, lat, phone,
            website_url, google_place_id) as (
  values
    (1, 'Candeal', '84838200-c23e-4af4-ba53-773c5bd207d7'::uuid, 'ES',
        'Plaza Blas Infante 1, 29601 Marbella',
        -4.8821173, 36.5096998, '+34608888006',
        'https://www.restaurantecandeal.com/', 'ChIJLXtQ8tLZcg0RivybYFNutqI'),
    (2, 'Onglet', '79d78599-a1b5-471d-ac90-12fecba8caf0'::uuid, 'NL',
        'Wycker Brugstraat 27, 6221 EB Maastricht',
        5.69970385, 50.84939015, '+31438528847',
        'https://www.onglet.nl/', 'ChIJ3VdunDTpwEcRBpCyA1tRV5M')
),
inserted as (
  insert into public.restaurants
    (restaurant_code, name, michelin_stars, inclusion_reason, city_id,
     country_code, address, location, google_place_id, website_url, phone,
     status)
  select 'rest_' || lpad((base.n + c.ord)::text, greatest(4, length((base.n + c.ord)::text)), '0'),
         c.name, null, 'editorial_selection', c.city_id, c.country_code,
         c.address, st_setsrid(st_makepoint(c.lon, c.lat), 4326)::geography,
         c.google_place_id, c.website_url, c.phone, 'open'
  from candidates c cross join base
  order by c.ord
  returning id, restaurant_code, name, google_place_id
),
selected as (
  insert into public.editorial_selections (restaurant_id, selected_on)
  select id, date '2026-11-25' from inserted
  returning restaurant_id
),
cuisines (google_place_id, cuisine_id, position, source_url, source_label) as (
  values
    ('ChIJLXtQ8tLZcg0RivybYFNutqI', 308, 1,
     'https://guide.michelin.com/en/andalucia/marbella/restaurant/candeal',
     'Creative, Mediterranean Cuisine'),
    ('ChIJLXtQ8tLZcg0RivybYFNutqI', 392, 2,
     'https://guide.michelin.com/en/andalucia/marbella/restaurant/candeal',
     'Creative, Mediterranean Cuisine'),
    ('ChIJ3VdunDTpwEcRBpCyA1tRV5M', 395, 1,
     'https://guide.michelin.com/en/limburg/maastricht/restaurant/onglet',
     'Modern Cuisine')
)
insert into public.restaurant_cuisines
  (restaurant_id, cuisine_id, position, source, source_url, source_label, verified_on)
select i.id, c.cuisine_id, c.position, 'michelin', c.source_url, c.source_label,
       date '2026-11-25'
from inserted i
join cuisines c on c.google_place_id = i.google_place_id
returning restaurant_id, cuisine_id, position;

-- ============================================================
-- 2. Verify
-- ============================================================

select r.restaurant_code, r.name, r.michelin_stars, r.inclusion_reason,
       r.cuisine_id, r.address, r.phone, r.google_place_id, es.selected_on
from public.restaurants r
join public.editorial_selections es on es.restaurant_id = r.id
where es.removed_on is null
  and r.google_place_id in ('ChIJLXtQ8tLZcg0RivybYFNutqI', 'ChIJ3VdunDTpwEcRBpCyA1tRV5M');
