-- News V1, part 2 — venue links, mirroring event_restaurants/event_hotels/
-- event_chefs exactly (20260810160000_create_events.sql /
-- 20260819140000_events_v2_host_venue_moderation.sql): id, a FK to the
-- owning row (cascade), a FK to the linked venue (cascade), a unique pair
-- constraint, two indexes, public-read RLS with no write policy for any
-- client role. Deliberately WITHOUT event_*'s later-added is_host/is_venue
-- booleans — those express event-specific "who's hosting" semantics with
-- no analogue here; every link is just "this article mentions this venue."
-- Writes happen by hand via the Supabase dashboard, same as news_articles
-- itself.

begin;

create table public.news_article_restaurants (
  id              uuid primary key default gen_random_uuid(),
  news_article_id uuid not null references public.news_articles(id) on delete cascade,
  restaurant_id   uuid not null references public.restaurants(id) on delete cascade,
  unique (news_article_id, restaurant_id)
);

create index news_article_restaurants_article_idx
  on public.news_article_restaurants (news_article_id);
create index news_article_restaurants_restaurant_idx
  on public.news_article_restaurants (restaurant_id);

alter table public.news_article_restaurants enable row level security;
create policy news_article_restaurants_public_read on public.news_article_restaurants
  for select to anon, authenticated using (true);
grant select on public.news_article_restaurants to anon, authenticated;

create table public.news_article_hotels (
  id              uuid primary key default gen_random_uuid(),
  news_article_id uuid not null references public.news_articles(id) on delete cascade,
  hotel_id        uuid not null references public.hotels(id) on delete cascade,
  unique (news_article_id, hotel_id)
);

create index news_article_hotels_article_idx
  on public.news_article_hotels (news_article_id);
create index news_article_hotels_hotel_idx
  on public.news_article_hotels (hotel_id);

alter table public.news_article_hotels enable row level security;
create policy news_article_hotels_public_read on public.news_article_hotels
  for select to anon, authenticated using (true);
grant select on public.news_article_hotels to anon, authenticated;

create table public.news_article_chefs (
  id              uuid primary key default gen_random_uuid(),
  news_article_id uuid not null references public.news_articles(id) on delete cascade,
  chef_id         uuid not null references public.private_chefs(id) on delete cascade,
  unique (news_article_id, chef_id)
);

create index news_article_chefs_article_idx
  on public.news_article_chefs (news_article_id);
create index news_article_chefs_chef_idx
  on public.news_article_chefs (chef_id);

alter table public.news_article_chefs enable row level security;
create policy news_article_chefs_public_read on public.news_article_chefs
  for select to anon, authenticated using (true);
grant select on public.news_article_chefs to anon, authenticated;

commit;
