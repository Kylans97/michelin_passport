-- Fixes a gap in 20260829150000_add_popup_expiry_to_views_and_search.sql:
-- that migration added starts_on/ends_on/parent_venue_type/
-- parent_venue_id/opening_weekdays to restaurants/hotels (base tables)
-- and to restaurant_repository.dart/hotel_repository.dart's own
-- restaurantFullColumns/hotelFullColumns select lists, but only ever
-- projected `is_expired` on restaurants_full/hotels_full themselves —
-- it used r.ends_on/h.ends_on internally to compute is_expired without
-- ever also SELECTing the 5 raw columns as their own output columns.
-- Confirmed live in production: `select restaurantFullColumns from
-- restaurants_full` throws `column restaurants_full.starts_on does not
-- exist` (42703) — every screen behind that shared column list broke
-- (Restaurant/Hotel Detail, Trips, Wishlist, Events, Worlds 50 Best,
-- Gault&Millau, Map, Passport/Visited all select through it).
--
-- private_chefs_full was NOT affected — it selects `pc.*`, so it always
-- inherited every private_chefs column automatically. This gap was
-- specific to restaurants_full/hotels_full's explicit column lists.
--
-- Fix: re-add the 5 columns to both views' SELECT lists. Nothing else
-- changes — same joins, same existing computed columns, same
-- security_invoker setting.

begin;

create or replace view public.restaurants_full
  with (security_invoker = true)
  as
select
  r.id,
  r.restaurant_code,
  r.name,
  r.michelin_stars,
  r.inclusion_reason,
  r.cuisine_id,
  r.city_id,
  r.country_code,
  r.address,
  r.location,
  r.google_place_id,
  r.michelin_url,
  r.website_url,
  r.booking_url,
  r.property_name,
  r.status,
  r.status_since,
  r.status_note,
  r.created_at,
  r.updated_at,
  hr.id is not null or r.property_name is not null as is_in_hotel,
  coalesce(h.name, r.property_name) as hotel_name,
  h.id as hotel_id,
  ci.name as city_name,
  ci.region,
  co.name as country_name,
  co.flag_emoji,
  w.rank as worlds_50_best_rank,
  st_y(r.location::geometry) as latitude,
  st_x(r.location::geometry) as longitude,
  (exists (
    select 1 from public.worlds_50_best hof
    where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame'
  )) as is_hall_of_fame,
  r.phone,
  (r.ends_on is not null and r.ends_on < current_date) as is_expired,
  -- CREATE OR REPLACE VIEW cannot change an existing output column's
  -- ordinal position (42P16) — these 5 must stay appended after
  -- is_expired, not inserted before it, even though they logically
  -- belong next to phone above.
  r.starts_on,
  r.ends_on,
  r.parent_venue_type,
  r.parent_venue_id,
  r.opening_weekdays
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
  h.id,
  h.hotel_code,
  h.name,
  h.michelin_keys,
  h.city_id,
  h.country_code,
  h.address,
  h.location,
  h.google_place_id,
  h.michelin_url,
  h.website_url,
  h.booking_url,
  h.status,
  h.status_since,
  h.status_note,
  h.created_at,
  h.updated_at,
  coalesce(hr.restaurant_count, 0) > 0 as has_michelin_restaurant,
  coalesce(hr.restaurant_count, 0) as restaurant_count,
  ci.name as city_name,
  ci.region,
  co.name as country_name,
  co.flag_emoji,
  st_y(h.location::geometry) as latitude,
  st_x(h.location::geometry) as longitude,
  w.rank as worlds_50_best_rank,
  w.year as worlds_50_best_year,
  (h.ends_on is not null and h.ends_on < current_date) as is_expired,
  -- Same ordinal-position constraint as restaurants_full above.
  h.starts_on,
  h.ends_on,
  h.parent_venue_type,
  h.parent_venue_id,
  h.opening_weekdays
from public.hotels h
join public.cities ci on ci.id = h.city_id
join public.countries co on co.country_code = h.country_code
left join (
  select hotel_id, count(*) as restaurant_count
  from public.hotel_restaurants
  group by hotel_id
) hr on hr.hotel_id = h.id
left join public.worlds_50_best_hotels w
  on w.hotel_id = h.id
 and w.year = (select max(year) from public.worlds_50_best_hotels where rank is not null);

commit;
