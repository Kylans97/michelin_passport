-- Venue Managers — the permission layer an APPROVED claim is supposed to
-- grant. Schema and RLS only, no automation, no UI. See this migration's
-- own chat report for the full investigation this is built on; the short
-- version:
--
-- claims_restaurants/claims_hotels/claims_private_chefs are a HISTORICAL
-- REQUEST (20260828120000) and stay exactly that — this migration does
-- not touch them, their RLS, or their status CHECK, as instructed.
-- has_approved_venue_claim() (same migration) already reads those tables
-- directly to gate venue_about_submissions/venue_photo_submissions (+its
-- storage bucket)/venue_ratings/the three event-claimant-submission
-- policies — SEVEN existing policies, all live today. That function is,
-- in every practical sense, an existing permission mechanism: it decides
-- who may act as a venue's manager. It is also exactly the bug this
-- migration exists to fix — status = 'approved' with no revocation
-- concept at all means an approval from a year ago silently still grants
-- rights forever, which is precisely the failure mode described as the
-- reason this table needs to exist as a SEPARATE thing from the claim
-- row. This migration does not touch has_approved_venue_claim() or the
-- seven policies that call it — migrating them onto these new tables is
-- real, separate follow-up work, deliberately left undone here (out of
-- this task's stated scope: "Schema and RLS only", nothing about editing
-- claims_restaurants or the submission/rating policies was asked for).
-- Until that follow-up happens, this project will have TWO answers to
-- "can this user manage this venue" — the old, non-revocable one (still
-- live, still gating those seven policies) and this new, revocable one
-- (gating nothing yet, since nothing reads it yet). That gap is reported
-- here, not silently left for someone to discover later.
--
-- notify_venue_claim_change() (20260927120000) fires on claims_* INSERT/
-- UPDATE purely to write a row into `notifications` for the CLAIMANT —
-- it never touches, references, or needs to know about a permission
-- table, and nothing here adds any trigger to claims_restaurants at all
-- (grants are manual, per explicit instruction), so there is no
-- collision: notify_venue_claim_change() keeps firing exactly as before,
-- untouched, alongside these new tables it has no reason to know about.
--
-- WHY THREE TABLES, NOT ONE WITH A venue_type COLUMN OR NULLABLE FKS:
-- follows_restaurants/follows_hotels/follows_private_chefs and claims_
-- restaurants/claims_hotels/claims_private_chefs are this schema's own
-- repeated, deliberate precedent for "a user's relationship to a venue,
-- split by venue type" — explicitly cited in this task's own brief. A
-- single table with three nullable FK columns (only one ever non-null)
-- would still be a polymorphic-shaped compromise wearing a different
-- disguise; three typed tables, exactly mirroring claims_*, is the
-- pattern actually asked for.
--
-- WHAT "which claim it came from" MEANS HERE: claim_id is NOT NULL,
-- referencing the SAME-TYPED claims table (claim_id on venue_managers_
-- restaurants points at claims_restaurants only) — no separate claim_
-- type column needed, since the table split itself already pins it.
-- `on delete restrict` (the implicit default, written explicitly for
-- clarity): claim rows are historical record and are never expected to
-- be deleted, so this should never fire in practice, but if someone ever
-- did try to delete a claim that's still the recorded justification for
-- an active grant, that should be a loud failure, not a silent orphan.
--
-- WHAT "active access is the absence of revocation" MEANS HERE: there is
-- deliberately no status/is_active column. `revoked_at is null` IS the
-- active/inactive signal, full stop — a second, parallel flag (status =
-- 'active'/'revoked') could drift from revoked_at/revoked_by/
-- revoked_reason (e.g. one gets updated, the other forgotten), which is
-- exactly the kind of two-sources-of-truth problem this whole feature
-- exists to avoid. The partial unique index below (mirroring claims_
-- restaurants_active_uidx's own `where status in (...)` shape, adapted
-- to this table's own single boolean-shaped signal) both expresses and
-- enforces this.
--
-- granted_by/revoked_by are nullable with `on delete set null`, NOT
-- `not null`, even though the grant SQL below always sets granted_by —
-- mirrors claims_*.reviewed_by/friendships.blocked_by exactly: a `not
-- null` FK would BLOCK deleting a profile that ever granted or revoked
-- any still-existing row, which would mean an admin's own account
-- deletion (delete-account, cascades from auth.users) could be blocked
-- by their own past dashboard actions — clearly wrong. Nullability here
-- is a delete-safety property of the FK, not a statement that granted_by
-- is ever actually left blank in practice.

begin;

-- ============================================================
-- 1. venue_managers_restaurants / _hotels / _private_chefs
-- ============================================================

create table public.venue_managers_restaurants (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  restaurant_id   uuid not null references public.restaurants(id) on delete cascade,
  claim_id        uuid not null references public.claims_restaurants(id) on delete restrict,
  granted_at      timestamptz not null default now(),
  granted_by      uuid references public.profiles(id) on delete set null,
  revoked_at      timestamptz,
  revoked_by      uuid references public.profiles(id) on delete set null,
  revoked_reason  text,
  constraint venue_managers_restaurants_revoked_by_iff_revoked check (
    (revoked_at is null) = (revoked_by is null)
  ),
  constraint venue_managers_restaurants_reason_iff_revoked check (
    revoked_at is null or revoked_reason is not null
  )
);

create table public.venue_managers_hotels (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  hotel_id        uuid not null references public.hotels(id) on delete cascade,
  claim_id        uuid not null references public.claims_hotels(id) on delete restrict,
  granted_at      timestamptz not null default now(),
  granted_by      uuid references public.profiles(id) on delete set null,
  revoked_at      timestamptz,
  revoked_by      uuid references public.profiles(id) on delete set null,
  revoked_reason  text,
  constraint venue_managers_hotels_revoked_by_iff_revoked check (
    (revoked_at is null) = (revoked_by is null)
  ),
  constraint venue_managers_hotels_reason_iff_revoked check (
    revoked_at is null or revoked_reason is not null
  )
);

create table public.venue_managers_private_chefs (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles(id) on delete cascade,
  private_chef_id   uuid not null references public.private_chefs(id) on delete cascade,
  claim_id          uuid not null references public.claims_private_chefs(id) on delete restrict,
  granted_at        timestamptz not null default now(),
  granted_by        uuid references public.profiles(id) on delete set null,
  revoked_at        timestamptz,
  revoked_by        uuid references public.profiles(id) on delete set null,
  revoked_reason    text,
  constraint venue_managers_private_chefs_revoked_by_iff_revoked check (
    (revoked_at is null) = (revoked_by is null)
  ),
  constraint venue_managers_private_chefs_reason_iff_revoked check (
    revoked_at is null or revoked_reason is not null
  )
);

-- Partial unique index per table, mirroring claims_restaurants_active_
-- uidx's own shape exactly (same (user_id, venue_id) pair, same partial-
-- predicate technique) — just keyed on this table's own active signal
-- (revoked_at is null) instead of a status column, per the design
-- decision above. Prevents the same user holding two simultaneously
-- active grants on the same venue; does NOT cap how many different
-- users may each independently manage one venue (an owner and a
-- delegated manager, say) — the same non-restriction claims_restaurants_
-- active_uidx itself already has.
create unique index venue_managers_restaurants_active_uidx
  on public.venue_managers_restaurants (user_id, restaurant_id)
  where revoked_at is null;
