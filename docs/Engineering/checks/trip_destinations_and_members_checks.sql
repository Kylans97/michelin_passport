-- Checks for supabase/migrations/20261021120000_add_trip_destinations_and_members.sql.
-- Run against a LOCAL stack only (it creates auth users and rows), never
-- production: supabase start on a scratch copy of supabase/, then
--   psql <local DB_URL> -q -f this-file 2>&1 | grep -E 'PASS|FAIL'
-- 2026-10-28: 44/44 PASS on a fresh replay of all 103 migrations.

-- Local-stack tests for 20261021120000. Each check prints PASS/FAIL.
\set ON_ERROR_STOP off
\pset pager off
set client_min_messages = warning;

create or replace function pg_temp.ok(label text, cond boolean) returns void
language plpgsql as $$ begin
  raise warning '% %', case when cond then 'PASS' else 'FAIL' end, label;
end $$;

-- Runs sql as user uid; returns null on success or the error message.
create or replace function pg_temp.as_user(uid uuid, sql text) returns text
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  -- Fire deferred constraint triggers here, inside the handler.
  execute 'set constraints all immediate';
  execute sql;
  execute 'set constraints all deferred';
  execute 'reset role';
  return 'OK';
exception when others then
  execute 'reset role';
  execute 'set constraints all deferred';
  return sqlerrm;
end $$;

create or replace function pg_temp.count_as(uid uuid, sql text) returns bigint
language plpgsql as $$
declare n bigint;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute 'select count(*) from (' || sql || ') q' into n;
  execute 'reset role';
  return n;
end $$;

-- ---------- fixtures ----------
insert into auth.users (id, raw_user_meta_data, email) values
 ('00000000-0000-0000-0000-00000000000a', '{"username":"qa_a"}', 'a@test.test'),
 ('00000000-0000-0000-0000-00000000000b', '{"username":"qa_b"}', 'b@test.test'),
 ('00000000-0000-0000-0000-00000000000c', '{"username":"qa_c"}', 'c@test.test'),
 ('00000000-0000-0000-0000-00000000000d', '{"username":"qa_d"}', 'd@test.test'),
 ('00000000-0000-0000-0000-00000000000e', '{"username":"qa_e"}', 'e@test.test');

insert into public.friendships (requester_id, addressee_id, status, responded_at) values
 ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000b','accepted',now()),
 ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000c','accepted',now()),
 ('00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-00000000000d','accepted',now()),
 ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000e','accepted',now());

\set A '''00000000-0000-0000-0000-00000000000a'''
\set B '''00000000-0000-0000-0000-00000000000b'''
\set C '''00000000-0000-0000-0000-00000000000c'''
\set D '''00000000-0000-0000-0000-00000000000d'''
\set E '''00000000-0000-0000-0000-00000000000e'''

select (select id from public.cities where country_code = 'FR' order by name limit 1) as fr_city \gset
select (select id from public.cities where country_code = 'IT' order by name limit 1) as it_city \gset
select pg_temp.ok('fixtures: a FR and an IT city exist', :'fr_city' <> '' and :'it_city' <> '');

-- ---------- 1. trips and destinations ----------
select pg_temp.as_user(:A, $q$insert into public.planned_trips (id, user_id, title, start_date, end_date, country_code)
  values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'Future', '2099-12-01', '2099-12-10', 'FR')$q$) = 'OK' as r \gset
select pg_temp.ok('owner creates a trip (installed-build insert)', :'r'::boolean);
select pg_temp.ok('default whole-country destination created',
  (select count(*) = 1 and bool_and(country_code = 'FR' and city_id is null and position = 0)
     from public.planned_trip_destinations where trip_id = '10000000-0000-0000-0000-000000000001'));

select pg_temp.as_user(:A, format($q$select public.save_trip_destinations('10000000-0000-0000-0000-000000000001', '2099-12-01', '2099-12-10',
  '[{"country_code":"FR","city_id":"%s","start_date":"2099-12-01","end_date":"2099-12-05"},{"country_code":"IT"}]')$q$, :'fr_city')) as r \gset
select pg_temp.ok('multi-leg without leg dates is refused: ' || :'r', :'r' like '%needs its dates%');

select pg_temp.as_user(:A, format($q$select public.save_trip_destinations('10000000-0000-0000-0000-000000000001', '2099-12-01', '2099-12-10',
  '[{"country_code":"IT","city_id":"%s"}]')$q$, :'fr_city')) as r \gset
