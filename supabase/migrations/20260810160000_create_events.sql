-- Culinary Events foundation: standalone/multi-venue events, matched
-- against Planned Trips (country + optional city + date overlap), with
-- future readiness for chefs, saved events, notifications and
-- Chasing-Stars-hosted events.
--
-- Additive only. No existing table, view or column is touched. Mirrors
-- this project's established conventions rather than inventing new ones:
--   - text + check for status/type taxonomies (see visits.entity_type,
--     wishlist.entity_type, worlds_50_best.list_type, planned_venues.status)
--     rather than a native Postgres enum (venue_status is the one place
--     this schema uses a real enum, for the older, more fixed
--     open/closed/... venue lifecycle — event_type/status are a newer,
--     more likely-to-grow taxonomy, so text + check matches the newer
--     precedent, not the older one).
--   - normalized join tables with a synthetic `id` + a `unique(...)`
--     constraint (see hotel_restaurants), not a composite primary key.
--   - scalar latitude/longitude as plain `double precision`, NOT PostGIS
--     geography — restaurants/hotels use geography(Point,4326) with a
--     view-level ST_X/ST_Y projection because their coordinates always
--     exist; an event's coordinates are frequently unknown/unverified, so
--     forcing PostGIS geometry + the same EWKB-over-PostgREST decoding
--     problem this app has already hit twice (see
--     20260807140000_add_venue_coordinates.sql's own commentary) for a
--     frequently-null value isn't worth it. Plain nullable columns read
--     directly, no client-side geometry decoding ever required.
--
-- PREPARED, NOT APPLIED.

create table public.events (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  description    text,
  start_at       timestamptz not null,
  end_at         timestamptz not null,
  country_code   char(2) not null references public.countries(country_code),
  -- Free text, not a public.cities FK — same reasoning as
  -- planned_trips.city (20260810120000_create_planned_trips.sql): an
  -- event's city must not be restricted to the curated Michelin-guide
  -- city list.
  city           text,
  venue_name     text,
  address        text,
  latitude       double precision,
  longitude      double precision,
  official_url   text,
  ticket_url     text,
  -- Future-ready, unused today — no event has a verified image yet, and
  -- none is fabricated. See EventsRepository/Event model on the Flutter
  -- side for the matching "photo-ready, no placeholder pretending to be
  -- real" pattern already used for venues (VenueThumbnail).
  image_url      text,
  event_type     text not null default 'other'
    check (event_type in
      ('festival', 'dinner', 'tasting', 'market', 'experience', 'other')),
  status         text not null default 'upcoming'
    check (status in ('upcoming', 'cancelled', 'completed')),
  created_at     timestamptz not null default now(),
  constraint events_dates_valid check (end_at >= start_at)
);

create index events_start_at_idx on public.events (start_at);
create index events_country_idx on public.events (country_code);
create index events_status_idx on public.events (status);

-- An event links to zero, one or many restaurants — never required, never
-- exclusive with event_hotels below. No entity_type/entity_id polymorphism
-- here on purpose: unlike visits/wishlist/planned_venues (which always
-- address exactly one venue of one type), an event can link BOTH
-- restaurants AND hotels at once, so two type-specific join tables (each
-- with a real, cascading foreign key) are the cleaner normalized shape —
-- exactly what the task asked for, and exactly how hotel_restaurants
-- already links two specific catalogue types together.
create table public.event_restaurants (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.events(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  unique (event_id, restaurant_id)
);

create index event_restaurants_event_idx
  on public.event_restaurants (event_id);
create index event_restaurants_restaurant_idx
  on public.event_restaurants (restaurant_id);

create table public.event_hotels (
  id       uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  unique (event_id, hotel_id)
);

create index event_hotels_event_idx on public.event_hotels (event_id);
create index event_hotels_hotel_idx on public.event_hotels (hotel_id);

-- Future readiness, NOT built now (task explicitly says do not build a
-- chef database yet): a later `event_chefs` table would follow the exact
-- same shape as event_restaurants/event_hotels above —
--   create table public.event_chefs (
--     id uuid primary key default gen_random_uuid(),
--     event_id uuid not null references public.events(id) on delete cascade,
--     chef_id uuid not null references public.chefs(id) on delete cascade,
--     unique (event_id, chef_id)
--   );
-- — needing a new `public.chefs` catalogue table and this one join table,
-- with zero changes to public.events itself.

-- RLS: events are discovery content, public like the restaurant/hotel
-- catalogue (restaurants_public_read, hotel_restaurants_public_read) —
-- NOT private like planned_trips/planned_venues. Read is open to
-- anon+authenticated; there is deliberately no insert/update/delete policy
-- for any client role, matching how the restaurant/hotel catalogue itself
-- is only ever written by the service role via import scripts, never by
-- app users.

alter table public.events enable row level security;
create policy events_public_read on public.events
  for select to anon, authenticated using (true);

alter table public.event_restaurants enable row level security;
create policy event_restaurants_public_read on public.event_restaurants
  for select to anon, authenticated using (true);

alter table public.event_hotels enable row level security;
create policy event_hotels_public_read on public.event_hotels
  for select to anon, authenticated using (true);

-- ============================================================
-- First real test record: 't Preuvenemint (Maastricht)
-- ============================================================
--
-- Facts below were verified via live web research on 2026-08-10, not
-- invented:
--   - Dates: Thursday 27 – Sunday 30 August 2026.
--   - Venue: Vrijthof square, Maastricht, Netherlands.
--   - Address: Vrijthof 25, 6211 LE Maastricht (per AllEvents' listing).
--   - Description quoted verbatim from the official site (preuvenemint.nl):
--     "'t Preuvenemint is the largest free-access gastronomic event in the
--     Benelux. For four days, everything revolves around taste,
--     connection, and the good life on the Vrijthof."
--   - Opening hours (preuvenemint.nl/en/openingstijden): general public
--     admission opens Thursday 18:00 CEST, event runs through to
--     Sunday 30 August close at 00:00 CEST (i.e. the start of 31 August).
--     A separate ticketed "'t PreuveneMeet" networking add-on runs
--     Thursday 15:00-18:00, before general admission — NOT the event
--     itself, so it is not reflected in start_at below.
--   - Official site: https://preuvenemint.nl/en
--   - Ticket link (for the optional PreuveneMeet add-on specifically —
--     the festival itself is free, general admission needs no ticket):
--     https://shop.celebratix.io/?c=2ghv4
--
-- Deliberately NOT included:
--   - latitude/longitude: not independently verified against a mapping
--     source during this research pass, so left null rather than guessed.
--   - image_url: no verified official image asset captured.
--   - Any event_restaurants/event_hotels links: no participating
--     restaurant or chef could be independently verified for the 2026
--     edition, and the task is explicit that fabricating participants is
--     not acceptable — this row intentionally links to zero venues.

insert into public.events (
  name, description, start_at, end_at, country_code, city, venue_name,
  address, official_url, ticket_url, event_type, status
) values (
  '''t Preuvenemint',
  '''t Preuvenemint is the largest free-access gastronomic event in the '
  'Benelux. For four days, everything revolves around taste, connection, '
  'and the good life on the Vrijthof. General admission is free; an '
  'optional ticketed ''t PreuveneMeet networking evening runs before the '
  'main event on opening day.',
  '2026-08-27 18:00:00+02'::timestamptz,
  '2026-08-31 00:00:00+02'::timestamptz,
  'NL',
  'Maastricht',
  'Vrijthof',
  'Vrijthof 25, 6211 LE Maastricht, Netherlands',
  'https://preuvenemint.nl/en',
  'https://shop.celebratix.io/?c=2ghv4',
  'festival',
  'upcoming'
);
