-- Storage bucket + RLS policies for curated, admin-published catalogue
-- media (Step 2C — Private Chefs cover photography is the first
-- consumer; Restaurants/Hotels may use the same bucket for their own
-- curated photography later without a new migration).
--
-- Distinct from `visit-photos` (private, user-scoped personal content,
-- read via signed URLs) — this is the opposite shape: PUBLIC,
-- admin-curated content with no per-user ownership concept at all.
-- `private_chef_photos.image_url`/`private_chefs.profile_image_url`
-- already accept a plain URL (Step 2B) — this bucket exists purely to
-- give that URL a stable, project-owned home instead of an external
-- host, without changing either column's shape.
--
-- Object path convention: {entity_type}/{entity_id}/{display_order}.{ext}
-- e.g. private-chefs/2e2089b0-f94d-46f5-923b-4ebf9135a5a1/0.jpg for
-- Lucas's cover photo — stable, predictable, and the same shape works
-- for a future restaurants/{id}/... or hotels/{id}/... prefix without
-- any bucket/policy change.
--
-- Public bucket (public = true): Supabase serves public-bucket objects
-- directly over the public URL path without evaluating storage.objects
-- RLS at all, which is exactly the desired "anyone can read an approved
-- image" behaviour — no signed URLs, no auth round-trip in the client,
-- matching how the app already just does `Image.network(url)`. The
-- explicit select policy below is defence-in-depth for the Storage API
-- itself (e.g. listing), not what actually gates the public URL.
--
-- No insert/update/delete policy exists for `anon`/`authenticated` —
-- deliberately: with RLS enabled and no matching policy, those clients
-- are denied by default. Only the service role (which bypasses RLS
-- entirely) can write here, matching every other Private Chefs write
-- path in this project (curation via service-role import scripts, never
-- the app itself — see PrivateChefRepository's own "read-only" header
-- comment).

begin;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'catalogue-media',
  'catalogue-media',
  true,
  10485760, -- 10 MiB per object
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy catalogue_media_read on storage.objects
  for select to public
  using (bucket_id = 'catalogue-media');

commit;
