begin;

-- ============================================================
-- In-app notifications — the delivery layer underneath; push is a
-- separate, later project (per explicit instruction, this migration
-- only builds the storage/creation/read layer, nothing device-facing).
-- ============================================================
--
-- Polymorphic reference shape matches content_reports/venue_corrections/
-- missing_listing_reports exactly: a type-discriminator + bare uuid, no
-- FK, since subject_id points at different tables depending on
-- subject_type. Kept as a SEPARATE column from `type` below, rather than
-- collapsing the two: friend_request_received and friend_request_accepted
-- both point at the same kind of subject (a friendships row), so `type`
-- alone can't also carry "which table subject_id belongs to".
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in (
    'friend_request_received',
    'friend_request_accepted',
    'missing_listing_added'
  )),
  subject_type text not null check (subject_type in ('friendship', 'missing_listing_report')),
  subject_id uuid not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);

comment on table public.notifications is
  'In-app notifications only -- no push delivery yet (a separate, later '
  'project). Created server-side only: a trigger on friendships for the '
  'two friend-request types, or by the operator by hand for '
  'missing_listing_added -- missing_listing_reports has no status or '
  'linkage column to hang a trigger off of (see that table''s own '
  'migration), so that type has no possible automatic source today.';

alter table public.notifications enable row level security;

create policy notifications_select on public.notifications
  for select to authenticated
  using (recipient_id = auth.uid());

-- Plain, full-row update policy -- matches every other UPDATE policy in
-- this codebase (profiles_update, visits_update, etc.); none restrict
-- which columns may change, and there is no precedent here for a
-- column-restricted policy. The only person who could misuse the extra
-- latitude is the owner, on their own row -- harmless.
create policy notifications_update on public.notifications
  for update to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

-- Deliberately NO insert policy and NO insert grant for authenticated or
-- anon -- notifications are created server-side only. Trigger functions
-- run as the table owner and bypass this; the operator writes the one
-- type with no trigger via the dashboard/service role.
grant select, update on public.notifications to authenticated;

-- ============================================================
-- Friendships trigger.
-- ============================================================
--
-- Both notification-worthy transitions are a single plain statement on
-- one row -- send_friend_request does one INSERT (always status =
-- 'pending'); accept_friend_request does one UPDATE ... SET status =
-- 'accepted' (confirmed against that RPC's own body) -- so a row-level
-- AFTER trigger cleanly captures both with no risk of missing one, per
-- the explicit request to make this a trigger rather than an app-side
-- write that could be skipped.
create function public.notify_friendship_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.addressee_id, 'friend_request_received', 'friendship', new.id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'accepted' then
    -- The ORIGINAL sender gets notified their request was accepted.
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.requester_id, 'friend_request_accepted', 'friendship', new.id);
  end if;
  return new;
end;
$$;

create trigger friendships_notify_on_change
  after insert or update on public.friendships
  for each row
  execute function public.notify_friendship_change();

-- ============================================================
-- get_notifications() -- resolves per-type display context in one call.
-- Needed because profiles_read is fully owner-only (a plain client-side
-- join to the other participant's profile returns nothing) and
-- missing_listing_reports has no select grant for anyone but the
-- operator -- the same reason get_incoming_friend_requests/
-- get_profile_identity already exist as security definer functions.
-- ============================================================

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
  listing_city text
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
    case when n.subject_type = 'friendship'
      then case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
    end as other_user_id,
    p.username as other_username,
    p.display_name as other_display_name,
    p.avatar_url as other_avatar_url,
    mlr.subject_type as listing_subject_type,
    mlr.name as listing_name,
    mlr.city as listing_city
  from public.notifications n
  left join public.friendships f
    on n.subject_type = 'friendship' and f.id = n.subject_id
  left join public.profiles p
    on p.id = (case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end)
  left join public.missing_listing_reports mlr
    on n.subject_type = 'missing_listing_report' and mlr.id = n.subject_id
  where n.recipient_id = auth.uid()
  order by n.created_at desc;
$$;

revoke execute on function public.get_notifications() from public;
grant execute on function public.get_notifications() to authenticated;

-- ============================================================
-- get_unread_notification_count() -- a lightweight count for a badge,
-- kept separate from get_notifications() so showing a number (e.g. on
-- the Profile screen's Notifications row) never requires fetching and
-- joining every notification just to learn how many are unread.
-- ============================================================

create function public.get_unread_notification_count()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false;
$$;

revoke execute on function public.get_unread_notification_count() from public;
grant execute on function public.get_unread_notification_count() to authenticated;

commit;
