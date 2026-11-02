-- Studio's Basic and Pro tabs: what a venue would see on each subscription
-- tier (docs/Architecture/VENUE_INSIGHTS_AND_SUBSCRIPTIONS_PLAN.md §4).
-- Written 2026-11-02, asked for by the product owner to show venues the
-- future state in conversations, before any venue has access itself.
--
-- Three admin-only reports, all through is_admin() (aal2 since
-- 20261101220000):
--   admin_studio_find_venues(p_query)          — the venue picker.
--   admin_studio_venue_report(type, id)        — one venue: Basic and Pro.
--   admin_studio_market_report()               — Pro's market view.
--
-- Unlike the admin overview (20261101230000), these return numbers the
-- way a VENUE would see them: every count of people under 5 is null
-- ("fewer than 5"), so what the product owner shows in a conversation is
-- exactly what that venue could later be given — never more. Rating
-- averages follow Rankings' rule instead: shown from 3 raters.
--
-- Counts people, not taps: a month with 40 opens by 3 members is
-- "fewer than 5". Per month at the finest, never per day (plan §3.3).
--
-- What isn't measured yet (what people search for, where they found a
-- venue) isn't faked here: those panels are labelled as examples in the
-- studio until the tracking in plan §5 ships.

create function public.studio_suppress(n bigint)
returns bigint
language sql
immutable
as $$ select case when n is null or n < 5 then null else n end $$;

revoke execute on function public.studio_suppress(bigint) from public, anon;
grant execute on function public.studio_suppress(bigint) to authenticated;

-- ---------------------------------------------------------------- picker

