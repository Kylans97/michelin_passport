-- Chapeau: applause on a friend's visit, stay or event stamp.
--
-- Written 2026-11-27. Product owner, 2026-11-27: "ook kunnen applaudiceren
-- op bezoeken aan hotels, restaurants, events en andere venues van je
-- vrienden", then "doe maar Chapeau". As proposed: one Chapeau per person
-- per item, only from someone who may see the item, never on your own;
-- the owner hears it in Notifications, bundled per item, without a push.
--
-- Builds on 20261101850000 (visit companions): the notification readers
-- move on to v9 the same way, and v8 and older filter the new type out.

begin;

-- ============================================================
-- 1. The table
-- ============================================================

create table public.chapeaus (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  -- 'visit' (a restaurant visit or a hotel stay) or 'event_stamp'
  -- (event_confirmed_attendance).
  subject_type text not null check (subject_type in ('visit', 'event_stamp')),
  subject_id uuid not null,
  created_at timestamptz not null default now(),
  constraint chapeaus_once unique (user_id, subject_type, subject_id)
);

create index chapeaus_subject_idx on public.chapeaus (subject_type, subject_id, created_at desc);

alter table public.chapeaus enable row level security;

-- A member sees their own Chapeaus directly; counts and names on an item
-- come through get_chapeaus, which checks the item is visible.
create policy chapeaus_select on public.chapeaus
  for select to authenticated
  using (user_id = auth.uid());

revoke all on public.chapeaus from anon, authenticated;
grant select on public.chapeaus to authenticated;

-- An item's owner, when the caller may see it (own items included), else
-- null. Friends-visible visits and stamps of an accepted friend, and the
-- caller's own.
create function public.chapeau_subject_owner(p_subject_type text, p_subject_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select owner from (
    select v.user_id as owner, v.visibility
      from public.visits v
     where p_subject_type = 'visit' and v.id = p_subject_id
    union all
    select e.user_id, e.visibility
      from public.event_confirmed_attendance e
     where p_subject_type = 'event_stamp' and e.id = p_subject_id
  ) s
  where auth.uid() is not null
    and (s.owner = auth.uid()
         or (s.visibility = 'friends' and public.is_friend(s.owner)))
  limit 1;
$$;

revoke execute on function public.chapeau_subject_owner(text, uuid) from public, anon, authenticated;

-- ============================================================
-- 2. Notifications: type and subjects
-- ============================================================

alter table public.notifications
  drop constraint notifications_type_check,
  add constraint notifications_type_check
    check (type in (
      'friend_request_received',
      'friend_request_accepted',
      'missing_listing_added',
      'venue_invite_received',
      'venue_invite_accepted',
      'venue_invite_declined',
      'venue_claim_received',
      'venue_claim_approved',
      'venue_claim_rejected',
      'venue_about_approved',
      'venue_about_rejected',
      'venue_photo_approved',
      'venue_photo_rejected',
      'event_approved',
      'event_rejected',
      'trip_invite_received',
      'trip_invite_accepted',
      'followed_venue_event',
      'birthday',
      'booking_window_opening',
      'invite_link_accepted',
      'invite_link_join_request',
      'invite_link_join_approved',
      'invite_link_join_declined',
      'visit_tag_received',
      'visit_tag_accepted',
      -- to the owner: friends gave a Chapeau (one row per item while unread)
      'chapeau_received'
    ));

alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim',
      'venue_about_submission', 'venue_photo_submission', 'event',
      'planned_trip_member', 'profile', 'booking_reminder',
      'invite_link_redemption', 'visit_companion',
      'visit', 'event_stamp'
    ));

-- ============================================================
-- 3. Giving and taking back
-- ============================================================

