-- PREPARED -- NOT APPLIED.
--
-- Google Place IDs for the 13 restaurants newly starred in the MICHELIN Guide
-- Belgium 2026 (rest_1405..rest_1417), written 2026-10-28. Same method and
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
-- exist. Fills only `google_place_id is null`; aborts on an ID already held
-- by another restaurant (UNIQUE per table). Safe to re-run.

begin;

create temp table _pid_be_2026 (code text primary key, place_id text not null unique) on commit drop;
insert into _pid_be_2026 values
    ('rest_1405', 'ChIJI005cUTCw0cR60lkDX7vnvo'),  -- 2 m, 't Stoveke
    ('rest_1406', 'ChIJT4ToJKdhwUcRHq2mDWiYgxg'),  -- 10 m, Couvert Couvert
    ('rest_1407', 'ChIJfXkxdSW7w0cRco2u8gYkbPw'),  -- 13 m, De Bakermat
    ('rest_1408', 'ChIJAx-M4tlgwUcRmXyrj6eUHOw'),  -- 26 m, EED
    ('rest_1409', 'ChIJjRoSkNdgwUcRYrG2-h0eCWI'),  -- 12 m, EssenCiel
    ('rest_1410', 'ChIJWZv9Z5j3wEcRVAc7p_mzONc'),  -- 7 m, Héliport Brasserie
    ('rest_1411', 'ChIJkYP82l2swUcRw1CVbx37FMc'),  -- 20 m, La Roseraie Modave
    ('rest_1412', 'ChIJrfiY8NXbw0cRer3pt1VSa2c'),  -- 18 m, Menssa
    ('rest_1413', 'ChIJzzbG3f_3w0cRQLYw8YYuq14'),  -- 24 m, Nebo
    ('rest_1414', 'ChIJwfnUD2txw0cR0_9xO0hX36c'),  -- 6 m, OAK
    ('rest_1415', 'ChIJm6VJcdcBwUcRDiojP78doF8'),  -- 7 m, Philippe Fauchet
    ('rest_1416', 'ChIJ17v_QcenxEcR8tP55_pRpaA'),  -- 111 m, Sensum Gent
    ('rest_1417', 'ChIJkamNxyxfwEcRvJCwxs-BJf4');  -- 12 m, Un Max de Goût
begin
  select string_agg(p.code, ', ') into bad from _pid_be_2026 p
   where not exists (select 1 from public.restaurants t where t.restaurant_code = p.code);
  if bad is not null then raise exception 'restaurants: unknown codes (run prepared_be_lu_stars_2026.sql first): %', bad; end if;

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
