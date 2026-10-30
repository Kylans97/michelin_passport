-- Push notifications: device tokens, per-type preferences, a new in-app
-- type for followed venues' events, and the trigger that hands push-worthy
-- notifications to the send-push Edge Function.
--
-- Written 2026-10-30. Named after 20261030120000 (claude/launch-egress,
-- not yet merged), the highest migration on any branch at the time;
-- main tops out at 20261023190000 and claude/usage-tracking at
-- 20261023200000. Filename order is replay order only, see CLAUDE.md.
--
-- Push builds on public.notifications rather than beside it: every push is
-- the delivery of one in-app row, so the in-app list stays the single
-- record, and a tap opens what the list would have shown. Two types push
-- today:
--   - friend_request_received (already created by notify_friendship_change)
--   - followed_venue_event    (new, section 4)
-- Preferences only decide push. The in-app list always shows everything.
--
-- Provider: APNs directly, no Firebase. The Edge Function signs its own
-- APNs token from a .p8 key held in function secrets.
--
-- BEST-EFFORT, the same way notify-venue-claim is: pg_net is asynchronous
-- and the queuing call sits in its own exception block, so a push failure
-- can never fail the insert of a notification, a friend request or an
-- event approval.
--
-- The webhook secret is NOT in this file. It is created out of band with
-- `select vault.create_secret('<value>', 'send_push_webhook_secret', ...)`
-- and the same value set as the SEND_PUSH_WEBHOOK_SECRET function secret.

begin;

-- ============================================================
-- 1. push_devices — one row per APNs device token
-- ============================================================
--
-- A token belongs to one install of the app on one device. When a phone
-- signs in to another account, the token moves to that account (it is the
-- same device, and the old account must stop receiving its pushes). That
-- takeover is why writes go through register_push_device: RLS on a plain
-- insert/update could never let user B claim a row user A owns.
--
-- apns_environment is the app's own report of which APNs host its token
-- belongs to (Xcode builds: sandbox; TestFlight/App Store: production).
-- send-push treats it as a hint and corrects it on BadDeviceToken.

create table public.push_devices (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  token            text not null unique,
  platform         text not null default 'ios' check (platform in ('ios')),
  apns_environment text not null check (apns_environment in ('sandbox', 'production')),
  app_version      text,
  created_at       timestamptz not null default now(),
  last_seen_at     timestamptz not null default now()
);

create index push_devices_user_idx on public.push_devices (user_id);

comment on table public.push_devices is
  'APNs device tokens. Written only through register_push_device / '
  'unregister_push_device; read by the owner and by send-push '
  '(service_role), which also deletes tokens APNs reports as dead.';

alter table public.push_devices enable row level security;

create policy push_devices_select on public.push_devices
  for select to authenticated
  using (user_id = auth.uid());

create policy push_devices_delete on public.push_devices
  for delete to authenticated
  using (user_id = auth.uid());

revoke all on table public.push_devices from public, anon, authenticated;
grant select, delete on public.push_devices to authenticated;

create function public.register_push_device(
  p_token text,
  p_apns_environment text,
  p_app_version text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  -- An APNs token is 32 bytes, sent as 64 hex characters. Allow longer
  -- (Apple has said the length may grow), never anything that isn't hex.
  if p_token is null or p_token !~ '^[0-9a-f]{64,200}$' then
    raise exception 'Invalid device token';
  end if;
  if p_apns_environment not in ('sandbox', 'production') then
    raise exception 'Invalid APNs environment';
  end if;

  insert into public.push_devices (user_id, token, apns_environment, app_version)
  values (auth.uid(), p_token, p_apns_environment, left(p_app_version, 32))
  on conflict (token) do update
    set user_id = excluded.user_id,
        apns_environment = excluded.apns_environment,
        app_version = excluded.app_version,
        last_seen_at = now();
end;
$$;

revoke execute on function public.register_push_device(text, text, text) from public, anon;
grant execute on function public.register_push_device(text, text, text) to authenticated;

-- Sign-out: this device stops receiving this account's pushes. Only the
-- caller's own row can go; anyone else's token is left alone.
create function public.unregister_push_device(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.push_devices
   where token = p_token and user_id = auth.uid();
$$;

revoke execute on function public.unregister_push_device(text) from public, anon;
grant execute on function public.unregister_push_device(text) to authenticated;

-- ============================================================
-- 2. notification_preferences — per-type push toggles
-- ============================================================
--
-- One row per user, created on the first change. No row means the
-- defaults, which are on: iOS's own permission prompt is the real opt-in,
-- and nobody receives a push without saying yes to it.

create table public.notification_preferences (
  user_id                    uuid primary key references public.profiles(id) on delete cascade,
  push_friend_requests       boolean not null default true,
  push_followed_venue_events boolean not null default true,
  updated_at                 timestamptz not null default now()
);

comment on table public.notification_preferences is
  'Push toggles per notification type. A missing row means every default '
  '(on). Affects push only, never the in-app notifications list.';

alter table public.notification_preferences enable row level security;

create policy notification_preferences_select on public.notification_preferences
  for select to authenticated
  using (user_id = auth.uid());

create policy notification_preferences_insert on public.notification_preferences
  for insert to authenticated
  with check (user_id = auth.uid());

create policy notification_preferences_update on public.notification_preferences
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on table public.notification_preferences from public, anon, authenticated;
grant select, insert, update on public.notification_preferences to authenticated;

-- ============================================================
-- 3. The new notification type
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
      'followed_venue_event'
    ));

