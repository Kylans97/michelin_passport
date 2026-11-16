-- PREPARED -- NOT APPLIED.
--
-- The 50 Best Restaurants 2026 (announced 2026-11-05, Lima), written
-- 2026-11-16. Adds, to public.worlds_50_best only:
--   * 92 ranked rows for year 2026 (49 top_50, 43 extended_51_100) --
--     every 2026 entry that already has a catalogue row;
--   * 1 hall_of_fame row for 2026: Maido (rest_0134, PE), 2025's No. 1,
--     which joined "Best of the Best" and is no longer eligible;
--   * 1 ranked row for 2025: No. 94 Meet the Bund (rest_2739, CN), the
--     gap left by QA-194 (held back 2026-10-28 because the staged record
--     was the wrong restaurant; the row now in the catalogue was added by
--     the MICHELIN China pass and its address equals the 50 Best page's).
--
-- NOT included: the 8 ranked 2026 entries with no catalogue row (49 Naar,
-- 54 Nelita, 64 Seroja, 72 Eatanic Garden, 78 Mosu, 90 Baan Tepa,
-- 97 Khufu's, 99 Fauna) -- QA-473. They need a full identity pass
-- (address, coordinates, Place ID, city) before they can be added.
--
-- Catalogue data, applied explicitly after review, never by a db push:
--   supabase db query --linked --file prepared_w50b_2026_import.sql
-- One transaction; every check raises, which rolls the whole file back.
--
-- Keys: restaurant_code + country_code, never name. Each row's source URL
-- and match basis are in w50b_2026_matches.csv; the official capture is
-- _source/official_restaurants_2026_1-100.csv. See W50B_2026_REPORT.md.
--
-- Effect on reads: restaurants_full.worlds_50_best_rank joins the year
-- max(year) where rank is not null, so 2026 becomes the current year as
-- soon as this commits; restaurants not on the 2026 list stop showing a
-- current rank (their history rows stay). is_hall_of_fame is true for any
-- restaurant with a hall_of_fame row, so Maido gains it.

begin;

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
    ( 50, 'top_50', 'rest_1376', 'AU'),
    ( 51, 'extended_51_100', 'rest_0325', 'IT'),
    ( 52, 'extended_51_100', 'rest_0326', 'JP'),
    ( 53, 'extended_51_100', 'rest_2730', 'CN'),
    ( 55, 'extended_51_100', 'rest_1369', 'MX'),
    ( 56, 'extended_51_100', 'rest_0502', 'JP'),
    ( 57, 'extended_51_100', 'rest_0476', 'DK'),
    ( 58, 'extended_51_100', 'rest_0321', 'SE'),
    ( 59, 'extended_51_100', 'rest_0310', 'JP'),
    ( 60, 'extended_51_100', 'rest_0424', 'SI'),
    ( 61, 'extended_51_100', 'rest_0319', 'JP'),
    ( 62, 'extended_51_100', 'rest_1375', 'CN'),
    ( 63, 'extended_51_100', 'rest_0837', 'BE'),
    ( 65, 'extended_51_100', 'rest_1385', 'ZA'),
    ( 66, 'extended_51_100', 'rest_0842', 'BE'),
    ( 67, 'extended_51_100', 'rest_0327', 'FR'),
    ( 68, 'extended_51_100', 'rest_1393', 'BR'),
    ( 69, 'extended_51_100', 'rest_0330', 'ES'),
    ( 70, 'extended_51_100', 'rest_0329', 'GB'),
    ( 71, 'extended_51_100', 'rest_1389', 'ZA'),
    ( 73, 'extended_51_100', 'rest_0440', 'MO'),
    ( 74, 'extended_51_100', 'rest_0314', 'TH'),
    ( 75, 'extended_51_100', 'rest_0324', 'PT'),
    ( 76, 'extended_51_100', 'rest_1373', 'DE'),
    ( 77, 'extended_51_100', 'rest_0443', 'HK'),
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
    ( 91, 'extended_51_100', 'rest_0532', 'JP'),
    ( 92, 'extended_51_100', 'rest_2721', 'CN'),
    ( 93, 'extended_51_100', 'rest_0736', 'US'),
    ( 94, 'extended_51_100', 'rest_0071', 'TR'),
    ( 95, 'extended_51_100', 'rest_1381', 'PE'),
    ( 96, 'extended_51_100', 'rest_0328', 'MX'),
    ( 98, 'extended_51_100', 'rest_1394', 'SG'),
    (100, 'extended_51_100', 'rest_0336', 'ES');

do $$
declare
  n int;
begin
  -- Guard: nothing for 2026 yet, and 2025 No. 94 still empty.
  if exists (select 1 from public.worlds_50_best where year = 2026) then
    raise exception 'worlds_50_best already has 2026 rows; aborting';
  end if;
  if exists (select 1 from public.worlds_50_best where year = 2025 and rank = 94) then
    raise exception '2025 rank 94 already present; aborting';
  end if;

  -- Stage sanity: 92 distinct ranks and codes, ranks in 1..100,
  -- list_type consistent with rank.
  select count(*) into n from w50b_2026_stage;
  if n <> 92 then raise exception 'expected 92 staged rows, got %', n; end if;
  if (select count(distinct rank) from w50b_2026_stage) <> 92
     or (select count(distinct restaurant_code) from w50b_2026_stage) <> 92 then
    raise exception 'duplicate rank or restaurant_code in stage';
  end if;
  if exists (select 1 from w50b_2026_stage
             where rank not between 1 and 100
                or (rank <= 50) <> (list_type = 'top_50')
                or list_type not in ('top_50', 'extended_51_100')) then
    raise exception 'rank / list_type mismatch in stage';
  end if;

  -- Every staged code resolves to exactly one restaurant in the stated
  -- country.
  select count(*) into n
  from w50b_2026_stage s
  join public.restaurants r
    on r.restaurant_code = s.restaurant_code
   and r.country_code = s.country_code;
  if n <> 92 then
    raise exception 'only % of 92 staged codes resolve on code + country', n;
  end if;

  -- Maido and Meet the Bund resolve on code + country.
  if (select count(*) from public.restaurants
      where (restaurant_code, country_code) in (('rest_0134', 'PE'), ('rest_2739', 'CN'))) <> 2 then
    raise exception 'Maido (rest_0134 PE) or Meet the Bund (rest_2739 CN) not found';
  end if;
end $$;

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
  select count(*) into n from public.worlds_50_best where year = 2026 and list_type = 'top_50';
  if n <> 49 then raise exception '2026 top_50: expected 49, got %', n; end if;
  select count(*) into n from public.worlds_50_best where year = 2026 and list_type = 'extended_51_100';
  if n <> 43 then raise exception '2026 extended_51_100: expected 43, got %', n; end if;
  select count(*) into n from public.worlds_50_best where year = 2026 and list_type = 'hall_of_fame';
  if n <> 1 then raise exception '2026 hall_of_fame: expected 1, got %', n; end if;
  select count(*) into n from public.worlds_50_best where year = 2025 and rank is not null;
  if n <> 100 then raise exception '2025 ranked: expected 100, got %', n; end if;
  -- The view now treats 2026 as current.
  select count(distinct restaurant_code) into n from public.restaurants_full where worlds_50_best_rank is not null;
  if n <> 92 then raise exception 'restaurants_full current ranks: expected 92, got %', n; end if;
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
