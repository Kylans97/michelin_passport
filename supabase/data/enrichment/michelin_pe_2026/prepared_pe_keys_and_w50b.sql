-- PREPARED -- NOT APPLIED.
--
-- Peru: MICHELIN Keys and World's 50 Best, written 2026-10-28.
--
--   1. 14 MICHELIN Key hotels added (hotel_804..hotel_817), each with its
--      current Key row in award_history.
--   2. Palacio Nazarenas (hotel_745, already in production with One Key):
--      the missing current Key row is added, and its michelin_url is set to
--      MICHELIN's current page (the stored one is an /ie/en/ locale variant
--      with an old slug).
--   3. Central (Lima) added as rest_1578, inclusion_reason 'hall_of_fame':
--      No.1 in 2023, now in the Best of the Best. Its ten ranked years and
--      its hall-of-fame row are added to worlds_50_best.
--   4. Mil (rest_1381): its 2024 rank (No.73, 51-100) is added.
--
-- MICHELIN has no starred restaurants in Peru
-- (guide.michelin.com/en/pe/restaurants/all-starred, 2026-10-28: "no selected
-- restaurants"), so there is no star work here.
--
-- Deliberately NOT under supabase/migrations/: catalogue data is applied
-- explicitly after review, never by a db push. Run it as ONE file, e.g.:
--   supabase db query --linked --file prepared_pe_keys_and_w50b.sql
-- It is a single transaction; every check below raises, which rolls the
-- whole file back.
--
-- PREREQUISITE (checked below): the five cities in
-- supabase/migrations/20261019130000_add_pe_key_hotel_cities.sql.
--
-- SOURCES (evidence per row in pe_key_hotels.csv / PE_REPORT.md):
--   - Keys: each hotel's own guide.michelin.com page (structured-data award),
--     cross-checked against the Peru listing's Key filters: 1 x 3 Keys,
--     4 x 2 Keys, 10 x 1 Key = 15, matching exactly.
--   - Hotel address and coordinates: MICHELIN's page. All inside Peru.
--   - Website / phone: the hotel's own site. A phone is set only when
--     MICHELIN's number also appears there (two hotels); NULL otherwise.
--   - Central: the50.com Best of the Best page (contact, phone, address) and
--     previous lists 2013-2024; coordinates from OpenStreetMap's record for
--     Central at Av. Pedro de Osma 301 (no Google Place ID: no API key).
--
-- CODES are fixed. Production's highest codes on 2026-10-28: hotel_803 and
-- rest_1404. rest_1405..rest_1577 are reserved by
-- ../michelin_fr_stars_2026/prepared_fr_stars_2026.sql (not applied yet), so
-- Central takes rest_1578. The guards check the blocks, not the maximum, so
-- the two files can be applied in either order.

begin;

do $$
begin
  if exists (select 1 from public.hotels
              where hotel_code ~ '^hotel_[0-9]+$'
                and substring(hotel_code from 7)::int between 804 and 817) then
    raise exception 'hotel codes hotel_804..hotel_817 are no longer free -- re-check before applying';
  end if;
  if exists (select 1 from public.restaurants where restaurant_code = 'rest_1578') then
    raise exception 'restaurant code rest_1578 is no longer free -- re-check before applying';
  end if;
  if (select count(*) from public.hotels where country_code = 'PE') <> 1 then
    raise exception 'Peru no longer has exactly one hotel (Palacio Nazarenas) -- re-check before applying';
  end if;
  if (select count(distinct guide_year) from public.award_history
       where award_type = 'michelin_keys' and is_current) <> 1 then
    raise exception 'current michelin_keys rows do not share a single guide_year -- decide the year explicitly';
  end if;
  if not exists (select 1 from public.hotels
                  where hotel_code = 'hotel_745' and country_code = 'PE' and michelin_keys = 1) then
    raise exception 'hotel_745 is not Palacio Nazarenas (PE, One Key) any more -- re-check';
  end if;
  if exists (select 1 from public.award_history a join public.hotels h on h.id = a.entity_id
              where h.hotel_code = 'hotel_745' and a.award_type = 'michelin_keys') then
    raise exception 'hotel_745 already has a michelin_keys row -- this file is stale';
  end if;
  if not exists (select 1 from public.restaurants where restaurant_code = 'rest_1381' and country_code = 'PE') then
    raise exception 'rest_1381 is not Mil (PE) -- re-check';
  end if;
  if exists (select 1 from public.worlds_50_best w join public.restaurants r on r.id = w.restaurant_id
              where r.restaurant_code = 'rest_1381' and w.year = 2024) then
    raise exception 'Mil already has a 2024 ranking row -- this file is stale';
  end if;
end $$;

create temp table _new_hotels (
  code text, name text, keys smallint, city text,
  address text, lon float8, lat float8, michelin_url text,
  website_url text, phone text
) on commit drop;

insert into _new_hotels values
    ('hotel_804', 'Las Casitas, A Belmond Hotel', 3::smallint, 'Arequipa', 's/n Fundo La Curiña, Yanque, 04140 Arequipa', -71.677257, -15.661466, 'https://guide.michelin.com/en/hotels-stays/arequipa/las-casitas-a-belmond-hotel-6365', 'https://www.belmond.com/en/hotels/south-america/peru/las-casitas-colca-canyon', NULL),
    ('hotel_805', 'Titilaka by Andean', 2::smallint, 'Lake Titicaca', 'Peninsula Titilaka, Lake Titicaca', -69.736287, -15.902093, 'https://guide.michelin.com/en/hotels-stays/lake-titicaca/titilaka-6368', 'https://andean.travel/titilaka', NULL),
    ('hotel_806', 'CIRQA by Andean', 2::smallint, 'City of Arequipa', '104 C. Sucre, 04001 Arequipa', -71.538504, -16.398409, 'https://guide.michelin.com/en/hotels-stays/city-of-arequipa/cirqa-9418', 'https://andean.travel/cirqa', NULL),
    ('hotel_807', 'Inkaterra Hacienda Urubamba', 2::smallint, 'Sacred Valley', 'Km 63 of the Cusco-Urubamba-Pisac-Calca Highway, Sacred Valley of the Incas', -72.055825, -13.322279, 'https://guide.michelin.com/en/hotels-stays/sacred-valley/inkaterra-hacienda-urubamba-8905', 'https://www.inkaterra.com/inkaterra/inkaterra-hacienda-urubamba/', NULL),
    ('hotel_808', 'Inkaterra La Casona', 2::smallint, 'Cusco', '211 Nazarenas, 08002 Cusco', -71.977454, -13.515191, 'https://guide.michelin.com/en/hotels-stays/cusco/inkaterra-la-casona-6363', 'https://www.inkaterra.com/inkaterra/inkaterra-la-casona/', NULL),
    ('hotel_809', 'Hotel B', 1::smallint, 'Lima', 'Av. Sáenz Peña 204, Barranco, 15063 Lima', -77.023368, -12.143056, 'https://guide.michelin.com/en/hotels-stays/lima/hotel-b-6976', 'https://hotelb.pe/', '+51 1 206 0800'),
    ('hotel_810', 'Atemporal by Andean', 1::smallint, 'Lima', 'Santa Maria 190, Miraflores, 15074 Lima', -77.034365, -12.108597, 'https://guide.michelin.com/en/hotels-stays/lima/atemporal-8473', 'https://andean.travel/atemporal', NULL),
    ('hotel_811', 'Fausto by Andean', 1::smallint, 'Lima', 'Av. de la Aviación 316, 15074 Lima', -77.041262, -12.120543, 'https://guide.michelin.com/en/hotels-stays/lima/fausto-14291', 'https://andean.travel/fausto', NULL),
    ('hotel_812', 'Monasterio, A Belmond Hotel', 1::smallint, 'Cusco', '337 Nazarenas, 08002 Cusco', -71.976909, -13.515285, 'https://guide.michelin.com/en/hotels-stays/cusco/monasterio-a-belmond-hotel-6362', 'https://www.belmond.com/en/hotels/south-america/peru/monasterio-cusco', NULL),
    ('hotel_813', 'Miraflores Park, A Belmond Hotel', 1::smallint, 'Lima', '1035 Mal. de la Reserva, Miraflores, 15074 Lima', -77.027319, -12.135293, 'https://guide.michelin.com/en/hotels-stays/lima/miraflores-park-a-belmond-hotel-6367', 'https://www.belmond.com/en/hotels/south-america/peru/miraflores-park-lima', NULL),
    ('hotel_814', 'Rio Sagrado, A Belmond Hotel', 1::smallint, 'Sacred Valley', 'Km. 75.8, Carretera Urubamba-Ollantaytambo, 08660 Sacred Valley', -72.144941, -13.290561, 'https://guide.michelin.com/en/hotels-stays/sacred-valley/rio-sagrado-a-belmond-hotel-5990', 'https://www.belmond.com/en/hotels/south-america/peru/rio-sagrado-sacred-valley', NULL),
    ('hotel_815', 'Antigua Casona San Blas', 1::smallint, 'Cusco', 'Calle Carmen Bajo 243, 08003 Cusco', -71.973875, -13.515424, 'https://guide.michelin.com/en/hotels-stays/cusco/antigua-casona-san-blas-14521', NULL, NULL),
    ('hotel_816', 'explora Valle Sagrado', 1::smallint, 'Sacred Valley', 'Unnamed Rd, 08670 Sacred Valley', -72.049151, -13.341379, 'https://guide.michelin.com/en/hotels-stays/sacred-valley/explora-valle-sagrado-8975', 'https://www.explora.com/sacred-valley-information-and-services/', '+51 84 300000'),
    ('hotel_817', 'Tambo del Inka', 1::smallint, 'Urubamba', 'Avenida Ferrocarril S/N, Urubamba', -72.11765, -13.31001, 'https://guide.michelin.com/en/hotels-stays/urubamba/tambo-del-inka-11285', NULL, NULL);

-- Central's ranks: the50.com previous lists (2013-2023, top 50) and the
-- Best of the Best page. Induction year 2024 follows production's own rows
-- (Geranium No.1 2022 -> hall_of_fame 2023; Disfrutar No.1 2024 -> 2025).
create temp table _restaurant_ranks (code text, year smallint, rank smallint, list_type text) on commit drop;
insert into _restaurant_ranks values
    ('rest_1578', 2013, 50, 'top_50'),
    ('rest_1578', 2014, 15, 'top_50'),
    ('rest_1578', 2015, 4, 'top_50'),
    ('rest_1578', 2016, 4, 'top_50'),
    ('rest_1578', 2017, 5, 'top_50'),
    ('rest_1578', 2018, 6, 'top_50'),
    ('rest_1578', 2019, 6, 'top_50'),
    ('rest_1578', 2021, 4, 'top_50'),
    ('rest_1578', 2022, 2, 'top_50'),
    ('rest_1578', 2023, 1, 'top_50'),
    ('rest_1578', 2024, NULL, 'hall_of_fame'),
    ('rest_1381', 2024, 73, 'extended_51_100');

-- Every hotel must resolve to exactly one PE city; every MICHELIN URL must be
-- new; every ranked slot must be free.
do $$
declare bad text;
begin
  select string_agg(code || ' (' || city || ')', ', ') into bad
  from _new_hotels v
  where (select count(*) from public.cities c where c.country_code = 'PE' and c.name = v.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one PE row (apply the cities migration first?): %', bad; end if;

  select string_agg(n.code, ', ') into bad from _new_hotels n
  join public.hotels h on h.michelin_url = n.michelin_url;
  if bad is not null then raise exception 'hotel already present by michelin_url: %', bad; end if;

  if exists (select 1 from public.hotels
              where michelin_url = 'https://guide.michelin.com/en/hotels-stays/cusco/palacio-nazarenas-a-belmond-hotel-6409') then
    raise exception 'Palacio Nazarenas canonical michelin_url already used';
  end if;

  select string_agg(k.year || '#' || k.rank, ', ') into bad
  from _restaurant_ranks k join public.worlds_50_best w on w.year = k.year and w.rank = k.rank
  where k.rank is not null;
  if bad is not null then raise exception 'ranking slot already taken: %', bad; end if;
end $$;

insert into public.hotels
  (hotel_code, name, michelin_keys, city_id, country_code,
   address, location, michelin_url, website_url, phone)
select n.code, n.name, n.keys,
       (select c.id from public.cities c where c.country_code = 'PE' and c.name = n.city),
       'PE', n.address,
       ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)::geography,
       n.michelin_url, n.website_url, n.phone
from _new_hotels n;

-- Same guide_year as every current Key row (asserted single-valued above).
insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current)
select 'hotel', h.id,
       (select max(guide_year) from public.award_history
         where award_type = 'michelin_keys' and is_current),
       'michelin_keys', h.michelin_keys, true
