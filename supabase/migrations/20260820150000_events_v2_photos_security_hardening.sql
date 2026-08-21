-- Events V2 Step 4 — PROPOSED, NOT DEPLOYED. Photo security hardening.
--
-- Two genuine gaps found by direct audit of the live production RLS
-- (re-confirmed against pg_policies/pg_get_functiondef immediately before
-- writing this file, not assumed from an earlier pass):
--
-- A. `photos_insert`'s WITH CHECK is `(user_id = auth.uid())` only — it
--    never verifies that a supplied `visit_id`/`attendance_id` actually
--    belongs to the inserting user. A malicious authenticated client
--    could insert a photos row with someone ELSE's friends-visible
--    visit_id/attendance_id (their own user_id, so the row is still
--    "theirs" for ownership purposes) — and `photos_read`'s existing
--    friends-visible branches would then surface that row to the real
--    visit/attendance owner's friends, under their name. This predates
--    Events entirely (visit_id has had this exact shape since Social
--    Foundation Step 2) — Events V2 doesn't introduce it, but a new
--    'event' entity_type is the reason to close it now rather than carry
--    it forward untouched.
--
-- B. `storage.objects` on the `visit-photos` bucket has an owner-only
--    policy plus `visit_photos_read_friends` (a friends-visible bridge
--    joined through `visits`) — but no equivalent bridge joined through
--    `event_confirmed_attendance`. Today a friend permitted to SELECT a
--    friends-visible attendance's `photos` row (table RLS already allows
--    this, unchanged since Step 1) still cannot fetch the actual image
--    bytes, since `createSignedUrl(s)` is itself RLS-gated at the storage
--    layer.
--
-- Scope deliberately narrow, per explicit instruction: ownership
-- enforcement on INSERT and the storage friends-read bridge only.
-- `photos_update`'s WITH CHECK has the identical unenforced-ownership
-- shape as (A) — left untouched here, flagged as a same-class follow-up,
-- since no application code today updates visit_id/attendance_id after
-- insert and widening this migration's scope to also cover UPDATE was
-- explicitly out of scope for this pass. A stricter polymorphic CHECK
-- (e.g. entity_type='event' <-> attendance_id is not null) was
-- deliberately NOT added — perfect polymorphic normalization is out of
-- scope; ownership security is what this migration closes.
--
-- NOT applied to production by this migration file's authoring.

begin;

-- ============================================================
-- A. photos_insert — ownership enforcement
-- ============================================================
--
-- Preserves every existing legitimate write: a plain restaurant/hotel
-- photo (visit_id set, attendance_id null) still only needs its visit to
-- belong to the caller — exactly today's behavior, now actually verified
-- rather than merely implied. A row with neither visit_id nor
-- attendance_id set (entity_type/entity_id only) is unaffected — both
-- added conditions short-circuit true via `is null`.

drop policy photos_insert on public.photos;

create policy photos_insert on public.photos
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      visit_id is null
      or exists (
        select 1 from public.visits v
        where v.id = photos.visit_id and v.user_id = auth.uid()
      )
    )
    and (
      attendance_id is null
      or exists (
        select 1 from public.event_confirmed_attendance eca
        where eca.id = photos.attendance_id and eca.user_id = auth.uid()
      )
    )
  );

-- ============================================================
-- B. storage.objects — friends-visible bridge for confirmed Attendance
-- ============================================================
--
-- Exact mirror of the existing visit_photos_read_friends policy, joined
-- through event_confirmed_attendance instead of visits. Same bucket
-- (visit-photos — no new bucket, per explicit instruction); same
-- is_friend() SECURITY DEFINER helper every other friends-visibility
-- policy in this schema already uses. Never references entity_type —
-- official Event imagery (events.image_url) is untouched and unrelated;
-- this only ever governs objects a `photos` row with a non-null
-- attendance_id points at.

create policy attendance_photos_read_friends on storage.objects
  for select to authenticated
  using (
    bucket_id = 'visit-photos'
    and exists (
      select 1
      from public.photos p
      join public.event_confirmed_attendance eca on eca.id = p.attendance_id
      where p.storage_path = storage.objects.name
        and eca.visibility = 'friends'
        and public.is_friend(eca.user_id)
    )
  );

commit;
