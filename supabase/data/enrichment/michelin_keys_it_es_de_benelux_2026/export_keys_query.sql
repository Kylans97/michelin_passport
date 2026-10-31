-- Read-only export for the IT/ES/DE/BE/NL/LU Keys refresh (written 2026-10-31).
-- Adapted from ../michelin_ch_at_nordic_2026/export_ch_at_nordic_query.sql: hotels
-- (with their michelin_keys history), cities and links of the six countries, plus
-- the identifiers in use everywhere.
-- Run: supabase db query --linked -o json -f <absolute path to this file>
select json_build_object(
  'exported_at', now(),
  'max_hotel_code', (select max(substring(hotel_code from 7)::int)
                       from public.hotels where hotel_code ~ '^hotel_[0-9]+$'),
  'hotel_codes_2701_2900', (select json_agg(hotel_code) from public.hotels
                             where hotel_code ~ '^hotel_[0-9]+$'
                               and substring(hotel_code from 7)::int between 2701 and 2900),
  'cities', (select json_agg(json_build_object(
               'country', country_code, 'name', name, 'postal_municipality', postal_municipality,
               'region', region) order by country_code, name)
               from public.cities where country_code in ('IT', 'ES', 'DE', 'BE', 'NL', 'LU')),
  'hotels', (select json_agg(json_build_object(
               'code', h.hotel_code, 'country', h.country_code, 'name', h.name,
               'keys', h.michelin_keys, 'city', c.name, 'michelin_url', h.michelin_url,
               'phone', h.phone, 'website_url', h.website_url, 'google_place_id', h.google_place_id,
               'address', h.address,
               'lat', ST_Y(h.location::geometry), 'lon', ST_X(h.location::geometry),
               'status', h.status,
               'key_history', (select json_agg(json_build_object(
                    'year', ah.guide_year, 'value', ah.award_value,
                    'current', ah.is_current, 'announced_on', ah.announced_on)
                    order by ah.guide_year)
                    from public.award_history ah
                   where ah.entity_type = 'hotel' and ah.entity_id = h.id
                     and ah.award_type = 'michelin_keys'),
               'links', (select count(*) from public.hotel_restaurants hr where hr.hotel_id = h.id),
               'in_w50b', exists (select 1 from public.award_history ah
                   where ah.entity_type = 'hotel' and ah.entity_id = h.id
                     and ah.award_type <> 'michelin_keys'))
               order by h.hotel_code)
               from public.hotels h join public.cities c on c.id = h.city_id
              where h.country_code in ('IT', 'ES', 'DE', 'BE', 'NL', 'LU')),
  'award_types', (select json_agg(distinct award_type) from public.award_history where entity_type = 'hotel'),
  'current_key_years', (select json_agg(json_build_object('country', h.country_code, 'year', ah.guide_year,
                           'announced_on', ah.announced_on, 'n', 1))
                         from public.award_history ah join public.hotels h on h.id = ah.entity_id
                         where ah.award_type = 'michelin_keys' and ah.is_current and ah.entity_type = 'hotel'
                           and h.country_code in ('IT', 'ES', 'DE', 'BE', 'NL', 'LU')),
  'hotel_michelin_urls_in_use', (select json_agg(michelin_url) from public.hotels
                                  where michelin_url is not null),
  'hotel_place_ids_in_use', (select json_agg(google_place_id) from public.hotels
                              where google_place_id is not null)
) as export;
