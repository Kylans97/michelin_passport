-- Two small cleanups from a Friends/Follow inventory pass:
--   1. Drop the dead user-to-user `public.follows` table.
--   2. Add `unblock_user()`, the missing other half of `block_user()`.
--
-- PREPARED, NOT APPLIED.

begin;

-- ============================================================
-- 1. DROP public.follows — dead since before Social Foundation Step 1
-- ============================================================
--
-- Verified again, directly against the live production schema, before
-- writing this DROP (not re-trusting the earlier inventory read alone):
--   - 0 rows (select count(*) from public.follows).
--   - 0 foreign keys reference it (pg_constraint.confrelid).
--   - 0 views mention it (pg_views.definition).
--   - 0 function bodies mention it (pg_proc.prosrc).
--   - 0 RLS policies on any OTHER table reference it (pg_policies.qual/
--     with_check).
--   - 0 references anywhere in lib/ (no `.from('follows')` call site).
-- The friendships migration (20260813120000) already documented this
-- table as "pre-existing, unused... not being built on top of" at the
-- time `friendships` was introduced as the real user-to-user relationship
-- — this migration acts on that finding rather than restating it. No
-- CASCADE needed: nothing external depends on it, so a plain DROP is
-- sufficient and errors loudly instead of silently taking anything else
-- down if that verification was ever wrong.

drop table public.follows;

-- ============================================================
-- 2. UNBLOCK_USER — the missing other half of block_user()
-- ============================================================
--
-- *** UI NOTE: a "Block" affordance must not ship in the app until this
-- RPC exists and is wired up too. *** Shipping the block button alone
-- (as block_user()'s own original comment left open — "no matching
-- unblock RPC yet... out of Step 1's scope") would create a one-way
-- door: a user who blocks someone by mistake, or changes their mind,
-- would have no path back except a support request. This function
-- closes that gap at the schema/RPC layer; whoever builds the Block UI
-- next must build the Unblock affordance in the same change, not defer
-- it again.
--
-- Same SECURITY DEFINER shape as block_user() (and its friend-request
-- siblings): the caller's identity comes only from auth.uid(), never a
-- client-supplied parameter, and this function is deliberately the ONLY
-- way a 'blocked' row can ever be removed — friendships_delete's own
-- RLS (`status in ('pending', 'accepted')`) still excludes 'blocked'
-- rows from a plain client-side DELETE, unchanged by this migration, so
-- unblocking genuinely has no other path.
--
-- Only the person who set blocked_by may reverse it — the blocked party
-- cannot unblock themselves, matching the same one-sided-control
-- reasoning block_user() itself relies on for who may block. Unblocking
-- deletes the row outright (not a status transition to some third
-- state) — a block was never a friendship in the meaningful sense, and
-- removing the row is exactly what send_friend_request() already
-- expects to find: a clean slate either person can send a fresh request
-- into afterward.

create function public.unblock_user(target_user_id uuid)
returns public.friendships
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  existing public.friendships;
  result public.friendships;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  if target_user_id = me then
    raise exception 'You cannot unblock yourself';
  end if;

  select * into existing from public.friendships
    where least(requester_id, addressee_id) = least(me, target_user_id)
      and greatest(requester_id, addressee_id) = greatest(me, target_user_id);

  if existing.id is null or existing.status <> 'blocked' then
    raise exception 'No active block exists between you and this user';
  end if;

  if existing.blocked_by <> me then
    raise exception 'Only the person who blocked can remove the block';
  end if;

  delete from public.friendships where id = existing.id
    returning * into result;

  return result;
end;
$$;

-- Revoked from anon explicitly, not just `public` — the Step 1 follow-up
-- migration (20260813130000) found that this schema's default
-- privileges grant EXECUTE to anon on every new function regardless of
-- a `revoke ... from public`, since anon is a real role, not an alias
-- for PUBLIC. Getting this right from the start here, not repeating
-- that near-miss.
revoke execute on function public.unblock_user(uuid) from public;
revoke execute on function public.unblock_user(uuid) from anon;
grant  execute on function public.unblock_user(uuid) to authenticated;

commit;
