-- Venue Managers cutover — backfills the venue_managers_* permission
-- tables (schema exactly as designed and validated in the prior task)
-- from every currently approved claim, repoints every policy that
-- currently reads has_approved_venue_claim() at the new tables instead,
-- and drops that function. Applied together with
-- 20260930120000_add_venue_managers_permission_tables.sql as one
-- movement — see this file's own CORRECTION note below for exactly how
-- that pairing actually happened. Backfill + cutover landing separately
-- from table creation would leave two disagreeing answers to "may this
-- user manage this venue" live at once — the exact two-sources-of-truth
-- failure this whole feature exists to prevent. See the chat report
-- accompanying this migration for the full per-policy investigation, the
-- backfill counts, and the rollback-transaction validation this was
-- proven against before being applied for real.
--
-- EIGHTH POLICY, not in the original seven: venue_ratings_update was not
-- named in the task that produced this migration, but it references
-- has_approved_venue_claim() too (same negative-check shape as
-- venue_ratings_insert, for the UPDATE path — editing your own existing
-- rating must be blocked exactly the same way creating one is). Left
-- unmigrated, it would either break outright once the old function is
-- dropped, or keep reading the old, non-revocable source while every
-- sibling policy reads the new one. Migrated identically to venue_
-- ratings_insert; reported, not silently folded in.
--
-- claims_restaurants/claims_hotels/claims_private_chefs — their rows,
-- their RLS, their status CHECK — are NOT touched anywhere below.
--
-- CORRECTION, made immediately after a failed first apply attempt of
-- this exact file: this migration originally also (re)created the
-- venue_managers_* tables themselves, on the assumption that
-- 20260930120000_add_venue_managers_permission_tables.sql (the prior
-- task's migration, which the user had explicitly held back — "I will
-- review first") was still unapplied. `supabase db push` doesn't work
-- that way: it applies every pending migration in order, so the moment
-- this file was pushed, the CLI applied 20260930120000 FOR REAL first
-- (its tables now exist, empty, unbackfilled), then hit this file's own
-- `create table venue_managers_restaurants` and failed with "relation
-- already exists" — 20260930120000 stayed applied (its own transaction
-- had already committed), this file's own transaction rolled back
-- entirely. That briefly left production in exactly the split state
-- this task exists to prevent: new tables live, nothing backfilled, the
-- eight old policies still reading has_approved_venue_claim(). Caught
-- and fixed within the same sitting, before any client ever observed
-- it (nothing reads venue_managers_* yet) — this file no longer creates
-- those tables (section 1 removed entirely), only backfills them,
-- adds is_active_venue_manager(), repoints the eight policies, and
-- drops the old function, which is exactly the remaining, unapplied
-- half of the intended one-movement cutover.

begin;

-- ============================================================
-- 1. Backfill — every currently approved claim becomes an active grant,
--    so cutover to reading venue_managers_* instead of claims_* loses
--    nobody's access at the moment the policies flip below.
--
--    granted_at/granted_by are taken from the CLAIM's own reviewed_at/
--    reviewed_by, not from now()/whoever runs this migration — that is
--    literally who approved it and when, under the mechanism being
--    replaced; attributing it to "now" or to the person running this
--    migration would misrepresent history the exact way this table
--    exists to stop doing. Both stay null on a backfilled row if the
--    source claim itself never had them set (no CHECK on claims_*
--    enforces reviewed_at/reviewed_by being present when status =
--    'approved' — confirmed before writing this) rather than inventing
--    a value.
--
--    Confirmed live before writing this: 0 approved rows in
--    claims_restaurants, 0 in claims_hotels, 0 in claims_private_chefs
--    (the only claim that exists at all is still pending) — so this
--    backfill inserts 0 rows today. Written as a real, general INSERT...
--    SELECT anyway, not skipped, so it does the right thing the moment
--    the first claim is ever approved AND correctly backfills any
--    approval that happens between review of this migration and it
--    actually being applied.
-- ============================================================

insert into public.venue_managers_restaurants (user_id, restaurant_id, claim_id, granted_at, granted_by)
select c.user_id, c.restaurant_id, c.id, coalesce(c.reviewed_at, now()), c.reviewed_by
from public.claims_restaurants c
where c.status = 'approved';

insert into public.venue_managers_hotels (user_id, hotel_id, claim_id, granted_at, granted_by)
select c.user_id, c.hotel_id, c.id, coalesce(c.reviewed_at, now()), c.reviewed_by
from public.claims_hotels c
where c.status = 'approved';

insert into public.venue_managers_private_chefs (user_id, private_chef_id, claim_id, granted_at, granted_by)
select c.user_id, c.private_chef_id, c.id, coalesce(c.reviewed_at, now()), c.reviewed_by
from public.claims_private_chefs c
where c.status = 'approved';

