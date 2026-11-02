-- Phase 1 of docs/Architecture/VENUE_INSIGHTS_AND_SUBSCRIPTIONS_PLAN.md:
-- the admin dashboard on the website (site/studio). Written 2026-11-02.
--
-- One report function, admin_studio_report(p_days), returns everything
-- the dashboard shows for the last p_days days as one jsonb document:
-- headline numbers, weekly growth, screens, top venues, events and trip
-- destinations. Counts only, never a person — the same rule as Insights
-- in the app. Admin numbers are not suppressed below 5 (the plan, §3.3):
-- they are counts the operator may see; the suppression rule is for what
-- leaves Mantelier, and that is phase 2.
--
-- Who may call it: an admin whose session passed two-step sign-in.
-- is_admin() itself requires aal2 since 20261101220000; the aal check is
-- kept here, first, so a password-only session gets 'mfa_required'
-- rather than 'not_admin'.
--
-- Renumbered 2026-11-02 from 20261101220000 before it was ever applied
-- anywhere: 20261101220000_admins_require_two_step took that number on
-- main first. Same date and content otherwise.
--
-- admin_two_step_pending() tells the studio's sign-in, after the password
-- and before the code, whether this account is an admin still owing its
-- code — is_admin() is false at that point by design. It says only that,
-- and only about the caller.
--
-- No new table, no new tracking: it reads what the app already records.

create function public.admin_two_step_pending()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
     and coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2'
     and exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

revoke execute on function public.admin_two_step_pending() from public, anon;
grant execute on function public.admin_two_step_pending() to authenticated;