from public.hotels h
where h.hotel_code in ('hotel_745','hotel_804','hotel_805','hotel_806','hotel_807',
                       'hotel_808','hotel_809','hotel_810','hotel_811','hotel_812',
                       'hotel_813','hotel_814','hotel_815','hotel_816','hotel_817');

update public.hotels
set michelin_url = 'https://guide.michelin.com/en/hotels-stays/cusco/palacio-nazarenas-a-belmond-hotel-6409'
where hotel_code = 'hotel_745'
  and michelin_url = 'https://guide.michelin.com/ie/en/hotels-stays/cusco/palacio-nazarenas-a-belmond-hotel-cusco-6409';

insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
   address, location, google_place_id, michelin_url, website_url, phone)
values
  ('rest_1578', 'Central', NULL, 'hall_of_fame',
   (select c.id from public.cities c where c.country_code = 'PE' and c.name = 'Lima'),
   'PE', 'Av. Pedro de Osma 301, Barranco, 15063 Lima',
   ST_SetSRID(ST_MakePoint(-77.0225397, -12.1525709), 4326)::geography,
   NULL, NULL, 'https://centralrestaurante.com.pe/', '+51 1 2428515');

insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
select r.id, k.year, k.rank, k.list_type
from _restaurant_ranks k
join public.restaurants r on r.restaurant_code = k.code;

