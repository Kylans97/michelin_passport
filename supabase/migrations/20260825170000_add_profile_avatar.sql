-- PROFILE UI REDESIGN V1 + PROFILE PHOTO — proposed, NOT YET APPLIED.
--
-- Adds the data-model + Storage support for a real member profile photo:
-- a new `profiles.avatar_path` column, a private `profile-photos`
-- Storage bucket, and owner-only RLS on it. See
-- docs/Architecture/PROFILE_AVATAR_V1.md for the full audit and
-- architecture reasoning this migration implements — in particular why
-- this is a NEW column (not a reuse of the existing, never-populated
-- `avatar_url`), why the bucket stays private with owner-only read for
-- this pass (deliberately NOT yet matching is_discoverable/relationship-
-- based visibility — nothing outside this pass exposes avatar_path to
-- any other user through any RPC yet), and why objects are addressed by
-- a unique per-upload path rather than a fixed `avatar.<ext>` name.
--
-- ============================================================
-- 1. New column.
-- ============================================================
--
-- A Storage OBJECT PATH, never a URL — resolving a path into a
-- displayable URL happens at read time via a short-lived signed URL
-- (ProfileRepository.resolveAvatarUrl), matching visit-photos' own
-- established display pattern exactly. Nullable: most existing rows
-- (and any user who never sets a photo) simply have no avatar, which
-- MemberAvatar already renders correctly as an initials fallback.
--
-- Deliberately NOT reusing the existing `avatar_url` column: that column
-- has never been populated by any code path in this app (confirmed
-- during this feature's own audit — grepped for every write site) and
-- its name/semantics (a URL) don't fit a stable path. `avatar_url` is
-- left untouched here — dropping it is out of this migration's scope.

alter table public.profiles
  add column avatar_path text;

comment on column public.profiles.avatar_path is
  'Storage object path (bucket profile-photos), never a URL, for this '
  'user''s current avatar. Null when no photo has been set. Resolved to '
  'a short-lived signed URL at read time via '
  'ProfileRepository.resolveAvatarUrl — never stored as a URL/token '
  'here. Exactly one canonical current avatar per user: replacing it '
  'uploads a new object, updates this column, then best-effort removes '
  'the superseded object (see ProfileRepository.replaceAvatar) — never '
  'an unbounded list of orphaned uploads.';

-- ============================================================
-- 2. Storage bucket.
-- ============================================================
--
-- Private (public = false), matching visit-photos — the app displays
-- avatars via signed URLs only, never a public bucket URL, so privacy
-- costs nothing in the client. 5 MiB is deliberately smaller than
-- visit-photos' 10 MiB cap: a single compressed avatar
-- (image_picker imageQuality 85, capped at 1024x1024 — see
-- lib/features/profile/avatar_picker.dart) is typically well under 1
-- MiB; 5 MiB leaves generous headroom without inviting a
-- disproportionately large single upload for what is only ever one
-- small identity photo.

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'profile-photos',
  'profile-photos',
  false,
  5242880, -- 5 MiB per object
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

-- ============================================================
-- 3. Storage RLS — owner-only, matching visit-photos exactly.
-- ============================================================
--
-- Objects are stored as {user_id}/{uniqueId}.{ext} — every policy below
-- checks that the first path segment equals the caller's own auth.uid(),
-- identical in shape to visit_photos_read/insert/delete. Owner-only
-- READ is a deliberate V1 scope decision, not an oversight: nothing in
-- this pass surfaces avatar_path to any user other than its owner
-- through any RPC (search_profiles/get_profile_identity/get_friends
-- etc. are all untouched by this migration and still only ever select
-- the pre-existing avatar_url column) — so there is no feature today
-- that needs a friend or a discoverable stranger to ever read this
-- bucket. Extending read access to match is_discoverable/relationship
-- visibility is real, separate architecture (signed-URL-issuing RPC or
-- equivalent) deferred to whichever future pass actually wires avatar
-- display into Friends/Community-facing surfaces — see
-- docs/Architecture/PROFILE_AVATAR_V1.md §"Storage read visibility" for
-- the full reasoning already worked through for that future pass.
--
-- No update policy: exactly like visit-photos, a replace is always a
-- fresh insert of a new object plus a delete of the superseded one,
-- never an in-place overwrite of an existing object.

create policy profile_photos_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy profile_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy profile_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
