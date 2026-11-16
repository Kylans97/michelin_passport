-- When you want to go, and a reminder the day before bookings open.
--
-- The idea (product owner, 2026-11-16): the restaurants people dream of
-- are hard to book because their books open months ahead and fill at
-- once. So a restaurant on someone's wishlist may carry the month they
-- would like to go, and when that restaurant's booking window is known,
-- Mantelier reminds them the day before that month opens.
--
-- Decided by the product owner on 2026-11-16:
--   1. The month is optional, month and year only, restaurants only. It
--      is the member's own: friends read the rest of the wishlist
--      (20260814120000) but not this column. The member reads it through
--      get_my_wishlist_plans() and writes it through
--      set_wishlist_planned_month().
--   2. A restaurant's booking window is a verified fact, never an
--      estimate. Four shapes: rolling (on day X at a set local time, day
--      X + N days or months opens), monthly (on day D of each month, the
--      month M months ahead opens), seasonal (one-off releases, each
--      opening a run of dates) and unknown. Unknown, or no row at all,
--      means no reminder, ever. A known date with an unknown time keeps
--      the time NULL — never made up — and the reminder then names no
--      time.
--   3. A venue manager adds and changes their restaurant's window without
--      an admin's check, like opening hours (20261101180000): it is a
--      practical fact, and a delay would leave members unreminded. Who
--      changed it last, and when, is recorded. Writes go only through
--      set_restaurant_booking_window(), which checks
--      is_active_venue_manager(), the single source of edit permission.
--   4. The reminder comes at 10:00 in the member's own timezone on the
--      day before the opening, as an in-app notification and a push
--      (the push only when the member keeps push_booking_reminders on).
--      The member's timezone is their home country's (the first of its
--      timezones), else Europe/Amsterdam. One reminder per wishlist plan:
--      a new month is a new plan. A month that is already open gets no
--      reminder; the app says so instead.
--   5. Later this may be a Pro feature. booking_reminders_enabled() is
--      the one server-side switch: the reminder job and the app's read
--      both ask it. Today it is true for everyone.
--
-- The date logic lives in three pure functions — booking_window_opening,
-- booking_window_status and booking_reminder_due — that read no table,
-- so they can be tested on their own (supabase/tests/
-- booking_window_test.sql) and the app and the job can never disagree:
-- the app's status line comes from the same functions through
-- get_my_wishlist_plans().
--
-- Installed builds: the new notification type follows the established
-- pattern (20261101210000): this build reads v6, and v5 and the unread
-- counts installed builds call leave 'booking_window_opening' out.
--
-- Every new SECURITY DEFINER function carries its own
-- `revoke execute ... from public, anon` in this file (CLAUDE.md).
--
-- Real date: 2026-11-16. The filename is a sequence number, the next one
-- after the highest existing migration (20261101390000, on production),
-- per CLAUDE.md.

begin;

-- ============================================================
-- 1. The month on the wishlist row, readable by its owner alone
-- ============================================================

alter table public.wishlist
  add column planned_month date,
  add constraint wishlist_planned_month_check check (
    planned_month is null
    or (entity_type = 'restaurant' and extract(day from planned_month) = 1)
  );

comment on column public.wishlist.planned_month is
  'The month (always its 1st) the member would like to go. Restaurants '
  'only, optional. Readable and writable by the owner only, through '
  'get_my_wishlist_plans() and set_wishlist_planned_month(); friends, '
  'who may read the rest of the row, cannot select it.';

-- RLS cannot hide a column, so column privileges do: authenticated keeps
-- every column it had, except planned_month. Every reader in the app
-- names its columns; the SECURITY DEFINER reports that count rows run as
-- the owner and are unaffected.
revoke select, insert, update on public.wishlist from authenticated;
grant select (user_id, entity_type, entity_id, added_at, priority)
  on public.wishlist to authenticated;
grant insert (user_id, entity_type, entity_id, added_at, priority)
  on public.wishlist to authenticated;
grant update (priority) on public.wishlist to authenticated;

-- ============================================================
-- 2. Booking windows
-- ============================================================