-- subject_type 'event' already exists (20261018130000).

-- One notification per person per event, ever: an event taken offline and
-- published again, or a host link added twice, never notifies twice.
create unique index notifications_followed_venue_event_uidx
  on public.notifications (recipient_id, subject_id)
  where type = 'followed_venue_event';

-- ============================================================
-- 4. Fan-out: a followed venue publishes an event
-- ============================================================
--
-- Who: every follower of the event's HOST venue (restaurant, hotel or
-- private chef), through its approved host links. Not followers of the
-- event's venue or participants — host only, by decision (2026-10-30).
--
-- When: the event is published, upcoming (not cancelled), and has not
-- ended in its own timezone. A host venue's own active managers are left
-- out: they made the event.
--
-- Called at COMMIT, by deferred constraint triggers on events and on the
-- three link tables, and it re-reads the current state rather than
-- trusting the trigger's row. That covers every order the writes come in:
-- submit_venue_event inserts the event and its host link in one
-- transaction; admin_approve_event flips an event whose links already
-- exist; an ops import may insert a published event and add its links in
-- the same or a later transaction. The unique index above makes repeated
-- calls harmless.
--
-- Existing published events never fire: the triggers react only to
-- changes made after they exist.

create function public.fan_out_followed_venue_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.events;
begin
  select * into v_event from public.events where id = p_event_id;
  if not found
     or v_event.moderation_status <> 'published'
     or v_event.status <> 'upcoming'
     or v_event.cancelled_at is not null
     or coalesce(v_event.end_date, v_event.start_date)
        < (now() at time zone v_event.timezone)::date
  then
    return;
  end if;

  insert into public.notifications (recipient_id, type, subject_type, subject_id)
  select distinct f.user_id, 'followed_venue_event', 'event', p_event_id
    from (
      select fr.user_id
        from public.event_restaurants l
        join public.follows_restaurants fr on fr.restaurant_id = l.restaurant_id
       where l.event_id = p_event_id and l.is_host and l.approved_at is not null
         and not exists (
           select 1 from public.venue_managers_restaurants m
            where m.restaurant_id = l.restaurant_id and m.user_id = fr.user_id
              and m.revoked_at is null)
      union
      select fh.user_id
        from public.event_hotels l
        join public.follows_hotels fh on fh.hotel_id = l.hotel_id
       where l.event_id = p_event_id and l.is_host and l.approved_at is not null
         and not exists (
           select 1 from public.venue_managers_hotels m
            where m.hotel_id = l.hotel_id and m.user_id = fh.user_id
              and m.revoked_at is null)
      union
      select fc.user_id
        from public.event_chefs l
        join public.follows_private_chefs fc on fc.private_chef_id = l.chef_id
       where l.event_id = p_event_id and l.is_host and l.approved_at is not null
         and not exists (
           select 1 from public.venue_managers_private_chefs m
            where m.private_chef_id = l.chef_id and m.user_id = fc.user_id
              and m.revoked_at is null)
    ) f
  on conflict (recipient_id, subject_id) where type = 'followed_venue_event'
  do nothing;
end;
$$;

revoke execute on function public.fan_out_followed_venue_event(uuid) from public, anon, authenticated;

