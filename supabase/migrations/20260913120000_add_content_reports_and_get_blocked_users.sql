-- Block/Report UI foundation: a general content-reporting table (Apple
-- requires this for apps with user-generated content) plus the one RPC
-- missing from the block/unblock pair that's already live — a way to
-- list who *you* have blocked, so the block UI isn't one-way.
--
-- content_reports follows venue_corrections' own shape exactly: owner-
-- insert, owner-read-only, no client update/delete (moderation happens
-- by hand, via service role).

begin;

create table public.content_reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null references public.profiles(id) on delete cascade,
  content_type text not null check (content_type in ('photo', 'rating', 'profile', 'event')),
  content_id   uuid not null,
  reason       text not null check (reason in ('inappropriate', 'spam', 'misleading', 'other')),
  details      text,
  created_at   timestamptz not null default now(),
  status       text not null default 'open' check (status in ('open', 'resolved'))
);

create index content_reports_content_idx on public.content_reports (content_type, content_id);

alter table public.content_reports enable row level security;

-- Owner-only read, exactly like venue_corrections_own_read: a report is
-- never itself published content — only the reporter and the reviewer
-- (service role) ever see it.
create policy content_reports_own_read on public.content_reports
  for select to authenticated using (reporter_id = auth.uid());

create policy content_reports_insert on public.content_reports
  for insert to authenticated with check (reporter_id = auth.uid());

-- No update/delete policy for any client role — status changes to
-- 'resolved' happen by hand, via service role, same as venue_corrections.

grant select, insert on public.content_reports to authenticated;

-- get_blocked_users(): friendships is self-referencing (requester_id/
-- addressee_id) with no fixed "other party" column, so a plain client
-- select can't resolve who's on the other end of a blocked pair without
-- knowing in advance which side the caller is on. Security definer,
-- same shape as block_user/unblock_user — returns only the caller's own
-- blocks (blocked_by = auth.uid()), never anyone else's.
create function public.get_blocked_users()
returns table (
  friendship_id uuid,
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  blocked_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    f.id,
    p.id,
    p.display_name,
    p.username,
    p.avatar_url,
    f.responded_at
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where f.status = 'blocked'
    and f.blocked_by = auth.uid();
$$;

revoke all on function public.get_blocked_users() from public;
grant execute on function public.get_blocked_users() to authenticated;

commit;
