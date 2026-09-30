-- Closes a gap the owner-preview feature's photo merge surfaced: nothing
-- stopped two different PENDING submissions from naming the same
-- replaces_photo_id. approve_venue_photo already fails safely if that
-- happens (the second approval's DELETE against the already-consumed
-- published photo matches zero rows, so it raises 'replaces_photo_id %
-- does not belong to venue %' before any insert) — but that only catches
-- it at approval time, after two people/moments have already believed
-- their own replacement was the one going through. This closes it at
-- submission time instead, mirroring the existing
-- claims_restaurants_one_pending_per_venue_uidx pattern
-- (20260928120000_harden_claims_restaurants_insert_rls.sql) for the same
-- class of problem: a partial unique index scoped to the in-flight state
-- only, so re-submitting after a rejection is unaffected.
--
-- Validated in a rollback transaction against the live database before
-- writing this: creates cleanly, and zero existing rows would violate it
-- (venue_photo_submissions currently holds 5 rows, all status =
-- 'approved' — no pending rows at all today).
--
-- replaces_photo_id is nullable (a submission with none is a new addition,
-- not a replacement), so — unlike the claims precedent, whose indexed
-- column is not null — this needs its own "and replaces_photo_id is not
-- null" clause: only replacement submissions are constrained here, never
-- new-addition ones.
create unique index venue_photo_submissions_one_pending_replacement_uidx
  on public.venue_photo_submissions (replaces_photo_id)
  where status = 'pending' and replaces_photo_id is not null;
