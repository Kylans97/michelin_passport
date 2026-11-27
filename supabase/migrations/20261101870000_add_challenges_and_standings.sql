-- Challenges and standings among friends.
--
-- Written 2026-11-27. Product owner, 2026-11-27: "ik wil niet je eigen
-- doelen stellen. Ik wil dat er vaste doelen komen en dat je in een mooi
-- overzicht kan zien waar jij en je vrienden staan op de ranglijst van het
-- behalen van die doelen"; then "iedereen doet automatisch mee, prive
-- bezoeken tellen niet mee. En ja eens met 3" (start with one monthly, one
-- yearly and one open-ended challenge); and "kunnen we ergens ranglijsten
-- maken tussen vrienden met sterren restaurants bezocht, world 50 best
-- restaurants bezocht? Mantelier selection bezocht?".
--
--   * Challenges are fixed, set by Mantelier (rows in `challenges`; added
--     by hand or from Studio later, never by members). A monthly challenge
--     runs every calendar month, a yearly one every calendar year, an open
--     one until it is done.
--   * Everyone takes part. Only dated visits a member shares with friends
--     count (visibility 'friends'), in a ranking and in their own progress:
--     a private visit never counts anywhere, so a standing never reveals
--     one. The same place counts once per period.
--   * Rankings show the viewer and their accepted friends only.
--   * Standings: all-time counts among friends of MICHELIN-starred
--     restaurants (stars at the time of the visit), restaurants on the
--     current World's 50 Best list (1 to 100), and restaurants currently in
--     the Mantelier Selection.
--
-- Nothing here is written by a member: progress is computed on read.

begin;

-- ============================================================
-- 1. Challenges
-- ============================================================

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text not null,
  -- 'month' and 'year' repeat every calendar period (Europe/Amsterdam);
  -- 'open' runs from starts_on until done.
  cadence text not null check (cadence in ('month', 'year', 'open')),
  -- What is counted:
  --   'venues'    distinct restaurants or hotels matching the filters
  --   'countries' distinct countries of matching visits
  --   'all_of'    every restaurant currently matching the filters
  --               (target = how many there are now)
  metric text not null check (metric in ('venues', 'countries', 'all_of')),
  venue_kind text not null default 'any' check (venue_kind in ('restaurant', 'hotel', 'any')),
  -- Stars on the visit itself (visits.stars_at_visit), for 'venues'.
  min_stars_at_visit smallint check (min_stars_at_visit between 1 and 3),
  -- Stars the restaurant holds now, for 'all_of'.
  current_min_stars smallint check (current_min_stars between 1 and 3),
  country_codes text[],
  target integer check (target is null or target > 0),
  starts_on date not null default current_date,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint challenges_target_needed check (metric = 'all_of' or target is not null)
);

alter table public.challenges enable row level security;

create policy challenges_select on public.challenges
  for select to authenticated
  using (active);

revoke all on public.challenges from anon, authenticated;
grant select on public.challenges to authenticated;

insert into public.challenges
  (slug, title, description, cadence, metric, venue_kind, min_stars_at_visit,
   current_min_stars, country_codes, target, starts_on, sort_order)
values
  ('three-stars-a-month', 'Three stars this month',
   'Three MICHELIN-starred restaurants in one calendar month.',
   'month', 'venues', 'restaurant', 1, null, null, 3, date '2026-11-01', 10),
  ('five-countries-a-year', 'Five countries this year',
   'A restaurant or hotel in five different countries in one year.',
   'year', 'countries', 'any', null, null, null, 5, date '2026-01-01', 20),
  ('every-three-star-benelux', 'Every three-star in the Benelux',
   'Each three-star restaurant in Belgium, the Netherlands and Luxembourg.',
   'open', 'all_of', 'restaurant', null, 3, array['BE', 'NL', 'LU'], null,
   date '2026-01-01', 30);

-- ============================================================
-- 2. Who counts and what counts
-- ============================================================

