-- Replace the text of "Why I built Mantelier" with the product owner's new
-- version (given in chat, 2026-11-06; verbatim in
-- why_i_built_mantelier_as_given_20261106.md), and its title with that
-- version's heading, "Why I Built Mantelier". Image, photos, links and published_at are
-- unchanged. The previous body is kept verbatim in
-- why_i_built_mantelier_body_before_20261106.txt.
--
-- Body format (20260918140000): plain text, paragraphs separated by a blank
-- line. The two bold lines ("That's why I built Mantelier." and the
-- signature) lose their ** markers, since the app shows the body as plain
-- text; the signature stays the last paragraph. 12 paragraphs, was 8; the
-- four small photos sit at after_paragraph 999, so they stay at the end.
--
-- One transaction; aborts unless the article still has its 2026-10-29 body.

begin;

do $$
begin
  if not exists (
    select 1 from public.news_articles
     where id = 'ee9af51e-eadc-4717-9ae7-117bb2c78b73'
       and title = 'Why I built Mantelier'
       and md5(body) = 'a4a8011110c5e6f79f4ffe469d30d82f'
  ) then
    raise exception 'the article no longer has the title and body this file replaces -- re-check';
  end if;
end $$;

update public.news_articles
   set title = $title$Why I Built Mantelier$title$,
       body = $body$As long as I can remember, I've always loved food. Especially eating out, discovering cuisines from different countries, and experiencing new flavors and styles. As I grew older, that curiosity only continued to grow.

When I was 15, I started working at a café in the town where I grew up. My first job was as a dishwasher, which, to be fair, I didn't particularly enjoy. But being surrounded by the world of hospitality sparked something in me.

That interest eventually led me to Mise en Place, an agency that places students in hotels, restaurants, event venues, and festivals. Working in so many different environments made my passion for hospitality grow even stronger. By the end of that year, I had decided to study at Hotel Management School Maastricht.

In my second year, it was time for an internship. I wanted to combine the Spanish I had learned during my gap year with my growing passion for gastronomy and hospitality. That's how I ended up at Moments, the two-Michelin-star restaurant at the Mandarin Oriental in Barcelona.

During my first two months, I quickly realized that my skills were nowhere near the level expected at a two-Michelin-star restaurant. Nevertheless, I loved being part of that world. Every day was an opportunity to learn, improve, and understand what it takes to create something truly special. I was fortunate to work alongside an incredible team, both in service and in the kitchen, who put so much dedication into giving every guest an unforgettable experience.

In the years that followed, I've been fortunate enough to dine at some extraordinary restaurants and stay in some wonderful hotels. Each experience was different, but many left memories that stayed with me long after I had left.

That got me thinking. What if there were a place where I could keep track of all these experiences? Somewhere to remember those special evenings, discover new places, plan future visits, and share it all with friends and family.

That's why I built Mantelier.

A place to discover, plan, and remember unique gastronomic and hospitality experiences.

Built with an appreciation for the people who make these experiences possible: the chefs, sommeliers, restaurant managers, hoteliers, and everyone working behind the scenes.

And, of course, for those of us fortunate enough to experience what they create.

Kylan Scheepstra$body$
 where id = 'ee9af51e-eadc-4717-9ae7-117bb2c78b73';

do $$
begin
  if (select md5(body) from public.news_articles
       where id = 'ee9af51e-eadc-4717-9ae7-117bb2c78b73') <> 'ab5d7c1f6a8a0f2346f3c1727274462c' then
    raise exception 'stored body differs from why_i_built_mantelier_body_20261106.txt';
  end if;
end $$;

commit;
