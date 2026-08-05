-- Michelin Passport production schema v1
-- Replaces the legacy public schema.
-- auth.users and Supabase-managed schemas are deliberately preserved.

begin;

-- ============================================================
-- 1. REMOVE LEGACY PUBLIC OBJECTS
-- ============================================================

drop view if exists public.restaurants_full cascade;
drop view if exists public.hotels_full cascade;

drop materialized view if exists public.user_country_progress cascade;

drop table if exists public.user_trophies cascade;
drop table if exists public.trophies cascade;
drop table if exists public.visit_photos cascade;
drop table if exists public.visited_restaurants cascade;
drop table if exists public.friendships cascade;
drop table if exists public.hotel_awards cascade;
drop table if exists public.restaurant_awards cascade;

drop table if exists public.follows cascade;
drop table if exists public.photos cascade;
drop table if exists public.wishlist cascade;
drop table if exists public.visits cascade;
drop table if exists public.profiles cascade;

drop table if exists public.worlds_50_best cascade;
drop table if exists public.award_history cascade;
drop table if exists public.hotel_restaurants cascade;
drop table if exists public.restaurants cascade;
drop table if exists public.hotels cascade;
drop table if exists public.cuisines cascade;
drop table if exists public.cities cascade;
drop table if exists public.countries cascade;

drop function if exists public.handle_new_user() cascade;
drop function if exists public.profile_is_visible(uuid) cascade;
drop function if exists public.set_updated_at() cascade;

drop type if exists public.venue_status cascade;

-- ============================================================
-- 2. REQUIRED EXTENSIONS
-- ============================================================

create extension if not exists postgis;
create extension if not exists pg_trgm;
create extension if not exists pgcrypto;

-- pg_cron is enabled separately in the hosted Supabase project.
-- It is not needed for the initial local schema build.

-- ============================================================
-- 3. REFERENCE TABLES
-- ============================================================

create table public.countries (
  country_code char(2) primary key,
  name text not null unique,
  flag_emoji text not null
);

create table public.cities (
  id uuid primary key default gen_random_uuid(),
  country_code char(2) not null
    references public.countries(country_code),
  name text not null,
  postal_municipality text,
  region text,
  michelin_guide_edition text
);

create unique index cities_unique_key
  on public.cities (
    country_code,
    name,
    coalesce(region, '')
  );

create index cities_country_region_idx
  on public.cities (country_code, region);

create index cities_guide_edition_idx
  on public.cities (michelin_guide_edition);

create table public.cuisines (
  id smallint generated always as identity primary key,
  name text not null unique
);

-- ============================================================
-- 4. SHARED CATALOGUE TYPE
-- ============================================================

create type public.venue_status as enum (
  'open',
  'temporarily_closed',
  'permanently_closed'
);

-- ============================================================
-- 5. UPDATED_AT TRIGGER FUNCTION
-- ============================================================

create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ============================================================
-- 6. CATALOGUE TABLES
-- ============================================================

create table public.hotels (
  id uuid primary key default gen_random_uuid(),
  hotel_code text not null unique,
  name text not null,
  michelin_keys smallint not null check (michelin_keys between 1 and 3),
  city_id uuid not null references public.cities(id),
  country_code char(2) not null references public.countries(country_code),
  address text not null,
  location geography(Point,4326) not null,
  google_place_id text unique,
  michelin_url text unique,
  website_url text,
  booking_url text,
  status public.venue_status not null default 'open',
  status_since date,
  status_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger hotels_updated_at
  before update on public.hotels
  for each row execute function public.set_updated_at();

create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  restaurant_code text not null unique,
  name text not null,
  michelin_stars smallint,
  inclusion_reason text not null default 'michelin_star',
  cuisine_id smallint references public.cuisines(id),
  city_id uuid not null references public.cities(id),
  country_code char(2) not null references public.countries(country_code),
  address text not null,
  location geography(Point,4326) not null,
  google_place_id text unique,
  michelin_url text unique,
  website_url text,
  booking_url text,
  property_name text,
  status public.venue_status not null default 'open',
  status_since date,
  status_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint michelin_stars_valid
    check (michelin_stars is null or michelin_stars between 1 and 3),
  constraint inclusion_reason_valid
    check (inclusion_reason in ('michelin_star', 'worlds_50_best',
                                 'hall_of_fame', 'bib_gourmand'))
);

