-- Hotel phone parity with restaurants.phone.
--
-- Written 2026-10-28. Filename timestamp is a sequence number only (named
-- after the highest existing migration, 20261016120000), not this date.
--
-- 20260819120000_add_restaurant_phone.sql deliberately added `phone` to
-- restaurants only and named hotel parity as a separate follow-up; this is
-- that follow-up, prompted by user feedback asking for a phone number on
-- every World's 50 Best venue. Same shape, same reasoning:
--
--   - One nullable text column. No format constraint -- it must never
--     reject a legitimate international number. Stores the human-readable
--     international form (e.g. "+33 1 43 16 30 30"); the Flutter app
--     derives a tel: URI at call time via lib/core/utils/phone_utils.dart.
--   - hotels_full is redefined with CREATE OR REPLACE and `phone` appended
--     as the LAST output column, after card_zoom. Every existing
--     column keeps its name and ordinal position, so CREATE OR REPLACE is
--     legal and the view's existing grants are preserved (no drop view --
--     see the restaurant migration's header for why that matters). The
--     select list below is 20261015120000_add_venue_card_photo.sql's
--     hotels_full verbatim (the definition production runs today), plus
--     h.phone.
--   - No RLS change: hotels' table-level public-read select policy has no
--     column restriction, so it covers the new column like every other.
--     No client write grant -- this stays a service_role-managed catalogue
--     column, like website_url/michelin_url/google_place_id.
--
-- Deployment order: apply this BEFORE shipping a build whose
-- hotelFullColumns lists `phone` -- that build's explicit select would fail
-- against a hotels_full without the column. The reverse (column present,
-- old build not selecting it) is harmless.

begin;

alter table public.hotels add column phone text;

comment on column public.hotels.phone is
  'Official hotel phone number (main or reservations line, never a '
  'restaurant/spa line inside the hotel), human-readable international '
  'format (e.g. "+33 1 43 16 30 30"). Nullable. No format constraint. Not '
  'a URI -- the Flutter app derives a tel: URI from this at call time, see '
  'lib/core/utils/phone_utils.dart.';

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
  h.missing_listing_report_id,
  cover.image_url as cover_photo_url,
  cover.focus_x as cover_focus_x,
  cover.focus_y as cover_focus_y,
  cover.zoom as cover_zoom,
  card.image_url as card_photo_url,
  card.card_focus_x,
  card.card_focus_y,
  card.card_zoom,
  h.phone
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
 and w.year = (select max(year) from public.worlds_50_best_hotels where rank is not null)
left join lateral (
  select hp.image_url, hp.focus_x, hp.focus_y, hp.zoom
  from public.hotel_photos hp
  where hp.hotel_id = h.id
  order by hp.display_order
  limit 1
) cover on true
left join lateral (
  select hp.image_url, hp.card_focus_x, hp.card_focus_y, hp.card_zoom
  from public.hotel_photos hp
  where hp.hotel_id = h.id
  order by hp.is_card desc, hp.display_order
  limit 1
) card on true;

commit;
