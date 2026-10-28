-- PREPARED -- NOT APPLIED.
--
-- Google Place IDs for the queue in README.md, written 2026-10-28.
-- Input: the production export of README Step 1 (90 rows: 75 World's 50
-- Best ranked hotels, 15 NL restaurants) plus hotel_801 Singita from
-- ../worlds_50_best_2025_2026/prepared_w50b_new_venues_import.sql.
-- Evidence per row: placeid_results.csv (Places API (New) searchText,
-- distance measured against the stored coordinates). Summary: RESULTS.md.
--
-- Only `confirmed` rows: 73 hotels + 14 restaurants in Step 1, Singita
-- in Step 3. Most are under 100 m with the right record type. Exceptions,
-- each double-checked against the venue's own site and OpenStreetMap and
-- explained per row in placeid_results.csv:
--   hotel_693 Cipriani (130 m), hotel_727 Desa Potato Head (101 m),
--   hotel_760 Jumeirah Marsa Al Arab (140 m) -- both points on the same
--     property; hotel_748 Amangalla (496 m) -- OUR coordinates are wrong, fixed in Step 2;
--   rest_0784/0789/0790/0791 -- Google's only record is a combined
--     hotel-restaurant listing; accepted on the owner's instruction.
-- Left out: hotel_704 (mainland China), rest_0781 Graphite (no Google
-- record; QA-210), hotel_744 Six Senses Zighy Bay (Google pin 1.57 km off; see the
-- commented-out optional block at the end).
--
-- Fills only empty values (`google_place_id is null`) -- never overwrites;
-- a row that already holds a different ID is reported (NOTICE) and left.
-- Aborts on an unknown code, or on an ID already held by another row in
-- the same table (google_place_id is UNIQUE per table). Cross-table sharing
-- with a restaurant row is allowed by design and not checked.
--
-- Steps 1-3 are separate transactions. Step 2 corrects Amangalla's stored
-- coordinates (QA-209). Step 3 (Singita) aborts by design until hotel_801
-- exists in production, so it is last.

-- ============================================================
-- Step 1
-- ============================================================
begin;