-- Trigger wrapper on events: only an insert, or a change of
-- moderation_status, can make an event newly published.
create function public.events_fan_out_on_publish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.moderation_status = 'published'
     and (tg_op = 'INSERT' or old.moderation_status is distinct from 'published')
  then
    perform public.fan_out_followed_venue_event(new.id);
  end if;
  return null;
end;
$$;

revoke execute on function public.events_fan_out_on_publish() from public, anon;

create constraint trigger events_fan_out_on_publish
  after insert or update of moderation_status on public.events
  deferrable initially deferred
  for each row execute function public.events_fan_out_on_publish();

-- Trigger wrapper on the three link tables: a host link that becomes
-- approved on an already-published event (an ops import adding links
-- after the event, or a host link approved later).
create function public.event_links_fan_out_on_host()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_host and new.approved_at is not null
     and (tg_op = 'INSERT' or not old.is_host or old.approved_at is null)
  then
    perform public.fan_out_followed_venue_event(new.event_id);
  end if;
  return null;
end;
$$;

revoke execute on function public.event_links_fan_out_on_host() from public, anon;

create constraint trigger event_restaurants_fan_out_on_host
  after insert or update of is_host, approved_at on public.event_restaurants
  deferrable initially deferred
  for each row execute function public.event_links_fan_out_on_host();

create constraint trigger event_hotels_fan_out_on_host
  after insert or update of is_host, approved_at on public.event_hotels
  deferrable initially deferred
  for each row execute function public.event_links_fan_out_on_host();

create constraint trigger event_chefs_fan_out_on_host
  after insert or update of is_host, approved_at on public.event_chefs
  deferrable initially deferred
  for each row execute function public.event_links_fan_out_on_host();

-- ============================================================
-- 5. Push hand-off: notifications -> pg_net -> send-push
-- ============================================================
--
-- Statement-level, with a transition table, so one fan-out insert of N
-- followers becomes ceil(N / 500) HTTP calls rather than N. The function
-- receives only ids and reads everything else itself with service_role,
-- so nothing about the recipient travels through pg_net's request table.

do $$
begin
  if not exists (
    select 1 from vault.decrypted_secrets where name = 'send_push_webhook_secret'
  ) then
    raise warning 'send_push_webhook_secret is not set in vault.secrets — pushes will be '
      'skipped (see notify_push_for_notifications) until it is created with the same value '
      'as the send-push function''s SEND_PUSH_WEBHOOK_SECRET secret. Never commit that value.';
  end if;
end $$;

create function public.notify_push_for_notifications()
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
   where type in ('friend_request_received', 'followed_venue_event');
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

revoke execute on function public.notify_push_for_notifications() from public, anon;

create trigger notifications_push_on_insert
  after insert on public.notifications
  referencing new table as new_rows
  for each statement execute function public.notify_push_for_notifications();

-- ============================================================
-- 6. Reading: get_notifications_v4 for this build, older ones filtered
-- ============================================================
--
-- v4 is v3's exact body (20261022120000) under a new name — the event
-- columns already resolve a followed_venue_event (name, start date, host
-- venue), so no new column is needed. v3 becomes v4 minus the new type,
-- which is what installed 1.4.0 reads; v2 and v1 already read through v3,
-- so they inherit the filter. The unread counts follow the same steps.

