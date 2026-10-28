-- PREPARED -- NOT APPLIED.
--
-- QA-227: Kjolle (rest_0135, Lima) -- move its stored point onto its building.
-- Written 2026-10-28.
--
-- The stored point, (-12.145, -77.0211), looks rounded and lies 856 m from
-- the restaurant. Kjolle is at Av. Pedro de Osma 301, Barranco, the same
-- building as Central:
--   - The World's 50 Best listing for Kjolle gives Pedro de Osma 301,
--     Barranco, Lima 15063 (theworlds50best.com, checked 2026-10-28).
--   - Living in Peru describes it inside Casa Tupac on that avenue, with
--     Central in the same building.
--   - production's own address for rest_0135 is already
--     "Av. Pedro de Osma 301, Barranco, Lima"; only the point is wrong.
-- OpenStreetMap places that building at (-12.1525709, -77.0225397): node
-- 6228532187, tagged as Central, Avenida Pedro de Osma 301 (Nominatim,
-- 2026-10-28). Central (rest_1578, added 2026-10-28) already uses that point.
--
-- Not changed: google_place_id (ChIJr1L1USC3BZEREp0Z1sp3AeU). It has not
-- been checked against Google (no Places API key); do that when one exists.
--
-- One transaction; aborts unless rest_0135 is still Kjolle at the old point.

begin;

do $$
begin
  if not exists (
    select 1 from public.restaurants
     where restaurant_code = 'rest_0135' and name = 'Kjolle' and country_code = 'PE'
       and round(st_y(location::geometry)::numeric, 4) = -12.1450
       and round(st_x(location::geometry)::numeric, 4) = -77.0211
  ) then
    raise exception 'rest_0135 is not Kjolle at (-12.145, -77.0211) any more -- re-check';
  end if;
end $$;

update public.restaurants
   set location = ST_SetSRID(ST_MakePoint(-77.0225397, -12.1525709), 4326)::geography,
       updated_at = now()
 where restaurant_code = 'rest_0135';

do $$
begin
  if not exists (
    select 1 from public.restaurants
     where restaurant_code = 'rest_0135'
       and round(st_y(location::geometry)::numeric, 7) = -12.1525709
       and round(st_x(location::geometry)::numeric, 7) = -77.0225397
  ) then
    raise exception 'rest_0135 did not end at the expected point';
  end if;
end $$;

commit;
