-- PREPARED -- NOT APPLIED.
--
-- The 50 Best Restaurants 2026 (announced 2026-11-05, Lima), written
-- 2026-11-16. Makes the 2026 list complete, 100 of 100, and closes the
-- 2025 gap:
--   * 8 new restaurants, rest_4200..rest_4207 -- the 2026 entries that had
--     no catalogue row (QA-473) -- with a current award_history row for the
--     4 that hold MICHELIN stars;
--   * 100 ranked worlds_50_best rows for year 2026 (50 top_50, 50
--     extended_51_100): 92 existing catalogue rows plus the 8 new ones;
--   * 1 hall_of_fame row for 2026: Maido (rest_0134, PE), 2025's No. 1,
--     which joined "Best of the Best" and is no longer eligible;
--   * 1 ranked row for 2025: No. 94 Meet the Bund (rest_2739, CN), the gap
--     left by QA-194 (held back 2026-10-28 because the staged record was the
--     wrong restaurant; the row now in the catalogue was added by the
--     MICHELIN China pass and its address equals the 50 Best page's).
--
-- PREREQUISITE (checked below): migration
--   supabase/migrations/20261101390000_add_w50b_2026_cities.sql (Kasauli).
--
-- Catalogue data, applied explicitly after review, never by a db push:
--   supabase db query --linked --file prepared_w50b_2026_import.sql
-- One transaction; every check raises, which rolls the whole file back.
--
-- Keys: restaurant_code + country_code, never name. Per-entry source URL
-- and match basis: w50b_2026_matches.csv. Per-field sources of the new
-- restaurants: w50b_2026_new_restaurants.csv. Official capture:
-- _source/official_restaurants_2026_1-100.csv. See W50B_2026_REPORT.md.
--
-- New restaurants: stars only from each venue's own MICHELIN page; NULL
-- means no star (Nelita is listed without one, Fauna is Bib Gourmand only),
-- never zero. inclusion_reason michelin_star when starred, else
-- worlds_50_best. guide_year is the year that page shows (2026, Baan Tepa
-- 2027). google_place_id NULL for all eight: no Places lookup in this
-- session (QA-476). Codes are fixed, not computed; the guard aborts if any
-- is taken.
--
-- Effect on reads: restaurants_full.worlds_50_best_rank joins the year
-- max(year) where rank is not null, so 2026 becomes the current year as
-- soon as this commits; restaurants not on the 2026 list stop showing a
-- current rank (their history rows stay). is_hall_of_fame is true for any
-- restaurant with a hall_of_fame row, so Maido gains it.

begin;

create temp table w50b_2026_new (
  restaurant_code text, name text, country_code text, city text,
  property_name text, stars smallint, guide_year smallint,
  inclusion_reason text, address text, lon float8, lat float8,
  michelin_url text, website_url text, phone text, worlds_50_best_url text
) on commit drop;

insert into w50b_2026_new values
    ('rest_4200', 'Naar', 'IN', 'Kasauli', 'Amaya', NULL::smallint, NULL::smallint, 'worlds_50_best', 'VPO Darwa, Sub Tehsil Kishangarh, Kasauli, District Solan, Himachal Pradesh 173206', 76.9412636, 31.001467, NULL, 'https://restaurantnaar.com/', '+91 88004 22053', 'https://www.the50.com/discovery/Establishments/India/Kasauli/Naar.html'),
    ('rest_4201', 'Nelita', 'BR', 'São Paulo', NULL, NULL::smallint, NULL::smallint, 'worlds_50_best', 'Rua Ferreira de Araújo, 330, Pinheiros, São Paulo 05428-000', -46.6980906, -23.5605315, 'https://guide.michelin.com/en/sao-paulo-region/sao-paulo/restaurant/nelita', 'https://www.nelitarestaurante.com.br/', '+55 11 2626-1496', 'https://www.the50.com/discovery/Establishments/Brazil/São-Paulo/Nelita.html'),
    ('rest_4202', 'Seroja', 'SG', 'Singapore', NULL, 2::smallint, 2026::smallint, 'michelin_star', 'Duo Galleria, #01-30/31/32/33, 7 Fraser Street, Singapore 189356', 103.858076, 1.2998671, 'https://guide.michelin.com/en/singapore-region/singapore/restaurant/seroja', 'https://seroja.sg/', '+65 8522 2926', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Seroja.html'),
    ('rest_4203', 'Eatanic Garden', 'KR', 'Seoul', 'Josun Palace', 1::smallint, 2026::smallint, 'michelin_star', '36F, Josun Palace Hotel, 231 Teheran-ro, Gangnam-gu, Seoul 06142', 127.04158, 37.50304, 'https://guide.michelin.com/en/seoul-capital-area/kr-seoul/restaurant/eatanic-garden', 'https://jpg.josunhotel.com/dining/EatanicGarden.do', '+82 2-727-7610', NULL),
    ('rest_4204', 'Mosu', 'KR', 'Seoul', NULL, 2::smallint, 2026::smallint, 'michelin_star', '4 Hoenamu-ro 41-gil, Yongsan-gu, Seoul 04344', 126.99615, 37.54115, 'https://guide.michelin.com/en/seoul-capital-area/kr-seoul/restaurant/mosu', 'https://mosuseoul.com/', '+82 2-6272-5678', 'https://www.the50.com/discovery/Establishments/South-Korea/Seoul/Mosu.html'),
    ('rest_4205', 'Baan Tepa', 'TH', 'Bangkok', NULL, 2::smallint, 2027::smallint, 'michelin_star', '561 Ramkhamhaeng Road, Hua Mak, Bang Kapi, Bangkok 10240', 100.6263514, 13.7608267, 'https://guide.michelin.com/en/bangkok-region/bangkok/restaurant/baan-tepa', 'https://www.baantepabkk.com/', '+66 98 696 9074', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Baan-Tepa.html'),
    ('rest_4206', 'Khufu''s', 'EG', 'Giza', NULL, NULL::smallint, NULL::smallint, 'worlds_50_best', 'X4HF+8P, Nazlet El-Semman, Al Haram, Giza 12512', 31.124313, 29.978312, NULL, 'https://khufus.com/', '+20 10 8005 8888', NULL),
    ('rest_4207', 'Fauna', 'MX', 'Valle de Guadalupe', 'Bruma Wine Resort', NULL::smallint, NULL::smallint, 'worlds_50_best', 'México 3 Km. 73, Valle de Guadalupe 22750', -116.5251294, 32.117928, 'https://guide.michelin.com/en/baja-california/valle-de-guadalupe_7770290/restaurant/fauna-1208366', 'https://www.brumawineresort.com/fauna-guadalupe-valley', NULL, 'https://www.the50.com/discovery/Establishments/Mexico/Valle-de-Guadalupe/Fauna.html');

create temp table w50b_2026_stage (
  rank smallint not null,
  list_type text not null,
  restaurant_code text not null,
  country_code text not null
) on commit drop;

insert into w50b_2026_stage (rank, list_type, restaurant_code, country_code) values
    (  1, 'top_50', 'rest_0296', 'ES'),
    (  2, 'top_50', 'rest_0298', 'TH'),
    (  3, 'top_50', 'rest_0297', 'DK'),
    (  4, 'top_50', 'rest_0132', 'MX'),
    (  5, 'top_50', 'rest_0301', 'HK'),
    (  6, 'top_50', 'rest_0137', 'HK'),
    (  7, 'top_50', 'rest_0135', 'PE'),
    (  8, 'top_50', 'rest_0323', 'DK'),
    (  9, 'top_50', 'rest_0044', 'ES'),
    ( 10, 'top_50', 'rest_0304', 'FR'),
    ( 11, 'top_50', 'rest_0302', 'US'),
    ( 12, 'top_50', 'rest_0307', 'TH'),
    ( 13, 'top_50', 'rest_0139', 'PE'),
    ( 14, 'top_50', 'rest_0311', 'TH'),
    ( 15, 'top_50', 'rest_0125', 'SG'),
    ( 16, 'top_50', 'rest_1379', 'BR'),
    ( 17, 'top_50', 'rest_0313', 'KR'),
    ( 18, 'top_50', 'rest_0318', 'TH'),
    ( 19, 'top_50', 'rest_0182', 'DE'),
    ( 20, 'top_50', 'rest_0316', 'IT'),
    ( 21, 'top_50', 'rest_2739', 'CN'),
    ( 22, 'top_50', 'rest_0138', 'CL'),
    ( 23, 'top_50', 'rest_0142', 'SE'),
    ( 24, 'top_50', 'rest_0003', 'IT'),
    ( 25, 'top_50', 'rest_0140', 'BR'),
    ( 26, 'top_50', 'rest_1378', 'IN'),
    ( 27, 'top_50', 'rest_0308', 'IT'),
    ( 28, 'top_50', 'rest_0128', 'AE'),
    ( 29, 'top_50', 'rest_0317', 'ES'),
    ( 30, 'top_50', 'rest_0266', 'AT'),
    ( 31, 'top_50', 'rest_0143', 'CO'),
    ( 32, 'top_50', 'rest_0303', 'TH'),
    ( 33, 'top_50', 'rest_0312', 'ES'),
    ( 34, 'top_50', 'rest_1136', 'FR'),
    ( 35, 'top_50', 'rest_1371', 'ZA'),
    ( 36, 'top_50', 'rest_2757', 'CN'),
    ( 37, 'top_50', 'rest_1374', 'EC'),
    ( 38, 'top_50', 'rest_0309', 'IT'),
    ( 39, 'top_50', 'rest_0237', 'CH'),
    ( 40, 'top_50', 'rest_0474', 'DK'),
    ( 41, 'top_50', 'rest_1372', 'KR'),
    ( 42, 'top_50', 'rest_0156', 'BE'),
    ( 43, 'top_50', 'rest_0315', 'IT'),
    ( 44, 'top_50', 'rest_0136', 'AR'),
    ( 45, 'top_50', 'rest_0141', 'PE'),
    ( 46, 'top_50', 'rest_1370', 'CO'),
    ( 47, 'top_50', 'rest_1579', 'MC'),
    ( 48, 'top_50', 'rest_0305', 'GB'),
    ( 49, 'top_50', 'rest_4200', 'IN'),
    ( 50, 'top_50', 'rest_1376', 'AU'),
    ( 51, 'extended_51_100', 'rest_0325', 'IT'),
    ( 52, 'extended_51_100', 'rest_0326', 'JP'),
    ( 53, 'extended_51_100', 'rest_2730', 'CN'),
    ( 54, 'extended_51_100', 'rest_4201', 'BR'),
    ( 55, 'extended_51_100', 'rest_1369', 'MX'),
    ( 56, 'extended_51_100', 'rest_0502', 'JP'),
    ( 57, 'extended_51_100', 'rest_0476', 'DK'),
    ( 58, 'extended_51_100', 'rest_0321', 'SE'),
    ( 59, 'extended_51_100', 'rest_0310', 'JP'),
    ( 60, 'extended_51_100', 'rest_0424', 'SI'),
    ( 61, 'extended_51_100', 'rest_0319', 'JP'),
    ( 62, 'extended_51_100', 'rest_1375', 'CN'),
    ( 63, 'extended_51_100', 'rest_0837', 'BE'),
    ( 64, 'extended_51_100', 'rest_4202', 'SG'),
    ( 65, 'extended_51_100', 'rest_1385', 'ZA'),
    ( 66, 'extended_51_100', 'rest_0842', 'BE'),
    ( 67, 'extended_51_100', 'rest_0327', 'FR'),
    ( 68, 'extended_51_100', 'rest_1393', 'BR'),
    ( 69, 'extended_51_100', 'rest_0330', 'ES'),
    ( 70, 'extended_51_100', 'rest_0329', 'GB'),
    ( 71, 'extended_51_100', 'rest_1389', 'ZA'),
    ( 72, 'extended_51_100', 'rest_4203', 'KR'),
    ( 73, 'extended_51_100', 'rest_0440', 'MO'),
    ( 74, 'extended_51_100', 'rest_0314', 'TH'),
    ( 75, 'extended_51_100', 'rest_0324', 'PT'),
    ( 76, 'extended_51_100', 'rest_1373', 'DE'),
    ( 77, 'extended_51_100', 'rest_0443', 'HK'),
    ( 78, 'extended_51_100', 'rest_4204', 'KR'),
    ( 79, 'extended_51_100', 'rest_1390', 'MX'),
    ( 80, 'extended_51_100', 'rest_1387', 'ES'),
    ( 81, 'extended_51_100', 'rest_0322', 'FR'),
    ( 82, 'extended_51_100', 'rest_0190', 'DE'),
    ( 83, 'extended_51_100', 'rest_2606', 'GB'),
    ( 84, 'extended_51_100', 'rest_1383', 'FR'),
    ( 85, 'extended_51_100', 'rest_0193', 'DE'),
    ( 86, 'extended_51_100', 'rest_0862', 'BE'),
    ( 87, 'extended_51_100', 'rest_1377', 'MX'),
    ( 88, 'extended_51_100', 'rest_0127', 'AE'),
    ( 89, 'extended_51_100', 'rest_1391', 'SG'),
    ( 90, 'extended_51_100', 'rest_4205', 'TH'),
    ( 91, 'extended_51_100', 'rest_0532', 'JP'),
    ( 92, 'extended_51_100', 'rest_2721', 'CN'),
    ( 93, 'extended_51_100', 'rest_0736', 'US'),
    ( 94, 'extended_51_100', 'rest_0071', 'TR'),
    ( 95, 'extended_51_100', 'rest_1381', 'PE'),
    ( 96, 'extended_51_100', 'rest_0328', 'MX'),
    ( 97, 'extended_51_100', 'rest_4206', 'EG'),
    ( 98, 'extended_51_100', 'rest_1394', 'SG'),
    ( 99, 'extended_51_100', 'rest_4207', 'MX'),
    (100, 'extended_51_100', 'rest_0336', 'ES');

do $$
declare
  n int;
  bad text;
begin
  -- Nothing for 2026 yet, and 2025 No. 94 still empty.
  if exists (select 1 from public.worlds_50_best where year = 2026) then
    raise exception 'worlds_50_best already has 2026 rows; aborting';
  end if;
  if exists (select 1 from public.worlds_50_best where year = 2025 and rank = 94) then
    raise exception '2025 rank 94 already present; aborting';
  end if;

  -- The new restaurants: codes free; MICHELIN URL and 50 Best URL not
  -- already on another row (both UNIQUE); each city resolves to one row.
  select string_agg(n.restaurant_code, ', ') into bad
  from w50b_2026_new n
  join public.restaurants r
    on r.restaurant_code = n.restaurant_code
    or r.michelin_url = n.michelin_url
    or r.worlds_50_best_url = n.worlds_50_best_url;
  if bad is not null then
    raise exception 'new restaurant already present (code / michelin_url / worlds_50_best_url): %', bad;
  end if;
  select string_agg(n.restaurant_code || ' (' || n.country_code || '/' || n.city || ')', ', ') into bad
  from w50b_2026_new n
  where (select count(*) from public.cities c
          where c.country_code = n.country_code and c.name = n.city) <> 1;
  if bad is not null then
    raise exception 'city does not resolve to exactly one row (apply 20261101390000 first?): %', bad;
  end if;

  -- Stage sanity: 100 distinct ranks and codes, list_type consistent.
  select count(*) into n from w50b_2026_stage;
  if n <> 100 then raise exception 'expected 100 staged rows, got %', n; end if;
  if (select count(distinct rank) from w50b_2026_stage) <> 100
     or (select count(distinct restaurant_code) from w50b_2026_stage) <> 100 then
    raise exception 'duplicate rank or restaurant_code in stage';
  end if;
  if exists (select 1 from w50b_2026_stage
             where rank not between 1 and 100
                or (rank <= 50) <> (list_type = 'top_50')
                or list_type not in ('top_50', 'extended_51_100')) then
    raise exception 'rank / list_type mismatch in stage';
  end if;

  -- The 92 existing codes resolve on code + country.
  select count(*) into n
  from w50b_2026_stage s
  join public.restaurants r
    on r.restaurant_code = s.restaurant_code
   and r.country_code = s.country_code;
  if n <> 92 then
    raise exception 'only % of 92 existing staged codes resolve on code + country', n;
  end if;

  if (select count(*) from public.restaurants
      where (restaurant_code, country_code) in (('rest_0134', 'PE'), ('rest_2739', 'CN'))) <> 2 then
    raise exception 'Maido (rest_0134 PE) or Meet the Bund (rest_2739 CN) not found';
  end if;
end $$;

insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
   property_name, address, location, michelin_url, website_url, phone,
   worlds_50_best_url)
select n.restaurant_code, n.name, n.stars, n.inclusion_reason,
       (select c.id from public.cities c
         where c.country_code = n.country_code and c.name = n.city),
       n.country_code, n.property_name, n.address,
       ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)::geography,
       n.michelin_url, n.website_url, n.phone, n.worlds_50_best_url
from w50b_2026_new n;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current)
select 'restaurant', r.id, n.guide_year, 'michelin_stars', n.stars, true
from w50b_2026_new n
join public.restaurants r on r.restaurant_code = n.restaurant_code
where n.stars is not null;

insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
select r.id, 2026, s.rank, s.list_type
from w50b_2026_stage s
join public.restaurants r
  on r.restaurant_code = s.restaurant_code
 and r.country_code = s.country_code;

insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
select r.id, 2026, null, 'hall_of_fame'
from public.restaurants r
where r.restaurant_code = 'rest_0134' and r.country_code = 'PE';

insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
select r.id, 2025, 94, 'extended_51_100'
from public.restaurants r
where r.restaurant_code = 'rest_2739' and r.country_code = 'CN';

-- Post-checks.
do $$
declare
  n int;
begin
  select count(*) into n from public.restaurants where restaurant_code in ('rest_4200', 'rest_4201', 'rest_4202', 'rest_4203', 'rest_4204', 'rest_4205', 'rest_4206', 'rest_4207');
  if n <> 8 then raise exception 'expected 8 new restaurants, got %', n; end if;
  select count(*) into n
  from public.award_history a
  join public.restaurants r on r.id = a.entity_id and a.entity_type = 'restaurant'
  where r.restaurant_code in ('rest_4200', 'rest_4201', 'rest_4202', 'rest_4203', 'rest_4204', 'rest_4205', 'rest_4206', 'rest_4207') and a.is_current;
  if n <> 4 then raise exception 'expected 4 award_history rows for the new restaurants, got %', n; end if;
  select count(*) into n from public.worlds_50_best where year = 2026 and list_type = 'top_50';
  if n <> 50 then raise exception '2026 top_50: expected 50, got %', n; end if;
  select count(*) into n from public.worlds_50_best where year = 2026 and list_type = 'extended_51_100';
  if n <> 50 then raise exception '2026 extended_51_100: expected 50, got %', n; end if;
  select count(*) into n from public.worlds_50_best where year = 2026 and list_type = 'hall_of_fame';
  if n <> 1 then raise exception '2026 hall_of_fame: expected 1, got %', n; end if;
  select count(*) into n from public.worlds_50_best where year = 2025 and rank is not null;
  if n <> 100 then raise exception '2025 ranked: expected 100, got %', n; end if;
  -- The view now treats 2026 as current.
  select count(distinct restaurant_code) into n from public.restaurants_full where worlds_50_best_rank is not null;
  if n <> 100 then raise exception 'restaurants_full current ranks: expected 100, got %', n; end if;
  if (select worlds_50_best_rank from public.restaurants_full
      where restaurant_code = 'rest_0296' and country_code = 'ES') is distinct from 1 then
    raise exception 'Asador Etxebarri (rest_0296 ES) is not current No. 1';
  end if;
  if not (select is_hall_of_fame from public.restaurants_full
          where restaurant_code = 'rest_0134' and country_code = 'PE') then
    raise exception 'Maido is not hall of fame';
  end if;
end $$;

commit;
