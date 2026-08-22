-- Events V2 — Discovery Taxonomy Phase A
--
-- Additive schema only. Widens events.event_type to support the seven
-- approved V1 Event Types (adds lunch/gala/brunch/party; keeps every
-- existing value, including the three currently-unused legacy values
-- market/experience/other, for backward compatibility with any
-- already-stored row and any not-yet-updated Dart client).
--
-- Creates the curated Event Tag taxonomy as a normalized reference
-- table (event_tags) plus a many-to-many join table
-- (event_tag_assignments), mirroring the existing event_restaurants /
-- event_hotels join-table shape (uuid PK, cascade-deleting FKs,
-- composite unique constraint, separate per-column indexes, single
-- public-read RLS policy, no write policy — writes happen via the
-- service role only, matching every other content table in this
-- schema) and the existing cuisines reference-table shape (small
-- curated lookup list, public-read RLS).
--
-- No production data is modified by this migration. Tag seeding and
-- the 27-Event backfill are a deliberately separate, human-reviewed
-- data change (see EVENTS_DISCOVERY_TAXONOMY_PHASE_A_PRE_APPLY.md),
-- not part of this schema migration.

-- 1. Widen event_type — additive only, nothing removed.
alter table public.events drop constraint events_event_type_check;
alter table public.events add constraint events_event_type_check
  check (event_type = any (array[
    'festival', 'dinner', 'tasting', 'market', 'experience', 'other',
    'lunch', 'gala', 'brunch', 'party'
  ]::text[]));

-- 2. event_tags — curated taxonomy definition table.
create table public.event_tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  name text not null,
  created_at timestamptz not null default now()
);

alter table public.event_tags
  add constraint event_tags_slug_key unique (slug);

alter table public.event_tags enable row level security;

create policy event_tags_public_read
  on public.event_tags
  for select
  using (true);

-- 3. event_tag_assignments — many-to-many join, event <-> tag.
create table public.event_tag_assignments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  tag_id uuid not null references public.event_tags(id) on delete cascade
);

alter table public.event_tag_assignments
  add constraint event_tag_assignments_event_id_tag_id_key
  unique (event_id, tag_id);

create index event_tag_assignments_event_idx
  on public.event_tag_assignments (event_id);

create index event_tag_assignments_tag_idx
  on public.event_tag_assignments (tag_id);

alter table public.event_tag_assignments enable row level security;

create policy event_tag_assignments_public_read
  on public.event_tag_assignments
  for select
  using (true);
