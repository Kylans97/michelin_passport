-- Venue events — phase 3 of docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md,
-- designed in docs/Architecture/VENUE_EVENTS_PHASE_3_DESIGN.md (all six
-- recommendations accepted by the product owner, 2026-10-28).
--
-- Written 2026-10-28. Not yet applied.
-- Needs 20261018120000_add_country_timezones.sql first.
--
-- What it does:
--   1. events gains its review record (submitted_at, reviewed_at,
--      reviewed_by, review_note); event_edits records every edit to a
--      live event for the admins.
--   2. A venue writes events only through RPCs: submit_venue_event,
--      update_venue_event, cancel_venue_event, and reads its own with
--      get_venue_events. Rights: an active manager of a host venue
--      (is_active_venue_manager), never "whoever submitted it".
--   3. One validation function holds every rule, for submit and update
--      alike: the V1 types and tags, the one-year window in the event's
--      own timezone, the time model (an unknown time is never invented:
--      start_at/end_at are set only from a known time), coordinates, and
--      a timezone from the event country's own list.
--   4. Admins approve, reject (which also takes a live event offline) and
--      mark edits seen; get_review_queue gains both new kinds; admins can
--      read non-published events, so the review preview can show the real
--      event page.
--   5. The six V1 event tags, which only production had, are seeded
--      (a no-op there) so a fresh replay matches.
--   6. The loose write policies keyed on submitted_by are dropped: the
--      open insert/update on events, the claimant link inserts, and the
--      unused participant-link policies (decision 3). Nothing writes
--      through them: production's 28 events have no submitted_by, and
--      every app query on these tables is a read (checked 2026-10-28).
--   7. Notifications gain event_approved/event_rejected. Installed builds
--      throw on a notification type they don't know
--      (AppNotificationType.fromWire), which would empty their whole
--      Notifications screen. So get_notifications() and
--      get_unread_notification_count() keep returning only the types
--      they already knew; the phase 3 build reads the _v2 versions.
--
-- Every SECURITY DEFINER function has its own revoke from public, anon
-- below (CLAUDE.md). The internal helpers are revoked from authenticated
-- too.

begin;

-- ============================================================
-- 1. Schema
-- ============================================================

alter table public.events
  add column submitted_at timestamptz,
  add column reviewed_at  timestamptz,
  add column reviewed_by  uuid references public.profiles(id) on delete set null,
  add column review_note  text;

create table public.event_edits (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  edited_by  uuid references public.profiles(id) on delete set null,
  edited_at  timestamptz not null default now(),
  changes    jsonb not null,
  seen_at    timestamptz,
  seen_by    uuid references public.profiles(id) on delete set null
);

create index event_edits_unseen_idx on public.event_edits (edited_at) where seen_at is null;

-- The six V1 tags. They exist in production (inserted 2026-08-22,
-- outside any migration), but no migration ever wrote them, so a fresh
-- replay had none and the RPCs below could never assign a tag there.
-- Exactly production's rows, ids included; a no-op on production
-- (verified: all six ids already present, 2026-10-28).
insert into public.event_tags (id, slug, name, created_at) values
  ('f01457d1-627d-471b-9804-32842b89f412', 'wine',       'Wine',        '2026-08-22 21:40:49.711883+00'),
  ('97ea0a69-0267-416b-9594-42c41be9e569', 'winemaker',  'Winemaker',   '2026-08-22 21:40:49.711883+00'),
  ('060f945a-610e-4dec-934f-ad77e4267e22', 'wild_game',  'Wild / Game', '2026-08-22 21:40:49.711883+00'),
  ('58f79eda-7e48-4434-a812-3289723f499d', 'guest_chef', 'Guest Chef',  '2026-08-22 21:40:49.711883+00'),
  ('52e6755e-b99c-46d6-8336-e4a70ec65635', 'four_hands', 'Four Hands',  '2026-08-22 21:40:49.711883+00'),
  ('83d0577a-d07c-4a9c-9ec6-913b4e6bb473', 'charity',    'Charity',     '2026-08-22 21:40:49.711883+00')
on conflict (id) do nothing;