create trigger restaurants_updated_at
  before update on public.restaurants
  for each row execute function public.set_updated_at();

-- ============================================================
-- 7. HOTEL-RESTAURANT RELATIONSHIP
-- ============================================================

create table public.hotel_restaurants (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  link_confidence text not null check (link_confidence in ('exact', 'campus', 'manual_review')),
  evidence text,
  verified_at timestamptz,
  unique (hotel_id, restaurant_id)
);

-- ============================================================
-- 8. AWARD HISTORY AND WORLD'S 50 BEST
-- ============================================================

create table public.award_history (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('hotel', 'restaurant')),
  entity_id uuid not null,
  guide_year smallint not null,
  award_type text not null check (award_type in ('michelin_keys', 'michelin_stars')),
  award_value smallint,
  is_current boolean not null default false,
  announced_on date,
  unique (entity_type, entity_id, guide_year, award_type)
);

create index award_history_entity_idx
  on public.award_history (entity_type, entity_id);

create unique index award_history_current_uidx
  on public.award_history (entity_type, entity_id, award_type)
  where is_current;

create table public.worlds_50_best (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  year smallint not null,
  rank smallint,
  list_type text not null default 'top_50'
    check (list_type in ('top_50', 'extended_51_100', 'hall_of_fame')),
  unique (restaurant_id, year)
);

create unique index worlds_50_best_year_rank_uidx
  on public.worlds_50_best (year, rank)
  where rank is not null;

create index worlds_50_best_restaurant_idx
  on public.worlds_50_best (restaurant_id);

-- ============================================================
-- 9. CATALOGUE INDEXES
-- ============================================================

create index hotels_location_gix
  on public.hotels using gist (location);

create index restaurants_location_gix
  on public.restaurants using gist (location);

create index hotels_country_keys_idx
  on public.hotels (country_code, michelin_keys);

create index restaurants_country_stars_idx
  on public.restaurants (country_code, michelin_stars);

create index hotels_city_idx
  on public.hotels (city_id);

create index restaurants_city_idx
  on public.restaurants (city_id);

create index hotels_name_trgm_idx
  on public.hotels using gin (name gin_trgm_ops);

create index restaurants_name_trgm_idx
  on public.restaurants using gin (name gin_trgm_ops);

create index restaurants_status_idx
  on public.restaurants (status) where status <> 'open';

create index hotels_status_idx
  on public.hotels (status) where status <> 'open';

create index hotel_restaurants_restaurant_idx
  on public.hotel_restaurants (restaurant_id);

-- ============================================================
-- 10. VIEWS
-- ============================================================

create view public.restaurants_full
  with (security_invoker = true)
  as
select
  r.*,
  (hr.id is not null or r.property_name is not null) as is_in_hotel,
  coalesce(h.name, r.property_name)                  as hotel_name,
  h.id                                                as hotel_id,
  ci.name                                             as city_name,
  ci.region                                           as region,
  co.name                                             as country_name,
  co.flag_emoji                                       as flag_emoji,
  w.rank                                              as worlds_50_best_rank
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null);

create view public.hotels_full
  with (security_invoker = true)
  as
select
  h.*,
  coalesce(hr.restaurant_count, 0) > 0 as has_michelin_restaurant,
  coalesce(hr.restaurant_count, 0)     as restaurant_count,
  ci.name                              as city_name,
  ci.region                            as region,
  co.name                              as country_name,
  co.flag_emoji                        as flag_emoji
from public.hotels h
join public.cities ci on ci.id = h.city_id
join public.countries co on co.country_code = h.country_code
left join (
  select hotel_id, count(*) as restaurant_count
  from public.hotel_restaurants
  group by hotel_id
) hr on hr.hotel_id = h.id;

-- ============================================================
-- 11. USER TABLES
-- ============================================================

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  home_country_code char(2) references public.countries(country_code),
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null check (entity_type in ('hotel', 'restaurant')),
  entity_id uuid not null,
  visited_on date not null,
  rating smallint check (rating between 1 and 10),
  notes text,
  price_paid numeric,
  currency char(3),
  keys_at_visit smallint,
  stars_at_visit smallint
);

create index visits_user_visited_idx
  on public.visits (user_id, visited_on desc);

create index visits_entity_idx
  on public.visits (entity_type, entity_id);

