-- Admins need two-step sign-in. Written 2026-11-02, decided by the product
-- owner the same day, after build 1.5.6 (26) shipped two-step sign-in and
-- the admin account turned it on.
--
-- is_admin() stays the single source of the admin permission (CLAUDE.md,
-- "Venue permissions"); it now also asks for a session that passed the
-- code step: the token's aal claim is aal2. A password alone is aal1, so
-- a stolen admin password no longer opens anything admin.
--
-- Everything admin goes through is_admin(), evaluated as the caller, so
-- this one change covers all of it (listed from production 2026-11-02):
--   - get_review_queue and the 16 admin_* RPCs (claims, about texts,
--     photos rejected, team, Instagram, events, contact edits, content
--     reports, missing listings, member insights);
--   - the admin read policies on events, event_restaurants, event_hotels,
--     event_chefs, and storage.objects (venue-photo-submissions);
--   - publish-venue-photo's admin path, which calls is_admin() with the
--     admin's own JWT (its secret-based path is unchanged);
--   - the app's Review and Insights rows, which show when is_admin() is
--     true.
-- The dashboard fallback with service_role (VENUE_CLAIM_OPERATIONS.md) is
-- unaffected: it never goes through is_admin().
--
-- An admin without an authenticator is no longer an admin until they set
-- one up (Profile → Privacy → Two-step sign-in, build 26 and later). That
-- is the point. Builds before 26 have no code step, so an admin on such a
-- build loses admin access; only the product owner is an admin, on 26.
--
-- create or replace keeps the existing grants (execute for authenticated,
-- revoked from public and anon in 20261017120000); restated below anyway.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
     and coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