-- Written by update_venue_event, read by get_review_queue: no client path.
alter table public.event_edits enable row level security;
revoke all on table public.event_edits from public, anon, authenticated;

-- The host-edit column lock, extended to the new review columns. No
-- client update path is left after section 5, so this is defence in depth.
create or replace function public.enforce_event_host_edit_columns()
returns trigger
language plpgsql
as $$
begin
  if current_user = 'authenticated' then
    if new.moderation_status is distinct from old.moderation_status
      or new.submitted_by is distinct from old.submitted_by
      or new.submitted_at is distinct from old.submitted_at
      or new.reviewed_at is distinct from old.reviewed_at
      or new.reviewed_by is distinct from old.reviewed_by
      or new.review_note is distinct from old.review_note
    then
      raise exception
        'Moderation and review columns can only change through review, not a host edit.';
    end if;
  end if;
  return new;
end;
$$;

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
      'event_rejected'
    ));

alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim',
      'venue_about_submission', 'venue_photo_submission', 'event'
    ));

-- ============================================================
-- 2. Internal helpers
-- ============================================================

-- The event's host venue: its first host link. A venue-submitted event
-- has exactly one; a curated one may have none (then no rows).
create function public.event_host_venue(p_event_id uuid)
returns table (venue_type text, venue_id uuid, venue_name text)
language sql
stable
security definer
set search_path = public
as $$
  select 'restaurant'::text, l.restaurant_id, r.name
    from public.event_restaurants l join public.restaurants r on r.id = l.restaurant_id
   where l.event_id = p_event_id and l.is_host
  union all
  select 'hotel', l.hotel_id, h.name
    from public.event_hotels l join public.hotels h on h.id = l.hotel_id
   where l.event_id = p_event_id and l.is_host
  union all
  select 'private_chef', l.chef_id, c.display_name
    from public.event_chefs l join public.private_chefs c on c.id = l.chef_id
   where l.event_id = p_event_id and l.is_host
  limit 1;
$$;

-- True when the caller actively manages any host venue of the event.
create function public.is_event_host_manager(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.event_restaurants l
     where l.event_id = p_event_id and l.is_host
       and public.is_active_venue_manager('restaurant', l.restaurant_id)
    union all
    select 1 from public.event_hotels l
     where l.event_id = p_event_id and l.is_host
       and public.is_active_venue_manager('hotel', l.hotel_id)
    union all
    select 1 from public.event_chefs l
     where l.event_id = p_event_id and l.is_host
       and public.is_active_venue_manager('private_chef', l.chef_id)
  );
$$;

