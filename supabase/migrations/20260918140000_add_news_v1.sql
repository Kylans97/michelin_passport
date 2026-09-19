-- News V1 — minimal: one table for articles, a public-read image bucket,
-- and a narrow open-tracking table with the same internal/shareable
-- two-view split venue_link_clicks already established
-- (20260829120000_add_venue_link_click_tracking.sql). Publishing itself
-- happens by hand via the Supabase dashboard (service_role) — no admin
-- screen, no insert/update policy for any client role.

begin;

-- ============================================================
-- 1. news_articles
-- ============================================================

create table public.news_articles (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  -- Plain text, paragraphs separated by a blank line — not real
  -- Markdown. The app splits on blank lines and renders each piece as
  -- its own paragraph; no bold/italic/link-in-text parsing exists.
  body         text not null,
  image_url    text,
  -- Matches events.official_url's own shape exactly — one optional
  -- outbound link, opened the same way (launchUrl, external browser).
  link_url     text,
  status       text not null default 'draft' check (status in ('draft', 'published')),
  -- Nullable on purpose — a draft may not have a date decided yet. But
  -- READ THIS BEFORE ASKING WHY AN ARTICLE ISN'T SHOWING: the public-read
  -- policy below requires published_at to be non-null AND in the past.
  -- Flipping status to 'published' while published_at is still null (or
  -- in the future) does not error and does not show the article — it
  -- just silently stays invisible to every reader until published_at is
  -- also set to a past timestamp. This is intentional (it's what makes
  -- "schedule ahead" possible at all), not a bug — but it means a
  -- forgotten published_at looks identical, from the dashboard, to a
  -- correctly scheduled future article. Always set both together.
  published_at timestamptz,
  created_at   timestamptz not null default now()
);

alter table public.news_articles enable row level security;

create policy news_articles_public_read on public.news_articles
  for select to anon, authenticated
  using (status = 'published' and published_at is not null and published_at <= now());

-- No insert/update/delete policy for anon or authenticated at all —
-- publishing happens by hand via the Supabase dashboard, as service_role
-- (bypasses RLS entirely), matching this project's "no admin screen"
-- decision for News V1.
grant select on public.news_articles to anon, authenticated;

-- ============================================================
-- 2. news-images storage bucket — mirrors catalogue-media exactly
--    (20260818150000_add_catalogue_media_storage.sql): public bucket,
--    one read policy (defence-in-depth only — Supabase serves public
--    bucket objects directly, without evaluating this policy), no
--    insert/update/delete policy for any client role. Uploads happen by
--    hand via the Supabase dashboard.
-- ============================================================

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'news-images',
  'news-images',
  true,
  10485760, -- 10 MiB per object
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy news_images_read on storage.objects
  for select to public
  using (bucket_id = 'news-images');

-- ============================================================
-- 3. news_article_opens — mirrors venue_link_clicks exactly: raw table
--    never selectable by any client role, self-attributed insert only.
-- ============================================================

create table public.news_article_opens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  article_id uuid not null references public.news_articles(id) on delete cascade,
  opened_at  timestamptz not null default now()
);

create index news_article_opens_article_idx
  on public.news_article_opens (article_id, opened_at desc);

alter table public.news_article_opens enable row level security;

-- Self-attributed insert only. No select/update/delete policy for anon
-- or authenticated at all — "deze data is van mij", same as
-- venue_link_clicks.
create policy news_article_opens_insert on public.news_article_opens
  for insert to authenticated
  with check (user_id = auth.uid());

grant insert on public.news_article_opens to authenticated;

create function public.news_article_open_min_unique_users()
returns integer
language sql
immutable
as $$ select 5; $$;

-- INTERNAL — per article per day, no suppression threshold. NEVER
-- SHAREABLE: a row can carry unique_readers as low as 1, which can
-- identify a single reader in a small enough audience. For the
-- operator's own use only.
create view public.news_article_open_stats_internal
with (security_invoker = false)
as
select
  article_id,
  (opened_at at time zone 'utc')::date as open_date,
  count(*)::integer                    as total_opens,
  count(distinct user_id)::integer     as unique_readers
from public.news_article_opens
group by article_id, (opened_at at time zone 'utc')::date
order by article_id, open_date desc;

revoke all on public.news_article_open_stats_internal from public;
revoke all on public.news_article_open_stats_internal from anon;
revoke all on public.news_article_open_stats_internal from authenticated;

-- SHAREABLE — per article per month, suppressed below 5 distinct
-- readers. THE ONLY ONE OF THESE TWO VIEWS THAT MAY EVER BE SHARED
-- EXTERNALLY.
create view public.news_article_open_stats_shareable
with (security_invoker = false)
as
select
  article_id,
  date_trunc('month', opened_at at time zone 'utc')::date as open_month,
  count(*)::integer                                       as total_opens,
  count(distinct user_id)::integer                        as unique_readers
from public.news_article_opens
group by article_id, date_trunc('month', opened_at at time zone 'utc')
having count(distinct user_id) >= public.news_article_open_min_unique_users()
order by article_id, open_month desc;

revoke all on public.news_article_open_stats_shareable from public;
revoke all on public.news_article_open_stats_shareable from anon;
revoke all on public.news_article_open_stats_shareable from authenticated;

-- Both views: read by the operator directly (service_role/dashboard),
-- never by the app — no grant to anon/authenticated on either, matching
-- venue_link_click_stats_internal/shareable exactly.

commit;
