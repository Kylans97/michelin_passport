-- Community Rankings for hotels and events, and recognition beyond stars.
--
-- Written 2026-10-30. Applied to production 2026-10-30 with
-- `supabase db push --linked`, at the product owner's request.
--
-- Named after 20261030150000_add_venue_team.sql, which another branch
-- (claude/venue-follow-team) already carries, so this sorts after it on
-- any replay whichever merges first. The two touch no common object.
--
-- Decided by the product owner on 2026-10-30: the community score for all
-- three venue kinds comes from the overall score members already give
-- (a visit's or stay's `rating`, a confirmed attendance's `rating`) — the
-- same source restaurant_rankings has used since 20260824120000 — and a
-- venue appears from 3 members with a score, the same threshold
-- restaurant_rankings already applies. The separate, still-unused
-- venue_ratings / venue_community_rankings pair (20260828120000) is left
-- exactly as it is.
--
-- 1. restaurant_rankings: unchanged rows and order. Five columns are
--    appended (CREATE OR REPLACE VIEW may only add columns at the end):
--    worlds_50_best_rank for the new recognition filter, and the card
--    photo + crop the rest of the app already shows. Build 1.5.0 (18)
--    selects named columns from this view, so appending is invisible to
--    it.
-- 2. hotel_rankings: restaurant_rankings' exact shape for stays — each
--    member's latest rated stay per hotel, averaged, from 3 members, open
--    hotels only.
-- 3. event_rankings: one confirmed attendance per member per event
--    (unique(event_id, user_id) already guarantees it), averaged, from 3
--    members, published and not-cancelled events only.
--
-- Privacy: like restaurant_rankings, both new views are owner-privileged
-- (security_invoker = false) so they can count rows RLS hides from any one
-- caller — that is the only way an aggregate can be computed at all
-- (FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md §7.1). They return only the
-- venue, its average and its count — never a user id, never a single
-- member's score — and nothing below 3 members. Unlike restaurant_rankings
-- (which also grants anon), they are readable by `authenticated` only:
-- the app reads them signed in, and anon has no use for them.
--
-- No function is created, so CLAUDE.md's SECURITY DEFINER revoke rule has
-- nothing to apply to; the views' own grants are set explicitly below.

-- ============================================================
-- 1. restaurant_rankings — append recognition and card photo
-- ============================================================

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
  rf.card_zoom
from aggregated a
join public.restaurants_full rf on rf.id = a.restaurant_id
where rf.status = 'open'
order by a.community_rating desc, a.total_visits desc, rf.name asc;

-- ============================================================
-- 2. hotel_rankings
-- ============================================================

create view public.hotel_rankings
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
  hf.card_zoom
from aggregated a
join public.hotels_full hf on hf.id = a.hotel_id
where hf.status = 'open'
order by a.community_rating desc, a.total_stays desc, hf.name asc;

revoke all on public.hotel_rankings from public;
revoke all on public.hotel_rankings from anon;
revoke all on public.hotel_rankings from authenticated;
grant select on public.hotel_rankings to authenticated;

-- ============================================================
-- 3. event_rankings
-- ============================================================

create view public.event_rankings
with (security_invoker = false)
as
with aggregated as (
  select
    a.event_id,
    round(avg(a.rating)::numeric, 2) as community_rating,
    count(*)::integer as total_attendees
  from public.event_confirmed_attendance a
  where a.rating is not null
  group by a.event_id
  having count(*) >= 3
)
select
  e.id as event_id,
  e.name,
  e.city,
  e.country_code,
  e.start_date,
  e.end_date,
  e.image_url,
  a.community_rating,
  a.total_attendees
from aggregated a
join public.events e on e.id = a.event_id
where e.moderation_status = 'published'
  and e.cancelled_at is null
order by a.community_rating desc, a.total_attendees desc, e.name asc;

revoke all on public.event_rankings from public;
revoke all on public.event_rankings from anon;
revoke all on public.event_rankings from authenticated;
grant select on public.event_rankings to authenticated;
