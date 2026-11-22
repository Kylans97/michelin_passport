-- Behaviour test for 20261101670000_add_invite_links.sql. Run against a
-- scratch local stack (never production): psql -f this file. Everything
-- happens in one transaction that is rolled back. Every check prints
-- 'ok: ...' or raises 'FAIL: ...'. Last run 2026-11-22: all ok.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email, instance_id, aud, role)
values ('00000000-0000-0000-0000-00000000000a', 'a@test.local', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'),
       ('00000000-0000-0000-0000-00000000000b', 'b@test.local', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'),
       ('00000000-0000-0000-0000-00000000000c', 'c@test.local', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'),
       ('00000000-0000-0000-0000-00000000000d', 'd@test.local', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated');
update profiles set username = 'elise', display_name = 'Elise Laurent' where id = '00000000-0000-0000-0000-00000000000a';
update profiles set username = 'julien', display_name = 'Julien Martens' where id = '00000000-0000-0000-0000-00000000000b';
update profiles set username = 'anna', display_name = 'Anna Verbeek' where id = '00000000-0000-0000-0000-00000000000c';
update profiles set username = 'sam', display_name = 'Sam Peeters' where id = '00000000-0000-0000-0000-00000000000d';

insert into restaurants (id, restaurant_code, name, city_id, country_code, address, location, michelin_stars)
select '00000000-0000-0000-0000-0000000000f1', 'TEST-HVC', 'Hof van Cleve', id, country_code, 'Riemegemstraat 1',
       'POINT(3.5 50.9)'::geography, 3
from cities where country_code = 'BE' limit 1;

create temp table t (k text primary key, v text);
grant all on t to authenticated, anon;

-- A: a visit, a one-person visit link
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
insert into visits (user_id, entity_type, entity_id, visited_on)
values (auth.uid(), 'restaurant', '00000000-0000-0000-0000-0000000000f1', date '2026-11-14')
returning id \gset
insert into t select 'visit', :'id';
insert into t select 'tok1', token from create_invite_link('visit', (select v::uuid from t where k='visit'));
insert into t select 'code1', code from invite_links limit 1;
select 'A link', token, code, expires_at::date from invite_links;

-- A cannot share someone else's visit, B cannot see A's link
do $$ begin
  perform create_invite_link('visit', gen_random_uuid());
  raise exception 'FAIL: shared a visit that is not mine';
exception when insufficient_privilege then raise notice 'ok: foreign visit refused';
end $$;

-- anon: preview by token
reset role;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select 'anon preview', state, kind, sender_name, venue_name, venue_city, michelin_stars, visited_on, code
  from get_invite_link_preview((select v from t where k='tok1'));
select 'anon unknown', state, sender_name from get_invite_link_preview('nope-nope-nope-nope-nope');
do $$ begin
  perform redeem_invite_link('x');
  raise exception 'FAIL: anon could redeem';
exception when insufficient_privilege then raise notice 'ok: anon cannot redeem';
end $$;

-- B redeems with the code typed sloppily
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select 'B preview by code', token = (select v from t where k='tok1'), state
  from get_invite_link_preview_by_code(lower(substr((select v from t where k='code1'),1,4)) || ' ' || substr((select v from t where k='code1'),5));
select 'B redeem', redeem_invite_link((select v from t where k='tok1'));
select 'B friends', status from friendships;
select 'B copy', visited_on, stars_at_visit, shared_from_visit_id = (select v::uuid from t where k='visit')
  from visits where user_id = auth.uid();
-- B may not move the date, nor unlink, nor fake a link
do $$ begin
  update visits set visited_on = date '2026-11-10' where user_id = auth.uid();
  raise exception 'FAIL: copy date changed by recipient';
exception when insufficient_privilege then raise notice 'ok: copy date locked';
end $$;
do $$ begin
  update visits set shared_from_visit_id = null where user_id = auth.uid();
  raise exception 'FAIL: copy unlinked by recipient';
exception when insufficient_privilege then raise notice 'ok: link locked';
end $$;
update visits set notes = 'Mine' where user_id = auth.uid();
select 'B again', state from get_invite_link_preview((select v from t where k='tok1'));
do $$ begin
  perform redeem_invite_link((select v from t where k='tok1'));
  raise exception 'FAIL: redeemed twice';
exception when unique_violation then raise notice 'ok: second use by same person refused';
end $$;

-- C: link is used up
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select 'C preview', state, sender_name from get_invite_link_preview((select v from t where k='tok1'));
do $$ begin
  perform redeem_invite_link((select v from t where k='tok1'));
  raise exception 'FAIL: used-up link redeemed';
exception when invalid_parameter_value then raise notice 'ok: used up -> %', sqlerrm;
end $$;

-- A moves the date: the copy follows
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
update visits set visited_on = date '2026-11-13' where user_id = auth.uid();
reset role;
select 'copy after move', visited_on from visits where user_id = '00000000-0000-0000-0000-00000000000b';
select 'notifications to A', type, subject_type from notifications where recipient_id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
select 'A v7', type, other_display_name, link_kind, link_venue_name, link_visited_on, link_redemption_status from get_notifications_v7() where type like 'invite_link%';
select 'A v6 count of invite rows', count(*) from get_notifications_v6() where type like 'invite_link%';
select 'A v5 count of invite rows', count(*) from get_notifications_v5() where type like 'invite_link%';
select 'A unread v7/v6/v1', get_unread_notification_count_v7(), get_unread_notification_count_v6(), get_unread_notification_count();
select 'A my links', kind, max_uses, use_count, venue_name, last_used_by_name from get_my_invite_links();

-- Group trip link: A's trip, up to 3
insert into planned_trips (user_id, title, start_date, end_date, country_code)
values (auth.uid(), 'Piemonte in May', date '2027-05-08', date '2027-05-12', 'IT')
returning id \gset trip_
insert into t values ('trip', :'trip_id');
insert into t select 'tok2', token from create_invite_link('trip', null, (select v::uuid from t where k='trip'), 3::smallint);

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select 'C trip preview', state, kind, is_group, needs_approval, trip_title, trip_start_date from get_invite_link_preview((select v from t where k='tok2'));
select 'C redeem trip', redeem_invite_link((select v from t where k='tok2'));
reset role;
select 'members before approval', count(*) from planned_trip_members;
set local role authenticated;

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}';
select 'D redeem trip', redeem_invite_link((select v from t where k='tok2'));
do $$ begin
  perform decide_invite_link_join((select id from invite_link_redemptions where redeemed_by = auth.uid()), true);
  raise exception 'FAIL: recipient approved themselves';
exception when insufficient_privilege then raise notice 'ok: only sender or owner decides';
end $$;

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select 'A join requests', type, other_display_name, link_trip_title, link_redemption_status from get_notifications_v7() where type = 'invite_link_join_request';
select 'A redemptions', display_name, status from get_invite_link_redemptions((select id from invite_links where kind='trip'));
select decide_invite_link_join(r.id, true) from invite_link_redemptions r where r.redeemed_by = '00000000-0000-0000-0000-00000000000c';
select decide_invite_link_join(r.id, false) from invite_link_redemptions r where r.redeemed_by = '00000000-0000-0000-0000-00000000000d';
reset role;
select 'members after', user_id, status from planned_trip_members;
select 'C/D notified', recipient_id, type from notifications where type in ('invite_link_join_approved', 'invite_link_join_declined');
select 'requests left', count(*) from notifications where type = 'invite_link_join_request';
set local role authenticated;

-- Remove C: friendship and trip place gone
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select remove_invite_link_redemption(r.id) from invite_link_redemptions r where r.redeemed_by = '00000000-0000-0000-0000-00000000000c';
-- Remove B: friendship and copied visit gone
select remove_invite_link_redemption(r.id) from invite_link_redemptions r where r.redeemed_by = '00000000-0000-0000-0000-00000000000b';
reset role;
select 'after removes: friendships', requester_id, addressee_id, status from friendships order by 2;
select 'after removes: members', count(*) from planned_trip_members;
select 'after removes: B visits', count(*) from visits where user_id = '00000000-0000-0000-0000-00000000000b';

-- Sender deletes the visit: a remaining copy is freed
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
insert into t select 'tok3', token from create_invite_link('visit', (select v::uuid from t where k='visit'), null, 2::smallint);
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select 'C redeem visit group', redeem_invite_link((select v from t where k='tok3'));
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
delete from visits where id = (select v::uuid from t where k='visit');
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
update visits set visited_on = date '2026-11-01' where user_id = auth.uid();
select 'C freed copy', visited_on, shared_from_visit_id from visits where user_id = auth.uid();
do $$ begin
  insert into visits (user_id, entity_type, entity_id, visited_on, shared_from_visit_id)
  values (auth.uid(), 'restaurant', '00000000-0000-0000-0000-0000000000f1', date '2026-10-01', (select id from visits limit 1));
  raise exception 'FAIL: client inserted a linked copy';
exception when insufficient_privilege then raise notice 'ok: client cannot link a visit';
end $$;

-- Revoke, and code guessing
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select revoke_invite_link(id) from invite_links where kind = 'trip';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}';
select 'D (declined) after revoke', state from get_invite_link_preview((select v from t where k='tok2'));
do $$
declare i int;
begin
  for i in 1..10 loop
    if (select state from get_invite_link_preview_by_code('ZZZZZZZZ')) <> 'not_found' then
      raise exception 'FAIL: unknown code found';
    end if;
  end loop;
  perform get_invite_link_preview_by_code('ZZZZZZZZ');
  raise exception 'FAIL: no rate limit';
exception when program_limit_exceeded then raise notice 'ok: code guessing limited';
end $$;

-- The anon surface
reset role;
select 'anon can execute', p.proname
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and (p.proname like '%invite_link%' or p.proname like 'visits_%shared%' or p.proname like 'get_notifications_v7%' or p.proname = 'get_unread_notification_count_v7')
   and has_function_privilege('anon', p.oid, 'EXECUTE');
select 'authenticated can execute', p.proname
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and (p.proname like '%invite_link%' or p.proname like 'visits_%shared%' or p.proname like 'get_notifications_v7%')
   and has_function_privilege('authenticated', p.oid, 'EXECUTE')
 order by 2;
select 'anon table privileges', table_name, privilege_type from information_schema.role_table_grants
 where grantee = 'anon' and table_name like 'invite_link%';

rollback;
