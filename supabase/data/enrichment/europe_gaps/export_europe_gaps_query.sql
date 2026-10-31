-- Read-only export: Place ID / phone / website gaps in Europe (2026-10-31).
-- ONE row, ONE JSON cell. Run in the Supabase SQL Editor, download as CSV,
-- upload to the session.
-- Europe = the explicit ISO list below (no continent column exists).
with eu(cc) as (values ('AD'),('AL'),('AT'),('BA'),('BE'),('BG'),('CH'),('CY'),('CZ'),('DE'),('DK'),('EE'),
  ('ES'),('FI'),('FR'),('GB'),('GR'),('HR'),('HU'),('IE'),('IS'),('IT'),('LI'),('LT'),('LU'),('LV'),('MC'),
  ('MD'),('ME'),('MK'),('MT'),('NL'),('NO'),('PL'),('PT'),('RO'),('RS'),('SE'),('SI'),('SK'),('SM'),('VA'),('XK'))
select json_build_object(
  'exported_at', now(),
  'summary', (select json_agg(s order by s.country) from (
      select 'restaurant' as kind, r.country_code as country, count(*) as total,
             count(*) filter (where r.google_place_id is null) as no_place_id,
             count(*) filter (where r.phone is null) as no_phone,
             count(*) filter (where r.website_url is null) as no_website
        from public.restaurants r join eu on eu.cc = r.country_code
       where r.status <> 'permanently_closed' group by r.country_code
      union all
      select 'hotel', h.country_code, count(*),
             count(*) filter (where h.google_place_id is null),
             count(*) filter (where h.phone is null),
             count(*) filter (where h.website_url is null)
        from public.hotels h join eu on eu.cc = h.country_code
       where h.status <> 'permanently_closed' group by h.country_code) s),
  'gaps', (select json_agg(g order by g.country, g.kind, g.code) from (
      select 'restaurant' as kind, r.restaurant_code as code, r.country_code as country, r.name,
             c.name as city, r.address, ST_Y(r.location::geometry) as lat, ST_X(r.location::geometry) as lon,
             r.michelin_stars as stars, r.inclusion_reason, r.michelin_url, r.property_name,
             r.google_place_id, r.phone, r.website_url
        from public.restaurants r join eu on eu.cc = r.country_code join public.cities c on c.id = r.city_id
       where r.status <> 'permanently_closed'
         and (r.google_place_id is null or r.phone is null or r.website_url is null)
      union all
      select 'hotel', h.hotel_code, h.country_code, h.name, c.name, h.address,
             ST_Y(h.location::geometry), ST_X(h.location::geometry),
             h.michelin_keys, null, h.michelin_url, null,
             h.google_place_id, h.phone, h.website_url
        from public.hotels h join eu on eu.cc = h.country_code join public.cities c on c.id = h.city_id
       where h.status <> 'permanently_closed'
         and (h.google_place_id is null or h.phone is null or h.website_url is null)) g),
  'restaurant_place_ids_in_use', (select json_agg(google_place_id) from public.restaurants where google_place_id is not null),
  'hotel_place_ids_in_use', (select json_agg(google_place_id) from public.hotels where google_place_id is not null)
) as export;
