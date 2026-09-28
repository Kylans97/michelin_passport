-- Close a self-approval hole in claims_restaurants' INSERT policy.
--
-- Confirmed live before writing this (see chat transcript for the full
-- query output, not restated here): claims_restaurants_insert's own
-- with_check only constrains user_id = auth.uid(). Every other column,
-- including status, is free — an authenticated user can INSERT a row with
-- status = 'approved' directly (role/business_email/phone are NOT NULL so
-- must be supplied, but that's no obstacle) and self-approve a claim on any
-- restaurant in a single statement, no UPDATE needed. There is no UPDATE
-- policy on this table, so that path is already closed — this migration
-- only closes the INSERT one.
--
-- Deliberately scoped to claims_restaurants only, per the task that
-- produced this migration — claims_hotels/claims_private_chefs have the
-- identical shape and the identical hole, but widening this fix to them
-- was explicitly not asked for here.
--
-- NOT included: the task that produced this migration also asked for a
-- CHECK constraint limiting status to ('pending','approved','rejected',
-- 'withdrawn'). Confirmed live: claims_restaurants_status_check already
-- exists (added by 20260927120000_add_venue_claim_details_and_notifications
-- .sql) and already limits status to ('pending','approved','rejected',
-- 'blocked') — 'blocked' is a real, deliberately-added status wired into
-- notify_venue_claim_change() and the Flutter notifications screen; no
-- 'withdrawn' status exists anywhere in this schema or the app. Replacing
-- 'blocked' with 'withdrawn', adding 'withdrawn' as a fifth value, or
-- silently keeping 'blocked' instead of what was asked would each be a
-- product decision this migration isn't the place to make unasked — see
-- the chat report for the full discrepancy. Left out pending a decision.

begin;

-- ============================================================
-- 1. Tighten the INSERT policy — a new claim can only ever be created in
--    a neutral, unreviewed state. Confirmed live: the one existing row
--    (id a454a673-e1ff-4360-9dd0-1805befa5dc9) already satisfies this —
--    status = 'pending', reviewed_at/reviewed_by both null — so this is
--    a pure tightening, nothing to migrate.
-- ============================================================

drop policy claims_restaurants_insert on public.claims_restaurants;

create policy claims_restaurants_insert on public.claims_restaurants
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
  );

-- ============================================================
-- 2. One open claim per venue at a time, platform-wide — not just one
--    per (user, venue) pair, which claims_restaurants_active_uidx
--    already enforces. Confirmed live: zero restaurant_id has more than
--    one 'pending' row today, so this is safe to add outright.
--
--    This is a real behavior change, not just a lock-tightening: today,
--    two different people can each have a pending claim on the same
--    restaurant at once (e.g. two managers, both awaiting manual
--    review); after this, the second person's insert is rejected by
--    this index (a unique_violation, surfaced client-side the same way
--    VenueClaimRepository.submitClaim() already handles the existing
--    active_uidx violation — see its own doc comment) until the first
--    claim is resolved one way or another. Flagged in the chat report;
--    written here because the task asked for it explicitly.
-- ============================================================

create unique index claims_restaurants_one_pending_per_venue_uidx
  on public.claims_restaurants (restaurant_id)
  where status = 'pending';

commit;
