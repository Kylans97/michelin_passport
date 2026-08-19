-- Private Chefs Step 2B — 5-photo hero gallery + biography length cap.
--
-- PREPARED, NOT APPLIED. Additive only: does not touch restaurants,
-- hotels, events, profiles, or any other table outside the three Private
-- Chefs tables from 20260817120000_create_private_chefs_foundation.sql.
-- Deliberately does NOT edit that already-deployed migration file itself
-- — this is a new, focused, additive migration on top of it.
--
-- ============================================================
-- A. PRIVATE_CHEF_PHOTOS
-- ============================================================
--
-- A small, admin-curated Detail-hero gallery — up to 5 images per chef.
-- Shape mirrors private_chef_restaurant_history exactly (synthetic uuid
-- pk, private_chef_id FK on delete cascade, display_order smallint,
-- created_at/updated_at with the shared set_updated_at() trigger) rather
-- than the unrelated public.photos table: that table is Supabase-
-- Storage-backed (storage_path + signed-URL resolution) for user-
-- uploaded personal visit photos, a genuinely different system for a
-- genuinely different (private, user-owned) use case. Private Chef
-- photography is admin-curated during curation, exactly like
-- `private_chefs.profile_image_url` already is — see that column's own
-- migration comment and PRIVATE_CHEFS.md §31 ("Chef catalogue images
-- will be admin-managed... no new Supabase Storage bucket is created").
-- image_url is therefore a plain text URL, matching profile_image_url's
-- own shape, not a storage_path.
--
-- profile_image_url vs private_chef_photos — deliberate MVP semantics,
-- documented here so the two never drift apart:
--   - profile_image_url: the compact portrait/avatar used by catalogue
--     rows (PrivateChefRow/PrivateChefAvatar) and as the Detail hero's
--     fallback when no gallery photo exists.
--   - private_chef_photos: the curated, up-to-5-image Detail hero
--     gallery. When present, it is authoritative for the hero; when
--     empty, the hero falls back to profile_image_url, then to the
--     existing branded placeholder. Neither column is dropped or
--     deprecated by the other.
--
-- Ordering: a single source of truth, display_order alone -- no separate
-- is_cover boolean. The lowest display_order value for a chef is always
-- the cover/first hero image; a `unique (private_chef_id, display_order)`
-- constraint makes "which one is first" unambiguous by construction,
-- rather than trusting two independently-settable fields (an is_cover
-- flag and a display_order value) to never disagree.
--
-- Max-5 enforcement: a single-purpose BEFORE INSERT trigger, not a
-- broader validation framework -- the simplest mechanism that gives a
-- real database-level guarantee rather than relying solely on the
-- trusted admin/import workflow to remember the limit.

begin;

create table public.private_chef_photos (
  id               uuid primary key default gen_random_uuid(),
  private_chef_id  uuid not null references public.private_chefs(id) on delete cascade,
  image_url        text not null,
  alt_text         text,
  display_order    smallint not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint private_chef_photos_display_order_unique
    unique (private_chef_id, display_order)
);

create trigger private_chef_photos_updated_at
  before update on public.private_chef_photos
  for each row execute function public.set_updated_at();

-- Enforces the product-approved 5-photo maximum at the database layer,
-- independent of whatever the admin/import workflow does or forgets to
-- check. Fires only on INSERT -- the limit is a row-count rule, not
-- something an UPDATE or DELETE could violate.
create function public.enforce_private_chef_photo_limit()
returns trigger
language plpgsql
as $$
begin
  if (
    select count(*) from public.private_chef_photos
    where private_chef_id = new.private_chef_id
  ) >= 5 then
    raise exception
      'private_chef_photos: chef % already has the maximum of 5 photos',
      new.private_chef_id;
  end if;
  return new;
end;
$$;

create trigger private_chef_photos_max_five
  before insert on public.private_chef_photos
  for each row execute function public.enforce_private_chef_photo_limit();

-- "This chef's photos, in order" -- the only query the Detail hero
-- issues (PrivateChefRepository.getChefPhotos). Catalogue rows never
-- query this table at all (they use profile_image_url only), so no
-- second index shape is needed for that path.
create index private_chef_photos_chef_idx
  on public.private_chef_photos (private_chef_id);

alter table public.private_chef_photos enable row level security;

-- Same read-audience decision as private_chefs/private_chef_restaurant_history
-- (PRIVATE_CHEFS.md's RLS design, §50): anon + authenticated, gated on
-- the parent chef's publication_status, matching
-- private_chef_restaurant_history_public_read's exact predicate shape.
create policy private_chef_photos_public_read on public.private_chef_photos
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.private_chefs pc
      where pc.id = private_chef_id
        and pc.publication_status = 'published'
    )
  );

-- No insert/update/delete policy for any client role -- admin-managed,
-- same as private_chefs/private_chef_restaurant_history.

grant select on public.private_chef_photos to anon, authenticated;

-- ============================================================
-- B. BIOGRAPHY LENGTH CAP
-- ============================================================
--
-- private_chefs already exists (deployed by 20260817120000) with zero
-- production rows -- adding a CHECK constraint now, via ALTER TABLE in
-- this new migration, is safe and instant (no existing row to validate
-- against) and does not touch the original migration file. Editorial
-- target is 350-650 characters (enforced by curation practice, not the
-- database); this constraint enforces only the hard outer bound product
-- has approved: 900 characters. Deliberately scoped to `biography` only
-- -- personalization_note and every other editorial text field are
-- unaffected, per explicit product direction.
alter table public.private_chefs
  add constraint private_chefs_biography_max_length
  check (biography is null or char_length(biography) <= 900);

commit;
