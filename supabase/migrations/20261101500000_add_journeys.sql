-- Journeys: luxury trains and small ships, a new kind of place in the
-- catalogue next to restaurants, hotels and private chefs. Decided by the
-- product owner on 2026-11-16; plan and the four decisions taken with it
-- in docs/Architecture/JOURNEYS_PLAN.md. Written 2026-11-16. The number is
-- sort order, not a date.
--
-- A train or ship is not a hotel. The hotel scope rules (Key hotels and
-- 50 Best hotels only, no stub rows) are untouched: no journey ever enters
-- hotels, restaurants or hotel_restaurants. Every relationship is a join
-- table or a plain FK to a lookup table.
--
-- Recognition is editorial only. MICHELIN gives no stars or Keys to trains
-- or ships, so there is no michelin_* column here and nothing is gold.
-- Membership is journey_selections, shown as "Mantelier Selection" (the
-- brand stays out of every identifier).
--
-- Passport stamps come only from journey_travels, a member's explicit
-- confirmation that they travelled, never from a wishlist entry or a plan.
--
-- No function is created here, so there is no execute grant to revoke.

begin;

-- ============================================================
-- 1. journey_operators — lookup, never free text
-- ============================================================
--
-- Belmond alone runs five of the first trains. Grouping by operator is a
-- feature from day one, so it is a table with a code, not a text column
-- (the property_name lesson in DATABASE_ARCHITECTURE.md §6).
create table public.journey_operators (
  id             uuid primary key default gen_random_uuid(),
  operator_code  text not null unique,
  name           text not null,
  website_url    text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint journey_operators_code_format check (operator_code ~ '^op_[0-9]{3,}$')
);

create trigger journey_operators_updated_at
  before update on public.journey_operators
  for each row execute function public.set_updated_at();

-- ============================================================
-- 2. journeys — one row per train or ship
-- ============================================================
--
-- kind says train or ship; ship_type is the kind of ship and NULL for a
-- train. journey_code is the key; never match on name ("Orient Express"
-- names three products by two companies). primary_country_code is set only
-- when a journey runs in one country (the Andean Explorer, Peru); a polar
-- ship or the Venice Simplon-Orient-Express has none, and regions_text
-- ("Peruvian Amazon", "Polar regions") is what the card says instead. The
-- countries a journey actually crosses come from its routes.
--
-- status mirrors venue status: a retired train stays, the way a restaurant
-- that loses its stars stays, so a Passport stamp keeps its place.
-- first_departure_on is only for an announced journey, and only when the
-- operator states the date.
--
-- cabins_text and dining_text are starting values written from the
-- operator's own pages; the operator's own text takes over later (the
-- venue-supplied content rule).
create table public.journeys (
  id                    uuid primary key default gen_random_uuid(),
  journey_code          text not null unique,
  slug                  text not null unique,
  kind                  text not null,
  ship_type             text,
  name                  text not null,
  operator_id           uuid not null references public.journey_operators(id),
  primary_country_code  char(2) references public.countries(country_code),
  regions_text          text,
  status                text not null default 'operating',
  first_departure_on    date,
  summary               text,
  cabins_text           text,
  guest_capacity        smallint,
  dining_text           text,
  official_url          text,
  publication_status    text not null default 'draft',
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint journeys_code_format
    check (journey_code ~ '^(train|ship)_[0-9]{3,}$'),
  constraint journeys_code_matches_kind
    check (split_part(journey_code, '_', 1) = kind),
  constraint journeys_slug_format
    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint journeys_kind_valid
    check (kind in ('train', 'ship')),
  constraint journeys_ship_type_valid check (
    (kind = 'train' and ship_type is null)
    or (kind = 'ship' and (ship_type is null or ship_type in
        ('river', 'expedition', 'sailing_yacht', 'motor_yacht', 'yacht')))
  ),
  constraint journeys_status_valid
    check (status in ('operating', 'announced', 'retired')),
  constraint journeys_first_departure_only_when_announced
    check (first_departure_on is null or status = 'announced'),
  constraint journeys_guest_capacity_valid
    check (guest_capacity is null or guest_capacity > 0),
  constraint journeys_publication_status_valid
    check (publication_status in ('draft', 'published'))
);

create trigger journeys_updated_at
  before update on public.journeys
  for each row execute function public.set_updated_at();

create index journeys_operator_idx on public.journeys (operator_id);
create index journeys_country_idx on public.journeys (primary_country_code);