create unique index venue_managers_hotels_active_uidx
  on public.venue_managers_hotels (user_id, hotel_id)
  where revoked_at is null;
create unique index venue_managers_private_chefs_active_uidx
  on public.venue_managers_private_chefs (user_id, private_chef_id)
  where revoked_at is null;

-- "who manages this venue" lookups (admin review, and eventually the
-- owner-facing screen this task exists to unblock) — mirrors claims_
-- restaurants_restaurant_idx/claims_hotels_hotel_idx/claims_private_
-- chefs_chef_idx exactly, same reasoning: the composite indexes above
-- already serve "this user's grants" (user_id leftmost), the venue side
-- needs its own.
create index venue_managers_restaurants_restaurant_idx
  on public.venue_managers_restaurants (restaurant_id);
create index venue_managers_hotels_hotel_idx
  on public.venue_managers_hotels (hotel_id);
create index venue_managers_private_chefs_chef_idx
  on public.venue_managers_private_chefs (private_chef_id);

-- ============================================================
-- 2. RLS — read own rows only; no client-facing write path at all.
--    Granting and revoking is a service_role-only, dashboard-driven
--    action (see the grant SQL below), consistent with how claims_*
--    approval itself already works ("geen beheerscherm in de app" — no
--    admin role, no in-app admin identity, settled earlier and unchanged
--    here). service_role bypasses RLS entirely and needs no policy or
--    grant of its own, same as everywhere else in this schema.
-- ============================================================

alter table public.venue_managers_restaurants enable row level security;
alter table public.venue_managers_hotels enable row level security;
alter table public.venue_managers_private_chefs enable row level security;

create policy venue_managers_restaurants_own_read on public.venue_managers_restaurants
  for select to authenticated using (user_id = auth.uid());
create policy venue_managers_hotels_own_read on public.venue_managers_hotels
  for select to authenticated using (user_id = auth.uid());
create policy venue_managers_private_chefs_own_read on public.venue_managers_private_chefs
  for select to authenticated using (user_id = auth.uid());

-- No insert/update/delete policy for any client role, on any of the
-- three tables — RLS defaults to deny with no matching policy,
-- regardless of the table-level GRANT below (confirmed live behavior
-- this same session: an UPDATE with no matching policy affects 0 rows,
-- never errors, never mutates). Only `select` is explicitly granted,
-- matching claims_restaurants' own convention of granting exactly what
-- the client needs and no more, even though authenticated's default
-- per-table grant (`postgres`'s default ACL, confirmed live) already
-- includes full arwdDxtm — this project's established position (see
-- 20260918130000's own header) is that RLS is the real gate and the
-- wider default grant is inert without a matching policy, so no explicit
-- revoke is added here either, matching that precedent.
grant select on public.venue_managers_restaurants to authenticated;
grant select on public.venue_managers_hotels to authenticated;
grant select on public.venue_managers_private_chefs to authenticated;

commit;
