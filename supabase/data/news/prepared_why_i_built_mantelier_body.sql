-- Replace the body of "Why I built Mantelier" with the product owner's new
-- text (given in chat, 2026-10-29). Title, image, link and published_at are
-- unchanged. The previous body is kept verbatim in
-- why_i_built_mantelier_body_before_20261029.txt.
--
-- Body format (20260918140000_add_news_v1.sql): plain text, paragraphs
-- separated by a blank line. The text's first line, the title, is already the
-- article's title, so it isn't repeated in the body; the signature is the last
-- paragraph.
--
-- One transaction; aborts unless the article still has its 2026-10-29 body.

begin;

do $$
begin
  if not exists (
    select 1 from public.news_articles
     where id = 'ee9af51e-eadc-4717-9ae7-117bb2c78b73'
       and title = 'Why I built Mantelier'
       and md5(body) = 'f988f36a7baf41dbe00478719051f360'
  ) then
    raise exception 'the article no longer has the body this file replaces -- re-check';
  end if;
end $$;

update public.news_articles
   set body = $body$As a kid, I always loved eating, especially eating out. Trying food from different countries, discovering new flavours and styles. As I got older, that curiosity only grew.

At 15, I started working at a café in the town where I grew up. I was a dishwasher, and I didn’t enjoy it at all. But working in hospitality sparked something.

That spark led to a job at Mise en Place, an agency that places students at hotels, restaurants, event venues and festivals. During that time my passion for hospitality grew, and at the end of the year I started at Hotel Management School Maastricht.

In my second year it was time for an internship. I wanted to combine the Spanish I had picked up during my gap year with my love for gastronomy and hospitality, so I joined Moments at the Mandarin Oriental, Barcelona, which held two Michelin stars at the time.

Within my first two months I found out that my skills were nowhere near two-star level. Still, I loved working at that level, learning and improving every day. We had an amazing team, in the dining room and in the kitchen, who worked incredibly hard to give every guest a wonderful evening.

In the years since, I’ve been lucky enough to dine and stay at a number of remarkable restaurants and hotels. And I kept coming back to the same questions. How do I hear about the special nights, like a guest chef in town for one evening, a winemaker dinner or a four-hands collaboration, before they’re sold out? And how do I hold on to those evenings afterwards and share them with friends and family?

That’s why I built Mantelier: a place to discover, plan and keep unique gastronomic experiences. Built for the chefs, sommeliers, hoteliers and front-of-house teams who create these moments, and for you, the guest lucky enough to experience them.

Kylan Scheepstra$body$
 where id = 'ee9af51e-eadc-4717-9ae7-117bb2c78b73';

commit;
