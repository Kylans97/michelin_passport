-- PREPARED -- NOT APPLIED.
--
-- Google Place IDs for the 13 restaurants newly starred in the MICHELIN Guide
-- Belgium 2026 (rest_1827..rest_1839; first numbered rest_1405..1417 and
-- renumbered the same day, when France 2026 had taken those codes), written 2026-10-28. Same method and
-- rules as README.md / prepared_place_id_backfill.sql. Codes and coordinates
-- from ../michelin_be_lu_stars_2026/prepared_be_lu_stars_2026.sql, checked
-- row by row against ../michelin_be_lu_stars_2026/new_restaurants.csv
-- (MICHELIN JSON-LD). Evidence per row: placeid_results_be_stars_2026.csv.
--
-- All 13 confirmed: one candidate each, the restaurant's own record, with
-- the official site and the MICHELIN address; 12 under 30 m, Sensum Gent at
-- 111 m with an exact address match. Héliport Brasserie shows
-- CLOSED_TEMPORARILY on Google -- a finding, not a reason to withhold the ID.
--
-- Run only AFTER prepared_be_lu_stars_2026.sql: aborts until all 13 codes
-- exist, and unless each is the Belgian restaurant with the expected
-- MICHELIN page. Fills only `google_place_id is null`; aborts on an ID already held
-- by another restaurant (UNIQUE per table). Safe to re-run.

begin;

create temp table _pid_be_2026 (code text primary key, place_id text not null unique, michelin_url text not null unique) on commit drop;
insert into _pid_be_2026 values
    ('rest_1827', 'ChIJI005cUTCw0cR60lkDX7vnvo', 'https://guide.michelin.com/en/vlaams-brabant/strombeek-bever/restaurant/t-stoveke'),  -- 2 m, 't Stoveke
    ('rest_1828', 'ChIJT4ToJKdhwUcRHq2mDWiYgxg', 'https://guide.michelin.com/en/vlaams-brabant/heverlee/restaurant/couvert-couvert'),  -- 10 m, Couvert Couvert
    ('rest_1829', 'ChIJfXkxdSW7w0cRco2u8gYkbPw', 'https://guide.michelin.com/en/oost-vlaanderen/ninove/restaurant/de-bakermat'),  -- 13 m, De Bakermat
    ('rest_1830', 'ChIJAx-M4tlgwUcRmXyrj6eUHOw', 'https://guide.michelin.com/en/vlaams-brabant/leuven/restaurant/eed'),  -- 26 m, EED
    ('rest_1831', 'ChIJjRoSkNdgwUcRYrG2-h0eCWI', 'https://guide.michelin.com/en/vlaams-brabant/leuven/restaurant/essenciel'),  -- 12 m, EssenCiel
    ('rest_1832', 'ChIJWZv9Z5j3wEcRVAc7p_mzONc', 'https://guide.michelin.com/en/liege/liege/restaurant/heliport-brasserie'),  -- 7 m, Héliport Brasserie
    ('rest_1833', 'ChIJkYP82l2swUcRw1CVbx37FMc', 'https://guide.michelin.com/en/liege/modave_1065092/restaurant/la-roseraie'),  -- 20 m, La Roseraie Modave
    ('rest_1834', 'ChIJrfiY8NXbw0cRer3pt1VSa2c', 'https://guide.michelin.com/en/bruxelles-capitale/woluwe-saint-pierre/restaurant/menssa'),  -- 18 m, Menssa
    ('rest_1835', 'ChIJzzbG3f_3w0cRQLYw8YYuq14', 'https://guide.michelin.com/en/antwerpen/be-antwerpen/restaurant/nebo-1197020'),  -- 24 m, Nebo
    ('rest_1836', 'ChIJwfnUD2txw0cR0_9xO0hX36c', 'https://guide.michelin.com/en/oost-vlaanderen/gent/restaurant/oak'),  -- 6 m, OAK
    ('rest_1837', 'ChIJm6VJcdcBwUcRDiojP78doF8', 'https://guide.michelin.com/en/liege/saint-georges-sur-meuse/restaurant/philippe-fauchet'),  -- 7 m, Philippe Fauchet
    ('rest_1838', 'ChIJ17v_QcenxEcR8tP55_pRpaA', 'https://guide.michelin.com/en/west-vlaanderen/sint-denijs-westrem/restaurant/sensum-1194348'),  -- 111 m, Sensum Gent
    ('rest_1839', 'ChIJkamNxyxfwEcRvJCwxs-BJf4', 'https://guide.michelin.com/en/liege/comblain-au-pont/restaurant/un-max-de-gout');  -- 12 m, Un Max de Goût

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _pid_be_2026 p
   where not exists (select 1 from public.restaurants t where t.restaurant_code = p.code);
  if bad is not null then raise exception 'restaurants: unknown codes (run prepared_be_lu_stars_2026.sql first): %', bad; end if;

  -- Identity guard (added 2026-10-28 after the codes moved): each code must
  -- be the Belgian restaurant this file was researched for, identified by
  -- its MICHELIN page -- never a different restaurant that later took the
  -- same code. The first numbering (rest_1405..1417) collided with France
  -- 2026, applied the same day.
  select string_agg(p.code, ', ') into bad from _pid_be_2026 p
    join public.restaurants t on t.restaurant_code = p.code
   where t.country_code <> 'BE' or t.michelin_url is distinct from p.michelin_url;
  if bad is not null then raise exception 'restaurants: code is not the expected Belgian restaurant: %', bad; end if;

  select string_agg(p.code || ' -> ' || p.place_id || ' (held by ' || t.restaurant_code || ')', '; ') into bad
    from _pid_be_2026 p join public.restaurants t
      on t.google_place_id = p.place_id and t.restaurant_code <> p.code;
  if bad is not null then raise exception 'restaurants: Place ID already used by another row: %', bad; end if;

  select string_agg(p.code, ', ') into bad from _pid_be_2026 p
    join public.restaurants t on t.restaurant_code = p.code
   where t.google_place_id is not null and t.google_place_id <> p.place_id;
  if bad is not null then raise notice 'restaurants: already holds a different Place ID, left untouched: %', bad; end if;
end $$;

update public.restaurants t set google_place_id = p.place_id
  from _pid_be_2026 p
 where t.restaurant_code = p.code and t.google_place_id is null;

commit;
