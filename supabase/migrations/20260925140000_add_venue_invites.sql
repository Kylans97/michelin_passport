begin;

-- ============================================================
-- venue_invites — replaces the "Plan a dinner" stub
-- (friend_profile_dinner_invitation.dart) with the actual signal it was
-- always meant to be: "this is on my wishlist, shall we go together?".
-- Deliberately narrower than that stub's own sketched schema (no dates,
-- no meal type) — this is a proposal to go together, not a scheduling
-- tool. Accepting only flips `status`; the two people arrange the actual
-- visit themselves outside this table.
-- ============================================================

create table public.venue_invites (
  id            uuid primary key default gen_random_uuid(),
  from_user_id  uuid not null references public.profiles(id) on delete cascade,
  to_user_id    uuid not null references public.profiles(id) on delete cascade,
  venue_type    text not null check (venue_type in ('restaurant', 'hotel')),
  venue_id      uuid not null,
  note          text,
  status        text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  -- No auto-expire job anywhere in this schema (checked, not assumed —
  -- see the accept/decline RPCs below for where this is actually
  -- enforced, and get_notifications()'s invite_expires_at column for how
  -- the client renders "Expired" without the row ever disappearing).
  expires_at    timestamptz not null default (now() + interval '14 days'),
  constraint venue_invites_no_self_invite check (from_user_id <> to_user_id)
);

-- Blocks a second identical PENDING proposal (same sender, same
-- recipient, same venue) at the database level — send_venue_invite below
-- turns the resulting unique_violation into a friendly, visible message
-- rather than a silent no-op. Partial (WHERE status = 'pending') so a
-- declined invite can always be re-proposed later, mirroring
-- friendships' own "the decliner may re-request" precedent.
create unique index venue_invites_pending_uidx
  on public.venue_invites (from_user_id, to_user_id, venue_type, venue_id)
  where status = 'pending';

create index venue_invites_to_user_idx on public.venue_invites (to_user_id);
create index venue_invites_from_user_idx on public.venue_invites (from_user_id);

alter table public.venue_invites enable row level security;

create policy venue_invites_select on public.venue_invites
  for select to authenticated
  using (from_user_id = auth.uid() or to_user_id = auth.uid());

-- No insert/update policy for authenticated — every state transition
-- goes through a SECURITY DEFINER RPC below, mirroring friendships
-- exactly (see that migration's own comment for the rationale).
grant select on public.venue_invites to authenticated;

-- ============================================================
-- State-transition RPCs — same shape as send_friend_request/
-- accept_friend_request/decline_friend_request.
-- ============================================================

-- Reuses is_friend() (Social Foundation Step 1) rather than re-deriving
-- a friendship check here — defense in depth: the only entry point
-- (Friend Profile's Together tab) is already friend-scoped, but a direct
-- RPC call shouldn't be able to reach a stranger.
create function public.send_venue_invite(
  p_to_user_id uuid,
  p_venue_type text,
  p_venue_id uuid,
  p_note text default null
)
returns public.venue_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.venue_invites;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_to_user_id = auth.uid() then
    raise exception 'You cannot invite yourself';
  end if;
  if p_venue_type not in ('restaurant', 'hotel') then
    raise exception 'Invalid venue type';
  end if;
  if not public.is_friend(p_to_user_id) then
    raise exception 'You can only propose a venue to a friend';
  end if;

  begin
    insert into public.venue_invites (from_user_id, to_user_id, venue_type, venue_id, note)
    values (auth.uid(), p_to_user_id, p_venue_type, p_venue_id, p_note)
    returning * into result;
  exception when unique_violation then
    raise exception 'You already invited them to this place';
  end;

  return result;
end;
$$;

-- Only the recipient may accept, only while still pending AND not yet
-- expired — an expired-but-still-'pending' row can no longer be actioned
-- (the WHERE clause itself is the enforcement point; see the table
-- comment above for why there is no separate 'expired' status/job).
create function public.accept_venue_invite(p_invite_id uuid)
returns public.venue_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.venue_invites;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.venue_invites
    set status = 'accepted', responded_at = now()
    where id = p_invite_id
      and to_user_id = auth.uid()
      and status = 'pending'
      and expires_at > now()
    returning * into result;

  if result.id is null then
    raise exception 'That invitation is no longer available';
  end if;
  return result;
end;
$$;

create function public.decline_venue_invite(p_invite_id uuid)
returns public.venue_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.venue_invites;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.venue_invites
    set status = 'declined', responded_at = now()
    where id = p_invite_id
      and to_user_id = auth.uid()
      and status = 'pending'
      and expires_at > now()
    returning * into result;

  if result.id is null then
    raise exception 'That invitation is no longer available';
  end if;
  return result;
end;
$$;

-- This Supabase project has a default ACL (`pg_default_acl`, defaclrole
-- postgres, objtype 'f') that auto-grants EXECUTE to anon/authenticated on
-- every new function in `public`, independent of the schema's migrations —
-- confirmed live, the same phenomenon the friendships migration already
-- documented for table-level DML grants. `revoke ... from public` does not
-- touch a grant made directly to `anon` this way, so it's revoked
-- explicitly below too — these RPCs are meaningless to an unauthenticated
-- caller (each starts `if auth.uid() is null then raise exception`), but
-- "harmless by accident" isn't "designed safe", and it costs nothing to
-- close explicitly here since these functions are being created fresh.
revoke execute on function public.send_venue_invite(uuid, text, uuid, text) from public, anon;
revoke execute on function public.accept_venue_invite(uuid) from public, anon;
revoke execute on function public.decline_venue_invite(uuid) from public, anon;
grant  execute on function public.send_venue_invite(uuid, text, uuid, text) to authenticated;
grant  execute on function public.accept_venue_invite(uuid) to authenticated;
grant  execute on function public.decline_venue_invite(uuid) to authenticated;

-- ============================================================
-- Notifications integration — widen notifications, add the trigger,
-- extend get_notifications(). Mirrors notify_friendship_change() exactly.
-- ============================================================

alter table public.notifications drop constraint notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in (
    'friend_request_received',
    'friend_request_accepted',
    'missing_listing_added',
    'venue_invite_received',
    'venue_invite_accepted',
    'venue_invite_declined'
  ));

alter table public.notifications drop constraint notifications_subject_type_check;
alter table public.notifications add constraint notifications_subject_type_check
  check (subject_type in ('friendship', 'missing_listing_report', 'venue_invite'));

create function public.notify_venue_invite_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.to_user_id, 'venue_invite_received', 'venue_invite', new.id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'accepted' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.from_user_id, 'venue_invite_accepted', 'venue_invite', new.id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'declined' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.from_user_id, 'venue_invite_declined', 'venue_invite', new.id);
  end if;
  return new;