create function public.admin_studio_find_venues(p_query text)
returns table (venue_type text, venue_id uuid, name text, city text, country text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_q text := nullif(trim(coalesce(p_query, '')), '');
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  if v_q is null or length(v_q) < 2 then
    return;
  end if;
  return query
  select x.venue_type, x.venue_id, x.name, x.city, x.country
  from (
    select 'restaurant'::text as venue_type, r.id as venue_id, r.name, c.name as city, r.country_code::text as country
    from public.restaurants r left join public.cities c on c.id = r.city_id
    where r.name ilike '%' || v_q || '%'
    union all
    select 'hotel', h.id, h.name, c.name, h.country_code::text
    from public.hotels h left join public.cities c on c.id = h.city_id
    where h.name ilike '%' || v_q || '%'
    union all
    select 'private_chef', p.id, coalesce(p.business_name, p.display_name), p.home_city, p.home_country_code::text
    from public.private_chefs p
    where coalesce(p.business_name, '') ilike '%' || v_q || '%'
       or p.display_name ilike '%' || v_q || '%'
  ) x
  order by (lower(x.name) = lower(v_q)) desc, x.name
  limit 20;
end;
$$;

revoke execute on function public.admin_studio_find_venues(text) from public, anon;
grant execute on function public.admin_studio_find_venues(text) to authenticated;

-- ------------------------------------------------------------ one venue

create function public.admin_studio_venue_report(p_venue_type text, p_venue_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_name text;
  v_city text;
  v_city_id uuid;
  v_country text;
  v_stars smallint;
  v_cuisine text;
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef') then
    raise exception 'unknown venue type' using errcode = '22023';
  end if;

  if p_venue_type = 'restaurant' then
    select r.name, c.name, r.city_id, r.country_code, r.michelin_stars, cu.name
      into v_name, v_city, v_city_id, v_country, v_stars, v_cuisine
    from public.restaurants r
    left join public.cities c on c.id = r.city_id
    left join public.cuisines cu on cu.id = r.cuisine_id
    where r.id = p_venue_id;
  elsif p_venue_type = 'hotel' then
    select h.name, c.name, h.city_id, h.country_code, null::smallint, null
      into v_name, v_city, v_city_id, v_country, v_stars, v_cuisine
    from public.hotels h left join public.cities c on c.id = h.city_id
    where h.id = p_venue_id;
  else
    select coalesce(p.business_name, p.display_name), p.home_city, null::uuid,
           p.home_country_code, null::smallint, null
      into v_name, v_city, v_city_id, v_country, v_stars, v_cuisine
    from public.private_chefs p where p.id = p_venue_id;
  end if;

  if v_name is null then
    raise exception 'venue not found' using errcode = 'P0002';
  end if;

  with
  months as (
    select generate_series(
      date_trunc('month', now()) - interval '11 months',
      date_trunc('month', now()),
      interval '1 month'
    ) as m
  ),
  opens as (
    select user_id, opened_at as at from public.venue_page_opens
    where venue_type = p_venue_type and venue_id = p_venue_id
  ),
  taps as (
    select user_id, destination, clicked_at as at from public.venue_link_clicks
    where venue_type = p_venue_type and venue_id = p_venue_id
  ),
  followers as (
    select user_id, created_at as at from public.follows_restaurants
      where p_venue_type = 'restaurant' and restaurant_id = p_venue_id
    union all
    select user_id, created_at from public.follows_hotels
      where p_venue_type = 'hotel' and hotel_id = p_venue_id
    union all
    select user_id, created_at from public.follows_private_chefs
      where p_venue_type = 'private_chef' and private_chef_id = p_venue_id
  ),
  saves as (
    select user_id, added_at as at from public.wishlist
    where entity_type = p_venue_type and entity_id = p_venue_id
  ),
  monthly as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'month',      to_char(mo.m, 'YYYY-MM'),
      'visitors',   public.studio_suppress((select count(distinct o.user_id) from opens o
                      where o.at >= mo.m and o.at < mo.m + interval '1 month')),
      'opens',      case when (select count(distinct o.user_id) from opens o
                      where o.at >= mo.m and o.at < mo.m + interval '1 month') >= 5
                      then (select count(*) from opens o
                      where o.at >= mo.m and o.at < mo.m + interval '1 month') end,
      'tappers',    public.studio_suppress((select count(distinct t.user_id) from taps t
                      where t.at >= mo.m and t.at < mo.m + interval '1 month')),
      'new_followers', public.studio_suppress((select count(distinct f.user_id) from followers f
                      where f.at >= mo.m and f.at < mo.m + interval '1 month')),
      'new_saves',  public.studio_suppress((select count(distinct s.user_id) from saves s
                      where s.at >= mo.m and s.at < mo.m + interval '1 month'))
    ) order by mo.m), '[]'::jsonb) as doc
    from months mo
  ),
  tap_kinds as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'destination', k.destination, 'people', public.studio_suppress(k.people)
    ) order by k.people desc), '[]'::jsonb) as doc
    from (
      select destination, count(distinct user_id) as people
      from taps where at >= now() - interval '12 months'
      group by destination
    ) k
  ),
  rating as (
    select count(distinct user_id) as raters, round(avg(rating)::numeric, 1) as avg
    from public.visits
    where entity_type = p_venue_type and entity_id = p_venue_id and rating is not null
  ),
  totals as (
    select jsonb_build_object(
      'followers',   public.studio_suppress((select count(distinct user_id) from followers)),
      'saves',       public.studio_suppress((select count(distinct user_id) from saves)),
      'visits',      public.studio_suppress((select count(distinct user_id) from public.visits
                       where entity_type = p_venue_type and entity_id = p_venue_id)),
      'visitors_12m', public.studio_suppress((select count(distinct user_id) from opens
                       where at >= now() - interval '12 months')),
      'tappers_12m', public.studio_suppress((select count(distinct user_id) from taps
                       where at >= now() - interval '12 months')),
      'rating',      (select case when raters >= 3 then avg end from rating),
      'raters',      (select case when raters >= 3 then raters end from rating)
    ) as doc
  ),
  own_events as (
    select e.id, e.name, e.start_date, e.city
    from public.events e
    where e.moderation_status = 'published'
      and (
        (p_venue_type = 'restaurant' and exists (select 1 from public.event_restaurants l
           where l.event_id = e.id and l.restaurant_id = p_venue_id and (l.is_host or l.is_venue)))
        or (p_venue_type = 'hotel' and exists (select 1 from public.event_hotels l
           where l.event_id = e.id and l.hotel_id = p_venue_id and (l.is_host or l.is_venue)))
        or (p_venue_type = 'private_chef' and exists (select 1 from public.event_chefs l
           where l.event_id = e.id and l.chef_id = p_venue_id and (l.is_host or l.is_venue)))
      )
  ),
  events_doc as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'name',       oe.name,
      'start_date', oe.start_date,
      'city',       oe.city,
      'viewers',    public.studio_suppress((select count(distinct u.user_id) from public.app_usage_events u
                      where u.event_name = 'event_opened' and u.event_id = oe.id)),
      'interested', public.studio_suppress((select count(*) from public.event_attendance a
                      where a.event_id = oe.id and a.status = 'interested')),
      'going',      public.studio_suppress((select count(*) from public.event_attendance a
                      where a.event_id = oe.id and a.status = 'going')),
      'attended',   public.studio_suppress((select count(*) from public.event_confirmed_attendance c
                      where c.event_id = oe.id))
    ) order by oe.start_date desc nulls last), '[]'::jsonb) as doc
    from (select * from own_events order by start_date desc nulls last limit 12) oe
  ),
  -- Pro: who the audience is. Anyone who opened the page in the last 12
  -- months or follows it.
  audience as (
    select distinct user_id from opens where at >= now() - interval '12 months'
    union
    select user_id from followers
  ),
  audience_country as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'country', g.k, 'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (
      select coalesce(p.home_country_code::text, 'none') as k, count(*) as n
      from audience a join public.profiles p on p.id = a.user_id
      group by 1
    ) g
  ),
  audience_age as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'age', g.k, 'people', public.studio_suppress(g.n)
    ) order by g.k), '[]'::jsonb) as doc
    from (
      select case
               when pp.birth_date is null then 'none'
               when extract(year from age(current_date, pp.birth_date)) < 25 then '16-24'
               when extract(year from age(current_date, pp.birth_date)) < 35 then '25-34'
               when extract(year from age(current_date, pp.birth_date)) < 45 then '35-44'
               when extract(year from age(current_date, pp.birth_date)) < 55 then '45-54'
               when extract(year from age(current_date, pp.birth_date)) < 65 then '55-64'
               else '65+'
             end as k,
             count(*) as n
      from audience a left join public.profile_private pp on pp.user_id = a.user_id
      group by 1
    ) g
  ),
  -- Pro: members planning a trip to this venue's city, and to its
  -- country, by month of arrival, next six months.
  trips as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'month',   to_char(mo.m, 'YYYY-MM'),
      'city',    case when v_city_id is null then null else public.studio_suppress((
                   select count(distinct t.user_id) from public.planned_trip_destinations d
                   join public.planned_trips t on t.id = d.trip_id
                   where d.city_id = v_city_id
                     and coalesce(d.start_date, t.start_date) >= mo.m
                     and coalesce(d.start_date, t.start_date) < mo.m + interval '1 month')) end,
      'country', public.studio_suppress((
                   select count(distinct t.user_id) from public.planned_trip_destinations d
                   join public.planned_trips t on t.id = d.trip_id
                   where d.country_code = v_country
                     and coalesce(d.start_date, t.start_date) >= mo.m
                     and coalesce(d.start_date, t.start_date) < mo.m + interval '1 month'))
    ) order by mo.m), '[]'::jsonb) as doc
    from (
      select generate_series(date_trunc('month', now()),
                             date_trunc('month', now()) + interval '5 months',
                             interval '1 month') as m
    ) mo
  ),
  -- Pro: this venue next to similar ones — same city and type; or, with
  -- fewer than 5 of those, same country, type and stars. Only a median,
  -- never another venue's own number, and only across 5 or more peers.
  peers as (
    select x.venue_id from (
      select r.id as venue_id, 'city' as grp from public.restaurants r
        where p_venue_type = 'restaurant' and r.city_id = v_city_id and r.id <> p_venue_id
      union all
      select h.id, 'city' from public.hotels h
        where p_venue_type = 'hotel' and h.city_id = v_city_id and h.id <> p_venue_id
    ) x
  ),
  peer_group as (
    select case when (select count(*) from peers) >= 5 then 'city' else 'country' end as grp
  ),
  peer_set as (
    select venue_id from peers where (select grp from peer_group) = 'city'
    union all
    select r.id from public.restaurants r
      where (select grp from peer_group) = 'country' and p_venue_type = 'restaurant'
        and r.country_code = v_country and r.id <> p_venue_id
        and r.michelin_stars is not distinct from v_stars
    union all
    select h.id from public.hotels h
      where (select grp from peer_group) = 'country' and p_venue_type = 'hotel'
        and h.country_code = v_country and h.id <> p_venue_id
  ),
  peer_visitors as (
    select ps.venue_id,
           (select count(distinct o.user_id) from public.venue_page_opens o
             where o.venue_type = p_venue_type and o.venue_id = ps.venue_id
               and o.opened_at >= now() - interval '90 days') as visitors
    from peer_set ps
  ),
  benchmark as (
    select jsonb_build_object(
      'group',      (select grp from peer_group),
      'peers',      (select count(*) from peer_visitors),
      'you',        public.studio_suppress((select count(distinct user_id) from opens
                      where at >= now() - interval '90 days')),
      'median',     case when (select count(*) from peer_visitors) >= 5
                      then (select percentile_cont(0.5) within group (order by visitors) from peer_visitors) end,
      'top_quarter', case when (select count(*) from peer_visitors) >= 5
                      then (select percentile_cont(0.75) within group (order by visitors) from peer_visitors) end
    ) as doc
  )
  select jsonb_build_object(
    'venue', jsonb_build_object(
      'type', p_venue_type, 'id', p_venue_id, 'name', v_name, 'city', v_city,
      'country', v_country, 'stars', v_stars, 'cuisine', v_cuisine),
    'basic', jsonb_build_object(
      'monthly',   (select doc from monthly),
      'taps',      (select doc from tap_kinds),
      'totals',    (select doc from totals),
      'events',    (select doc from events_doc)),
    'pro', jsonb_build_object(
      'audience_country', (select doc from audience_country),
      'audience_age',     (select doc from audience_age),
      'trips',            (select doc from trips),
      'benchmark',        (select doc from benchmark)),
    'generated_at', now()
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.admin_studio_venue_report(text, uuid) from public, anon;
grant execute on function public.admin_studio_venue_report(text, uuid) to authenticated;

-- --------------------------------------------------------------- market

create function public.admin_studio_market_report()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  with
  -- Interest in a restaurant: following it, saving it, or recording a
  -- visit. One person counts once per cuisine.
  interest as (
    select f.user_id, f.restaurant_id from public.follows_restaurants f
    union
    select w.user_id, w.entity_id from public.wishlist w where w.entity_type = 'restaurant'
    union
    select v.user_id, v.entity_id from public.visits v where v.entity_type = 'restaurant'
  ),
  by_cuisine as (
    select cu.name as cuisine, coalesce(p.home_country_code::text, 'none') as member_country,
           i.user_id
    from interest i
    join public.restaurants r on r.id = i.restaurant_id
    join public.cuisines cu on cu.id = r.cuisine_id
    join public.profiles p on p.id = i.user_id
  ),
  cuisines as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'cuisine', g.cuisine, 'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (select cuisine, count(distinct user_id) as n from by_cuisine
          group by cuisine order by n desc limit 15) g
  ),
  cuisine_country as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'member_country', g.member_country, 'cuisine', g.cuisine,
      'people', public.studio_suppress(g.n)
    ) order by g.member_country, g.n desc), '[]'::jsonb) as doc
    from (select member_country, cuisine, count(distinct user_id) as n
          from by_cuisine group by member_country, cuisine) g
  ),
  -- Where interest goes: restaurants' countries, by the member's home
  -- country ("members from Belgium look at restaurants in France").
  venue_country as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'member_country', g.member_country, 'venue_country', g.venue_country,
      'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (
      select coalesce(p.home_country_code::text, 'none') as member_country,
             r.country_code::text as venue_country,
             count(distinct i.user_id) as n
      from interest i
      join public.restaurants r on r.id = i.restaurant_id
      join public.profiles p on p.id = i.user_id
      group by 1, 2
    ) g
  ),
  event_interest as (
    select a.user_id, a.event_id from public.event_attendance a
    union
    select c.user_id, c.event_id from public.event_confirmed_attendance c
  ),
  event_types as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'type', g.k, 'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (select e.event_type as k, count(distinct ei.user_id) as n
          from event_interest ei join public.events e on e.id = ei.event_id
          group by e.event_type) g
  ),
  event_tags as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'tag', g.k, 'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (select t.name as k, count(distinct ei.user_id) as n
          from event_interest ei
          join public.event_tag_assignments ta on ta.event_id = ei.event_id
          join public.event_tags t on t.id = ta.tag_id
          group by t.name) g
  ),
  event_viewers as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'country', g.k, 'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (select e.country_code::text as k, count(distinct u.user_id) as n
          from public.app_usage_events u join public.events e on e.id = u.event_id
          where u.event_name = 'event_opened' and u.occurred_at >= now() - interval '12 months'
          group by e.country_code) g
  ),
  destinations as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'country', g.k, 'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (select d.country_code::text as k, count(distinct t.user_id) as n
          from public.planned_trip_destinations d join public.planned_trips t on t.id = d.trip_id
          where coalesce(d.end_date, d.start_date, t.end_date, t.start_date, current_date) >= current_date
          group by d.country_code) g
  )
  select jsonb_build_object(
    'cuisines',        (select doc from cuisines),
    'cuisine_country', (select doc from cuisine_country),
    'venue_country',   (select doc from venue_country),
    'event_types',     (select doc from event_types),
    'event_tags',      (select doc from event_tags),
    'event_viewers',   (select doc from event_viewers),
    'destinations',    (select doc from destinations),
    'generated_at',    now()
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.admin_studio_market_report() from public, anon;
grant execute on function public.admin_studio_market_report() to authenticated;
