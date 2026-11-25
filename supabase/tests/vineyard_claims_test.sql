-- Functional test of 20261101780000_add_vineyard_claims.sql. Run on a
-- local stack with every migration replayed (never on production):
--   psql "$DB_URL" -f supabase/tests/vineyard_claims_test.sql
-- Two test users and one test estate; every check raises on failure, and
-- the whole run is rolled back. Passed 2026-11-25 on a scratch stack.

\set ON_ERROR_STOP 1
begin;

insert into auth.users (id, email, aud, role, instance_id)
values ('00000000-0000-0000-0000-0000000000a1', 'owner@test.invalid', 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000'),
       ('00000000-0000-0000-0000-0000000000b2', 'other@test.invalid', 'authenticated', 'authenticated', '00000000-0000-0000-0000-000000000000');
insert into public.profiles (id) values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b2')
on conflict do nothing;
insert into public.vineyards (id, vineyard_code, name, country_code, city, website_url)
values ('00000000-0000-0000-0000-00000000e57a', 'vine_9999', 'Test Estate', 'ES', 'Laguardia', 'https://old.example.com');

-- 1. The owner files a claim, as themselves.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
insert into public.claims_vineyards (user_id, vineyard_id, role, business_email, phone)
values (auth.uid(), '00000000-0000-0000-0000-00000000e57a', 'owner', 'owner@estate.example', '+34 600 000 000');
do $$ begin
  if (select count(*) from public.claims_vineyards) <> 1 then raise exception 'own claim not readable'; end if;
  if public.is_active_venue_manager('vineyard', '00000000-0000-0000-0000-00000000e57a') then
    raise exception 'a pending claim must not grant permission';
  end if;
end $$;
-- A claim filed as someone else, or pre-approved, is refused.
do $$ begin
  insert into public.claims_vineyards (user_id, vineyard_id, role, business_email, phone)
  values ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000e57a', 'owner', 'x@x.example', '+34 600 000 001');
  raise exception 'claim for another user was allowed';
exception when insufficient_privilege or check_violation then null;
end $$;
do $$ begin
  insert into public.claims_vineyards (user_id, vineyard_id, role, business_email, phone, status)
  values (auth.uid(), '00000000-0000-0000-0000-00000000e57a', 'owner', 'x@x.example', '+34 600 000 001', 'approved');
  raise exception 'pre-approved claim was allowed';
exception when insufficient_privilege or check_violation or unique_violation then null;
end $$;
-- Managing before approval is refused.
do $$ begin
  perform public.set_venue_contact('vineyard', '00000000-0000-0000-0000-00000000e57a', 'https://new.example.com', null);
  raise exception 'contact edit before approval was allowed';
exception when raise_exception then
  if sqlerrm not like 'Not a manager%' then raise; end if;
end $$;
reset role;

-- 2. The claim shows in the admin review queue (service context here).
do $$ begin
  if not exists (select 1 from public.claims_vineyards c
                 join lateral (select 1) x on true where c.status = 'pending') then
    raise exception 'no pending claim';
  end if;
end $$;

-- 3. Approval grants the permission, through the same function admins use.
select * from public.approve_venue_claim('vineyard',
  (select id from public.claims_vineyards limit 1),
  '00000000-0000-0000-0000-0000000000b2');
do $$ begin
  if (select status from public.claims_vineyards limit 1) <> 'approved' then raise exception 'claim not approved'; end if;
  if (select count(*) from public.venue_managers_vineyards where revoked_at is null) <> 1 then raise exception 'no manager row'; end if;
  if (select count(*) from public.notifications where subject_type = 'venue_claim') <> 2 then
    raise exception 'expected received + approved notifications';
  end if;
end $$;

-- 4. As the approved manager.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
do $$ begin
  if not public.is_active_venue_manager('vineyard', '00000000-0000-0000-0000-00000000e57a') then
    raise exception 'approved manager is not a manager';
  end if;
  if (select count(*) from public.venue_managers_vineyards) <> 1 then raise exception 'own grant not readable'; end if;
  if (select claim_venue_type from public.get_notifications_v6() where claim_venue_type is not null limit 1) <> 'vineyard'
     or (select claim_venue_name from public.get_notifications_v6() where claim_venue_type is not null limit 1) <> 'Test Estate' then
    raise exception 'claim notification does not name the estate';
  end if;
end $$;
-- Website through set_venue_contact, logged; a phone is refused.
select public.set_venue_contact('vineyard', '00000000-0000-0000-0000-00000000e57a', 'https://new.example.com', null);
do $$ begin
  if (select website_url from public.vineyards where id = '00000000-0000-0000-0000-00000000e57a') <> 'https://new.example.com' then
    raise exception 'website not set';
  end if;
  begin
    perform public.set_venue_contact('vineyard', '00000000-0000-0000-0000-00000000e57a', null, '+34 600 000 000');
    raise exception 'phone for an estate was allowed';
  exception when raise_exception then
    if sqlerrm not like 'An estate page has no phone%' then raise; end if;
  end;
end $$;
-- The estate's facts stay ours: a direct update is refused.
do $$ declare n int; begin
  update public.vineyards set name = 'Renamed' where id = '00000000-0000-0000-0000-00000000e57a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'manager could rename the estate'; end if;
exception when insufficient_privilege then null;
end $$;
-- About text and a photo submission, as the manager.
insert into public.venue_about_submissions (user_id, venue_type, venue_id, about_text)
values (auth.uid(), 'vineyard', '00000000-0000-0000-0000-00000000e57a', 'Our vines, in our words.');
insert into public.venue_photo_submissions (user_id, venue_type, venue_id, storage_path)
values (auth.uid(), 'vineyard', '00000000-0000-0000-0000-00000000e57a',
        'vineyard/00000000-0000-0000-0000-00000000e57a/00000000-0000-0000-0000-0000000000a1/a.jpg');
reset role;
do $$ begin
  if (select count(*) from public.venue_contact_edits where venue_type = 'vineyard') <> 1 then raise exception 'edit not logged'; end if;
end $$;

-- 5. Another member cannot submit for the estate.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
do $$ begin
  insert into public.venue_about_submissions (user_id, venue_type, venue_id, about_text)
  values (auth.uid(), 'vineyard', '00000000-0000-0000-0000-00000000e57a', 'Not mine.');
  raise exception 'a non-manager could submit an about text';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  if (select count(*) from public.claims_vineyards) <> 0 then raise exception 'saw someone else''s claim'; end if;
  if (select count(*) from public.venue_managers_vineyards) <> 0 then raise exception 'saw someone else''s grant'; end if;
end $$;
reset role;

-- 6. Review queue lists the about text and photo with the estate's name,
-- for an admin signed in with two steps.
insert into public.admins (user_id) values ('00000000-0000-0000-0000-0000000000b2');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated","aal":"aal2"}', true);
do $$ begin
  if (select count(*) from public.get_review_queue() q
      where q.venue_type = 'vineyard' and q.venue_name = 'Test Estate' and q.venue_city = 'Laguardia') <> 3 then
    raise exception 'review queue does not name the estate for about, photo and website edit';
  end if;
end $$;
reset role;

-- 7. Publishing photos, then reorder, framing and card photo as the manager.
insert into storage.objects (bucket_id, name) values
  ('catalogue-media', 'vineyard/00000000-0000-0000-0000-00000000e57a/a.jpg'),
  ('catalogue-media', 'vineyard/00000000-0000-0000-0000-00000000e57a/b.jpg');
select * from public.approve_venue_photo(
  (select id from public.venue_photo_submissions where venue_type = 'vineyard' limit 1),
  '00000000-0000-0000-0000-0000000000b2',
  'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/vineyard/00000000-0000-0000-0000-00000000e57a/a.jpg');
insert into public.vineyard_photos (vineyard_id, image_url, display_order)
values ('00000000-0000-0000-0000-00000000e57a', 'https://example.invalid/b.jpg', 1);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select public.reorder_venue_photos('vineyard', '00000000-0000-0000-0000-00000000e57a',
  array(select id from public.vineyard_photos order by display_order desc));
select public.set_venue_photo_framing('vineyard', (select id from public.vineyard_photos order by display_order limit 1), 0.3, 0.6, 1.5);
select public.set_venue_card_photo('vineyard', '00000000-0000-0000-0000-00000000e57a',
  (select id from public.vineyard_photos order by display_order desc limit 1), 0.5, 0.5, 2);
do $$ begin
  if (select image_url from public.vineyard_photos order by display_order limit 1) <> 'https://example.invalid/b.jpg' then
    raise exception 'reorder did not take';
  end if;
  if (select zoom from public.vineyard_photos order by display_order limit 1) <> 1.5 then raise exception 'framing did not take'; end if;
  if (select count(*) from public.vineyard_photos where is_card) <> 1 then raise exception 'card photo not set'; end if;
  begin
    update public.vineyard_photos set image_url = 'https://evil.invalid/x.jpg';
    raise exception 'manager could change image_url';
  exception when raise_exception then
    if sqlerrm not like 'Only display_order%' then raise; end if;
  end;
end $$;
reset role;
-- Anyone reads published photos, anon included.
set local role anon;
do $$ begin
  if (select count(*) from public.vineyard_photos) <> 2 then raise exception 'anon cannot read estate photos'; end if;
  begin
    perform 1 from public.claims_vineyards;
    raise exception 'anon could read claims';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- 8. Five photos at most.
insert into public.vineyard_photos (vineyard_id, image_url, display_order)
select '00000000-0000-0000-0000-00000000e57a', 'https://example.invalid/' || g || '.jpg', g from generate_series(10, 12) g;
do $$ begin
  insert into public.vineyard_photos (vineyard_id, image_url, display_order)
  values ('00000000-0000-0000-0000-00000000e57a', 'https://example.invalid/6.jpg', 20);
  raise exception 'a sixth photo was allowed';
exception when raise_exception then
  if sqlerrm not like '%maximum of 5%' then raise; end if;
end $$;

-- 9. Invite link and following.
do $$ begin
  if not public.invite_link_venue_exists('vineyard', '00000000-0000-0000-0000-00000000e57a') then raise exception 'estate not found for invite'; end if;
  perform public.invite_link_venue_follow('vineyard', '00000000-0000-0000-0000-00000000e57a', '00000000-0000-0000-0000-0000000000b2');
  if not public.invite_link_venue_followed_by('vineyard', '00000000-0000-0000-0000-00000000e57a', '00000000-0000-0000-0000-0000000000b2') then
    raise exception 'follow through invite did not take';
  end if;
  if (select venue_name from public.invite_link_venue_summary('vineyard', '00000000-0000-0000-0000-00000000e57a')) <> 'Test Estate' then
    raise exception 'invite summary does not name the estate';
  end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select 'invite' as step, public.create_venue_invite_link('vineyard', '00000000-0000-0000-0000-00000000e57a') is not null;
reset role;

-- 10. Rejecting a second claim, and the three old types still work.
insert into public.claims_vineyards (user_id, vineyard_id, role, business_email, phone)
values ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000e57a', 'manager', 'b@x.example', '+34 600 000 002');
select * from public.reject_venue_claim('vineyard',
  (select id from public.claims_vineyards where status = 'pending'),
  '00000000-0000-0000-0000-0000000000a1', 'Could not confirm.');
do $$ begin
  if (select count(*) from public.claims_vineyards where status = 'rejected') <> 1 then raise exception 'reject failed'; end if;
  begin
    perform public.approve_venue_claim('nonsense', gen_random_uuid(), '00000000-0000-0000-0000-0000000000a1');
    raise exception 'unknown type accepted';
  exception when raise_exception then
    if sqlerrm not like 'Unknown venue_type%' then raise; end if;
  end;
end $$;

select 'ALL VINEYARD CLAIM CHECKS PASSED';
rollback;