-- The viewer and their accepted friends.
create function public.challenge_circle()
returns table (user_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() where auth.uid() is not null
  union
  select case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
    from public.friendships f
   where f.status = 'accepted'
     and auth.uid() in (f.requester_id, f.addressee_id);
$$;

revoke execute on function public.challenge_circle() from public, anon, authenticated;

-- The current period of a challenge, in the app's home timezone.
create function public.challenge_period(p_cadence text, p_starts_on date)
returns table (period_start date, period_end date)
language sql
stable
set search_path = public
as $$
  select case p_cadence
           when 'month' then date_trunc('month', (now() at time zone 'Europe/Amsterdam'))::date
           when 'year'  then date_trunc('year',  (now() at time zone 'Europe/Amsterdam'))::date
           else p_starts_on end,
         case p_cadence
           when 'month' then (date_trunc('month', (now() at time zone 'Europe/Amsterdam')) + interval '1 month - 1 day')::date
           when 'year'  then (date_trunc('year',  (now() at time zone 'Europe/Amsterdam')) + interval '1 year - 1 day')::date
           else null end;
$$;

revoke execute on function public.challenge_period(text, date) from public, anon, authenticated;

-- Every friends-visible, dated visit of the circle with what a challenge
-- needs to know about it.
create function public.challenge_visits()
returns table (
  user_id uuid, visited_on date, entity_type text, entity_id uuid,
  country_code text, stars_at_visit smallint, current_stars smallint
)
language sql
stable
security definer
set search_path = public
as $$
  select v.user_id, v.visited_on, v.entity_type, v.entity_id,
         coalesce(r.country_code, h.country_code),
         v.stars_at_visit::smallint,
         r.michelin_stars::smallint
    from public.visits v
    join public.challenge_circle() c on c.user_id = v.user_id
    left join public.restaurants r on v.entity_type = 'restaurant' and r.id = v.entity_id
    left join public.hotels h on v.entity_type = 'hotel' and h.id = v.entity_id
   where v.visibility = 'friends';
$$;

revoke execute on function public.challenge_visits() from public, anon, authenticated;

-- ============================================================
-- 3. A challenge's ranking
-- ============================================================

-- The viewer and their friends on one challenge, in its current period:
-- progress, the target, and the date the target was reached (the visit
-- that completed it). Finished first, then most progress, then earliest.
create function public.get_challenge_ranking(p_challenge_id uuid)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  is_me boolean,
  progress integer,
  target integer,
  completed_on date,
  rank integer
)
language sql
stable
security definer
set search_path = public
as $$
  with ch as (
    select c.*, p.period_start, p.period_end
      from public.challenges c
      cross join lateral public.challenge_period(c.cadence, c.starts_on) p
     where c.id = p_challenge_id and c.active and auth.uid() is not null
  ),
  goal as (
    select ch.id,
           case when ch.metric = 'all_of' then (
             select count(*)::integer from public.restaurants r
              where r.michelin_stars >= ch.current_min_stars
                and (ch.country_codes is null or r.country_code = any (ch.country_codes))
                and coalesce(r.status, 'open') = 'open'
           ) else ch.target end as target
      from ch
  ),
  hits as (
    -- One row per thing counted, with the first date it was reached.
    select v.user_id,
           case when ch.metric = 'countries' then v.country_code
                else v.entity_type || ':' || v.entity_id end as item,
           min(v.visited_on) as first_on
      from public.challenge_visits() v, ch
     where v.visited_on >= ch.period_start
       and (ch.period_end is null or v.visited_on <= ch.period_end)
       and (ch.venue_kind = 'any' or v.entity_type = ch.venue_kind)
       and (ch.min_stars_at_visit is null or coalesce(v.stars_at_visit, 0) >= ch.min_stars_at_visit)
       and (ch.current_min_stars is null or coalesce(v.current_stars, 0) >= ch.current_min_stars)
       and (ch.country_codes is null or v.country_code = any (ch.country_codes))
       and (ch.metric <> 'countries' or v.country_code is not null)
     group by 1, 2
  ),
  ordered as (
    select h.user_id, h.first_on,
           row_number() over (partition by h.user_id order by h.first_on, h.item) as n
      from hits h
  ),
  per_user as (
    select c.user_id,
           coalesce(max(o.n), 0)::integer as progress,
           min(o.first_on) filter (where o.n = g.target) as completed_on,
           g.target
      from public.challenge_circle() c
      cross join goal g
      left join ordered o on o.user_id = c.user_id
     group by c.user_id, g.target
  )
  select pu.user_id, p.username, p.display_name, p.avatar_url,
         pu.user_id = auth.uid(),
         least(pu.progress, pu.target),
         pu.target,
         pu.completed_on,
         (rank() over (order by (pu.completed_on is null), pu.completed_on,
                                least(pu.progress, pu.target) desc))::integer
    from per_user pu
    join public.profiles p on p.id = pu.user_id
   order by 9, p.display_name;
$$;

revoke execute on function public.get_challenge_ranking(uuid) from public, anon;
grant execute on function public.get_challenge_ranking(uuid) to authenticated;

-- The active challenges with their current period, for the overview.
create function public.get_challenges()
returns table (
  id uuid, slug text, title text, description text, cadence text,
  period_start date, period_end date, sort_order integer
)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, c.slug, c.title, c.description, c.cadence,
         p.period_start, p.period_end, c.sort_order
    from public.challenges c
    cross join lateral public.challenge_period(c.cadence, c.starts_on) p
   where c.active and auth.uid() is not null
     and c.starts_on <= current_date
   order by c.sort_order;
$$;

revoke execute on function public.get_challenges() from public, anon;
grant execute on function public.get_challenges() to authenticated;

-- ============================================================
-- 4. Standings
-- ============================================================

-- All-time counts among the viewer and their friends, from visits they
-- share with friends: 'stars' (restaurants starred at the time of the
-- visit), 'w50b' (restaurants on the current World's 50 Best list) and
-- 'selection' (restaurants in the Mantelier Selection now).
create function public.get_friend_standings(p_kind text)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  is_me boolean,
  total integer,
  rank integer
)
language sql
stable
security definer
set search_path = public
as $$
  with counted as (
    select v.user_id, count(distinct v.entity_id)::integer as total
      from public.challenge_visits() v
     where v.entity_type = 'restaurant'
       and case p_kind
             when 'stars' then coalesce(v.stars_at_visit, 0) >= 1
             when 'w50b' then exists (
               select 1 from public.worlds_50_best w
                where w.restaurant_id = v.entity_id
                  and w.rank between 1 and 100
                  and w.year = (select max(year) from public.worlds_50_best where rank is not null))
             when 'selection' then exists (
               select 1 from public.editorial_selections es
                where es.restaurant_id = v.entity_id and es.removed_on is null)
             else false
           end
     group by v.user_id
  )
  select c.user_id, p.username, p.display_name, p.avatar_url,
         c.user_id = auth.uid(),
         coalesce(k.total, 0),
         (rank() over (order by coalesce(k.total, 0) desc))::integer
    from public.challenge_circle() c
    join public.profiles p on p.id = c.user_id
    left join counted k on k.user_id = c.user_id
   where p_kind in ('stars', 'w50b', 'selection')
   order by 7, p.display_name;
$$;

revoke execute on function public.get_friend_standings(text) from public, anon;
grant execute on function public.get_friend_standings(text) to authenticated;

commit;