create function public.get_notifications_v4()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      end,
      case when n.subject_type = 'planned_trip_member'
        then case when tm.user_id = auth.uid() then tm.invited_by else tm.user_id end
      end
    ) as other_user_id,
    p.username as other_username,
    p.display_name as other_display_name,
    p.avatar_url as other_avatar_url,
    mlr.subject_type as listing_subject_type,
    mlr.name as listing_name,
    mlr.city as listing_city,
    vi.venue_type as invite_venue_type,
    vi.venue_id as invite_venue_id,
    coalesce(rf.name, hf.name) as invite_venue_name,
    coalesce(rf.city_name, hf.city_name) as invite_venue_city,
    vi.note as invite_note,
    vi.status as invite_status,
    vi.expires_at as invite_expires_at,
    coalesce(
      case when clr.id is not null then 'restaurant' end,
      case when clh.id is not null then 'hotel' end,
      case when clp.id is not null then 'private_chef' end
    ) as claim_venue_type,
    coalesce(clr.restaurant_id, clh.hotel_id, clp.private_chef_id) as claim_venue_id,
    coalesce(clrf.name, clhf.name, clpf.display_name) as claim_venue_name,
    coalesce(clrf.city_name, clhf.city_name, clpf.home_city) as claim_venue_city,
    coalesce(clr.review_note, clh.review_note, clp.review_note) as claim_review_note,
    coalesce(vas.venue_type, vps.venue_type) as submission_venue_type,
    coalesce(vas.venue_id, vps.venue_id) as submission_venue_id,
    coalesce(subrf.name, subhf.name, subpf.display_name) as submission_venue_name,
    coalesce(subrf.city_name, subhf.city_name, subpf.home_city) as submission_venue_city,
    coalesce(vas.review_note, vps.review_note) as submission_review_note,
    f.status as friendship_status,
    ev.name as event_name,
    ev.start_date as event_start_date,
    ev.review_note as event_review_note,
    evh.venue_type as event_venue_type,
    evh.venue_id as event_venue_id,
    evh.venue_name as event_venue_name,
    tr.id as trip_id,
    tr.title as trip_title,
    tr.start_date as trip_start_date,
    tr.end_date as trip_end_date,
    tm.status as trip_member_status
  from public.notifications n
  left join public.friendships f
    on n.subject_type = 'friendship' and f.id = n.subject_id
  left join public.venue_invites vi
    on n.subject_type = 'venue_invite' and vi.id = n.subject_id
  left join public.restaurants_full rf
    on vi.venue_type = 'restaurant' and rf.id = vi.venue_id
  left join public.hotels_full hf
    on vi.venue_type = 'hotel' and hf.id = vi.venue_id
  left join public.planned_trip_members tm
    on n.subject_type = 'planned_trip_member' and tm.id = n.subject_id
  left join public.planned_trips tr
    on tr.id = tm.trip_id
  left join public.profiles p
    on p.id = coalesce(
      case when n.subject_type = 'friendship'
        then case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
      end,
      case when n.subject_type = 'venue_invite'
        then case when vi.from_user_id = auth.uid() then vi.to_user_id else vi.from_user_id end
      end,
      case when n.subject_type = 'planned_trip_member'
        then case when tm.user_id = auth.uid() then tm.invited_by else tm.user_id end
      end
    )
  left join public.missing_listing_reports mlr
    on n.subject_type = 'missing_listing_report' and mlr.id = n.subject_id
  left join public.claims_restaurants clr
    on n.subject_type = 'venue_claim' and clr.id = n.subject_id
  left join public.claims_hotels clh
    on n.subject_type = 'venue_claim' and clh.id = n.subject_id
  left join public.claims_private_chefs clp
    on n.subject_type = 'venue_claim' and clp.id = n.subject_id
  left join public.restaurants_full clrf on clrf.id = clr.restaurant_id
  left join public.hotels_full clhf on clhf.id = clh.hotel_id
  left join public.private_chefs_full clpf on clpf.id = clp.private_chef_id
  left join public.venue_about_submissions vas
    on n.subject_type = 'venue_about_submission' and vas.id = n.subject_id
  left join public.venue_photo_submissions vps
    on n.subject_type = 'venue_photo_submission' and vps.id = n.subject_id
  left join public.restaurants_full subrf
    on coalesce(vas.venue_type, vps.venue_type) = 'restaurant'
    and subrf.id = coalesce(vas.venue_id, vps.venue_id)
  left join public.hotels_full subhf
    on coalesce(vas.venue_type, vps.venue_type) = 'hotel'
    and subhf.id = coalesce(vas.venue_id, vps.venue_id)
  left join public.private_chefs_full subpf
    on coalesce(vas.venue_type, vps.venue_type) = 'private_chef'
    and subpf.id = coalesce(vas.venue_id, vps.venue_id)
  left join public.events ev
    on n.subject_type = 'event' and ev.id = n.subject_id
  left join lateral public.event_host_venue(ev.id) evh on true
  where n.recipient_id = auth.uid()
  order by n.created_at desc;
$function$;

revoke execute on function public.get_notifications_v4() from public, anon;
grant execute on function public.get_notifications_v4() to authenticated;

-- Same signature as before, so create or replace is enough. The order is
-- v4's own (created_at desc); a filter preserves it.
create or replace function public.get_notifications_v3()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v4()
   where type <> 'followed_venue_event';
$function$;

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
      'followed_venue_event'
    );
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
      'followed_venue_event'
    );
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
    and type <> 'followed_venue_event';
$$;

create function public.get_unread_notification_count_v4()
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

revoke execute on function public.get_unread_notification_count_v4() from public, anon;
grant execute on function public.get_unread_notification_count_v4() to authenticated;

commit;
