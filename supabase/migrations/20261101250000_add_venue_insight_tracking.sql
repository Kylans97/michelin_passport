-- VENUE INSIGHT TRACKING: the nine data points venues don't get yet.
-- Written 2026-11-02, asked for by the product owner ("laten we gewoon voor
-- al die 9 datapunten gaan"), after the list in
-- docs/Architecture/VENUE_INSIGHTS_AND_SUBSCRIPTIONS_PLAN.md §5.
--
--   1. Event ticket and website taps   app_usage_events, two new names
--   2. Where a page was opened from    a `source` on venue_page_opens and
--                                      app_usage_events (event_opened); for
--                                      a venue opened from a news article or
--                                      an event, which one (`source_id`)
--   3. What people search and filter   explore_signals: the cuisine, city,
--                                      country or venue a search matched,
--                                      and filter values. Never typed text
--                                      (decision 1, B then A).
--   4. Seen in lists                   entity_impressions, per member per
--                                      day per surface, via
--                                      record_impressions()
--   5. Reach of new-event notices      notifications.push_sent_at, set by
--                                      send-push; opens via source
--   6. Searches with no results        explore_signals, signal no_results
--   7. Changing their mind             event_intent_changes, written by a
--                                      trigger on event_attendance
--   8. Friends' influence, trip adds   the same trigger records whether a
--                                      friend was already Interested/Going;
--                                      trip adds already live in
--                                      planned_venues
--   9. Photos looked at                venue_photo_views
--
-- Same ownership model as every tracking table before it
-- (20261023200000): raw rows are insert-only for the member themself,
-- never selectable by any client role; only admin reports read them, and
-- those suppress every count of people under 5. Every user_id cascades
-- from profiles, so deleting an account deletes its rows.
--
-- 7 and 8 are server-side, so they record from the moment this applies,
-- for every build. 5's push_sent_at needs send-push redeployed. The rest
-- need an app build; older builds simply don't send them, which every
-- report reads as "no data before".
--
-- New SECURITY DEFINER functions, each with its own revoke from public,
-- anon below (CLAUDE.md): record_impressions, event_attendance_log_change,
-- admin_studio_venue_insights, admin_studio_search_report.

begin;

-- ============================================================
-- 1 + 2. app_usage_events: ticket/website taps, and a source
-- ============================================================

alter table public.app_usage_events
  drop constraint app_usage_events_event_name_check,
  add constraint app_usage_events_event_name_check check (event_name in (
    'screen_opened',
    'explore_search_performed',
    'explore_filter_applied',
    'event_opened',
    'ticket_link_opened',
    'event_website_opened'
  ));

-- The open-source vocabulary is AnalyticsOpenSource.wireName
-- (lib/core/analytics/analytics_properties.dart). Null: an older build,
-- or a route that doesn't say.
alter table public.app_usage_events
  add column source text check (source in (
    'explore', 'search', 'map', 'guides', 'rankings', 'events', 'passport',
    'wishlist', 'trips', 'friends', 'community', 'news', 'notifications',
    'push', 'venue', 'event', 'private_chefs', 'stays'
  ));

-- A tap on an event's ticket or website link names its event in the app
-- (SupabaseAnalyticsService refuses it otherwise), but not as a CHECK
-- here: event_id is `on delete set null`, so such a CHECK would refuse
-- deleting the event itself. Found testing this migration on a replay.

create index app_usage_events_event_idx
  on public.app_usage_events (event_id, event_name)
  where event_id is not null;

alter table public.venue_page_opens
  add column source text check (source in (
    'explore', 'search', 'map', 'guides', 'rankings', 'events', 'passport',
    'wishlist', 'trips', 'friends', 'community', 'news', 'notifications',
    'push', 'venue', 'event', 'private_chefs', 'stays'
  ));

-- The news article or event a venue page was opened from: which article
-- or event sent members to a venue it names. No foreign key, so deleting
-- an article or event never touches the opens it caused; a report simply
-- finds no title for it.
alter table public.venue_page_opens
  add column source_id uuid,
  add constraint venue_page_opens_source_id_shape
    check (source_id is null or source in ('news', 'event'));

-- ============================================================
-- 3 + 6. explore_signals
-- ============================================================
--
--   search_match  a finished search whose text named a known cuisine
--                 family, city, country or venue exactly — the entity is
--                 recorded, never the text. Nothing matched, no row.
--   filter        an Explore filter was set to a value.
--   no_results    a finished search returned nothing: one row per active
--                 filter and match, or a single row with no dimension.
--
-- `value` is an id, slug, code or enum name — never prose. The CHECK
-- refuses spaces, so typed text can't be stored here even by mistake.

create table public.explore_signals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  signal      text not null check (signal in ('search_match', 'filter', 'no_results')),
  dimension   text check (dimension in (
                'search_type', 'country', 'cuisine_family', 'restaurant_award',
                'hotel_keys', 'city', 'restaurant', 'hotel', 'event'
              )),
  value       text check (value ~ '^[A-Za-z0-9_-]{1,64}$'),
  occurred_at timestamptz not null default now(),
  constraint explore_signals_shape check (
    (dimension is null) = (value is null)
    and (dimension is not null or signal = 'no_results')
  )
);

