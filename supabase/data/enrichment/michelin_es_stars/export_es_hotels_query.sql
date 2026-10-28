-- Read-only export for the Spain pass (2026-10-28), part 2: Spanish Key
-- hotels and their existing restaurant links. One row, one JSON cell.
select json_build_object(
  'hotels', (select json_agg(json_build_object(
               'code', h.hotel_code, 'name', h.name, 'keys', h.michelin_keys,
               'city', c.name, 'michelin_url', h.michelin_url,
               'lat', ST_Y(h.location::geometry), 'lon', ST_X(h.location::geometry),
               'status', h.status) order by h.hotel_code)
               from public.hotels h join public.cities c on c.id = h.city_id
              where h.country_code = 'ES'),
  'links', (select json_agg(json_build_object(
              'hotel_code', h.hotel_code, 'restaurant_code', r.restaurant_code,
              'confidence', hr.link_confidence))
              from public.hotel_restaurants hr
              join public.hotels h on h.id = hr.hotel_id
              join public.restaurants r on r.id = hr.restaurant_id
             where h.country_code = 'ES' or r.country_code = 'ES')
) as export;