-- ============================================================
-- 2. is_active_venue_manager() — same shape/style as has_approved_
--    venue_claim() (language sql, stable, security definer, search_path
--    pinned, one UNION ALL across the three typed tables so every caller
--    stays a one-line call), reading venue_managers_* and revoked_at is
--    null instead of claims_* and status = 'approved'. Named "is_" not
--    "has_" deliberately: the old name described HAVING a claim in a
--    given status; this one describes BEING a manager — an identity/
--    role, not a claim state — which is the actual distinction this
--    whole migration exists to draw.
-- ============================================================

create function public.is_active_venue_manager(p_venue_type text, p_venue_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.venue_managers_restaurants m
    where p_venue_type = 'restaurant'
      and m.restaurant_id = p_venue_id
      and m.user_id = auth.uid()
      and m.revoked_at is null
    union all
    select 1 from public.venue_managers_hotels m
    where p_venue_type = 'hotel'
      and m.hotel_id = p_venue_id
      and m.user_id = auth.uid()
      and m.revoked_at is null
    union all
    select 1 from public.venue_managers_private_chefs m
    where p_venue_type = 'private_chef'
      and m.private_chef_id = p_venue_id
      and m.user_id = auth.uid()
      and m.revoked_at is null
  );
$$;

revoke execute on function public.is_active_venue_manager(text, uuid) from public;
grant execute on function public.is_active_venue_manager(text, uuid) to authenticated;

-- ============================================================
-- 3. Repoint every policy that read has_approved_venue_claim() at
--    is_active_venue_manager() instead. Drop + create, not ALTER POLICY
--    (Postgres does support ALTER POLICY ... WITH CHECK (...), but this
--    project has never once used it — every prior policy change in this
--    repo's history is drop+create; matched here for consistency, not
--    because ALTER POLICY wouldn't work). Every clause below is
--    character-for-character the original except the one function call
--    — "this migration changes where permission comes from, nothing
--    else," confirmed by diffing against each policy's own original
--    source in 20260828120000_add_venue_claims_submissions_rankings.sql
--    before writing this.
-- ============================================================

drop policy venue_about_submissions_insert on public.venue_about_submissions;
create policy venue_about_submissions_insert on public.venue_about_submissions
  for insert to authenticated with check (
    user_id = auth.uid()
    and public.is_active_venue_manager(venue_type, venue_id)
  );

drop policy venue_photo_submissions_insert on public.venue_photo_submissions;
create policy venue_photo_submissions_insert on public.venue_photo_submissions
  for insert to authenticated with check (
    user_id = auth.uid()
    and public.is_active_venue_manager(venue_type, venue_id)
  );

drop policy venue_photo_submissions_storage_insert on storage.objects;
create policy venue_photo_submissions_storage_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'venue-photo-submissions'
    and (storage.foldername(name))[3] = auth.uid()::text
    and public.is_active_venue_manager(
      (storage.foldername(name))[1],
      ((storage.foldername(name))[2])::uuid
    )
  );

drop policy venue_ratings_insert on public.venue_ratings;
create policy venue_ratings_insert on public.venue_ratings
  for insert to authenticated with check (
    user_id = auth.uid()
    and not public.is_active_venue_manager(venue_type, venue_id)
  );

-- The eighth policy — see this file's own header.
drop policy venue_ratings_update on public.venue_ratings;
create policy venue_ratings_update on public.venue_ratings
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and not public.is_active_venue_manager(venue_type, venue_id)
  );

drop policy event_restaurants_claimant_insert on public.event_restaurants;
create policy event_restaurants_claimant_insert on public.event_restaurants
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'submitted'
    )
    and public.is_active_venue_manager('restaurant', restaurant_id)
  );

drop policy event_hotels_claimant_insert on public.event_hotels;
create policy event_hotels_claimant_insert on public.event_hotels
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'submitted'
    )
    and public.is_active_venue_manager('hotel', hotel_id)
  );

drop policy event_chefs_claimant_insert on public.event_chefs;
create policy event_chefs_claimant_insert on public.event_chefs
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'submitted'
    )
    and public.is_active_venue_manager('private_chef', chef_id)
  );

-- ============================================================
-- 4. Drop the old function — safe now, nothing references it. Confirmed
--    live before writing this via pg_depend (catches policies, views,
--    other functions, everything with a normal dependency on it): the
--    exact eight policies above were its only dependents, nothing else.
--    A plain DROP (no CASCADE) proves that claim again, structurally —
--    if anything had been missed, this statement itself would fail
--    rather than silently taking something else down with it.
-- ============================================================

drop function public.has_approved_venue_claim(text, uuid);

commit;
