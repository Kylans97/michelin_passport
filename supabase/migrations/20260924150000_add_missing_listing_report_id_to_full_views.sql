-- Same bug class as 20260918120000_fix_missing_popup_columns_on_full_views.sql,
-- recurring: 20260924140000_add_missing_listing_report_link.sql added
-- missing_listing_report_id to restaurants/hotels/events (base tables) and
-- to restaurant_repository.dart/hotel_repository.dart's own
-- restaurantFullColumns/hotelFullColumns select lists, but never touched
-- restaurants_full/hotels_full themselves — those views have an explicit
-- column list, not `select r.*`/`select h.*`, so the new column was never
-- exposed through them.
--
-- Confirmed live in production (build 1.0.0+8): `select
-- missing_listing_report_id from restaurants_full` and the same against
-- hotels_full both throw `column "missing_listing_report_id" does not
-- exist` (42703) — every screen behind restaurantFullColumns/
-- hotelFullColumns broke (Explore, Trips, Wishlist, Map, Passport/Visited,
-- Restaurant/Hotel Detail). events wasn't affected — EventsRepository
-- queries the raw events table directly, no view involved.
--
-- Fix: append missing_listing_report_id to both views' SELECT lists.
-- CREATE OR REPLACE VIEW cannot change an existing output column's
-- ordinal position (42P16), so it goes at the very end, after
-- opening_weekdays — same constraint documented in
-- 20260918120000_fix_missing_popup_columns_on_full_views.sql. Nothing
-- else changes: same joins, same existing computed columns, same
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
  r.starts_on,
  r.ends_on,
  r.parent_venue_type,
  r.parent_venue_id,
  r.opening_weekdays,
  r.missing_listing_report_id
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
  h.starts_on,
  h.ends_on,
  h.parent_venue_type,
  h.parent_venue_id,
  h.opening_weekdays,
  h.missing_listing_report_id
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