create index explore_signals_idx
  on public.explore_signals (signal, dimension, occurred_at desc);

alter table public.explore_signals enable row level security;

create policy explore_signals_insert on public.explore_signals
  for insert to authenticated
  with check (user_id = auth.uid());

grant insert on public.explore_signals to authenticated;

-- ============================================================
-- 4. entity_impressions
-- ============================================================
--
-- A card that was shown in a list. One row per member, entity, surface
-- and day with a running count, so a long scroll is one row, not a
-- thousand. Written only through record_impressions(), which upserts.

create table public.entity_impressions (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null check (entity_type in ('restaurant', 'hotel', 'private_chef', 'event')),
  entity_id   uuid not null,
  surface     text not null check (surface in (
                'explore', 'search', 'map', 'guides', 'rankings', 'events',
                'wishlist', 'community', 'private_chefs'
              )),
  seen_on     date not null,
  seen_count  integer not null default 1 check (seen_count > 0),
  primary key (user_id, entity_type, entity_id, surface, seen_on)
);

create index entity_impressions_entity_idx
  on public.entity_impressions (entity_type, entity_id, seen_on desc);

alter table public.entity_impressions enable row level security;
-- No client policy at all: record_impressions() is the only way in.

-- p_items: [{"entity_type": "...", "entity_id": "...", "surface": "...",
-- "count": n}, ...], at most 500. A malformed item fails the whole call,
-- which the app ignores (tracking is best-effort).
create function public.record_impressions(p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > 500 then
    raise exception 'p_items must be an array of at most 500 items' using errcode = '22023';
  end if;

  insert into public.entity_impressions as i
    (user_id, entity_type, entity_id, surface, seen_on, seen_count)
  select v_uid, x.entity_type, x.entity_id, x.surface,
         (now() at time zone 'utc')::date, sum(greatest(1, least(coalesce(x.count, 1), 100)))
  from jsonb_to_recordset(p_items)
    as x(entity_type text, entity_id uuid, surface text, count integer)
  group by x.entity_type, x.entity_id, x.surface
  on conflict (user_id, entity_type, entity_id, surface, seen_on)
  do update set seen_count = i.seen_count + excluded.seen_count;
end;
$$;

revoke execute on function public.record_impressions(jsonb) from public, anon;
grant execute on function public.record_impressions(jsonb) to authenticated;

-- ============================================================
-- 5. notifications.push_sent_at
-- ============================================================
--
-- Set by send-push (service_role) once APNs accepted the push for at
-- least one of the member's devices. Null: no push went out (switched
-- off, no device, or before this column existed).

alter table public.notifications
  add column push_sent_at timestamptz;

create index notifications_event_notice_idx
  on public.notifications (subject_id)
  where type = 'followed_venue_event';

-- ============================================================
-- 7 + 8. event_intent_changes
-- ============================================================
--
-- event_attendance holds only the current Interested/Going, so a member
-- who leaves leaves no trace. This logs every change: from_status ->
-- to_status, null meaning "none". friend_signal records whether, at that
-- moment, an accepted friend already had the event as Interested or Going
-- with visibility 'friends' — the same rows the member could see. Never
-- which friend.

