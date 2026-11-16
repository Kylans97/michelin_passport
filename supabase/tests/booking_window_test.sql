-- Tests for the wishlist month and booking-window reminder
-- (20261101400000_add_wishlist_month_and_booking_windows.sql).
--
-- Run against a local stack that has every migration applied, never
-- against production:
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/booking_window_test.sql
-- Everything runs inside one transaction that is rolled back, so the
-- database is left as it was. A failed check raises, naming the case;
-- success ends with "booking window tests: all passed".

begin;

create function pg_temp.check(p_ok boolean, p_case text)
returns void language plpgsql as $$
begin
  if p_ok is distinct from true then
    raise exception 'FAILED: %', p_case;
  end if;
end;
$$;

-- Shorthand: the opening of p_month for a window shape.
create function pg_temp.opening(
  p_kind text, p_amount int, p_unit text, p_day int, p_ahead int,
  p_time time, p_releases jsonb, p_month date)
returns text language sql as $$
  select coalesce(
    (select o.opens_on::text || ' ' || coalesce(o.opens_time::text, 'no time')
       from public.booking_window_opening(
         p_kind, p_amount, p_unit, p_day, p_ahead, p_time, p_releases, p_month) o),
    'unknown');
$$;

-- ── 1. When a month opens ─────────────────────────────────────────────

-- Rolling, days: 1 May 2027 minus 60 days is 2 March.
select pg_temp.check(
  pg_temp.opening('rolling', 60, 'day', null, null, '10:00', null, '2027-05-01')
    = '2027-03-02 10:00:00', 'rolling 60 days');
-- Any day of the month asks about its 1st.
select pg_temp.check(
  pg_temp.opening('rolling', 60, 'day', null, null, '10:00', null, '2027-05-17')
    = '2027-03-02 10:00:00', 'rolling, month given mid-month');
-- Rolling across a leap day: 1 March 2028 minus 30 days is 31 January.
select pg_temp.check(
  pg_temp.opening('rolling', 30, 'day', null, null, '00:00', null, '2028-03-01')
    = '2028-01-31 00:00:00', 'rolling across 29 February');
-- Rolling, months.
select pg_temp.check(
  pg_temp.opening('rolling', 2, 'month', null, null, '09:30', null, '2027-05-01')
    = '2027-03-01 09:30:00', 'rolling 2 months');
-- Rolling across a year end.
select pg_temp.check(
  pg_temp.opening('rolling', 3, 'month', null, null, '10:00', null, '2027-02-01')
    = '2026-11-01 10:00:00', 'rolling across new year');
-- Known date, unknown time: the time stays unknown.
select pg_temp.check(
  pg_temp.opening('rolling', 90, 'day', null, null, null, null, '2027-05-01')
    = '2027-01-31 no time', 'rolling, time not known');

-- Monthly: on the 1st, the month two ahead opens.
select pg_temp.check(
  pg_temp.opening('monthly', null, null, 1, 2, '10:00', null, '2027-05-01')
    = '2027-03-01 10:00:00', 'monthly day 1, 2 ahead');
-- Monthly on the 15th, one ahead.
select pg_temp.check(
  pg_temp.opening('monthly', null, null, 15, 1, '12:00', null, '2027-01-01')
    = '2026-12-15 12:00:00', 'monthly across new year');
-- Release day 31 in February: its last day.
select pg_temp.check(
  pg_temp.opening('monthly', null, null, 31, 3, '10:00', null, '2027-05-01')
    = '2027-02-28 10:00:00', 'monthly day 31 in February');
select pg_temp.check(
  pg_temp.opening('monthly', null, null, 31, 4, '10:00', null, '2028-06-01')
    = '2028-02-29 10:00:00', 'monthly day 31 in a leap February');
select pg_temp.check(
  pg_temp.opening('monthly', null, null, 31, 1, '10:00', null, '2027-05-01')
    = '2027-04-30 10:00:00', 'monthly day 31 in a 30-day month');

-- Seasonal.
select pg_temp.check(
  pg_temp.opening('seasonal', null, null, null, null, null,
    '[{"release_on":"2027-03-01","release_time":"10:00","covers_from":"2027-06-01","covers_to":"2027-09-30"},
      {"release_on":"2027-09-01","release_time":null,"covers_from":"2027-10-01","covers_to":"2027-12-31"}]',
    '2027-07-01') = '2027-03-01 10:00:00', 'seasonal, inside the first release');
