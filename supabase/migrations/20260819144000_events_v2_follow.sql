-- Events V2 Step 1 — Database Foundation, part 5 of 5: Follow layer.
--
-- "Tell me about new activity from this entity" — explicitly distinct from
-- Wishlist ("I want to visit this Place"): a user can visit Parkheuvel,
-- remove it from Wishlist, and keep Following it for years. Three
-- dedicated typed tables (Restaurant/Hotel/Private Chef), not a
-- polymorphic table and not a canonical entity registry — see
-- docs/Architecture/EVENTS_V2_ARCHITECTURE.md §15.2 for the full
-- comparison. Matches this schema's own repeated, explicit preference for
-- real FKs on catalogue-linking relationships, and deliberately does NOT
-- reuse or extend the pre-existing, unreferenced public.follows table
-- (one-way, no-acceptance-step, a shape this codebase's own docs already
-- recommend retiring rather than building on).
--
-- Winery/Bar equivalents (follows_wineries/follows_bars) are NOT created
-- here — future-compatible extensions only, added at zero cost the moment
-- those catalogues exist, matching event_wineries/event_bars' own
-- deliberate exclusion from this Step 1 scope.
--
-- No visibility tier of any kind: a user's own follow list is never shown
-- to anyone else in this design (owner-only read), unlike visits/wishlist/
-- event_attendance/event_confirmed_attendance which all support a
-- friends-visible tier.
--
-- Does NOT touch events, event_restaurants, event_hotels, event_chefs,
-- event_attendance, event_confirmed_attendance, visits, wishlist,
-- planned_trips, planned_venues, restaurants, hotels, private_chefs.
--
-- NOT applied to production by this migration file's authoring — prepared
-- for pre-deployment review only.

begin;

-- ============================================================
-- 1. FOLLOWS_RESTAURANTS / FOLLOWS_HOTELS / FOLLOWS_PRIVATE_CHEFS — tables
-- ============================================================

create table public.follows_restaurants (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  created_at   timestamptz not null default now(),
  unique (user_id, restaurant_id)
);

create table public.follows_hotels (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  hotel_id   uuid not null references public.hotels(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, hotel_id)
);

create table public.follows_private_chefs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  private_chef_id uuid not null references public.private_chefs(id) on delete cascade,
  created_at      timestamptz not null default now(),
  unique (user_id, private_chef_id)
);

-- Each unique constraint's own composite index already serves "does user
-- X follow entity Y" and "all of user X's follows" (user_id is the
-- leftmost column in every one of the three). It does NOT serve "who
-- follows entity Y" (Follow -> Events discovery's join, and any future
-- follower-count metric) — entity_id is not the leftmost column of any of
-- the three composite indexes — so each table gets one additional,
-- explicit index on its own entity-id column.
create index follows_restaurants_restaurant_idx on public.follows_restaurants (restaurant_id);
create index follows_hotels_hotel_idx on public.follows_hotels (hotel_id);
create index follows_private_chefs_chef_idx on public.follows_private_chefs (private_chef_id);

-- ============================================================
-- 2. RLS — owner-only, no public/friends read at all
-- ============================================================

alter table public.follows_restaurants enable row level security;
alter table public.follows_hotels enable row level security;
alter table public.follows_private_chefs enable row level security;

create policy follows_restaurants_select on public.follows_restaurants
  for select to authenticated using (user_id = auth.uid());
create policy follows_restaurants_insert on public.follows_restaurants
  for insert to authenticated with check (user_id = auth.uid());
create policy follows_restaurants_delete on public.follows_restaurants
  for delete to authenticated using (user_id = auth.uid());

create policy follows_hotels_select on public.follows_hotels
  for select to authenticated using (user_id = auth.uid());
create policy follows_hotels_insert on public.follows_hotels
  for insert to authenticated with check (user_id = auth.uid());
create policy follows_hotels_delete on public.follows_hotels
  for delete to authenticated using (user_id = auth.uid());

create policy follows_private_chefs_select on public.follows_private_chefs
  for select to authenticated using (user_id = auth.uid());
create policy follows_private_chefs_insert on public.follows_private_chefs
  for insert to authenticated with check (user_id = auth.uid());
create policy follows_private_chefs_delete on public.follows_private_chefs
  for delete to authenticated using (user_id = auth.uid());

-- No UPDATE policy on any of the three — following is a pure add/remove
-- membership fact, matching wishlist's own shape (no update policy either):
-- there is nothing about a follow relationship to revise in place.

grant select, insert, delete on public.follows_restaurants to authenticated;
grant select, insert, delete on public.follows_hotels to authenticated;
grant select, insert, delete on public.follows_private_chefs to authenticated;

commit;
