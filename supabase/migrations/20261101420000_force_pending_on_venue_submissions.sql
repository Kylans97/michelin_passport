-- A venue's about text and photo submissions can only be created pending.
--
-- Written 2026-11-16. Named after 20261101410000_add_shared_guide_tables
-- (the highest version in production's ledger on that day, applied from
-- another branch) per CLAUDE.md's monotonic-sequence rule.
--
-- The gap: venue_about_submissions_insert and venue_photo_submissions_insert
-- (latest definition 20261001120000_venue_managers_cutover.sql, confirmed
-- live on 2026-11-16) check only user_id and is_active_venue_manager().
-- status, reviewed_at, reviewed_by and review_note are free, so an active
-- manager holding the public anon key could insert status = 'approved'
-- and venue_about_current would show that text without any admin having
-- seen it. The app always inserts with the column default ('pending');
-- the rule lived only in Dart. Photos were less exposed (publishing still
-- goes through publish-venue-photo, which checks is_admin()), but an
-- 'approved' submission row is still a review that never happened.
--
-- Same shape as claims_restaurants_insert (20260928120000) and the team
-- and Instagram submissions (20261101170000).
--
-- Deliberately NOT constrained: venue_photo_submissions.duplicate_of_
-- submission_id. The BEFORE INSERT trigger venue_photo_submissions_
-- duplicate_check sets it, and WITH CHECK sees the row after BEFORE
-- triggers, so requiring it null would reject every genuine duplicate the
-- trigger flags.
--
-- Production on 2026-11-16: zero rows in either table, so nothing existing
-- is affected. Shipped builds never send any of these columns, so no build
-- in the wild breaks.

begin;

drop policy venue_about_submissions_insert on public.venue_about_submissions;
create policy venue_about_submissions_insert on public.venue_about_submissions
  for insert to authenticated with check (
    user_id = auth.uid()
    and public.is_active_venue_manager(venue_type, venue_id)
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
    and review_note is null
  );

drop policy venue_photo_submissions_insert on public.venue_photo_submissions;
create policy venue_photo_submissions_insert on public.venue_photo_submissions
  for insert to authenticated with check (
    user_id = auth.uid()
    and public.is_active_venue_manager(venue_type, venue_id)
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
    and review_note is null
  );

commit;
