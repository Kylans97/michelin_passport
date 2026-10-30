-- VENUE ACTION + APP USAGE TRACKING. Written 2026-10-30, at the product
-- owner's request ("how often people call venues, use directions, visit
-- the website, land on venue pages, which features are used most").
-- Before this, only website/booking taps (venue_link_clicks), news opens
-- and venue invites were stored; every other AnalyticsEvent went to
-- NoopAnalyticsService and was discarded.
--
-- Same ownership model as venue_link_clicks (20260829120000) and
-- news_article_opens (20260918140000), unchanged: raw tables are
-- insert-only for the signed-in user themself, never selectable by any
-- client role; the operator reads them with service_role. Only the
-- *_shareable views (monthly, suppressed below 5 distinct users) may ever
-- leave this database, and none is granted to a client role today.
--
-- Three parts:
--
-- 1. venue_link_clicks gains two destinations, 'phone' (the Call action)
--    and 'directions' (the Maps action), and a third source screen,
--    'private_chef_detail'. Widening a CHECK only — every existing row
--    (3 website rows in production on 2026-10-30) stays valid, and both
--    existing stats views already group by destination, so they report
--    the new destinations with no change of their own. The constraint
--    names are the ones production actually carries (queried 2026-10-30,
--    venue_link_clicks_destination_check / _source_screen_check).
--
-- 2. venue_page_opens — one row each time a Restaurant, Hotel or Private
--    Chef Detail screen is opened by a visitor. A manager's "Preview my
--    page" never writes here (isPreview gates it in the app).
--
-- 3. app_usage_events — the "which features are used" table. A short,
--    CHECK-constrained allowlist of event names and screens, never free
--    text: no search query, no filter value and no note is ever stored,
--    only the fact that a search or filter happened. Features that
--    already leave their own rows (visits, wishlist, follows,
--    event_attendance, planned_venues) are deliberately not duplicated
--    here — their own tables already count them.
--
-- Account deletion: every user_id cascades from profiles, as before.
--
-- No SECURITY DEFINER function is created here, so CLAUDE.md's
-- revoke-execute rule has nothing to apply to; the two threshold
-- functions are plain `language sql immutable`, same as their siblings.

begin;

-- ============================================================
-- 1. venue_link_clicks — phone and directions
-- ============================================================

alter table public.venue_link_clicks
  drop constraint venue_link_clicks_destination_check,
  add constraint venue_link_clicks_destination_check
    check (destination in ('website', 'booking', 'phone', 'directions'));

alter table public.venue_link_clicks
  drop constraint venue_link_clicks_source_screen_check,
  add constraint venue_link_clicks_source_screen_check
    check (source_screen in ('restaurant_detail', 'hotel_detail', 'private_chef_detail'));

-- ============================================================
-- 2. venue_page_opens
-- ============================================================

create table public.venue_page_opens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  venue_type text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id   uuid not null,
  opened_at  timestamptz not null default now()
);

create index venue_page_opens_venue_idx
  on public.venue_page_opens (venue_type, venue_id, opened_at desc);

alter table public.venue_page_opens enable row level security;

-- Self-attributed insert only. No select/update/delete policy for anon or
-- authenticated — "deze data is van mij", same as venue_link_clicks.
create policy venue_page_opens_insert on public.venue_page_opens
  for insert to authenticated
  with check (user_id = auth.uid());

grant insert on public.venue_page_opens to authenticated;

create function public.venue_page_open_min_unique_users()
returns integer
language sql
immutable
as $$ select 5; $$;

-- INTERNAL — per venue per day, no suppression threshold. NEVER
-- SHAREABLE: a row can carry unique_visitors as low as 1. For the
-- operator's own use only.
create view public.venue_page_open_stats_internal
with (security_invoker = false)
as
select
  venue_type,
  venue_id,
  (opened_at at time zone 'utc')::date as open_date,
  count(*)::integer                    as total_opens,
  count(distinct user_id)::integer     as unique_visitors
from public.venue_page_opens
group by venue_type, venue_id, (opened_at at time zone 'utc')::date
order by venue_type, venue_id, open_date desc;

revoke all on public.venue_page_open_stats_internal from public;
revoke all on public.venue_page_open_stats_internal from anon;
revoke all on public.venue_page_open_stats_internal from authenticated;

-- SHAREABLE — per venue per month, suppressed below 5 distinct visitors.
-- THE ONLY ONE OF THESE TWO VIEWS THAT MAY EVER BE SHARED EXTERNALLY
-- (e.g. a future "your page was viewed N times" for venue managers).
create view public.venue_page_open_stats_shareable
with (security_invoker = false)
as
select
  venue_type,
  venue_id,
  date_trunc('month', opened_at at time zone 'utc')::date as open_month,
  count(*)::integer                                       as total_opens,
  count(distinct user_id)::integer                        as unique_visitors
from public.venue_page_opens
group by venue_type, venue_id, date_trunc('month', opened_at at time zone 'utc')
having count(distinct user_id) >= public.venue_page_open_min_unique_users()
order by venue_type, venue_id, open_month desc;

revoke all on public.venue_page_open_stats_shareable from public;
revoke all on public.venue_page_open_stats_shareable from anon;
revoke all on public.venue_page_open_stats_shareable from authenticated;

-- ============================================================
-- 3. app_usage_events
-- ============================================================
--
-- event_name values are AnalyticsEvent.wireName exactly
-- (lib/core/analytics/analytics_event.dart); screen values are
-- AnalyticsScreen.wireName (analytics_properties.dart). Extend both
-- CHECKs alongside those enums, in a new migration.
--
--   screen_opened            a tab or a pushed screen became visible;
--                            `screen` says which (required)
--   explore_search_performed an Explore search ran (query text never
--                            stored)
--   explore_filter_applied   an Explore search filter changed (value
--                            never stored)
--   event_opened             Event Detail opened; event_id says which

create table public.app_usage_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  event_name  text not null check (event_name in (
                'screen_opened',
                'explore_search_performed',
                'explore_filter_applied',
                'event_opened'
              )),
  screen      text check (screen in (
                'explore', 'passport', 'news', 'community', 'profile',
                'events', 'guides', 'map', 'friends', 'friend_profile',
                'notifications', 'trip_detail'
              )),
  event_id    uuid references public.events(id) on delete set null,
  occurred_at timestamptz not null default now(),
  -- screen is required for screen_opened and meaningless for the rest.
  constraint app_usage_events_screen_shape check (
    (event_name = 'screen_opened') = (screen is not null)
  )
);

create index app_usage_events_name_idx
  on public.app_usage_events (event_name, occurred_at desc);

alter table public.app_usage_events enable row level security;

create policy app_usage_events_insert on public.app_usage_events
  for insert to authenticated
  with check (user_id = auth.uid());

grant insert on public.app_usage_events to authenticated;

-- INTERNAL ONLY — per event/screen per day. There is no shareable
-- sibling: app-wide feature use is the operator's own information, never
-- a venue's or partner's.
create view public.app_usage_stats_internal
with (security_invoker = false)
as
select
  event_name,
  screen,
  (occurred_at at time zone 'utc')::date as usage_date,
  count(*)::integer                      as total,
  count(distinct user_id)::integer       as unique_users
from public.app_usage_events
group by event_name, screen, (occurred_at at time zone 'utc')::date
order by usage_date desc, event_name, screen;

revoke all on public.app_usage_stats_internal from public;
revoke all on public.app_usage_stats_internal from anon;
revoke all on public.app_usage_stats_internal from authenticated;

commit;
