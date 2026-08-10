-- Expose the CURRENT (most recent ranked year's) World's 50 Best Hotels
-- rank on hotels_full, so Explore/Hotel Detail can read it the same way
-- restaurants_full already exposes worlds_50_best_rank for restaurants.
--
-- Prerequisite: this migration references public.worlds_50_best_hotels,
-- which does not exist until
-- 20260807160000_create_worlds_50_best_hotels.sql is applied first. Applying
-- this migration before that one fails outright (relation does not exist) —
-- that ordering dependency is deliberate, not accidental; see
-- phase9_deployment_order.md in the hotel catalogue expansion workspace for
-- the full verified deployment order.
--
-- Also exposes worlds_50_best_year (the year that current rank was earned)
-- -- restaurants_full does not expose an equivalent column, because no
-- restaurant surface currently displays "#4 · 2025"-style copy the way
-- Hotel Detail's award card does; hotels need it, so it's added here rather
-- than left implicit.
--
-- CREATE OR REPLACE VIEW requires the existing column list/order/types to
-- be preserved exactly -- and, critically, a CREATE OR REPLACE VIEW does
-- NOT layer on top of a previous CREATE OR REPLACE VIEW, it replaces the
-- whole definition. 20260807140000_add_venue_coordinates.sql independently
-- redefines this same view (to append latitude/longitude), and since these
-- two migrations may apply in either order relative to each other, this
-- migration's SELECT list includes THAT migration's columns too -- applying
-- both, in either order, converges on the same final view. Applying only
-- this one (coordinates migration not yet applied) is equally correct: the
-- st_y/st_x calls below are unconditional and don't depend on the other
-- migration having run.
--
-- PREPARED, NOT APPLIED. Do not run against any database until
-- hotelFullColumns (lib/data/repositories/hotel_repository.dart) is updated
-- to request these two columns in the same change -- see that file's
-- comment for why leaving hotelFullColumns unchanged after this migration
-- ships would be silently inert, not broken (Hotel.worlds50BestRank/Year
-- simply keep resolving to null), but updating hotelFullColumns before this
-- migration ships WOULD break every hotel-catalogue caller (PostgREST 42703).

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
  st_x(h.location::geometry)           as longitude,
  w.rank                               as worlds_50_best_rank,
  w.year                               as worlds_50_best_year
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
 and w.year = (
   select max(year) from public.worlds_50_best_hotels where rank is not null
 );