create table public.wishlist (
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null check (entity_type in ('hotel', 'restaurant')),
  entity_id uuid not null,
  added_at timestamptz not null default now(),
  priority smallint,
  unique (user_id, entity_type, entity_id)
);

create index wishlist_user_idx
  on public.wishlist (user_id);

create table public.photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  visit_id uuid references public.visits(id),
  entity_type text not null check (entity_type in ('hotel', 'restaurant')),
  entity_id uuid not null,
  storage_path text not null,
  caption text,
  taken_at timestamptz,
  is_public boolean not null default true
);

create table public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (follower_id, following_id),
  check (follower_id <> following_id)
);

create index follows_following_idx
  on public.follows (following_id);

-- ============================================================
-- 12. PROFILE BOOTSTRAP TRIGGER
-- ============================================================

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, new.raw_user_meta_data ->> 'username');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 13. PROFILE VISIBILITY FUNCTION
-- ============================================================

create function public.profile_is_visible(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target = auth.uid()
      or exists (select 1 from public.profiles p where p.id = target and p.is_public);
$$;

revoke execute on function public.profile_is_visible(uuid) from public;
grant  execute on function public.profile_is_visible(uuid) to anon, authenticated;

-- ============================================================
-- 14. ROW LEVEL SECURITY
-- ============================================================

-- 14.1 Catalogue tables: public read, no write

alter table public.countries enable row level security;
create policy countries_public_read on public.countries
  for select to anon, authenticated using (true);

alter table public.cities enable row level security;
create policy cities_public_read on public.cities
  for select to anon, authenticated using (true);

alter table public.cuisines enable row level security;
create policy cuisines_public_read on public.cuisines
  for select to anon, authenticated using (true);

alter table public.hotels enable row level security;
create policy hotels_public_read on public.hotels
  for select to anon, authenticated using (true);

alter table public.restaurants enable row level security;
create policy restaurants_public_read on public.restaurants
  for select to anon, authenticated using (true);

alter table public.hotel_restaurants enable row level security;
create policy hotel_restaurants_public_read on public.hotel_restaurants
  for select to anon, authenticated using (true);

alter table public.award_history enable row level security;
create policy award_history_public_read on public.award_history
  for select to anon, authenticated using (true);

alter table public.worlds_50_best enable row level security;
create policy worlds_50_best_public_read on public.worlds_50_best
  for select to anon, authenticated using (true);

-- 14.2 profiles

alter table public.profiles enable row level security;

create policy profiles_read on public.profiles
  for select to anon, authenticated
  using (is_public or id = auth.uid());

create policy profiles_insert on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- 14.3 visits

alter table public.visits enable row level security;

create policy visits_read on public.visits
  for select to anon, authenticated
  using (public.profile_is_visible(user_id));

create policy visits_insert on public.visits
  for insert to authenticated
  with check (user_id = auth.uid());

create policy visits_update on public.visits
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy visits_delete on public.visits
  for delete to authenticated
  using (user_id = auth.uid());

-- 14.4 wishlist

alter table public.wishlist enable row level security;

create policy wishlist_read on public.wishlist
  for select to anon, authenticated
  using (public.profile_is_visible(user_id));

create policy wishlist_insert on public.wishlist
  for insert to authenticated
  with check (user_id = auth.uid());

create policy wishlist_update on public.wishlist
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy wishlist_delete on public.wishlist
  for delete to authenticated
  using (user_id = auth.uid());

-- 14.5 photos

alter table public.photos enable row level security;

create policy photos_read on public.photos
  for select to anon, authenticated
  using (
    user_id = auth.uid()
    or (is_public and public.profile_is_visible(user_id))
  );

create policy photos_insert on public.photos
  for insert to authenticated
  with check (user_id = auth.uid());

create policy photos_update on public.photos
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy photos_delete on public.photos
  for delete to authenticated
  using (user_id = auth.uid());

-- 14.6 follows

alter table public.follows enable row level security;

create policy follows_read on public.follows
  for select to authenticated
  using (follower_id = auth.uid() or following_id = auth.uid());

create policy follows_insert on public.follows
  for insert to authenticated
  with check (follower_id = auth.uid());

create policy follows_delete on public.follows
  for delete to authenticated
  using (follower_id = auth.uid() or following_id = auth.uid());

commit;