create function public.give_chapeau(p_subject_type text, p_subject_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  if p_subject_type not in ('visit', 'event_stamp') then
    raise exception 'Unknown item' using errcode = '22023';
  end if;
  v_owner := public.chapeau_subject_owner(p_subject_type, p_subject_id);
  if v_owner is null then
    raise exception 'This is no longer available.' using errcode = 'P0002';
  end if;
  if v_owner = v_uid then
    raise exception 'Chapeau is for your friends.' using errcode = '22023';
  end if;

  insert into public.chapeaus (user_id, subject_type, subject_id)
  values (v_uid, p_subject_type, p_subject_id)
  on conflict (user_id, subject_type, subject_id) do nothing;
  if not found then
    return;
  end if;

  -- One unread row per item: a new Chapeau moves it to the top.
  update public.notifications
     set created_at = now()
   where recipient_id = v_owner
     and type = 'chapeau_received'
     and subject_type = p_subject_type
     and subject_id = p_subject_id
     and is_read = false;
  if not found then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (v_owner, 'chapeau_received', p_subject_type, p_subject_id);
  end if;
end;
$$;

revoke execute on function public.give_chapeau(text, uuid) from public, anon;
grant execute on function public.give_chapeau(text, uuid) to authenticated;

create function public.take_back_chapeau(p_subject_type text, p_subject_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.chapeaus
   where user_id = auth.uid()
     and subject_type = p_subject_type
     and subject_id = p_subject_id;
  -- The last one taken back: the owner's row goes too, so the badge
  -- never counts a notification that says nothing.
  if not exists (
    select 1 from public.chapeaus c
     where c.subject_type = p_subject_type and c.subject_id = p_subject_id
  ) then
    delete from public.notifications
     where type = 'chapeau_received'
       and subject_type = p_subject_type
       and subject_id = p_subject_id;
  end if;
end;
$$;

revoke execute on function public.take_back_chapeau(text, uuid) from public, anon;
grant execute on function public.take_back_chapeau(text, uuid) to authenticated;

-- ============================================================
-- 4. Reading
-- ============================================================

-- For each item the caller may see: how many Chapeaus, whether the caller
-- gave one, and up to three names, newest first.
create function public.get_chapeaus(p_subject_type text, p_subject_ids uuid[])
returns table (
  subject_id uuid,
  chapeau_count integer,
  given_by_me boolean,
  recent_names text[]
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id,
         count(c.id)::integer,
         coalesce(bool_or(c.user_id = auth.uid()), false),
         coalesce(
           (array_agg(coalesce(nullif(trim(p.display_name), ''), '@' || p.username)
                      order by c.created_at desc)
              filter (where c.id is not null))[1:3],
           '{}')
    from unnest(coalesce(p_subject_ids, '{}')) as s(id)
    left join public.chapeaus c
      on c.subject_type = p_subject_type and c.subject_id = s.id
    left join public.profiles p on p.id = c.user_id
   where public.chapeau_subject_owner(p_subject_type, s.id) is not null
   group by s.id;
$$;

revoke execute on function public.get_chapeaus(text, uuid[]) from public, anon;
grant execute on function public.get_chapeaus(text, uuid[]) to authenticated;

-- ============================================================
-- 5. Readers: v9; v8 and older without the new type
-- ============================================================

alter function public.get_notifications_v8() rename to get_notifications_v9_base;
revoke execute on function public.get_notifications_v9_base() from public, anon, authenticated;

create function public.get_notifications_v9()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text, link_kind text, link_venue_name text, link_visited_on date, link_trip_id uuid, link_trip_title text, link_redemption_status text, link_became_friends boolean, link_visit_id uuid, tag_status text, tag_visit_id uuid, tag_entity_type text, tag_entity_id uuid, tag_venue_name text, tag_visited_on date, tag_copy_visit_id uuid, chapeau_count integer, chapeau_subject_name text, chapeau_entity_type text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    n.id, n.type, n.subject_type, n.subject_id, n.is_read, n.created_at,
    coalesce(n.other_user_id, cp.id),
    coalesce(n.other_username, cp.username),
    coalesce(n.other_display_name, cp.display_name),
    coalesce(n.other_avatar_url, cp.avatar_url),
    n.listing_subject_type, n.listing_name, n.listing_city,
    n.invite_venue_type, n.invite_venue_id, n.invite_venue_name, n.invite_venue_city,
    n.invite_note, n.invite_status, n.invite_expires_at,
    n.claim_venue_type, n.claim_venue_id, n.claim_venue_name, n.claim_venue_city,
    n.claim_review_note,
    n.submission_venue_type, n.submission_venue_id, n.submission_venue_name,
    n.submission_venue_city, n.submission_review_note,
    n.friendship_status,
    n.event_name, n.event_start_date, n.event_review_note, n.event_venue_type,
    n.event_venue_id, n.event_venue_name,
    n.trip_id, n.trip_title, n.trip_start_date, n.trip_end_date, n.trip_member_status,
    n.booking_restaurant_id, n.booking_restaurant_name, n.booking_planned_month,
    n.booking_opens_on, n.booking_opens_time, n.booking_timezone,
    n.link_kind, n.link_venue_name, n.link_visited_on, n.link_trip_id,
    n.link_trip_title, n.link_redemption_status, n.link_became_friends, n.link_visit_id,
    n.tag_status, n.tag_visit_id, n.tag_entity_type, n.tag_entity_id,
    n.tag_venue_name, n.tag_visited_on, n.tag_copy_visit_id,
    ch.cnt,
    coalesce(r.name, h.name, ev.name),
    v.entity_type
  from public.get_notifications_v9_base() n
  left join lateral (
    select count(*)::integer as cnt,
           (array_agg(c.user_id order by c.created_at desc))[1] as latest
      from public.chapeaus c
     where n.type = 'chapeau_received'
       and c.subject_type = n.subject_type and c.subject_id = n.subject_id
  ) ch on n.type = 'chapeau_received'
  left join public.profiles cp on cp.id = ch.latest
  left join public.visits v on n.subject_type = 'visit' and v.id = n.subject_id
  left join public.restaurants r on v.entity_type = 'restaurant' and r.id = v.entity_id
  left join public.hotels h on v.entity_type = 'hotel' and h.id = v.entity_id
  left join public.event_confirmed_attendance eca
    on n.subject_type = 'event_stamp' and eca.id = n.subject_id
  left join public.events ev on ev.id = eca.event_id
  -- A Chapeau row whose every Chapeau was taken back says nothing.
  where n.type <> 'chapeau_received' or coalesce(ch.cnt, 0) > 0;
$function$;

revoke execute on function public.get_notifications_v9() from public, anon;
grant execute on function public.get_notifications_v9() to authenticated;

create function public.get_notifications_v8()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text, link_kind text, link_venue_name text, link_visited_on date, link_trip_id uuid, link_trip_title text, link_redemption_status text, link_became_friends boolean, link_visit_id uuid, tag_status text, tag_visit_id uuid, tag_entity_type text, tag_entity_id uuid, tag_venue_name text, tag_visited_on date, tag_copy_visit_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v9_base()
   where type <> 'chapeau_received';
$function$;

revoke execute on function public.get_notifications_v8() from public, anon;
grant execute on function public.get_notifications_v8() to authenticated;

-- v7 reads v8_base, v6 v7_base, v5 v6_rows: each already selects every
-- type, so each gains the filter.
create or replace function public.get_notifications_v7()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text, link_kind text, link_venue_name text, link_visited_on date, link_trip_id uuid, link_trip_title text, link_redemption_status text, link_became_friends boolean, link_visit_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v8_base()
   where type not in ('visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$function$;

create or replace function public.get_notifications_v6()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v7_base()
   where type not in ('invite_link_accepted', 'invite_link_join_request',
                      'invite_link_join_approved', 'invite_link_join_declined',
                      'visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$function$;

create or replace function public.get_notifications_v5()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v6_rows()
   where type not in ('booking_window_opening',
                      'invite_link_accepted', 'invite_link_join_request',
                      'invite_link_join_approved', 'invite_link_join_declined',
                      'visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$function$;

alter function public.get_unread_notification_count_v8() rename to get_unread_notification_count_v9;

create function public.get_unread_notification_count_v8()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type <> 'chapeau_received';
$$;

revoke execute on function public.get_unread_notification_count_v8() from public, anon;
grant execute on function public.get_unread_notification_count_v8() to authenticated;

create or replace function public.get_unread_notification_count_v7()
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.notifications
   where recipient_id = auth.uid() and is_read = false
     and type not in ('visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$$;

create or replace function public.get_unread_notification_count_v6()
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.notifications
   where recipient_id = auth.uid() and is_read = false
     and type not in ('invite_link_accepted', 'invite_link_join_request',
                      'invite_link_join_approved', 'invite_link_join_declined',
                      'visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$$;

create or replace function public.get_unread_notification_count_v5()
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.notifications
   where recipient_id = auth.uid() and is_read = false
     and type not in ('booking_window_opening',
                      'invite_link_accepted', 'invite_link_join_request',
                      'invite_link_join_approved', 'invite_link_join_declined',
                      'visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$$;

create or replace function public.get_unread_notification_count_v4()
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.notifications
   where recipient_id = auth.uid() and is_read = false
     and type not in ('birthday', 'booking_window_opening',
                      'invite_link_accepted', 'invite_link_join_request',
                      'invite_link_join_approved', 'invite_link_join_declined',
                      'visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$$;

create or replace function public.get_unread_notification_count_v3()
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.notifications
   where recipient_id = auth.uid() and is_read = false
     and type not in ('followed_venue_event', 'birthday', 'booking_window_opening',
                      'invite_link_accepted', 'invite_link_join_request',
                      'invite_link_join_approved', 'invite_link_join_declined',
                      'visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$$;

create or replace function public.get_unread_notification_count_v2()
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.notifications
   where recipient_id = auth.uid() and is_read = false
     and type not in (
       'trip_invite_received', 'trip_invite_accepted',
       'followed_venue_event', 'birthday', 'booking_window_opening',
       'invite_link_accepted', 'invite_link_join_request',
       'invite_link_join_approved', 'invite_link_join_declined',
       'visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$$;

create or replace function public.get_unread_notification_count()
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.notifications
   where recipient_id = auth.uid() and is_read = false
     and type not in (
       'event_approved', 'event_rejected',
       'trip_invite_received', 'trip_invite_accepted',
       'followed_venue_event', 'birthday', 'booking_window_opening',
       'invite_link_accepted', 'invite_link_join_request',
       'invite_link_join_approved', 'invite_link_join_declined',
       'visit_tag_received', 'visit_tag_accepted', 'chapeau_received');
$$;

commit;
