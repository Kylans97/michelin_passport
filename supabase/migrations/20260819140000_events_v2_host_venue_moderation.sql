-- Events V2 Step 1 — Database Foundation, part 1 of 5: moderation gate on
-- events, independent host/venue flags on the existing participant join
-- tables, and the new event_chefs join table.
--
-- HOST vs VENUE correction (see docs/Architecture/EVENTS_V2_ARCHITECTURE.md
-- §6.3): a single-value role column cannot express "this canonical
-- restaurant is the venue but a different, non-canonical party is the
-- host" (Club Leroy at Parkheuvel) nor "this restaurant is both host and
-- venue at once" (a restaurant hosting its own dinner) without two
-- conflicting rows for the same (event_id, restaurant_id) pair — which
-- the existing unique(event_id, restaurant_id)/unique(event_id, hotel_id)
-- constraints forbid. is_host/is_venue are independent, non-exclusive
-- booleans instead: a row's mere existence already means "participates";
-- the two flags layer additively on top. Never inferred from
-- address-matching or any other heuristic — always an explicit fact
-- recorded by whoever links the entity to the event.
--
-- moderation_status is additive and orthogonal to the existing `status`
-- lifecycle column (upcoming/cancelled/completed, untouched here) and the
-- existing admission_type/admission_note columns (untouched). Every
-- currently-live event defaults to 'published' so nothing already public
-- changes visibility — this migration does not hide any existing event.
--
-- Does NOT touch event_attendance, visits, wishlist, photos, planned_trips,
-- planned_venues, restaurants, hotels, or award_history.
--
-- NOT applied to production by this migration file's authoring — prepared
-- for pre-deployment review only. See
-- docs/Architecture/EVENTS_V2_DATABASE_FOUNDATION_PRE_APPLY.md for the
-- full audit this migration was designed against.

begin;

-- ============================================================
-- 1. EVENTS — moderation/availability gate + external host + descriptors
-- ============================================================

alter table public.events
  add column moderation_status text not null default 'published'
    check (moderation_status in ('draft', 'submitted', 'published', 'archived', 'rejected')),
  add column availability_status text not null default 'unknown'
    check (availability_status in ('available', 'sold_out', 'unknown')),
  -- Fully-external host with no canonical Chasing Stars entity at all
  -- (e.g. "Club Leroy" while it stays non-canonical, or Preuvenemint's
  -- organizing body if it's ever named). Mirrors the proven
  -- restaurant_name_text fallback private_chef_restaurant_history already
  -- uses for an entity real enough to record but not real enough for the
  -- catalogue. Never a join table, never an FK-to-nothing.
  add column external_host_name text,
  add column external_host_url text,
  -- Editorial labels ("SPECIAL LUNCH", "LIVE MUSIC", "LIMITED SEATING"),
  -- deliberately separate from the filterable event_type taxonomy
  -- (unchanged by this migration) — never mixed into one CHECK-constrained
  -- enum, per the architecture's explicit "don't mix taxonomy with
  -- editorial labels" instruction.
  add column descriptor_tags text[];

-- Replaces the unconditional `using (true)` read policy with a
-- moderation-status gate. Every existing row defaults to 'published'
-- above, so this is a no-op for current visibility — confirmed against
-- production: 4 events, all status='upcoming', all become
-- moderation_status='published' the instant this column exists.
drop policy events_public_read on public.events;
create policy events_public_read on public.events
  for select to anon, authenticated
  using (moderation_status = 'published');

-- ============================================================
-- 2. EVENT_RESTAURANTS / EVENT_HOTELS — independent host/venue flags
-- ============================================================

alter table public.event_restaurants
  add column is_host boolean not null default false,
  add column is_venue boolean not null default false;

alter table public.event_hotels
  add column is_host boolean not null default false,
  add column is_venue boolean not null default false;

-- Both default false, correctly describing the one live relationship
-- (Tout à Fait <-> 't Preuvenemint) as a plain participant — no manual
-- backfill needed or performed.

-- ============================================================
-- 3. EVENT_CHEFS — new join table, same shape as event_restaurants/
--    event_hotels, exactly as already sketched (role-free, pre-flag) in
--    20260810160000_create_events.sql's own header comment
-- ============================================================
--
-- chef_id targets private_chefs specifically -- an independent, freelance
-- chef business already catalogued as its own entity -- never a
-- restaurant's or hotel's own employed kitchen staff. MVP host entities
-- are exactly Restaurant, Hotel, Private Chef; a broader canonical Chef
-- entity letting a restaurant/hotel-employed chef host independently of
-- their employer is a distinct, larger modeling question, explicitly
-- deferred post-MVP (see EVENTS_V2_ARCHITECTURE.md #6.1). An employed
-- chef hosting independently today is recorded the same way Club Leroy
-- is -- events.external_host_name/external_host_url, non-canonical.

create table public.event_chefs (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  chef_id    uuid not null references public.private_chefs(id) on delete cascade,
  is_host    boolean not null default false,
  is_venue   boolean not null default false,
  unique (event_id, chef_id)
);

-- Mirrors event_restaurants/event_hotels' own index shape exactly: the
-- unique constraint's composite index already serves "chefs for this
-- event" (event_id as the leftmost column); chef_id needs its own index
-- for "events this chef is linked to" (Host Profile -> Upcoming Events).
create index event_chefs_event_idx on public.event_chefs (event_id);
create index event_chefs_chef_idx on public.event_chefs (chef_id);

alter table public.event_chefs enable row level security;

-- Public catalogue read, identical shape to event_restaurants_public_read/
-- event_hotels_public_read — service-role/admin-only writes, no client
-- insert/update/delete policy at all.
create policy event_chefs_public_read on public.event_chefs
  for select to anon, authenticated
  using (true);

commit;
