-- Social Foundation Step 2 — Privacy & Friend Content.
--
-- Establishes the personal-activity privacy boundary the Step 1 report's
-- own §8/§13 flagged as deferred: visits gain a real `private | friends`
-- visibility column; ratings/comments (columns on the same row) and
-- photos (via their parent visit) inherit it; wishlist becomes
-- automatically readable by accepted friends with no visibility column of
-- its own; trips are untouched (already owner-only, correct as-is).
--
-- Reuses Step 1's `public.is_friend(uuid)` helper (checks a live
-- `status = 'accepted'` friendship row, symmetric on either side) as the
-- single shared friendship predicate for every policy below — deliberately
-- not duplicated five slightly different ways. Because every check here is
-- a live subquery against `public.friendships`, an unfriend or a block
-- takes effect on the very next read: no visit/wishlist/photo row is ever
-- rewritten, and no authorization is cached anywhere.
--
-- `profiles.is_public` / `public.profile_is_visible()` are NOT read by any
-- policy in this migration — this was an explicit product decision (see
-- the task brief and the FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md update
-- accompanying this migration), not an oversight. After this migration,
-- `profile_is_visible()` has zero remaining callers among RLS policies
-- (it was previously used only by visits_read/wishlist_read/photos_read,
-- all three rewritten below); `profiles.is_public` itself remains
-- load-bearing for `profiles_read` (profile-row discoverability, a
-- deliberately separate concern per Step 1). Neither is dropped here —
-- removal is a later, independent cleanup, not required for correctness.
--
-- NOT applied to production by this task — prepared for physical-device
-- and pre-deployment review only.

begin;

-- ============================================================
-- 1. VISITS — visibility column
-- ============================================================

-- NOT NULL with a constant default backfills every existing row to
-- 'private' as part of the ALTER itself (a metadata-only operation on
-- Postgres 11+, no full-table rewrite) — the "deliberate protective
-- default" the task requires, achieved without a separate UPDATE pass.
-- No index added: the existing `visits_user_visited_idx`/`visits_entity_idx`
-- already cover this table's actual query patterns at MVP data volumes: a
-- friends-visibility check is one indexed-PK lookup via `is_friend()` per
-- row already selected by other means, not a bulk scan keyed on
-- `visibility` itself.
alter table public.visits
  add column visibility text not null default 'private'
    constraint visits_visibility_valid
    check (visibility in ('private', 'friends'));

-- ============================================================
-- 2. VISITS — SELECT policy rewrite
-- ============================================================
--
-- Owner always reads their own row, regardless of visibility. Otherwise:
-- visible only when the row itself opted into 'friends' AND the viewer
-- currently has an accepted friendship with the owner. Ratings, notes,
-- menu_type, price_paid, keys_at_visit, stars_at_visit — every column on
-- this row — inherit this exact policy, since they are not separate
-- tables/columns with their own visibility, per the task's explicit
-- instruction not to add rating_visibility/comment_visibility fields.
--
-- Narrowed from `anon, authenticated` to `authenticated` only: an
-- unauthenticated caller can never satisfy either clause below
-- (auth.uid() is null, so `user_id = auth.uid()` and `is_friend(...)`
-- — which itself keys off auth.uid() — are both always false), and the
-- task is explicit that there is deliberately no public visit visibility
-- tier in this MVP. Owner INSERT/UPDATE/DELETE (visits_insert/
-- visits_update/visits_delete) are untouched by this migration.

drop policy visits_read on public.visits;

create policy visits_read on public.visits
  for select to authenticated
  using (
    user_id = auth.uid()
    or (visibility = 'friends' and public.is_friend(user_id))
  );

-- ============================================================
-- 3. PHOTOS — SELECT policy rewrite (inherits parent visit visibility)
-- ============================================================
--
-- photos.visit_id is nullable (photos is a polymorphic table in
-- principle, per its own entity_type/entity_id columns) — a photo with no
-- visit_id has no visibility signal to inherit and is therefore
-- owner-only, never friends-visible, matching the task's explicit
-- instruction to only touch the visit-photo path. `photos.is_public` is
-- deliberately no longer read by this policy at all — the task is
-- explicit that visit-visibility, not the old per-photo flag, is now the
-- single source of truth. Photo INSERT/UPDATE/DELETE (photos_insert/
-- photos_update/photos_delete) are untouched by this migration.

drop policy photos_read on public.photos;

create policy photos_read on public.photos
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      visit_id is not null
      and exists (
        select 1 from public.visits v
        where v.id = photos.visit_id
          and v.visibility = 'friends'
          and public.is_friend(v.user_id)
      )
    )
  );

-- ============================================================
-- 4. WISHLIST — SELECT policy rewrite (no visibility column, ever)
-- ============================================================
--
-- Final MVP decision (see task brief): an accepted friend can always read
-- the owner's whole wishlist — no per-item or per-user visibility
-- setting, no public tier. wishlist_insert/wishlist_update/wishlist_delete
-- (owner-only) are untouched by this migration.

drop policy wishlist_read on public.wishlist;

create policy wishlist_read on public.wishlist
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_friend(user_id)
  );

-- ============================================================
-- 5. STORAGE — visit-photos bucket, additive friends-read policy
-- ============================================================
--
-- The pre-existing storage.objects policies for this bucket (both the
-- migration-created `visit_photos_read`/`_insert`/`_delete` and four
-- dashboard-created "Users can ... own stored visit photos" policies —
-- see this task's own audit/report for the exact discrepancy found) stay
-- exactly as they are: all are strictly owner-only, and Postgres RLS
-- policies are OR'd together, so adding one more additive SELECT policy
-- here only ever grants additional read access — it can never take
-- access away, and every existing owner-only guarantee (including
-- INSERT/UPDATE/DELETE, none of which are touched here) is unaffected.
--
-- Joins through public.photos rather than parsing the object path itself
-- ((storage.foldername(name))[2] would need an explicit UUID-format guard
-- before casting, since a malformed path would otherwise throw and break
-- the whole SELECT for unrelated callers) — `photos.storage_path = name`
-- is the actual source-of-truth link between a storage object and its
-- visit, already relied on everywhere else in this app
-- (PhotoRepository.resolveDisplayUrls), and only ever contains rows the
-- real owner created (photos_insert/visit_photos_insert are both already
-- owner-only, untouched here).
create policy visit_photos_read_friends on storage.objects
  for select to authenticated
  using (
    bucket_id = 'visit-photos'
    and exists (
      select 1
      from public.photos p
      join public.visits v on v.id = p.visit_id
      where p.storage_path = name
        and v.visibility = 'friends'
        and public.is_friend(v.user_id)
    )
  );

commit;