create table public.restaurant_booking_windows (
  restaurant_id  uuid primary key references public.restaurants(id) on delete cascade,
  kind           text not null check (kind in ('rolling', 'monthly', 'seasonal', 'unknown')),
  -- The venue's IANA timezone; every date and time below is local to it.
  timezone       text not null,
  -- rolling: on day X at release_time, day X + rolling_amount
  -- rolling_unit(s) becomes bookable.
  rolling_amount smallint,
  rolling_unit   text check (rolling_unit in ('day', 'month')),
  -- monthly: on day release_day of each month at release_time (the
  -- month's last day when it is shorter), the month months_ahead months
  -- later becomes bookable, all of it.
  release_day    smallint check (release_day between 1 and 31),
  months_ahead   smallint check (months_ahead between 1 and 24),
  -- rolling and monthly. NULL = the time is not known; never guessed.
  release_time   time,
  platform       text check (platform in (
                   'tock', 'resy', 'sevenrooms', 'thefork', 'opentable',
                   'own_site', 'phone', 'email', 'other')),
  -- 'venue': set by the restaurant's own manager. 'research': verified
  -- by us from source_url, after review.
  source_kind    text not null check (source_kind in ('venue', 'research')),
  source_url     text,
  verified_on    date not null,
  updated_at     timestamptz not null default now(),
  updated_by     uuid references public.profiles(id) on delete set null,
  check (source_kind = 'venue' or source_url is not null),
  check (case kind
    when 'rolling' then
      ((rolling_unit = 'day' and rolling_amount between 1 and 730)
        or (rolling_unit = 'month' and rolling_amount between 1 and 24))
      and release_day is null and months_ahead is null
    when 'monthly' then
      release_day is not null and months_ahead is not null
      and rolling_amount is null and rolling_unit is null
    else
      rolling_amount is null and rolling_unit is null
      and release_day is null and months_ahead is null and release_time is null
  end)
);

comment on table public.restaurant_booking_windows is
  'When a restaurant''s books open, verified, never estimated. kind '
  '''unknown'' (or no row) means no reminder. Kept by the venue''s manager '
  'through set_restaurant_booking_window(), live at once, or by reviewed '
  'research.';

-- seasonal: each release opens covers_from..covers_to on release_on at
-- release_time (NULL = not known), local to the window's timezone.
create table public.restaurant_booking_releases (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurant_booking_windows(restaurant_id) on delete cascade,
  release_on    date not null,
  release_time  time,
  covers_from   date not null,
  covers_to     date not null,
  check (covers_to >= covers_from),
  check (release_on <= covers_from)
);

create index restaurant_booking_releases_restaurant_idx
  on public.restaurant_booking_releases (restaurant_id);

-- The timezone must be one of the restaurant's country's
-- (countries.timezones, 20261018120000), which also proves it is a real
-- IANA name.
create function public.check_restaurant_booking_window()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
      from public.restaurants r
      join public.countries c on c.country_code = r.country_code
     where r.id = new.restaurant_id
       and new.timezone = any (c.timezones)
  ) then
    raise exception 'Timezone % is not one of this restaurant''s country''s timezones', new.timezone;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function public.check_restaurant_booking_window() from public, anon;

create trigger restaurant_booking_windows_check
  before insert or update on public.restaurant_booking_windows
  for each row execute function public.check_restaurant_booking_window();

alter table public.restaurant_booking_windows enable row level security;
alter table public.restaurant_booking_releases enable row level security;

-- Catalogue-like: anyone may read, nobody writes directly.
create policy restaurant_booking_windows_read on public.restaurant_booking_windows
  for select to anon, authenticated using (true);
create policy restaurant_booking_releases_read on public.restaurant_booking_releases
  for select to anon, authenticated using (true);

revoke all on table public.restaurant_booking_windows from public, anon, authenticated;
revoke all on table public.restaurant_booking_releases from public, anon, authenticated;
grant select (restaurant_id, kind, timezone, rolling_amount, rolling_unit,
              release_day, months_ahead, release_time, platform,
              source_kind, source_url, verified_on, updated_at)
  on public.restaurant_booking_windows to anon, authenticated;
grant select on public.restaurant_booking_releases to anon, authenticated;

-- ============================================================
-- 3. The date logic: pure, no table reads
-- ============================================================

-- The local date and time at which the first day of p_month becomes
-- bookable; no row when that is not known. For a seasonal window, the
-- earliest release that opens any day of the month.
create function public.booking_window_opening(
  p_kind text,
  p_rolling_amount integer,
  p_rolling_unit text,
  p_release_day integer,
  p_months_ahead integer,
  p_release_time time,
  p_releases jsonb,
  p_month date
)
returns table (opens_on date, opens_time time)
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_first date := date_trunc('month', p_month)::date;
  v_last date := (date_trunc('month', p_month) + interval '1 month - 1 day')::date;
  v_release_month date;
  v_month_days integer;
begin
  if p_month is null then
    return;
  end if;

  if p_kind = 'rolling' and p_rolling_amount is not null then
    opens_on := case p_rolling_unit
      when 'day' then v_first - p_rolling_amount
      when 'month' then (v_first - make_interval(months => p_rolling_amount))::date
    end;
    opens_time := p_release_time;
    if opens_on is not null then
      return next;
    end if;
  elsif p_kind = 'monthly' and p_release_day is not null and p_months_ahead is not null then
    v_release_month := (v_first - make_interval(months => p_months_ahead))::date;
    v_month_days := extract(day from (v_release_month + interval '1 month - 1 day'))::integer;
    opens_on := v_release_month + (least(p_release_day, v_month_days) - 1);
    opens_time := p_release_time;
    return next;
  elsif p_kind = 'seasonal' then
    select (r ->> 'release_on')::date, (r ->> 'release_time')::time
      into opens_on, opens_time
      from jsonb_array_elements(coalesce(p_releases, '[]'::jsonb)) r
     where (r ->> 'covers_from')::date <= v_last
       and (r ->> 'covers_to')::date >= v_first
     order by (r ->> 'release_on')::date, (r ->> 'release_time')::time nulls last
     limit 1;
    if found then
      return next;
    end if;
  end if;
  -- 'unknown', or an incomplete shape: nothing, never an estimate.
end;
$$;

revoke execute on function public.booking_window_opening(text, integer, text, integer, integer, time, jsonb, date) from public, anon;

-- 'open', 'opens_today' (date known, time not, and it is that date),
-- 'upcoming', or NULL when the opening is not known. Judged in the
-- restaurant's own timezone.
create function public.booking_window_status(
  p_opens_on date,
  p_opens_time time,
  p_timezone text,
  p_now timestamptz
)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select case
    when p_opens_on is null then null
    when p_opens_time is not null then
      case when p_now >= ((p_opens_on + p_opens_time) at time zone p_timezone)
           then 'open' else 'upcoming' end
    when (p_now at time zone p_timezone)::date > p_opens_on then 'open'
    when (p_now at time zone p_timezone)::date = p_opens_on then 'opens_today'
    else 'upcoming'
  end;
$$;

revoke execute on function public.booking_window_status(date, time, text, timestamptz) from public, anon;

-- The member-local date the books open: the opening moment seen from the
-- member's timezone, or, with no known time, the restaurant's own date.
create function public.booking_opening_member_date(
  p_opens_on date,
  p_opens_time time,
  p_restaurant_timezone text,
  p_member_timezone text
)
returns date
language sql
stable
set search_path = public, pg_temp
as $$
  select case
    when p_opens_time is null then p_opens_on
    else (((p_opens_on + p_opens_time) at time zone p_restaurant_timezone)
           at time zone p_member_timezone)::date
  end;
$$;

revoke execute on function public.booking_opening_member_date(date, time, text, text) from public, anon;

-- True from 10:00 to midnight, member time, on the day before the
-- opening's member-local date. Outside that day it is too early, or too
-- late to say "tomorrow".
create function public.booking_reminder_due(
  p_opens_on date,
  p_opens_time time,
  p_restaurant_timezone text,
  p_member_timezone text,
  p_now timestamptz
)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select p_opens_on is not null
     and (p_now at time zone p_member_timezone)::date
         = public.booking_opening_member_date(
             p_opens_on, p_opens_time, p_restaurant_timezone, p_member_timezone) - 1
     and (p_now at time zone p_member_timezone)::time >= time '10:00';
$$;

revoke execute on function public.booking_reminder_due(date, time, text, text, timestamptz) from public, anon;

-- ============================================================
-- 4. Switches: the feature (later perhaps Pro) and the member's timezone
-- ============================================================

-- The one server-side switch for booking reminders. Today: everyone.
-- Making this a Pro feature later means changing this body only.
create function public.booking_reminders_enabled(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p_user_id is not null;
$$;

revoke execute on function public.booking_reminders_enabled(uuid) from public, anon, authenticated;

create function public.member_timezone(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select c.timezones[1]
       from public.profiles p
       join public.countries c on c.country_code = p.home_country_code
      where p.id = p_user_id),
    'Europe/Amsterdam'
  );
$$;

revoke execute on function public.member_timezone(uuid) from public, anon, authenticated;

alter table public.notification_preferences
  add column push_booking_reminders boolean not null default true;

-- ============================================================
-- 5. The member's own plans
-- ============================================================

-- Sets (or, with NULL, clears) the month for a restaurant already on the
-- caller's wishlist. A month before the current one, or more than three
-- years ahead, is refused.
create function public.set_wishlist_planned_month(
  p_restaurant_id uuid,
  p_month date
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_month date := date_trunc('month', p_month)::date;
begin
  if v_uid is null then
    raise exception 'Not signed in';
  end if;
  if p_month is not null and (
       v_month < date_trunc('month', current_date)::date
       or v_month > (date_trunc('month', current_date) + interval '3 years')::date
     ) then
    raise exception 'Choose a month from now up to three years ahead';
  end if;

  update public.wishlist
     set planned_month = v_month
   where user_id = v_uid
     and entity_type = 'restaurant'
     and entity_id = p_restaurant_id;
  if not found then
    raise exception 'This restaurant is not on your wishlist';
  end if;
end;
$$;

revoke execute on function public.set_wishlist_planned_month(uuid, date) from public, anon;
grant execute on function public.set_wishlist_planned_month(uuid, date) to authenticated;

-- One row per restaurant on the caller's wishlist with a month set: when
-- that month opens, judged now, in the restaurant's timezone. status is
-- NULL when the window is not known.
create function public.get_my_wishlist_plans()
returns table (
  restaurant_id uuid,
  planned_month date,
  opens_on date,
  opens_time time,
  timezone text,
  status text,
  reminders_enabled boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select w.entity_id,
         w.planned_month,
         o.opens_on,
         o.opens_time,
         case when o.opens_on is not null then bw.timezone end,
         public.booking_window_status(o.opens_on, o.opens_time, bw.timezone, now()),
         public.booking_reminders_enabled(auth.uid())
    from public.wishlist w
    left join public.restaurant_booking_windows bw on bw.restaurant_id = w.entity_id
    left join lateral public.booking_window_opening(
      bw.kind, bw.rolling_amount, bw.rolling_unit, bw.release_day,
      bw.months_ahead, bw.release_time,
      (select jsonb_agg(jsonb_build_object(
                'release_on', r.release_on, 'release_time', r.release_time,
                'covers_from', r.covers_from, 'covers_to', r.covers_to))
         from public.restaurant_booking_releases r
        where r.restaurant_id = w.entity_id),
      w.planned_month
    ) o on true
   where w.user_id = auth.uid()
     and w.entity_type = 'restaurant'
     and w.planned_month is not null;
$$;

revoke execute on function public.get_my_wishlist_plans() from public, anon;
grant execute on function public.get_my_wishlist_plans() to authenticated;

-- ============================================================
-- 6. The manager's write
-- ============================================================

-- Replaces the restaurant's window, or removes it with NULL. p_window:
--   {"kind": "rolling", "rolling_amount": 60, "rolling_unit": "day",
--    "release_time": "10:00", ...}
--   {"kind": "monthly", "release_day": 1, "months_ahead": 2, ...}
--   {"kind": "seasonal", "releases": [{"release_on": "2027-03-01",
--      "release_time": "10:00", "covers_from": "2027-06-01",
--      "covers_to": "2027-09-30"}], ...}
-- plus optional "timezone" (required when the country has more than
-- one), "platform" and "source_url". release_time may be null: not known.
create function public.set_restaurant_booking_window(
  p_restaurant_id uuid,
  p_window jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_kind text := p_window ->> 'kind';
  v_timezone text := nullif(p_window ->> 'timezone', '');
  v_releases jsonb := coalesce(p_window -> 'releases', '[]'::jsonb);
begin
  if not public.is_active_venue_manager('restaurant', p_restaurant_id) then
    raise exception 'Not a manager of this restaurant';
  end if;

  if p_window is null or jsonb_typeof(p_window) = 'null' then
    delete from public.restaurant_booking_windows where restaurant_id = p_restaurant_id;
    return;
  end if;

  -- 'unknown' is what research records after looking; a venue that has
  -- no fixed window removes it instead.
  if v_kind is null or v_kind not in ('rolling', 'monthly', 'seasonal') then
    raise exception 'Booking window kind must be rolling, monthly or seasonal';
  end if;

  if v_timezone is null then
    select c.timezones[1] into v_timezone
      from public.restaurants r
      join public.countries c on c.country_code = r.country_code
     where r.id = p_restaurant_id
       and cardinality(c.timezones) = 1;
    if v_timezone is null then
      raise exception 'Choose the restaurant''s timezone';
    end if;
  end if;

  if v_kind = 'seasonal' then
    if jsonb_typeof(v_releases) <> 'array' or jsonb_array_length(v_releases) = 0 then
      raise exception 'A seasonal window needs at least one release';
    end if;
    if jsonb_array_length(v_releases) > 24 then
      raise exception 'At most 24 releases';
    end if;
  end if;

  insert into public.restaurant_booking_windows as bw (
    restaurant_id, kind, timezone, rolling_amount, rolling_unit,
    release_day, months_ahead, release_time, platform,
    source_kind, source_url, verified_on, updated_by
  ) values (
    p_restaurant_id,
    v_kind,
    v_timezone,
    case when v_kind = 'rolling' then (p_window ->> 'rolling_amount')::smallint end,
    case when v_kind = 'rolling' then p_window ->> 'rolling_unit' end,
    case when v_kind = 'monthly' then (p_window ->> 'release_day')::smallint end,
    case when v_kind = 'monthly' then (p_window ->> 'months_ahead')::smallint end,
    case when v_kind <> 'seasonal' then nullif(p_window ->> 'release_time', '')::time end,
    nullif(p_window ->> 'platform', ''),
    'venue',
    nullif(p_window ->> 'source_url', ''),
    current_date,
    auth.uid()
  )
  on conflict (restaurant_id) do update set
    kind = excluded.kind,
    timezone = excluded.timezone,
    rolling_amount = excluded.rolling_amount,
    rolling_unit = excluded.rolling_unit,
    release_day = excluded.release_day,
    months_ahead = excluded.months_ahead,
    release_time = excluded.release_time,
    platform = excluded.platform,
    source_kind = excluded.source_kind,
    source_url = excluded.source_url,
    verified_on = excluded.verified_on,
    updated_by = excluded.updated_by;

  delete from public.restaurant_booking_releases where restaurant_id = p_restaurant_id;
  if v_kind = 'seasonal' then
    insert into public.restaurant_booking_releases (
      restaurant_id, release_on, release_time, covers_from, covers_to)
    select p_restaurant_id,
           (r ->> 'release_on')::date,
           nullif(r ->> 'release_time', '')::time,
           (r ->> 'covers_from')::date,
           (r ->> 'covers_to')::date
      from jsonb_array_elements(v_releases) r;
  end if;
end;
$$;

revoke execute on function public.set_restaurant_booking_window(uuid, jsonb) from public, anon;
grant execute on function public.set_restaurant_booking_window(uuid, jsonb) to authenticated;

-- ============================================================
-- 7. The reminder
-- ============================================================

-- One row per reminder sent: the notification's subject, and the guard
-- that no plan is reminded twice. What it says is fixed when it is sent.
create table public.booking_reminders (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.profiles(id) on delete cascade,
  restaurant_id       uuid not null references public.restaurants(id) on delete cascade,
  planned_month       date not null,
  opens_on            date not null,
  opens_time          time,
  restaurant_timezone text not null,
  member_timezone     text not null,
  created_at          timestamptz not null default now(),
  unique (user_id, restaurant_id, planned_month)
);

alter table public.booking_reminders enable row level security;

create policy booking_reminders_own_select on public.booking_reminders
  for select to authenticated using (user_id = auth.uid());

revoke all on table public.booking_reminders from public, anon, authenticated;
grant select on public.booking_reminders to authenticated;

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
      'booking_window_opening'
    ));

alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim',
      'venue_about_submission', 'venue_photo_submission', 'event',
      'planned_trip_member', 'profile', 'booking_reminder'
    ));

-- Run every hour by pg_cron, so 10:00 is caught in every member's
-- timezone. Safe to run again: a plan already reminded is skipped by
-- booking_reminders' unique key. p_now is for tests only.
create function public.send_booking_window_reminders(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  with due as (
    select w.user_id, w.entity_id as restaurant_id, w.planned_month,
           o.opens_on, o.opens_time, bw.timezone as restaurant_timezone,
           public.member_timezone(w.user_id) as member_timezone
      from public.wishlist w
      join public.restaurant_booking_windows bw on bw.restaurant_id = w.entity_id
      cross join lateral public.booking_window_opening(
        bw.kind, bw.rolling_amount, bw.rolling_unit, bw.release_day,
        bw.months_ahead, bw.release_time,
        (select jsonb_agg(jsonb_build_object(
                  'release_on', r.release_on, 'release_time', r.release_time,
                  'covers_from', r.covers_from, 'covers_to', r.covers_to))
           from public.restaurant_booking_releases r
          where r.restaurant_id = w.entity_id),
        w.planned_month
      ) o
     where w.entity_type = 'restaurant'
       and w.planned_month is not null
       and bw.kind <> 'unknown'
       and public.booking_reminders_enabled(w.user_id)
  ),
  sent as (
    insert into public.booking_reminders (
      user_id, restaurant_id, planned_month, opens_on, opens_time,
      restaurant_timezone, member_timezone)
    select d.user_id, d.restaurant_id, d.planned_month, d.opens_on, d.opens_time,
           d.restaurant_timezone, d.member_timezone
      from due d
     where public.booking_reminder_due(
             d.opens_on, d.opens_time, d.restaurant_timezone, d.member_timezone, p_now)
    on conflict (user_id, restaurant_id, planned_month) do nothing
    returning id, user_id
  )
  insert into public.notifications (recipient_id, type, subject_type, subject_id)
  select s.user_id, 'booking_window_opening', 'booking_reminder', s.id
    from sent s;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.send_booking_window_reminders(timestamptz) from public, anon, authenticated;

select cron.schedule(
  'booking-window-reminders',
  '5 * * * *',
  'select public.send_booking_window_reminders()'
);

-- The push hand-off gains the type: 20261101210000's function, unchanged
-- apart from the type list.
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
                  'booking_window_opening');
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
-- 8. Readers: v6 for this build, v5 and older without the reminder
-- ============================================================
-- v5's body becomes get_notifications_v6_rows, untouched. v6 adds the
-- reminder's columns to it; a new v5, which installed builds call, is it
-- without reminders. v4 reads v5, and the older ones v4, so they inherit
-- that. The unread counts follow the same steps.

alter function public.get_notifications_v5() rename to get_notifications_v6_rows;
revoke execute on function public.get_notifications_v6_rows() from public, anon, authenticated;

create function public.get_notifications_v6()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select n.*,
         br.restaurant_id,
         r.name,
         br.planned_month,
         br.opens_on,
         br.opens_time,
         br.restaurant_timezone
    from public.get_notifications_v6_rows() n
    left join public.booking_reminders br
      on n.subject_type = 'booking_reminder' and br.id = n.subject_id
    left join public.restaurants r on r.id = br.restaurant_id;
$function$;

revoke execute on function public.get_notifications_v6() from public, anon;
grant execute on function public.get_notifications_v6() to authenticated;

create function public.get_notifications_v5()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v6_rows()
   where type <> 'booking_window_opening';
$function$;

revoke execute on function public.get_notifications_v5() from public, anon;
grant execute on function public.get_notifications_v5() to authenticated;

alter function public.get_unread_notification_count_v5() rename to get_unread_notification_count_v6;

create function public.get_unread_notification_count_v5()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type <> 'booking_window_opening';
$$;

revoke execute on function public.get_unread_notification_count_v5() from public, anon;
grant execute on function public.get_unread_notification_count_v5() to authenticated;

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
    and type not in ('birthday', 'booking_window_opening');
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
    and type not in ('followed_venue_event', 'birthday', 'booking_window_opening');
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
      'followed_venue_event', 'birthday', 'booking_window_opening'
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
      'followed_venue_event', 'birthday', 'booking_window_opening'
    );
$$;

commit;
