-- In-app review: a small, explicit set of admins, and admin-only RPCs
-- that let them review venue claims, about texts and photos from the app
-- instead of the Supabase dashboard. Phase 1 of
-- docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md.
--
-- This revises a settled CLAUDE.md decision on purpose (decided by the
-- product owner on 2026-10-28): "There is no in-app admin identity and
-- none is planned — review happens through the dashboard with
-- service_role." Review now happens in the app by the admins listed in
-- public.admins; the dashboard and service_role stay as the fallback.
--
-- How the pieces fit:
--   - public.admins: who may review. RLS on, no client policy and no
--     client grant at all — rows are added by hand in the dashboard,
--     the one step that deliberately stays there.
--   - is_admin(): the only source of that permission, the way
--     is_active_venue_manager() is for venue edits.
--   - get_review_queue(): everything waiting, oldest first, across
--     kinds, with what the queue screen shows. Admin-only.
--   - admin_* wrappers around the existing review functions
--     (20261005120000). Those were written to take an explicit
--     p_reviewed_by precisely so "a later in-app admin screen" could pass
--     auth.uid() — these wrappers are that caller. The originals keep
--     their dashboard-only ACL, so the fallback keeps working unchanged.
--     Notifications to the venue are unchanged too: they fire from the
--     existing triggers on the status change, whoever makes it.
--   - Photo approval is not a wrapper here: it needs the file copied out
--     of the private bucket first, which the publish-venue-photo Edge
--     Function already does. That function gains an admin-JWT path in
--     the same change.
--   - Admins may read the private venue-photo-submissions bucket, so
--     the review screen can show a pending photo through a signed URL.
--
-- An admin may approve their own submissions (decided 2026-10-28: there
-- is one admin today, and Mantelier may organise its own events), so
-- nothing here refuses a reviewer who manages the venue in question.
--
-- Every new SECURITY DEFINER function carries its own
-- `revoke execute ... from public, anon` in this file (CLAUDE.md).
--
-- Real date: 2026-10-28. The filename is a sequence number, the next one
-- after the highest existing migration (20261016140000), per CLAUDE.md.

begin;

-- ============================================================
-- 1. Admins
-- ============================================================

create table public.admins (
  user_id  uuid primary key references public.profiles(id) on delete cascade,
  added_at timestamptz not null default now(),
  note     text
);

alter table public.admins enable row level security;
revoke all on table public.admins from public, anon, authenticated;

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
     and exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ============================================================
-- 2. The review queue
-- ============================================================
-- One row per thing waiting. detail carries the kind's own payload: the
-- claim's role/contact/notes, or the about text; for a photo, the
-- storage path plus framing, so the screen can sign a URL and show it in
-- its real frames. Venue name/city resolved here (SECURITY DEFINER), so
-- the screen needs no extra lookups and works for a private chef too.

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
  photo_zoom numeric
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
           null::uuid as dup, null::numeric as fx, null::numeric as fy, null::numeric as z
      from public.claims_restaurants c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'hotel', c.hotel_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null
      from public.claims_hotels c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'private_chef', c.private_chef_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null
      from public.claims_private_chefs c where c.status = 'pending'
    union all
    select 'venue_about', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           s.about_text, null, null, null, null, null, null
      from public.venue_about_submissions s where s.status = 'pending'
    union all
    select 'venue_photo', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           null, s.storage_path, s.replaces_photo_id, s.duplicate_of_submission_id,
           s.focus_x, s.focus_y, s.zoom
      from public.venue_photo_submissions s where s.status = 'pending'
  )
  select i.kind, i.item_id, i.venue_type, i.venue_id,
         coalesce(r.name, h.name, pc.display_name) as venue_name,
         coalesce(rc.name, hc.name, pc.home_city) as venue_city,
         i.user_id,
         coalesce(nullif(trim(p.display_name), ''), '@' || p.username, 'Mantelier member') as submitter_label,
         i.at,
         i.role, i.business_email, i.phone, i.notes,
         i.about_text, i.storage_path, i.replaces, i.dup, i.fx, i.fy, i.z
    from items i
    left join public.restaurants r on i.venue_type = 'restaurant' and r.id = i.venue_id
    left join public.cities rc on rc.id = r.city_id
    left join public.hotels h on i.venue_type = 'hotel' and h.id = i.venue_id
    left join public.cities hc on hc.id = h.city_id
    left join public.private_chefs pc on i.venue_type = 'private_chef' and pc.id = i.venue_id
    left join public.profiles p on p.id = i.user_id
   order by i.at;
end;
$$;

revoke execute on function public.get_review_queue() from public, anon;
grant execute on function public.get_review_queue() to authenticated;

-- ============================================================
-- 3. Admin wrappers around the existing review functions
-- ============================================================

create function public.admin_approve_venue_claim(p_venue_type text, p_claim_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  perform public.approve_venue_claim(p_venue_type, p_claim_id, auth.uid());
end;
$$;

create function public.admin_reject_venue_claim(p_venue_type text, p_claim_id uuid, p_review_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  perform public.reject_venue_claim(p_venue_type, p_claim_id, auth.uid(), p_review_note);
end;
$$;

create function public.admin_approve_venue_about(p_submission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  perform public.approve_venue_about(p_submission_id, auth.uid());
end;
$$;

create function public.admin_reject_venue_about(p_submission_id uuid, p_review_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  perform public.reject_venue_about(p_submission_id, auth.uid(), p_review_note);
end;
$$;

create function public.admin_reject_venue_photo(p_submission_id uuid, p_review_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  perform public.reject_venue_photo(p_submission_id, auth.uid(), p_review_note);
end;
$$;

revoke execute on function public.admin_approve_venue_claim(text, uuid) from public, anon;
revoke execute on function public.admin_reject_venue_claim(text, uuid, text) from public, anon;
revoke execute on function public.admin_approve_venue_about(uuid) from public, anon;
revoke execute on function public.admin_reject_venue_about(uuid, text) from public, anon;
revoke execute on function public.admin_reject_venue_photo(uuid, text) from public, anon;
grant execute on function public.admin_approve_venue_claim(text, uuid) to authenticated;
grant execute on function public.admin_reject_venue_claim(text, uuid, text) to authenticated;
grant execute on function public.admin_approve_venue_about(uuid) to authenticated;
grant execute on function public.admin_reject_venue_about(uuid, text) to authenticated;
grant execute on function public.admin_reject_venue_photo(uuid, text) to authenticated;

-- ============================================================
-- 4. Admins may view pending photos (signed URLs) for the preview
-- ============================================================

create policy venue_photo_submissions_storage_admin_read on storage.objects
  for select to authenticated
  using (bucket_id = 'venue-photo-submissions' and public.is_admin());

commit;