create table public.event_intent_changes (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  event_id      uuid not null references public.events(id) on delete cascade,
  from_status   text check (from_status in ('interested', 'going')),
  to_status     text check (to_status in ('interested', 'going')),
  friend_signal boolean not null default false,
  changed_at    timestamptz not null default now(),
  constraint event_intent_changes_is_change
    check (from_status is distinct from to_status)
);

create index event_intent_changes_event_idx
  on public.event_intent_changes (event_id, changed_at desc);

alter table public.event_intent_changes enable row level security;
-- No client policy: only the trigger below writes, only admin reports read.

create function public.event_attendance_log_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_event uuid;
  v_from text;
  v_to text;
  v_friend boolean := false;
begin
  if tg_op = 'DELETE' then
    v_user := old.user_id; v_event := old.event_id;
    v_from := old.status;  v_to := null;
  elsif tg_op = 'INSERT' then
    v_user := new.user_id; v_event := new.event_id;
    v_from := null;        v_to := new.status;
  else
    if new.status is not distinct from old.status then
      return null;
    end if;
    v_user := new.user_id; v_event := new.event_id;
    v_from := old.status;  v_to := new.status;
  end if;

  -- A cascade from a deleted account or event: nothing to log, and an
  -- insert pointing at the vanished row would fail the deletion itself.
  if not exists (select 1 from public.profiles where id = v_user)
     or not exists (select 1 from public.events where id = v_event) then
    return null;
  end if;

  if v_to is not null then
    select exists (
      select 1
      from public.event_attendance a
      join public.friendships f
        on f.status = 'accepted'
       and ((f.requester_id = v_user and f.addressee_id = a.user_id)
         or (f.addressee_id = v_user and f.requester_id = a.user_id))
      where a.event_id = v_event
        and a.user_id <> v_user
        and a.visibility = 'friends'
    ) into v_friend;
  end if;

  insert into public.event_intent_changes
    (user_id, event_id, from_status, to_status, friend_signal)
  values (v_user, v_event, v_from, v_to, v_friend);
  return null;
exception when others then
  -- Logging never blocks an Interested/Going change.
  raise warning 'event_attendance_log_change: %', sqlerrm;
  return null;
end;
$$;

revoke execute on function public.event_attendance_log_change() from public, anon;

create trigger event_attendance_log_change
  after insert or update of status or delete on public.event_attendance
  for each row execute function public.event_attendance_log_change();

-- ============================================================
-- 9. venue_photo_views
-- ============================================================
--
-- One row per published photo a member actually had on screen in a
-- venue's gallery, once per page visit. The cover counts too: it is
-- always seen, which makes it the baseline the others compare against.

create table public.venue_photo_views (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  venue_type text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id   uuid not null,
  photo_id   uuid not null,
  viewed_at  timestamptz not null default now()
);

create index venue_photo_views_venue_idx
  on public.venue_photo_views (venue_type, venue_id, viewed_at desc);

alter table public.venue_photo_views enable row level security;

create policy venue_photo_views_insert on public.venue_photo_views
  for insert to authenticated
  with check (user_id = auth.uid());

grant insert on public.venue_photo_views to authenticated;

-- ============================================================
-- Studio: one venue's new insights
-- ============================================================
--
-- Beside admin_studio_venue_report (20261101240000), not inside it, so
-- that function stays exactly what production runs. Same rules: admin
-- only, people not taps, every count under 5 null.

