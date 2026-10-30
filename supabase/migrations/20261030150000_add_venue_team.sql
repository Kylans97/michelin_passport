-- The team on a venue's page: a restaurant (or hotel) manager and a
-- chef, each a name and a short text, written by the venue itself.
--
-- Venue-supplied content (CLAUDE.md): the names and texts come from the
-- venue, so they follow venue_about_submissions exactly — a submission
-- waits for an admin, and the page shows the latest approved one per
-- role through a view. It is new descriptive copy shown under the
-- venue's name, not presentation of something already reviewed (the
-- reason photo framing skips review), so it is reviewed like an about
-- text (decided 2026-10-30).
--
-- How the pieces fit:
--   - venue_team_submissions: one row per submitted name + text for one
--     role. Managers insert (is_active_venue_manager() is the only gate,
--     never the claims tables) and only ever as pending: the insert
--     grant covers the content columns alone, and the policy checks the
--     moderation columns are untouched. No client update or delete.
--   - venue_team_current: the latest approved, not removed submission
--     per (venue, role). What the detail page reads.
--   - remove_venue_team_member(): taking someone off the page needs no
--     review (nothing new is shown), so a manager does it directly. It
--     marks every row for that role removed — approved and pending — so
--     a pending one can't reappear on approval afterwards.
--   - admin_approve_venue_team / admin_reject_venue_team: the in-app
--     review, checking is_admin() and recording auth.uid().
--   - get_review_queue() gains the kind 'venue_team' and three columns
--     at the end. Installed builds skip kinds they don't know
--     (ReviewItem.fromJson) and ignore extra columns.
--
-- Restaurants and hotels only: a private chef's page is the chef.
--
-- Not here, on purpose: a notification to the venue on approval or
-- rejection (new notification types need a new get_notifications_vN
-- pair; the Team screen shows the outcome instead), and the admin email
-- on a new submission (notify-venue-submission rejects a submission type
-- it doesn't know, so it needs a function change and deploy first).
--
-- Every new SECURITY DEFINER function carries its own
-- `revoke execute ... from public, anon` in this file (CLAUDE.md).
--
-- Real date: 2026-10-30. The filename is a sequence number, the next one
-- after the highest existing migration (20261030140000), per CLAUDE.md.

begin;

-- ============================================================
-- 1. Submissions
-- ============================================================

create table public.venue_team_submissions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  venue_type    text not null check (venue_type in ('restaurant', 'hotel')),
  venue_id      uuid not null,
  role          text not null check (role in ('manager', 'chef')),
  name          text not null check (char_length(btrim(name)) between 1 and 80),
  bio           text check (bio is null or char_length(bio) <= 280),
  status        text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  submitted_at  timestamptz not null default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references public.profiles(id) on delete set null,
  review_note   text,
  removed_at    timestamptz,
  removed_by    uuid references public.profiles(id) on delete set null
);

create index venue_team_submissions_venue_idx
  on public.venue_team_submissions (venue_type, venue_id, role);

create index venue_team_submissions_pending_idx
  on public.venue_team_submissions (submitted_at)
  where status = 'pending' and removed_at is null;

alter table public.venue_team_submissions enable row level security;

create policy venue_team_submissions_own_read on public.venue_team_submissions
  for select to authenticated using (user_id = auth.uid());

create policy venue_team_submissions_public_read on public.venue_team_submissions
  for select to anon, authenticated
  using (status = 'approved' and removed_at is null);

create policy venue_team_submissions_insert on public.venue_team_submissions
  for insert to authenticated with check (
    user_id = auth.uid()
    and public.is_active_venue_manager(venue_type, venue_id)
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
    and review_note is null
    and removed_at is null
    and removed_by is null
  );

-- anon reads only what the view shows (and filters on), never who
-- submitted or reviewed. authenticated reads whole rows, for the
-- manager's own submissions and their status; RLS limits it to those
-- plus the public approved ones, as on venue_about_submissions.
revoke all on table public.venue_team_submissions from public, anon, authenticated;
grant select (venue_type, venue_id, role, name, bio, status, submitted_at, reviewed_at, removed_at)
  on public.venue_team_submissions to anon;
grant select on public.venue_team_submissions to authenticated;
grant insert (user_id, venue_type, venue_id, role, name, bio)
  on public.venue_team_submissions to authenticated;

-- Safe as security_invoker: the base table already lets anyone read the
-- approved, not removed rows, and only those are selected.
create view public.venue_team_current
with (security_invoker = true)
as
select distinct on (venue_type, venue_id, role)
  venue_type, venue_id, role, name, bio, reviewed_at as approved_at
from public.venue_team_submissions
where status = 'approved' and removed_at is null
order by venue_type, venue_id, role, reviewed_at desc nulls last, submitted_at desc;

grant select on public.venue_team_current to anon, authenticated;

-- ============================================================
-- 2. A manager takes someone off the page
-- ============================================================

