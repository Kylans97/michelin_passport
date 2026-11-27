-- Visit companions: tag the friends you dined with.
--
-- Written 2026-11-27. Product owner, 2026-11-27: "kunnen we ook als je
-- ergens gegeten hebt vrienden hier toevoegen? Dat je dan ook in de feed
-- van vrienden ziet wanneer er vrienden van je samen gegeten hebben", and
-- "stel ik ga eten met Pieter en Pieter is niet bevriend met mijn andere
-- vrienden dat mijn andere vrienden wel kunnen zien dat ik met Pieter ben
-- gaan eten". Design approved the same day ("bovenstaande is top en mag
-- je bouwen"):
--
--   * The owner of a visit tags friends on it (accepted friends only, not
--     on a visit that is itself a shared copy).
--   * A tag starts pending. The tagged member answers: accept and add the
--     visit to their own Passport (a copy, linked by
--     visits.shared_from_visit_id exactly like an invite link's copy, so
--     the date follows the original), accept without a copy, or decline.
--   * Only an accepted tag is shown to anyone else. Whoever may read the
--     visit sees its accepted companions, including members who are not
--     friends with the companion: the companion consented by accepting.
--   * Either side can remove a tag at any time. Ending the friendship
--     drops tags that are still pending; accepted ones stay as history.
--
-- Nothing a shipped build reads changes shape. The two new notification
-- types are filtered out of every reader installed builds call (v7 and
-- older), the same steps as 20261101670000.
--
-- The filename is a sequence number placed after the highest migration
-- on main when written (20261101810000), with room left for the wine
-- estate migrations being renumbered the same day. Re-check the order
-- against the ledger before applying.

begin;

-- ============================================================
-- 1. The table
-- ============================================================

create table public.visit_companions (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits (id) on delete cascade,
  -- The friend who was there.
  user_id uuid not null references auth.users (id) on delete cascade,
  -- The owner of the visit at the time of tagging (always visits.user_id).
  tagged_by uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  -- The companion's own copy, when they added it to their Passport.
  copy_visit_id uuid references public.visits (id) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint visit_companions_not_self check (user_id <> tagged_by),
  constraint visit_companions_unique unique (visit_id, user_id)
);

create index visit_companions_user_idx on public.visit_companions (user_id, status);
create index visit_companions_tagged_by_idx on public.visit_companions (tagged_by);

alter table public.visit_companions enable row level security;

-- Both people on a tag can see it. Everyone else reads accepted tags
-- only through get_visit_companions, which applies the visit's own
-- visibility.
create policy visit_companions_select on public.visit_companions
  for select to authenticated
  using (user_id = auth.uid() or tagged_by = auth.uid());

revoke all on public.visit_companions from anon, authenticated;
grant select on public.visit_companions to authenticated;

-- ============================================================
-- 2. Notifications: types and subject
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
      -- to the friend: you were tagged on a visit
      'visit_tag_received',
      -- to the owner of the visit: the friend said yes
      'visit_tag_accepted'
    ));

alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim',
      'venue_about_submission', 'venue_photo_submission', 'event',
      'planned_trip_member', 'profile', 'booking_reminder',
      'invite_link_redemption', 'visit_companion'
    ));

-- 20261101670000's function, unchanged apart from the type list.
create or replace function public.notify_push_for_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_secret text;
  v_ids uuid[];
  v_chunk uuid[];
  v_offset int := 0;
begin
  select array_agg(id) into v_ids
    from new_rows
   where type in ('friend_request_received', 'followed_venue_event', 'birthday',
                  'booking_window_opening', 'invite_link_accepted',
                  'invite_link_join_request', 'visit_tag_received');
  if v_ids is null then
    return null;
  end if;

  begin
    select decrypted_secret into v_secret
      from vault.decrypted_secrets
     where name = 'send_push_webhook_secret';

    if v_secret is null then
      raise warning 'notify_push_for_notifications: webhook secret not found in vault — '
        'skipping push for % notification(s)', cardinality(v_ids);
      return null;
    end if;

    while v_offset < cardinality(v_ids) loop
      v_chunk := v_ids[v_offset + 1 : v_offset + 500];
      perform net.http_post(
        url := 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/send-push',
        body := jsonb_build_object('notification_ids', to_jsonb(v_chunk)),
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-webhook-secret', v_secret
        ),
        timeout_milliseconds := 10000
      );
      v_offset := v_offset + 500;
    end loop;
  exception when others then
    -- Best-effort: never take the notification insert down with it.
    raise warning 'notify_push_for_notifications: failed to queue push — %', sqlerrm;
  end;
  return null;
