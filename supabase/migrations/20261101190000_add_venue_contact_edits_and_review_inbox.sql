-- A venue keeps its own website and phone number, and everything an
-- admin needs to look at lands in the in-app review queue.
--
-- Decided by the product owner on 2026-11-02:
--   1. A venue manager changes or adds the venue's website and phone
--      number (a private chef: the website) without review — they change
--      during the year, and keeping them current by hand would be a lot
--      of work. Each change goes live at once and puts an item in the
--      review queue, so an admin can glance at it now and then.
--   2. Everything that needs an admin is in the app's review queue, not
--      only in an email or the dashboard. Two things weren't:
--        - content reports (a photo, rating, profile or event reported
--          by a member) reached admins only by email
--          (notify-content-report) and the dashboard;
--        - missing-listing reports (a venue or event a member couldn't
--          find in Explore) reached them only through the dashboard.
--      Both now appear in the queue, each with a way to mark it dealt
--      with. The emails stay as a heads-up.
--
-- Website and phone are not part of the verified data that originates
-- with us (CLAUDE.md lists MICHELIN stars, Keys, World's 50 Best,
-- Gault&Millau and the verified location fields). They were filled in by
-- our enrichment passes as a starting value; a venue's own value is the
-- source taking over, not a correction to defer to. The previous value
-- is kept on the edit row, so nothing we had is lost.
--
-- Every new SECURITY DEFINER function carries its own
-- `revoke execute ... from public, anon` in this file (CLAUDE.md).
--
-- Real date: 2026-11-02. The filename is a sequence number, the next one
-- after the highest existing migration (20261101180000), per CLAUDE.md.

begin;

-- ============================================================
-- 1. Website and phone, kept by the venue
-- ============================================================

-- One row per changed field. No client access at all: written by
-- set_venue_contact, read through get_review_queue.
create table public.venue_contact_edits (
  id          uuid primary key default gen_random_uuid(),
  venue_type  text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id    uuid not null,
  field       text not null check (field in ('website', 'phone')),
  old_value   text,
  new_value   text,
  edited_by   uuid references public.profiles(id) on delete set null,
  edited_at   timestamptz not null default now(),
  seen_at     timestamptz,
  seen_by     uuid references public.profiles(id) on delete set null
);

create index venue_contact_edits_unseen_idx
  on public.venue_contact_edits (edited_at) where seen_at is null;

alter table public.venue_contact_edits enable row level security;
revoke all on table public.venue_contact_edits from public, anon, authenticated;

