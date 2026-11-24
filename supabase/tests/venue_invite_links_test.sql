-- Behaviour test for 20261101750000_add_venue_invite_links.sql. Run
-- against a scratch local stack (never production): psql -f this file.
-- Everything happens in one transaction that is rolled back. Every check
-- prints 'ok: ...' or raises 'FAIL: ...'. Last run 2026-11-24: all ok.
\set ON_ERROR_STOP on
begin;

-- m1, m2 manage Hof van Cleve; g1..g6 are guests; x manages nothing.
insert into auth.users (id, email, instance_id, aud, role)
select ('00000000-0000-0000-0000-0000000000' || n)::uuid, n || '@test.local',
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'
from unnest(array['a1','a2','b1','b2','b3','b4','b5','b6','c1']) n;

insert into restaurants (id, restaurant_code, name, city_id, country_code, address, location, michelin_stars)
select '00000000-0000-0000-0000-0000000000f1', 'TEST-HVC', 'Hof van Cleve', id, country_code, 'Riemegemstraat 1',
       'POINT(3.5 50.9)'::geography, 3
from cities where country_code = 'BE' limit 1;

with c as (
  insert into claims_restaurants (user_id, restaurant_id, status, role, business_email, phone)
  values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', 'approved', 'owner', 'a1@test.local', '+32'),
         ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000f1', 'approved', 'manager', 'a2@test.local', '+32')
  returning id, user_id, restaurant_id
)
insert into venue_managers_restaurants (user_id, restaurant_id, claim_id)
select user_id, restaurant_id, id from c;

create temp table t (k text primary key, v text);
grant all on t to authenticated, anon;

-- Nobody but a manager can make or read the venue's link.
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}';
do $$ begin
  perform create_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1');
  raise exception 'FAIL: a non manager made a venue link';
exception when insufficient_privilege then raise notice 'ok: non manager refused';
end $$;
do $$ begin
  perform get_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1');
  raise exception 'FAIL: a non manager read the venue link';
exception when insufficient_privilege then raise notice 'ok: non manager cannot read';
end $$;
do $$ begin
  perform create_invite_link('venue');
  raise exception 'FAIL: create_invite_link made a venue link';
exception when invalid_parameter_value then raise notice 'ok: create_invite_link refuses venue';
end $$;

-- m1 makes it; asking again gives the same link; m2 sees it too.
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
select 'none yet', token is null, followed_count, followed_since
  from get_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1');
insert into t select 'tok1', token from create_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1');
insert into t select 'code1', code from create_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1');
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}';
do $$ begin
  if (select token from get_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1'))
     is distinct from (select v from t where k = 'tok1') then
    raise exception 'FAIL: second manager sees another link';
  end if;
  if (select token from create_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1'))
     is distinct from (select v from t where k = 'tok1') then
    raise exception 'FAIL: second manager made a second open link';
  end if;
  raise notice 'ok: one open link, shared by both managers';
end $$;

-- anon: v2 shows the venue, never who shared it; v1 says unavailable.
reset role;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select 'anon v2', state, kind, sender_name, venue_type, venue_name, venue_city, venue_country, michelin_stars, expires_at, code is not null
  from get_invite_link_preview_v2((select v from t where k = 'tok1'));
do $$ begin
  if (select sender_name from get_invite_link_preview_v2((select v from t where k = 'tok1'))) is not null then
    raise exception 'FAIL: the sharer''s name reached the page';
  end if;
  if (select state from get_invite_link_preview((select v from t where k = 'tok1'))) <> 'unavailable'
     or (select kind from get_invite_link_preview((select v from t where k = 'tok1'))) is not null then
    raise exception 'FAIL: v1 shows a venue link';
  end if;
  raise notice 'ok: anon v2 shows the venue, v1 says unavailable';
end $$;

-- g1 follows through the link, typed as a code first.
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}';
select 'g1 by code v2', state, kind, venue_name
  from get_invite_link_preview_by_code_v2(lower((select v from t where k = 'code1')));
select 'g1 by code v1', state, kind
  from get_invite_link_preview_by_code((select v from t where k = 'code1'));
select 'g1 redeem', redeem_invite_link((select v from t where k = 'tok1'));
do $$ begin
  if not exists (select 1 from follows_restaurants where user_id = auth.uid()
                 and restaurant_id = '00000000-0000-0000-0000-0000000000f1') then
    raise exception 'FAIL: no follow';
  end if;
  if exists (select 1 from friendships) then
    raise exception 'FAIL: a venue link made a friendship';
  end if;
  if (select state from get_invite_link_preview_v2((select v from t where k = 'tok1'))) <> 'accepted' then
    raise exception 'FAIL: g1 state after follow';
  end if;
  raise notice 'ok: g1 follows, no friendship';
end $$;
do $$ begin
  perform redeem_invite_link((select v from t where k = 'tok1'));
  raise exception 'FAIL: redeemed twice';
exception when unique_violation then raise notice 'ok: second use refused';
end $$;

-- g2 already follows: 'following', and redeeming changes nothing.
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}';
insert into follows_restaurants (user_id, restaurant_id)
values (auth.uid(), '00000000-0000-0000-0000-0000000000f1');
do $$ begin
  if (select state from get_invite_link_preview_v2((select v from t where k = 'tok1'))) <> 'following' then
    raise exception 'FAIL: g2 should read following';
  end if;
  perform redeem_invite_link((select v from t where k = 'tok1'));
  raise exception 'FAIL: g2 redeemed while following';
exception when unique_violation then raise notice 'ok: already following';
end $$;

