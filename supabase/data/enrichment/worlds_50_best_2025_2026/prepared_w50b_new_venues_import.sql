-- PREPARED -- NOT APPLIED.
--
-- World's 50 Best catalogue completion, written 2026-10-28: adds the
-- 26 World's 50 Best Restaurants 2025 (51-100) entries and the 22
-- World's 50 Best Hotels 2025/2026 entries that were ranked but missing
-- from the catalogue, with their ranking rows (26 restaurant, 23
-- hotel) and, where MICHELIN confirms one, the matching award_history row.
--
-- Deliberately NOT under supabase/migrations/ (same reason as
-- michelin_netherlands_completion/pre_import/prepared_nl_15_import.sql):
-- catalogue data is applied explicitly after review, never by a db push.
-- Run it as ONE file, e.g.:
--   supabase db query --linked --file prepared_w50b_new_venues_import.sql
-- It is a single transaction; every check below raises, which rolls the
-- whole file back.
--
-- PREREQUISITES (checked below, the file aborts if either is missing):
--   1. supabase/migrations/20261012120000_add_worlds_50_best_countries_and_cities.sql
--   2. supabase/migrations/20261012130000_add_hotel_phone.sql
--
-- SOURCES, all in this folder:
--   - identity (address, coordinates, Google Place ID): the September
--     staging batches in ../worlds_50_best_new_venues/, re-checked against
--     MICHELIN coordinates on 2026-10-28.
--   - stars, Keys, MICHELIN URL, website, phone: restaurants_completion.csv
--     / hotels_completion.csv. Stars and Keys come ONLY from each venue's own
--     guide.michelin.com page; NULL means no confirmed value, never zero.
--   - names and ranks: the official lists (the50.com, rendered 2026-10-28;
--     2025 hotels 51-100 from the official press-release PDF).
--   See W50B_COMPLETION_REPORT.md for the per-venue evidence and every row
--   held back.
--
-- DECISIONS RECORDED HERE (made by the user, 2026-10-28):
--   - Unstarred restaurants ranked 51-100 are in scope (scope rule 2, "on the
--     current World's 50 Best list", read as the full 1-100 list).
--     inclusion_reason = 'worlds_50_best' for them, 'michelin_star' for
--     starred ones.
--   - Hotels without a MICHELIN Key are accepted when ranked (Carlton Cannes,
--     Wynn Palace). michelin_keys stays NULL for them.
--   - Capella Hanoi and Waldorf Astoria Osaka: michelin_keys NULL. MICHELIN's
--     city listings show Key cards (3 / 1) but each hotel's own page is a dead
--     link; filled in once the pages resolve.
--   - Singita: ONE hotel row for the collective 50 Best entry (Sweni +
--     Lebombo, same concession, ~340 m apart), placed at Lebombo, which is
--     the address and website the 50 Best entry uses. Both lodges hold Two
--     Keys, so 2 is true whichever lodge the row stands for. No Place ID (the
--     staged one is Sweni's). The ranking can only belong to one row anyway:
--     worlds_50_best_hotels_year_rank_uidx allows one hotel per rank per year.
--
-- HELD BACK: rest_1392 Meet the Bund (2025 #94). The staged Google record,
-- address and coordinates belong to a different restaurant (M on the Bund,
-- 20 Guangdong Lu); the real venue is at 600 Zhongshan Dong Er Road. Its
-- code is left unused for it.
--
-- CODES are fixed (the staged ones), not computed: production's highest
-- codes were rest_1368 / hotel_781 on 2026-10-28. The first check aborts if
-- any code in this file's restaurant block (rest_1369..1395) is already
-- taken, or if the hotel maximum is no longer hotel_781, so a concurrent
-- addition can never be silently renumbered around.

begin;

do $$
begin
  -- rest_1369..rest_1395 is this file's reserved block (rest_1392 stays
  -- unused for Meet the Bund). Other prepared files take codes above it
  -- (prepared_nl_stars_2026.sql uses rest_1396+), so the guard checks the
  -- block, not the maximum -- the two can be applied in either order.
  if exists (select 1 from public.restaurants
              where restaurant_code ~ '^rest_[0-9]+$'
                and substring(restaurant_code from 6)::int between 1369 and 1395) then
    raise exception 'restaurant codes rest_1369..rest_1395 are no longer free -- re-check before applying';
  end if;
  if (select max(substring(hotel_code from 7)::int) from public.hotels
       where hotel_code ~ '^hotel_[0-9]+$') <> 781 then
    raise exception 'hotels changed since 2026-10-28 (max code is no longer hotel_781) -- re-check before applying';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'hotels' and column_name = 'phone') then
    raise exception 'hotels.phone missing -- apply 20261012130000_add_hotel_phone.sql first';
  end if;
  if not exists (select 1 from public.award_history
                  where award_type = 'michelin_stars' and is_current and guide_year = 2026) then
    raise exception 'no current 2026 michelin_stars rows exist -- the guide_year pattern assumed below does not hold';
  end if;
  if (select count(distinct guide_year) from public.award_history
       where award_type = 'michelin_keys' and is_current) <> 1 then
    raise exception 'current michelin_keys rows do not share a single guide_year -- decide the year explicitly';
  end if;
end $$;

create temp table _new_restaurants (
  code text, name text, stars smallint, country_code text, city text,
  address text, lon float8, lat float8, place_id text, michelin_url text,
  website_url text, phone text
) on commit drop;

insert into _new_restaurants values
    ('rest_1369', 'Alcalde', 1::smallint, 'MX', 'Guadalajara', 'Av. México 2903, Vallarta Nte., 44690 Guadalajara, Jal., Mexico', -103.3897964, 20.6793273, 'ChIJSxhI0W6uKIQRLbizqZhTQuQ', 'https://guide.michelin.com/en/jalisco/guadalajara_2011748/restaurant/alcalde-1243800', 'https://alcalde.com.mx/', '+52 33 3615 7400'),
    ('rest_1370', 'El Chato', NULL::smallint, 'CO', 'Bogotá', 'Cl. 65 #4-76, Chapinero, Alto, Bogotá, Colombia', -74.057071, 4.647952099999999, 'ChIJQclc-kSaP44RJgBygHivOB4', NULL, 'https://www.elchato.co/', '+57 321 9718676'),
    ('rest_1371', 'La Colombe', NULL::smallint, 'ZA', 'Cape Town', 'Silvermist Wine Estate, Main Road, Constantia Nek, Cape Town, 7806, South Africa', 18.4033113, -34.0151706, 'ChIJCWq-g2FCzB0R4RYvykSREW4', NULL, 'https://www.lacolombe.restaurant/la-colombe', '+27 21 794 2390'),
    ('rest_1372', 'Onjium', 1::smallint, 'KR', 'Seoul', 'South Korea, Seoul, Jongno District, Hyoja-ro, 49 4층', 126.9733488, 37.5804867, 'ChIJk5DRDD2jfDURUA4aAk0Frx0', 'https://guide.michelin.com/en/seoul-capital-area/kr-seoul/restaurant/onjium', NULL, '+82 2-6952-0024'),
    ('rest_1373', 'Nobelhart & Schmutzig', 1::smallint, 'DE', 'Berlin', 'Friedrichstraße 218, 10969 Berlin-Bezirk Friedrichshain-Kreuzberg, Germany', 13.3904178, 52.5053369, 'ChIJNdtTjdNRqEcR-n4Xa0Y92G4', 'https://guide.michelin.com/en/berlin-region/berlin/restaurant/nobelhart-schmutzig', 'https://www.nobelhartundschmutzig.com/', '+49 30 25940610'),
    ('rest_1374', 'Nuema', NULL::smallint, 'EC', 'Quito', 'Bello Horizonte E11-12 y, 170517 Quito, Ecuador', -78.4825583, -0.1981897, 'ChIJ8Wv4QnmZ1ZERpY0fkRPP5fE', NULL, 'https://nuema.ec/', '+593 99 250 9160'),
    ('rest_1375', 'Fu He Hui', 2::smallint, 'CN', 'Shanghai', '1037 Yu Yuan Lu, Chang Ning Qu, Shang Hai Shi, China, 200085', 121.4296926, 31.2186213, 'ChIJNZenaONlsjURk5lrxUnMSZU', 'https://guide.michelin.com/en/shanghai-municipality/shanghai/restaurant/fu-he-hui', NULL, '+86 21 3980 9188'),
    ('rest_1376', 'Saint Peter', NULL::smallint, 'AU', 'Sydney', '161 Underwood St, Paddington NSW 2021, Australia', 151.2318567, -33.8863741, 'ChIJ9-UbWgauEmsRa9hUtKIjdN4', NULL, 'https://www.saintpeter.com.au/', '+61 2 9167 3703'),
    ('rest_1377', 'Arca', NULL::smallint, 'MX', 'Tulum', 'Carr. Tulum-Boca Paila km 7.6, Tulum Beach, 77780 Tulum, Q.R., Mexico', -87.45958999999999, 20.1495855, 'ChIJJ-ohbMvQT48RUyLPOYlArC0', 'https://guide.michelin.com/en/quintana-roo/tulum_2069429/restaurant/arca-1208263', 'https://arcatulum.com/', '+52 984 177 2231'),
    ('rest_1378', 'Masque', NULL::smallint, 'IN', 'Mumbai', 'Masque, Unit G3, Shree Laxmi Woollen Mills, Shakti Mills Ln, off Doctor Elijah Moses Road, Mahalakshmi, Mumbai, Maharashtra 400018, India', 72.8256177, 18.9898258, 'ChIJ2RdH8orO5zsR9j_YJgVbG64', NULL, 'https://www.masquerestaurant.com/', '+91 98190 69222'),
    ('rest_1379', 'Tuju', 3::smallint, 'BR', 'São Paulo', 'R. Frei Galvão, 135 - Jardim Paulistano, São Paulo - SP, 01454-060, Brazil', -46.6858278, -23.58046, 'ChIJm2pQ-1dXzpQRLcFNxi6yWeI', 'https://guide.michelin.com/en/sao-paulo-region/sao-paulo/restaurant/tuju', 'https://www.tuju.com.br/', '+55 11 91899-0002'),
    ('rest_1380', 'Mountain', 1::smallint, 'GB', 'London', '16-18 Beak St, London W1F 9RD, UK', -0.1382302, 51.5120181, 'ChIJGXGPYsEFdkgRAIIfSSET698', 'https://guide.michelin.com/en/greater-london/london/restaurant/mountain', 'https://mountainbeakstreet.com/', NULL),
    ('rest_1381', 'Mil', NULL::smallint, 'PE', 'Cusco', 'Vía a Moray, Maras 08655, Peru', -72.1967971, -13.3327468, 'ChIJ44w-0C3DbZERMiSuC6LNweo', NULL, 'https://milcentro.pe/en/', '+51 970 645 908'),
    ('rest_1382', 'Leo', NULL::smallint, 'CO', 'Bogotá', 'Cl. 65 Bis #4-23, Bogotá, Colombia', -74.0564373, 4.648031599999999, 'ChIJf0x6pJuZP44RbF-3kBjiZLs', NULL, 'https://restauranteleo.com/', '+57 317 6616866'),
    ('rest_1383', 'Le Doyenné', NULL::smallint, 'FR', 'Saint-Vrain', '5 Rue Saint-Antoine, 91770 Saint-Vrain, France', 2.3261406, 48.5375511, 'ChIJFddyE7rb5UcRaA53AIRo_gw', 'https://guide.michelin.com/en/ile-de-france/saint-vrain/restaurant/le-doyenne', 'https://ledoyennerestaurant.com/', '+33 1 60 80 00 99'),
    ('rest_1384', 'Oteque', 1::smallint, 'BR', 'Rio de Janeiro', 'Rua Conde de Irajá, 581 - Botafogo, Rio de Janeiro - RJ, 22271-020, Brazil', -43.1943018, -22.9574723, 'ChIJd30eZgB_mQAR-KdRFwN99rE', 'https://guide.michelin.com/en/rio-de-janeiro-region/rio-de-janeiro/restaurant/oteque', 'https://www.oteque.com/', '+55 21 3486-5758'),
    ('rest_1385', 'Fyn', NULL::smallint, 'ZA', 'Cape Town', '5th Floor, Speakers Corner, 37 Parliament St, Cape Town City Centre, Cape Town, 8001, South Africa', 18.4218031, -33.924723, 'ChIJJXjP9dFnzB0RKRtezQrweYM', NULL, 'https://www.fynrestaurant.com/', '+27 21 286 2733'),
    ('rest_1386', 'A Casa do Porco', NULL::smallint, 'BR', 'São Paulo', 'R. Araújo, 124 - República, São Paulo - SP, 01220-020, Brazil', -46.6447336, -23.5449136, 'ChIJK76a5E5YzpQRCoY7nm1M3-k', 'https://guide.michelin.com/en/sao-paulo-region/sao-paulo/restaurant/a-casa-do-porco', 'https://acasadoporco.com.br/', '+55 11 3258-2578'),
    ('rest_1387', 'Txispa', 1::smallint, 'ES', 'Atxondo', 'San Juan Auzoa, 45, 48291 Apatamonasterio, Bizkaia, Spain', -2.6024408, 43.1144957, 'ChIJz-u9dpzTTw0RZHHXvqX4fb8', 'https://guide.michelin.com/en/pais-vasco/axpe/restaurant/txispa', 'https://txispa.com/', '+34 691 71 45 86'),
    ('rest_1388', 'The Clove Club', 2::smallint, 'GB', 'London', 'Shoreditch Town Hall, 380 Old St, London EC1V 9LT, UK', -0.07933849999999999, 51.5270972, 'ChIJkbGoX7ocdkgRgfrpjeC7xzM', 'https://guide.michelin.com/en/greater-london/london/restaurant/the-clove-club', 'https://www.thecloveclub.com/', '+44 20 7729 6496'),
    ('rest_1389', 'Salsify at the Roundhouse', NULL::smallint, 'ZA', 'Cape Town', 'Roundhouse, Round House Rd, Camps Bay, Cape Town, 8040, South Africa', 18.3850138, -33.9435685, 'ChIJL5QxrbpnzB0REZTW-bJD0qA', NULL, 'https://salsify.co.za/', '+27 21 010 6444'),
    ('rest_1390', 'Huniik', 1::smallint, 'MX', 'Mérida', 'C. 60 415-B, entre Calle 45 y Calle 47, Parque Santa Ana, Centro, 97000 Mérida, Yuc., Mexico', -89.62150779999999, 20.9762466, 'ChIJG_gayOp2Vo8R7ZP4TYIkEDc', 'https://guide.michelin.com/en/yucatan/merida_2068208/restaurant/huniik', 'https://www.huniik.com/', '+52 999 912 6244'),
    ('rest_1391', 'Burnt Ends', 1::smallint, 'SG', 'Singapore', '7 Dempsey Rd, #01-02, Singapore 249671', 103.8089925, 1.304606, 'ChIJLZ9DYnIZ2jERQ51Am7WzJLM', 'https://guide.michelin.com/en/singapore-region/singapore/restaurant/burnt-ends-1200777', 'https://burntends.com.sg/', '+65 6224 3933'),
    ('rest_1393', 'Evvai', 3::smallint, 'BR', 'São Paulo', 'R. Joaquim Antunes, 108 - Pinheiros, São Paulo - SP, 05415-000, Brazil', -46.6790581, -23.567081, 'ChIJ15xqwHlXzpQR-wSlgx8ckJM', 'https://guide.michelin.com/en/sao-paulo-region/sao-paulo/restaurant/evvai', 'https://www.evvai.com.br/', '+55 11 3062-1160'),
    ('rest_1394', 'Labyrinth', 1::smallint, 'SG', 'Singapore', '8 Raffles Ave., #02 - 23, Singapore 039802', 103.8562976, 1.2897489, 'ChIJj99Fo3IZ2jERFIUg_m-VhO8', 'https://guide.michelin.com/en/singapore-region/singapore/restaurant/labyrinth', 'https://www.restaurantlabyrinth.com/', '+65 6223 4098'),
    ('rest_1395', 'Amisfield Restaurant', 1::smallint, 'NZ', 'Queenstown', '10 Arrowtown-Lake Hayes Road Lake Hayes, 10 Arrowtown-Lake Hayes Road, Queenstown 9371, New Zealand', 168.8158838, -44.9865689, 'ChIJQw4OaFgf1akRsNbxrHgfmpU', 'https://guide.michelin.com/en/south-island/queenstown_2306160/restaurant/amisfield', 'https://amisfield.co.nz/', '+64 3 442 0556');

create temp table _new_hotels (
  code text, name text, keys smallint, country_code text, city text,
  address text, lon float8, lat float8, place_id text, michelin_url text,
  website_url text, phone text
) on commit drop;

insert into _new_hotels values
    ('hotel_782', 'One&Only Mandarina', 3::smallint, 'MX', 'Lo de Marcos', 'Carretera Federal Libre 200 Tepic-Puerto Vallarta Municipio de Compostela El Monteón, 63724 Nayari, Nay., Mexico', -105.3309758, 20.9778543, 'ChIJxV2Ai0UjIYQR8UGO_35AXXE', 'https://guide.michelin.com/en/hotels-stays/Lo-de-Marcos/oneonly-mandarina-12145', 'https://www.oneandonlyresorts.com/mandarina', '+52 327 689 0100'),
    ('hotel_783', 'The Peninsula Istanbul', 2::smallint, 'TR', 'Istanbul', 'Kemankeş Karamustafa Paşa, Kemankeş Cd. No:34, 34425 Beyoğlu/İstanbul, Türkiye', 28.9779274, 41.0230125, 'ChIJm8vQkZm5yhQRYZFcCnD4NS0', 'https://guide.michelin.com/en/hotels-stays/istanbul/the-peninsula-istanbul-12990', 'https://www.peninsula.com/en/istanbul/5-star-luxury-hotel-bosphorus', '+90 212 931 28 88'),
    ('hotel_784', 'San Domenico Palace', 3::smallint, 'IT', 'Taormina', 'Via S. Domenico, 5, 98039 Taormina ME, Italy', 15.2834895, 37.8502041, 'ChIJDVC2m6QRFBMRpO4vM4lfaAs', 'https://guide.michelin.com/en/hotels-stays/taormina/san-domenico-palace-hotel-7330', 'https://www.fourseasons.com/taormina/', '+39 0942 613111'),
    ('hotel_785', 'Park Hyatt Tokyo', 1::smallint, 'JP', 'Tokyo', '2, 3-chōme-7-1 Nishishinjuku, Shinjuku City, Tokyo 163-1055, Japan', 139.6904828, 35.6862131, 'ChIJJ7La1yzzGGARln2OypSj2Cw', 'https://guide.michelin.com/en/hotels-stays/tokyo/park-hyatt-tokyo-3141', 'https://www.hyatt.com/park-hyatt/en-US/tyoph-park-hyatt-tokyo', '+81 3-5322-1234'),
    ('hotel_786', 'Rosewood London', 2::smallint, 'GB', 'London', '252 High Holborn, London WC1V 7EN, UK', -0.1175009, 51.51737439999999, 'ChIJi-8-gTUbdkgRvgRcAHEwuyc', 'https://guide.michelin.com/en/hotels-stays/london/rosewood-london-7135', 'https://www.rosewoodhotels.com/en/london', '+44 20 7781 8888'),
    ('hotel_787', 'Castiglion del Bosco', 3::smallint, 'IT', 'Montalcino', 'SP103, 53024 Castiglion del Bosco SI, Italy', 11.4222631, 43.0839873, 'ChIJi-QTUe15KRMRL-ZzRTvxbkA', 'https://guide.michelin.com/en/hotels-stays/montalcino/castiglion-del-bosco-a-rosewood-hotel-5137', 'https://www.rosewoodhotels.com/en/castiglion-del-bosco', '+39 0577 141 3001'),
    ('hotel_788', 'Sofitel Legend Casco Viejo', 1::smallint, 'PA', 'Panama City', 'C. 1a Oeste, Panamá, Provincia de Panamá, Panama', -79.53205779999999, 8.951455, 'ChIJr_tNuXuvrI8RnuNWZzAsEiY', 'https://guide.michelin.com/en/hotels-stays/panama-city/sofitel-legend-casco-viejo-13505', 'https://www.sofitel-legend-panama.com/', '+507 302-4300'),
    ('hotel_789', 'Orient Express La Minerva', 2::smallint, 'IT', 'Rome', 'Piazza della Minerva, 69, 00186 Roma RM, Italy', 12.4775802, 41.8977272, 'ChIJJU2bDU5gLxMRfoPUpIkerKU', 'https://guide.michelin.com/en/hotels-stays/rome/orient-express-la-minerva-15216', 'https://www.orient-express.com/en/hotel/europe/italy/rome/la-minerva', '+39 06 9974 8181'),
    ('hotel_790', 'Forestis Dolomites', 2::smallint, 'IT', 'Brixen', 'Palmschoß 22, 39042 Bressanone BZ, Italy', 11.7100308, 46.6757557, 'ChIJUzkj65AQeEcRKXSK0ZN3uS8', 'https://guide.michelin.com/en/hotels-stays/brixen/forestis-dolomites-11259', 'https://www.forestis.it/en', '+39 0472 521008'),
    ('hotel_791', 'Ritz Paris', 3::smallint, 'FR', 'Paris', '15 Pl. Vendôme, 75001 Paris, France', 2.3288932, 48.8680987, 'ChIJVSOS5FBv5kcRmaCCdrMCfk4', 'https://guide.michelin.com/en/hotels-stays/paris/ritz-paris-6008', 'https://www.ritzparis.com/en-GB', '+33 1 43 16 30 30'),
    ('hotel_792', 'Palace Hotel Tokyo', 3::smallint, 'JP', 'Tokyo', '1-chōme-1-1 Marunouchi, Chiyoda City, Tokyo 100-0005, Japan', 139.7612295, 35.6845024, 'ChIJq0s44BuMGGARvBtm78mmRRg', 'https://guide.michelin.com/en/hotels-stays/tokyo/palace-hotel-tokyo-7686', 'https://en.palacehoteltokyo.com/', '+81 3-3211-5211'),
    ('hotel_793', 'Carlton Cannes', NULL::smallint, 'FR', 'Cannes', '58 Bd de la Croisette, 06400 Cannes, France', 7.0272836, 43.54973700000001, 'ChIJZykAMpaBzhIRJkI13XQDqHw', 'https://guide.michelin.com/en/hotels-stays/cannes/carlton-intercontinental-6039', 'https://carltoncannes.com/en/', '+33 4 93 06 40 06'),
    ('hotel_794', 'Capella Hanoi', NULL::smallint, 'VN', 'Hanoi', '11 P. Lê Phụng Hiểu, French Quarter, Hoàn Kiếm, Hà Nội 100000, Vietnam', 105.8566886, 21.0257164, 'ChIJeysLiz2rNTER3KKgUoOxxUQ', NULL, 'https://capellahotels.com/en/capella-hanoi', '+84 24 3987 8888'),
    ('hotel_795', 'Waldorf Astoria Osaka', NULL::smallint, 'JP', 'Osaka', '5-54 Ōfukachō, Kita Ward, Osaka, 530-0011, Japan', 135.4915437, 34.702993, 'ChIJ5YDVAwDnAGARnv2oTYJOmo0', NULL, 'https://www.hilton.com/en/hotels/osawawa-waldorf-astoria-osaka/', NULL),
    ('hotel_796', 'Mandarin Oriental Shenzhen', 2::smallint, 'CN', 'Shenzhen', 'Block A UpperHills No, 5001 Huang Gang Lu, Fu Tian Qu, Shen Zhen Shi, Guang Dong Sheng, China, 518026', 114.0712503, 22.5575267, 'ChIJM2YptGn0AzQR-pilfJW8YTg', 'https://guide.michelin.com/en/hotels-stays/shenzhen/mandarin-oriental-shenzhen-13280', 'https://www.mandarinoriental.com/en/shenzhen/futian', '+86 755 8802 6888'),
    ('hotel_797', 'Villa Treville', 2::smallint, 'IT', 'Positano', 'Via Arienzo, 30, 84017 Positano SA, Italy', 14.496936, 40.62645750000001, 'ChIJi5eLcRaXOxMRqoj0BLPrGyE', 'https://guide.michelin.com/en/hotels-stays/positano/villa-treville-15599', 'https://villatreville.com/', '+39 089 812 2401'),
    ('hotel_798', 'Wynn Palace', NULL::smallint, 'MO', 'Macau', 'Av. da Nave Desportiva, Macao', 113.5714287, 22.1476213, 'ChIJQ0Jd-QJwATQRHok4K_ZwSZA', NULL, 'https://www.wynnresortsmacau.com/en/wynn-palace', '+853 8889 8889'),
    ('hotel_799', 'The Oberoi Udaivilas', 2::smallint, 'IN', 'Udaipur', 'HMGC+VVV, Badi-Gorela-Mulla Talai Rd, Haridas Ji Ki Magri, Pichola, Udaipur, Rajasthan 313004, India', 73.67244120000001, 24.5773827, 'ChIJ8-KpToDPbDkRmn78-WuA6yE', 'https://guide.michelin.com/en/hotels-stays/udaipur/the-oberoi-udaivilas-6148', 'https://www.oberoihotels.com/hotels-in-udaipur-udaivilas-resort/', '+91 294 243 3300'),
    ('hotel_800', 'The Peninsula Shanghai', 2::smallint, 'CN', 'Shanghai', '32 Zhong Shan Dong Yi Lu, Waitan, Huang Pu Qu, China, 200002', 121.4887562, 31.2408079, 'ChIJ3R5OI1FwsjURal2wzq5gbhI', 'https://guide.michelin.com/en/hotels-stays/shanghai/the-peninsula-shanghai-5858', 'https://www.peninsula.com/en/shanghai/5-star-luxury-hotel-bund', '+86 21 2327 2888'),
    ('hotel_801', 'Singita – Kruger National Park', 2::smallint, 'ZA', 'Kruger National Park', 'N''wanetsi River, Kruger National Park, Mpumalanga, 1350', 31.9780821, -24.4520170, NULL, 'https://guide.michelin.com/en/hotels-stays/Mpumalanga-1/singita-lebombo-16240', 'https://singita.com/lodge/singita-lebombo-lodge/', '+27 13 735 1500'),
    ('hotel_802', 'Suján Jawai', 2::smallint, 'IN', 'Bisalpur', 'JAWAI DAM DISTRICT, Pali Marwar, RAJASTHAN, Bisalpur, Rajasthan 306126, India', 73.1950952, 25.09579, 'ChIJIQVz622WQjkRG1jDGixb83o', 'https://guide.michelin.com/en/hotels-stays/Bisalpur/jawai-8223', 'https://thesujanlife.com/sujan-camps/sujan-jawai', '+91 11 4617 2700'),
    ('hotel_803', 'Soneva Secret', 3::smallint, 'MV', 'Dhipparufushi Island', 'Dhipparufushi Island, Kulhudhuffushi 02110, Maldives', 72.64072209999999, 6.3194851, 'ChIJc41ROwBjbDsRGcXQ3SHSG_A', 'https://guide.michelin.com/en/hotels-stays/Dhipparufushi%20Island/soneva-secret-16237', 'https://soneva.com/resorts/soneva-secret/', '+960 660-4300');

create temp table _restaurant_ranks (code text, year smallint, rank smallint, list_type text) on commit drop;
insert into _restaurant_ranks values
    ('rest_1369', 2025, 51, 'extended_51_100'),
    ('rest_1370', 2025, 54, 'extended_51_100'),
    ('rest_1371', 2025, 55, 'extended_51_100'),
    ('rest_1372', 2025, 57, 'extended_51_100'),
    ('rest_1373', 2025, 59, 'extended_51_100'),
    ('rest_1374', 2025, 61, 'extended_51_100'),
    ('rest_1375', 2025, 64, 'extended_51_100'),
    ('rest_1376', 2025, 66, 'extended_51_100'),
    ('rest_1377', 2025, 67, 'extended_51_100'),
    ('rest_1378', 2025, 68, 'extended_51_100'),
    ('rest_1379', 2025, 70, 'extended_51_100'),
    ('rest_1380', 2025, 74, 'extended_51_100'),
    ('rest_1381', 2025, 75, 'extended_51_100'),
    ('rest_1382', 2025, 76, 'extended_51_100'),
    ('rest_1383', 2025, 77, 'extended_51_100'),
    ('rest_1384', 2025, 81, 'extended_51_100'),
    ('rest_1385', 2025, 82, 'extended_51_100'),
    ('rest_1386', 2025, 83, 'extended_51_100'),
    ('rest_1387', 2025, 85, 'extended_51_100'),
    ('rest_1388', 2025, 86, 'extended_51_100'),
    ('rest_1389', 2025, 88, 'extended_51_100'),
    ('rest_1390', 2025, 89, 'extended_51_100'),
    ('rest_1391', 2025, 93, 'extended_51_100'),
    ('rest_1393', 2025, 95, 'extended_51_100'),
    ('rest_1394', 2025, 97, 'extended_51_100'),
    ('rest_1395', 2025, 99, 'extended_51_100');

create temp table _hotel_ranks (code text, year smallint, rank smallint, list_type text) on commit drop;
insert into _hotel_ranks values
    ('hotel_782', 2025, 39, 'top_50'),
    ('hotel_801', 2025, 40, 'top_50'),
    ('hotel_802', 2025, 91, 'extended_51_100'),
    ('hotel_803', 2025, 92, 'extended_51_100'),
    ('hotel_782', 2026, 23, 'top_50'),
    ('hotel_783', 2026, 31, 'top_50'),
    ('hotel_784', 2026, 50, 'top_50'),
    ('hotel_785', 2026, 53, 'extended_51_100'),
    ('hotel_786', 2026, 56, 'extended_51_100'),
    ('hotel_787', 2026, 62, 'extended_51_100'),
    ('hotel_788', 2026, 63, 'extended_51_100'),
    ('hotel_789', 2026, 66, 'extended_51_100'),
    ('hotel_790', 2026, 68, 'extended_51_100'),
    ('hotel_791', 2026, 72, 'extended_51_100'),
    ('hotel_792', 2026, 73, 'extended_51_100'),
    ('hotel_793', 2026, 80, 'extended_51_100'),
    ('hotel_794', 2026, 81, 'extended_51_100'),
    ('hotel_795', 2026, 89, 'extended_51_100'),
    ('hotel_796', 2026, 90, 'extended_51_100'),
    ('hotel_797', 2026, 91, 'extended_51_100'),
    ('hotel_798', 2026, 96, 'extended_51_100'),
    ('hotel_799', 2026, 98, 'extended_51_100'),
    ('hotel_800', 2026, 99, 'extended_51_100');

-- Every venue must resolve to exactly one existing city; every code, Place ID
-- and MICHELIN URL must be new (all three are UNIQUE).
do $$
declare bad text;
begin
  select string_agg(code || ' (' || country_code || '/' || city || ')', ', ') into bad
  from (select code, country_code, city from _new_restaurants
        union all select code, country_code, city from _new_hotels) v
  where (select count(*) from public.cities c
          where c.country_code = v.country_code and c.name = v.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one row: %', bad; end if;

  select string_agg(n.code, ', ') into bad from _new_restaurants n
  join public.restaurants r on r.restaurant_code = n.code or r.google_place_id = n.place_id or r.michelin_url = n.michelin_url;
  if bad is not null then raise exception 'restaurant already present (code/place id/michelin url): %', bad; end if;

  select string_agg(n.code, ', ') into bad from _new_hotels n
  join public.hotels h on h.hotel_code = n.code or h.google_place_id = n.place_id or h.michelin_url = n.michelin_url;
  if bad is not null then raise exception 'hotel already present (code/place id/michelin url): %', bad; end if;
end $$;

insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
   address, location, google_place_id, michelin_url, website_url, phone)
select n.code, n.name, n.stars,
       case when n.stars is null then 'worlds_50_best' else 'michelin_star' end,
       (select c.id from public.cities c where c.country_code = n.country_code and c.name = n.city),
       n.country_code, n.address,
       ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)::geography,
       n.place_id, n.michelin_url, n.website_url, n.phone