-- Post-conditions.
do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = 'PE' and michelin_keys is not null;
  if n <> 15 then raise exception 'expected 15 PE Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'PE' and michelin_keys = 3;
  if n <> 1 then raise exception 'expected 1 PE three-Key hotel, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'PE' and michelin_keys = 2;
  if n <> 4 then raise exception 'expected 4 PE two-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'PE' and michelin_keys = 1;
  if n <> 10 then raise exception 'expected 10 PE one-Key hotels, found %', n; end if;
  -- every PE Key hotel has exactly one current Key row, agreeing with the hotel row
  select count(*) into n from public.hotels h
  where h.country_code = 'PE'
    and (select count(*) from public.award_history a
          where a.entity_id = h.id and a.award_type = 'michelin_keys' and a.is_current
            and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% PE hotels without exactly one matching current Key row', n; end if;
  select count(*) into n from public.worlds_50_best w join public.restaurants r on r.id = w.restaurant_id
  where r.restaurant_code = 'rest_1578';
  if n <> 11 then raise exception 'expected 11 ranking rows for Central, found %', n; end if;
  select count(*) into n from public.worlds_50_best where list_type = 'hall_of_fame';
  if n <> 7 then raise exception 'expected 7 hall_of_fame rows (6 before + Central), found %', n; end if;
end $$;

commit;
