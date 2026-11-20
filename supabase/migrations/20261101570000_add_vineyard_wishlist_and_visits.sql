-- Wine estates on the wishlist and in the Passport. Asked for by the
-- product owner on 2026-11-20 after reviewing the "Wishlist, calmer"
-- canvas: "let me log estate visits" and save estates to the wishlist.
-- Written 2026-11-20 (branch claude/wishlist-kinds). The number is sort
-- order, not a date: named after the highest migration on any branch.
--
-- PREPARED -- NOT APPLIED until the product owner approves.
--
-- 1. wishlist gains a fifth entity_type, 'vineyard'. Every wishlist read in
--    shipped builds filters on entity_type (wishlist_repository.dart:
--    _wishlistedIds, loadWishlistVenues), so 1.6.0 and 1.6.1 ignore these
--    rows rather than misreading them -- the reasoning journeys used
--    (20261101500000 §6). No other wishlist column or policy changes.
--
-- 2. vineyard_visits: a member's visit to an estate. Its own table, not a
--    third entity_type on public.visits. visits is read by every shipped
--    build as "hotel, else restaurant" (visited_repository.dart), carries
--    restaurant-only columns (stars_at_visit, food/service ratings, menu
--    type) and is joined by the rankings, the freeze trigger and the
--    reports, so a vineyard row there would be misread by builds already in
--    the wild. The same call trains and ships made with journey_travels,
--    and the same shape: created only by the member, private by default,
--    readable by an accepted friend when shared. An estate may be visited
--    more than once, so no unique (vineyard_id, user_id).
--
--    What the member did is a set of fixed activities, not free text, so it
--    can be shown and counted the same way for everyone. Wines tasted at
--    the estate are not part of this migration: visit_wines.visit_id
--    points at public.visits and shipped builds read every visit_wines row
--    of an estate expecting a visit_id; linking them here is a later,
--    separate change.
--
-- No function is created here, so there is no execute grant to revoke.

begin;

-- ============================================================
-- 1. wishlist -- vineyards become a fifth entity_type
-- ============================================================
alter table public.wishlist drop constraint wishlist_entity_type_check;
alter table public.wishlist add constraint wishlist_entity_type_check
  check (entity_type in ('hotel', 'restaurant', 'event', 'journey', 'vineyard'));

-- ============================================================
-- 2. vineyard_visits
-- ============================================================
create table public.vineyard_visits (
  id           uuid primary key default gen_random_uuid(),
  vineyard_id  uuid not null references public.vineyards(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  visited_on   date not null,
  activities   text[] not null default '{}'
    check (activities <@ array['tasting', 'cellar_tour', 'lunch', 'vineyard_walk', 'stay']::text[]),
  rating       smallint check (rating between 1 and 10),
  comment      text,
  visibility   text not null default 'private'
    check (visibility in ('private', 'friends')),
  created_at   timestamptz not null default now()
);

create index vineyard_visits_user_idx
  on public.vineyard_visits (user_id, visited_on desc);
create index vineyard_visits_vineyard_idx
  on public.vineyard_visits (vineyard_id);

comment on table public.vineyard_visits is
  'A member''s visit to a wine estate. Its own table, not an entity_type '
  'on visits, which shipped builds read as hotel-else-restaurant. The only '
  'source of an estate Passport stamp; a wishlist entry never creates one.';

-- ============================================================
-- 3. ROW LEVEL SECURITY
-- ============================================================
-- Same policy shape as journey_travels: the owner reads and writes their
-- own rows, an accepted friend reads a 'friends' row, anon reads nothing.
alter table public.vineyard_visits enable row level security;

revoke all on public.vineyard_visits from public, anon, authenticated;
grant select, insert, update, delete on public.vineyard_visits to authenticated;

create policy vineyard_visits_select on public.vineyard_visits
  for select to authenticated
  using (
    user_id = auth.uid()
    or (visibility = 'friends' and public.is_friend(user_id))
  );

create policy vineyard_visits_insert on public.vineyard_visits
  for insert to authenticated
  with check (user_id = auth.uid());

create policy vineyard_visits_update on public.vineyard_visits
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy vineyard_visits_delete on public.vineyard_visits
  for delete to authenticated
  using (user_id = auth.uid());

commit;