select pg_temp.check(
  pg_temp.opening('seasonal', null, null, null, null, null,
    '[{"release_on":"2027-03-01","release_time":"10:00","covers_from":"2027-06-01","covers_to":"2027-09-30"},
      {"release_on":"2027-09-01","release_time":null,"covers_from":"2027-10-01","covers_to":"2027-12-31"}]',
    '2027-11-01') = '2027-09-01 no time', 'seasonal, second release, time not known');
select pg_temp.check(
  pg_temp.opening('seasonal', null, null, null, null, null,
    '[{"release_on":"2027-03-01","release_time":"10:00","covers_from":"2027-06-01","covers_to":"2027-09-30"}]',
    '2028-02-01') = 'unknown', 'seasonal, month no release covers');
-- A season that starts mid-month still opens that month.
select pg_temp.check(
  pg_temp.opening('seasonal', null, null, null, null, null,
    '[{"release_on":"2027-04-01","release_time":"11:00","covers_from":"2027-06-15","covers_to":"2027-08-31"}]',
    '2027-06-01') = '2027-04-01 11:00:00', 'seasonal, season starts mid-month');
-- Two releases cover the month: the earlier one.
select pg_temp.check(
  pg_temp.opening('seasonal', null, null, null, null, null,
    '[{"release_on":"2027-05-01","release_time":"10:00","covers_from":"2027-07-01","covers_to":"2027-07-31"},
      {"release_on":"2027-03-01","release_time":"10:00","covers_from":"2027-06-01","covers_to":"2027-07-15"}]',
    '2027-07-01') = '2027-03-01 10:00:00', 'seasonal, earliest of two releases');

-- Unknown, or an incomplete shape: never an estimate.
select pg_temp.check(
  pg_temp.opening('unknown', null, null, null, null, null, null, '2027-05-01') = 'unknown',
  'unknown window');
select pg_temp.check(
  pg_temp.opening(null, null, null, null, null, null, null, '2027-05-01') = 'unknown',
  'no window');
select pg_temp.check(
  pg_temp.opening('monthly', null, null, 1, null, '10:00', null, '2027-05-01') = 'unknown',
  'monthly without months_ahead');
select pg_temp.check(
  pg_temp.opening('rolling', 60, 'day', null, null, '10:00', null, null) = 'unknown',
  'no month');

-- ── 2. Open yet? Judged in the restaurant's timezone ───────────────────

-- 10:00 Paris on 1 March 2027 is 09:00 UTC (CET).
select pg_temp.check(public.booking_window_status('2027-03-01', '10:00', 'Europe/Paris',
  '2027-03-01 08:59:59+00') = 'upcoming', 'status: a second before');
select pg_temp.check(public.booking_window_status('2027-03-01', '10:00', 'Europe/Paris',
  '2027-03-01 09:00:00+00') = 'open', 'status: on the minute');
select pg_temp.check(public.booking_window_status('2026-12-01', '10:00', 'Europe/Paris',
  '2027-03-01 09:00:00+00') = 'open', 'status: month already open');
-- No time: that whole local day is "opens today".
select pg_temp.check(public.booking_window_status('2027-03-01', null, 'Europe/Paris',
  '2027-02-28 23:30:00+00') = 'opens_today', 'status, no time: just after local midnight');
select pg_temp.check(public.booking_window_status('2027-03-01', null, 'Europe/Paris',
  '2027-02-28 22:30:00+00') = 'upcoming', 'status, no time: the evening before');
select pg_temp.check(public.booking_window_status('2027-03-01', null, 'Europe/Paris',
  '2027-03-01 23:30:00+00') = 'open', 'status, no time: the next local day');
select pg_temp.check(public.booking_window_status(null, null, 'Europe/Paris',
  '2027-03-01 09:00:00+00') is null, 'status: unknown');
-- Tokyo midnight is the previous afternoon in UTC.
select pg_temp.check(public.booking_window_status('2027-03-02', '00:00', 'Asia/Tokyo',
  '2027-03-01 15:00:00+00') = 'open', 'status: Tokyo midnight');
select pg_temp.check(public.booking_window_status('2027-03-02', '00:00', 'Asia/Tokyo',
  '2027-03-01 14:59:00+00') = 'upcoming', 'status: just before Tokyo midnight');

-- ── 3. When the reminder is due: 10:00 member time, the day before ─────

