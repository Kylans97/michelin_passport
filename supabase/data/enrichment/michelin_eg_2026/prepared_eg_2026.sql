-- MICHELIN Key hotels in Egypt, read 2026-11-04: 13 hotels (hotel_3121..hotel_3133), each with a current
-- 2026 Key row, announced 2026-09-18 (global Key article: "Egypt – 13 Key hotels"). Evidence in eg_key_hotels_2026.csv.
-- Name = page h1; address and pin = page JSON-LD. Phone, website and Place ID NULL: none confirmable outside
-- MICHELIN in this pass (QA-460). No restaurant, link or property_name is written.
-- PREREQUISITE: supabase/migrations/20261101370000_add_eg_2026_country_and_cities.sql.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;

create temp table _newh (code text, name text, keys smallint, city text, address text, lon float8, lat float8, michelin_url text) on commit drop;
insert into _newh values
    ('hotel_3121', 'Al Moudira Hotel', 2, 'Luxor', 'Hager Al Dabbeya, West Bank, 1340304 Luxor', 32.552754, 25.684357, 'https://guide.michelin.com/en/hotels-stays/luxor/al-moudira-9477'),
    ('hotel_3122', 'Casa Cook El Gouna', 1, 'El Gouna', 'Hurghada, 84513 El Gouna', 33.666465, 27.423875, 'https://guide.michelin.com/en/hotels-stays/el-gouna/casa-cook-el-gouna-126627-15566'),
    ('hotel_3123', 'Dusit Thani LakeView Cairo', 1, 'Cairo', 'El Tesseen Street, Fifth Settlement, Cairo', 31.456078, 30.025529, 'https://guide.michelin.com/en/hotels-stays/cairo/dusit-thani-lakeview-cairo-16265'),
    ('hotel_3124', 'Fairmont Nile City', 1, 'Cairo', 'Nile City Towers, 2005B Corniche El Nil, Ramlet Bulaq, 11311 Cairo', 31.2277493288, 30.0718079847, 'https://guide.michelin.com/en/hotels-stays/cairo/fairmont-nile-city-15160'),
    ('hotel_3125', 'Four Seasons Hotel Alexandria at San Stefano, Egypt', 1, 'Alexandria', '399 El Geish Road, San Stefano Grand Plaza, Alexandria', 29.96586, 31.24584, 'https://guide.michelin.com/en/hotels-stays/alexandria/four-seasons-hotel-alexandria-9522'),
    ('hotel_3126', 'Four Seasons Hotel Cairo at Nile Plaza', 1, 'Cairo', '1089 Corniche El Nil, P.O. Box 63 Maglis El Shaab, Garden City, 11519 Cairo', 31.23215546, 30.0382348376, 'https://guide.michelin.com/en/hotels-stays/cairo/four-seasons-cairo-at-nile-plaza-8431'),
    ('hotel_3127', 'Four Seasons Resort Sharm El Sheikh', 2, 'Sharm El Sheikh', '1 Four Seasons Boulevard, PO Box 203, Sharm El Sheikh', 34.393036, 27.955264, 'https://guide.michelin.com/en/hotels-stays/sharm-el-sheikh/four-seasons-resort-sharm-el-sheikh-8233'),
    ('hotel_3128', 'Giza Palace Hotel & Spa', 1, 'Giza', 'No.35/36. 26th July Corridor Sheikh Zayed, 6th of October City, 12588 Giza', 31.002285, 30.018278, 'https://guide.michelin.com/en/hotels-stays/Giza/giza-palace-hotel-spa-15388'),
    ('hotel_3129', 'La Maison Bleue El Gouna', 1, 'El Gouna', 'Kite Center Road, Hurghada, 84513 El Gouna', 33.67045, 27.42246, 'https://guide.michelin.com/en/hotels-stays/el-gouna/la-maison-bleue-el-gouna-14616'),
    ('hotel_3130', 'Mazeej Balad Boutique Hotel', 1, 'Cairo', '7 Champollion Road, 4272111 Cairo', 31.236536, 30.048159, 'https://guide.michelin.com/en/hotels-stays/cairo/mazeej-balad-boutique-hotel-15456'),
    ('hotel_3131', 'Rixos Montaza Alexandria', 1, 'Alexandria', 'Montaza, 21919 Alexandria', 30.015993, 31.288405, 'https://guide.michelin.com/en/hotels-stays/alexandria/rixos-montaza-alexandria-16269'),
    ('hotel_3132', 'The Oberoi Beach Resort, Sahl Hasheesh', 1, 'Hurghada', 'Oberoi 117, Sahl Hasheesh, 84500 Hurghada', 33.879991, 27.076915, 'https://guide.michelin.com/en/hotels-stays/Hurghada/the-oberoi-beach-resort-sahl-hasheesh-15528'),
    ('hotel_3133', 'The St. Regis Cairo', 1, 'Cairo', 'Corniche El Nile, Cairo', 31.22734, 30.06301, 'https://guide.michelin.com/en/hotels-stays/cairo/the-st-regis-cairo-12311');

do $$
declare n int; bad text;
begin
  select count(*) into n from public.countries where country_code = 'EG';
  if n <> 1 then raise exception 'no EG country (run the migration first?)'; end if;
  select count(*) into n from public.hotels where country_code = 'EG';
  if n <> 0 then raise exception 'expected no EG hotels, found % -- production changed or this file has run', n; end if;
  select string_agg(x.code, ', ') into bad from _newh x join public.hotels h on h.hotel_code = x.code;
  if bad is not null then raise exception 'hotel codes no longer free: %', bad; end if;
  select string_agg(x.name, ', ') into bad from _newh x join public.hotels h
    on substring(h.michelin_url from '-([0-9]+)/?$') = substring(x.michelin_url from '-([0-9]+)/?$');
  if bad is not null then raise exception 'hotel already present (MICHELIN id): %', bad; end if;
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _newh x
   where (select count(*) from public.cities c where c.country_code = 'EG' and c.name = x.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one row: %', bad; end if;
end $$;

insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url)
select x.code, x.name, x.keys, (select c.id from public.cities c where c.country_code = 'EG' and c.name = x.city), 'EG',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography, x.michelin_url
  from _newh x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2026, 'michelin_keys', h.michelin_keys, true, date '2026-09-18'
  from public.hotels h join _newh x on x.code = h.hotel_code;

do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = 'EG' and michelin_keys = 2;
  if n <> 2 then raise exception 'expected 2 two-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'EG' and michelin_keys = 1;
  if n <> 11 then raise exception 'expected 11 one-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = 'EG'
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% hotels without exactly one current Key row', n; end if;
end $$;

commit;