-- Identity guard (added 2026-10-28): every code below must still be the
-- row exported from production for this queue (same country, same name).
-- Codes are stable, but a guard costs nothing and stops a file written
-- against one export from landing on a different row.
create temp table _expect (tbl text, code text, country text, name text, primary key (tbl, code)) on commit drop;
insert into _expect values
    ('hotels', 'hotel_688', 'JP', 'Aman Tokyo'),
    ('hotels', 'hotel_689', 'IT', 'Borgo Santandrea'),
    ('hotels', 'hotel_690', 'IT', 'Bulgari Roma'),
    ('hotels', 'hotel_691', 'IT', 'Four Seasons Firenze'),
    ('hotels', 'hotel_692', 'JP', 'Hoshinoya Tokyo'),
    ('hotels', 'hotel_693', 'IT', 'Hotel Cipriani'),
    ('hotels', 'hotel_694', 'IT', 'Hotel Il Pellicano'),
    ('hotels', 'hotel_695', 'BR', 'Hotel das Cataratas'),
    ('hotels', 'hotel_696', 'IT', 'Passalacqua'),
    ('hotels', 'hotel_697', 'BR', 'Rosewood São Paulo'),
    ('hotels', 'hotel_699', 'JP', 'The Tokyo Edition Toranomon'),
    ('hotels', 'hotel_700', 'AU', 'Capella Sydney'),
    ('hotels', 'hotel_701', 'AU', 'Southern Ocean Lodge'),
    ('hotels', 'hotel_702', 'AU', 'The Calile'),
    ('hotels', 'hotel_704', 'CN', 'Mandarin Oriental Qianmen'),
    ('hotels', 'hotel_705', 'MX', 'Four Seasons Tamarindo'),
    ('hotels', 'hotel_707', 'FR', 'Cheval Blanc Paris'),
    ('hotels', 'hotel_708', 'FR', 'Hôtel de Crillon'),
    ('hotels', 'hotel_709', 'FR', 'Hôtel du Cap-Eden-Roc'),
    ('hotels', 'hotel_710', 'FR', 'Hôtel du Couvent'),
    ('hotels', 'hotel_711', 'FR', 'La Réserve Paris'),
    ('hotels', 'hotel_712', 'FR', 'Le Bristol Paris'),
    ('hotels', 'hotel_713', 'FR', 'Plaza Athénée'),
    ('hotels', 'hotel_714', 'FR', 'The Maybourne Riviera'),
    ('hotels', 'hotel_716', 'GR', 'Four Seasons Astir Palace Hotel Athens'),
    ('hotels', 'hotel_717', 'HK', 'Four Seasons Hong Kong'),
    ('hotels', 'hotel_718', 'HK', 'Mandarin Oriental Hong Kong'),
    ('hotels', 'hotel_719', 'HK', 'Rosewood Hong Kong'),
    ('hotels', 'hotel_720', 'HK', 'The Peninsula Hong Kong'),
    ('hotels', 'hotel_721', 'HK', 'Upper House Hong Kong'),
    ('hotels', 'hotel_722', 'IN', 'Amanbagh'),
    ('hotels', 'hotel_724', 'IN', 'The Johri'),
    ('hotels', 'hotel_726', 'IN', 'The Taj Mahal Palace'),
    ('hotels', 'hotel_727', 'ID', 'Desa Potato Head'),
    ('hotels', 'hotel_728', 'ID', 'Mandapa'),
    ('hotels', 'hotel_729', 'ID', 'Nihi Sumba'),
    ('hotels', 'hotel_730', 'MY', 'The Datai'),
    ('hotels', 'hotel_731', 'MV', 'Soneva Fushi'),
    ('hotels', 'hotel_734', 'MX', 'Chablé Yucatán'),
    ('hotels', 'hotel_735', 'MX', 'Hotel Esencia'),
    ('hotels', 'hotel_736', 'MX', 'Las Ventanas al Paraíso'),
    ('hotels', 'hotel_737', 'MX', 'Maroma'),
    ('hotels', 'hotel_738', 'MX', 'Montage Los Cabos'),
    ('hotels', 'hotel_740', 'MX', 'Rosewood Mayakoba'),
    ('hotels', 'hotel_741', 'MA', 'La Mamounia'),
    ('hotels', 'hotel_742', 'MA', 'Royal Mansour'),
    ('hotels', 'hotel_743', 'NZ', 'Huka Lodge'),
    ('hotels', 'hotel_744', 'OM', 'Six Senses Zighy Bay'),
    ('hotels', 'hotel_745', 'PE', 'Palacio Nazarenas'),
    ('hotels', 'hotel_746', 'ZA', 'Mount Nelson'),
    ('hotels', 'hotel_748', 'LK', 'Amangalla'),
    ('hotels', 'hotel_749', 'BL', 'Eden Rock'),
    ('hotels', 'hotel_750', 'SE', 'Ett Hem'),
    ('hotels', 'hotel_751', 'TH', 'Aman Nai Lert'),
    ('hotels', 'hotel_752', 'TH', 'Capella Bangkok'),
    ('hotels', 'hotel_754', 'TH', 'Four Seasons Bangkok at Chao Phraya River'),
    ('hotels', 'hotel_755', 'TH', 'Mandarin Oriental Bangkok'),
    ('hotels', 'hotel_756', 'TH', 'Rosewood Bangkok'),
    ('hotels', 'hotel_757', 'TH', 'The Siam'),
    ('hotels', 'hotel_758', 'TR', 'Maçakızı'),
    ('hotels', 'hotel_759', 'AE', 'Atlantis The Royal'),
    ('hotels', 'hotel_760', 'AE', 'Jumeirah Marsa Al Arab'),
    ('hotels', 'hotel_761', 'AE', 'The Lana'),
    ('hotels', 'hotel_762', 'GB', 'Claridge''s'),
    ('hotels', 'hotel_763', 'GB', 'Estelle Manor'),
    ('hotels', 'hotel_764', 'GB', 'Gleneagles'),
    ('hotels', 'hotel_766', 'GB', 'Raffles London at The OWO'),
    ('hotels', 'hotel_767', 'GB', 'The Connaught'),
    ('hotels', 'hotel_768', 'GB', 'The Emory'),
    ('hotels', 'hotel_771', 'US', 'Aman New York'),
    ('hotels', 'hotel_774', 'US', 'Four Seasons at The Surf Club'),
    ('hotels', 'hotel_776', 'US', 'San Ysidro Ranch'),
    ('hotels', 'hotel_779', 'US', 'The Fifth Avenue Hotel'),
    ('hotels', 'hotel_780', 'US', 'The Greenwich Hotel'),
    ('hotels', 'hotel_781', 'US', 'The Mark'),
    ('restaurants', 'rest_0780', 'NL', 'Basiliek'),
    ('restaurants', 'rest_0781', 'NL', 'Graphite by Peter Gast'),
    ('restaurants', 'rest_0782', 'NL', 'Zheng'),
    ('restaurants', 'rest_0783', 'NL', 'Daalder'),
    ('restaurants', 'rest_0784', 'NL', 'Merlet'),
    ('restaurants', 'rest_0785', 'NL', 'Latour'),
    ('restaurants', 'rest_0786', 'NL', 'Restaurant Smink'),
    ('restaurants', 'rest_0787', 'NL', 'De Vlindertuin'),
    ('restaurants', 'rest_0788', 'NL', 'De Woage'),
    ('restaurants', 'rest_0789', 'NL', 'De Swarte Ruijter'),
    ('restaurants', 'rest_0790', 'NL', '''t Lansink'),
    ('restaurants', 'rest_0791', 'NL', 'De Bloemenbeek'),
    ('restaurants', 'rest_0792', 'NL', 'De Gieser Wildeman'),
    ('restaurants', 'rest_0793', 'NL', 'De Moerbei'),
    ('restaurants', 'rest_0794', 'NL', 'Bij Jef');

do $$
declare bad text;
begin
  select string_agg(e.code, ', ') into bad from _expect e
   where e.tbl = 'hotels' and not exists (select 1 from public.hotels h
          where h.hotel_code = e.code and h.country_code = e.country and h.name = e.name);
  if bad is not null then raise exception 'hotels: code is not the exported row (country/name changed): %', bad; end if;
  select string_agg(e.code, ', ') into bad from _expect e
   where e.tbl = 'restaurants' and not exists (select 1 from public.restaurants r
          where r.restaurant_code = e.code and r.country_code = e.country and r.name = e.name);
  if bad is not null then raise exception 'restaurants: code is not the exported row (country/name changed): %', bad; end if;
end $$;

create temp table _pid_hotels (code text primary key, place_id text not null unique) on commit drop;
insert into _pid_hotels values
    ('hotel_688', 'ChIJfV9KdPiLGGARn4ma2GUEoJo'),  -- 19 m, Aman Tokyo
    ('hotel_689', 'ChIJTWWjar-VOxMRzRDEH_NRrrs'),  -- 0 m, Borgo Santandrea
    ('hotel_690', 'ChIJ-XKhYh9hLxMR6SM6GuN3HM4'),  -- 22 m, Bulgari Roma
    ('hotel_691', 'ChIJeQnHJxBUKhMRqEIwEupVmuk'),  -- 15 m, Four Seasons Firenze
    ('hotel_692', 'ChIJQ3xyRgaMGGARUS7IVQTZRQY'),  -- 17 m, Hoshinoya Tokyo
    ('hotel_693', 'ChIJ0U-xZiqufkcRAVmQKP082-Y'),  -- 130 m, Hotel Cipriani
    ('hotel_694', 'ChIJ-adrLpFcKBMRez6Ri5tz168'),  -- 18 m, Hotel Il Pellicano
    ('hotel_695', 'ChIJWZUzp3jq9pQRaUqL9AJx9Fg'),  -- 20 m, Hotel das Cataratas
    ('hotel_696', 'ChIJ4-TBnmknhEcRu-kvLumZm4Y'),  -- 45 m, Passalacqua
    ('hotel_697', 'ChIJsbAShclZzpQRiiYQjjaTjIA'),  -- 56 m, Rosewood São Paulo
    ('hotel_699', 'ChIJwxqh7qyLGGARp01W6wdogZI'),  -- 83 m, The Tokyo Edition Toranomon
    ('hotel_700', 'ChIJ9Zcet0ivEmsRgInM0K7in-Q'),  -- 35 m, Capella Sydney
    ('hotel_701', 'ChIJRX0wR-cprWoRoivPUwnAfBE'),  -- 81 m, Southern Ocean Lodge
    ('hotel_702', 'ChIJAf1SvqVZkWsRIi9YGehg2ME'),  -- 49 m, The Calile
    ('hotel_705', 'ChIJ82O4cOC9JIQRxqtfEPP391M'),  -- 65 m, Four Seasons Tamarindo
    ('hotel_707', 'ChIJE6y1dkBv5kcRhZB0rsUidCQ'),  -- 11 m, Cheval Blanc Paris
    ('hotel_708', 'ChIJC_jkvdJv5kcRqjbmf7Zql3s'),  -- 44 m, Hôtel de Crillon
    ('hotel_709', 'ChIJgUQSbb1_zhIRaXQjX38vUD8'),  -- 12 m, Hôtel du Cap-Eden-Roc
    ('hotel_710', 'ChIJfUqOdgXPzRIR-8aYHCo-Qxw'),  -- 11 m, Hôtel du Couvent
    ('hotel_711', 'ChIJA1PHDM9v5kcRMUeBLlUu4HA'),  -- 6 m, La Réserve Paris
    ('hotel_712', 'ChIJVeUHqupv5kcR4taEicvH7ww'),  -- 22 m, Le Bristol Paris
    ('hotel_713', 'ChIJkd-uh8pv5kcRe9TvkndT36Y'),  -- 39 m, Plaza Athénée
    ('hotel_714', 'ChIJv521BnPCzRIRRR1__gpUMVM'),  -- 61 m, The Maybourne Riviera
    ('hotel_716', 'ChIJKwqn-87roRQRo5RKNIcMG64'),  -- 6 m, Four Seasons Astir Palace Hotel Athens
    ('hotel_717', 'ChIJzbDWTWIABDQR_WNi3VDdv-U'),  -- 48 m, Four Seasons Hong Kong
    ('hotel_718', 'ChIJuY8iZWQABDQR81RwhbR5TXE'),  -- 5 m, Mandarin Oriental Hong Kong
    ('hotel_719', 'ChIJ4cj9uvEABDQRn5SxnnZaBi0'),  -- 31 m, Rosewood Hong Kong
    ('hotel_720', 'ChIJdRlVSfIABDQRq5S65hPQo-8'),  -- 8 m, The Peninsula Hong Kong
    ('hotel_721', 'ChIJDVW9tmcABDQRamXo3aZeQlw'),  -- 5 m, Upper House Hong Kong
    ('hotel_722', 'ChIJkYZj_SyDbTkR7voZS5otyPM'),  -- 84 m, Amanbagh
    ('hotel_724', 'ChIJlyF9yTa3bTkROi8TUsAfzaE'),  -- 0 m, The Johri
    ('hotel_726', 'ChIJ____b8DR5zsRVz_XpIUEKcA'),  -- 20 m, The Taj Mahal Palace
    ('hotel_727', 'ChIJ4f9QNY9H0i0REbMfgG5iI18'),  -- 101 m, Desa Potato Head
    ('hotel_728', 'ChIJI_3sXcMi0i0RLXYUYYo7eT4'),  -- 27 m, Mandapa
    ('hotel_729', 'ChIJ3_Tt_a-dTCwRCqPx7ZsYgSs'),  -- 0 m, Nihi Sumba
    ('hotel_730', 'ChIJWXZGfiJxTDAR84FmKVf47oI'),  -- 29 m, The Datai
    ('hotel_731', 'ChIJG5c3NkV-PzsRCoaG5GwkxPQ'),  -- 76 m, Soneva Fushi
    ('hotel_734', 'ChIJmxz8vjUYVo8RM54REwRBoZc'),  -- 0 m, Chablé Yucatán
    ('hotel_735', 'ChIJee1qZv8rTI8R-T_IOBbLXpI'),  -- 0 m, Hotel Esencia
    ('hotel_736', 'ChIJB2OaS2Jar4YRBfY2bc9HeNI'),  -- 85 m, Las Ventanas al Paraíso
    ('hotel_737', 'ChIJuw7x5fu3m4YRrkFGdr0zO8U'),  -- 11 m, Maroma
    ('hotel_738', 'ChIJBZTif0hMr4YRJPckXqL9nZg'),  -- 0 m, Montage Los Cabos
    ('hotel_740', 'ChIJq6qq2oFnTo8R9K9YLrZaX_8'),  -- 0 m, Rosewood Mayakoba
    ('hotel_741', 'ChIJr1XKb3L3rw0RV8kmfw6rZeY'),  -- 16 m, La Mamounia
    ('hotel_742', 'ChIJyx6ijl7urw0RJmV3ZuinO5o'),  -- 12 m, Royal Mansour
    ('hotel_743', 'ChIJU41t9Vz3a20R3-cXhoaaX1o'),  -- 79 m, Huka Lodge
    ('hotel_745', 'ChIJUdl-FnPWbZERCN5OJ4PGa7o'),  -- 45 m, Palacio Nazarenas
    ('hotel_746', 'ChIJ2ZmgHnFnzB0RObLO5XspkIw'),  -- 4 m, Mount Nelson
    ('hotel_748', 'ChIJmyNMRrtz4ToR1N8_DiW-ckU'),  -- 496 m, Amangalla
    ('hotel_749', 'ChIJaSlfs091DowRpAapQXu2czo'),  -- 42 m, Eden Rock
    ('hotel_750', 'ChIJ5dbUPWqdX0YRmE5enY3QHQk'),  -- 0 m, Ett Hem
    ('hotel_751', 'ChIJJ2BaV9if4jARiNLkIi1g87I'),  -- 67 m, Aman Nai Lert
    ('hotel_752', 'ChIJqcNXkyaZ4jAR6PgpLK1RNzI'),  -- 24 m, Capella Bangkok
    ('hotel_754', 'ChIJgf1Rnb-Y4jARaZXmSa-m7sU'),  -- 82 m, Four Seasons Bangkok at Chao Phraya River
    ('hotel_755', 'ChIJs6CnycSY4jAR5cqJZjPOsgs'),  -- 35 m, Mandarin Oriental Bangkok
    ('hotel_756', 'ChIJJUys49ye4jAR-TlV_Qsxx3Y'),  -- 86 m, Rosewood Bangkok
    ('hotel_757', 'ChIJbw__g9-b4jAR3iYpzC9gRoI'),  -- 74 m, The Siam
    ('hotel_758', 'ChIJybTpQuxvvhQRvHMQvLA1YMk'),  -- 0 m, Maçakızı
    ('hotel_759', 'ChIJyTL-aggVXz4R4cAwRc0Ydsw'),  -- 93 m, Atlantis The Royal
    ('hotel_760', 'ChIJ7yNA5vtrXz4RHHx0-yTRgJk'),  -- 140 m, Jumeirah Marsa Al Arab
    ('hotel_761', 'ChIJiyZtnNlpXz4Rmopi1CKIQR8'),  -- 86 m, The Lana
    ('hotel_762', 'ChIJcZY1XAAFdkgRieYQg6UqpzQ'),  -- 26 m, Claridge's
    ('hotel_763', 'ChIJZUrLFl_PdkgRnQzTVFzh6P8'),  -- 15 m, Estelle Manor
    ('hotel_764', 'ChIJzR8TvrYohkgRlgU5Noy3dBM'),  -- 32 m, Gleneagles
    ('hotel_766', 'ChIJZfEMTNkFdkgRXHTECATydW8'),  -- 60 m, Raffles London at The OWO
    ('hotel_767', 'ChIJiTyvxdcEdkgRIE3fJmxwzVM'),  -- 0 m, The Connaught
    ('hotel_768', 'ChIJnTmXt6QFdkgRV1_2XnA4xCA'),  -- 49 m, The Emory
    ('hotel_771', 'ChIJM-uWC9VZwokRMm_7bwjHFBg'),  -- 23 m, Aman New York
    ('hotel_774', 'ChIJr9ahs5ey2YgRdtqjj6J7NmI'),  -- 45 m, Four Seasons at The Surf Club
    ('hotel_776', 'ChIJCXlmZIoS6YARwDbVhFeD0Q8'),  -- 32 m, San Ysidro Ranch
    ('hotel_779', 'ChIJ4dl6S5lZwokRb4ibeAxtTjI'),  -- 15 m, The Fifth Avenue Hotel
    ('hotel_780', 'ChIJTWkuhfVZwokRvaommqZ2oqA'),  -- 4 m, The Greenwich Hotel
    ('hotel_781', 'ChIJXYOiRJRYwokRm1i3c9R6WDA');  -- 4 m, The Mark

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _pid_hotels p
   where not exists (select 1 from public.hotels t where t.hotel_code = p.code);
  if bad is not null then raise exception 'hotels: unknown codes: %', bad; end if;

  select string_agg(p.code || ' -> ' || p.place_id || ' (held by ' || t.hotel_code || ')', '; ') into bad
    from _pid_hotels p join public.hotels t
      on t.google_place_id = p.place_id and t.hotel_code <> p.code;
  if bad is not null then raise exception 'hotels: Place ID already used by another row: %', bad; end if;

  select string_agg(p.code, ', ') into bad from _pid_hotels p
    join public.hotels t on t.hotel_code = p.code
   where t.google_place_id is not null and t.google_place_id <> p.place_id;
  if bad is not null then raise notice 'hotels: already holds a different Place ID, left untouched: %', bad; end if;
end $$;

update public.hotels t set google_place_id = p.place_id
  from _pid_hotels p
 where t.hotel_code = p.code and t.google_place_id is null;

create temp table _pid_restaurants (code text primary key, place_id text not null unique) on commit drop;
insert into _pid_restaurants values
    ('rest_0780', 'ChIJoZbs8dMzxkcR01gwFw7uBBY'),  -- 18 m, Basiliek
    ('rest_0782', 'ChIJ_bFKjRC3xUcRl7uUWFhXr5c'),  -- 6 m, Zheng
    ('rest_0783', 'ChIJu61sS84JxkcR9DvNepP2cfU'),  -- 5 m, Daalder
    ('rest_0784', 'ChIJTdKgQhxaz0cRFaMdTHA5JEA'),  -- 9 m, Merlet
    ('rest_0785', 'ChIJx7KqLHnAxUcRPeqNspXmcWs'),  -- 2 m, Latour
    ('rest_0786', 'ChIJXy6mMnZnyEcRYnSX9uz9RL4'),  -- 8 m, Restaurant Smink
    ('rest_0787', 'ChIJ6XzF2T4pyEcRaa6_ZE0fvA8'),  -- 3 m, De Vlindertuin
    ('rest_0788', 'ChIJ1dkJZYT9t0cRk_Vw74UwBJo'),  -- 2 m, De Woage
    ('rest_0789', 'ChIJz271mAzxx0cRKfqfufb6wls'),  -- 43 m, De Swarte Ruijter
    ('rest_0790', 'ChIJj7leFQMOuEcRw98L7cjYynE'),  -- 8 m, 't Lansink
    ('rest_0791', 'ChIJKYzZQvQXuEcRCLnglJqempA'),  -- 68 m, De Bloemenbeek
    ('rest_0792', 'ChIJB5b9InSHxkcRJ9Q3glPUDTk'),  -- 8 m, De Gieser Wildeman
    ('rest_0793', 'ChIJ0eloBkzBxUcRUuFnYqJ_gjI'),  -- 18 m, De Moerbei
    ('rest_0794', 'ChIJWdF0Qu45z0cRlfiYb_UsJk0');  -- 8 m, Bij Jef

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _pid_restaurants p
   where not exists (select 1 from public.restaurants t where t.restaurant_code = p.code);
  if bad is not null then raise exception 'restaurants: unknown codes: %', bad; end if;

  select string_agg(p.code || ' -> ' || p.place_id || ' (held by ' || t.restaurant_code || ')', '; ') into bad
    from _pid_restaurants p join public.restaurants t
      on t.google_place_id = p.place_id and t.restaurant_code <> p.code;
  if bad is not null then raise exception 'restaurants: Place ID already used by another row: %', bad; end if;

  select string_agg(p.code, ', ') into bad from _pid_restaurants p
    join public.restaurants t on t.restaurant_code = p.code
   where t.google_place_id is not null and t.google_place_id <> p.place_id;
  if bad is not null then raise notice 'restaurants: already holds a different Place ID, left untouched: %', bad; end if;
end $$;

update public.restaurants t set google_place_id = p.place_id
  from _pid_restaurants p
 where t.restaurant_code = p.code and t.google_place_id is null;

commit;

-- ============================================================
-- Step 2 -- Amangalla coordinate correction (QA-209)
-- ============================================================
-- Our stored point (6.03306, 80.21667) is outside Galle Fort, on Wakwella
-- Road; the official address is 10 Church Street, "within the ramparts of
-- Galle Fort" (aman.com). Google's pin (6.028619, 80.217041) and
-- OpenStreetMap's building outline (way 136845382, centre 6.0286114,
-- 80.2170010) agree; the OSM value is used. Moves the point ~496 m.
-- Skips if already corrected (safe to re-run the file); otherwise aborts
-- unless exactly one row still holds the old point, so it can never
-- overwrite a different, later correction.
begin;

do $$
declare n int;
begin
  if exists (select 1 from public.hotels
              where hotel_code = 'hotel_748'
                and ST_DWithin(location, ST_SetSRID(ST_MakePoint(80.2170010, 6.0286114), 4326)::geography, 5)) then
    raise notice 'hotel_748: already at the corrected point, skipped';
    return;
  end if;
  update public.hotels
     set location = ST_SetSRID(ST_MakePoint(80.2170010, 6.0286114), 4326)::geography
   where hotel_code = 'hotel_748'
     and ST_DWithin(location, ST_SetSRID(ST_MakePoint(80.21667, 6.03306), 4326)::geography, 5);
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'hotel_748: expected 1 row at the old point, found %', n; end if;
end $$;

commit;

-- ============================================================
-- Step 3 -- run only after prepared_w50b_new_venues_import.sql
-- ============================================================
begin;

do $$
begin
  -- Identity guard: hotel_801 must be the Singita row the W50B import creates
  -- (South Africa, Singita Lebombo's MICHELIN page), not another hotel.
  if exists (select 1 from public.hotels where hotel_code = 'hotel_801')
     and not exists (select 1 from public.hotels where hotel_code = 'hotel_801' and country_code = 'ZA'
                     and michelin_url = 'https://guide.michelin.com/en/hotels-stays/Mpumalanga-1/singita-lebombo-16240') then
    raise exception 'hotel_801 is not the expected Singita row';
  end if;
end $$;

create temp table _pid_singita (code text primary key, place_id text not null unique) on commit drop;
insert into _pid_singita values
    ('hotel_801', 'ChIJe2Oep6s93R4RhzCjx_VIOq0');  -- 25 m, Singita Lebombo Lodge

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _pid_singita p
   where not exists (select 1 from public.hotels t where t.hotel_code = p.code);
  if bad is not null then raise exception 'hotels: unknown codes: %', bad; end if;

  select string_agg(p.code || ' -> ' || p.place_id || ' (held by ' || t.hotel_code || ')', '; ') into bad
    from _pid_singita p join public.hotels t
      on t.google_place_id = p.place_id and t.hotel_code <> p.code;
  if bad is not null then raise exception 'hotels: Place ID already used by another row: %', bad; end if;

  select string_agg(p.code, ', ') into bad from _pid_singita p
    join public.hotels t on t.hotel_code = p.code
   where t.google_place_id is not null and t.google_place_id <> p.place_id;
  if bad is not null then raise notice 'hotels: already holds a different Place ID, left untouched: %', bad; end if;
end $$;

update public.hotels t set google_place_id = p.place_id
  from _pid_singita p
 where t.hotel_code = p.code and t.google_place_id is null;

commit;

-- ============================================================
-- OPTIONAL -- commented out; needs an explicit decision (QA-211)
-- ============================================================
--
-- Six Senses Zighy Bay Place ID. The record is the resort's own listing
--     (links to sixsenses.com, the only candidate) but Google's pin sits at
--     the clifftop restaurant, 1,571 m from our (correct-looking) beach
--     coordinates -- past the 500 m rule. Run only if you accept the record
--     despite its pin; our coordinates stay as they are.
--
-- update public.hotels set google_place_id = 'ChIJzWx5aPUr9D4RCUtY4UglHAE'
--  where hotel_code = 'hotel_744' and google_place_id is null
--    and not exists (select 1 from public.hotels
--                     where google_place_id = 'ChIJzWx5aPUr9D4RCUtY4UglHAE');
