begin;

-- ============================================================
-- venue_invite_events — measurement only, kept separate from
-- venue_invites itself, mirroring how venue_link_clicks
-- (20260829120000) and news_article_opens (20260918140000) each got
-- their own focused migration alongside the feature they measure.
-- Written by SupabaseAnalyticsService only, via AnalyticsEvent.
-- venueInviteSent/Accepted/Declined — no second tracking mechanism.
-- ============================================================

create table public.venue_invite_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  invite_id   uuid not null references public.venue_invites(id) on delete cascade,
  action      text not null check (action in ('sent', 'accepted', 'declined')),
  venue_type  text not null check (venue_type in ('restaurant', 'hotel')),
  venue_id    uuid not null,
  created_at  timestamptz not null default now()
);

create index venue_invite_events_invite_idx on public.venue_invite_events (invite_id);

alter table public.venue_invite_events enable row level security;

create policy venue_invite_events_insert on public.venue_invite_events
  for insert to authenticated
  with check (user_id = auth.uid());

grant insert on public.venue_invite_events to authenticated;

-- Deliberately no select policy and no select grant for anon or
-- authenticated -- matches venue_link_clicks/news_article_opens exactly
-- ("deze data is van mij, niet van de gebruiker"). Read via
-- dashboard/service_role only.

commit;