end;
$$;

-- ============================================================
-- 3. Tagging, answering, removing
-- ============================================================

-- The owner sets the full list of friends on a visit. New names get a
-- pending tag and a notification; names left out are removed (their own
-- copy, if any, stays theirs). Returns the visit's tags afterwards.
create function public.set_visit_companions(p_visit_id uuid, p_user_ids uuid[])
returns setof public.visit_companions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_visit public.visits;
  v_ids uuid[] := coalesce(
    (select array_agg(distinct x) from unnest(coalesce(p_user_ids, '{}')) x where x is not null),
    '{}');
  v_new uuid;
  v_tag_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  select * into v_visit from public.visits v where v.id = p_visit_id for update;
  if v_visit.id is null or v_visit.user_id <> v_uid then
    raise exception 'You can only add friends to your own visits.' using errcode = '42501';
  end if;
  if v_visit.shared_from_visit_id is not null then
    raise exception 'Friends are added on the original visit.' using errcode = '22023';
  end if;
  if cardinality(v_ids) > 12 then
    raise exception 'You can add up to 12 friends to a visit.' using errcode = '22023';
  end if;
  if v_uid = any (v_ids) then
    raise exception 'You are already on your own visit.' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(v_ids) x where not public.is_friend(x)) then
    raise exception 'You can only add your friends.' using errcode = '42501';
  end if;

  delete from public.visit_companions c
   where c.visit_id = p_visit_id
     and not (c.user_id = any (v_ids));

  foreach v_new in array v_ids loop
    if not exists (
      select 1 from public.visit_companions c
       where c.visit_id = p_visit_id and c.user_id = v_new
    ) then
      insert into public.visit_companions (visit_id, user_id, tagged_by)
      values (p_visit_id, v_new, v_uid)
      returning id into v_tag_id;

      insert into public.notifications (recipient_id, type, subject_type, subject_id)
      values (v_new, 'visit_tag_received', 'visit_companion', v_tag_id);
    end if;
  end loop;

  return query
    select * from public.visit_companions c
     where c.visit_id = p_visit_id
     order by c.created_at;
end;
$$;

revoke execute on function public.set_visit_companions(uuid, uuid[]) from public, anon;
grant execute on function public.set_visit_companions(uuid, uuid[]) to authenticated;

