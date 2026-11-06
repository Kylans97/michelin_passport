-- Publish the first real interview: private chef Lucas de Jager
-- (private_chefs 2e2089b0-f94d-46f5-923b-4ebf9135a5a1, slug lucas-de-jager),
-- and remove the three placeholder articles it replaces.
-- Written 2026-11-06 at the product owner's request. Text as given in chat
-- (interview_as_given_20261106.md), converted to the app's body format in
-- body_20261106.txt: "## " questions became "Q: ", the two quotes became
-- "> " paragraphs without their bold and their "— Lucas de Jager" line,
-- since a quote is one paragraph in the app, and the italic introduction
-- became the first paragraph, which an interview shows as its lead.
--
-- Needs, in this order, before it runs:
--   1. 20261101380000_add_news_card_title.sql on production;
--   2. the five photos in news-images/lucas-de-jager/ (UPLOAD.md).
-- It checks both and aborts otherwise.
--
-- Photo places (after_paragraph counts the body's 46 paragraphs, 1-based
-- "after paragraph n"): the dish with wine after the Parkheuvel answer
-- ("It wasn't for nothing...", 15), the table after the evenings answer
-- ("For me, those are...", 23), Lucas at work after "That's one of the
-- best parts..." (37), the dish with the green sauce at the end (46).
-- The header is his portrait, focus 0.5/0.25 so the band keeps his face.
--
-- The placeholders cccccccc-...-0001/2/3 are deleted, as the changelog
-- entry that added them on 2026-11-02 says; ON DELETE CASCADE takes their
-- 4 photo rows and their 20 news_article_opens rows (opens of placeholder
-- content, counted 2026-11-06) with them.
--
-- One transaction; every check aborts the whole thing.

begin;

do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'news_articles'
       and column_name = 'card_title'
  ) then
    raise exception 'news_articles.card_title is missing -- apply 20261101380000 first';
  end if;
  if not exists (
    select 1 from public.private_chefs
     where id = '2e2089b0-f94d-46f5-923b-4ebf9135a5a1'
       and slug = 'lucas-de-jager' and display_name = 'Lucas de Jager'
       and publication_status = 'published'
  ) then
    raise exception 'private chef 2e2089b0-f94d-46f5-923b-4ebf9135a5a1 is not the published Lucas de Jager -- re-check';
  end if;
  if exists (select 1 from public.news_articles where id = '699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd') then
    raise exception 'article 699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd already exists';
  end if;
  if (
    select count(*) from storage.objects
     where bucket_id = 'news-images'
       and name in ('lucas-de-jager/portrait.jpg', 'lucas-de-jager/dish-with-wine.jpg', 'lucas-de-jager/table.jpg', 'lucas-de-jager/at-work.jpg', 'lucas-de-jager/dish-with-sauce.jpg')
  ) <> 5 then
    raise exception 'not all five photos are in news-images/lucas-de-jager/ -- upload first';
  end if;
  if (
    select count(*) from public.news_articles
     where id in ('cccccccc-0000-0000-0000-000000000001',
                  'cccccccc-0000-0000-0000-000000000002',
                  'cccccccc-0000-0000-0000-000000000003')
       and title like 'Example %'
  ) <> 3 then
    raise exception 'the three placeholders are not as expected -- re-check';
  end if;
end $$;

insert into public.news_articles
  (id, section, status, published_at, title, card_title, body,
   image_url, focus_x, focus_y)
