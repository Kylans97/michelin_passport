-- LANDING PAGE WAITLIST
--
-- One table for the mantelier.app pre-launch waitlist form (site/index.html,
-- outside the Flutter app entirely — a static page, not a repo build
-- target). Anonymous visitors submit an email address using the public
-- anon key directly from the browser; nothing else reads this table
-- through that key.
--
-- No user_id: a waitlist signup happens before anyone has an account, so
-- there is nothing to attribute it to yet. Not a profiles/auth.users
-- relationship of any kind.
--
-- RLS: exactly one policy, insert-only for anon. No select policy, no
-- update policy, no delete policy — with RLS enabled, the absence of a
-- policy for an operation denies it outright for that role, independent
-- of any table-level GRANT already in place from Supabase's own default
-- privileges. Reading the list back requires the service_role key
-- (bypasses RLS by design), never the anon key that ships in this page.
--
-- Does NOT touch profiles, auth.users, or any other existing table.
--
-- NOT applied to production by this migration file's authoring — prepared
-- for pre-deployment review only.

begin;

-- ============================================================
-- 1. WAITLIST — table
-- ============================================================

create table public.waitlist (
  id         uuid primary key default gen_random_uuid(),
  email      text not null unique,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 2. RLS — anon insert only, nothing else
-- ============================================================

alter table public.waitlist enable row level security;

create policy waitlist_insert on public.waitlist
  for insert to anon with check (true);

grant insert on public.waitlist to anon;

commit;