select pg_temp.ok('a city from another country is refused: ' || :'r', :'r' like '%not in that country%');

select pg_temp.as_user(:A, format($q$select public.save_trip_destinations('10000000-0000-0000-0000-000000000001', '2099-12-01', '2099-12-10',
  '[{"country_code":"FR","city_id":"%s","start_date":"2099-12-01","end_date":"2099-12-05"},{"country_code":"IT","start_date":"2099-12-05","end_date":"2099-12-12"}]')$q$, :'fr_city')) as r \gset
select pg_temp.ok('a leg outside the trip is refused: ' || :'r', :'r' like '%within the trip%');

select pg_temp.as_user(:A, format($q$select public.save_trip_destinations('10000000-0000-0000-0000-000000000001', '2099-11-30', '2099-12-12',
  '[{"country_code":"FR","city_id":"%s","start_date":"2099-11-30","end_date":"2099-12-05"},{"country_code":"IT","start_date":"2099-12-05","end_date":"2099-12-12"}]')$q$, :'fr_city')) as r \gset
select pg_temp.ok('trip dates and legs change together in one call: ' || coalesce(:'r', ''), :'r' = 'OK');
select pg_temp.ok('two legs saved in order',
  (select string_agg(country_code, ',' order by position) = 'FR,IT' from public.planned_trip_destinations where trip_id = '10000000-0000-0000-0000-000000000001'));
select pg_temp.ok('planned_trips mirrors the first destination (country + city text)',
  (select t.country_code = 'FR' and t.city = c.name and t.start_date = '2099-11-30'
     from public.planned_trips t, public.cities c
    where t.id = '10000000-0000-0000-0000-000000000001' and c.id = :'fr_city'::uuid));

select pg_temp.as_user(:B, $q$select public.save_trip_destinations('10000000-0000-0000-0000-000000000001', '2099-11-30', '2099-12-12', '[{"country_code":"FR"}]')$q$) as r \gset
select pg_temp.ok('a non-owner can''t save destinations: ' || :'r', :'r' like '%owner%');

select pg_temp.as_user(:A, $q$update public.planned_trips set start_date = '2099-12-03' where id = '10000000-0000-0000-0000-000000000001'$q$) as r \gset
select pg_temp.ok('installed build narrowing dates past a leg is refused: ' || :'r', :'r' like '%within the trip%');

-- Installed build changes the country: first leg follows, city dropped.
select pg_temp.as_user(:A, $q$insert into public.planned_trips (id, user_id, title, start_date, end_date, country_code)
  values ('10000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-00000000000a', 'Old build', '2099-06-01', '2099-06-03', 'FR')$q$) as r \gset
select pg_temp.as_user(:A, $q$update public.planned_trips set country_code = 'IT' where id = '10000000-0000-0000-0000-000000000009'$q$) as r \gset
select pg_temp.ok('installed-build country change moves the first destination',
  (select country_code = 'IT' and city_id is null from public.planned_trip_destinations
    where trip_id = '10000000-0000-0000-0000-000000000009' and position = 0));

select pg_temp.as_user(:A, $q$insert into public.planned_trip_destinations (trip_id, position, country_code) values ('10000000-0000-0000-0000-000000000001', 5, 'FR')$q$) as r \gset
select pg_temp.ok('clients can''t write destinations directly: ' || :'r', :'r' <> 'OK');

-- ---------- 2. invitations ----------
select pg_temp.as_user(:A, $q$select public.invite_to_trip('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d')$q$) as r \gset
select pg_temp.ok('owner can''t invite a non-friend: ' || :'r', :'r' like '%friends%');

select pg_temp.as_user(:A, $q$select public.invite_to_trip('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b')$q$) as r \gset
select pg_temp.ok('owner invites a friend: ' || coalesce(:'r', ''), :'r' = 'OK');
select pg_temp.as_user(:A, $q$select public.invite_to_trip('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b')$q$) as r \gset
select pg_temp.ok('a second invite to the same person is refused', :'r' like '%already%');

select pg_temp.as_user(:B, $q$select public.invite_to_trip('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d')$q$) as r \gset
select pg_temp.ok('a pending invitee can''t invite yet: ' || :'r', :'r' like '%on this trip%');

select pg_temp.ok('pending invitee sees the trip and its destinations',
  pg_temp.count_as(:B, $q$select 1 from public.planned_trips where id = '10000000-0000-0000-0000-000000000001'$q$) = 1
  and pg_temp.count_as(:B, $q$select 1 from public.planned_trip_destinations where trip_id = '10000000-0000-0000-0000-000000000001'$q$) = 2);
