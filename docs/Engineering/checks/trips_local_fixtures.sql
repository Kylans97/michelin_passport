-- LOCAL STACK ONLY — never production. Fixtures for checking shared,
-- multi-destination trips (20261022120000) in the app against a scratch
-- `supabase start` stack: two test accounts who are friends, two cities
-- the migrations don't seed, and a handful of clearly fake venues.
-- Test credentials (local accounts only, valid nowhere else):
--   tripsa@example.test / TripsjI6EVJrcUVDF
--   tripsb@example.test / TripsOo6oX5nfZKY0

begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change)
values
 ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-0000-4000-8000-00000000000a', 'authenticated', 'authenticated',
  'tripsa@example.test', crypt('TripsjI6EVJrcUVDF', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}', '{"username":"trips_anna","display_name":"Anna Fixture"}', now(), now(), '', '', '', ''),
 ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-0000-4000-8000-00000000000b', 'authenticated', 'authenticated',
  'tripsb@example.test', crypt('TripsOo6oX5nfZKY0', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}', '{"username":"trips_ben","display_name":"Ben Fixture"}', now(), now(), '', '', '', '');

insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select id::text, id, json_build_object('sub', id::text, 'email', email), 'email', now(), now(), now()
  from auth.users where email in ('tripsa@example.test', 'tripsb@example.test');

insert into public.friendships (requester_id, addressee_id, status, responded_at)
values ('aaaaaaaa-0000-4000-8000-00000000000a', 'bbbbbbbb-0000-4000-8000-00000000000b', 'accepted', now());

insert into public.cities (id, country_code, name) values
 ('c1000000-0000-4000-8000-000000000001', 'FR', 'Paris'),
 ('c1000000-0000-4000-8000-000000000002', 'IT', 'Roma')
on conflict do nothing;

insert into public.restaurants (restaurant_code, name, michelin_stars, city_id, country_code, address, location) values
 ('FIX-R-PAR', 'Fixture Bistrot (Paris)', 1, 'c1000000-0000-4000-8000-000000000001', 'FR', '1 rue Fixture', 'SRID=4326;POINT(2.35 48.85)'),
 ('FIX-R-LYO', 'Fixture Table (Lyon)', 2, '14826ce3-4fe9-4051-a9ab-621baff92675', 'FR', '2 rue Fixture', 'SRID=4326;POINT(4.83 45.76)'),
 ('FIX-R-ROM', 'Fixture Osteria (Roma)', 1, 'c1000000-0000-4000-8000-000000000002', 'IT', '3 via Fixture', 'SRID=4326;POINT(12.49 41.90)');

insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location) values
 ('FIX-H-PAR', 'Fixture Hôtel (Paris)', 2, 'c1000000-0000-4000-8000-000000000001', 'FR', '4 rue Fixture', 'SRID=4326;POINT(2.33 48.86)'),
 ('FIX-H-ROM', 'Fixture Villa (Roma)', 1, 'c1000000-0000-4000-8000-000000000002', 'IT', '5 via Fixture', 'SRID=4326;POINT(12.48 41.89)');

-- Ben owns a trip and invites Anna, so Anna's app shows an invitation.
insert into public.planned_trips (id, user_id, title, start_date, end_date, country_code)
values ('d1000000-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-00000000000b',
        'Ben''s Roman weekend', '2026-12-11', '2026-12-13', 'IT');
insert into public.planned_trip_members (trip_id, user_id, invited_by)
values ('d1000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-00000000000a', 'bbbbbbbb-0000-4000-8000-00000000000b');

commit;
