-- MICHELIN Key hotels, Monaco 2026 (written 2026-10-30; production read the same day,
-- _source/production_mc_export_20261030.json).
-- MICHELIN publishes Monaco's Keys inside its French 2026 Key article (18 Sep 2026):
-- Hôtel de Paris Monte-Carlo 3, Hotel Metropole Monte Carlo 2, Hermitage Monte-Carlo 1
-- (new in 2026). Production holds the first two with correct current 2026 Key rows, and
-- no Hermitage. This file:
--   1. adds Hermitage Monte-Carlo (hotel_2212) with its current 2026 Key row;
--   2. fills empty fields on the two existing hotels (fill-only): michelin_url on both,
--      phone and website_url on Metropole;
--   3. links L'Abysse Monte-Carlo to Hermitage (MICHELIN restaurant page "Stay at the
--      hotel"; MICHELIN's restaurant pin, 1 square Beaumarchais, 213 m from the hotel's
--      pin -> campus). The three existing Monaco links are confirmed by MICHELIN the same way.
-- Sources: each hotel page's JSON-LD (_source/michelin_fr_key_hotel_pages_20261030.json,
-- ids 6872, 4661, 6873); website and phone read on the hotel's own site in a browser,
-- 2026-10-30 (montecarlosbm.com Hermitage page: "Square Beaumarchais, 98000 Monaco",
-- +377 98 06 40 00; metropole.com: "4 Avenue de la Madone, 98000 Monaco", (+377) 93 15 15 15,
-- both matching MICHELIN). Google Place ID left NULL (QA-350). Independent of the French
-- file and its migration; uses the existing 'Monte Carlo' city.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;

do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = 'MC';
  if n <> 2 then raise exception 'MC: expected 2 hotels (2026-10-30), found % -- production changed, re-check', n; end if;
  select count(*) into n from (values ('hotel_193', 'Hôtel de Paris Monte-Carlo', 3), ('hotel_194', 'Hotel Metropole Monte Carlo', 2)) e(code, name, keys)
   where not exists (select 1 from public.hotels h where h.hotel_code = e.code and h.name = e.name and h.country_code = 'MC' and h.michelin_keys = e.keys);
  if n <> 0 then raise exception 'MC: % existing hotels no longer match their 2026-10-30 code, name and Key', n; end if;
  if exists (select 1 from public.hotels where hotel_code = 'hotel_2212') then
    raise exception 'hotel code hotel_2212 is no longer free -- re-check';
  end if;
  if exists (select 1 from public.hotels where michelin_url ~ '-(6872|4661|6873)$') then
    raise exception 'a Monaco Key hotel''s MICHELIN URL is already in use';
  end if;
  if (select count(*) from public.cities where country_code = 'MC' and name = 'Monte Carlo') <> 1 then
    raise exception 'MC city Monte Carlo does not resolve to exactly one row';
  end if;
  select count(*) into n from public.restaurants where restaurant_code = 'rest_1580' and name = 'L''Abysse Monte-Carlo' and country_code = 'MC' and property_name is null;
  if n <> 1 then raise exception 'rest_1580 L''Abysse Monte-Carlo is not as exported'; end if;
end $$;

-- 1. Hermitage Monte-Carlo
insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url, website_url, phone)
select 'hotel_2212', 'Hermitage Monte-Carlo', 1, c.id, 'MC', 'Square Beaumarchais, 98000 Monaco',
       ST_SetSRID(ST_MakePoint(7.425814, 43.740406), 4326)::geography,
       'https://guide.michelin.com/en/hotels-stays/monte-carlo/hotel-hermitage-monte-carlo-6873',
       'https://www.montecarlosbm.com/en/hotel-monaco/hotel-hermitage-monte-carlo', '+377 98 06 40 00'
  from public.cities c where c.country_code = 'MC' and c.name = 'Monte Carlo';
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2026, 'michelin_keys', 1, true, date '2026-09-18'
  from public.hotels h where h.hotel_code = 'hotel_2212';

-- 2. existing Monaco hotels, fill-only (never overwrites)
update public.hotels set michelin_url = 'https://guide.michelin.com/en/hotels-stays/monte-carlo/hotel-de-paris-monte-carlo-6872', updated_at = now()
 where hotel_code = 'hotel_193' and michelin_url is null;
update public.hotels set michelin_url = 'https://guide.michelin.com/en/hotels-stays/monte-carlo/hotel-metropole-monte-carlo-4661', updated_at = now()
 where hotel_code = 'hotel_194' and michelin_url is null;
update public.hotels set phone = '+377 93 15 15 15', updated_at = now()
 where hotel_code = 'hotel_194' and phone is null;
update public.hotels set website_url = 'https://www.metropole.com/', updated_at = now()
 where hotel_code = 'hotel_194' and website_url is null;

-- 3. link
insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, 'campus',
       'MICHELIN restaurant page ''Stay at the hotel'' -> /en/hotels-stays/monte-carlo/hotel-hermitage-monte-carlo-6873 (Hermitage Monte-Carlo), a 1-Key hotel; MICHELIN''s restaurant pin (1 square Beaumarchais) 213 m from the hotel''s MICHELIN pin. 2026-10-30.',
       now()
  from public.hotels h, public.restaurants r
 where h.hotel_code = 'hotel_2212' and r.restaurant_code = 'rest_1580'
on conflict (hotel_id, restaurant_id) do nothing;

-- post-conditions: MICHELIN's 2026 Monaco Keys, 1/1/1
do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = 'MC' and michelin_keys = 3;
  if n <> 1 then raise exception 'expected 1 three-Key MC hotel, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'MC' and michelin_keys = 2;
  if n <> 1 then raise exception 'expected 1 two-Key MC hotel, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'MC' and michelin_keys = 1;
  if n <> 1 then raise exception 'expected 1 one-Key MC hotel, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = 'MC'
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% MC Key hotels without exactly one matching current Key row', n; end if;
  select count(*) into n from public.hotels where country_code = 'MC' and michelin_url is null;
  if n <> 0 then raise exception '% MC hotels still without a MICHELIN URL', n; end if;
  select count(*) into n from public.hotel_restaurants hr join public.hotels h on h.id = hr.hotel_id where h.country_code = 'MC';
  if n <> 4 then raise exception 'expected 4 MC hotel links, found %', n; end if;
end $$;

commit;