create function public.admin_studio_report(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days  integer := least(greatest(coalesce(p_days, 30), 1), 365);
  v_since timestamptz;
  v_weeks integer;
  v_result jsonb;
begin
  if coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'mfa_required' using errcode = '42501';
  end if;
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  v_since := now() - make_interval(days => v_days);
  v_weeks := least(greatest(ceil(v_days / 7.0)::integer, 4), 52);

  with
  -- Anyone who did anything recorded, per day.
  activity as (
    select user_id, occurred_at as at from public.app_usage_events
    union all
    select user_id, opened_at from public.venue_page_opens
    union all
    select user_id, clicked_at from public.venue_link_clicks
  ),
  overview as (
    select jsonb_build_object(
      'members',          (select count(*) from public.profiles),
      'new_members',      (select count(*) from public.profiles where created_at >= v_since),
      'active_members',   (select count(distinct user_id) from activity where at >= v_since),
      'visits',           (select count(*) from public.visits),
      'visits_in_period', (select count(*) from public.visits where visited_on >= (v_since at time zone 'utc')::date),
      'follows',          (select count(*) from public.follows_restaurants)
                        + (select count(*) from public.follows_hotels)
                        + (select count(*) from public.follows_private_chefs),
      'wishlist',         (select count(*) from public.wishlist),
      'trips',            (select count(*) from public.planned_trips),
      'managed_venues',   (select count(distinct restaurant_id) from public.venue_managers_restaurants where revoked_at is null)
                        + (select count(distinct hotel_id) from public.venue_managers_hotels where revoked_at is null)
                        + (select count(distinct private_chef_id) from public.venue_managers_private_chefs where revoked_at is null),
      'upcoming_events',  (select count(*) from public.events
                            where moderation_status = 'published'
                              and status = 'upcoming'
                              and coalesce(end_date, start_date) >= current_date)
    ) as doc
  ),
  weeks as (
    select generate_series(
      date_trunc('week', now()) - make_interval(weeks => v_weeks - 1),
      date_trunc('week', now()),
      interval '1 week'
    ) as week_start
  ),
  weekly as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'week',           to_char(w.week_start, 'YYYY-MM-DD'),
      'new_members',    (select count(*) from public.profiles p
                          where p.created_at >= w.week_start
                            and p.created_at <  w.week_start + interval '1 week'),
      'active_members', (select count(distinct a.user_id) from activity a
                          where a.at >= w.week_start
                            and a.at <  w.week_start + interval '1 week'),
      'members_total',  (select count(*) from public.profiles p
                          where p.created_at < w.week_start + interval '1 week')
    ) order by w.week_start), '[]'::jsonb) as doc
    from weeks w
  ),
  screens as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'screen', s.screen, 'opens', s.opens, 'members', s.members
    ) order by s.opens desc), '[]'::jsonb) as doc
    from (
      select screen, count(*) as opens, count(distinct user_id) as members
      from public.app_usage_events
      where event_name = 'screen_opened' and occurred_at >= v_since
      group by screen
    ) s
  ),
  explore as (
    select jsonb_build_object(
      'searches',        count(*) filter (where event_name = 'explore_search_performed'),
      'search_members',  count(distinct user_id) filter (where event_name = 'explore_search_performed'),
      'filters',         count(*) filter (where event_name = 'explore_filter_applied'),
      'filter_members',  count(distinct user_id) filter (where event_name = 'explore_filter_applied')
    ) as doc
    from public.app_usage_events
    where occurred_at >= v_since
  ),
  venue_opens as (
    select venue_type, venue_id, count(*) as opens, count(distinct user_id) as visitors
    from public.venue_page_opens
    where opened_at >= v_since
    group by venue_type, venue_id
  ),
  venue_taps as (
    select venue_type, venue_id,
           count(*) filter (where destination = 'website')    as website,
           count(*) filter (where destination = 'booking')    as booking,
           count(*) filter (where destination = 'phone')      as phone,
           count(*) filter (where destination = 'directions') as directions
    from public.venue_link_clicks
    where clicked_at >= v_since
    group by venue_type, venue_id
  ),
  venue_follows as (
    select 'restaurant'::text as venue_type, restaurant_id as venue_id, count(*) as follows
      from public.follows_restaurants where created_at >= v_since group by restaurant_id
    union all
    select 'hotel', hotel_id, count(*)
      from public.follows_hotels where created_at >= v_since group by hotel_id
    union all
    select 'private_chef', private_chef_id, count(*)
      from public.follows_private_chefs where created_at >= v_since group by private_chef_id
  ),
  venue_keys as (
    select venue_type, venue_id from venue_opens
    union
    select venue_type, venue_id from venue_taps
    union
    select venue_type, venue_id from venue_follows
  ),
  venue_rows as (
    select k.venue_type, k.venue_id,
           coalesce(o.opens, 0)      as opens,
           coalesce(o.visitors, 0)   as visitors,
           coalesce(t.website, 0)    as website,
           coalesce(t.booking, 0)    as booking,
           coalesce(t.phone, 0)      as phone,
           coalesce(t.directions, 0) as directions,
           coalesce(f.follows, 0)    as follows
    from venue_keys k
    left join venue_opens   o using (venue_type, venue_id)
    left join venue_taps    t using (venue_type, venue_id)
    left join venue_follows f using (venue_type, venue_id)
  ),
  top_venues as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'venue_type', v.venue_type,
      'venue_id',   v.venue_id,
      'name',       coalesce(r.name, h.name, pc.business_name, pc.display_name),
      'city',       coalesce(rc.name, hc.name, pc.home_city),
      'country',    coalesce(r.country_code, h.country_code, pc.home_country_code),
      'opens',      v.opens,
      'visitors',   v.visitors,
      'website',    v.website,
      'booking',    v.booking,
      'phone',      v.phone,
      'directions', v.directions,
      'follows',    v.follows
    ) order by v.opens desc, v.follows desc), '[]'::jsonb) as doc
    from (
      select * from venue_rows
      order by opens desc, follows desc, website + booking + phone + directions desc
      limit 20
    ) v
    left join public.restaurants   r  on v.venue_type = 'restaurant'   and r.id  = v.venue_id
    left join public.cities        rc on rc.id = r.city_id
    left join public.hotels        h  on v.venue_type = 'hotel'        and h.id  = v.venue_id
    left join public.cities        hc on hc.id = h.city_id
    left join public.private_chefs pc on v.venue_type = 'private_chef' and pc.id = v.venue_id
  ),
  event_rows as (
    select e.id, e.name, e.city, e.country_code, e.start_date,
           (select count(*) from public.app_usage_events u
             where u.event_name = 'event_opened' and u.event_id = e.id
               and u.occurred_at >= v_since)                                  as opens,
           (select count(*) from public.event_attendance a
             where a.event_id = e.id and a.status = 'interested')             as interested,
           (select count(*) from public.event_attendance a
             where a.event_id = e.id and a.status = 'going')                  as going,
           (select count(*) from public.event_confirmed_attendance c
             where c.event_id = e.id)                                         as attended
    from public.events e
    where e.moderation_status = 'published'
      and coalesce(e.end_date, e.start_date) >= (v_since at time zone 'utc')::date
  ),
  top_events as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'event_id',   x.id,
      'name',       x.name,
      'city',       x.city,
      'country',    x.country_code,
      'start_date', x.start_date,
      'opens',      x.opens,
      'interested', x.interested,
      'going',      x.going,
      'attended',   x.attended
    ) order by x.opens desc, x.going desc, x.interested desc), '[]'::jsonb) as doc
    from (
      select * from event_rows
      where opens + interested + going + attended > 0
      order by opens desc, going desc, interested desc
      limit 20
    ) x
  ),
  trip_countries as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'country', t.country_code, 'trips', t.trips
    ) order by t.trips desc, t.country_code), '[]'::jsonb) as doc
    from (
      select d.country_code, count(distinct d.trip_id) as trips
      from public.planned_trip_destinations d
      where coalesce(d.end_date, d.start_date, current_date) >= current_date
      group by d.country_code
    ) t
  )
  select jsonb_build_object(
    'days',            v_days,
    'generated_at',    now(),
    'overview',        (select doc from overview),
    'weekly',          (select doc from weekly),
    'screens',         (select doc from screens),
    'explore',         (select doc from explore),
    'top_venues',      (select doc from top_venues),
    'top_events',      (select doc from top_events),
    'trip_countries',  (select doc from trip_countries)
  ) into v_result;

  return v_result;
end;
$$;

-- CLAUDE.md: every new SECURITY DEFINER function revokes from public and
-- anon in the migration that creates it. The function checks is_admin()
-- and aal2 itself; authenticated keeps execute so an admin can call it.
revoke execute on function public.admin_studio_report(integer) from public, anon;
grant execute on function public.admin_studio_report(integer) to authenticated;
