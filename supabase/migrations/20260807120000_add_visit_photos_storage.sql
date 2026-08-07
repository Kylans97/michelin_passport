-- Storage bucket + RLS policies for visit/stay photos.
--
-- public.photos (production schema v1) already has every column this
-- feature needs (user_id, visit_id, entity_type, entity_id, storage_path,
-- caption, taken_at, is_public) — but no storage bucket has ever been
-- created for it, and storage.objects has no RLS policies scoped to it.
-- This migration adds both. Nothing in public.photos itself changes.
--
-- The bucket is private (public = false): visibility of a *photo row* is
-- already governed by public.photos' own RLS (owner, or is_public AND
-- profile visible — see photos_read below it in the production schema),
-- but that is a row-level concept, not a storage-object-level one.
-- storage.objects RLS here is intentionally simpler and stricter
-- (owner-only), matching this MVP slice's scope: a user only ever views
-- their own photos so far — sharing/community photos are a later slice,
-- and can be layered on top of this later without breaking existing
-- objects. The app reads images via signed URLs
-- (createSignedUrl/createSignedUrls), never a public bucket URL, so a
-- private bucket costs nothing in the client.
--
-- Objects are stored as {user_id}/{visit_id}/{filename} — every policy
-- below checks that the first path segment equals the caller's own
-- auth.uid(), via storage.foldername(name).

begin;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'visit-photos',
  'visit-photos',
  false,
  10485760, -- 10 MiB per object
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

create policy visit_photos_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'visit-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy visit_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'visit-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy visit_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'visit-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

commit;
