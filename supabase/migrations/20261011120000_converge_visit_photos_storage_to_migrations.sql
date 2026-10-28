-- Converge production's visit-photos bucket and storage.objects policies
-- onto what migration history already says they are. Written 2026-10-28.
--
-- The visit-photos bucket was first created by hand in the dashboard on
-- 2026-07-27, before this project had migration history, together with
-- four owner-only storage.objects policies:
--   "Users can read own stored visit photos"    (SELECT)
--   "Users can upload own stored visit photos"  (INSERT)
--   "Users can update own stored visit photos"  (UPDATE)
--   "Users can delete own stored visit photos"  (DELETE)
-- all `to public`, all keyed on (storage.foldername(name))[1] =
-- auth.uid()::text. 20260807120000_add_visit_photos_storage.sql then
-- created the bucket "again" with `on conflict (id) do nothing`, so
-- production kept the dashboard's settings (15 MiB, and image/heif on
-- top of the migration's four types) rather than the migration's (10
-- MiB, jpeg/png/webp/heic). 20260814120000's own header already recorded
-- the four policies and left them in place deliberately; nothing since
-- has brought either side into history.
--
-- Found by the 2026-10-28 schema diff (production against a full local
-- replay of all 89 migrations): everything migrations create in public
-- matched exactly, and this bucket and these four policies were the only
-- real drift. On a database rebuilt from history — disaster recovery, a
-- preview branch — this one bucket would behave differently from
-- production.
--
-- Converged toward history, not toward production, because history is
-- the documented design and the dashboard extras are unused:
--
-- - No update policy is the stated design. 20260825170000's header:
--   "No update policy: exactly like visit-photos, a replace is always a
--   fresh insert of a new object plus a delete of the superseded one,
--   never an in-place overwrite of an existing object." PhotoRepository
--   uploads with uploadBinary and no upsert, and never moves or updates
--   an object; nothing in git history back to the initial commit
--   (2026-06-23) ever used upsert or a storage move.
-- - The other three dashboard policies duplicate visit_photos_read/
--   _insert/_delete exactly. Their `to public` grants anon nothing, since
--   auth.uid() is null there. visit_photos_read_friends and
--   attendance_photos_read_friends (additive SELECT bridges) are not
--   touched.
-- - image/heif is never sent: staged_photo.dart's allowedPhotoExtensions
--   is jpg/jpeg/png/webp/heic, anything else is stored as jpg, and no
--   commit has ever mentioned heif.
-- - 10 MiB is ample: every pick is compressed (imageQuality 85, maxWidth
--   1600) before upload, and photo egress is this project's primary cost
--   risk — the tighter cap is the one worth keeping.
--
-- The bucket limits only apply to new uploads; objects already stored
-- stay readable and deletable whatever their size or type. Before this
-- goes to production, a read-only check for existing visit-photos
-- objects over 10485760 bytes or with mimetype image/heif tells whether
-- the looser settings were ever actually used.
--
-- Against a fresh replay this is a no-op (the policies don't exist, the
-- bucket already has these values); against production it drops the
-- four policies and tightens the bucket. Safe to re-run either way.

begin;

drop policy if exists "Users can read own stored visit photos" on storage.objects;
drop policy if exists "Users can upload own stored visit photos" on storage.objects;
drop policy if exists "Users can update own stored visit photos" on storage.objects;
drop policy if exists "Users can delete own stored visit photos" on storage.objects;

update storage.buckets
set file_size_limit = 10485760, -- 10 MiB per object, as in 20260807120000
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
where id = 'visit-photos';

commit;
