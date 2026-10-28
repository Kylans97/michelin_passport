-- Read-only export for the Spain star/Place ID/phone pass (2026-10-28).
-- Returns ONE row with ONE JSON cell, so the SQL Editor's 100-row page
-- limit doesn't apply. Run in the Supabase SQL Editor, then download the
-- result as CSV.
select json_build_object(
  'exported_at', now(),
  'max_restaurant_code', (select max(substring(restaurant_code from 6)::int)
                            from public.restaurants where restaurant_code ~ '^rest_[0-9]+$'),
  'restaurants', (
    select json_agg(json_build_object(
      'code', r.restaurant_code, 'name', r.name, 'stars', r.michelin_stars,
      'inclusion_reason', r.inclusion_reason,
      'city', c.name, 'postal_municipality', c.postal_municipality, 'region', c.region,
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
   where r.country_code = 'ES'),
  'cities', (select json_agg(json_build_object(
               'name', name, 'postal_municipality', postal_municipality,
               'region', region, 'edition', michelin_guide_edition) order by name)
               from public.cities where country_code = 'ES'),
  'place_ids_in_use', (select json_agg(google_place_id) from public.restaurants
                        where google_place_id is not null),
  'michelin_urls_in_use', (select json_agg(michelin_url) from public.restaurants
                            where michelin_url is not null)
) as export;
