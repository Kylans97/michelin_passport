-- Read-only export for the mainland China pass (written 2026-10-29).
-- Copied from ../michelin_gb_ie_2026/export_gb_ie_query.sql (countries set to CN).
-- Run: supabase db query --linked -o json -f <absolute path to this file>
select json_build_object(
  'exported_at', now(),
  'max_restaurant_code', (select max(substring(restaurant_code from 6)::int)
                            from public.restaurants where restaurant_code ~ '^rest_[0-9]+$'),
  'countries_present', (select json_agg(json_build_object('country_code', country_code))
                          from public.countries where country_code in ('CN')),
  'max_hotel_code', (select max(substring(hotel_code from 7)::int)
                       from public.hotels where hotel_code ~ '^hotel_[0-9]+$'),
  'restaurants', (
    select json_agg(json_build_object(
      'code', r.restaurant_code, 'country', r.country_code, 'name', r.name,
      'stars', r.michelin_stars, 'inclusion_reason', r.inclusion_reason,
      'city', c.name, 'region', c.region,
      'address', r.address,
      'lat', ST_Y(r.location::geometry), 'lon', ST_X(r.location::geometry),
      'google_place_id', r.google_place_id, 'phone', r.phone,
      'michelin_url', r.michelin_url, 'website_url', r.website_url,
      'status', r.status, 'property_name', r.property_name,
      'history', (select json_agg(json_build_object(
                    'year', ah.guide_year, 'value', ah.award_value,
                    'current', ah.is_current, 'announced_on', ah.announced_on)
                    order by ah.guide_year)
                    from public.award_history ah
                   where ah.entity_type = 'restaurant' and ah.entity_id = r.id
                     and ah.award_type = 'michelin_stars'))
      order by r.restaurant_code)
    from public.restaurants r join public.cities c on c.id = r.city_id
   where r.country_code in ('CN')),
  'cities', (select json_agg(json_build_object(
               'country', country_code, 'name', name, 'postal_municipality', postal_municipality,
               'region', region) order by country_code, name)
               from public.cities where country_code in ('CN')),
  'hotels', (select json_agg(json_build_object(
               'code', h.hotel_code, 'country', h.country_code, 'name', h.name,
               'keys', h.michelin_keys, 'city', c.name, 'michelin_url', h.michelin_url,
               'phone', h.phone, 'website_url', h.website_url, 'google_place_id', h.google_place_id,
               'address', h.address,
               'lat', ST_Y(h.location::geometry), 'lon', ST_X(h.location::geometry),
               'status', h.status) order by h.hotel_code)
               from public.hotels h join public.cities c on c.id = h.city_id
              where h.country_code in ('CN')),
  'links', (select json_agg(json_build_object(
              'hotel_code', h.hotel_code, 'restaurant_code', r.restaurant_code,
              'confidence', hr.link_confidence))
              from public.hotel_restaurants hr
              join public.hotels h on h.id = hr.hotel_id
              join public.restaurants r on r.id = hr.restaurant_id
             where h.country_code in ('CN') or r.country_code in ('CN')),
  'place_ids_in_use', (select json_agg(google_place_id) from public.restaurants
                        where google_place_id is not null),
  'michelin_urls_in_use', (select json_agg(michelin_url) from public.restaurants
                            where michelin_url is not null),
  'hotel_place_ids_in_use', (select json_agg(google_place_id) from public.hotels
                              where google_place_id is not null),
  'hotel_michelin_urls_in_use', (select json_agg(michelin_url) from public.hotels
                                  where michelin_url is not null)
) as export;
