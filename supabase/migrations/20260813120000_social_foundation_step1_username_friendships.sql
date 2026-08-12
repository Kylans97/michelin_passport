-- Social Foundation Step 1: username + mutual friendships.
--
-- PREPARED, NOT APPLIED. Purely additive — no existing table, column,
-- policy, view, or row is dropped, renamed, or rewritten. Nothing here
-- touches visits/wishlist/photos privacy (Step 2's job — see the
-- architecture doc), trips, events, or catalogue data.
--
-- Fixes two confirmed, currently-live bugs found during the pre-
-- implementation audit rather than assumed from the prior architecture
-- spike:
--   1. handle_new_user() has only ever read `username` out of signup
--      metadata, and SignupScreen has only ever sent `display_name` — so
--      every profile created since production schema v1 shipped has
--      username = null AND display_name = null (the "Edit Profile" row
--      that would set display_name later is a no-op today). Fixed by
--      having the trigger read both keys, and by SignupScreen sending
--      both (see the Flutter changes in this same task).
--   2. ProfileRepository.updateDisplayName already sends an `updated_at`
--      value on every call, but `profiles` has never had that column —
--      the call would fail with an undefined-column error the moment
--      anything actually invoked it. Fixed by adding the column (reusing
--      the existing set_updated_at() trigger function already used by
--      hotels/restaurants, not inventing a new one).
--
-- Existing profiles with username IS NULL are left null — no fabricated
-- usernames, per the task's explicit instruction. The Flutter side is
-- responsible for prompting a one-time "choose a username" step before
-- Friends functionality is used; the schema simply keeps allowing null.

begin;

-- ============================================================
-- 1. PROFILES: updated_at + username format
-- ============================================================

alter table public.profiles
  add column updated_at timestamptz not null default now();

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Canonical-lowercase-storage username rule, enforced by the database,
-- not only the Flutter form. A single POSIX-ERE pattern deliberately
-- carries every rule at once rather than several separate constraints:
--   ^[a-z0-9]                  -- must start with a lowercase letter/digit
--   ( [a-z0-9]                 -- ...followed by any run of further
--   | [_.][a-z0-9]             --    alnum chars, OR a single '_'/'.'
--   )*                         --    that must itself be immediately
--                              --    followed by an alnum char...
--   $                          -- ...and the whole string must end in one.
-- The "punctuation must be immediately followed by alnum" shape is what
-- makes this one pattern also reject consecutive punctuation ("kylan__x")
-- and a trailing punctuation character ("kylan_") for free, without a
-- second regex or a lookahead (POSIX ERE, which Postgres `~` uses, has no
-- lookahead support). Length (3-30) is a separate, simpler condition in
-- the same constraint. NULL is unaffected — a CHECK is satisfied
-- automatically when the expression evaluates to NULL, which is exactly
-- how existing/unset usernames stay valid without a special case.
--
-- Because only lowercase letters ever satisfy the character class, this
-- same constraint also enforces canonical-lowercase storage — there is no
-- separate `username = lower(username)` check to keep in sync.
alter table public.profiles
  add constraint profiles_username_format check (
    username is null or (
      char_length(username) between 3 and 30
      and username ~ '^[a-z0-9]([a-z0-9]|[_.][a-z0-9])*$'
    )
  );

-- profiles_username_key (production schema v1) already exists as a plain
-- unique index on `username` — with canonical-lowercase storage now
-- guaranteed by the CHECK above, that existing index is already correct,
-- race-safe, case-insensitive uniqueness. It does not need to change.

-- ============================================================
-- 2. PROFILE BOOTSTRAP TRIGGER: read both metadata keys
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    new.raw_user_meta_data ->> 'display_name'
  );
  return new;
end;
$$;

-- ============================================================
-- 3. FRIENDSHIPS
-- ============================================================
--
-- One row per unordered pair of users, ever — status transitions in
-- place rather than deleting-and-recreating, except for the two cases
-- where a fresh row genuinely is the right model (cancelling a pending
-- request, or removing an accepted friendship — see the DELETE policy
-- below and the RPCs' own comments for the declined-row exception).
--
-- No `following`/`muted`/`close_friend`/`archived` states — this product
-- explicitly does not do one-way following (see the pre-existing, unused
-- public.follows table, deliberately left untouched by this migration —
-- no Flutter code references it, and it is not being built on top of).

create table public.friendships (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles(id) on delete cascade,
  addressee_id  uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'blocked')),
  -- Only meaningful when status = 'blocked'; must name one of the two
  -- participants (enforced below) — never a third party, since blocking
  -- is something one of the two people in this exact relationship did.
  blocked_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  constraint friendships_no_self_friend check (requester_id <> addressee_id),
  constraint friendships_blocked_by_participant check (
    blocked_by is null or blocked_by in (requester_id, addressee_id)
  ),
  constraint friendships_blocked_by_present_iff_blocked check (
    (status = 'blocked') = (blocked_by is not null)
  )
);