select pg_temp.ok('a friend who wasn''t invited sees nothing',
  pg_temp.count_as(:C, $q$select 1 from public.planned_trips where id = '10000000-0000-0000-0000-000000000001'$q$) = 0);

select pg_temp.ok('invitee gets trip_invite_received in v3, not in v2/v1',
  pg_temp.count_as(:B, $q$select 1 from public.get_notifications_v3() where type = 'trip_invite_received' and trip_title = 'Future' and other_username = 'qa_a'$q$) = 1
  and pg_temp.count_as(:B, $q$select 1 from public.get_notifications_v2() where type like 'trip_%'$q$) = 0
  and pg_temp.count_as(:B, $q$select 1 from public.get_notifications() where type like 'trip_%'$q$) = 0);
select pg_temp.ok('unread counts: v3 counts it, v2 and v1 don''t',
  (select pg_temp.as_user(:B, 'select 1') = 'OK')
  and pg_temp.count_as(:B, $q$select 1 where public.get_unread_notification_count_v3() = 1$q$) = 1
  and pg_temp.count_as(:B, $q$select 1 where public.get_unread_notification_count_v2() = 0$q$) = 1
  and pg_temp.count_as(:B, $q$select 1 where public.get_unread_notification_count() = 0$q$) = 1);

select pg_temp.as_user(:B, $q$select public.respond_to_trip_invite((select id from public.planned_trip_members where user_id = '00000000-0000-0000-0000-00000000000b'), true)$q$) as r \gset
select pg_temp.ok('invitee accepts: ' || coalesce(:'r', ''), :'r' = 'OK');
select pg_temp.ok('inviter is told (trip_invite_accepted)',
  pg_temp.count_as(:A, $q$select 1 from public.get_notifications_v3() where type = 'trip_invite_accepted' and other_username = 'qa_b'$q$) = 1);

select pg_temp.as_user(:B, $q$select public.invite_to_trip('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d')$q$) as r \gset
select pg_temp.ok('an accepted member invites their own friend (decision 4): ' || coalesce(:'r', ''), :'r' = 'OK');
select pg_temp.as_user(:B, $q$select public.invite_to_trip('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000e')$q$) as r \gset
select pg_temp.ok('a member can''t invite someone who is only the owner''s friend', :'r' like '%friends%');

select pg_temp.ok('get_trip_members lists owner + B + pending D for a member',
  pg_temp.count_as(:B, $q$select 1 from public.get_trip_members('10000000-0000-0000-0000-000000000001')$q$) = 3);
select pg_temp.ok('get_trip_members is empty for an outsider',
  pg_temp.count_as(:C, $q$select 1 from public.get_trip_members('10000000-0000-0000-0000-000000000001')$q$) = 0);

-- ---------- 3. plans on a shared trip ----------
select pg_temp.as_user(:B, $q$insert into public.planned_venues (id, user_id, entity_type, entity_id, trip_id, start_date)
  values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'restaurant', gen_random_uuid(), '10000000-0000-0000-0000-000000000001', '2099-12-02')$q$) as r \gset
select pg_temp.ok('a member adds a plan to the shared trip: ' || coalesce(:'r', ''), :'r' = 'OK');
select pg_temp.ok('the owner sees the member''s plan',
  pg_temp.count_as(:A, $q$select 1 from public.planned_venues where id = '20000000-0000-0000-0000-000000000001'$q$) = 1);
select pg_temp.ok('the pending invitee does not see plans',
  pg_temp.count_as(:D, $q$select 1 from public.planned_venues where trip_id = '10000000-0000-0000-0000-000000000001'$q$) = 0);
select pg_temp.as_user(:C, $q$insert into public.planned_venues (user_id, entity_type, entity_id, trip_id, start_date)
  values ('00000000-0000-0000-0000-00000000000c', 'restaurant', gen_random_uuid(), '10000000-0000-0000-0000-000000000001', '2099-12-02')$q$) as r \gset
select pg_temp.ok('an outsider can''t attach a plan to the trip: ' || :'r', :'r' <> 'OK');
select pg_temp.as_user(:A, $q$update public.planned_venues set notes = 'x' where id = '20000000-0000-0000-0000-000000000001'$q$) as r \gset
select pg_temp.ok('the owner can''t edit a member''s plan',
  (select notes is null from public.planned_venues where id = '20000000-0000-0000-0000-000000000001'));

