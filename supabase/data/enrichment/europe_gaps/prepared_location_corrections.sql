-- PREPARED -- NOT APPLIED.
--
-- Location corrections for 18 restaurants/hotels whose stored coordinates
-- are 0.5-53 km from the venue (QA-209 follow-up set: QA-232, QA-256, QA-393,
-- QA-396), written 2026-11-01, plus the Place ID (and, for one hotel, phone and
-- website) each correction unblocks. Evidence per row: location_corrections.csv.
--
-- A point is moved only when two independent sources agree on where the venue
-- is and our stored point is the outlier:
--   * MICHELIN's pin and the venue's own Google record within 150 m of each
--     other (11 rows: new point = MICHELIN's pin), or
--   * where our stored point IS MICHELIN's pin: an OpenStreetMap geocode of
--     the venue's address within 100 m of the venue's Google record and more
--     than 500 m from MICHELIN's (7 rows: new point = the Google record).
-- Where the address sides with MICHELIN (Seaham Hall, Ballyfin, Ca' Matilde)
-- our point is right and Google's pin is off: nothing changes. Undecided cases
-- are left for review.
--
-- Guards: each code must still carry the expected name and country; a point
-- moves only while the row still holds the old point (within 5 m), so a later
-- correction is never overwritten; Place ID/phone/website are fill-only and a
-- Place ID held by another row aborts. One transaction; safe to re-run.

begin;
-- restaurants: 13 locations
create temp table _loc_restaurant (code text primary key, country text, name text, old_lon float8, old_lat float8,
                       new_lon float8, new_lat float8, place_id text unique, phone text, website text) on commit drop;
insert into _loc_restaurant values
    ('rest_0952', 'FR', 'Onor', 2.3087456, 48.8736875, 2.3003097, 48.8772724, 'ChIJswl0oJdv5kcR5M9tkvzjpnM', NULL, NULL),  -- moves 735 m
    ('rest_1054', 'FR', 'Ruche', 1.6868992, 48.7822418, 1.6961807, 48.790545, 'ChIJOS3ZLhmj5kcRDjlq9QLyQdk', NULL, NULL),  -- moves 1,147 m
    ('rest_1082', 'FR', 'La Table d''Olivier Nasti', 7.247364, 48.1527693, 7.2656078, 48.1386841, 'ChIJE5WL7OVgkUcRaNiOhlO1-pI', NULL, NULL),  -- moves 2,070 m
    ('rest_1130', 'FR', 'Auberge Sauvage', -1.4581438, 48.1205417, -1.4196972, 48.6007516, 'ChIJi7pC8HWtDkgRZuBGiBCcyDo', NULL, NULL),  -- moves 53,472 m
    ('rest_1153', 'FR', 'L''Inattendu - Domaine de Locguénolé', -3.2824688, 47.7697308, -3.2761308, 47.7735735, 'ChIJgcGunE1dEEgRY6lF1rPXAM8', NULL, NULL),  -- moves 638 m
    ('rest_1353', 'FR', 'La Maison de Pierre', -1.3524002, 43.3684857, -1.30407, 43.38693, 'ChIJi2yFbY4wUQ0RA6A8N0FQZ4U', NULL, NULL),  -- moves 4,412 m
    ('rest_1366', 'FR', 'La Table de la Ferme', 8.9488892, 41.5160957, 8.9469027, 41.5229756, 'ChIJSdEchmfM2xIR8UFufD3nrgQ', NULL, NULL),  -- moves 783 m
    ('rest_1551', 'FR', 'La Huchette', 4.8826914, 46.2987913, 4.890126899999999, 46.2966267, 'ChIJg7Kym9ho80cRX7JavJ0AdBw', NULL, NULL),  -- moves 620 m
    ('rest_3633', 'AT', 'Gründler''s Gourmet Stüberl', 11.7040198, 47.5088961, 11.706062, 47.5032304, NULL, NULL, NULL),  -- moves 648 m
    ('rest_0002', 'ES', 'ABAC', 2.1344, 41.4145, 2.1365112, 41.4104497, NULL, NULL, NULL),  -- moves 484 m
    ('rest_0044', 'ES', 'DiverXO', -3.683, 40.4516, -3.6856715, 40.4582913, NULL, NULL, NULL),  -- moves 778 m
    ('rest_0003', 'IT', 'Al Gatto Verde', 10.9254, 44.6423, 10.980026, 44.6102868, NULL, NULL, NULL),  -- moves 5,600 m
    ('rest_0006', 'IT', 'Alto', 10.8107, 44.5374, 10.8243773, 44.5379081, NULL, NULL, NULL);  -- moves 1,086 m

do $$
declare bad text;
begin
  select string_agg(l.code, ', ') into bad from _loc_restaurant l
   where not exists (select 1 from public.restaurants x where x.restaurant_code = l.code and x.name = l.name and x.country_code = l.country);
  if bad is not null then raise exception 'restaurants: code is no longer the expected row: %', bad; end if;
  select string_agg(l.code || ' -> ' || l.place_id || ' (held by ' || x.restaurant_code || ')', '; ') into bad
    from _loc_restaurant l join public.restaurants x on x.google_place_id = l.place_id and x.restaurant_code <> l.code;
  if bad is not null then raise exception 'restaurants: Place ID already used by another row: %', bad; end if;
end $$;

-- move only while the row still holds the old point (never overwrites a later fix)
update public.restaurants x set location = ST_SetSRID(ST_MakePoint(l.new_lon, l.new_lat), 4326)::geography, updated_at = now()
  from _loc_restaurant l
 where x.restaurant_code = l.code
   and ST_DWithin(x.location, ST_SetSRID(ST_MakePoint(l.old_lon, l.old_lat), 4326)::geography, 5);
update public.restaurants x set google_place_id = l.place_id, updated_at = now()
  from _loc_restaurant l where x.restaurant_code = l.code and l.place_id is not null and x.google_place_id is null;
update public.restaurants x set phone = l.phone, updated_at = now()
  from _loc_restaurant l where x.restaurant_code = l.code and l.phone is not null and x.phone is null;
update public.restaurants x set website_url = l.website, updated_at = now()
  from _loc_restaurant l where x.restaurant_code = l.code and l.website is not null and x.website_url is null;

-- hotels: 5 locations
create temp table _loc_hotel (code text primary key, country text, name text, old_lon float8, old_lat float8,
                       new_lon float8, new_lat float8, place_id text unique, phone text, website text) on commit drop;
insert into _loc_hotel values
    ('hotel_2058', 'FR', 'Altapura', 6.584665, 45.296609, 6.5747703, 45.2974803, 'ChIJg4o3wFiGiUcRicfNeQgl4Eg', NULL, NULL),  -- moves 780 m
    ('hotel_2100', 'FR', 'Domaine des Andéols', 5.362873, 43.98, 5.3648922, 43.931323, 'ChIJfywbhacVyhIRbpjGDAZgsAE', NULL, NULL),  -- moves 5,415 m
    ('hotel_2107', 'FR', 'Georges Blanc', 4.992602, 46.225837, 4.9897279999999995, 46.220067, NULL, NULL, NULL),  -- moves 679 m
    ('hotel_946', 'IE', 'Dromoland Castle', -8.8982, 52.76081, -8.905636399999999, 52.7830484, 'ChIJ748FdHFrW0gRuGSaV5OTUFM', NULL, NULL),  -- moves 2,523 m
    ('hotel_2610', 'IS', 'The Retreat at Blue Lagoon Iceland', -22.42956, 63.88128, -22.451410799999998, 63.879586, 'ChIJqb_dB3cd1kgRwDIBpv48FM0', '+354 420 8700', 'https://www.bluelagoon.com/accommodation/retreat-hotel');  -- moves 1,086 m

do $$
declare bad text;
begin
  select string_agg(l.code, ', ') into bad from _loc_hotel l
   where not exists (select 1 from public.hotels x where x.hotel_code = l.code and x.name = l.name and x.country_code = l.country);
  if bad is not null then raise exception 'hotels: code is no longer the expected row: %', bad; end if;
  select string_agg(l.code || ' -> ' || l.place_id || ' (held by ' || x.hotel_code || ')', '; ') into bad
    from _loc_hotel l join public.hotels x on x.google_place_id = l.place_id and x.hotel_code <> l.code;
  if bad is not null then raise exception 'hotels: Place ID already used by another row: %', bad; end if;
end $$;

-- move only while the row still holds the old point (never overwrites a later fix)
update public.hotels x set location = ST_SetSRID(ST_MakePoint(l.new_lon, l.new_lat), 4326)::geography, updated_at = now()
  from _loc_hotel l
 where x.hotel_code = l.code
   and ST_DWithin(x.location, ST_SetSRID(ST_MakePoint(l.old_lon, l.old_lat), 4326)::geography, 5);
update public.hotels x set google_place_id = l.place_id, updated_at = now()
  from _loc_hotel l where x.hotel_code = l.code and l.place_id is not null and x.google_place_id is null;
update public.hotels x set phone = l.phone, updated_at = now()
  from _loc_hotel l where x.hotel_code = l.code and l.phone is not null and x.phone is null;
update public.hotels x set website_url = l.website, updated_at = now()
  from _loc_hotel l where x.hotel_code = l.code and l.website is not null and x.website_url is null;

commit;
