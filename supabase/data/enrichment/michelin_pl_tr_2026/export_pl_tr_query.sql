-- Read-only export for the Poland + Türkiye pass (written 2026-11-01).
-- Combines ../michelin_pt_stars/export_pt_query.sql (restaurants with their
-- star history) and ../michelin_keys_it_es_de_benelux_2026/export_keys_query.sql
-- (hotels with their Key history), for PL and TR, plus identifiers in use everywhere.
-- Run: supabase db query --linked -o json -f <absolute path to this file>
select json_build_object(
  'exported_at', now(),
  'max_restaurant_code', (select max(substring(restaurant_code from 6)::int)
                            from public.restaurants where restaurant_code ~ '^rest_[0-9]+$'),
  'max_hotel_code', (select max(substring(hotel_code from 7)::int)
                       from public.hotels where hotel_code ~ '^hotel_[0-9]+$'),
  'restaurants', (
    select json_agg(json_build_object(
      'code', r.restaurant_code, 'country', r.country_code, 'name', r.name,
      'stars', r.michelin_stars, 'inclusion_reason', r.inclusion_reason,
      'city', c.name, 'region', c.region, 'address', r.address,
      'lat', ST_Y(r.location::geometry), 'lon', ST_X(r.location::geometry),
      'google_place_id', r.google_place_id, 'phone', r.phone,
      'michelin_url', r.michelin_url, 'website_url', r.website_url,
      'status', r.status, 'property_name', r.property_name,
      'history', (select json_agg(json_build_object(
                    'type', ah.award_type, 'year', ah.guide_year, 'value', ah.award_value,
                    'current', ah.is_current, 'announced_on', ah.announced_on)
                    order by ah.award_type, ah.guide_year)
                    from public.award_history ah
                   where ah.entity_type = 'restaurant' and ah.entity_id = r.id))
      order by r.restaurant_code)
    from public.restaurants r join public.cities c on c.id = r.city_id
   where r.country_code in ('PL', 'TR')),
  'cities', (select json_agg(json_build_object(
               'country', country_code, 'name', name, 'postal_municipality', postal_municipality,
               'region', region) order by country_code, name)
               from public.cities where country_code in ('PL', 'TR')),
  'hotels', (select json_agg(json_build_object(
               'code', h.hotel_code, 'country', h.country_code, 'name', h.name,
               'keys', h.michelin_keys, 'city', c.name, 'michelin_url', h.michelin_url,
               'phone', h.phone, 'website_url', h.website_url, 'google_place_id', h.google_place_id,
               'address', h.address,
               'lat', ST_Y(h.location::geometry), 'lon', ST_X(h.location::geometry),
               'status', h.status,
               'history', (select json_agg(json_build_object(
                    'type', ah.award_type, 'year', ah.guide_year, 'value', ah.award_value,
                    'current', ah.is_current, 'announced_on', ah.announced_on)
                    order by ah.award_type, ah.guide_year)
                    from public.award_history ah
                   where ah.entity_type = 'hotel' and ah.entity_id = h.id))
               order by h.hotel_code)
               from public.hotels h join public.cities c on c.id = h.city_id
              where h.country_code in ('PL', 'TR')),
  'links', (select json_agg(json_build_object(
              'hotel_code', h.hotel_code, 'restaurant_code', r.restaurant_code,
              'confidence', hr.link_confidence))
              from public.hotel_restaurants hr
              join public.hotels h on h.id = hr.hotel_id
              join public.restaurants r on r.id = hr.restaurant_id
             where h.country_code in ('PL', 'TR') or r.country_code in ('PL', 'TR')),
  'countries', (select json_agg(row_to_json(x)) from public.countries x where x.country_code in ('PL', 'TR')),
  'place_ids_in_use', (select json_agg(google_place_id) from public.restaurants where google_place_id is not null),
  'michelin_urls_in_use', (select json_agg(michelin_url) from public.restaurants where michelin_url is not null),
  'hotel_michelin_urls_in_use', (select json_agg(michelin_url) from public.hotels where michelin_url is not null),
  'hotel_place_ids_in_use', (select json_agg(google_place_id) from public.hotels where google_place_id is not null)
) as export;