-- Sets both values for the venue; null or blank clears one. Only what
-- actually changed is written and logged. A private chef has no phone
-- column, so a phone for one is refused rather than dropped silently.
create function public.set_venue_contact(
  p_venue_type text,
  p_venue_id uuid,
  p_website text,
  p_phone text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_website text := nullif(btrim(p_website), '');
  v_phone text := nullif(btrim(p_phone), '');
  v_old_website text;
  v_old_phone text;
begin
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef') then
    raise exception 'Unknown venue type %', p_venue_type;
  end if;
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Not a manager of this venue';
  end if;

  if v_website is not null and (
       char_length(v_website) > 500
       or v_website !~* '^https?://[^\s/?#]+\.[^\s/?#]{2,}([/?#]\S*)?$'
     ) then
    raise exception 'The website must be a full address, like https://www.yourvenue.com';
  end if;
  if v_phone is not null and (
       char_length(v_phone) > 30
       or v_phone !~ '^\+?[0-9 ()./-]+$'
       or char_length(regexp_replace(v_phone, '[^0-9]', '', 'g')) < 6
     ) then
    raise exception 'The phone number may hold digits, spaces and + ( ) . / - only, with at least six digits';
  end if;
  if p_venue_type = 'private_chef' and v_phone is not null then
    raise exception 'A private chef page has no phone number';
  end if;

  if p_venue_type = 'restaurant' then
    select website_url, phone into v_old_website, v_old_phone
      from public.restaurants where id = p_venue_id for update;
    update public.restaurants
       set website_url = v_website, phone = v_phone
     where id = p_venue_id
       and (website_url is distinct from v_website or phone is distinct from v_phone);
  elsif p_venue_type = 'hotel' then
    select website_url, phone into v_old_website, v_old_phone
      from public.hotels where id = p_venue_id for update;
    update public.hotels
       set website_url = v_website, phone = v_phone
     where id = p_venue_id
       and (website_url is distinct from v_website or phone is distinct from v_phone);
  else
    select website_url into v_old_website
      from public.private_chefs where id = p_venue_id for update;
    update public.private_chefs
       set website_url = v_website
     where id = p_venue_id and website_url is distinct from v_website;
  end if;

  if v_old_website is distinct from v_website then
    insert into public.venue_contact_edits (venue_type, venue_id, field, old_value, new_value, edited_by)
    values (p_venue_type, p_venue_id, 'website', v_old_website, v_website, auth.uid());
  end if;
  if p_venue_type <> 'private_chef' and v_old_phone is distinct from v_phone then
    insert into public.venue_contact_edits (venue_type, venue_id, field, old_value, new_value, edited_by)
    values (p_venue_type, p_venue_id, 'phone', v_old_phone, v_phone, auth.uid());
  end if;
end;
$$;

revoke execute on function public.set_venue_contact(text, uuid, text, text) from public, anon;
grant execute on function public.set_venue_contact(text, uuid, text, text) to authenticated;

create function public.admin_mark_venue_contact_edit_seen(p_edit_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.venue_contact_edits
     set seen_at = now(), seen_by = auth.uid()
   where id = p_edit_id and seen_at is null;
  if not found then
    raise exception 'venue_contact_edits % is not waiting (or does not exist)', p_edit_id;
  end if;
end;
$$;

revoke execute on function public.admin_mark_venue_contact_edit_seen(uuid) from public, anon;
grant execute on function public.admin_mark_venue_contact_edit_seen(uuid) to authenticated;

-- ============================================================
-- 2. Content reports and missing listings, dealt with in the app
-- ============================================================

alter table public.content_reports
  add column resolved_at timestamptz,
  add column resolved_by uuid references public.profiles(id) on delete set null;

alter table public.missing_listing_reports
  add column handled_at timestamptz,
  add column handled_by uuid references public.profiles(id) on delete set null;

create function public.admin_resolve_content_report(p_report_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.content_reports
     set status = 'resolved', resolved_at = now(), resolved_by = auth.uid()
   where id = p_report_id and status = 'open';
  if not found then
    raise exception 'content_reports % is not open (or does not exist)', p_report_id;
  end if;
end;
$$;

create function public.admin_mark_missing_listing_handled(p_report_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.missing_listing_reports
     set handled_at = now(), handled_by = auth.uid()
   where id = p_report_id and handled_at is null;
  if not found then
    raise exception 'missing_listing_reports % is not waiting (or does not exist)', p_report_id;
  end if;
end;
$$;

revoke execute on function public.admin_resolve_content_report(uuid) from public, anon;
revoke execute on function public.admin_mark_missing_listing_handled(uuid) from public, anon;
grant execute on function public.admin_resolve_content_report(uuid) to authenticated;
grant execute on function public.admin_mark_missing_listing_handled(uuid) to authenticated;

-- ============================================================
-- 3. The review queue: contact edits, content reports, missing listings
-- ============================================================
-- 20261101170000's definition unchanged, plus three branches and their
-- columns appended. A missing listing has no venue yet, and a content
-- report about a profile has none either, so venue_type/venue_id are
-- null there. A missing listing already added to the catalogue (its
-- report id on a restaurant, hotel or event) no longer waits.

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
  instagram_handle text,
  contact_field text,
  contact_old_value text,
  contact_new_value text,
  report_content_type text,
  report_content_id uuid,
  report_reason text,
  report_details text,
  missing_subject_type text,
  missing_name text,
  missing_city text,
  missing_message text,
  missing_works_here boolean,
  missing_reporter_role text,
  missing_reporter_contact text
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
           null::text as t_photo, null::boolean as t_remove_photo, null::text as ig_handle,
           null::text as c_field, null::text as c_old, null::text as c_new,
           null::text as r_type, null::uuid as r_id, null::text as r_reason, null::text as r_details,
           null::text as m_type, null::text as m_name, null::text as m_city, null::text as m_message,
           null::boolean as m_works_here, null::text as m_role, null::text as m_contact
      from public.claims_restaurants c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'hotel', c.hotel_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.claims_hotels c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'private_chef', c.private_chef_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.claims_private_chefs c where c.status = 'pending'
    union all
    select 'venue_about', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           s.about_text, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_about_submissions s where s.status = 'pending'
    union all
    select 'venue_photo', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           null, s.storage_path, s.replaces_photo_id, s.duplicate_of_submission_id,
           s.focus_x, s.focus_y, s.zoom, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_photo_submissions s where s.status = 'pending'
    union all
    select 'venue_event', e.id, h.venue_type, h.venue_id, e.submitted_by,
           coalesce(e.submitted_at, e.created_at),
           null, null, null, null,
           null, null, null, null, null, null, null, e.id, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.events e
      left join lateral public.event_host_venue(e.id) h on true
     where e.moderation_status = 'submitted' and e.cancelled_at is null
    union all
    select 'venue_event_edit', x.id, h.venue_type, h.venue_id, x.edited_by, x.edited_at,
           null, null, null, null,
           null, null, null, null, null, null, null, x.event_id, x.changes,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.event_edits x
      left join lateral public.event_host_venue(x.event_id) h on true
     where x.seen_at is null
    union all
    select 'venue_team', t.id, t.venue_type, t.venue_id, t.user_id, t.submitted_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           t.role, t.name, t.bio, t.photo_path, t.remove_photo, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_team_submissions t
     where t.status = 'pending' and t.removed_at is null
    union all
    select 'venue_instagram', g.id, g.venue_type, g.venue_id, g.user_id, g.submitted_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, g.handle,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_instagram_submissions g
     where g.status = 'pending' and g.removed_at is null
    union all
    select 'venue_contact_edit', k.id, k.venue_type, k.venue_id, k.edited_by, k.edited_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           k.field, k.old_value, k.new_value, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_contact_edits k
     where k.seen_at is null
    union all
    -- The venue a reported event is hosted by, so the queue row names it.
    select 'content_report', cr.id,
           case when cr.content_type = 'event' then h.venue_type end,
           case when cr.content_type = 'event' then h.venue_id end,
           cr.reporter_id, cr.created_at,
           null, null, null, null,
           null, null, null, null, null, null, null,
           case when cr.content_type = 'event' then cr.content_id end, null,
           null, null, null, null, null, null,
           null, null, null, cr.content_type, cr.content_id, cr.reason, cr.details,
           null, null, null, null, null, null, null
      from public.content_reports cr
      left join lateral (
        select hv.venue_type, hv.venue_id from public.event_host_venue(cr.content_id) hv
         where cr.content_type = 'event'
      ) h on true
     where cr.status = 'open'
    union all
    select 'missing_listing', m.id, null, null, m.reporter_id, m.created_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           m.subject_type, m.name, m.city, m.message, m.works_here, m.reporter_role, m.reporter_contact
      from public.missing_listing_reports m
     where m.handled_at is null
       and not exists (select 1 from public.restaurants r where r.missing_listing_report_id = m.id)
       and not exists (select 1 from public.hotels ho where ho.missing_listing_report_id = m.id)
       and not exists (select 1 from public.events ev2 where ev2.missing_listing_report_id = m.id)
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
         i.t_role, i.t_name, i.t_bio, i.t_photo, i.t_remove_photo, i.ig_handle,
         i.c_field, i.c_old, i.c_new,
         i.r_type, i.r_id, i.r_reason, i.r_details,
         i.m_type, i.m_name, i.m_city, i.m_message, i.m_works_here, i.m_role, i.m_contact
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
