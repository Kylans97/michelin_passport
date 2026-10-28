-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Guide Belgium & Luxembourg 2026 (announced 4 May 2026): bring
-- every BE/LU restaurant's stars and award_history in line with MICHELIN's
-- own published selection. Written 2026-10-28.
--
-- SOURCE: MICHELIN only -- guide.michelin.com/en/be|lu/restaurants/
-- all-starred (136 restaurants live), cross-checked against MICHELIN's
-- full-list articles for 2026 (139) and 2025 (151). The 3-row difference is
-- three restaurants MICHELIN took offline after May (see KEPT below).
-- Captures and the per-row comparison are in this folder; see
-- BE_LU_STARS_2026_REPORT.md.
--
-- GUIDE YEAR: MICHELIN labels this selection 2026 (JSON-LD dateAwarded
-- "2026"). Unlike the Netherlands, the BE/LU launch rows labelled 2026 hold
-- this 2026 edition's values -- every row checked against the 2026 listing
-- -- except the six below, which still carry their 2025 value. So no blanket
-- relabel: only those six rows move to 2025 (DATA_UPDATE_PROCESS.md, the
-- launch-label rule, applied row by row).
--
-- WHAT CHANGES
--   1. losses ('rest_0163', 'rest_0167', 'rest_0824', 'rest_0830', 'rest_0840', 'rest_0846' -- La Durée, Ralf Berendsen, Bar Bulot
--      Zedelgem, Mémoire, Table d'Amis, Aurum): starred in MICHELIN's 2025
--      list, absent from 2026. Their 2026 row is relabelled 2025 (value
--      unchanged, closed), a 2026 row with award_value NULL is written,
--      restaurants.michelin_stars set NULL. Rows are kept.
--   2. Le Lys (rest_1368): one star, no award_history row at all -- the
--      2026 row is added.
--   3. michelin_url filled for 16 restaurants that had none (same
--      restaurant, same stars; matched by MICHELIN page, checked by eye).
--   4. 13 restaurants starred in 2026 (and before) but missing from the
--      catalogue added (rest_1405..rest_1417), each with a 2026 award_history
--      row. Their awards before 2026 are not recorded -- the same launch
--      limitation as every seeded row.
--   KEPT unchanged ('rest_0798', 'rest_0836', 'rest_0890' -- Kommilfoo, La Paix, La Table de Manon): in the
--   2026 edition with stars, but MICHELIN removed their pages after May with
--   no reason given. User decision 2026-10-28: keep the stars, log, revisit
--   (QA log).
--
-- PREREQUISITE: supabase/migrations/20261016150000_add_be_2026_star_cities.sql.
-- One transaction; every check raises, rolling the whole file back. A
-- re-run after success aborts at the first check.

begin;

do $$
begin
  if exists (select 1 from public.restaurants
              where restaurant_code ~ '^rest_[0-9]+$'
                and substring(restaurant_code from 6)::int between 1405 and 1404 + 13) then
    raise exception 'codes rest_1405..rest_1417 are no longer free -- re-check';
  end if;
  if exists (select 1 from public.award_history ah
               join public.restaurants r on r.id = ah.entity_id
              where ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
                and r.country_code in ('BE', 'LU') and ah.guide_year = 2025) then
    raise exception 'BE/LU 2025 star rows already exist -- this file has run, or production changed since 2026-10-28';
  end if;
  if (select count(*) from public.award_history ah
        join public.restaurants r on r.id = ah.entity_id
       where ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
         and r.country_code in ('BE', 'LU') and ah.guide_year = 2026 and ah.is_current) <> 131 then
    raise exception 'expected 131 current BE/LU 2026 star rows (export of 2026-10-28) -- production changed, re-check';
  end if;
end $$;

-- 1. losses
create temp table _losses (code text primary key) on commit drop;
insert into _losses select unnest(array['rest_0163', 'rest_0167', 'rest_0824', 'rest_0830', 'rest_0840', 'rest_0846']);

update public.award_history ah set guide_year = 2025, is_current = false
  from public.restaurants r, _losses l
 where r.id = ah.entity_id and r.restaurant_code = l.code
   and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
   and ah.guide_year = 2026;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', null, true, date '2026-05-04'
from public.restaurants r join _losses l on l.code = r.restaurant_code;

update public.restaurants r set michelin_stars = null, updated_at = now()
  from _losses l where r.restaurant_code = l.code;

-- 2. Le Lys: the missing current row
insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', 1, true, date '2026-05-04'
from public.restaurants r
where r.restaurant_code = 'rest_1368' and r.michelin_stars = 1
  and not exists (select 1 from public.award_history ah
                   where ah.entity_type = 'restaurant' and ah.entity_id = r.id
                     and ah.award_type = 'michelin_stars');

-- 3. missing MICHELIN links
create temp table _urls (code text primary key, michelin_url text unique) on commit drop;
insert into _urls values
    ('rest_0164', 'https://guide.michelin.com/en/west-vlaanderen/heist/restaurant/bartholomeus'),
    ('rest_0166', 'https://guide.michelin.com/en/be-limburg/lommel/restaurant/cuchara'),
    ('rest_0168', 'https://guide.michelin.com/en/be-limburg/opglabbeek/restaurant/slagmolen'),
    ('rest_0169', 'https://guide.michelin.com/en/west-vlaanderen/sint-kruis/restaurant/de-jonkman'),
    ('rest_0170', 'https://guide.michelin.com/en/vlaams-brabant/sint-kwintens-lennik/restaurant/sir-kwinten'),
    ('rest_0171', 'https://guide.michelin.com/en/antwerpen/tongerlo_1063046/restaurant/maison-colette'),
    ('rest_0172', 'https://guide.michelin.com/en/namur/arbre/restaurant/l-eau-vive'),
    ('rest_0173', 'https://guide.michelin.com/en/hainaut/baudour/restaurant/d-eugenie-a-emilie'),
    ('rest_0174', 'https://guide.michelin.com/en/be-luxembourg/our/restaurant/la-table-de-maxime'),
    ('rest_0809', 'https://guide.michelin.com/en/oost-vlaanderen/aalst/restaurant/kelderman'),
    ('rest_0810', 'https://guide.michelin.com/en/oost-vlaanderen/waasmunster/restaurant/sense-1192293'),
    ('rest_0811', 'https://guide.michelin.com/en/west-vlaanderen/sint-kruis/restaurant/goffin'),
    ('rest_0812', 'https://guide.michelin.com/en/west-vlaanderen/elverdinge/restaurant/hostellerie-st-nicolas'),
    ('rest_0834', 'https://guide.michelin.com/en/namur/liernu/restaurant/l-air-du-temps371956'),
    ('rest_0837', 'https://guide.michelin.com/en/antwerpen/be-antwerpen/restaurant/the-jane-1244485'),
    ('rest_0838', 'https://guide.michelin.com/en/bruxelles-capitale/bruxelles/restaurant/comme-chez-soi113872');

do $$
declare bad text;
begin
  select string_agg(u.code, ', ') into bad from _urls u
    join public.restaurants r on r.michelin_url = u.michelin_url and r.restaurant_code <> u.code;
  if bad is not null then raise exception 'michelin_url already used by another row: %', bad; end if;
end $$;

update public.restaurants r set michelin_url = u.michelin_url, updated_at = now()
  from _urls u where r.restaurant_code = u.code and r.michelin_url is null;

-- 4. missing starred restaurants
create temp table _new (code text, name text, stars smallint, city text, address text,
                        lon float8, lat float8, michelin_url text, website_url text,
                        phone text, property_name text) on commit drop;
insert into _new values
    ('rest_1405', '''t Stoveke', 1::smallint, 'Strombeek-Bever', 'Jetsestraat 52, 1853 Strombeek-Bever', 4.3507766, 50.9049469, 'https://guide.michelin.com/en/vlaams-brabant/strombeek-bever/restaurant/t-stoveke', 'https://www.tstoveke.be/', '+32 2 267 67 25', NULL),
    ('rest_1406', 'Couvert Couvert', 1::smallint, 'Heverlee', 'Sint-Jansbergsesteenweg 171, 3001 Heverlee', 4.6596864, 50.8629609, 'https://guide.michelin.com/en/vlaams-brabant/heverlee/restaurant/couvert-couvert', 'https://couvertcouvert.be/', '+32 16 29 69 79', NULL),
    ('rest_1407', 'De Bakermat', 1::smallint, 'Ninove', 'Leopoldlaan 95, 9400 Ninove', 4.0203277, 50.8262371, 'https://guide.michelin.com/en/oost-vlaanderen/ninove/restaurant/de-bakermat', 'https://www.debakermatninove.be/', '+32 54 25 80 25', NULL),
    ('rest_1408', 'EED', 1::smallint, 'Leuven', 'Vaartstraat 14, 3000 Leuven', 4.7024848, 50.880639, 'https://guide.michelin.com/en/vlaams-brabant/leuven/restaurant/eed', 'https://eedleuven.be/', '+32 16 19 06 14', NULL),
    ('rest_1409', 'EssenCiel', 1::smallint, 'Leuven', 'Bondgenotenlaan 114, 3000 Leuven', 4.711476, 50.8805967, 'https://guide.michelin.com/en/vlaams-brabant/leuven/restaurant/essenciel', 'https://www.essenciel.be/', '+32 474 26 18 64', NULL),
    ('rest_1410', 'Héliport Brasserie', 1::smallint, 'Liège', 'allée des Érables, 4000 Liège', 5.5961592, 50.5789946, 'https://guide.michelin.com/en/liege/liege/restaurant/heliport-brasserie', 'https://www.heliportbrasserie.be/', '+32 4 366 28 20', NULL),
    ('rest_1411', 'La Roseraie Modave', 1::smallint, 'Modave', 'route de Limet 80, 4577 Modave', 5.2866657, 50.4541319, 'https://guide.michelin.com/en/liege/modave_1065092/restaurant/la-roseraie', 'https://www.laroseraiemodave.com/', '+32 85 41 13 60', NULL),
    ('rest_1412', 'Menssa', 1::smallint, 'Woluwe-Saint-Pierre', 'Avenue de Tervueren 453, 1150 Woluwe-Saint-Pierre', 4.4466158, 50.8228567, 'https://guide.michelin.com/en/bruxelles-capitale/woluwe-saint-pierre/restaurant/menssa', 'https://www.menssa.be/', '+32 2 346 66 15', NULL),
    ('rest_1413', 'Nebo', 1::smallint, 'Antwerp', 'Panamarenkoplein 5, 2000 Antwerpen', 4.3829209, 51.2051513, 'https://guide.michelin.com/en/antwerpen/be-antwerpen/restaurant/nebo-1197020', 'https://www.restaurantnebo.be/', '+32 3 272 45 00', NULL),
    ('rest_1414', 'OAK', 1::smallint, 'Ghent', 'Burgstraat 16, 9000 Gent', 3.7190482, 51.0566815, 'https://guide.michelin.com/en/oost-vlaanderen/gent/restaurant/oak', 'https://oakgent.be/', '+32 9 353 90 50', NULL),
    ('rest_1415', 'Philippe Fauchet', 1::smallint, 'Saint-Georges-sur-Meuse', 'rue de Warfée 62, 4470 Saint-Georges-sur-Meuse', 5.37086, 50.6096146, 'https://guide.michelin.com/en/liege/saint-georges-sur-meuse/restaurant/philippe-fauchet', 'https://philippefauchet.be/', NULL, NULL),
    ('rest_1416', 'Sensum Gent', 1::smallint, 'Sint-Denijs-Westrem', 'Kortrijksesteenweg 1026, 9051 Sint-Denijs-Westrem', 3.7029908, 51.0236852, 'https://guide.michelin.com/en/west-vlaanderen/sint-denijs-westrem/restaurant/sensum-1194348', 'https://sensumgent.be/', '+32 9 246 11 46', NULL),
    ('rest_1417', 'Un Max de Goût', 1::smallint, 'Comblain-au-Pont', 'quai de l''Ourthe 17, 4170 Comblain-au-Pont', 5.5785763, 50.4767771, 'https://guide.michelin.com/en/liege/comblain-au-pont/restaurant/un-max-de-gout', 'https://maxdegout.be/', '+32 4 369 17 08', NULL);

do $$
declare bad text;
begin
  select string_agg(n.name || ' (' || n.city || ')', ', ') into bad from _new n
   where (select count(*) from public.cities c where c.country_code = 'BE' and c.name = n.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one BE row: %', bad; end if;
  select string_agg(n.name, ', ') into bad from _new n
    join public.restaurants r on r.michelin_url = n.michelin_url;
  if bad is not null then raise exception 'restaurant already present (michelin_url): %', bad; end if;
end $$;

insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
   address, location, michelin_url, website_url, phone, property_name)
select n.code, n.name, n.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = 'BE' and c.name = n.city),
       'BE', n.address, ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)::geography,
       n.michelin_url, n.website_url, n.phone, n.property_name
from _new n;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current)
select 'restaurant', r.id, 2026, 'michelin_stars', n.stars, true
from _new n join public.restaurants r on r.restaurant_code = n.code;

-- Post-conditions: production equals MICHELIN's 2026 full list (139),
-- i.e. the live listing (136) plus the three KEPT rows.
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = 'BE' and michelin_stars = 3;
  if n <> 2 then raise exception 'BE: expected 2 three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'BE' and michelin_stars = 2;
  if n <> 20 then raise exception 'BE: expected 20 two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'BE' and michelin_stars = 1;
  if n <> 105 then raise exception 'BE: expected 105 one-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'LU' and michelin_stars = 2;
  if n <> 2 then raise exception 'LU: expected 2 two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'LU' and michelin_stars = 1;
  if n <> 10 then raise exception 'LU: expected 10 one-star, found %', n; end if;
  select count(*) into n from public.restaurants r
   where r.country_code in ('BE', 'LU')
     and (select count(*) from public.award_history ah
           where ah.entity_type = 'restaurant' and ah.entity_id = r.id
             and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '% BE/LU restaurants do not have exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r
    join public.award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id
                                and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code in ('BE', 'LU') and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '% BE/LU restaurants disagree with their current award_history row', n; end if;
end $$;

commit;
