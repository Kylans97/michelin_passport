-- NEWS SECTIONS AND PHOTOS. Written 2026-11-02, asked for by the product
-- owner: the News tab in three parts (Why Mantelier on top, then
-- Interviews, then Stories), and articles and interviews that can carry
-- more than one photo.
--
-- 1. news_articles.section: 'about', 'interview' or 'story' (the
--    default). At most one published 'about' article, the one that heads
--    the tab as "Why Mantelier". The one article on production today,
--    ee9af51e-eadc-4717-9ae7-117bb2c78b73 (queried 2026-11-02, keyed on
--    id, never on title), becomes it.
--
-- 2. news_article_photos: photos inside an article. after_paragraph says
--    where: 0 puts it before the first paragraph, n after paragraph n,
--    and anything past the end at the end. Two or more photos at the same
--    place show as one swipeable gallery, in display_order. The header
--    photo stays news_articles.image_url, unchanged.
--
-- The body stays plain text, paragraphs split on a blank line
-- (20260918140000). Two prefixes are now read by the app, and are plain
-- text to anything that doesn't know them:
--   "Q: "  the paragraph is an interviewer's question;
--   "> "   the paragraph is a pull quote.
--
-- Publishing stays by hand in the dashboard, as before: no client write
-- policy on either table. Photos are readable exactly when their article
-- is.

begin;

alter table public.news_articles
  add column section text not null default 'story'
    check (section in ('about', 'interview', 'story'));

create unique index news_articles_one_about
  on public.news_articles (section)
  where section = 'about' and status = 'published';

update public.news_articles
   set section = 'about'
 where id = 'ee9af51e-eadc-4717-9ae7-117bb2c78b73';

create table public.news_article_photos (
  id              uuid primary key default gen_random_uuid(),
  news_article_id uuid not null references public.news_articles(id) on delete cascade,
  image_url       text not null,
  caption         text,
  after_paragraph smallint not null default 0 check (after_paragraph >= 0),
  display_order   smallint not null default 0,
  focus_x         numeric not null default 0.5 check (focus_x between 0 and 1),
  focus_y         numeric not null default 0.5 check (focus_y between 0 and 1),
  created_at      timestamptz not null default now()
);

create index news_article_photos_article_idx
  on public.news_article_photos (news_article_id, after_paragraph, display_order);

alter table public.news_article_photos enable row level security;

create policy news_article_photos_public_read on public.news_article_photos
  for select to anon, authenticated
  using (exists (
    select 1 from public.news_articles a
    where a.id = news_article_id
      and a.status = 'published'
      and a.published_at is not null
      and a.published_at <= now()
  ));

revoke all on public.news_article_photos from public, anon, authenticated;
grant select on public.news_article_photos to anon, authenticated;

commit;