values (
  '699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd', 'interview', 'published', now(),
  $title$Fine Dining, Wherever You Are: A Conversation with Private Chef Lucas de Jager$title$,
  $card$Fine Dining, Wherever You Are$card$,
  $body$Lucas started out front of house at Parkheuvel in Rotterdam, discovered his passion for cooking, and now brings fine dining to a variety of settings as a private chef. From intimate dinners at home to unique locations, we talked about his love for gastronomy, the personal nature of private dining, and the unforgettable moments that make his work so special.

Q: When did you know cooking was your passion?

Honestly, I've always been passionate about cooking, good food, and pairing beautiful dishes with the right wines.

As a child, I'd already be looking forward to it in the morning if we were going out for dinner that evening. I'd study the menu beforehand and work out what I wanted to order, so that on the night itself I wouldn't make the wrong choice.

At home we're true bon vivants, and I grew up with that love of good food and drink from a very young age.

Still, when you're young you also know that hospitality doesn't always have the kindest working hours. So at first I decided to go in another direction and study. I soon found out that studying wasn't really for me. I'm quite restless by nature, and I love being busy.

In the end I realised my passion really did lie in hospitality, and I decided to go for it.

Q: You started front of house at Parkheuvel and moved into the kitchen. Why the switch, and what did you learn there that you still use as a chef?

Through a friend of my father's, I got in touch with Erik van Loo, the owner and chef of Restaurant Parkheuvel in Rotterdam.

I started there front of house, because waiting tables had always been my side job. At Parkheuvel I discovered what is really possible with food, and how much craft, knowledge and passion goes into working with beautiful produce.

I started cooking more and more myself, and soon noticed my interest moving towards the kitchen. At some point, working front of house became a little monotonous for me. I wanted to learn more about the produce, the preparations and the techniques behind the dishes.

I asked the cooks an enormous number of questions, and that's how, step by step, I grew into the chef I am today.

One of the most important things I took from Parkheuvel is the importance of a good sauce. To this day I give it a great deal of attention and time.

You can have a magnificent piece of meat, but if the sauce doesn't carry the dish, the quality of that meat never fully comes into its own.

It wasn't for nothing that Erik van Loo was known among chefs as the 'King of Sauces'. I bring that philosophy into my own kitchen every single day.

Q: You cook in people's homes. What kinds of guests and evenings have you had, and which one has really stayed with you?

The lovely thing about my work is that I get to come into so many different people's homes. Every evening, every group and every occasion is different.

With some people you click straight away, with others a little less, but that's part of it. What I find especially lovely is that people are always incredibly hospitable and sociable. After all, they're opening their own home and kitchen to someone they often don't know at all.

What has stayed with me most are the dinners I've been able to cook, more than once, for people who are terminally ill.

Often they're no longer able to go to a restaurant themselves, while they'd still dearly love to share a special culinary experience with the people closest to them.

Being allowed into someone's home at a moment like that, to make it a special evening, means an enormous amount to me.

It touches me as a person, and it shows me that my work is about far more than just cooking well. You can give people something worth remembering at a particular moment in their lives.

For me, those are without a doubt the most special evenings.

> “You can give people something worth remembering at a particular moment in their lives.”

Q: Who would you still love to host a private dinner for one day?

Of course, it would be incredibly special to cook for the King one day!

Beyond that, I don't really have a wish list of famous people I'd like to cook a private dinner for.

For me, what matters is that every guest gets the same special experience, whoever is sitting at the table.

Whether I'm cooking for a family with something to celebrate, a group of friends, or perhaps one day the King: the passion, attention and quality I put into a dinner stay the same.

> “Whether I'm cooking for a family, a group of friends, or perhaps one day the King, the passion, attention and quality I put into every dinner remain the same.”

Q: What happens at a private dinner that can't happen in a restaurant?

For me, the biggest difference is the intimacy and the personal atmosphere.

Going out to a beautiful restaurant is wonderful, of course. You enjoy the ambience, the service and the people around you. But how special is it to have that same fine dining experience in your own home, with family or friends?

You're in your own familiar surroundings, you have all the time in the world for each other, and there's nothing you need to take into account.

What I always love are guests' enthusiastic reactions when they see what's possible in their own kitchen.

I regularly hear: 'I had no idea you could make this in my kitchen!'

That's one of the best parts of my job. You bring the quality and the experience of a restaurant to a place where people feel completely at home.

Q: Why should everyone have a private chef experience at least once?

Because it's a real luxury to do absolutely nothing in your own home for an evening, while you enjoy a special dinner with friends or family.

Normally, as the host, you're busy all day with the shopping, the preparations, the cooking, welcoming your guests and, of course, clearing up afterwards.

Which means you often enjoy it far less yourself than you'd like to.

With a private chef, all of that is taken off your hands, from the preparation and the cooking to serving the dishes and clearing up afterwards.

You don't have to worry about a thing, and you can enjoy your company completely, from the first moment to the end of the evening.

And perhaps best of all: when the evening is over, everything is left neat and tidy, and there's no mountain of washing-up waiting for you.

That feeling of being completely taken care of, combined with a special culinary experience in your own home, is something I think everyone should have at least once.

And it doesn't have to be at home. Whether it's at your office, on a yacht, or somewhere completely unexpected, the beauty of private dining is that you can create a special culinary experience almost anywhere.$body$,
  'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/news-images/lucas-de-jager/portrait.jpg', 0.5, 0.25
);

insert into public.news_article_photos
  (news_article_id, image_url, after_paragraph, display_order, focus_x, focus_y)
values
  ('699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd', 'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/news-images/lucas-de-jager/dish-with-wine.jpg', 15, 0, 0.5, 0.5),
  ('699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd', 'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/news-images/lucas-de-jager/table.jpg', 23, 0, 0.5, 0.5),
  ('699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd', 'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/news-images/lucas-de-jager/at-work.jpg', 37, 0, 0.5, 0.5),
  ('699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd', 'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/news-images/lucas-de-jager/dish-with-sauce.jpg', 46, 0, 0.5, 0.4);

insert into public.news_article_chefs (news_article_id, chef_id)
values ('699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd', '2e2089b0-f94d-46f5-923b-4ebf9135a5a1');

delete from public.news_articles
 where id in ('cccccccc-0000-0000-0000-000000000001',
              'cccccccc-0000-0000-0000-000000000002',
              'cccccccc-0000-0000-0000-000000000003')
   and title like 'Example %';

do $$
begin
  if (select md5(body) from public.news_articles where id = '699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd')
     <> 'a2505d794d568ce1239411347001696b' then
    raise exception 'stored body differs from body_20261106.txt';
  end if;
  if (select count(*) from public.news_article_photos where news_article_id = '699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd') <> 4
     or (select count(*) from public.news_article_chefs where news_article_id = '699d2a2a-e5e6-4d25-8b7b-8e8adf2f40bd') <> 1
     or (select count(*) from public.news_articles where status = 'published') <> 2 then
    raise exception 'unexpected result -- rolled back';
  end if;
end $$;

commit;
