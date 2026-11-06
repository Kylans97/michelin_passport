-- NEWS CARD TITLE. Written 2026-11-06, asked for by the product owner for
-- the first real interview: the article keeps its full title
-- ("Fine Dining, Wherever You Are: A Conversation with Private Chef Lucas
-- de Jager"), while the card on the News tab, the private chef's page and
-- the band an article's photo shrinks to show a short one ("Fine Dining,
-- Wherever You Are").
--
-- news_articles.card_title: optional. When null, everything shows title,
-- exactly as before, so a build that doesn't read this column is
-- unaffected. Publishing stays by hand in the dashboard: no client write
-- policy, and the table's existing read policy and grants cover the new
-- column.
--
-- No new function, so no revoke is needed (CLAUDE.md).

begin;

alter table public.news_articles
  add column card_title text
    check (card_title is null or length(btrim(card_title)) > 0);

commit;
