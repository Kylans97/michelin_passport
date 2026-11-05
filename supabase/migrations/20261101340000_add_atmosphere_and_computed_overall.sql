-- ATMOSPHERE, AND OVERALL AS THE AVERAGE OF THE SCORES GIVEN. Written
-- 2026-11-04, asked for by the product owner: with hand-picked whole
-- numbers, several venues tie at the top of a ranking and the order says
-- nothing. Named after 20261101330000, the highest applied migration;
-- 20261101320000 on claude/event-expected-soldout is unapplied and still
-- has to be renamed past this one.
--
-- 1. visits.atmosphere_rating: restaurants only, by the product owner's
--    decision (hotels already have Experience). Same shape as every other
--    sub-rating: nullable smallint, 1-10, and NULL on a hotel row as
--    food_rating and wine_rating are.
--
-- 2. visits.rating becomes numeric(4,2) and is computed: the plain average
--    of the sub-ratings that are filled in, NULLs left out, so food alone
--    makes the overall that food score. The database computes it, so every
--    client gets one rule, including builds that still send a hand-picked
--    overall: when any sub-rating is present, whatever was sent is ignored.
--    Shipped builds read rating through (num?)?.toInt(), so until they are
--    gone they show 8.7 as 8; they cannot crash on it. Nothing filled in on
--    a shipped build's insert keeps the overall it sent, because there is
--    nothing to compute it from. Taking away the last sub-rating clears an
--    overall that was computed from them, unless the same write sets one.
--
-- 3. Existing rows with sub-ratings are recomputed, decided by the product
--    owner: one rule for the whole ranking. On production on 2026-11-04,
--    queried: 26 visits, 18 with an overall, all 18 with sub-ratings, 7 of
--    them moving by half a point or more. The other 8 have no scores at
--    all and stay NULL. This overwrites what members chose by hand; there
--    is no way back from the table itself.
--
-- restaurant_rankings and hotel_rankings depend on the column, so both are
-- dropped and recreated around the type change: each body is
-- 20261030180000's verbatim, and the grants are what production holds
-- today (queried 2026-11-04). They read rating through
-- round(avg(rating)::numeric, 2), which is unchanged by the new type.
-- admin_studio_venue_report reads it the same way; venue_ratings and event
-- attendance have their own rating and are untouched.
--
-- The trigger function is not SECURITY DEFINER: it only sets NEW on a row
-- the writer may already write.

begin;

alter table public.visits
  add column atmosphere_rating smallint
    constraint visits_atmosphere_rating_valid
    check (atmosphere_rating between 1 and 10);

drop view public.restaurant_rankings;
drop view public.hotel_rankings;

alter table public.visits
  alter column rating type numeric(4,2) using rating::numeric(4,2);

create function public.visits_compute_overall()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_average numeric;
  v_old_had_scores boolean;
begin
  select round(avg(s), 2) into v_average
  from unnest(array[
    new.food_rating, new.service_rating, new.wine_rating,
    new.atmosphere_rating, new.value_rating, new.room_rating,
    new.experience_rating
  ]) as s;

  if v_average is not null then
    new.rating := v_average;
  elsif tg_op = 'UPDATE' then
    v_old_had_scores := num_nonnulls(
      old.food_rating, old.service_rating, old.wine_rating,
      old.atmosphere_rating, old.value_rating, old.room_rating,
      old.experience_rating
    ) > 0;
    if v_old_had_scores and new.rating is not distinct from old.rating then
      new.rating := null;
    end if;
  end if;

  return new;
end;
$$;

create trigger visits_compute_overall
  before insert or update on public.visits
  for each row execute function public.visits_compute_overall();

-- Fires the trigger above on every row it can compute.
update public.visits
   set rating = rating
 where num_nonnulls(
         food_rating, service_rating, wine_rating, atmosphere_rating,
         value_rating, room_rating, experience_rating
       ) > 0;

create view public.restaurant_rankings
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
  hf.card_zoom,
  hf.country_code
from aggregated a
join public.hotels_full hf on hf.id = a.hotel_id
where hf.status = 'open'
order by a.community_rating desc, a.total_stays desc, hf.name asc;

revoke all on public.restaurant_rankings from public, anon, authenticated;
grant select on public.restaurant_rankings to anon, authenticated;
revoke all on public.hotel_rankings from public, anon, authenticated;
grant select on public.hotel_rankings to authenticated;

commit;