-- g3 and g4 follow: three so far, hidden.
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b3","role":"authenticated"}';
select 'g3', redeem_invite_link((select v from t where k = 'tok1')) ->> 'kind';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b4","role":"authenticated"}';
select 'g4', redeem_invite_link((select v from t where k = 'tok1')) ->> 'kind';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
do $$ begin
  if (select followed_count from get_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1')) is not null then
    raise exception 'FAIL: three followers shown';
  end if;
  raise notice 'ok: under 5 hidden';
end $$;

-- The sharer sees no one: not in their lists, not in the table.
do $$ begin
  if exists (select 1 from get_my_invite_links()) then
    raise exception 'FAIL: venue link in get_my_invite_links';
  end if;
  if exists (select 1 from invite_link_redemptions) then
    raise exception 'FAIL: sharer reads the redemptions';
  end if;
  if exists (select 1 from get_invite_link_redemptions((select id from invite_links limit 1))) then
    raise exception 'FAIL: sharer reads who followed';
  end if;
  raise notice 'ok: the sharer never sees who followed';
end $$;
do $$ begin
  perform remove_invite_link_redemption((
    select r.id from invite_link_redemptions r limit 1));
  raise exception 'FAIL: remove on a venue link';
exception when insufficient_privilege then raise notice 'ok: no Remove on a venue link';
end $$;

-- A new link: the old one stops; g5 gets 'unavailable' from it.
insert into t select 'tok2', token from create_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1', true);
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b5","role":"authenticated"}';
do $$ begin
  if (select state from get_invite_link_preview_v2((select v from t where k = 'tok1'))) <> 'unavailable' then
    raise exception 'FAIL: replaced link still open';
  end if;
  raise notice 'ok: replaced link stops';
end $$;
select 'g5 new link', redeem_invite_link((select v from t where k = 'tok2')) ->> 'venue_id';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b6","role":"authenticated"}';
select 'g6 new link', redeem_invite_link((select v from t where k = 'tok2')) ->> 'kind';

-- Five across both links now show; the first link's date is "since".
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}';
select 'count', followed_count, token = (select v from t where k = 'tok2')
  from get_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1');
do $$ begin
  if (select followed_count from get_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1')) is distinct from 5 then
    raise exception 'FAIL: count across links';
  end if;
  raise notice 'ok: five shown, across both links';
end $$;

-- A manager whose access is revoked can no longer read or share it; the
-- link keeps working for guests.
reset role;
update venue_managers_restaurants set revoked_at = now(), revoked_by = user_id, revoked_reason = 'test'
 where user_id = '00000000-0000-0000-0000-0000000000a1';
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
do $$ begin
  perform get_venue_invite_link('restaurant', '00000000-0000-0000-0000-0000000000f1');
  raise exception 'FAIL: revoked manager reads the link';
exception when insufficient_privilege then raise notice 'ok: revoked manager refused';
end $$;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}';
do $$ begin
  if (select state from get_invite_link_preview_v2((select v from t where k = 'tok2'))) <> 'open' then
    raise exception 'FAIL: link stopped when its maker left';
  end if;
  raise notice 'ok: link keeps working when its maker leaves';
end $$;

-- Old kinds are untouched by v2 and by the new constraints.
do $$ begin
  begin
    reset role;
    insert into invite_links (token, code, created_by, kind, max_uses, expires_at)
    values ('t-null-max-xxxxxxxxxxxx', 'ZZZZZZZZ', '00000000-0000-0000-0000-0000000000b6', 'friend', null, now());
    raise exception 'FAIL: friend link without a maximum';
  exception when check_violation then raise notice 'ok: only a venue link is open ended';
  end;
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b6","role":"authenticated"}';
insert into t select 'tokf', token from create_invite_link('friend');
select 'friend v2', state, kind, sender_name, venue_id is null
  from get_invite_link_preview_v2((select v from t where k = 'tokf'));

-- Privileges: every new function closed to anon except the v2 preview.
reset role;
do $$
declare f text;
begin
  foreach f in array array[
    'create_venue_invite_link(text, uuid, boolean)',
    'get_venue_invite_link(text, uuid)',
    'get_invite_link_preview_by_code_v2(text)',
    'invite_link_preview_row_v2(public.invite_links)',
    'invite_link_venue_exists(text, uuid)',
    'invite_link_venue_followed_by(text, uuid, uuid)',
    'invite_link_venue_follow(text, uuid, uuid)',
    'invite_link_venue_summary(text, uuid)',
    'invite_link_state(public.invite_links, uuid)',
    'redeem_invite_link(text, boolean)',
    'create_invite_link(text, uuid, uuid, smallint)',
    'remove_invite_link_redemption(uuid)',
    'get_my_invite_links()',
    'get_invite_link_redemptions(uuid)',
    'invite_link_preview_row(public.invite_links)'
  ] loop
    if has_function_privilege('anon', 'public.' || f, 'EXECUTE') then
      raise exception 'FAIL: anon can execute %', f;
    end if;
  end loop;
  foreach f in array array[
    'invite_link_preview_row_v2(public.invite_links)',
    'invite_link_venue_exists(text, uuid)',
    'invite_link_venue_followed_by(text, uuid, uuid)',
    'invite_link_venue_follow(text, uuid, uuid)',
    'invite_link_venue_summary(text, uuid)'
  ] loop
    if has_function_privilege('authenticated', 'public.' || f, 'EXECUTE') then
      raise exception 'FAIL: authenticated can execute helper %', f;
    end if;
  end loop;
  if not has_function_privilege('anon', 'public.get_invite_link_preview_v2(text)', 'EXECUTE') then
    raise exception 'FAIL: the page cannot read v2';
  end if;
  raise notice 'ok: privileges';
end $$;

rollback;