-- Every rule a venue event must meet, for submit and update alike.
-- Raises with a message the app can show; returns nothing.
--
-- p_existing_start_date: the stored start date on an update, else null.
-- An event already under way may keep its (past) start date; it may not
-- be moved into the past, and its end date may never be.
create function public.validate_venue_event(
  p_name text,
  p_description text,
  p_event_type text,
  p_tag_slugs text[],
  p_start_date date,
  p_end_date date,
  p_start_time time,
  p_end_time time,
  p_timezone text,
  p_country_code text,
  p_city text,
  p_venue_name text,
  p_address text,
  p_latitude double precision,
  p_longitude double precision,
  p_ticket_url text,
  p_admission_type text,
  p_admission_note text,
  p_existing_start_date date
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_zones text[];
  v_today date;
begin
  if length(trim(coalesce(p_name, ''))) not between 1 and 200 then
    raise exception 'Give the event a name (up to 200 characters).';
  end if;
  if length(trim(coalesce(p_description, ''))) not between 1 and 5000 then
    raise exception 'Describe the event (up to 5,000 characters).';
  end if;
  if p_event_type is null
     or p_event_type not in ('dinner', 'lunch', 'festival', 'gala', 'tasting', 'brunch', 'party') then
    raise exception 'Choose a type: dinner, lunch, festival, gala, tasting, brunch or party.';
  end if;
  if exists (
    select 1 from unnest(coalesce(p_tag_slugs, '{}')) s
     where s not in (select t.slug from public.event_tags t)
  ) then
    raise exception 'Unknown tag.';
  end if;

  select c.timezones into v_zones from public.countries c where c.country_code = p_country_code;
  if v_zones is null then
    raise exception 'Unknown country.';
  end if;
  if p_timezone is null or not (p_timezone = any (v_zones)) then
    raise exception 'Choose a timezone for this country.';
  end if;

  -- "Today" is today where the event happens.
  v_today := (now() at time zone p_timezone)::date;
  if p_start_date is null or p_end_date is null then
    raise exception 'Give the event a date.';
  end if;
  if p_end_date < p_start_date then
    raise exception 'The end date can''t be before the start date.';
  end if;
  if p_start_date < v_today
     and p_start_date is distinct from p_existing_start_date then
    raise exception 'The event can''t start in the past.';
  end if;
  if p_end_date < v_today then
    raise exception 'The event can''t end in the past.';
  end if;
  if p_end_date > (v_today + interval '1 year')::date then
    raise exception 'Events can be added at most one year ahead.';
  end if;

  -- The time model: a start time is optional; an end time only with one.
  -- On a single day the end must follow the start; 00:00 is the end of
  -- that day (the same "last active date" rule the curated events use).
  if p_end_time is not null and p_start_time is null then
    raise exception 'Add a start time before an end time.';
  end if;
  if p_end_date = p_start_date
     and p_end_time is not null
     and p_end_time <> time '00:00'
     and p_end_time <= p_start_time then
    raise exception 'The end time must be after the start time, or end on the next day.';
  end if;

  if length(trim(coalesce(p_city, ''))) not between 1 and 100 then
    raise exception 'Give the city.';
  end if;
  if length(trim(coalesce(p_venue_name, ''))) not between 1 and 200 then
    raise exception 'Give the place''s name.';
  end if;
  if length(coalesce(p_address, '')) > 300 then
    raise exception 'The address is too long.';
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    raise exception 'Set the location on the map.';
  end if;
  if p_ticket_url is not null
     and (p_ticket_url !~ '^https://[^ ]+$' or length(p_ticket_url) > 2000) then
    raise exception 'The ticket link must be a full https:// address.';
  end if;
  if coalesce(p_admission_type, 'unknown') not in ('free', 'paid', 'mixed', 'unknown') then
    raise exception 'Unknown admission type.';
  end if;
  if length(coalesce(p_admission_note, '')) > 500 then
    raise exception 'The admission note is too long.';
  end if;
end;
$$;

-- An exact instant only from a known time, never an invented one. An end
-- at 00:00 is midnight at the end of its (last active) date.
create function public.venue_event_instant(p_date date, p_time time, p_timezone text, p_is_end boolean)
returns timestamptz
language sql
immutable
set search_path = public
as $$
  select case
    when p_time is null then null
    when p_is_end and p_time = time '00:00' then ((p_date + 1) + p_time) at time zone p_timezone
    else (p_date + p_time) at time zone p_timezone
  end;
$$;

-- Queues the admin email for a submitted event. Best-effort, exactly as
-- notify_admin_of_pending_venue_submission: it never fails the caller.
-- Sends the host venue alongside the row, since an events row has none.
create function public.notify_admin_of_venue_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_secret text;
  v_row jsonb;
begin
  begin
    select to_jsonb(e) || jsonb_build_object('venue_type', h.venue_type, 'venue_id', h.venue_id)
      into v_row
      from public.events e
      left join lateral public.event_host_venue(e.id) h on true
     where e.id = p_event_id;

    select decrypted_secret into v_secret
      from vault.decrypted_secrets
     where name = 'notify_venue_submission_webhook_secret';

    if v_secret is null then
      raise warning 'notify_admin_of_venue_event: webhook secret not found in vault — '
        'skipping admin email for event %', p_event_id;
    else
      perform net.http_post(
        url := 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/notify-venue-submission',
        body := jsonb_build_object('submission_type', 'events', 'row', v_row),
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-webhook-secret', v_secret
        ),
        timeout_milliseconds := 5000
      );
    end if;
  exception when others then
    raise warning 'notify_admin_of_venue_event: failed to queue admin email for event % — %',
      p_event_id, sqlerrm;
  end;
end;
$$;

