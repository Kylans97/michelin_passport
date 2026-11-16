-- Hotel and private-chef claims can only be created pending, like
-- restaurant claims already are.
--
-- Written 2026-11-16. Named after 20261101420000_force_pending_on_venue_
-- submissions per CLAUDE.md's monotonic-sequence rule.
--
-- The gap: claims_hotels_insert and claims_private_chefs_insert (only
-- definition 20260828120000, confirmed live on 2026-11-16) check only
-- user_id = auth.uid(). 20260928120000 closed the identical hole on
-- claims_restaurants and left these two out on purpose ("not asked for
-- here"). What a self-approved insert does today, traced 2026-11-16:
--   - it grants no edit permission: since 20261001120000 that comes only
--     from venue_managers_*, through is_active_venue_manager();
--   - the *_welcome_host_on_approval triggers are AFTER UPDATE only, so
--     no welcome email is sent;
--   - the *_notify_admin_on_insert triggers act only on status =
--     'pending', so the admins are not told either, and the row escapes
--     *_one_pending_per_venue_uidx;
--   - *_notify_on_change does not notify on an insert that isn't pending;
--   - the app (VenueClaimRepository.loadMyClaims) reads status ==
--     approved to show "my venue" entry points, and *_active_uidx then
--     blocks a real claim by the same user on that venue.
-- So: a silent, unreviewed 'approved' row that misleads the app and the
-- review history, without granting anything. Closed here.
--
-- review_note is added to all three tables (claims_restaurants too): it is
-- the admin's note to the claimant, and the app never sends it on insert.
--
-- Production on 2026-11-16: claims_hotels has zero rows; claims_private_
-- chefs has one, approved with a reviewer — inserts only, so untouched.
-- Shipped builds insert only user_id, the venue id, role, business_email,
-- phone and notes, so no build in the wild breaks.

begin;

drop policy claims_hotels_insert on public.claims_hotels;
create policy claims_hotels_insert on public.claims_hotels
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
    and review_note is null
  );

drop policy claims_private_chefs_insert on public.claims_private_chefs;
create policy claims_private_chefs_insert on public.claims_private_chefs
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
    and review_note is null
  );

drop policy claims_restaurants_insert on public.claims_restaurants;
create policy claims_restaurants_insert on public.claims_restaurants
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
    and review_note is null
  );

commit;
