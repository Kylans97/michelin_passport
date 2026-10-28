-- Add each venue's World's 50 Best page URL, beside michelin_url.
--
-- Written 2026-10-28 (feature/guide-sources). The filename timestamp is a
-- sequence number, named after the highest migration on any branch at the
-- time (20261020120000_add_editorial_selection.sql, feature/editorial-
-- selection, unapplied when this was written), not a date.
--
-- Why: Restaurant/Hotel Detail link to a venue's MICHELIN page through
-- michelin_url and to its Gault&Millau page through
-- gault_millau_awards.gault_millau_url; nothing stored a World's 50 Best
-- page. Plan and findings: docs/Architecture/GUIDE_SOURCE_LINKS_PLAN.md.
--
-- A URL belongs to the venue, not to a ranking year, so it sits on
-- restaurants/hotels next to michelin_url rather than on worlds_50_best
-- rows. Like michelin_url it is nullable, sparse, UNIQUE, enrichment only
-- -- never identity, never a join key. Values come from the reviewed
-- staging files in supabase/data/enrichment/guide_source_links/, each
-- proven against our own rank history, phone, website or address; this
-- migration writes none of them.
--
-- Schema only. No new function, so no revoke is needed. Both views keep
-- every existing column in its existing position and only append the new
-- one, so create or replace is enough and installed builds, which select
-- named columns, are unaffected. Their bodies are the live production
-- definitions as of 2026-10-28 (pg_get_viewdef), schema-qualified.

begin;

alter table public.restaurants add column worlds_50_best_url text unique;
alter table public.hotels add column worlds_50_best_url text unique;

comment on column public.restaurants.worlds_50_best_url is
  'The restaurant''s own page on the World''s 50 Best site (the50.com), '
  'verified against our worlds_50_best rows, phone, website or address -- '
  'never built from the name. Nullable; enrichment only, never a join key. '
  'See supabase/data/enrichment/guide_source_links/.';
comment on column public.hotels.worlds_50_best_url is
  'The hotel''s own page on the World''s 50 Best site (the50.com), '
  'verified against our worlds_50_best_hotels rows, phone, website or '
  'address -- never built from the name. Nullable; enrichment only, never '
  'a join key. See supabase/data/enrichment/guide_source_links/.';

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
  exists (
    select 1 from public.worlds_50_best hof
    where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame'
  ) as is_hall_of_fame,
  r.phone,
  r.ends_on is not null and r.ends_on < current_date as is_expired,
  r.starts_on,
  r.ends_on,
  r.parent_venue_type,
  r.parent_venue_id,
  r.opening_weekdays,
  r.missing_listing_report_id,
  cover.image_url as cover_photo_url,
  cover.focus_x as cover_focus_x,
  cover.focus_y as cover_focus_y,
  cover.zoom as cover_zoom,
  card.image_url as card_photo_url,
  card.card_focus_x,
  card.card_focus_y,
  card.card_zoom,
  r.worlds_50_best_url
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null)
left join lateral (
  select rp.image_url, rp.focus_x, rp.focus_y, rp.zoom
  from public.restaurant_photos rp
  where rp.restaurant_id = r.id
  order by rp.display_order
  limit 1
) cover on true
left join lateral (
  select rp.image_url, rp.card_focus_x, rp.card_focus_y, rp.card_zoom
  from public.restaurant_photos rp
  where rp.restaurant_id = r.id
  order by rp.is_card desc, rp.display_order
  limit 1
) card on true;

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
  h.phone,
  h.worlds_50_best_url
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
