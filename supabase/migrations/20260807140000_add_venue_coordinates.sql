-- Expose scalar latitude/longitude on restaurants_full and hotels_full.
--
-- public.restaurants.location and public.hotels.location remain the sole
-- source of truth (geography(Point,4326)). This migration does not add,
-- alter, or duplicate any stored column — it only appends two derived,
-- read-only columns to each view via ST_Y/ST_X, so PostgREST can return
-- scalar coordinates instead of an EWKB hex string.
--
-- CREATE OR REPLACE VIEW requires the existing column list/order/types to
-- be preserved exactly; these two columns are appended at the end.

create or replace view public.restaurants_full
  with (security_invoker = true)
  as
select
  r.*,
  (hr.id is not null or r.property_name is not null) as is_in_hotel,
  coalesce(h.name, r.property_name)                  as hotel_name,
  h.id                                                as hotel_id,
  ci.name                                             as city_name,
  ci.region                                           as region,
  co.name                                             as country_name,
  co.flag_emoji                                       as flag_emoji,
  w.rank                                              as worlds_50_best_rank,
  st_y(r.location::geometry)                          as latitude,
  st_x(r.location::geometry)                          as longitude
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null);

create or replace view public.hotels_full
  with (security_invoker = true)
  as
select
  h.*,
  coalesce(hr.restaurant_count, 0) > 0 as has_michelin_restaurant,
  coalesce(hr.restaurant_count, 0)     as restaurant_count,
  ci.name                              as city_name,
  ci.region                            as region,
  co.name                              as country_name,
  co.flag_emoji                        as flag_emoji,
  st_y(h.location::geometry)           as latitude,
  st_x(h.location::geometry)           as longitude
from public.hotels h
join public.cities ci on ci.id = h.city_id
join public.countries co on co.country_code = h.country_code
left join (
  select hotel_id, count(*) as restaurant_count
  from public.hotel_restaurants
  group by hotel_id
) hr on hr.hotel_id = h.id;