-- Normalized-pair uniqueness: an expression index over least()/greatest()
-- of the two participant ids, so A->B and B->A can never coexist as two
-- separate rows — enforced by Postgres itself (least/greatest on uuid are
-- immutable, so this is a valid, race-safe unique index), not only by
-- application logic that could lose a race between two simultaneous
-- requests.
create unique index friendships_pair_uidx
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

-- "My pending requests" / "requests I've sent" / friends-list lookups
-- each key off one side of the pair; the pair index above doesn't serve
-- either of those directly.
create index friendships_requester_idx on public.friendships (requester_id);
create index friendships_addressee_idx on public.friendships (addressee_id);

alter table public.friendships enable row level security;

-- SELECT: only a participant may see a friendship row they're part of —
-- no enumerating unrelated pairs.
create policy friendships_select on public.friendships
  for select to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());

-- No INSERT/UPDATE policy for `authenticated` at all, deliberately.
-- Every state transition that has a rule more subtle than plain row
-- ownership (who may create a request, who may accept/decline a
-- *pending* request specifically, what happens to an already-declined or
-- already-blocked pair) is mediated by a SECURITY DEFINER RPC below,
-- which runs with its own elevated privilege and does not need a grant
-- here — mirroring how this project already treats stamp-claim-shaped
-- state machines (see FUTURE_PRODUCT_ARCHITECTURE.md 5.4) as
-- server-decided, never client-writable.
--
-- DELETE has no such subtlety — "stop this relationship existing" is a
-- plain ownership check regardless of whether it's the requester
-- cancelling their own still-pending request or either party removing an
-- accepted friendship — so it's a direct RLS-permitted client operation,
-- not routed through an RPC just for form's sake. A 'declined' row is
-- deliberately NOT deletable this way (it exists specifically to prevent
-- the original requester from immediately re-requesting — see
-- send_friend_request below); neither is a 'blocked' row (unblocking is
-- out of Step 1's scope).
create policy friendships_delete on public.friendships
  for delete to authenticated
  using (
    (requester_id = auth.uid() or addressee_id = auth.uid())
    and status in ('pending', 'accepted')
  );

-- Table-level privilege, distinct from (and required in addition to) the
-- RLS policies above — Postgres checks both, and RLS alone is a no-op
-- without the underlying GRANT. Confirmed necessary by testing directly
-- against a local database rather than assumed: `visits`/`planned_trips`
-- etc. have no equivalent explicit GRANT in their own migrations either,
-- which works in production because a real Supabase project's
-- default-privilege setup (configured once, outside the migrations
-- folder, when the project itself was created) already grants baseline
-- DML to `anon`/`authenticated` project-wide — but that ambient default
-- is exactly the kind of thing that shouldn't be relied on implicitly by
-- a new table when it's this cheap to state explicitly. Only SELECT and
-- DELETE, matching the only two policies that actually exist above —
-- granting INSERT/UPDATE would be harmless-but-pointless, since there is
-- deliberately no permissive policy for either (see the comment above the
-- SELECT policy for why every state transition beyond delete goes through
-- a SECURITY DEFINER RPC instead).
grant select, delete on public.friendships to authenticated;

-- ============================================================
-- 4. is_friend() — built now so Step 2 RLS never needs to redesign
--    friendships to add friends-visibility to visits/photos/wishlist.
--    Not referenced by any policy yet; safe, inert until Step 2 uses it.
-- ============================================================

create function public.is_friend(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and (
        (requester_id = auth.uid() and addressee_id = other_user_id)
        or (addressee_id = auth.uid() and requester_id = other_user_id)
      )
  );
$$;

revoke execute on function public.is_friend(uuid) from public;
grant  execute on function public.is_friend(uuid) to authenticated;

-- ============================================================
-- 5. USERNAME AVAILABILITY (pre-check, best-effort UX only — the
--    profiles_username_key unique index + profiles_username_format
--    check remain the actual authority; this can race and that's fine,
--    it only ever informs a hint, never gates the real write).
-- ============================================================

create function public.username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    candidate is not null
    and char_length(candidate) between 3 and 30
    and candidate ~ '^[a-z0-9]([a-z0-9]|[_.][a-z0-9])*$'
    and not exists (select 1 from public.profiles where username = candidate);
$$;

-- Callable while signed out too — this is what the signup form itself
-- calls before an account (and therefore a session) exists.
revoke execute on function public.username_available(text) from public;
grant  execute on function public.username_available(text) to anon, authenticated;

-- ============================================================
-- 6. FRIEND REQUEST STATE-TRANSITION RPCs
-- ============================================================

-- Creates a new pending request, or — the one deliberate exception to
-- "never resurrect a row" — flips an existing 'declined' row back to
-- pending if (and only if) the caller is the person who originally
-- declined it. That's a real "I changed my mind" action by the person
-- who has the right to change it; the original requester trying again
-- after being declined is exactly the spammy-re-request case this design
-- exists to prevent, and gets a clear error instead.
create function public.send_friend_request(target_user_id uuid)
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
    raise exception 'You cannot send yourself a friend request';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'That user could not be found';
  end if;

  select * into existing from public.friendships
    where least(requester_id, addressee_id) = least(me, target_user_id)
      and greatest(requester_id, addressee_id) = greatest(me, target_user_id);

  if existing.id is not null then
    case existing.status
      when 'accepted' then
        raise exception 'You are already friends';
      when 'pending' then
        raise exception 'A friend request is already pending';
      when 'blocked' then
        raise exception 'Unable to send a friend request';
      when 'declined' then
        if existing.addressee_id = me then
          -- The original decliner is now the one reaching out — a
          -- genuine new request, not a re-request. Start clean rather
          -- than mutating the old row's requester/addressee orientation
          -- in place.
          delete from public.friendships where id = existing.id;
        else
          raise exception 'This friend request was previously declined';
        end if;
    end case;
  end if;

  insert into public.friendships (requester_id, addressee_id, status)
  values (me, target_user_id, 'pending')
  returning * into result;

  return result;
end;
$$;

-- Only the addressee of a still-pending request may accept it — a
-- requester can never accept their own outgoing request, since the
-- WHERE clause below can only ever match rows where they are NOT the
-- requester who called this.
create function public.accept_friend_request(friendship_id uuid)
returns public.friendships
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.friendships;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.friendships
    set status = 'accepted', responded_at = now()
    where id = friendship_id
      and addressee_id = auth.uid()
      and status = 'pending'
    returning * into result;

  if result.id is null then
    raise exception 'That friend request is no longer available';
  end if;
  return result;
end;
$$;

-- Only the addressee may decline. The row is kept (not deleted) — see
-- send_friend_request's own comment for exactly what that unlocks/blocks.
create function public.decline_friend_request(friendship_id uuid)
returns public.friendships
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.friendships;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.friendships
    set status = 'declined', responded_at = now()
    where id = friendship_id
      and addressee_id = auth.uid()
      and status = 'pending'
    returning * into result;

  if result.id is null then
    raise exception 'That friend request is no longer available';
  end if;
  return result;
end;
$$;

-- Either participant may block the other from any prior state (including
-- re-blocking an already-blocked pair, which is a harmless no-op that
-- just re-affirms blocked_by). This intentionally has no matching
-- "unblock" RPC yet — out of Step 1's scope; see the report's Step 2
-- notes.
create function public.block_user(target_user_id uuid)
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
    raise exception 'You cannot block yourself';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'That user could not be found';
  end if;

  select * into existing from public.friendships
    where least(requester_id, addressee_id) = least(me, target_user_id)
      and greatest(requester_id, addressee_id) = greatest(me, target_user_id);

  if existing.id is not null then
    update public.friendships
      set status = 'blocked', blocked_by = me, responded_at = now()
      where id = existing.id
      returning * into result;
  else
    insert into public.friendships (requester_id, addressee_id, status, blocked_by, responded_at)
    values (me, target_user_id, 'blocked', me, now())
    returning * into result;
  end if;

  return result;
end;
$$;

revoke execute on function public.send_friend_request(uuid) from public;
revoke execute on function public.accept_friend_request(uuid) from public;
revoke execute on function public.decline_friend_request(uuid) from public;
revoke execute on function public.block_user(uuid) from public;
grant  execute on function public.send_friend_request(uuid) to authenticated;
grant  execute on function public.accept_friend_request(uuid) to authenticated;
grant  execute on function public.decline_friend_request(uuid) to authenticated;
grant  execute on function public.block_user(uuid) to authenticated;

-- ============================================================
-- 7. READ RPCs — identity + friendship-state reads that must work
--    regardless of profiles.is_public (profile DISCOVERABILITY is
--    deliberately not gated by that flag — see the architecture doc's
--    "profile identity vs activity visibility" split). Plain PostgREST
--    embedding through profiles_read RLS would silently hide a
--    private-profile friend/request counterpart's name; these RPCs read
--    profiles directly (SECURITY DEFINER bypasses RLS internally) and
--    return only the four safe identity columns, never anything else on
--    the row (no email, no auth metadata — profiles doesn't carry email
--    at all today, and these queries wouldn't select it if it did).
-- ============================================================

create function public.get_friends()
returns table (
  friendship_id uuid,
  friend_id uuid,
  username text,
  display_name text,
  avatar_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    f.id,
    case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end,
    p.username,
    p.display_name,
    p.avatar_url
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where f.status = 'accepted'
    and (f.requester_id = auth.uid() or f.addressee_id = auth.uid())
  order by p.username nulls last;
$$;

create function public.get_incoming_friend_requests()
returns table (
  friendship_id uuid,
  requester_id uuid,
  username text,
  display_name text,
  avatar_url text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select f.id, f.requester_id, p.username, p.display_name, p.avatar_url, f.created_at
  from public.friendships f
  join public.profiles p on p.id = f.requester_id
  where f.status = 'pending' and f.addressee_id = auth.uid()
  order by f.created_at desc;
$$;

create function public.get_outgoing_friend_requests()
returns table (
  friendship_id uuid,
  addressee_id uuid,
  username text,
  display_name text,
  avatar_url text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select f.id, f.addressee_id, p.username, p.display_name, p.avatar_url, f.created_at
  from public.friendships f
  join public.profiles p on p.id = f.addressee_id
  where f.status = 'pending' and f.requester_id = auth.uid()
  order by f.created_at desc;
$$;

-- Minimal identity + relationship state for one specific user — powers
-- the Friend/Non-Friend Profile screen when it's reached some way other
-- than tapping a just-fetched search result (e.g. a future deep link).
create function public.get_profile_identity(target_user_id uuid)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  relationship_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    case
      when f.status is null then null
      when f.status = 'accepted' then 'accepted'
      when f.status = 'pending' and f.requester_id = auth.uid() then 'pending_sent'
      when f.status = 'pending' and f.addressee_id = auth.uid() then 'pending_received'
      when f.status = 'declined' then 'declined'
      else null -- 'blocked' rows never surface a relationship state here
    end
  from public.profiles p
  left join public.friendships f
    on (f.requester_id = auth.uid() and f.addressee_id = p.id)
    or (f.addressee_id = auth.uid() and f.requester_id = p.id)
  where auth.uid() is not null
    and p.id = target_user_id
    and (f.status is null or f.status <> 'blocked');
$$;

-- Username search (§9-10 of the task) — prefix match, minimum 2
-- characters, excludes the caller and any blocked-either-direction pair,
-- deterministic order, hard-capped result count. Same relationship-state
-- shape as get_profile_identity so a search result and a profile screen
-- render identical "Add friend / Request sent / Friends" states from one
-- shared piece of Flutter logic.
create function public.search_profiles(query text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  relationship_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    case
      when f.status is null then null
      when f.status = 'accepted' then 'accepted'
      when f.status = 'pending' and f.requester_id = auth.uid() then 'pending_sent'
      when f.status = 'pending' and f.addressee_id = auth.uid() then 'pending_received'
      when f.status = 'declined' then 'declined'
      else null
    end
  from public.profiles p
  left join public.friendships f
    on (f.requester_id = auth.uid() and f.addressee_id = p.id)
    or (f.addressee_id = auth.uid() and f.requester_id = p.id)
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.username is not null
    and char_length(trim(query)) >= 2
    and p.username ilike (trim(query) || '%')
    and (f.status is null or f.status <> 'blocked')
  order by p.username
  limit 20;
$$;

revoke execute on function public.get_friends() from public;
revoke execute on function public.get_incoming_friend_requests() from public;
revoke execute on function public.get_outgoing_friend_requests() from public;
revoke execute on function public.get_profile_identity(uuid) from public;
revoke execute on function public.search_profiles(text) from public;
grant  execute on function public.get_friends() to authenticated;
grant  execute on function public.get_incoming_friend_requests() to authenticated;
grant  execute on function public.get_outgoing_friend_requests() to authenticated;
grant  execute on function public.get_profile_identity(uuid) to authenticated;
grant  execute on function public.search_profiles(text) to authenticated;

commit;