-- Paris 10:00 on 1 March; member in Amsterdam: 28 February, 10:00 CET = 09:00 UTC.
select pg_temp.check(public.booking_reminder_due('2027-03-01', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-02-28 09:00:00+00'), 'due: 10:00 the day before');
select pg_temp.check(not public.booking_reminder_due('2027-03-01', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-02-28 08:59:00+00'), 'not due: 09:59 the day before');
select pg_temp.check(public.booking_reminder_due('2027-03-01', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-02-28 22:59:00+00'), 'due: 23:59 the day before (a late run)');
select pg_temp.check(not public.booking_reminder_due('2027-03-01', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-03-01 06:00:00+00'), 'not due: on the day itself');
select pg_temp.check(not public.booking_reminder_due('2027-03-01', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-02-27 09:00:00+00'), 'not due: two days before');

-- Tokyo midnight on 2 March is 16:00 on 1 March in Amsterdam: the member's
-- "tomorrow" is 1 March, so the reminder is 28 February.
select pg_temp.check(public.booking_reminder_due('2027-03-02', '00:00', 'Asia/Tokyo',
  'Europe/Amsterdam', '2027-02-28 09:00:00+00'), 'due: Tokyo opening, Amsterdam member');
select pg_temp.check(not public.booking_reminder_due('2027-03-02', '00:00', 'Asia/Tokyo',
  'Europe/Amsterdam', '2027-03-01 09:00:00+00'), 'not due: Tokyo opening, member''s same day');

-- New York midnight on 1 March is 06:00 on 1 March in Amsterdam.
select pg_temp.check(public.booking_reminder_due('2027-03-01', '00:00', 'America/New_York',
  'Europe/Amsterdam', '2027-02-28 09:00:00+00'), 'due: New York opening, Amsterdam member');
-- Same opening, member in New York: 10:00 EST on 28 February = 15:00 UTC.
select pg_temp.check(not public.booking_reminder_due('2027-03-01', '00:00', 'America/New_York',
  'America/New_York', '2027-02-28 14:59:00+00'), 'not due: New York member, 09:59');
select pg_temp.check(public.booking_reminder_due('2027-03-01', '00:00', 'America/New_York',
  'America/New_York', '2027-02-28 15:00:00+00'), 'due: New York member, 10:00');

-- Summer time starts in Europe on 28 March 2027: 10:00 that day is CEST,
-- 08:00 UTC, an hour earlier in UTC than the day before.
select pg_temp.check(public.booking_reminder_due('2027-03-29', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-03-28 08:00:00+00'), 'due: on the day summer time starts');
select pg_temp.check(not public.booking_reminder_due('2027-03-29', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-03-28 07:59:00+00'), 'not due: 09:59 CEST');
-- Winter time returns on 31 October 2027: 10:00 is 09:00 UTC again.
select pg_temp.check(not public.booking_reminder_due('2027-11-01', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-10-31 08:59:00+00'), 'not due: 09:59 CET after winter time');
select pg_temp.check(public.booking_reminder_due('2027-11-01', '10:00', 'Europe/Paris',
  'Europe/Amsterdam', '2027-10-31 09:00:00+00'), 'due: 10:00 CET after winter time');
-- An opening inside the hour summer time skips (02:30 on 28 March 2027)
-- is read as 03:30 CEST, still on the 28th.
select pg_temp.check(public.booking_window_status('2027-03-28', '02:30', 'Europe/Paris',
  '2027-03-28 01:30:00+00') = 'open', 'status: opening inside the skipped hour');

-- No known time: the restaurant's own date.
select pg_temp.check(public.booking_reminder_due('2027-03-01', null, 'Asia/Tokyo',
  'Europe/Amsterdam', '2027-02-28 09:00:00+00'), 'due: no time, restaurant date');
select pg_temp.check(not public.booking_reminder_due(null, null, 'Asia/Tokyo',
  'Europe/Amsterdam', '2027-02-28 09:00:00+00'), 'not due: unknown opening');

-- ── 4. End to end: plans, privacy, the manager, the job, the readers ───

do $$
declare
  v_member uuid := gen_random_uuid();
  v_friend uuid := gen_random_uuid();
  v_manager uuid := gen_random_uuid();
  v_claim uuid := gen_random_uuid();
  v_city uuid;
  v_paris uuid;
  v_tokyo uuid;
  v_sent integer;
  v_row record;
  v_failed boolean;
begin
  insert into auth.users (id, email, raw_user_meta_data)
  values (v_member, 'member@bw.test', '{"username":"bw_member"}'),
         (v_friend, 'friend@bw.test', '{"username":"bw_friend"}'),
         (v_manager, 'manager@bw.test', '{"username":"bw_manager"}');
  update public.profiles set home_country_code = 'NL' where id = v_member;

  insert into public.friendships (requester_id, addressee_id, status)
  values (v_member, v_friend, 'accepted');

  select id into v_city from public.cities limit 1;
  insert into public.restaurants (restaurant_code, name, city_id, country_code, address, location)
  values ('BW-PARIS', 'Test Paris', v_city, 'FR', 'x', 'POINT(2.35 48.85)')
  returning id into v_paris;
  insert into public.restaurants (restaurant_code, name, city_id, country_code, address, location)
  values ('BW-TOKYO', 'Test Tokyo', v_city, 'JP', 'x', 'POINT(139.7 35.7)')
  returning id into v_tokyo;
  insert into public.claims_restaurants (id, user_id, restaurant_id, status, role, business_email, phone)
  values (v_claim, v_manager, v_paris, 'approved', 'owner', 'manager@bw.test', '+33 1 00 00 00 00');
  insert into public.venue_managers_restaurants (user_id, restaurant_id, claim_id)
  values (v_manager, v_paris, v_claim);

  -- The member saves both and plans March 2027.
  perform set_config('request.jwt.claims', json_build_object('sub', v_member, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.wishlist (user_id, entity_type, entity_id) values (v_member, 'restaurant', v_paris);
  insert into public.wishlist (user_id, entity_type, entity_id) values (v_member, 'restaurant', v_tokyo);
  perform public.set_wishlist_planned_month(v_paris, '2027-03-14');
  perform public.set_wishlist_planned_month(v_tokyo, '2027-03-01');

  -- Planned, no window known yet: status unknown (NULL).
  select * into v_row from public.get_my_wishlist_plans() where restaurant_id = v_paris;
  perform pg_temp.check(v_row.planned_month = '2027-03-01', 'plan stored as the 1st');
  perform pg_temp.check(v_row.status is null and v_row.opens_on is null, 'plan without a window is unknown');
  perform pg_temp.check(v_row.reminders_enabled, 'reminders enabled for everyone today');

  -- A past month and a month past three years are refused.
  begin
    perform public.set_wishlist_planned_month(v_paris, '2020-01-01');
    v_failed := false;
  exception when others then v_failed := true; end;
  perform pg_temp.check(v_failed, 'past month refused');

  -- Not on the wishlist: refused.
  begin
    perform public.set_wishlist_planned_month(gen_random_uuid(), '2027-03-01');
    v_failed := false;
  exception when others then v_failed := true; end;
  perform pg_temp.check(v_failed, 'month for a restaurant not on the wishlist refused');

  -- The member cannot write a window: not a manager.
  begin
    perform public.set_restaurant_booking_window(v_paris, '{"kind":"rolling","rolling_amount":60,"rolling_unit":"day"}');
    v_failed := false;
  exception when others then v_failed := true; end;
  perform pg_temp.check(v_failed, 'non-manager cannot set a window');

  -- Nor touch the table directly.
  begin
    insert into public.restaurant_booking_windows (restaurant_id, kind, timezone, source_kind, verified_on)
    values (v_paris, 'unknown', 'Europe/Paris', 'venue', current_date);
    v_failed := false;
  exception when others then v_failed := true; end;
  perform pg_temp.check(v_failed, 'no direct insert into booking windows');
  reset role;

  -- The friend sees the wishlist row but not the month.
  perform set_config('request.jwt.claims', json_build_object('sub', v_friend, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform pg_temp.check(
    (select count(*) from public.wishlist where user_id = v_member) = 2,
    'friend still reads the wishlist');
  begin
    perform planned_month from public.wishlist where user_id = v_member;
    v_failed := false;
  exception when insufficient_privilege then v_failed := true; end;
  perform pg_temp.check(v_failed, 'friend cannot read the month');
  perform pg_temp.check(
    (select count(*) from public.get_my_wishlist_plans()) = 0,
    'friend''s own plans do not include the member''s');
  reset role;

  -- The manager sets a monthly window: on the 1st at 10:00, two months ahead.
  perform set_config('request.jwt.claims', json_build_object('sub', v_manager, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.set_restaurant_booking_window(v_paris,
    '{"kind":"monthly","release_day":1,"months_ahead":2,"release_time":"10:00","platform":"own_site"}');
  -- A wrong timezone for the country is refused.
  begin
    perform public.set_restaurant_booking_window(v_paris,
      '{"kind":"rolling","rolling_amount":30,"rolling_unit":"day","timezone":"Asia/Tokyo"}');
    v_failed := false;
  exception when others then v_failed := true; end;
  perform pg_temp.check(v_failed, 'timezone outside the country refused');
  reset role;

  select * into v_row from public.restaurant_booking_windows where restaurant_id = v_paris;
  perform pg_temp.check(v_row.timezone = 'Europe/Paris' and v_row.source_kind = 'venue'
    and v_row.updated_by = v_manager and v_row.verified_on = current_date,
    'manager window stored with timezone, source and who');

  -- Tokyo: research says rolling 30 days, time not known.
  insert into public.restaurant_booking_windows (restaurant_id, kind, timezone, rolling_amount,
    rolling_unit, source_kind, source_url, verified_on)
  values (v_tokyo, 'rolling', 'Asia/Tokyo', 30, 'day', 'research', 'https://example.test', current_date);

  -- March 2027 at Paris opens 1 January 2027 10:00 Paris; Tokyo on 30
  -- January 2027, time unknown.
  perform set_config('request.jwt.claims', json_build_object('sub', v_member, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select * into v_row from public.get_my_wishlist_plans() where restaurant_id = v_paris;
  perform pg_temp.check(v_row.opens_on = '2027-01-01' and v_row.opens_time = '10:00'
    and v_row.timezone = 'Europe/Paris' and v_row.status = 'upcoming', 'member sees when March opens');
  reset role;

  -- The job: nothing two days before.
  v_sent := public.send_booking_window_reminders('2026-12-30 12:00+00');
  perform pg_temp.check(v_sent = 0, 'job: nothing two days early');
  -- 31 December 10:00 Amsterdam = 09:00 UTC: Paris is due.
  v_sent := public.send_booking_window_reminders('2026-12-31 09:05+00');
  perform pg_temp.check(v_sent = 1, 'job: Paris reminder sent');
  -- Again an hour later: nothing new.
  v_sent := public.send_booking_window_reminders('2026-12-31 10:05+00');
  perform pg_temp.check(v_sent = 0, 'job: never twice');
  -- Tokyo, no time: the restaurant's date, 30 January; reminder 29 January.
  v_sent := public.send_booking_window_reminders('2027-01-29 09:05+00');
  perform pg_temp.check(v_sent = 1, 'job: Tokyo reminder without a time');

  -- Feature off for the member (later: not Pro): nothing.
  update public.wishlist set planned_month = '2027-04-01' where user_id = v_member and entity_id = v_paris;
  create or replace function public.booking_reminders_enabled(p_user_id uuid)
  returns boolean language sql stable security definer set search_path = public, pg_temp
  as 'select false';
  v_sent := public.send_booking_window_reminders('2027-01-31 09:05+00');
  perform pg_temp.check(v_sent = 0, 'job: switched off, no reminder');

  -- Readers: v6 carries the reminder, v5 and the old counts do not.
  perform set_config('request.jwt.claims', json_build_object('sub', v_member, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select * into v_row from public.get_notifications_v6()
   where type = 'booking_window_opening' and booking_restaurant_name = 'Test Paris';
  perform pg_temp.check(v_row.booking_planned_month = '2027-03-01'
    and v_row.booking_opens_on = '2027-01-01' and v_row.booking_opens_time = '10:00'
    and v_row.booking_timezone = 'Europe/Paris', 'v6 carries the reminder');
  perform pg_temp.check(
    (select count(*) from public.get_notifications_v5() where type = 'booking_window_opening') = 0,
    'v5 hides the reminder');
  perform pg_temp.check(public.get_unread_notification_count_v6() = 2, 'v6 count includes it');
  perform pg_temp.check(public.get_unread_notification_count_v5() = 0, 'v5 count leaves it out');
  perform pg_temp.check(public.get_unread_notification_count_v4() = 0, 'v4 count leaves it out');
  perform pg_temp.check(public.get_unread_notification_count() = 0, 'v1 count leaves it out');
  perform pg_temp.check((select count(*) from public.booking_reminders) = 2, 'member reads own reminders');
  reset role;

  perform set_config('request.jwt.claims', json_build_object('sub', v_friend, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform pg_temp.check((select count(*) from public.booking_reminders) = 0, 'friend reads no reminders');
  reset role;

  -- Manager removes the window.
  perform set_config('request.jwt.claims', json_build_object('sub', v_manager, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.set_restaurant_booking_window(v_paris, null);
  reset role;
  perform pg_temp.check(not exists (select 1 from public.restaurant_booking_windows where restaurant_id = v_paris),
    'manager removes the window');
end;
$$;

select 'booking window tests: all passed' as result;

rollback;