revoke execute on function public.event_host_venue(uuid) from public, anon, authenticated;
revoke execute on function public.is_event_host_manager(uuid) from public, anon, authenticated;
revoke execute on function public.validate_venue_event(
  text, text, text, text[], date, date, time, time, text, text, text, text, text,
  double precision, double precision, text, text, text, date
) from public, anon, authenticated;
revoke execute on function public.venue_event_instant(date, time, text, boolean) from public, anon, authenticated;
revoke execute on function public.notify_admin_of_venue_event(uuid) from public, anon, authenticated;

-- ============================================================
-- 3. What a venue calls
-- ============================================================

-- Creates the event as 'submitted' with its host link and tags, in one
-- transaction. p_at_venue: held at the venue itself, so the location is
-- copied from the venue's own verified fields and the client's location
-- is ignored. A private chef has no location of its own, so always pins.
create function public.submit_venue_event(
  p_venue_type text,
  p_venue_id uuid,
  p_name text,
  p_description text,
  p_event_type text,
  p_start_date date,
  p_timezone text,
  p_at_venue boolean,
  p_end_date date default null,
  p_start_time time default null,
  p_end_time time default null,
  p_tag_slugs text[] default '{}',
  p_venue_name text default null,
  p_address text default null,
  p_city text default null,
  p_country_code text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_ticket_url text default null,
  p_admission_type text default 'unknown',
  p_admission_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_end_date date := coalesce(p_end_date, p_start_date);
  v_venue_name text := p_venue_name;
  v_address text := p_address;
  v_city text := p_city;
  v_country text := p_country_code;
  v_lat double precision := p_latitude;
  v_lng double precision := p_longitude;
begin
  if auth.uid() is null
     or p_venue_type not in ('restaurant', 'hotel', 'private_chef')
     or not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'You don''t manage this venue.';
  end if;

  if coalesce(p_at_venue, false) then
    if p_venue_type = 'restaurant' then
      select v.name, v.address, v.city_name, v.country_code, v.latitude, v.longitude
        into v_venue_name, v_address, v_city, v_country, v_lat, v_lng
        from public.restaurants_full v where v.id = p_venue_id;
    elsif p_venue_type = 'hotel' then
      select v.name, v.address, v.city_name, v.country_code, v.latitude, v.longitude
        into v_venue_name, v_address, v_city, v_country, v_lat, v_lng
        from public.hotels_full v where v.id = p_venue_id;
    else
      raise exception 'A private chef sets the location on the map.';
    end if;
    if v_lat is null or v_lng is null then
      raise exception 'This venue has no location yet. Set it on the map.';
    end if;
  end if;

  perform public.validate_venue_event(
    p_name, p_description, p_event_type, p_tag_slugs,
    p_start_date, v_end_date, p_start_time, p_end_time, p_timezone,
    v_country, v_city, v_venue_name, v_address, v_lat, v_lng,
    p_ticket_url, p_admission_type, p_admission_note, null
  );

  insert into public.events (
    name, description, event_type,
    start_date, end_date, start_time, end_time, start_at, end_at, timezone,
    venue_name, address, city, country_code, latitude, longitude,
    ticket_url, admission_type, admission_note,
    moderation_status, submitted_by, submitted_at
  ) values (
    trim(p_name), trim(p_description), p_event_type,
    p_start_date, v_end_date, p_start_time, p_end_time,
    public.venue_event_instant(p_start_date, p_start_time, p_timezone, false),
    public.venue_event_instant(v_end_date, p_end_time, p_timezone, true),
    p_timezone,
    trim(v_venue_name), nullif(trim(v_address), ''), trim(v_city), v_country, v_lat, v_lng,
    p_ticket_url, coalesce(p_admission_type, 'unknown'), nullif(trim(p_admission_note), ''),
    'submitted', auth.uid(), now()
  )
  returning id into v_id;

  if p_venue_type = 'restaurant' then
    insert into public.event_restaurants (event_id, restaurant_id, is_host, is_venue)
    values (v_id, p_venue_id, true, coalesce(p_at_venue, false));
  elsif p_venue_type = 'hotel' then
    insert into public.event_hotels (event_id, hotel_id, is_host, is_venue)
    values (v_id, p_venue_id, true, coalesce(p_at_venue, false));
  else
    insert into public.event_chefs (event_id, chef_id, is_host, is_venue)
    values (v_id, p_venue_id, true, false);
  end if;

  insert into public.event_tag_assignments (event_id, tag_id)
  select v_id, t.id from public.event_tags t
   where t.slug = any (coalesce(p_tag_slugs, '{}'));

  perform public.notify_admin_of_venue_event(v_id);
  return v_id;
end;
$$;

-- Edits an event. Submitted stays submitted; rejected goes back to
-- submitted (the resubmit); published stays live and the change is
-- recorded in event_edits (nothing recorded if nothing changed).
-- Cancelled and archived events can't be edited.
create function public.update_venue_event(
  p_event_id uuid,
  p_name text,
  p_description text,
  p_event_type text,
  p_start_date date,
  p_timezone text,
  p_at_venue boolean,
  p_end_date date default null,
  p_start_time time default null,
  p_end_time time default null,
  p_tag_slugs text[] default '{}',
  p_venue_name text default null,
  p_address text default null,
  p_city text default null,
  p_country_code text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_ticket_url text default null,
  p_admission_type text default 'unknown',
  p_admission_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old public.events;
  v_new public.events;
  v_host record;
  v_end_date date := coalesce(p_end_date, p_start_date);
  v_venue_name text := p_venue_name;
  v_address text := p_address;
  v_city text := p_city;
  v_country text := p_country_code;
  v_lat double precision := p_latitude;
  v_lng double precision := p_longitude;
  v_old_tags text[];
  v_new_tags text[];
  v_changes jsonb;
begin
  select * into v_old from public.events where id = p_event_id for update;
  if v_old.id is null or auth.uid() is null or not public.is_event_host_manager(p_event_id) then
    raise exception 'You don''t manage this event.';
  end if;
  if v_old.cancelled_at is not null then
    raise exception 'A cancelled event can''t be edited.';
  end if;
  if v_old.moderation_status not in ('submitted', 'rejected', 'published') then
    raise exception 'This event can''t be edited.';
  end if;

  select * into v_host from public.event_host_venue(p_event_id);
  if coalesce(p_at_venue, false) then
    if v_host.venue_type = 'restaurant' then
      select v.name, v.address, v.city_name, v.country_code, v.latitude, v.longitude
        into v_venue_name, v_address, v_city, v_country, v_lat, v_lng
        from public.restaurants_full v where v.id = v_host.venue_id;
    elsif v_host.venue_type = 'hotel' then
      select v.name, v.address, v.city_name, v.country_code, v.latitude, v.longitude
        into v_venue_name, v_address, v_city, v_country, v_lat, v_lng
        from public.hotels_full v where v.id = v_host.venue_id;
    else
      raise exception 'A private chef sets the location on the map.';
    end if;
    if v_lat is null or v_lng is null then
      raise exception 'This venue has no location yet. Set it on the map.';
    end if;
  end if;

  perform public.validate_venue_event(
    p_name, p_description, p_event_type, p_tag_slugs,
    p_start_date, v_end_date, p_start_time, p_end_time, p_timezone,
    v_country, v_city, v_venue_name, v_address, v_lat, v_lng,
    p_ticket_url, p_admission_type, p_admission_note, v_old.start_date
  );

  select coalesce(array_agg(t.slug order by t.slug), '{}') into v_old_tags
    from public.event_tag_assignments a join public.event_tags t on t.id = a.tag_id
   where a.event_id = p_event_id;
  select coalesce(array_agg(distinct s order by s), '{}') into v_new_tags
    from unnest(coalesce(p_tag_slugs, '{}')) s;

  update public.events set
    name = trim(p_name),
    description = trim(p_description),
    event_type = p_event_type,
    start_date = p_start_date,
    end_date = v_end_date,
    start_time = p_start_time,
    end_time = p_end_time,
    start_at = public.venue_event_instant(p_start_date, p_start_time, p_timezone, false),
    end_at = public.venue_event_instant(v_end_date, p_end_time, p_timezone, true),
    timezone = p_timezone,
    venue_name = trim(v_venue_name),
    address = nullif(trim(v_address), ''),
    city = trim(v_city),
    country_code = v_country,
    latitude = v_lat,
    longitude = v_lng,
    ticket_url = p_ticket_url,
    admission_type = coalesce(p_admission_type, 'unknown'),
    admission_note = nullif(trim(p_admission_note), ''),
    moderation_status = case when moderation_status = 'rejected' then 'submitted' else moderation_status end,
    submitted_at = case when moderation_status = 'rejected' then now() else submitted_at end
  where id = p_event_id
  returning * into v_new;

  delete from public.event_tag_assignments where event_id = p_event_id;
  insert into public.event_tag_assignments (event_id, tag_id)
  select p_event_id, t.id from public.event_tags t where t.slug = any (v_new_tags);

  -- The is_venue flag follows where the event is held.
  update public.event_restaurants set is_venue = coalesce(p_at_venue, false)
   where event_id = p_event_id and is_host and v_host.venue_type = 'restaurant';
  update public.event_hotels set is_venue = coalesce(p_at_venue, false)
   where event_id = p_event_id and is_host and v_host.venue_type = 'hotel';

  if v_old.moderation_status = 'published' then
    select coalesce(jsonb_object_agg(o.key, jsonb_build_object('old', o.value, 'new', n.value)), '{}')
      into v_changes
      from jsonb_each(to_jsonb(v_old)) o
      join jsonb_each(to_jsonb(v_new)) n on n.key = o.key
     where o.key in (
             'name', 'description', 'event_type', 'start_date', 'end_date', 'start_time',
             'end_time', 'timezone', 'venue_name', 'address', 'city', 'country_code',
             'latitude', 'longitude', 'ticket_url', 'admission_type', 'admission_note')
       and o.value is distinct from n.value;
    if v_old_tags is distinct from v_new_tags then
      v_changes := v_changes || jsonb_build_object(
        'tags', jsonb_build_object('old', to_jsonb(v_old_tags), 'new', to_jsonb(v_new_tags)));
    end if;
    if v_changes <> '{}'::jsonb then
      insert into public.event_edits (event_id, edited_by, changes)
      values (p_event_id, auth.uid(), v_changes);
    end if;
  elsif v_old.moderation_status = 'rejected' then
    perform public.notify_admin_of_venue_event(p_event_id);
  end if;
end;
$$;

-- Cancels without review. The existing shim sets status = 'cancelled'.
create function public.cancel_venue_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_event_host_manager(p_event_id) then
    raise exception 'You don''t manage this event.';
  end if;
  update public.events set cancelled_at = now()
   where id = p_event_id and cancelled_at is null
     and moderation_status in ('submitted', 'rejected', 'published');
  if not found then
    raise exception 'This event can''t be cancelled.';
  end if;
end;
$$;

-- Every event the venue hosts, in any status, for any of its active
-- managers — events_own_submission_read only reaches the submitter.
create function public.get_venue_events(p_venue_type text, p_venue_id uuid)
returns setof public.events
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'You don''t manage this venue.';
  end if;
  return query
  select e.* from public.events e
   where e.moderation_status <> 'archived'
     and (
       (p_venue_type = 'restaurant' and exists (
          select 1 from public.event_restaurants l
           where l.event_id = e.id and l.is_host and l.restaurant_id = p_venue_id))
       or (p_venue_type = 'hotel' and exists (
          select 1 from public.event_hotels l
           where l.event_id = e.id and l.is_host and l.hotel_id = p_venue_id))
       or (p_venue_type = 'private_chef' and exists (
          select 1 from public.event_chefs l
           where l.event_id = e.id and l.is_host and l.chef_id = p_venue_id))
     )
   order by e.start_date, e.start_time nulls first;
end;
$$;

revoke execute on function public.submit_venue_event(
  text, uuid, text, text, text, date, text, boolean, date, time, time, text[],
  text, text, text, text, double precision, double precision, text, text, text
) from public, anon;
revoke execute on function public.update_venue_event(
  uuid, text, text, text, date, text, boolean, date, time, time, text[],
  text, text, text, text, double precision, double precision, text, text, text
) from public, anon;
revoke execute on function public.cancel_venue_event(uuid) from public, anon;
revoke execute on function public.get_venue_events(text, uuid) from public, anon;
grant execute on function public.submit_venue_event(
  text, uuid, text, text, text, date, text, boolean, date, time, time, text[],
  text, text, text, text, double precision, double precision, text, text, text
) to authenticated;
grant execute on function public.update_venue_event(
  uuid, text, text, text, date, text, boolean, date, time, time, text[],
  text, text, text, text, double precision, double precision, text, text, text
) to authenticated;
grant execute on function public.cancel_venue_event(uuid) to authenticated;
grant execute on function public.get_venue_events(text, uuid) to authenticated;

-- ============================================================
-- 4. What an admin calls
-- ============================================================

create function public.admin_approve_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_submitter uuid;
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.events
     set moderation_status = 'published', reviewed_at = now(), reviewed_by = auth.uid(),
         review_note = null
   where id = p_event_id and moderation_status = 'submitted'
  returning submitted_by into v_submitter;
  if not found then
    raise exception 'This event isn''t waiting for review.';
  end if;
  if v_submitter is not null then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (v_submitter, 'event_approved', 'event', p_event_id);
  end if;
end;
$$;

-- Rejects a submitted event, or takes a live one offline. A note is
-- required: it is what the venue sees.
create function public.admin_reject_event(p_event_id uuid, p_review_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_submitter uuid;
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  if length(trim(coalesce(p_review_note, ''))) = 0 then
    raise exception 'Add a note for the venue.';
  end if;
  update public.events
     set moderation_status = 'rejected', reviewed_at = now(), reviewed_by = auth.uid(),
         review_note = trim(p_review_note)
   where id = p_event_id and moderation_status in ('submitted', 'published')
  returning submitted_by into v_submitter;
  if not found then
    raise exception 'This event can''t be rejected.';
  end if;
  if v_submitter is not null then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (v_submitter, 'event_rejected', 'event', p_event_id);
  end if;
end;
$$;

create function public.admin_mark_event_edit_seen(p_edit_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  update public.event_edits set seen_at = now(), seen_by = auth.uid()
   where id = p_edit_id and seen_at is null;
  if not found then
    raise exception 'This change was already marked as seen.';
  end if;
end;
$$;

revoke execute on function public.admin_approve_event(uuid) from public, anon;
revoke execute on function public.admin_reject_event(uuid, text) from public, anon;
revoke execute on function public.admin_mark_event_edit_seen(uuid) from public, anon;
grant execute on function public.admin_approve_event(uuid) to authenticated;
grant execute on function public.admin_reject_event(uuid, text) to authenticated;
grant execute on function public.admin_mark_event_edit_seen(uuid) to authenticated;

-- Admins read events that aren't published yet, so the review preview
-- can open the real event page.
create policy events_admin_read on public.events
  for select to authenticated using (public.is_admin());
create policy event_restaurants_admin_read on public.event_restaurants
  for select to authenticated using (public.is_admin());
create policy event_hotels_admin_read on public.event_hotels
  for select to authenticated using (public.is_admin());
create policy event_chefs_admin_read on public.event_chefs
  for select to authenticated using (public.is_admin());

-- The review queue, with two new kinds: venue_event (a submitted event)
-- and venue_event_edit (an unseen change to a live one). New columns are
-- appended, so the return type changes: drop and recreate. Installed
-- builds skip kinds they don't know and ignore extra columns.
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
  event_changes jsonb
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
           null::uuid as ev_id, null::jsonb as changes
      from public.claims_restaurants c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'hotel', c.hotel_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null
      from public.claims_hotels c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'private_chef', c.private_chef_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null
      from public.claims_private_chefs c where c.status = 'pending'
    union all
    select 'venue_about', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           s.about_text, null, null, null, null, null, null, null, null
      from public.venue_about_submissions s where s.status = 'pending'
    union all
    select 'venue_photo', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           null, s.storage_path, s.replaces_photo_id, s.duplicate_of_submission_id,
           s.focus_x, s.focus_y, s.zoom, null, null
      from public.venue_photo_submissions s where s.status = 'pending'
    union all
    select 'venue_event', e.id, h.venue_type, h.venue_id, e.submitted_by,
           coalesce(e.submitted_at, e.created_at),
           null, null, null, null,
           null, null, null, null, null, null, null, e.id, null
      from public.events e
      left join lateral public.event_host_venue(e.id) h on true
     where e.moderation_status = 'submitted' and e.cancelled_at is null
    union all
    select 'venue_event_edit', x.id, h.venue_type, h.venue_id, x.edited_by, x.edited_at,
           null, null, null, null,
           null, null, null, null, null, null, null, x.event_id, x.changes
      from public.event_edits x
      left join lateral public.event_host_venue(x.event_id) h on true
     where x.seen_at is null
  )
  select i.kind, i.item_id, i.venue_type, i.venue_id,
         coalesce(r.name, h.name, pc.display_name) as venue_name,
         coalesce(rc.name, hc.name, pc.home_city) as venue_city,
         i.user_id,
         coalesce(nullif(trim(p.display_name), ''), '@' || p.username, 'Mantelier member') as submitter_label,
         i.at,
         i.role, i.business_email, i.phone, i.notes,
         i.about_text, i.storage_path, i.replaces, i.dup, i.fx, i.fy, i.z,
         i.ev_id, ev.name, ev.start_date, i.changes
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

-- ============================================================
-- 5. The loose write policies go
-- ============================================================

drop policy events_claimant_insert on public.events;
drop policy events_owner_update on public.events;
drop policy event_restaurants_claimant_insert on public.event_restaurants;
drop policy event_hotels_claimant_insert on public.event_hotels;
drop policy event_chefs_claimant_insert on public.event_chefs;
drop policy event_restaurants_host_edit_insert on public.event_restaurants;
drop policy event_hotels_host_edit_insert on public.event_hotels;
drop policy event_chefs_host_edit_insert on public.event_chefs;
drop policy event_restaurants_host_delete on public.event_restaurants;
drop policy event_hotels_host_delete on public.event_hotels;
drop policy event_chefs_host_delete on public.event_chefs;

-- ============================================================
-- 6. Notifications: event types for the new build only
-- ============================================================

-- Everything get_notifications() returned (its live definition, taken
-- from production 2026-10-28, which includes 20261012120000's
-- friendship_status), plus the event types and their columns. The
-- phase 3 build reads this one.
create function public.get_notifications_v2()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text)
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
    evh.venue_name as event_venue_name
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

revoke execute on function public.get_notifications_v2() from public, anon;
grant execute on function public.get_notifications_v2() to authenticated;

-- What installed builds read: every type they already know, nothing new.
-- Same columns and order as before, so create or replace is enough.
create or replace function public.get_notifications()
returns table (
  id uuid, type text, subject_type text, subject_id uuid, is_read boolean,
  created_at timestamptz, other_user_id uuid, other_username text,
  other_display_name text, other_avatar_url text, listing_subject_type text,
  listing_name text, listing_city text, invite_venue_type text,
  invite_venue_id uuid, invite_venue_name text, invite_venue_city text,
  invite_note text, invite_status text, invite_expires_at timestamptz,
  claim_venue_type text, claim_venue_id uuid, claim_venue_name text,
  claim_venue_city text, claim_review_note text, submission_venue_type text,
  submission_venue_id uuid, submission_venue_name text,
  submission_venue_city text, submission_review_note text, friendship_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select id, type, subject_type, subject_id, is_read, created_at, other_user_id,
         other_username, other_display_name, other_avatar_url, listing_subject_type,
         listing_name, listing_city, invite_venue_type, invite_venue_id,
         invite_venue_name, invite_venue_city, invite_note, invite_status,
         invite_expires_at, claim_venue_type, claim_venue_id, claim_venue_name,
         claim_venue_city, claim_review_note, submission_venue_type,
         submission_venue_id, submission_venue_name, submission_venue_city,
         submission_review_note, friendship_status
    from public.get_notifications_v2()
   where type not in ('event_approved', 'event_rejected');
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
    and type not in ('event_approved', 'event_rejected');
$$;

create function public.get_unread_notification_count_v2()
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

revoke execute on function public.get_unread_notification_count_v2() from public, anon;
grant execute on function public.get_unread_notification_count_v2() to authenticated;

commit;
