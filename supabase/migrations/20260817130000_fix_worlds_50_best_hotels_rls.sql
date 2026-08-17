-- Security hotfix: public.worlds_50_best_hotels was created (migration
-- 20260807160000_create_worlds_50_best_hotels.sql) without row level
-- security, unlike every sibling catalogue table in this schema —
-- including its own direct sibling, public.worlds_50_best, which that
-- same migration's own header comment says its shape "mirrors exactly."
-- The RLS/policy statements were simply never added alongside the table.
--
-- Confirmed via a project-wide database privilege audit: this project's
-- Supabase bootstrap grants anon/authenticated broad table privileges by
-- default on every table (ALTER DEFAULT PRIVILEGES at the project level,
-- unrelated to and unchanged by this migration) — RLS is this project's
-- actual, sole enforcement boundary for every other table, and it was
-- simply missing here. With RLS disabled and zero policies, a normal
-- PostgREST client could read, insert, update, or delete any row in this
-- table with no restriction at all.
--
-- Fix: enable RLS and add the exact same read-only catalogue policy its
-- sibling worlds_50_best already has (production_schema_v1.sql):
--
--   alter table public.worlds_50_best enable row level security;
--   create policy worlds_50_best_public_read on public.worlds_50_best
--     for select to anon, authenticated using (true);
--
-- Deliberately no INSERT/UPDATE/DELETE policy — matches every other
-- admin-managed catalogue table in this project (restaurants, hotels,
-- worlds_50_best, award_history, etc.): writes happen only via the
-- service role through import/admin scripts, never through the app.
--
-- Deliberately does NOT touch project-wide default privileges, does NOT
-- revoke or re-grant anything, and does NOT modify any of the 189
-- existing rows or any other table. That is a separate, deferred,
-- project-wide hardening decision — this migration fixes only the one
-- confirmed defect.

begin;

alter table public.worlds_50_best_hotels enable row level security;

create policy worlds_50_best_hotels_public_read on public.worlds_50_best_hotels
  for select to anon, authenticated
  using (true);

commit;
