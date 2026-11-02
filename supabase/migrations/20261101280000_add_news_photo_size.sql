-- NEWS PHOTO SIZE. Written 2026-11-02, asked for by the product owner:
-- photos that sit small at the foot of an article, with a credit, rather
-- than full width in the text.
--
-- news_article_photos.size: 'large' (the default, everything so far) or
-- 'small'. Small photos at the same place show as a row of small squares
-- that open full size on a tap; their captions, said once, sit under the
-- row. Large photos keep 20261101270000's behaviour exactly.

begin;

alter table public.news_article_photos
  add column size text not null default 'large'
    check (size in ('large', 'small'));

commit;