create function public.admin_studio_venue_insights(p_venue_type text, p_venue_id uuid)
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
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef') then
    raise exception 'unknown venue type' using errcode = '22023';
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
    select user_id, source, source_id, opened_at as at from public.venue_page_opens
    where venue_type = p_venue_type and venue_id = p_venue_id
  ),
  seen as (
    select user_id, surface, seen_on from public.entity_impressions
    where entity_type = p_venue_type and entity_id = p_venue_id
  ),
  sources as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'source', g.k, 'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (
      select coalesce(source, 'unknown') as k, count(distinct user_id) as n
      from opens where at >= now() - interval '90 days'
      group by 1
    ) g
  ),
  seen_monthly as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'month',     to_char(mo.m, 'YYYY-MM'),
      'seen_by',   public.studio_suppress((select count(distinct s.user_id) from seen s
                     where s.seen_on >= mo.m and s.seen_on < mo.m + interval '1 month')),
      'opened_by', public.studio_suppress((select count(distinct o.user_id) from opens o
                     where o.at >= mo.m and o.at < mo.m + interval '1 month'))
    ) order by mo.m), '[]'::jsonb) as doc
    from months mo
  ),
  seen_surfaces as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'surface', g.k, 'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (
      select surface as k, count(distinct user_id) as n
      from seen where seen_on >= current_date - 90
      group by 1
    ) g
  ),
  from_news as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'article_id', g.source_id, 'title', a.title, 'published_at', a.published_at,
      'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (
      select source_id, count(distinct user_id) as n
      from opens
      where source = 'news' and source_id is not null and at >= now() - interval '12 months'
      group by 1
    ) g
    join public.news_articles a on a.id = g.source_id
  ),
  from_events as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'event_id', g.source_id, 'name', e.name, 'start_date', e.start_date,
      'people', public.studio_suppress(g.n)
    ) order by g.n desc), '[]'::jsonb) as doc
    from (
      select source_id, count(distinct user_id) as n
      from opens
      where source = 'event' and source_id is not null and at >= now() - interval '12 months'
      group by 1
    ) g
    join public.events e on e.id = g.source_id
  ),
  searched as (
    select public.studio_suppress(count(distinct user_id)) as n
    from public.explore_signals
    where signal = 'search_match' and dimension = p_venue_type
      and value = p_venue_id::text and occurred_at >= now() - interval '90 days'
  ),
  photos as (
    select p.id, p.image_url, p.display_order
    from public.restaurant_photos p
    where p_venue_type = 'restaurant' and p.restaurant_id = p_venue_id
    union all
    select p.id, p.image_url, p.display_order
    from public.hotel_photos p
    where p_venue_type = 'hotel' and p.hotel_id = p_venue_id
    union all
    select p.id, p.image_url, p.display_order
    from public.private_chef_photos p
    where p_venue_type = 'private_chef' and p.private_chef_id = p_venue_id
  ),
  photos_doc as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'photo_id',  ph.id,
      'image_url', ph.image_url,
      'viewers',   public.studio_suppress((select count(distinct v.user_id)
                     from public.venue_photo_views v
                     where v.venue_type = p_venue_type and v.venue_id = p_venue_id
                       and v.photo_id = ph.id
                       and v.viewed_at >= now() - interval '12 months'))
    ) order by ph.display_order), '[]'::jsonb) as doc
    from photos ph
  ),
  trips_doc as (
    select jsonb_build_object(
      'added_12m', public.studio_suppress((select count(distinct user_id) from public.planned_venues
                     where entity_type = p_venue_type and entity_id = p_venue_id
                       and created_at >= now() - interval '12 months')),
      'upcoming',  public.studio_suppress((select count(distinct user_id) from public.planned_venues
                     where entity_type = p_venue_type and entity_id = p_venue_id
                       and status = 'planned' and start_date >= current_date))
    ) as doc
  ),
  own_events as (
    select e.id, e.name, e.start_date, e.timezone
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
    order by e.start_date desc nulls last
    limit 12
  ),
  events_doc as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'event_id',        oe.id,
      'name',            oe.name,
      'start_date',      oe.start_date,
      'ticket_tappers',  public.studio_suppress((select count(distinct u.user_id) from public.app_usage_events u
                           where u.event_name = 'ticket_link_opened' and u.event_id = oe.id)),
      'website_tappers', public.studio_suppress((select count(distinct u.user_id) from public.app_usage_events u
                           where u.event_name = 'event_website_opened' and u.event_id = oe.id)),
      'notified',        public.studio_suppress((select count(*) from public.notifications n
                           where n.type = 'followed_venue_event' and n.subject_id = oe.id)),
      'pushed',          public.studio_suppress((select count(*) from public.notifications n
                           where n.type = 'followed_venue_event' and n.subject_id = oe.id
                             and n.push_sent_at is not null)),
      'opened_from_notice', public.studio_suppress((select count(distinct u.user_id) from public.app_usage_events u
                           where u.event_name = 'event_opened' and u.event_id = oe.id
                             and u.source in ('push', 'notifications'))),
      'went_going',      public.studio_suppress((select count(distinct c.user_id) from public.event_intent_changes c
                           where c.event_id = oe.id and c.to_status = 'going')),
      'going_with_friend', public.studio_suppress((select count(distinct c.user_id) from public.event_intent_changes c
                           where c.event_id = oe.id and c.to_status = 'going' and c.friend_signal)),
      'changed_mind',    public.studio_suppress((select count(distinct c.user_id) from public.event_intent_changes c
                           where c.event_id = oe.id
                             and (c.to_status is null
                               or (c.from_status = 'going' and c.to_status = 'interested')))),
      -- Days between saying Going and the event's own date, as the
      -- median member; only once 5 or more said Going.
      'median_lead_days', (select case when count(distinct c.user_id) >= 5 then
                             percentile_disc(0.5) within group (
                               order by oe.start_date - (c.changed_at at time zone oe.timezone)::date)
                           end
                           from public.event_intent_changes c
                           where c.event_id = oe.id and c.to_status = 'going'
                             and oe.start_date is not null)
    ) order by oe.start_date desc nulls last), '[]'::jsonb) as doc
    from own_events oe
  )
  select jsonb_build_object(
    'tracking_since', '2026-11-02',
    'sources',        (select doc from sources),
    'seen_monthly',   (select doc from seen_monthly),
    'seen_surfaces',  (select doc from seen_surfaces),
    'searched_by_name', (select n from searched),
    'from_news',      (select doc from from_news),
    'from_events',    (select doc from from_events),
    'photos',         (select doc from photos_doc),
    'trips',          (select doc from trips_doc),
    'events',         (select doc from events_doc)
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.admin_studio_venue_insights(text, uuid) from public, anon;
grant execute on function public.admin_studio_venue_insights(text, uuid) to authenticated;

-- ============================================================
-- Studio: what members search for, market-wide
-- ============================================================
--
-- Cuisines, cities and countries only. Searches for one venue by name
-- stay in that venue's own report: across the market they would show one
-- venue how often members look for another.

create function public.admin_studio_search_report(p_days integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_since timestamptz;
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  v_since := now() - make_interval(days => greatest(1, least(coalesce(p_days, 90), 3650)));

  with
  sig as (
    select s.user_id, s.signal, s.dimension, s.value
    from public.explore_signals s
    where s.occurred_at >= v_since
      and (s.dimension is null
        or s.dimension in ('search_type', 'country', 'cuisine_family',
                           'restaurant_award', 'hotel_keys', 'city'))
  ),
  grouped as (
    select g.signal, g.dimension, g.value, g.n,
           case g.dimension
             when 'country' then (select c.name from public.countries c where c.country_code = g.value)
             when 'city' then (select c.name from public.cities c where c.id::text = g.value)
             when 'cuisine_family' then (select f.name from public.cuisine_families f where f.slug = g.value)
             else g.value
           end as label
    from (
      select signal, dimension, value, count(distinct user_id) as n
      from sig where dimension is not null
      group by 1, 2, 3
    ) g
  ),
  pick as (
    select signal, coalesce(jsonb_agg(jsonb_build_object(
      'dimension', dimension, 'value', value, 'label', label,
      'people', public.studio_suppress(n)
    ) order by n desc), '[]'::jsonb) as doc
    from (
      select *, row_number() over (partition by signal order by n desc) as rn
      from grouped
    ) r
    where rn <= 40
    group by signal
  )
  select jsonb_build_object(
    'tracking_since', '2026-11-02',
    'searchers',  public.studio_suppress((select count(distinct user_id) from public.app_usage_events
                    where event_name = 'explore_search_performed' and occurred_at >= v_since)),
    'no_results_people', public.studio_suppress((select count(distinct user_id) from sig
                    where signal = 'no_results')),
    'matches',    coalesce((select doc from pick where signal = 'search_match'), '[]'::jsonb),
    'filters',    coalesce((select doc from pick where signal = 'filter'), '[]'::jsonb),
    'no_results', coalesce((select doc from pick where signal = 'no_results'), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.admin_studio_search_report(integer) from public, anon;
grant execute on function public.admin_studio_search_report(integer) to authenticated;

commit;