create function public.remove_venue_team_member(
  p_venue_type text,
  p_venue_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Not a manager of this venue';
  end if;
  update public.venue_team_submissions
     set removed_at = now(), removed_by = auth.uid()
   where venue_type = p_venue_type
     and venue_id = p_venue_id
     and role = p_role
     and status in ('approved', 'pending')
     and removed_at is null;
end;
$$;

revoke execute on function public.remove_venue_team_member(text, uuid, text) from public, anon;
grant execute on function public.remove_venue_team_member(text, uuid, text) to authenticated;

-- ============================================================
-- 3. Review
-- ============================================================

create function public.admin_approve_venue_team(p_submission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.venue_team_submissions
     set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   where id = p_submission_id and status = 'pending' and removed_at is null;
  if not found then
    raise exception 'venue_team_submissions % is not pending (or does not exist)', p_submission_id;
  end if;
end;
$$;

create function public.admin_reject_venue_team(p_submission_id uuid, p_review_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.venue_team_submissions
     set status = 'rejected', reviewed_at = now(), reviewed_by = auth.uid(),
         review_note = nullif(btrim(p_review_note), '')
   where id = p_submission_id and status = 'pending' and removed_at is null;
  if not found then
    raise exception 'venue_team_submissions % is not pending (or does not exist)', p_submission_id;
  end if;
end;
$$;

revoke execute on function public.admin_approve_venue_team(uuid) from public, anon;
revoke execute on function public.admin_reject_venue_team(uuid, text) from public, anon;
grant execute on function public.admin_approve_venue_team(uuid) to authenticated;
grant execute on function public.admin_reject_venue_team(uuid, text) to authenticated;

-- ============================================================
-- 4. The review queue, with venue_team
-- ============================================================
-- 20261018130000's definition unchanged, plus the venue_team branch and
-- team_role/team_name/team_bio appended. The return type changes, so
-- drop and recreate.

drop function public.get_review_queue();

create function public.get_review_queue()
returns table (
  kind text,
  item_id uuid,
  venue_type text,
  venue_id uuid,
  venue_name text,
  venue_city text,
  submitted_by uuid,
  submitter_label text,
  submitted_at timestamptz,
  claim_role text,
  claim_business_email text,
  claim_phone text,
  claim_notes text,
  about_text text,
  photo_storage_path text,
  photo_replaces_photo_id uuid,
  photo_duplicate_of uuid,
  photo_focus_x numeric,
  photo_focus_y numeric,
  photo_zoom numeric,
  event_id uuid,
  event_name text,
  event_start_date date,
  event_changes jsonb,
  team_role text,
  team_name text,
  team_bio text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Not an admin';
  end if;
  return query
  with items as (
    select 'venue_claim'::text as kind, c.id as item_id, 'restaurant'::text as venue_type,
           c.restaurant_id as venue_id, c.user_id, c.requested_at as at,
           c.role, c.business_email, c.phone, c.notes,
           null::text as about_text, null::text as storage_path, null::uuid as replaces,
           null::uuid as dup, null::numeric as fx, null::numeric as fy, null::numeric as z,
           null::uuid as ev_id, null::jsonb as changes,
           null::text as t_role, null::text as t_name, null::text as t_bio
      from public.claims_restaurants c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'hotel', c.hotel_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null
      from public.claims_hotels c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'private_chef', c.private_chef_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null
      from public.claims_private_chefs c where c.status = 'pending'
    union all
    select 'venue_about', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           s.about_text, null, null, null, null, null, null, null, null,
           null, null, null
      from public.venue_about_submissions s where s.status = 'pending'
    union all
    select 'venue_photo', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           null, s.storage_path, s.replaces_photo_id, s.duplicate_of_submission_id,
           s.focus_x, s.focus_y, s.zoom, null, null,
           null, null, null
      from public.venue_photo_submissions s where s.status = 'pending'
    union all
    select 'venue_event', e.id, h.venue_type, h.venue_id, e.submitted_by,
           coalesce(e.submitted_at, e.created_at),
           null, null, null, null,
           null, null, null, null, null, null, null, e.id, null,
           null, null, null
      from public.events e
      left join lateral public.event_host_venue(e.id) h on true
     where e.moderation_status = 'submitted' and e.cancelled_at is null
    union all
    select 'venue_event_edit', x.id, h.venue_type, h.venue_id, x.edited_by, x.edited_at,
           null, null, null, null,
           null, null, null, null, null, null, null, x.event_id, x.changes,
           null, null, null
      from public.event_edits x
      left join lateral public.event_host_venue(x.event_id) h on true
     where x.seen_at is null
    union all
    select 'venue_team', t.id, t.venue_type, t.venue_id, t.user_id, t.submitted_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           t.role, t.name, t.bio
      from public.venue_team_submissions t
     where t.status = 'pending' and t.removed_at is null
  )
  select i.kind, i.item_id, i.venue_type, i.venue_id,
         coalesce(r.name, h.name, pc.display_name) as venue_name,
         coalesce(rc.name, hc.name, pc.home_city) as venue_city,
         i.user_id,
         coalesce(nullif(trim(p.display_name), ''), '@' || p.username, 'Mantelier member') as submitter_label,
         i.at,
         i.role, i.business_email, i.phone, i.notes,
         i.about_text, i.storage_path, i.replaces, i.dup, i.fx, i.fy, i.z,
         i.ev_id, ev.name, ev.start_date, i.changes,
         i.t_role, i.t_name, i.t_bio
    from items i
    left join public.restaurants r on i.venue_type = 'restaurant' and r.id = i.venue_id
    left join public.cities rc on rc.id = r.city_id
    left join public.hotels h on i.venue_type = 'hotel' and h.id = i.venue_id
    left join public.cities hc on hc.id = h.city_id
    left join public.private_chefs pc on i.venue_type = 'private_chef' and pc.id = i.venue_id
    left join public.profiles p on p.id = i.user_id
    left join public.events ev on ev.id = i.ev_id
   order by i.at;
end;
$$;

revoke execute on function public.get_review_queue() from public, anon;
grant execute on function public.get_review_queue() to authenticated;

commit;