end;
$$;

create trigger venue_invites_notify_on_change
  after insert or update on public.venue_invites
  for each row
  execute function public.notify_venue_invite_change();

-- get_notifications() return shape is changing (6 new columns) —
-- CREATE OR REPLACE cannot change a function's return-table shape
-- (confirmed live, error 42P13, earlier this session) — drop and
-- recreate instead.
drop function public.get_notifications();

create function public.get_notifications()
returns table (
  id uuid,
  type text,
  subject_type text,
  subject_id uuid,
  is_read boolean,
  created_at timestamptz,
  other_user_id uuid,
  other_username text,
  other_display_name text,
  other_avatar_url text,
  listing_subject_type text,
  listing_name text,
  listing_city text,
  invite_venue_type text,
  invite_venue_name text,
  invite_venue_city text,
  invite_note text,
  invite_status text,
  invite_expires_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    n.id,
    n.type,
    n.subject_type,
    n.subject_id,
    n.is_read,
    n.created_at,
    coalesce(
      case when n.subject_type = 'friendship'
        then case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
      end,
      case when n.subject_type = 'venue_invite'
        then case when vi.from_user_id = auth.uid() then vi.to_user_id else vi.from_user_id end
      end
    ) as other_user_id,
    p.username as other_username,
    p.display_name as other_display_name,
    p.avatar_url as other_avatar_url,
    mlr.subject_type as listing_subject_type,
    mlr.name as listing_name,
    mlr.city as listing_city,
    vi.venue_type as invite_venue_type,
    coalesce(rf.name, hf.name) as invite_venue_name,
    coalesce(rf.city_name, hf.city_name) as invite_venue_city,
    vi.note as invite_note,
    vi.status as invite_status,
    vi.expires_at as invite_expires_at
  from public.notifications n
  left join public.friendships f
    on n.subject_type = 'friendship' and f.id = n.subject_id
  left join public.venue_invites vi
    on n.subject_type = 'venue_invite' and vi.id = n.subject_id
  left join public.restaurants_full rf
    on vi.venue_type = 'restaurant' and rf.id = vi.venue_id
  left join public.hotels_full hf
    on vi.venue_type = 'hotel' and hf.id = vi.venue_id
  left join public.profiles p
    on p.id = coalesce(
      case when n.subject_type = 'friendship'
        then case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
      end,
      case when n.subject_type = 'venue_invite'
        then case when vi.from_user_id = auth.uid() then vi.to_user_id else vi.from_user_id end
      end
    )
  left join public.missing_listing_reports mlr
    on n.subject_type = 'missing_listing_report' and mlr.id = n.subject_id
  where n.recipient_id = auth.uid()
  order by n.created_at desc;
$$;

-- Closing the same default-ACL gap noted above for this recreated
-- function too — confirmed live that the current, pre-this-migration
-- get_notifications() already has this same anon grant (created after
-- whatever point the default ACL was set up; the older friend-request
-- RPCs predate it and don't). Recreating it here is the natural point to
-- fix it, not a separate, unrelated change.
revoke execute on function public.get_notifications() from public, anon;
grant execute on function public.get_notifications() to authenticated;

commit;
