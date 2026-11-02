-- USAGE RETENTION: raw usage rows are kept for a fixed time, then only
-- anonymous monthly totals remain. Written 2026-11-02 at the product
-- owner's request, after the venue insight tracking (20261101250000)
-- multiplied what is recorded per member.
--
-- Before this, the privacy policy said usage records are kept "for as
-- long as your account exists". Now:
--   - entity_impressions (cards seen in lists): 13 months;
--   - every other raw usage table: 24 months.
-- Both cover everything Studio reads (12 months at most) with room to
-- spare. A month is removed only once it is entirely past the limit.
--
-- Before a month's rows go, prune_usage_records() writes its totals to
-- usage_monthly_totals: per metric, entity, detail and month, how many
-- rows and how many distinct members. No user id, so the totals are
-- not personal data and outlive account deletion. They are internal:
-- RLS on, no client policy or grant. Anything shown to a venue from them
-- must suppress people under 5, like every Studio report.
--
-- Not covered, on purpose: visits, wishlist, follows, event_attendance,
-- trips and confirmed attendance are the member's own content, kept for
-- as long as the account; venue_invite_events is part of the invite
-- record, not usage.
--
-- Runs monthly through pg_cron (already enabled, 20261101210000), on the
-- 2nd at 03:15 UTC. On production today (2026-11-02, queried) the
-- oldest usage row is from 2026-09-19, so nothing is deleted before
-- October 2028 (impressions, which start now, not before January 2028).
--
-- New SECURITY DEFINER function prune_usage_records(), with its revoke
-- from public, anon and authenticated below (CLAUDE.md): only cron calls
-- it.

begin;

create table public.usage_monthly_totals (
  metric      text not null,
  entity_type text,
  entity_id   uuid,
  detail      text,
  month       date not null,
  total       bigint not null,
  people      bigint not null,
  constraint usage_monthly_totals_key
    unique nulls not distinct (metric, entity_type, entity_id, detail, month)
);

alter table public.usage_monthly_totals enable row level security;
-- No policy for any client role, and the default table grants taken back
-- too: RLS alone already shows no rows, this makes it plain.
revoke all on public.usage_monthly_totals from public, anon, authenticated;

create function public.prune_usage_records()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cut_24 timestamptz := date_trunc('month', now()) - interval '24 months';
  v_cut_13 date := (date_trunc('month', now()) - interval '13 months')::date;
  v_deleted jsonb := '{}'::jsonb;
  v_n bigint;
begin
  -- venue_page_opens
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select 'venue_page_open', venue_type, venue_id, source,
         date_trunc('month', opened_at)::date, count(*), count(distinct user_id)
  from public.venue_page_opens where opened_at < v_cut_24
  group by 2, 3, 4, 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.venue_page_opens where opened_at < v_cut_24;
  get diagnostics v_n = row_count;
  v_deleted := v_deleted || jsonb_build_object('venue_page_opens', v_n);

  -- venue_link_clicks
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select 'venue_link_click', venue_type, venue_id, destination,
         date_trunc('month', clicked_at)::date, count(*), count(distinct user_id)
  from public.venue_link_clicks where clicked_at < v_cut_24
  group by 2, 3, 4, 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.venue_link_clicks where clicked_at < v_cut_24;
  get diagnostics v_n = row_count;
  v_deleted := v_deleted || jsonb_build_object('venue_link_clicks', v_n);

  -- app_usage_events: the event, per screen or source, per event
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select event_name, case when event_id is not null then 'event' end, event_id,
         coalesce(screen, source),
         date_trunc('month', occurred_at)::date, count(*), count(distinct user_id)
  from public.app_usage_events where occurred_at < v_cut_24
  group by 1, 2, 3, 4, 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.app_usage_events where occurred_at < v_cut_24;
  get diagnostics v_n = row_count;
  v_deleted := v_deleted || jsonb_build_object('app_usage_events', v_n);

  -- news_article_opens
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select 'news_article_open', 'news_article', article_id, null,
         date_trunc('month', opened_at)::date, count(*), count(distinct user_id)
  from public.news_article_opens where opened_at < v_cut_24
  group by 3, 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.news_article_opens where opened_at < v_cut_24;
  get diagnostics v_n = row_count;
  v_deleted := v_deleted || jsonb_build_object('news_article_opens', v_n);

  -- explore_signals: dimension:value, never anything typed (its CHECK)
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select 'explore_' || signal, null, null,
         case when dimension is null then null else dimension || ':' || value end,
         date_trunc('month', occurred_at)::date, count(*), count(distinct user_id)
  from public.explore_signals where occurred_at < v_cut_24
  group by 1, 4, 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.explore_signals where occurred_at < v_cut_24;
  get diagnostics v_n = row_count;
  v_deleted := v_deleted || jsonb_build_object('explore_signals', v_n);

  -- event_intent_changes: from>to, plus whether a friend had marked it
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select 'intent_change', 'event', event_id,
         coalesce(from_status, 'none') || '>' || coalesce(to_status, 'none')
           || case when friend_signal then ':friend' else '' end,
         date_trunc('month', changed_at)::date, count(*), count(distinct user_id)
  from public.event_intent_changes where changed_at < v_cut_24
  group by 3, 4, 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.event_intent_changes where changed_at < v_cut_24;
  get diagnostics v_n = row_count;
  v_deleted := v_deleted || jsonb_build_object('event_intent_changes', v_n);

  -- venue_photo_views: per photo
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select 'photo_view', venue_type, venue_id, photo_id::text,
         date_trunc('month', viewed_at)::date, count(*), count(distinct user_id)
  from public.venue_photo_views where viewed_at < v_cut_24
  group by 2, 3, 4, 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.venue_photo_views where viewed_at < v_cut_24;
  get diagnostics v_n = row_count;
  v_deleted := v_deleted || jsonb_build_object('venue_photo_views', v_n);

  -- entity_impressions: 13 months; total is the summed seen_count
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select 'impression', entity_type, entity_id, surface,
         date_trunc('month', seen_on)::date, sum(seen_count), count(distinct user_id)
  from public.entity_impressions where seen_on < v_cut_13
  group by 2, 3, 4, 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.entity_impressions where seen_on < v_cut_13;
  get diagnostics v_n = row_count;
  v_deleted := v_deleted || jsonb_build_object('entity_impressions', v_n);

  return v_deleted;
end;
$$;

revoke execute on function public.prune_usage_records() from public, anon, authenticated;

select cron.schedule(
  'prune-usage-records',
  '15 3 2 * *',
  'select public.prune_usage_records()'
);

commit;