-- ---------- 4. removing ----------
select pg_temp.as_user(:B, $q$select public.remove_trip_member((select id from public.planned_trip_members where user_id = '00000000-0000-0000-0000-00000000000d'))$q$) as r \gset
select pg_temp.ok('an inviter withdraws their pending invite: ' || coalesce(:'r', ''), :'r' = 'OK'
  and not exists (select 1 from public.planned_trip_members where user_id = '00000000-0000-0000-0000-00000000000d')
  and not exists (select 1 from public.notifications where recipient_id = '00000000-0000-0000-0000-00000000000d' and type like 'trip_%'));

select pg_temp.as_user(:A, $q$select public.leave_trip('10000000-0000-0000-0000-000000000001')$q$) as r \gset
select pg_temp.ok('the owner can''t leave their own trip', :'r' like '%not on this trip%');

-- ---------- 5. unfriending (decision 5) ----------
-- A past trip owned by A with B on it.
insert into public.planned_trips (id, user_id, title, start_date, end_date, country_code)
values ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a', 'Past', '2020-01-01', '2020-01-05', 'FR');
insert into public.planned_trip_members (trip_id, user_id, invited_by, status)
values ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a', 'accepted');

select pg_temp.as_user(:A, $q$delete from public.friendships where requester_id = '00000000-0000-0000-0000-00000000000a' and addressee_id = '00000000-0000-0000-0000-00000000000b'$q$) as r \gset
select pg_temp.ok('A unfriends B: ' || coalesce(:'r', ''), :'r' = 'OK');
select pg_temp.ok('B is off A''s future trip',
  not exists (select 1 from public.planned_trip_members where trip_id = '10000000-0000-0000-0000-000000000001' and user_id = '00000000-0000-0000-0000-00000000000b'));
select pg_temp.ok('B stays on A''s past trip',
  exists (select 1 from public.planned_trip_members where trip_id = '10000000-0000-0000-0000-000000000002' and user_id = '00000000-0000-0000-0000-00000000000b'));
select pg_temp.ok('B''s plan is kept, detached from the trip',
  (select trip_id is null from public.planned_venues where id = '20000000-0000-0000-0000-000000000001'));

-- Blocking via block_user() removes too.
select pg_temp.as_user(:A, $q$select public.invite_to_trip('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000e')$q$) as r \gset
select pg_temp.as_user(:A, $q$select public.block_user('00000000-0000-0000-0000-00000000000e')$q$) as r \gset
select pg_temp.ok('blocking removes from future trips: ' || coalesce(:'r', 'ok'),
  :'r' = 'OK' and not exists (select 1 from public.planned_trip_members where user_id = '00000000-0000-0000-0000-00000000000e'));

-- ---------- 6. anon and grants ----------
select pg_temp.ok('anon can execute none of the new functions',
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('is_trip_member','can_view_trip','check_trip_leg_dates','add_default_trip_destination',
         'sync_first_trip_destination','save_trip_destinations','get_notifications_v3','get_unread_notification_count_v3',
         'detach_member_plans','delete_trip_membership','invite_to_trip','respond_to_trip_invite','leave_trip',
         'remove_trip_member','get_trip_members','remove_from_future_trips_on_unfriend')
       and has_function_privilege('anon', p.oid, 'EXECUTE')));
select pg_temp.ok('internal helpers are not callable by authenticated',
  not has_function_privilege('authenticated', 'public.delete_trip_membership(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.detach_member_plans(uuid, uuid)', 'EXECUTE'));
select pg_temp.ok('anon has no privileges on the new tables',
  not has_table_privilege('anon', 'public.planned_trip_destinations', 'SELECT')
  and not has_table_privilege('anon', 'public.planned_trip_members', 'SELECT'));
select pg_temp.ok('RLS on both new tables',
  (select bool_and(relrowsecurity) from pg_class where relname in ('planned_trip_destinations','planned_trip_members')));

-- ---------- 7. owner deletes the trip ----------
select pg_temp.as_user(:A, $q$delete from public.planned_trips where id = '10000000-0000-0000-0000-000000000001'$q$) as r \gset
select pg_temp.ok('deleting a trip cascades destinations and members',
  not exists (select 1 from public.planned_trip_destinations where trip_id = '10000000-0000-0000-0000-000000000001')
  and not exists (select 1 from public.planned_trip_members where trip_id = '10000000-0000-0000-0000-000000000001'));