from _new_restaurants n;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current)
select 'restaurant', r.id, 2026, 'michelin_stars', n.stars, true
from _new_restaurants n
join public.restaurants r on r.restaurant_code = n.code
where n.stars is not null;

insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
select r.id, k.year, k.rank, k.list_type
from _restaurant_ranks k
join public.restaurants r on r.restaurant_code = k.code;

insert into public.hotels
  (hotel_code, name, michelin_keys, city_id, country_code,
   address, location, google_place_id, michelin_url, website_url, phone)
select n.code, n.name, n.keys,
       (select c.id from public.cities c where c.country_code = n.country_code and c.name = n.city),
       n.country_code, n.address,
       ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)::geography,
       n.place_id, n.michelin_url, n.website_url, n.phone
from _new_hotels n;

-- Same guide_year as every current Key row (asserted single-valued above).
insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current)
select 'hotel', h.id,
       (select max(guide_year) from public.award_history
         where award_type = 'michelin_keys' and is_current),
       'michelin_keys', n.keys, true
from _new_hotels n
join public.hotels h on h.hotel_code = n.code
where n.keys is not null;

insert into public.worlds_50_best_hotels (hotel_id, year, rank, list_type)
select h.id, k.year, k.rank, k.list_type
from _hotel_ranks k
join public.hotels h on h.hotel_code = k.code;