-- ============================================================
-- 3. journey_routes and journey_route_stops
-- ============================================================
--
-- Places are text plus a country, not public.cities: that list is scoped
-- to guide editions, and Aguas Calientes or Manaus must not be forced into
-- it (the reasoning events.city and private_chefs.home_city already use).
-- nights is NULL when the operator does not state it; 0 is a day train.
-- duration_text is the length exactly as published ("8 days", "2, 3 or 4
-- nights") when it is not a single night count, so days are never turned
-- into nights by arithmetic.
-- season_text and departure_pattern_text are written as the operator
-- publishes them, never inferred.
create table public.journey_routes (
  id                      uuid primary key default gen_random_uuid(),
  journey_id              uuid not null references public.journeys(id) on delete cascade,
  route_code              text not null unique,
  name                    text not null,
  from_place              text not null,
  from_country_code       char(2) not null references public.countries(country_code),
  to_place                text not null,
  to_country_code         char(2) not null references public.countries(country_code),
  nights                  smallint,
  duration_text           text,
  season_text             text,
  departure_pattern_text  text,
  display_order           smallint not null default 0,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  constraint journey_routes_code_format
    check (route_code ~ '^(train|ship)_[0-9]{3,}_r[0-9]{2,}$'),
  constraint journey_routes_nights_valid
    check (nights is null or nights >= 0),
  -- target of journey_travels' composite FK, which keeps a travel's route
  -- on the travel's own journey
  unique (id, journey_id)
);

create trigger journey_routes_updated_at
  before update on public.journey_routes
  for each row execute function public.set_updated_at();

create index journey_routes_journey_idx on public.journey_routes (journey_id);

create table public.journey_route_stops (
  id            uuid primary key default gen_random_uuid(),
  route_id      uuid not null references public.journey_routes(id) on delete cascade,
  stop_order    smallint not null,
  place         text not null,
  country_code  char(2) not null references public.countries(country_code),
  latitude      double precision,
  longitude     double precision,
  unique (route_id, stop_order),
  constraint journey_route_stops_coordinates_paired
    check ((latitude is null) = (longitude is null)),
  constraint journey_route_stops_latitude_valid
    check (latitude is null or latitude between -90 and 90),
  constraint journey_route_stops_longitude_valid
    check (longitude is null or longitude between -180 and 180)
);

-- ============================================================
-- 4. journey_selections — editorial membership history
-- ============================================================
--
-- Mirrors editorial_selections for restaurants: one row per time a
-- journey enters the Selection; leaving sets removed_on, so the Passport
-- can still say it was in the Selection when the member travelled.
create table public.journey_selections (
  id           uuid primary key default gen_random_uuid(),
  journey_id   uuid not null references public.journeys(id) on delete cascade,
  selected_on  date not null,
  removed_on   date,
  created_at   timestamptz not null default now(),
  constraint journey_selections_dates_valid
    check (removed_on is null or removed_on >= selected_on)
);

create unique index journey_selections_one_current_idx
  on public.journey_selections (journey_id)
  where removed_on is null;

-- ============================================================
-- 5. journey_restaurants — dining partnerships with catalogue restaurants
-- ============================================================
--
-- A named chef partnership whose restaurant is in the catalogue (Heinz
-- Beck's La Pergola for La Dolce Vita, say). A chef whose restaurant is not
-- in the catalogue stays in journeys.dining_text only. Never matched on
-- name: rows are written by code.
create table public.journey_restaurants (
  id             uuid primary key default gen_random_uuid(),
  journey_id     uuid not null references public.journeys(id) on delete cascade,
  restaurant_id  uuid not null references public.restaurants(id) on delete cascade,
  role           text not null default 'dining_partner',
  unique (journey_id, restaurant_id),
  constraint journey_restaurants_role_valid check (role in ('dining_partner'))
);

create index journey_restaurants_restaurant_idx
  on public.journey_restaurants (restaurant_id);

-- ============================================================
-- 6. journey_travels — confirmed travel, the only source of a stamp
-- ============================================================
--
-- Mirrors event_confirmed_attendance: created only by the member's own
-- explicit confirmation. Unlike an event, the same journey can be taken
-- more than once, so there is no unique(journey_id, user_id); a row is one
-- trip aboard. route_id is optional (a member may not remember which
-- itinerary).
create table public.journey_travels (
  id           uuid primary key default gen_random_uuid(),
  journey_id   uuid not null references public.journeys(id) on delete cascade,
  route_id     uuid,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  departed_on  date not null,
  arrived_on   date,
  rating       smallint check (rating between 1 and 10),
  comment      text,
  visibility   text not null default 'private'
    check (visibility in ('private', 'friends')),
  source       text not null default 'manual'
    check (source in ('manual', 'trip_completion')),
  created_at   timestamptz not null default now(),
  constraint journey_travels_dates_valid
    check (arrived_on is null or arrived_on >= departed_on),
  -- The route must be one of this journey's own routes. set null (route_id)
  -- clears only the route when it is removed; the travel stays.
  constraint journey_travels_route_on_journey
    foreign key (route_id, journey_id)
    references public.journey_routes (id, journey_id)
    on delete set null (route_id)
);

create index journey_travels_user_idx
  on public.journey_travels (user_id, departed_on desc);
create index journey_travels_journey_idx
  on public.journey_travels (journey_id);

-- ============================================================
-- 7. wishlist — journeys become a fourth entity_type
-- ============================================================
--
-- Every wishlist read in shipped builds filters on entity_type
-- (wishlist_repository.dart), so an old build ignores journey rows rather
-- than misreading them. No other wishlist column or policy changes.
alter table public.wishlist drop constraint wishlist_entity_type_check;
alter table public.wishlist add constraint wishlist_entity_type_check
  check (entity_type in ('hotel', 'restaurant', 'event', 'journey'));

-- ============================================================
-- 8. journeys_full — what the app and site read
-- ============================================================
--
-- Published journeys only, with the operator, the current Selection flag,
-- the route count and every country a route touches. security_invoker, so
-- the reader's own RLS applies.
create view public.journeys_full
  with (security_invoker = true)
as
select
  j.id,
  j.journey_code,
  j.slug,
  j.kind,
  j.ship_type,
  j.name,
  j.status,
  j.first_departure_on,
  j.summary,
  j.cabins_text,
  j.guest_capacity,
  j.dining_text,
  j.official_url,
  j.primary_country_code,
  j.regions_text,
  c.name as country_name,
  c.flag_emoji,
  o.operator_code,
  o.name as operator_name,
  o.website_url as operator_website_url,
  exists (
    select 1 from public.journey_selections s
    where s.journey_id = j.id and s.removed_on is null
  ) as is_selected,
  (select count(*) from public.journey_routes r where r.journey_id = j.id)::int
    as route_count,
  coalesce((
    select array_agg(distinct cc order by cc)
    from public.journey_routes r
    cross join lateral (values (r.from_country_code), (r.to_country_code)) v(cc)
    where r.journey_id = j.id
  ), array[]::char(2)[]) as route_country_codes
from public.journeys j
join public.journey_operators o on o.id = j.operator_id
left join public.countries c on c.country_code = j.primary_country_code
where j.publication_status = 'published';

-- ============================================================
-- 9. ROW LEVEL SECURITY
-- ============================================================
--
-- Catalogue tables (operators, journeys, routes, stops, selections,
-- restaurant links): world-readable, no client write; only service_role
-- writes. A draft journey and everything under it stays hidden.
-- The project's default privileges grant ALL on every new table to anon and
-- authenticated (20260918130000); the grant is narrowed to select so these
-- tables do not depend on RLS alone.
alter table public.journey_operators   enable row level security;
alter table public.journeys            enable row level security;
alter table public.journey_routes      enable row level security;
alter table public.journey_route_stops enable row level security;
alter table public.journey_selections  enable row level security;
alter table public.journey_restaurants enable row level security;
alter table public.journey_travels     enable row level security;

revoke all on public.journey_operators, public.journeys, public.journey_routes,
  public.journey_route_stops, public.journey_selections,
  public.journey_restaurants
  from anon, authenticated;
grant select on public.journey_operators, public.journeys, public.journey_routes,
  public.journey_route_stops, public.journey_selections,
  public.journey_restaurants
  to anon, authenticated;
grant select on public.journeys_full to anon, authenticated;

create policy journey_operators_public_read on public.journey_operators
  for select to anon, authenticated
  using (true);

create policy journeys_public_read on public.journeys
  for select to anon, authenticated
  using (publication_status = 'published');

create policy journey_routes_public_read on public.journey_routes
  for select to anon, authenticated
  using (exists (
    select 1 from public.journeys j
    where j.id = journey_id and j.publication_status = 'published'
  ));

create policy journey_route_stops_public_read on public.journey_route_stops
  for select to anon, authenticated
  using (exists (
    select 1 from public.journey_routes r
    join public.journeys j on j.id = r.journey_id
    where r.id = route_id and j.publication_status = 'published'
  ));

create policy journey_selections_public_read on public.journey_selections
  for select to anon, authenticated
  using (exists (
    select 1 from public.journeys j
    where j.id = journey_id and j.publication_status = 'published'
  ));

create policy journey_restaurants_public_read on public.journey_restaurants
  for select to anon, authenticated
  using (exists (
    select 1 from public.journeys j
    where j.id = journey_id and j.publication_status = 'published'
  ));

-- journey_travels: personal history. Same policy shape as
-- event_confirmed_attendance: the owner reads and writes their own rows,
-- an accepted friend reads a 'friends' row, anon reads nothing.
revoke all on public.journey_travels from anon;
grant select, insert, update, delete on public.journey_travels to authenticated;

create policy journey_travels_select on public.journey_travels
  for select to authenticated
  using (
    user_id = auth.uid()
    or (visibility = 'friends' and public.is_friend(user_id))
  );

-- A travel can only be confirmed on a published journey.
create policy journey_travels_insert on public.journey_travels
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.journeys j
      where j.id = journey_id and j.publication_status = 'published'
    )
  );

create policy journey_travels_update on public.journey_travels
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy journey_travels_delete on public.journey_travels
  for delete to authenticated
  using (user_id = auth.uid());

comment on table public.journeys is
  'Luxury trains and small ships. Editorial catalogue (Selection), never '
  'gold, never in hotels. Plan: docs/Architecture/JOURNEYS_PLAN.md.';
comment on table public.journey_travels is
  'A member''s confirmed travel aboard a journey. The only source of a '
  'journey Passport stamp; a wishlist entry or a plan never creates one.';

commit;