-- The tagged friend answers. Accepting with p_add_to_passport makes their
-- own copy of the visit (place, date and the award at the time, as an
-- invite link's copy does); a visit they already have at that place on
-- that date is used instead of a second one.
create function public.respond_to_visit_tag(
  p_tag_id uuid,
  p_accept boolean,
  p_add_to_passport boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tag public.visit_companions;
  v_source public.visits;
  v_copy_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  select * into v_tag from public.visit_companions c where c.id = p_tag_id for update;
  if v_tag.id is null or v_tag.user_id <> v_uid then
    raise exception 'This tag is no longer available.' using errcode = 'P0002';
  end if;

  if not p_accept then
    update public.visit_companions
       set status = 'declined', responded_at = now(), copy_visit_id = null
     where id = v_tag.id;
    return jsonb_build_object('status', 'declined', 'copy_visit_id', null);
  end if;

  select * into v_source from public.visits v where v.id = v_tag.visit_id;

  if p_add_to_passport then
    select v.id into v_copy_id
      from public.visits v
     where v.user_id = v_uid
       and v.entity_type = v_source.entity_type
       and v.entity_id = v_source.entity_id
       and v.visited_on = v_source.visited_on
     limit 1;
    if v_copy_id is null then
      insert into public.visits (
        user_id, entity_type, entity_id, visited_on,
        stars_at_visit, keys_at_visit, shared_from_visit_id
      )
      values (
        v_uid, v_source.entity_type, v_source.entity_id, v_source.visited_on,
        v_source.stars_at_visit, v_source.keys_at_visit, v_source.id
      )
      returning id into v_copy_id;
    end if;
  end if;

  update public.visit_companions
     set status = 'accepted', responded_at = now(),
         copy_visit_id = coalesce(v_copy_id, copy_visit_id)
   where id = v_tag.id;

  -- Tell the owner once, the first time this tag is accepted.
  if v_tag.status <> 'accepted' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (v_tag.tagged_by, 'visit_tag_accepted', 'visit_companion', v_tag.id);
  end if;

  return jsonb_build_object('status', 'accepted', 'copy_visit_id', v_copy_id);
end;
$$;

revoke execute on function public.respond_to_visit_tag(uuid, boolean, boolean) from public, anon;
grant execute on function public.respond_to_visit_tag(uuid, boolean, boolean) to authenticated;

-- Either person removes a tag. The companion's own copy stays theirs.
create function public.remove_visit_tag(p_tag_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  delete from public.visit_companions c
   where c.id = p_tag_id
     and (c.user_id = v_uid or c.tagged_by = v_uid);
end;
$$;

revoke execute on function public.remove_visit_tag(uuid) from public, anon;
grant execute on function public.remove_visit_tag(uuid) to authenticated;

-- ============================================================
-- 4. Reading companions
-- ============================================================

-- For each visit the caller may read, its companions: accepted ones for
-- everyone who can see the visit; pending and declined ones only for the
-- owner (and each companion sees their own tag). A visit can be read by
-- its owner, by the owner's friends when it is set to friends, and by an
-- accepted companion.
create function public.get_visit_companions(p_visit_ids uuid[])
returns table (
  visit_id uuid,
  tag_id uuid,
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  status text,
  copy_visit_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select c.visit_id, c.id, c.user_id, p.username, p.display_name, p.avatar_url,
         c.status, c.copy_visit_id
    from public.visit_companions c
    join public.visits v on v.id = c.visit_id
    join public.profiles p on p.id = c.user_id
   where c.visit_id = any (coalesce(p_visit_ids, '{}'))
     and auth.uid() is not null
     and (
       -- the owner sees every tag on their visit
       v.user_id = auth.uid()
       -- a companion sees their own tag
       or c.user_id = auth.uid()
       -- everyone who may read the visit sees accepted companions
       or (c.status = 'accepted' and (
             (v.visibility = 'friends' and public.is_friend(v.user_id))
             or exists (
               select 1 from public.visit_companions me
                where me.visit_id = v.id and me.user_id = auth.uid()
                  and me.status = 'accepted')
           ))
     )
     -- nobody is shown to someone they blocked or who blocked them
     and not exists (
       select 1 from public.friendships b
        where b.status = 'blocked'
          and least(b.requester_id, b.addressee_id) = least(c.user_id, auth.uid())
          and greatest(b.requester_id, b.addressee_id) = greatest(c.user_id, auth.uid())
     )
   order by c.visit_id, c.created_at;
$$;

revoke execute on function public.get_visit_companions(uuid[]) from public, anon;
grant execute on function public.get_visit_companions(uuid[]) to authenticated;

-- ============================================================
-- 5. Ending a friendship drops pending tags
-- ============================================================

create function public.drop_pending_visit_tags_on_unfriend()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_a uuid := coalesce(old.requester_id, new.requester_id);
  v_b uuid := coalesce(old.addressee_id, new.addressee_id);
begin
  if tg_op = 'DELETE' or (old.status = 'accepted' and new.status <> 'accepted') then
    delete from public.visit_companions c
     where c.status = 'pending'
       and ((c.tagged_by = v_a and c.user_id = v_b)
         or (c.tagged_by = v_b and c.user_id = v_a));
  end if;
  return null;
end;
$$;

revoke execute on function public.drop_pending_visit_tags_on_unfriend() from public, anon, authenticated;

create trigger drop_pending_visit_tags_on_unfriend
  after update of status or delete on public.friendships
  for each row execute function public.drop_pending_visit_tags_on_unfriend();

-- ============================================================
-- 6. Readers: v8 for the next build; v7 and older without the new types
-- ============================================================
-- Same steps as 20261101670000: v7's body becomes
-- get_notifications_v8_base, untouched; v8 adds the tag's columns; a new
-- v7 (what 1.10.0 calls) is the base without the new types; v6 and v5
-- gain the same filter. The unread counts follow.

alter function public.get_notifications_v7() rename to get_notifications_v8_base;
revoke execute on function public.get_notifications_v8_base() from public, anon, authenticated;

create function public.get_notifications_v8()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text, link_kind text, link_venue_name text, link_visited_on date, link_trip_id uuid, link_trip_title text, link_redemption_status text, link_became_friends boolean, link_visit_id uuid, tag_status text, tag_visit_id uuid, tag_entity_type text, tag_entity_id uuid, tag_venue_name text, tag_visited_on date, tag_copy_visit_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    n.id, n.type, n.subject_type, n.subject_id, n.is_read, n.created_at,
    coalesce(n.other_user_id, tp.id),
    coalesce(n.other_username, tp.username),
    coalesce(n.other_display_name, tp.display_name),
    coalesce(n.other_avatar_url, tp.avatar_url),
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
    c.status,
    c.visit_id,
    v.entity_type,
    v.entity_id,
    coalesce(r.name, h.name),
    v.visited_on,
    c.copy_visit_id
  from public.get_notifications_v8_base() n
  left join public.visit_companions c
    on n.subject_type = 'visit_companion' and c.id = n.subject_id
  left join public.visits v on v.id = c.visit_id
  left join public.restaurants r on v.entity_type = 'restaurant' and r.id = v.entity_id
  left join public.hotels h on v.entity_type = 'hotel' and h.id = v.entity_id
  -- The other person: the owner when the companion reads it, the
  -- companion when the owner reads it.
  left join public.profiles tp
    on c.id is not null
   and tp.id = case when c.user_id = auth.uid() then c.tagged_by else c.user_id end;
$function$;

revoke execute on function public.get_notifications_v8() from public, anon;
grant execute on function public.get_notifications_v8() to authenticated;

create function public.get_notifications_v7()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text, link_kind text, link_venue_name text, link_visited_on date, link_trip_id uuid, link_trip_title text, link_redemption_status text, link_became_friends boolean, link_visit_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v8_base()
   where type not in ('visit_tag_received', 'visit_tag_accepted');
$function$;

revoke execute on function public.get_notifications_v7() from public, anon;
grant execute on function public.get_notifications_v7() to authenticated;

-- Same signatures as before, so create or replace keeps older readers
-- going through them.
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
                      'visit_tag_received', 'visit_tag_accepted');
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
                      'visit_tag_received', 'visit_tag_accepted');
$function$;

alter function public.get_unread_notification_count_v7() rename to get_unread_notification_count_v8;

create function public.get_unread_notification_count_v7()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in ('visit_tag_received', 'visit_tag_accepted');
$$;

revoke execute on function public.get_unread_notification_count_v7() from public, anon;
grant execute on function public.get_unread_notification_count_v7() to authenticated;

create or replace function public.get_unread_notification_count_v6()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in ('invite_link_accepted', 'invite_link_join_request',
                     'invite_link_join_approved', 'invite_link_join_declined',
                     'visit_tag_received', 'visit_tag_accepted');
$$;

create or replace function public.get_unread_notification_count_v5()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in ('booking_window_opening',
                     'invite_link_accepted', 'invite_link_join_request',
                     'invite_link_join_approved', 'invite_link_join_declined',
                     'visit_tag_received', 'visit_tag_accepted');
$$;

create or replace function public.get_unread_notification_count_v4()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in ('birthday', 'booking_window_opening',
                     'invite_link_accepted', 'invite_link_join_request',
                     'invite_link_join_approved', 'invite_link_join_declined',
                     'visit_tag_received', 'visit_tag_accepted');
$$;

create or replace function public.get_unread_notification_count_v3()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in ('followed_venue_event', 'birthday', 'booking_window_opening',
                     'invite_link_accepted', 'invite_link_join_request',
                     'invite_link_join_approved', 'invite_link_join_declined',
                     'visit_tag_received', 'visit_tag_accepted');
$$;

create or replace function public.get_unread_notification_count_v2()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in (
      'trip_invite_received', 'trip_invite_accepted',
      'followed_venue_event', 'birthday', 'booking_window_opening',
      'invite_link_accepted', 'invite_link_join_request',
      'invite_link_join_approved', 'invite_link_join_declined',
      'visit_tag_received', 'visit_tag_accepted'
    );
$$;

create or replace function public.get_unread_notification_count()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in (
      'event_approved', 'event_rejected',
      'trip_invite_received', 'trip_invite_accepted',
      'followed_venue_event', 'birthday', 'booking_window_opening',
      'invite_link_accepted', 'invite_link_join_request',
      'invite_link_join_approved', 'invite_link_join_declined',
      'visit_tag_received', 'visit_tag_accepted'
    );
$$;

commit;
