-- The venue team grows, and venues get an Instagram link.
--
--   1. A third role, sommelier, beside chef and manager. The page shows
--      them in that order: chef, manager, sommelier (decided 2026-11-02).
--   2. A photo per team member, optional. It's uploaded with the
--      submission to the private venue-photo-submissions bucket and
--      reviewed with the name and text. On approval, publish-venue-photo
--      copies it to the public catalogue-media bucket and records its URL
--      through approve_venue_team_photo(), the same path a venue photo
--      takes (CLAUDE.md: photo publishing goes through that function).
--      A submission without a new photo keeps the role's current photo,
--      unless it asks to remove it (remove_photo).
--   3. The team text may be longer (280 → 600 characters): the page now
--      shows a short strip, and the full text in a sheet per person.
--   4. An Instagram account per venue (restaurant, hotel or private
--      chef), reviewed like everything else a venue supplies. The page
--      shows the latest approved handle; a manager may take it off
--      directly, as with a team member.
--
-- Installed builds keep working: VenueTeamMember.fromJson skips a role
-- it doesn't know, ReviewItem.fromJson skips a kind it doesn't know, and
-- get_review_queue only gains columns at the end.
--
-- Every new SECURITY DEFINER function carries its own
-- `revoke execute ... from public, anon` in this file (CLAUDE.md).
--
-- Real date: 2026-11-02. The filename is a sequence number, the next one
-- after the highest existing migration (20261101160000), per CLAUDE.md.

begin;

-- ============================================================
-- 1. Team: sommelier, photos, longer text
-- ============================================================

alter table public.venue_team_submissions
  drop constraint venue_team_submissions_role_check,
  add constraint venue_team_submissions_role_check
    check (role in ('manager', 'chef', 'sommelier'));

alter table public.venue_team_submissions
  drop constraint venue_team_submissions_bio_check,
  add constraint venue_team_submissions_bio_check
    check (bio is null or char_length(bio) <= 600);

alter table public.venue_team_submissions
  add column photo_path text,
  add column remove_photo boolean not null default false,
  add column photo_url text;

-- A new photo always goes with a submission; asking to remove one and
-- sending one at the same time makes no sense.
alter table public.venue_team_submissions
  add constraint venue_team_submissions_photo_choice_check
    check (not (remove_photo and photo_path is not null));

-- The insert policy gains one condition: a photo must sit in the
-- submitter's own folder for this venue, the same layout the bucket's
-- own insert policy enforces (<venue_type>/<venue_id>/<user id>/...).
drop policy venue_team_submissions_insert on public.venue_team_submissions;
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
    and photo_url is null
    and (
      photo_path is null
      or photo_path like venue_type || '/' || venue_id::text || '/' || auth.uid()::text || '/%'
    )
  );

-- photo_url is set by approval only, so it's not in the insert grant.
-- anon may read the published URL, never the private upload path.
grant select (photo_url) on public.venue_team_submissions to anon;
grant insert (photo_path, remove_photo) on public.venue_team_submissions to authenticated;

-- The view gains photo_url at the end; columns can only be appended.
create or replace view public.venue_team_current
with (security_invoker = true)
as
select distinct on (venue_type, venue_id, role)
  venue_type, venue_id, role, name, bio, reviewed_at as approved_at, photo_url
from public.venue_team_submissions
where status = 'approved' and removed_at is null
order by venue_type, venue_id, role, reviewed_at desc nulls last, submitted_at desc;

-- The photo a role shows now, which an approval without a new photo
-- carries over. Internal: called only by the two approval functions.
create function public.venue_team_current_photo(
  p_venue_type text,
  p_venue_id uuid,
  p_role text
)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select c.photo_url
    from public.venue_team_current c
   where c.venue_type = p_venue_type and c.venue_id = p_venue_id and c.role = p_role;
$$;

revoke execute on function public.venue_team_current_photo(text, uuid, text) from public, anon, authenticated;

