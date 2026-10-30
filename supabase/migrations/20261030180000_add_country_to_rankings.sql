-- Country on the Community Rankings views, for the screen's Filters sheet.
--
-- Written 2026-10-30. NOT YET APPLIED — prepared for review; apply with
-- `supabase db push --linked` once the product owner approves.
--
-- Named after 20261030170000_add_venue_team.sql, the highest migration on
-- any branch when this was written.
--
-- Community Rankings (option B, chosen by the product owner 2026-10-30)
-- gets one Filters sheet: type, country, recognition. event_rankings
-- already carries country_code; restaurant_rankings and hotel_rankings
-- only had the flag emoji, which is a display value, not something to
-- filter on. This appends country_code as their last column — CREATE OR
-- REPLACE VIEW may only add columns at the end. Rows, order, thresholds
-- and grants are unchanged (CREATE OR REPLACE keeps existing grants);
-- 1.5.0 (18) and the current branch select named columns, so the extra
-- column is invisible to both. Each view body below is 20261030160000's,
-- verbatim, apart from the one appended column.
--
-- No function is created, so CLAUDE.md's SECURITY DEFINER revoke rule has
-- nothing to apply to.

-- 1. restaurant_rankings

create or replace view public.restaurant_rankings
with (security_invoker = false)
as
with per_user_rating as (
  select distinct on (v.user_id, v.entity_id)
    v.entity_id as restaurant_id,
    v.rating
  from public.visits v
  where v.entity_type = 'restaurant'
    and v.rating is not null
  order by v.user_id, v.entity_id, v.visited_on desc, v.id desc
),
aggregated as (
  select
    restaurant_id,
    round(avg(rating)::numeric, 2) as community_rating,
    count(*)::integer as total_visits
  from per_user_rating
  group by restaurant_id
  having count(*) >= 3
)
select
  rf.id as restaurant_id,
  rf.name,
  rf.city_name as city,
  rf.flag_emoji as country_flag,
  rf.michelin_stars,
  a.community_rating,
  a.total_visits,
  rf.is_expired,
  rf.worlds_50_best_rank,
  rf.card_photo_url,
  rf.card_focus_x,
  rf.card_focus_y,
  rf.card_zoom,
  rf.country_code
from aggregated a
join public.restaurants_full rf on rf.id = a.restaurant_id
where rf.status = 'open'
order by a.community_rating desc, a.total_visits desc, rf.name asc;

-- 2. hotel_rankings

create or replace view public.hotel_rankings
with (security_invoker = false)
as
with per_user_rating as (
  select distinct on (v.user_id, v.entity_id)
    v.entity_id as hotel_id,
    v.rating
  from public.visits v
  where v.entity_type = 'hotel'
    and v.rating is not null
  order by v.user_id, v.entity_id, v.visited_on desc, v.id desc
),
aggregated as (
  select
    hotel_id,
    round(avg(rating)::numeric, 2) as community_rating,
    count(*)::integer as total_stays
  from per_user_rating
  group by hotel_id
  having count(*) >= 3
)
select
  hf.id as hotel_id,
  hf.name,
  hf.city_name as city,
  hf.flag_emoji as country_flag,
  hf.michelin_keys,
  hf.worlds_50_best_rank,
  a.community_rating,
  a.total_stays,
  hf.is_expired,
  hf.card_photo_url,
  hf.card_focus_x,
  hf.card_focus_y,
  hf.card_zoom,
  hf.country_code
from aggregated a
join public.hotels_full hf on hf.id = a.hotel_id
where hf.status = 'open'
order by a.community_rating desc, a.total_stays desc, hf.name asc;