-- Post-conditions: the lists are complete except for the one held-back row.
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where restaurant_code in ('rest_1369','rest_1370','rest_1371','rest_1372','rest_1373','rest_1374','rest_1375','rest_1376','rest_1377','rest_1378','rest_1379','rest_1380','rest_1381','rest_1382','rest_1383','rest_1384','rest_1385','rest_1386','rest_1387','rest_1388','rest_1389','rest_1390','rest_1391','rest_1393','rest_1394','rest_1395');
  if n <> 26 then raise exception 'expected 26 new restaurants, found %', n; end if;
  select count(*) into n from public.hotels where hotel_code in ('hotel_782','hotel_783','hotel_784','hotel_785','hotel_786','hotel_787','hotel_788','hotel_789','hotel_790','hotel_791','hotel_792','hotel_793','hotel_794','hotel_795','hotel_796','hotel_797','hotel_798','hotel_799','hotel_800','hotel_801','hotel_802','hotel_803');
  if n <> 22 then raise exception 'expected 22 new hotels, found %', n; end if;
  select count(*) into n from public.worlds_50_best where year = 2025 and rank is not null;
  if n <> 99 then raise exception 'restaurants 2025: expected 99 ranked rows (100 minus Meet the Bund), found %', n; end if;
  select count(*) into n from public.worlds_50_best_hotels where year = 2025;
  if n <> 100 then raise exception 'hotels 2025: expected 100 rows, found %', n; end if;
  select count(*) into n from public.worlds_50_best_hotels where year = 2026;
  if n <> 100 then raise exception 'hotels 2026: expected 100 rows, found %', n; end if;
end $$;

commit;