-- Approving in the app, for a submission without a new photo. One with a
-- photo must go through publish-venue-photo, or it would show without it.
create or replace function public.admin_approve_venue_team(p_submission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.venue_team_submissions%rowtype;
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  select * into v_row from public.venue_team_submissions
   where id = p_submission_id and status = 'pending' and removed_at is null
   for update;
  if not found then
    raise exception 'venue_team_submissions % is not pending (or does not exist)', p_submission_id;
  end if;
  if v_row.photo_path is not null then
    raise exception 'venue_team_submissions % has a photo: approve it through publish-venue-photo', p_submission_id;
  end if;
  update public.venue_team_submissions
     set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid(),
         photo_url = case
           when v_row.remove_photo then null
           else public.venue_team_current_photo(v_row.venue_type, v_row.venue_id, v_row.role)
         end
   where id = p_submission_id;
end;
$$;

revoke execute on function public.admin_approve_venue_team(uuid) from public, anon;
grant execute on function public.admin_approve_venue_team(uuid) to authenticated;

-- Approving a submission with a photo, after publish-venue-photo has
-- copied it to catalogue-media and verified the copy. Called by that
-- function with the service role only, never by a client; the reviewer
-- is the admin the function resolved from the caller's session.
create function public.approve_venue_team_photo(
  p_submission_id uuid,
  p_reviewed_by uuid,
  p_photo_url text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_reviewed_by is null
     or not exists (select 1 from public.admins a where a.user_id = p_reviewed_by) then
    raise exception 'p_reviewed_by must be an admin, got %', p_reviewed_by;
  end if;
  if p_photo_url is null or p_photo_url not like 'https://%' then
    raise exception 'p_photo_url must be the published https URL, got %', p_photo_url;
  end if;
  update public.venue_team_submissions
     set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by,
         photo_url = p_photo_url
   where id = p_submission_id and status = 'pending' and removed_at is null
     and photo_path is not null;
  if not found then
    raise exception 'venue_team_submissions % is not a pending submission with a photo', p_submission_id;
  end if;
end;
$$;

revoke execute on function public.approve_venue_team_photo(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.approve_venue_team_photo(uuid, uuid, text) to service_role;

-- ============================================================
-- 2. Instagram
-- ============================================================

create table public.venue_instagram_submissions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  venue_type    text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id      uuid not null,
  -- The account name alone, without @ or URL: Instagram's own rule,
  -- letters, digits, dots and underscores, at most 30.
  handle        text not null check (handle ~ '^[A-Za-z0-9._]{1,30}$'),
  status        text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  submitted_at  timestamptz not null default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references public.profiles(id) on delete set null,
  review_note   text,
  removed_at    timestamptz,
  removed_by    uuid references public.profiles(id) on delete set null
);

create index venue_instagram_submissions_venue_idx
  on public.venue_instagram_submissions (venue_type, venue_id);

create index venue_instagram_submissions_pending_idx
  on public.venue_instagram_submissions (submitted_at)
  where status = 'pending' and removed_at is null;

alter table public.venue_instagram_submissions enable row level security;

create policy venue_instagram_submissions_own_read on public.venue_instagram_submissions
  for select to authenticated using (user_id = auth.uid());

create policy venue_instagram_submissions_public_read on public.venue_instagram_submissions
  for select to anon, authenticated
  using (status = 'approved' and removed_at is null);

create policy venue_instagram_submissions_insert on public.venue_instagram_submissions
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

revoke all on table public.venue_instagram_submissions from public, anon, authenticated;
grant select (venue_type, venue_id, handle, status, submitted_at, reviewed_at, removed_at)
  on public.venue_instagram_submissions to anon;
grant select on public.venue_instagram_submissions to authenticated;
grant insert (user_id, venue_type, venue_id, handle)
  on public.venue_instagram_submissions to authenticated;

create view public.venue_instagram_current
with (security_invoker = true)
as
select distinct on (venue_type, venue_id)
  venue_type, venue_id, handle, reviewed_at as approved_at
from public.venue_instagram_submissions
where status = 'approved' and removed_at is null
order by venue_type, venue_id, reviewed_at desc nulls last, submitted_at desc;

grant select on public.venue_instagram_current to anon, authenticated;

create function public.remove_venue_instagram(p_venue_type text, p_venue_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Not a manager of this venue';
  end if;
  update public.venue_instagram_submissions
     set removed_at = now(), removed_by = auth.uid()
   where venue_type = p_venue_type
     and venue_id = p_venue_id
     and status in ('approved', 'pending')
     and removed_at is null;
end;
$$;

revoke execute on function public.remove_venue_instagram(text, uuid) from public, anon;
grant execute on function public.remove_venue_instagram(text, uuid) to authenticated;

create function public.admin_approve_venue_instagram(p_submission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.venue_instagram_submissions
     set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   where id = p_submission_id and status = 'pending' and removed_at is null;
  if not found then
    raise exception 'venue_instagram_submissions % is not pending (or does not exist)', p_submission_id;
  end if;
end;
$$;

create function public.admin_reject_venue_instagram(p_submission_id uuid, p_review_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.venue_instagram_submissions
     set status = 'rejected', reviewed_at = now(), reviewed_by = auth.uid(),
         review_note = nullif(btrim(p_review_note), '')
   where id = p_submission_id and status = 'pending' and removed_at is null;
  if not found then
    raise exception 'venue_instagram_submissions % is not pending (or does not exist)', p_submission_id;
  end if;
end;
$$;

revoke execute on function public.admin_approve_venue_instagram(uuid) from public, anon;
revoke execute on function public.admin_reject_venue_instagram(uuid, text) from public, anon;
grant execute on function public.admin_approve_venue_instagram(uuid) to authenticated;
grant execute on function public.admin_reject_venue_instagram(uuid, text) to authenticated;

-- ============================================================
-- 3. The review queue: team photos and Instagram
-- ============================================================
-- 20261030170000's definition unchanged, plus team_photo_path,
-- team_remove_photo and instagram_handle appended and the
-- venue_instagram branch. The return type changes, so drop and recreate.

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
  team_bio text,
  team_photo_path text,
  team_remove_photo boolean,
  instagram_handle text
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
           null::text as t_role, null::text as t_name, null::text as t_bio,
           null::text as t_photo, null::boolean as t_remove_photo, null::text as ig_handle
      from public.claims_restaurants c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'hotel', c.hotel_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null
      from public.claims_hotels c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'private_chef', c.private_chef_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null
      from public.claims_private_chefs c where c.status = 'pending'
    union all
    select 'venue_about', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           s.about_text, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null
      from public.venue_about_submissions s where s.status = 'pending'
    union all
    select 'venue_photo', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           null, s.storage_path, s.replaces_photo_id, s.duplicate_of_submission_id,
           s.focus_x, s.focus_y, s.zoom, null, null,
           null, null, null, null, null, null
      from public.venue_photo_submissions s where s.status = 'pending'
    union all
    select 'venue_event', e.id, h.venue_type, h.venue_id, e.submitted_by,
           coalesce(e.submitted_at, e.created_at),
           null, null, null, null,
           null, null, null, null, null, null, null, e.id, null,
           null, null, null, null, null, null
      from public.events e
      left join lateral public.event_host_venue(e.id) h on true
     where e.moderation_status = 'submitted' and e.cancelled_at is null
    union all
    select 'venue_event_edit', x.id, h.venue_type, h.venue_id, x.edited_by, x.edited_at,
           null, null, null, null,
           null, null, null, null, null, null, null, x.event_id, x.changes,
           null, null, null, null, null, null
      from public.event_edits x
      left join lateral public.event_host_venue(x.event_id) h on true
     where x.seen_at is null
    union all
    select 'venue_team', t.id, t.venue_type, t.venue_id, t.user_id, t.submitted_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           t.role, t.name, t.bio, t.photo_path, t.remove_photo, null
      from public.venue_team_submissions t
     where t.status = 'pending' and t.removed_at is null
    union all
    select 'venue_instagram', g.id, g.venue_type, g.venue_id, g.user_id, g.submitted_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, g.handle
      from public.venue_instagram_submissions g
     where g.status = 'pending' and g.removed_at is null
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
         i.t_role, i.t_name, i.t_bio, i.t_photo, i.t_remove_photo, i.ig_handle
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
