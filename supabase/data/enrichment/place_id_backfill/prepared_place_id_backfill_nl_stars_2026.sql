-- PREPARED -- NOT APPLIED.
--
-- Google Place IDs for the 9 restaurants newly starred in the MICHELIN Gids
-- Nederland 2026 (rest_1396..rest_1404), written 2026-10-28. Same method and
-- rules as README.md / prepared_place_id_backfill.sql. Coordinates from
-- ../michelin_nl_stars_2026/new_restaurants.csv (MICHELIN JSON-LD); codes
-- from ../michelin_nl_stars_2026/prepared_nl_stars_2026.sql.
-- Evidence per row: placeid_results_nl_stars_2026.csv.
--
-- All 9 confirmed: the restaurant's own record (never the host hotel's, for
-- Nassau and Wild Atelier), each linking to the venue's site; 8 under 50 m,
-- Ambrozijn at 102 m with an exact address match.
--
-- Run only AFTER prepared_nl_stars_2026.sql: aborts until all 9 codes exist,
-- and unless each is the Dutch restaurant with the expected MICHELIN page.
-- Fills only `google_place_id is null`; aborts on an ID already held by
-- another restaurant (UNIQUE per table). Safe to re-run.

begin;

create temp table _pid_nl_2026 (code text primary key, place_id text not null unique, michelin_url text not null unique) on commit drop;
insert into _pid_nl_2026 values
    ('rest_1396', 'ChIJEfDtg9TrwEcR2JylGFdSJFQ', 'https://guide.michelin.com/en/limburg/valkenburg/restaurant/ambrozijn'),  -- 102 m, Ambrozijn
    ('rest_1397', 'ChIJUZqHp6O1xUcRPZzDJEW7adk', 'https://guide.michelin.com/en/zuid-holland/delft/restaurant/azurite'),  -- 40 m, Azurite
    ('rest_1398', 'ChIJ45WZxVlzxkcROuKqhfN6z1s', 'https://guide.michelin.com/en/utrecht/loenen-aan-de-vecht/restaurant/bij-sidney'),  -- 2 m, Bij Sidney
    ('rest_1399', 'ChIJp96hO8Mmx0cRAxaro-6IP4k', 'https://guide.michelin.com/en/noord-brabant/mierlo_2216676/restaurant/de-cuijt'),  -- 10 m, De Cuijt
    ('rest_1400', 'ChIJ3S4ESJ4PyEcR9WG5iiTCmFE', 'https://guide.michelin.com/en/drenthe/veeningen_2214724/restaurant/le-epifaan'),  -- 15 m, Le Epifaan
    ('rest_1401', 'ChIJ86hg0cTNyUcRl_BhT5E-hqQ', 'https://guide.michelin.com/en/groningen/groningen/restaurant/nassau'),  -- 32 m, Nassau
    ('rest_1402', 'ChIJFUGpKdWNxEcRNwkOx4Hzxas', 'https://guide.michelin.com/en/zeeland/kortgene_2215334/restaurant/rozewied'),  -- 19 m, Rozewied
    ('rest_1403', 'ChIJh-5FLeGVwEcRx8G-xWW9_fQ', 'https://guide.michelin.com/en/limburg/schin-op-geul_2216951/restaurant/suis'),  -- 8 m, SUIS
    ('rest_1404', 'ChIJgT_EfwDJx0cRNWWoTdruxbo', 'https://guide.michelin.com/en/gelderland/hoog-soeren_2216407/restaurant/wild-atelier');  -- 14 m, Wild Atelier

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _pid_nl_2026 p
   where not exists (select 1 from public.restaurants t where t.restaurant_code = p.code);
  if bad is not null then raise exception 'restaurants: unknown codes (run prepared_nl_stars_2026.sql first): %', bad; end if;

  -- Identity guard (added 2026-10-28, after another country's unapplied
  -- codes were found colliding with an applied import): each code must be
  -- the Dutch restaurant this file was researched for, identified by its
  -- MICHELIN page -- never a different restaurant holding the same code.
  select string_agg(p.code, ', ') into bad from _pid_nl_2026 p
    join public.restaurants t on t.restaurant_code = p.code
   where t.country_code <> 'NL' or t.michelin_url is distinct from p.michelin_url;
  if bad is not null then raise exception 'restaurants: code is not the expected Dutch restaurant: %', bad; end if;

  select string_agg(p.code || ' -> ' || p.place_id || ' (held by ' || t.restaurant_code || ')', '; ') into bad
    from _pid_nl_2026 p join public.restaurants t
      on t.google_place_id = p.place_id and t.restaurant_code <> p.code;
  if bad is not null then raise exception 'restaurants: Place ID already used by another row: %', bad; end if;

  select string_agg(p.code, ', ') into bad from _pid_nl_2026 p
    join public.restaurants t on t.restaurant_code = p.code
   where t.google_place_id is not null and t.google_place_id <> p.place_id;
  if bad is not null then raise notice 'restaurants: already holds a different Place ID, left untouched: %', bad; end if;
end $$;

update public.restaurants t set google_place_id = p.place_id
  from _pid_nl_2026 p
 where t.restaurant_code = p.code and t.google_place_id is null;

commit;
