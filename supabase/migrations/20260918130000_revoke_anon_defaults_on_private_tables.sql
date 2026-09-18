-- Hardening only — this migration changes NO behavior today.
--
-- Every table in this schema is created by the `postgres` role, and this
-- project's own `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA
-- public` entry (confirmed live via pg_default_acl, not assumed) grants
-- ALL privileges — select/insert/update/delete/truncate/references/
-- trigger — to `anon`, `authenticated` and `service_role` on every new
-- table automatically, with no per-migration action needed to get it.
-- That's a Supabase project-level default, not something any migration
-- in this repo's history ever asked for.
--
-- On the 20 tables below, that table-level grant to `anon` has never
-- once been exercised: RLS is enabled on every one of them, and not a
-- single policy on any of them names `anon` (or `public`, which would
-- also cover anon) for any command — confirmed live via pg_policies
-- before writing this migration. Postgres RLS defaults to deny when no
-- policy matches the requesting role, regardless of what the table-level
-- GRANT says. So `anon` has had zero practical access to any of these
-- 20 tables at any point — this migration only removes an unused,
-- purely defense-in-depth-violating grant, not a working access path.
-- If this shows up in a future audit looking like a sudden restriction,
-- it isn't: nothing that worked yesterday stops working today.
--
-- Deliberately scoped to `anon` only — `authenticated`/`service_role`
-- grants on these tables are untouched, since RLS already does the real
-- per-row restriction for signed-in users on all of them, and revoking
-- there was never asked for.
--
-- spatial_ref_sys deliberately excluded — already documented in
-- DATABASE_LINTER_EXCEPTIONS.md as unfixable from this project (owned
-- by supabase_admin, not postgres; the same ownership gap that blocks
-- enabling RLS on it likely blocks a REVOKE here too — not attempted).
--
-- Tables that DO have a genuine anon-facing policy (restaurants, hotels,
-- events, cities, countries, the *_public_read family, waitlist, etc.)
-- are NOT touched here — their anon grant is the one actually in use.

begin;

-- ============================================================
-- 1. Stop the recurrence: new tables created by `postgres` in `public`
--    no longer auto-grant anything to anon. Existing default privileges
--    for authenticated/service_role are untouched — only anon's default
--    changes. Any future table that genuinely needs anon read access
--    goes back to an explicit `grant select on ... to anon;` next to its
--    own public-read policy, exactly like restaurants_public_read /
--    hotels_public_read / events_public_read already do today.
-- ============================================================

alter default privileges for role postgres in schema public
  revoke all on tables from anon;

-- ============================================================
-- 2. Clear the existing backlog — the 20 tables where RLS was already
--    the only lock, confirmed above.
-- ============================================================

revoke all on table
  public.claims_hotels,
  public.claims_private_chefs,
  public.claims_restaurants,
  public.content_reports,
  public.event_attendance,
  public.event_confirmed_attendance,
  public.follows_hotels,
  public.follows_private_chefs,
  public.follows_restaurants,
  public.friendships,
  public.photos,
  public.planned_trips,
  public.planned_venues,
  public.private_chef_enquiries,
  public.profiles,
  public.venue_corrections,
  public.venue_link_clicks,
  public.venue_ratings,
  public.visits,
  public.wishlist
from anon;

commit;
