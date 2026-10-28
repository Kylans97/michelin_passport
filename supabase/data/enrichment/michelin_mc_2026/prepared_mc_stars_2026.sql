-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Guide Monaco 2026: the Principality's nine starred restaurants,
-- brought into scope by the product owner on 2026-10-28 (QA-224).
-- Written 2026-10-28.
--
-- SOURCE: MICHELIN only.
--   * The France 2026 full list (16 March 2026) names 9 Monaco restaurants:
--     1 x 3, 3 x 2, 5 x 1 (../michelin_fr_stars_2026/_source/).
--   * guide.michelin.com/en/mc/restaurants/all-starred on 2026-10-28:
--     "1-9 of 9 restaurants", the same nine with the same stars.
--   * Each restaurant's own MICHELIN page (structured data, award year 2026):
--     name, address, coordinates, phone and website below
--     (_source/michelin_mc_pages_parsed.json). Blue Bay's March URL
--     (le-blue-bay) now 404s; its current page is blue-bay-marcel-ravin.
--
-- CITY: the existing MC row "Monte Carlo", which both Monaco Key hotels
-- (hotel_193, hotel_194) already use. No new city, so no migration.
--
-- PHONES: set only where MICHELIN's number also appears on the restaurant's
-- own site (check_mc_phones.py, 2026-10-28): 7 of 9. Left NULL: Le Louis XV
-- (its MICHELIN website link is Ducasse's group address page) and Robuchon
-- Monaco (number not in the site's page source).
--
-- HOTEL LINKS: only where the restaurant's own MICHELIN address names a Key
-- hotel already in hotels: Le Louis XV and Le Grill (Hôtel de Paris
-- Monte-Carlo, hotel_193) and Les Ambassadeurs (Hôtel Métropole, 4 avenue
-- de la Madone, hotel_194). No other links and no property_name are guessed.
--
-- NOTE: Elsa's MICHELIN address is Monte-Carlo Beach, Roquebrune-Cap-Martin,
-- just across the border in France; MICHELIN files it under Monaco with
-- country MCO. It is stored as MICHELIN has it (country MC) and logged.
--
-- One transaction; every check raises and rolls the whole file back.

begin;

do $$
begin
  if exists (select 1 from public.restaurants where restaurant_code ~ '^rest_[0-9]+$'
              and substring(restaurant_code from 6)::int between 1579 and 1587) then
    raise exception 'codes rest_1579..rest_1587 are no longer free -- re-check';
  end if;
  if exists (select 1 from public.restaurants where country_code = 'MC') then
    raise exception 'Monaco already has restaurants -- re-check';
  end if;
  if (select count(*) from public.cities where country_code = 'MC' and name = 'Monte Carlo') <> 1 then
    raise exception 'expected exactly one MC city Monte Carlo';
  end if;
  if (select count(*) from public.hotels where hotel_code in ('hotel_193', 'hotel_194') and country_code = 'MC') <> 2 then
    raise exception 'hotel_193 / hotel_194 are not the two Monaco hotels any more';
  end if;
  if (select count(distinct guide_year) from public.award_history where award_type = 'michelin_stars' and is_current
        and entity_id in (select id from public.restaurants where country_code = 'FR')) <> 1 then
    raise exception 'French current star rows do not share one guide year -- decide the year explicitly';
  end if;
end $$;

create temp table _mc (code text, name text, stars smallint, address text, lon float8, lat float8,
                       michelin_url text, website_url text, phone text) on commit drop;
insert into _mc values
    ('rest_1579', 'Le Louis XV - Alain Ducasse à l''Hôtel de Paris', 3::smallint, 'Place du Casino, 98000 Monaco', 7.4271047, 43.7391839, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/le-louis-xv-alain-ducasse-a-l-hotel-de-paris', 'https://www.ducasse-paris.com/nos-adresses/', NULL),
    ('rest_1580', 'L''Abysse Monte-Carlo', 2::smallint, '1 square Beaumarchais, 98000 Monaco', 7.4259282, 43.7384886, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/l-abysse-monte-carlo', 'https://www.montecarlosbm.com/fr/restaurant/labysse-monte-carlo', '+377 98 06 94 94'),
    ('rest_1581', 'Les Ambassadeurs by Christophe Cussac', 2::smallint, 'Hôtel Métropole Monte-Carlo, 4 avenue de la Madone, 98000 Monaco', 7.4275615, 43.7405056, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/les-ambassadeurs-by-christophe-cussac', 'https://www.metropole.com/fr/restaurant-bar', '+377 93 15 15 10'),
    ('rest_1582', 'Blue Bay Marcel Ravin', 2::smallint, '40 avenue Princesse-Grace, 98000 Monaco', 7.4379746, 43.7488966, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/blue-bay-marcel-ravin', 'https://www.montecarlosbm.com/fr/restaurant-monaco/le-blue-bay', '+377 98 06 00 35'),
    ('rest_1583', 'Elsa Marcel Ravin', 1::smallint, 'Monte-Carlo Beach, avenue Princesse-Grace, Roquebrune-Cap-Martin, 98000 Monaco', 7.4443181, 43.7506541, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/elsa-marcel-ravin', 'https://www.montecarlosbm.com/fr/restaurant-monaco/elsa', '+377 98 06 50 05'),
    ('rest_1584', 'Le Grill', 1::smallint, 'Hôtel de Paris Monte-Carlo, place du Casino, 98000 Monaco', 7.4271, 43.7393665, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/le-grill9786', 'https://www.montecarlosbm.com/fr/restaurant-monaco/le-grill', '+377 98 06 88 88'),
    ('rest_1585', 'Pavyllon Monte-Carlo, un restaurant de Yannick Alléno', 1::smallint, 'Square Beaumarchais, 98000 Monaco', 7.4258682, 43.7384624, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/pavyllon-monte-carlo', 'https://www.montecarlosbm.com/fr/restaurant-monaco/pavyllon-monte-carlo-restaurant-yannick-alleno', '+377 98 06 98 98'),
    ('rest_1586', 'Robuchon Monaco', 1::smallint, 'Esplanade du Portier, 98000 Monaco', 7.4302288, 43.742019, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/robuchon-monaco', 'https://robuchonmonaco.com/', NULL),
    ('rest_1587', 'La Table d''Antonio Salvatore au Rampoldi', 1::smallint, '3 avenue des Spélugues, 98000 Monaco', 7.4278965, 43.7403707, 'https://guide.michelin.com/en/monaco-region/monaco/restaurant/la-table-d-antonio-salvatore-au-rampoldi', 'https://rampoldi.mc/la-table-dantonio-salvatore/', '+377 93 30 70 44');

do $$
declare bad text;
begin
  select string_agg(m.name, ', ') into bad from _mc m join public.restaurants r on r.michelin_url = m.michelin_url;
  if bad is not null then raise exception 'already present by michelin_url: %', bad; end if;
end $$;

insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
   address, location, michelin_url, website_url, phone)
select m.code, m.name, m.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = 'MC' and c.name = 'Monte Carlo'),
       'MC', m.address, ST_SetSRID(ST_MakePoint(m.lon, m.lat), 4326)::geography,
       m.michelin_url, m.website_url, m.phone
from _mc m;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', m.stars, true, date '2026-03-16'
from _mc m join public.restaurants r on r.restaurant_code = m.code;

insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, 'exact', v.evidence, now()
from (values
  ('hotel_193', 'rest_1579', 'MICHELIN restaurant page: "Le Louis XV - Alain Ducasse à l''Hôtel de Paris", Place du Casino, 98000 Monaco; the hotel row is Place du Casino, 98000 Monaco'),
  ('hotel_193', 'rest_1584', 'MICHELIN restaurant page address: "Hôtel de Paris Monte-Carlo, place du Casino, 98000 Monaco"'),
  ('hotel_194', 'rest_1581', 'MICHELIN restaurant page address: "Hôtel Métropole Monte-Carlo, 4 avenue de la Madone, 98000 Monaco"; the hotel row is 4 Avenue de la Madone, 98000 Monaco')
) as v(hotel_code, restaurant_code, evidence)
join public.hotels h on h.hotel_code = v.hotel_code
join public.restaurants r on r.restaurant_code = v.restaurant_code;

do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = 'MC' and michelin_stars is not null;
  if n <> 9 then raise exception 'expected 9 starred MC restaurants, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'MC' and michelin_stars = 3;
  if n <> 1 then raise exception 'expected 1 three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'MC' and michelin_stars = 2;
  if n <> 3 then raise exception 'expected 3 two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'MC' and michelin_stars = 1;
  if n <> 5 then raise exception 'expected 5 one-star, found %', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = 'MC'
     and (select count(*) from public.award_history a where a.entity_type = 'restaurant' and a.entity_id = r.id
           and a.award_type = 'michelin_stars' and a.is_current and a.award_value = r.michelin_stars) <> 1;
  if n <> 0 then raise exception '% MC restaurants without exactly one matching current star row', n; end if;
  select count(*) into n from public.hotel_restaurants hr join public.restaurants r on r.id = hr.restaurant_id
   where r.country_code = 'MC';
  if n <> 3 then raise exception 'expected 3 MC hotel links, found %', n; end if;
end $$;

commit;
