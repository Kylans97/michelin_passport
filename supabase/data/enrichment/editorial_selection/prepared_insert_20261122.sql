-- Adds Mont Blanc, Troef, Dame aan de Kade and Camarat (Amsterdam) to the
-- catalogue and to the editorial Selection. Values from
-- candidates_20261122.csv in this folder. Requested by the product owner
-- on 2026-11-22.
--
-- APPLIED 2026-11-22 (step 1), on the product owner's explicit go. Written
-- 2026-11-22. QA-534..QA-536.
--
-- Run the checks in step 0 first and read their output. Step 1 is one
-- statement: all four restaurants, their Selection entries and Troef's
-- cuisine, or nothing.

-- ============================================================
-- 0. Checks — read before running step 1
-- ============================================================

-- Amsterdam's city row. Expect one row.
select id, name, country_code from public.cities
where id = '3736b37d-e6b0-4786-b427-e85f5a47be16';

-- Nothing already in the catalogue within 150 m, with the same Place ID,
-- website or phone. Never matched on name (CLAUDE.md). Expect zero rows.
select r.restaurant_code, r.name, r.address, r.google_place_id, r.phone
from public.restaurants r
where r.google_place_id in ('ChIJc3C9G-UJxkcRbIMMVgNyojU', 'ChIJ6SqyXIoJxkcR22CqP0T14q4',
                            'ChIJ5WuOrEcJxkcRIH6hFsW_klw', 'ChIJvzNiq6sJxkcRWmGwIBgw9cg')
   or r.phone in ('+31207741645', '+31629827120', '+31630115120', '+31208950610')
   or r.website_url ilike any (array['%restaurantmontblanc.nl%', '%troefamsterdam.nl%',
                                     '%dameaandekade.nl%', '%camarat.nl%'])
   or exists (
     select 1 from (values
       (st_setsrid(st_makepoint(4.898765, 52.356327), 4326)::geography),
       (st_setsrid(st_makepoint(4.913681, 52.349206), 4326)::geography),
       (st_setsrid(st_makepoint(4.887176, 52.353025), 4326)::geography),
       (st_setsrid(st_makepoint(4.926550, 52.386268), 4326)::geography)
     ) as p(pt) where st_dwithin(r.location, p.pt, 150));

-- The highest restaurant_code. Expect 4207, so the four get
-- rest_4208..rest_4211 (claimed in the shared qa-ids note).
select max(substring(restaurant_code from 6)::int) as highest
from public.restaurants
where restaurant_code ~ '^rest_[0-9]+$';

-- Troef's cuisine. Expect 241, Modern French.
select id, name from public.cuisines where id = 241;

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
    (1, 'Mont Blanc', 'Govert Flinckstraat 308, 1073 CJ Amsterdam',
        4.898765, 52.356327, '+31207741645', 'https://www.restaurantmontblanc.nl/',
        'ChIJc3C9G-UJxkcRbIMMVgNyojU'),
    (2, 'Troef', 'Schollenbrugstraat 8, 1091 EX Amsterdam',
        4.913681, 52.349206, '+31629827120', 'https://troefamsterdam.nl/',
        'ChIJ6SqyXIoJxkcR22CqP0T14q4'),
    (3, 'Dame aan de Kade', 'Ruysdaelkade 169-H, 1072 AS Amsterdam',
        4.887176, 52.353025, '+31630115120', 'https://dameaandekade.nl/',
        'ChIJ5WuOrEcJxkcRIH6hFsW_klw'),
    (4, 'Camarat', 'Johan van Hasseltweg 51, 1021 KN Amsterdam',
        4.926550, 52.386268, '+31208950610', 'https://www.camarat.nl/',
        'ChIJvzNiq6sJxkcRWmGwIBgw9cg')
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
  returning id, restaurant_code, name, google_place_id
),
selected as (
  insert into public.editorial_selections (restaurant_id, selected_on)
  select id, date '2026-11-22' from inserted
  returning restaurant_id
)
insert into public.restaurant_cuisines
  (restaurant_id, cuisine_id, position, source, source_url, source_label, verified_on)
select id, 241, 1, 'michelin',
       'https://guide.michelin.com/en/noord-holland/amsterdam/restaurant/troef',
       'Modern French', date '2026-11-22'
from inserted
where google_place_id = 'ChIJ6SqyXIoJxkcR22CqP0T14q4'
returning restaurant_id, cuisine_id;

-- ============================================================
-- 2. Verify
-- ============================================================

select r.restaurant_code, r.name, r.michelin_stars, r.inclusion_reason,
       r.cuisine_id, r.address, r.phone, r.google_place_id, es.selected_on
from public.restaurants r
join public.editorial_selections es on es.restaurant_id = r.id
where es.removed_on is null
order by r.restaurant_code;
