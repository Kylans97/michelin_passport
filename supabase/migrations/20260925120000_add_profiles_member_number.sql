-- Adds a stable, sequential, never-reused member number to public.profiles
-- — assigned in registration order, backfilled for the existing real
-- profiles ordered by created_at (the first-ever registration becomes 1),
-- and assigned automatically for every new signup from then on via a
-- column DEFAULT so handle_new_user()'s existing plain INSERT needs no
-- change.
--
-- A real Postgres SEQUENCE, not a computed rank/row_number: a sequence
-- never reissues a value once handed out. That's exactly "never reused,
-- even after someone deletes their account" — profiles.id references
-- auth.users(id) on delete cascade, so a deleted account's profile row is
-- genuinely gone, not soft-deleted; a recomputed rank would silently
-- shift/reuse numbers the moment any earlier row disappeared, a sequence
-- never will.
--
-- Two existing accounts ('test', 'kylan2') are excluded from this
-- backfill by explicit instruction — they read as throwaway/test
-- accounts, not real members, and a number once assigned is permanent, so
-- burning one on a test account isn't reversible later. This is a
-- ONE-TIME exclusion list evaluated against usernames as they exist right
-- now, not an ongoing "anything named test is auto-excluded" rule — a
-- future account named "test" gets numbered normally by the DEFAULT like
-- any other signup.

create sequence public.profiles_member_number_seq;

alter table public.profiles
  add column member_number integer;

with ordered as (
  select id, row_number() over (order by created_at) as rn
  from public.profiles
  where username is distinct from 'test' and username is distinct from 'kylan2'
)
update public.profiles
set member_number = ordered.rn
from ordered
where profiles.id = ordered.id;

-- Continue the sequence from the highest number just assigned, so the
-- next real signup gets the next number, not a restart at 1. On an empty
-- table, leave the sequence at 1 marked unused (is_called = false), so
-- the first signup gets 1.
--
-- Edited 2026-10-27, after this migration was already applied to
-- production. The original statement was
--   select setval('public.profiles_member_number_seq',
--     coalesce((select max(member_number) from public.profiles), 0));
-- which raises "value 0 is out of bounds" on an empty table — the
-- sequence's minimum is 1 — so a from-scratch replay (shadow database,
-- preview branch, disaster recovery) could never get past this file.
-- Production had real profiles when it ran, so it never hit the error.
-- Whenever max(member_number) is not null, this form is exactly
-- setval(seq, max, true) — the call production actually ran — so no
-- existing member number, and nothing printed on anyone's passport, is
-- affected; production never re-runs an applied migration in any case.
-- It differs only where the original raised an error. See CLAUDE.md's
-- rule on correcting an already-applied migration.
select setval(
  'public.profiles_member_number_seq',
  coalesce((select max(member_number) from public.profiles), 1),
  (select max(member_number) from public.profiles) is not null
);

-- NOT NULL is deliberately NOT applied — 'test' and 'kylan2' keep
-- member_number = NULL rather than being force-numbered. Every future
-- real signup still gets a real number regardless, since the DEFAULT
-- fires on any INSERT that doesn't specify the column, which is exactly
-- what handle_new_user() does.
alter table public.profiles
  alter column member_number set default nextval('public.profiles_member_number_seq'),
  add constraint profiles_member_number_key unique (member_number);

alter sequence public.profiles_member_number_seq owned by public.profiles.member_number;

-- Immutable once assigned — but only once assigned: a currently-NULL
-- member_number (the two excluded test accounts above) can still be
-- filled in later if that ever becomes appropriate; what's blocked is
-- changing an already-assigned number. RLS's existing profiles_update
-- policy (20260805141519_production_schema_v1.sql) only restricts WHICH
-- row a user can update (their own) — not which columns. The Flutter
-- client (ProfileRepository.updateProfile) never sends this field, but a
-- direct REST call bypassing the client entirely could still overwrite it
-- without this trigger.
create function public.prevent_member_number_change()
returns trigger
language plpgsql
as $$
begin
  if old.member_number is not null
     and new.member_number is distinct from old.member_number then
    raise exception 'member_number cannot be changed once assigned';
  end if;
  return new;
end;
$$;

create trigger profiles_member_number_immutable
  before update on public.profiles
  for each row execute function public.prevent_member_number_change();
