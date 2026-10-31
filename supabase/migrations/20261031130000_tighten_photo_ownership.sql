-- Tighten who a photo can point at. Written 2026-10-31 from the
-- pre-launch security audit (read-only, against production).
--
-- 1. photos_update checked only user_id = auth.uid(). A member could
--    UPDATE their own photo row to point at someone else's visit or
--    event attendance, or at someone else's storage object, which would
--    then show through photos_read / visit_photos_read_friends to the
--    other member's friends (or, with a leaked path, to the editor's own
--    friends). The update check now matches photos_insert: the visit and
--    the attendance must be the caller's own.
-- 2. photos.storage_path and profiles.avatar_path must sit in the
--    owner's own folder ("<user id>/..."), which is how the app has
--    always written them (photo_repository.dart / profile_repository.dart).
--    Without this a member could copy another member's private avatar
--    path into their own profile and have can_view_member_avatar_object
--    (20261031120000) serve it to whoever may see the copier.
--
-- Left out on purpose: the audit also found PostGIS's spatial_ref_sys
-- writable by anon. Revoking it here was tried on a full local replay and
-- had no effect (anon kept INSERT): those grants come from another
-- grantor than the role running migrations. That needs moving PostGIS
-- out of public, a separate planned change.
--
-- Checked read-only on production before writing this, 2026-10-31:
-- 0 photos with a storage_path outside the owner's folder, 0 with a
-- visit or attendance that isn't the owner's, 0 profiles with an
-- avatar_path outside their own folder — so both constraints are added
-- VALID, and no existing row changes.
--
-- No SECURITY DEFINER function is created here.

begin;

-- 1 ---------------------------------------------------------------------
alter policy photos_update on public.photos
  with check (
    user_id = auth.uid()
    and (
      visit_id is null
      or exists (
        select 1 from public.visits v
        where v.id = visit_id and v.user_id = auth.uid()
      )
    )
    and (
      attendance_id is null
      or exists (
        select 1 from public.event_confirmed_attendance e
        where e.id = attendance_id and e.user_id = auth.uid()
      )
    )
  );

-- 2 ---------------------------------------------------------------------
alter table public.photos
  add constraint photos_storage_path_owner
  check (split_part(storage_path, '/', 1) = user_id::text);

alter table public.profiles
  add constraint profiles_avatar_path_owner
  check (avatar_path is null or split_part(avatar_path, '/', 1) = id::text);

commit;
