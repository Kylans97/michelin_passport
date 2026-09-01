-- POP-UPS — is_expired for rankings, and a real sortable column for
-- search. Follows on from 20260829140000 (which added starts_on/ends_on/
-- parent_venue_type/parent_venue_id/opening_weekdays to restaurants/
-- hotels/private_chefs but touched no view).
--
-- ============================================================
-- ONE FORMULA, DEFINED ONCE PER BASE VIEW, REUSED EVERYWHERE
-- ============================================================
--
-- `is_expired` = `ends_on is not null and ends_on < current_date` —
-- added to restaurants_full/hotels_full (both already exist) and to a
-- new private_chefs_full (did not exist before this migration — see
-- below for why one is needed now). restaurant_rankings and venue_
-- community_rankings then SELECT that same computed column from
-- whichever _full view they already join, rather than recomputing the
-- formula a second time — one definition, not three copies that could
-- drift.
--
-- Rankings themselves are NOT filtered or re-ordered by is_expired —
-- "een pop-up die zes weken liep... verdient zijn plek in een ranking
-- over het afgelopen jaar" — every existing WHERE/HAVING/ORDER BY
-- clause in both views is untouched. is_expired is purely an additional
-- output column for a future screen to render a "closed" label from.
--
-- ============================================================
-- WHY A NEW private_chefs_full VIEW
-- ============================================================
--
-- Search needs SQL-side ordering ("sorteer in SQL, niet client-side" —
-- client-side re-sorting only works within one already-fetched page and
-- silently breaks the moment pagination exists). PostgREST's `.order()`
-- can only reference a real, named output column of the queried
-- relation — never an arbitrary computed expression inline. restaurants_
-- full/hotels_full already exist as that queryable relation for
-- Restaurant/Hotel search; private_chefs has never had an equivalent —
-- every PrivateChefRepository read queries the base table directly.
-- private_chefs_full is the minimal such view: every column private_
-- chefs already has, plus is_expired, nothing else added or changed.
-- `security_invoker = true`, matching restaurants_full/hotels_full's own
-- pattern exactly — private_chefs' own RLS (`publication_status =
-- 'published'` for anon/authenticated) is enforced automatically for the
-- querying role, not restated in the view itself, the same way
-- restaurants_full never restates restaurants_public_read's `using
-- (true)`.
--
-- ============================================================
-- SORT KEY — the boolean chosen after review, not ends_on directly
-- ============================================================
--
-- Ordering by raw `ends_on` (even NULLS FIRST) does not actually sort
-- "expired lower": a pop-up that closed a year ago has an EARLIER date
-- than one still running for months, so ascending order would rank the
-- long-expired one ABOVE the currently-active one. `is_expired` (a
-- boolean: false for permanent AND for a currently-running pop-up, true
-- only once ends_on has actually passed) sorts correctly regardless of
-- how far in the past or future any individual ends_on falls — it is
-- deliberately not "order by recency of closing," just "closed venues
-- last, open/permanent ones first."
--
-- PREPARED, NOT APPLIED.

begin;

-- ============================================================
-- 1. restaurants_full — add is_expired
-- ============================================================
-- Current definition confirmed via pg_get_viewdef against production
-- immediately before writing this, not reconstructed from migration
-- history — every existing column below is unchanged and in its
-- existing order; is_expired is the one new column, appended last.

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
  (r.ends_on is not null and r.ends_on < current_date) as is_expired
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null);

-- ============================================================
-- 2. hotels_full — add is_expired
-- ============================================================

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
  (h.ends_on is not null and h.ends_on < current_date) as is_expired
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

-- ============================================================
-- 3. private_chefs_full — new
-- ============================================================

create view public.private_chefs_full
  with (security_invoker = true)
  as
select
  pc.*,
  (pc.ends_on is not null and pc.ends_on < current_date) as is_expired
from public.private_chefs pc;

-- New object — not auto-exposed by default under this project's current
-- privilege configuration (see 20260828120000's own note on the
-- "new cloud default" for new entities). Explicit grant, matching
-- private_chefs' own effective public-read reach (governed underneath by
-- that table's own RLS via security_invoker, not widened here).
grant select on public.private_chefs_full to anon, authenticated;

-- ============================================================
-- 4. restaurant_rankings — reuse restaurants_full.is_expired
-- ============================================================
-- Unchanged WHERE/HAVING/ORDER BY — is_expired is an added output
-- column only.

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
  rf.is_expired
from aggregated a
join public.restaurants_full rf on rf.id = a.restaurant_id
where rf.status = 'open'
order by a.community_rating desc, a.total_visits desc, rf.name asc;

revoke all on public.restaurant_rankings from public;
revoke all on public.restaurant_rankings from anon;
revoke all on public.restaurant_rankings from authenticated;
grant select on public.restaurant_rankings to anon;
grant select on public.restaurant_rankings to authenticated;

-- ============================================================
-- 5. venue_community_rankings — reuse is_expired from each joined
--    _full view; private_chef branch now joins private_chefs_full
--    instead of private_chefs directly, for the same single-formula
--    reuse (and because private_chefs alone has no is_expired column
--    to select).
-- ============================================================
-- Unchanged WHERE/HAVING/ORDER BY (still bayesian_score/review_count/
-- name-driven) — is_expired is an added output column only, last in
-- each branch's SELECT list, matching the other views above.

create or replace view public.venue_community_rankings
with (security_invoker = false)
as
with recent_ratings as (
  select venue_type, venue_id, rating
  from public.venue_ratings
  where updated_at >= now() - interval '365 days'
),
global_mean as (
  select avg(rating)::numeric as c from recent_ratings
),
aggregated as (
  select
    venue_type,
    venue_id,
    avg(rating)::numeric as venue_mean,
    count(*)::integer as review_count
  from recent_ratings
  group by venue_type, venue_id
  having count(*) >= public.venue_ranking_min_reviews()
),
scored as (
  select
    a.venue_type,
    a.venue_id,
    a.review_count,
    round(a.venue_mean, 2) as community_rating,
    round(
      (a.review_count::numeric / (a.review_count + public.venue_ranking_bayesian_m())) * a.venue_mean
      + (public.venue_ranking_bayesian_m() / (a.review_count + public.venue_ranking_bayesian_m())) * gm.c,
      3
    ) as bayesian_score
  from aggregated a
  cross join global_mean gm
)
select
  'restaurant'::text as venue_type,
  rf.id              as venue_id,
  rf.name,
  rf.city_name       as city,
  rf.flag_emoji      as country_flag,
  s.community_rating,
  s.review_count,
  s.bayesian_score,
  rf.is_expired
from scored s
join public.restaurants_full rf on rf.id = s.venue_id and s.venue_type = 'restaurant'
where rf.status = 'open'
union all
select
  'hotel',
  hf.id,
  hf.name,
  hf.city_name,
  hf.flag_emoji,
  s.community_rating,
  s.review_count,
  s.bayesian_score,
  hf.is_expired
from scored s
join public.hotels_full hf on hf.id = s.venue_id and s.venue_type = 'hotel'
where hf.status = 'open'
union all
select
  'private_chef',
  pc.id,
  pc.display_name,
  pc.home_city,
  co.flag_emoji,
  s.community_rating,
  s.review_count,
  s.bayesian_score,
  pc.is_expired
from scored s
join public.private_chefs_full pc on pc.id = s.venue_id and s.venue_type = 'private_chef'
left join public.countries co on co.country_code = pc.home_country_code
where pc.publication_status = 'published'
order by bayesian_score desc, review_count desc, name asc;

revoke all on public.venue_community_rankings from public;
revoke all on public.venue_community_rankings from anon;
revoke all on public.venue_community_rankings from authenticated;
grant select on public.venue_community_rankings to anon;
grant select on public.venue_community_rankings to authenticated;

commit;
