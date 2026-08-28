-- VENUE LINK CLICK TRACKING — the narrow path only: one table, one
-- event, two aggregated reporting views. Not the general analytics
-- layer described in docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md
-- — that contract's `ticket_link_opened` is explicitly scoped to Event
-- ticket/booking destinations (§5 "Ticketing"), never a Restaurant/
-- Hotel's own website/booking_url link. This migration adds the
-- Venue-scoped sibling instead of overloading that event's meaning.
--
-- ============================================================
-- OWNERSHIP MODEL — "deze data is van mij, niet van de gebruiker"
-- ============================================================
--
-- The raw table (`venue_link_clicks`) is NEVER readable by any client
-- role, `anon` or `authenticated` — no select policy exists for either,
-- and no select GRANT is issued to either. Only the service role
-- (bypasses RLS entirely — the Supabase dashboard / SQL editor /
-- `supabase db query --linked`) can read it. This is a deliberate,
-- structural choice: the only way any data derived from this table
-- ever reaches anyone else is through the two aggregating views below
-- — never a promise to aggregate before sharing, but the actual, only
-- path that exists. Nothing granted here is a feature (no in-app
-- reporting screen is built by this migration); it is the groundwork
-- for a future one, built correctly the first time.
--
-- TWO VIEWS, ONE OF WHICH MAY EVER LEAVE THIS DATABASE:
--
-- `venue_link_click_stats_internal` — per venue/destination/DAY, NO
-- suppression threshold. This is the operator's own working view (a
-- day-level threshold made the data useless for that purpose: a venue
-- with 200 clicks spread evenly across a month never reaches 5 on any
-- single day, and would vanish entirely under a daily floor). NOT
-- GRANTED to anon/authenticated. **NEVER SHAREABLE** — every row can
-- carry a single-digit unique-user count, which is identifying.
--
-- `venue_link_click_stats_shareable` — per venue/destination/MONTH,
-- WITH `HAVING count(distinct user_id) >=
-- venue_link_click_min_unique_users()`. This is the only one of the
-- two views a future "share aggregated performance with a venue/
-- partner" feature may ever read from. NOT GRANTED to anon/
-- authenticated today either — building that read surface is a
-- separate, later decision — but when it happens, it grants against
-- THIS view and only this one. **THIS IS THE SHAREABLE VIEW** — read
-- both view definitions' own comments below before changing either;
-- a year from now, the name is the only thing standing between "safe
-- to export" and "not."
--
-- SUPPRESSION THRESHOLD (shareable view only): `HAVING count(distinct
-- user_id) >= venue_link_click_min_unique_users()` (5, mirroring
-- venue_ranking_min_reviews()'s exact one-place-to-change-it shape) —
-- a row with fewer than 5 distinct clickers is dropped entirely, not
-- shown with a small number. "One visitor from Amsterdam looked at
-- your restaurant" is identifying even in aggregate; omitting the row
-- is the only way to not say that. This is k-anonymity on each
-- reported row (venue + destination + month), not a formal
-- differential-privacy guarantee (e.g. no protection against an
-- external party differencing two overlapping exports against each
-- other) — matches exactly what was asked for, not more. The internal
-- view carries no such protection at all, which is precisely why it
-- must never be the one that's shared.
--
-- WHAT NEITHER VIEW EVER EXPOSES, even though the raw table has it:
--   - user_id — no individual is ever nameable from either view, by
--     construction (COUNT DISTINCT only, never the ids themselves).
--   - clicked_at at second precision — collapsed to `date` (internal)
--     or a month (shareable). The internal view's daily grain exists
--     for the operator's own working detail; it is not a privacy
--     control on that view (it has none — see above).
--   - event_id — even though the raw table records it (needed there:
--     "als de klik vanaf een event kwam"), a specific event id
--     combined with a small venue and a narrow period is itself a
--     re-identification risk. Never selected into either view.
--   - source_screen — omitted from both; it's fully redundant with
--     venue_type today (this migration only wires `venue_link_clicks`
--     from the restaurant and hotel detail screens, a strict 1:1
--     mapping), so it adds an identifying-looking column with no
--     reporting value. Stays on the raw table for the operator's own
--     debugging use.
--   - Any free-text field — there is none; this table has no notes/
--     comment/message column of any kind, so there is nothing of that
--     shape to omit, only to confirm was never added.
--
-- PREPARED, NOT APPLIED.

begin;

-- ============================================================
-- 1. VENUE_LINK_CLICKS — the raw table
-- ============================================================

create table public.venue_link_clicks (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  venue_type    text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id      uuid not null,
  -- Optional: set only when the click happened from an event context
  -- (e.g. a venue link surfaced on an Event Detail screen in the
  -- future) — null for the restaurant/hotel detail screens this
  -- migration actually wires up today.
  event_id      uuid references public.events(id) on delete set null,
  destination   text not null check (destination in ('website', 'booking')),
  -- Matches AnalyticsVenueDetailScreen's wire values exactly
  -- (lib/core/analytics/analytics_properties.dart) — only the two
  -- screens this migration wires tracking into exist today; extend
  -- this CHECK alongside that enum if a third screen is ever added.
  source_screen text not null check (source_screen in ('restaurant_detail', 'hotel_detail')),
  clicked_at    timestamptz not null default now()
);

-- Serves both "this venue's clicks in [date range]" (the view's own
-- query shape below) and the operator's own ad-hoc period queries
-- against the raw table directly.
create index venue_link_clicks_venue_idx
  on public.venue_link_clicks (venue_type, venue_id, clicked_at desc);

alter table public.venue_link_clicks enable row level security;

-- Self-attributed insert only — a user may only ever log a click as
-- themselves. No select/update/delete policy for anon or authenticated
-- at all — see this file's own header for why that's the whole point.
create policy venue_link_clicks_insert on public.venue_link_clicks
  for insert to authenticated
  with check (user_id = auth.uid());

grant insert on public.venue_link_clicks to authenticated;

-- ============================================================
-- 2. Named, adjustable suppression threshold
-- ============================================================

create function public.venue_link_click_min_unique_users()
returns integer
language sql
immutable
as $$ select 5; $$;

-- ============================================================
-- 3a. VENUE_LINK_CLICK_STATS_INTERNAL — operator's own working view
-- ============================================================
--
-- *** NEVER SHAREABLE. NOT SUPPRESSED. FOR THE OPERATOR'S OWN USE
-- ONLY. *** A row here can carry a unique_users count as low as 1 —
-- showing this to anyone outside is exactly the "one visitor from
-- Amsterdam looked at your restaurant" identification risk this
-- feature's own design exists to prevent. If a future feature ever
-- needs to read venue-link-click data for anyone other than the
-- operator, it reads §3b below — never this view.

create view public.venue_link_click_stats_internal
with (security_invoker = false)
as
select
  venue_type,
  venue_id,
  destination,
  (clicked_at at time zone 'utc')::date as click_date,
  count(*)::integer                     as total_clicks,
  count(distinct user_id)::integer      as unique_users
from public.venue_link_clicks
group by venue_type, venue_id, destination, (clicked_at at time zone 'utc')::date
order by venue_type, venue_id, destination, click_date desc;

revoke all on public.venue_link_click_stats_internal from public;
revoke all on public.venue_link_click_stats_internal from anon;
revoke all on public.venue_link_click_stats_internal from authenticated;

-- ============================================================
-- 3b. VENUE_LINK_CLICK_STATS_SHAREABLE — the only one of these two
--     views that may ever leave this database
-- ============================================================
--
-- *** THIS IS THE SHAREABLE VIEW. *** Monthly grain, and every row
-- with fewer than venue_link_click_min_unique_users() distinct
-- clickers is dropped entirely (not shown, not zeroed — absent). A
-- future "share aggregated performance with a venue/partner" feature
-- grants SELECT against this view specifically, never the raw table
-- and never §3a above.

create view public.venue_link_click_stats_shareable
with (security_invoker = false)
as
select
  venue_type,
  venue_id,
  destination,
  date_trunc('month', clicked_at at time zone 'utc')::date as click_month,
  count(*)::integer                                        as total_clicks,
  count(distinct user_id)::integer                          as unique_users
from public.venue_link_clicks
group by venue_type, venue_id, destination, date_trunc('month', clicked_at at time zone 'utc')
having count(distinct user_id) >= public.venue_link_click_min_unique_users()
order by venue_type, venue_id, destination, click_month desc;

-- Not granted today either (see this file's header) — kept explicit
-- and separate from the internal view's own revoke block above so
-- each view's access grant is independently auditable, never implied
-- by "the other one is also locked down."
revoke all on public.venue_link_click_stats_shareable from public;
revoke all on public.venue_link_click_stats_shareable from anon;
revoke all on public.venue_link_click_stats_shareable from authenticated;

commit;
