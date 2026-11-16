-- Journeys: RLS and constraint checks. Run against a LOCAL stack only,
-- after 20261101500000_add_journeys.sql and the first-slice seed:
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/journeys_rls_test.sql
-- Everything runs in one transaction and is rolled back.
begin;

create function pg_temp.expect(ok boolean, label text) returns void
language plpgsql as $$
begin
  if not ok then raise exception 'FAIL: %', label; end if;
  raise notice 'ok: %', label;
end $$;

create function pg_temp.raises(stmt text, label text) returns void
language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    raise notice 'ok: % (%)', label, sqlerrm;
    return;
  end;
  raise exception 'FAIL: % did not raise', label;
end $$;

-- Fixtures: two members who are friends, one stranger, one draft journey.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000aa01', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000aa02', 'b@test.local'),
  ('00000000-0000-0000-0000-00000000aa03', 'c@test.local');
insert into public.profiles (id)
select id from auth.users where email like '%@test.local'
on conflict (id) do nothing;
insert into public.friendships (requester_id, addressee_id, status)
values ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-00000000aa02', 'accepted');

insert into public.journeys (journey_code, slug, kind, name, operator_id, publication_status)
select 'train_900', 'draft-train', 'train', 'Draft train', id, 'draft'
from public.journey_operators where operator_code = 'op_001';
insert into public.journey_routes (journey_id, route_code, name, from_place, from_country_code, to_place, to_country_code)
select id, 'train_900_r01', 'Draft route', 'A', 'FR', 'B', 'FR' from public.journeys where journey_code = 'train_900';

select set_config('test.draft_id', id::text, true) from public.journeys where journey_code = 'train_900';

-- Constraints (as the owner).
select pg_temp.raises($$insert into public.journeys (journey_code, slug, kind, name, operator_id)
  select 'ship_900', 'x-ship', 'train', 'x', id from public.journey_operators limit 1$$,
  'code prefix must match kind');
select pg_temp.raises($$insert into public.journeys (journey_code, slug, kind, ship_type, name, operator_id)
  select 'train_901', 'x-train', 'train', 'river', 'x', id from public.journey_operators limit 1$$,
  'a train has no ship_type');
select pg_temp.raises($$insert into public.journeys (journey_code, slug, kind, name, operator_id, first_departure_on)
  select 'train_902', 'y-train', 'train', 'x', id, date '2027-01-01' from public.journey_operators limit 1$$,
  'first_departure_on only when announced');
select pg_temp.raises($$insert into public.journey_travels (journey_id, route_id, user_id, departed_on)
  select j.id, r.id, '00000000-0000-0000-0000-00000000aa01', date '2026-01-01'
  from public.journeys j, public.journey_routes r
  where j.journey_code = 'train_002' and r.route_code = 'train_001_r01'$$,
  'a travel''s route must belong to its journey');

-- anon: reads published catalogue, never drafts, never travels, never writes.
set local role anon;
select pg_temp.expect((select count(*) from public.journeys_full) = 20, 'anon reads 20 published journeys');
select pg_temp.expect((select count(*) from public.journeys where journey_code = 'train_900') = 0, 'anon cannot see a draft');
select pg_temp.expect((select count(*) from public.journey_routes where route_code = 'train_900_r01') = 0, 'anon cannot see a draft''s route');
select pg_temp.raises($$select * from public.journey_travels$$, 'anon has no access to journey_travels');
select pg_temp.raises($$update public.journeys set name = 'x'$$, 'anon cannot write journeys');
reset role;

-- Member A confirms a travel and wishlists a journey.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aa01","role":"authenticated"}', true);
insert into public.journey_travels (journey_id, route_id, user_id, departed_on, arrived_on, visibility)
select j.id, r.id, auth.uid(), date '2026-06-01', date '2026-06-03', 'friends'
from public.journeys j join public.journey_routes r on r.journey_id = j.id
where r.route_code = 'train_002_r01';
insert into public.journey_travels (journey_id, user_id, departed_on)
select id, auth.uid(), date '2026-07-01' from public.journeys where journey_code = 'ship_004';
insert into public.wishlist (user_id, entity_type, entity_id)
select auth.uid(), 'journey', id from public.journeys where journey_code = 'train_001';
select pg_temp.expect((select count(*) from public.journey_travels) = 2, 'member reads own travels');
select pg_temp.raises($$insert into public.journey_travels (journey_id, user_id, departed_on)
  select id, '00000000-0000-0000-0000-00000000aa02', date '2026-01-01' from public.journeys limit 1$$,
  'cannot confirm a travel for someone else');
select pg_temp.raises($$insert into public.journey_travels (journey_id, user_id, departed_on)
  values (current_setting('test.draft_id')::uuid, auth.uid(), date '2026-01-01')$$,
  'cannot confirm a travel on a draft');
select pg_temp.raises($$insert into public.journey_travels (journey_id, user_id, departed_on, arrived_on)
  select id, auth.uid(), date '2026-02-02', date '2026-02-01' from public.journeys where journey_code = 'train_001'$$,
  'arrival before departure');

-- Friend B sees only the 'friends' travel; stranger C sees none.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aa02","role":"authenticated"}', true);
select pg_temp.expect((select count(*) from public.journey_travels) = 1, 'friend sees only the friends-visible travel');
delete from public.journey_travels;
reset role;
select pg_temp.expect((select count(*) from public.journey_travels) = 2,
  'friend cannot delete someone else''s travel');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aa03","role":"authenticated"}', true);
select pg_temp.expect((select count(*) from public.journey_travels) = 0, 'stranger sees no travels');
reset role;

rollback;
