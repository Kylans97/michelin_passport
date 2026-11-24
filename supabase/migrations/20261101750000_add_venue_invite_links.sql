-- Venue invite links: a venue's managers share one standing link, and
-- whoever opens it, signs in and taps Follow follows that venue, also
-- through installing the app first, like the friend, visit and trip
-- links of 20261101670000.
--
-- Written 2026-11-24. Product owner, 2026-11-23: "veneu houders moeten
-- ook een uitnodiging kunnen sturen vanuit de venue dat iemand gelijk hun
-- volgt", then "Ja, bouw het" to the plan at
-- https://claude.ai/artifact/9zwabtq2KGPTr529wFFaHY, which settled:
--   - Follow still needs one tap: following sends event pushes to the
--     member's phone, and a link can linger on the clipboard;
--   - one standing link per venue, for any number of people, with no end
--     date until a manager makes a new one (the old one then stops);
--   - any active manager (is_active_venue_manager(), never the claims)
--     shares it, and it keeps working when the one who made it leaves;
--   - no friendship with whoever shared it, and their name is never
--     shown: the link speaks for the venue;
--   - the venue sees only how many followed through its links, under 5
--     hidden (studio_suppress), never who; nobody is notified per follow.
--
-- 1.9.0 reads get_invite_link_preview and _by_code, which now answer
-- 'unavailable' for a venue link, so it never shows a card it doesn't
-- know. The _v2 readers carry the venue. get_my_invite_links, the
-- redemption list and Remove leave venue links out, so neither an old
-- build nor whoever shared the link ever sees who followed.
--
-- Every new SECURITY DEFINER function below is revoked from public and
-- anon in this file; get_invite_link_preview_v2 is then granted to anon
-- on purpose, as v1 is, for mantelier.app/i/<token>.

begin;

-- ============================================================
-- 1. The link can point at a venue
-- ============================================================

alter table public.invite_links
  add column venue_type text check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  add column venue_id   uuid,
  alter column max_uses drop not null,
  alter column expires_at drop not null;

alter table public.invite_links drop constraint invite_links_kind_check;
alter table public.invite_links
  add constraint invite_links_kind_check
    check (kind in ('friend', 'visit', 'trip', 'venue')),
  add constraint invite_links_venue_target
    check ((kind = 'venue') = (venue_id is not null)
       and (kind = 'venue') = (venue_type is not null)),
  -- Only a venue link is open-ended: every other kind keeps its maximum
  -- and its 14 days, which 1.9.0 reads.
  add constraint invite_links_venue_open_ended
    check (kind = 'venue' or (max_uses is not null and expires_at is not null));

comment on column public.invite_links.venue_id is
  'For kind venue: the restaurant, hotel or private chef followed through '
  'this link. venue_type says which table. max_uses and expires_at are '
  'null for these: one standing link until a manager replaces it.';

-- One open link per venue.
create unique index invite_links_one_open_per_venue
  on public.invite_links (venue_type, venue_id)
  where kind = 'venue' and revoked_at is null;

-- Whoever shared a venue link never reads who used it: the creator's
-- half of the policy is now for the other kinds only.
drop policy invite_link_redemptions_select on public.invite_link_redemptions;
create policy invite_link_redemptions_select on public.invite_link_redemptions
  for select to authenticated
  using (
    redeemed_by = auth.uid()
    or exists (
      select 1 from public.invite_links l
      where l.id = invite_id and l.created_by = auth.uid() and l.kind <> 'venue'
    )
  );

-- ============================================================
-- 2. Helpers (internal: not callable by anyone but the owner)
-- ============================================================

-- Whether the venue is there to follow: a restaurant or hotel row, a
-- published private chef.
create function public.invite_link_venue_exists(p_venue_type text, p_venue_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case p_venue_type
    when 'restaurant' then exists (select 1 from public.restaurants r where r.id = p_venue_id)
    when 'hotel' then exists (select 1 from public.hotels h where h.id = p_venue_id)
    when 'private_chef' then exists (
      select 1 from public.private_chefs c
      where c.id = p_venue_id and c.publication_status = 'published'
    )
    else false
  end;
$$;

revoke execute on function public.invite_link_venue_exists(text, uuid) from public, anon, authenticated;

create function public.invite_link_venue_followed_by(p_venue_type text, p_venue_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case p_venue_type
    when 'restaurant' then exists (
      select 1 from public.follows_restaurants f
      where f.restaurant_id = p_venue_id and f.user_id = p_user_id)
    when 'hotel' then exists (
      select 1 from public.follows_hotels f
      where f.hotel_id = p_venue_id and f.user_id = p_user_id)
    when 'private_chef' then exists (
      select 1 from public.follows_private_chefs f
      where f.private_chef_id = p_venue_id and f.user_id = p_user_id)
    else false
  end;
$$;

revoke execute on function public.invite_link_venue_followed_by(text, uuid, uuid) from public, anon, authenticated;

create function public.invite_link_venue_follow(p_venue_type text, p_venue_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_venue_type = 'restaurant' then
    insert into public.follows_restaurants (user_id, restaurant_id)
    values (p_user_id, p_venue_id) on conflict do nothing;
  elsif p_venue_type = 'hotel' then
    insert into public.follows_hotels (user_id, hotel_id)
    values (p_user_id, p_venue_id) on conflict do nothing;
  elsif p_venue_type = 'private_chef' then
    insert into public.follows_private_chefs (user_id, private_chef_id)
    values (p_user_id, p_venue_id) on conflict do nothing;
  end if;
end;
$$;

revoke execute on function public.invite_link_venue_follow(text, uuid, uuid) from public, anon, authenticated;

-- What a venue link shows: the venue's name, place, current awards and
-- card photo with its crop. Never who shared it.
create function public.invite_link_venue_summary(p_venue_type text, p_venue_id uuid)
returns table (
  venue_name text,
  venue_city text,
  venue_country text,
  michelin_stars smallint,
  michelin_keys smallint,
  card_photo_url text,
  card_focus_x numeric,
  card_focus_y numeric,
  card_zoom numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select r.name, c.name, co.name, r.michelin_stars::smallint, null::smallint,
         r.card_photo_url, r.card_focus_x, r.card_focus_y, r.card_zoom
    from public.restaurants_full r
    left join public.cities c on c.id = r.city_id
    left join public.countries co on co.country_code = c.country_code
   where p_venue_type = 'restaurant' and r.id = p_venue_id
  union all
  select h.name, c.name, co.name, null::smallint, h.michelin_keys::smallint,
         h.card_photo_url, h.card_focus_x, h.card_focus_y, h.card_zoom
    from public.hotels_full h
    left join public.cities c on c.id = h.city_id
    left join public.countries co on co.country_code = c.country_code
   where p_venue_type = 'hotel' and h.id = p_venue_id
  union all
  select coalesce(nullif(trim(pc.business_name), ''), pc.display_name),
         pc.home_city, co.name, null::smallint, null::smallint,
         ph.image_url, ph.card_focus_x, ph.card_focus_y, ph.card_zoom
    from public.private_chefs pc
    left join public.countries co on co.country_code = pc.home_country_code
    left join lateral (
      select p.image_url, p.card_focus_x, p.card_focus_y, p.card_zoom
        from public.private_chef_photos p
       where p.private_chef_id = pc.id
       order by p.is_card desc, p.display_order
       limit 1
    ) ph on true
   where p_venue_type = 'private_chef' and pc.id = p_venue_id
     and pc.publication_status = 'published';
$$;

revoke execute on function public.invite_link_venue_summary(text, uuid) from public, anon, authenticated;

-- The state of a link, now also for a venue: 'following' when the viewer
-- already follows it, 'unavailable' once the venue is gone. A block
-- between two members has no bearing on a venue's link.
create or replace function public.invite_link_state(p_link public.invite_links, p_viewer uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_viewer is not null and p_link.created_by = p_viewer then 'own'
    when p_viewer is not null and exists (
      select 1 from public.invite_link_redemptions r
      where r.invite_id = p_link.id and r.redeemed_by = p_viewer
        and r.status in ('approved', 'awaiting_approval')
    ) then 'accepted'
    -- Turned away from the trip, or removed by the sender: the link is
    -- spent for this person.
    when p_viewer is not null and exists (
      select 1 from public.invite_link_redemptions r
      where r.invite_id = p_link.id and r.redeemed_by = p_viewer
    ) then 'unavailable'
    when p_link.revoked_at is not null then 'unavailable'
    when p_link.expires_at <= now() then 'expired'
    when p_link.use_count >= p_link.max_uses then 'unavailable'
    when p_link.kind = 'trip' and not exists (
      select 1 from public.planned_trips t
      where t.id = p_link.trip_id and t.end_date >= current_date
    ) then 'unavailable'
    when p_link.kind = 'venue'
      and not public.invite_link_venue_exists(p_link.venue_type, p_link.venue_id)
      then 'unavailable'
    when p_link.kind = 'venue' and p_viewer is not null
      and public.invite_link_venue_followed_by(p_link.venue_type, p_link.venue_id, p_viewer)
      then 'following'
    when p_link.kind <> 'venue' and p_viewer is not null and exists (
      select 1 from public.friendships f
      where f.status = 'blocked'
        and least(f.requester_id, f.addressee_id) = least(p_link.created_by, p_viewer)
        and greatest(f.requester_id, f.addressee_id) = greatest(p_link.created_by, p_viewer)
    ) then 'unavailable'
    else 'open'
  end;
$$;

revoke execute on function public.invite_link_state(public.invite_links, uuid) from public, anon, authenticated;

-- ============================================================
-- 3. Existing functions, aware of venue links
-- ============================================================

create or replace function public.create_invite_link(
  p_kind text,
  p_visit_id uuid default null,
  p_trip_id uuid default null,
  p_max_uses smallint default 1
)
returns table (id uuid, token text, code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
  v_code text;
  v_bytes bytea;
  v_alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_link public.invite_links;
  i int;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  if p_kind not in ('friend', 'visit', 'trip') then
    raise exception 'Invalid invitation type' using errcode = '22023';
  end if;
  if p_max_uses is null or p_max_uses not between 1 and 12 then
    raise exception 'A group link is for up to 12 people' using errcode = '22023';
  end if;

  if p_kind = 'visit' and not exists (
    select 1 from public.visits v
    where v.id = p_visit_id and v.user_id = v_uid
  ) then
    raise exception 'You can only share your own visit' using errcode = '42501';
  end if;

  if p_kind = 'trip' then
    if not public.invite_link_sender_on_trip(p_trip_id, v_uid) then
      raise exception 'Only someone on this trip can invite to it' using errcode = '42501';
    end if;
    if exists (
      select 1 from public.planned_trips t
      where t.id = p_trip_id and t.end_date < current_date
    ) then
      raise exception 'This trip is over' using errcode = '22023';
    end if;
  end if;

  if (
    select count(*) from public.invite_links l
    where l.created_by = v_uid and l.kind <> 'venue'
      and l.revoked_at is null and l.expires_at > now()
  ) >= 50 then
    raise exception 'You have too many open links. Cancel a few under Friends first.'
      using errcode = '54000';
  end if;

  -- Retried on the (astronomically unlikely) collision of either value.
  for attempt in 1..5 loop
    v_token := rtrim(translate(encode(
      decode(replace(gen_random_uuid()::text, '-', ''), 'hex')
      || decode(substr(replace(gen_random_uuid()::text, '-', ''), 1, 2), 'hex'),
      'base64'), '+/', '-_'), '=');
    v_token := left(v_token, 22);
    v_bytes := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
    end loop;
    begin
      insert into public.invite_links (token, code, created_by, kind, visit_id, trip_id, max_uses)
      values (
        v_token, v_code, v_uid, p_kind,
        case when p_kind = 'visit' then p_visit_id end,
        case when p_kind = 'trip' then p_trip_id end,
        p_max_uses
      )
      returning * into v_link;
      exit;
    exception when unique_violation then
      if attempt = 5 then raise; end if;
    end;
  end loop;

  return query select v_link.id, v_link.token, v_link.code, v_link.expires_at;
end;
$$;

revoke execute on function public.create_invite_link(text, uuid, uuid, smallint) from public, anon;
grant execute on function public.create_invite_link(text, uuid, uuid, smallint) to authenticated;

create or replace function public.invite_link_preview_row(p_link public.invite_links)
returns table (
  state text,
  kind text,
  is_group boolean,
  needs_approval boolean,
  sender_name text,
  venue_type text,
  venue_name text,
  venue_city text,
  michelin_stars smallint,
  michelin_keys smallint,
  visited_on date,
  trip_title text,
  trip_start_date date,
  trip_end_date date,
  expires_at timestamptz,
  code text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_state text := public.invite_link_state(p_link, auth.uid());
begin
  -- Nothing about the link once it can't be used, except who sent an
  -- expired one, so the page can say whom to ask for a new one.
  -- A venue link (20261101750000) is unknown to 1.9.0, which reads only
  -- this row: it says unavailable there. get_invite_link_preview_v2 shows it.
  if v_state = 'unavailable' or p_link.kind = 'venue' then
    return query select 'unavailable'::text, null::text, null::boolean, null::boolean,
      null::text, null::text, null::text, null::text, null::smallint, null::smallint,
      null::date, null::text, null::date, null::date, null::timestamptz, null::text;
    return;
  end if;
  return query
    select v_state,
           p_link.kind,
           p_link.max_uses > 1,
           p_link.kind = 'trip' and p_link.max_uses > 1,
           s.sender_name,
           case when v_state = 'expired' then null else s.venue_type end,
           case when v_state = 'expired' then null else s.venue_name end,
           case when v_state = 'expired' then null else s.venue_city end,
           case when v_state = 'expired' then null else s.michelin_stars end,
           case when v_state = 'expired' then null else s.michelin_keys end,
           case when v_state = 'expired' then null else s.visited_on end,
           case when v_state = 'expired' then null else s.trip_title end,
           case when v_state = 'expired' then null else s.trip_start_date end,
           case when v_state = 'expired' then null else s.trip_end_date end,
           p_link.expires_at,
           case when v_state = 'expired' then null else p_link.code end
      from public.invite_link_summary(p_link.id) s;
end;
$$;

revoke execute on function public.invite_link_preview_row(public.invite_links) from public, anon, authenticated;

create or replace function public.redeem_invite_link(p_token text, p_add_visit boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_link public.invite_links;
  v_state text;
  v_friendship public.friendships;
  v_became_friends boolean := false;
  v_source public.visits;
  v_visit_id uuid;
  v_visit_present boolean := false;
  v_trip public.planned_trips;
  v_member public.planned_trip_members;
  v_member_id uuid;
  v_status text := 'approved';
  v_trip_state text;
  v_redemption_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  select * into v_link from public.invite_links l where l.token = p_token;
  if v_link.id is null then
    raise exception 'This invitation is no longer available.' using errcode = 'P0002';
  end if;
  select * into v_link from public.invite_links l where l.id = v_link.id for update;

  v_state := public.invite_link_state(v_link, v_uid);
  if v_state = 'own' then
    raise exception 'This is your own invitation.' using errcode = '22023';
  elsif v_state = 'accepted' then
    raise exception 'You have already accepted this invitation.' using errcode = '23505';
  elsif v_state = 'following' then
    raise exception 'You already follow them.' using errcode = '23505';
  elsif v_state = 'expired' then
    raise exception 'This invitation has expired.' using errcode = '22023';
  elsif v_state <> 'open' then
    raise exception 'This invitation is no longer available.' using errcode = '22023';
  end if;

  -- A venue link: follow, and nothing else. No friendship with whoever
  -- shared it and no notification to them; the venue sees only a count.
  if v_link.kind = 'venue' then
    perform public.invite_link_venue_follow(v_link.venue_type, v_link.venue_id, v_uid);
    update public.invite_links set use_count = use_count + 1 where id = v_link.id;
    insert into public.invite_link_redemptions (invite_id, redeemed_by, became_friends, status)
    values (v_link.id, v_uid, false, 'approved')
    returning id into v_redemption_id;
    return jsonb_build_object(
      'redemption_id', v_redemption_id,
      'kind', v_link.kind,
      'became_friends', false,
      'venue_type', v_link.venue_type,
      'venue_id', v_link.venue_id
    );
  end if;

  -- Friends: always the point of the link. Pending or declined either
  -- way becomes accepted: both people have now said yes themselves.
  select * into v_friendship from public.friendships f
   where least(f.requester_id, f.addressee_id) = least(v_link.created_by, v_uid)
     and greatest(f.requester_id, f.addressee_id) = greatest(v_link.created_by, v_uid)
   for update;
  if v_friendship.id is null then
    insert into public.friendships (requester_id, addressee_id, status, responded_at)
    values (v_link.created_by, v_uid, 'accepted', now());
    v_became_friends := true;
  elsif v_friendship.status in ('pending', 'declined') then
    update public.friendships
       set status = 'accepted', responded_at = now()
     where id = v_friendship.id;
    v_became_friends := true;
  end if;

  -- A visit: the recipient's own row, with only the place and the date.
  if v_link.kind = 'visit' and p_add_visit then
    select * into v_source from public.visits v where v.id = v_link.visit_id;
    if exists (
      select 1 from public.visits v
      where v.user_id = v_uid
        and v.entity_type = v_source.entity_type
        and v.entity_id = v_source.entity_id
        and v.visited_on = v_source.visited_on
    ) then
      v_visit_present := true;
    else
      insert into public.visits (
        user_id, entity_type, entity_id, visited_on,
        stars_at_visit, keys_at_visit, shared_from_visit_id
      )
      values (
        v_uid, v_source.entity_type, v_source.entity_id, v_source.visited_on,
        v_source.stars_at_visit, v_source.keys_at_visit, v_source.id
      )
      returning id into v_visit_id;
    end if;
  end if;

  -- A trip: only while the sender is still on it; otherwise the
  -- friendship still goes through.
  if v_link.kind = 'trip' then
    select * into v_trip from public.planned_trips t where t.id = v_link.trip_id;
    if v_trip.user_id = v_uid then
      v_trip_state := 'already_on_trip';
    elsif not public.invite_link_sender_on_trip(v_trip.id, v_link.created_by) then
      v_trip_state := 'sender_left';
    else
      select * into v_member from public.planned_trip_members m
       where m.trip_id = v_trip.id and m.user_id = v_uid
       for update;
      if v_member.status = 'accepted' then
        v_trip_state := 'already_on_trip';
        v_member_id := v_member.id;
      elsif v_member.status = 'pending' then
        -- Invited personally already: this is that invitation's yes.
        update public.planned_trip_members
           set status = 'accepted', responded_at = now()
         where id = v_member.id;
        v_member_id := v_member.id;
        v_trip_state := 'joined';
      elsif v_link.max_uses > 1 then
        v_status := 'awaiting_approval';
        v_trip_state := 'awaiting_approval';
      else
        insert into public.planned_trip_members (trip_id, user_id, invited_by, status, responded_at)
        values (v_trip.id, v_uid, v_link.created_by, 'accepted', now())
        on conflict (trip_id, user_id) do update
          set status = 'accepted', invited_by = excluded.invited_by, responded_at = now()
        returning id into v_member_id;
        v_trip_state := 'joined';
      end if;
    end if;
  end if;

  update public.invite_links set use_count = use_count + 1 where id = v_link.id;

  insert into public.invite_link_redemptions (
    invite_id, redeemed_by, became_friends, visit_id, trip_member_id, status
  )
  values (
    v_link.id, v_uid, v_became_friends, v_visit_id,
    case when v_trip_state = 'joined' then v_member_id end, v_status
  )
  returning id into v_redemption_id;

  insert into public.notifications (recipient_id, type, subject_type, subject_id)
  values (
    v_link.created_by,
    case when v_status = 'awaiting_approval' then 'invite_link_join_request'
         else 'invite_link_accepted' end,
    'invite_link_redemption',
    v_redemption_id
  );

  return jsonb_build_object(
    'redemption_id', v_redemption_id,
    'kind', v_link.kind,
    'became_friends', v_became_friends,
    'visit_id', v_visit_id,
    'visit_already_present', v_visit_present,
    'trip_id', v_link.trip_id,
    'trip_state', v_trip_state
  );
end;
$$;

revoke execute on function public.redeem_invite_link(text, boolean) from public, anon;
grant execute on function public.redeem_invite_link(text, boolean) to authenticated;

create or replace function public.remove_invite_link_redemption(p_redemption_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_redemption public.invite_link_redemptions;
  v_link public.invite_links;
begin
  select * into v_redemption from public.invite_link_redemptions r
   where r.id = p_redemption_id for update;
  select * into v_link from public.invite_links l where l.id = v_redemption.invite_id;

  if v_redemption.id is null
     or v_link.created_by is distinct from auth.uid()
     or v_redemption.status = 'removed'
     or v_link.kind = 'venue' then
    raise exception 'There is nothing to remove.' using errcode = '42501';
  end if;

  if v_redemption.trip_member_id is not null then
    perform public.delete_trip_membership(v_redemption.trip_member_id);
  end if;

  if v_redemption.visit_id is not null then
    delete from public.visits
     where id = v_redemption.visit_id
       and user_id = v_redemption.redeemed_by
       and shared_from_visit_id is not distinct from v_link.visit_id;
  end if;

  if v_redemption.became_friends then
    delete from public.friendships f
     where f.status = 'accepted'
       and least(f.requester_id, f.addressee_id) = least(v_link.created_by, v_redemption.redeemed_by)
       and greatest(f.requester_id, f.addressee_id) = greatest(v_link.created_by, v_redemption.redeemed_by);
  end if;

  update public.invite_link_redemptions
     set status = 'removed', decided_by = auth.uid(), decided_at = now()
   where id = v_redemption.id;

  delete from public.notifications
   where subject_type = 'invite_link_redemption' and subject_id = v_redemption.id;
end;
$$;

revoke execute on function public.remove_invite_link_redemption(uuid) from public, anon;
grant execute on function public.remove_invite_link_redemption(uuid) to authenticated;

create or replace function public.get_my_invite_links()
returns table (
  id uuid,
  token text,
  code text,
  kind text,
  max_uses smallint,
  use_count smallint,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz,
  venue_name text,
  visited_on date,
  trip_title text,
  trip_start_date date,
  trip_end_date date,
  last_used_by_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select l.id, l.token, l.code, l.kind, l.max_uses, l.use_count, l.expires_at,
         l.revoked_at, l.created_at,
         s.venue_name, s.visited_on, s.trip_title, s.trip_start_date, s.trip_end_date,
         (
           select coalesce(nullif(trim(p.display_name), ''), p.username)
             from public.invite_link_redemptions r
             join public.profiles p on p.id = r.redeemed_by
            where r.invite_id = l.id and r.status <> 'removed'
            order by r.redeemed_at desc
            limit 1
         )
    from public.invite_links l
    cross join lateral public.invite_link_summary(l.id) s
   where l.created_by = auth.uid()
     and l.kind <> 'venue'
     and l.created_at > now() - interval '60 days'
   order by l.created_at desc;
$$;

revoke execute on function public.get_my_invite_links() from public, anon;
grant execute on function public.get_my_invite_links() to authenticated;

create or replace function public.get_invite_link_redemptions(p_invite_id uuid)
returns table (
  id uuid,
  user_id uuid,
  username text,
  display_name text,
  status text,
  redeemed_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select r.id, r.redeemed_by, p.username, p.display_name, r.status, r.redeemed_at
    from public.invite_link_redemptions r
    join public.invite_links l on l.id = r.invite_id
    join public.profiles p on p.id = r.redeemed_by
   where r.invite_id = p_invite_id
     and l.created_by = auth.uid()
     and l.kind <> 'venue'
   order by r.redeemed_at;
$$;

revoke execute on function public.get_invite_link_redemptions(uuid) from public, anon;
grant execute on function public.get_invite_link_redemptions(uuid) to authenticated;


-- ============================================================
-- 4. Readers for this build: every kind, the venue included
-- ============================================================

create function public.invite_link_preview_row_v2(p_link public.invite_links)
returns table (
  state text,
  kind text,
  is_group boolean,
  needs_approval boolean,
  sender_name text,
  venue_type text,
  venue_id uuid,
  venue_name text,
  venue_city text,
  venue_country text,
  michelin_stars smallint,
  michelin_keys smallint,
  visited_on date,
  trip_title text,
  trip_start_date date,
  trip_end_date date,
  expires_at timestamptz,
  code text,
  card_photo_url text,
  card_focus_x numeric,
  card_focus_y numeric,
  card_zoom numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_state text;
begin
  if p_link.kind <> 'venue' then
    return query
      select v.state, v.kind, v.is_group, v.needs_approval, v.sender_name,
             v.venue_type, null::uuid, v.venue_name, v.venue_city, null::text,
             v.michelin_stars, v.michelin_keys, v.visited_on, v.trip_title,
             v.trip_start_date, v.trip_end_date, v.expires_at, v.code,
             null::text, null::numeric, null::numeric, null::numeric
        from public.invite_link_preview_row(p_link) v;
    return;
  end if;

  v_state := public.invite_link_state(p_link, auth.uid());
  if v_state = 'unavailable' then
    return query select v_state, null::text, null::boolean, null::boolean,
      null::text, null::text, null::uuid, null::text, null::text, null::text,
      null::smallint, null::smallint, null::date, null::text, null::date,
      null::date, null::timestamptz, null::text,
      null::text, null::numeric, null::numeric, null::numeric;
    return;
  end if;
  return query
    select v_state, p_link.kind, true, false, null::text,
           p_link.venue_type, p_link.venue_id, s.venue_name, s.venue_city,
           s.venue_country, s.michelin_stars, s.michelin_keys,
           null::date, null::text, null::date, null::date,
           null::timestamptz, p_link.code,
           s.card_photo_url, s.card_focus_x, s.card_focus_y, s.card_zoom
      from public.invite_link_venue_summary(p_link.venue_type, p_link.venue_id) s;
end;
$$;

revoke execute on function public.invite_link_preview_row_v2(public.invite_links) from public, anon, authenticated;

create function public.get_invite_link_preview_v2(p_token text)
returns table (
  state text,
  kind text,
  is_group boolean,
  needs_approval boolean,
  sender_name text,
  venue_type text,
  venue_id uuid,
  venue_name text,
  venue_city text,
  venue_country text,
  michelin_stars smallint,
  michelin_keys smallint,
  visited_on date,
  trip_title text,
  trip_start_date date,
  trip_end_date date,
  expires_at timestamptz,
  code text,
  card_photo_url text,
  card_focus_x numeric,
  card_focus_y numeric,
  card_zoom numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_link public.invite_links;
begin
  select * into v_link from public.invite_links l where l.token = p_token;
  if v_link.id is null then
    return query select 'unavailable'::text, null::text, null::boolean, null::boolean,
      null::text, null::text, null::uuid, null::text, null::text, null::text,
      null::smallint, null::smallint, null::date, null::text, null::date,
      null::date, null::timestamptz, null::text,
      null::text, null::numeric, null::numeric, null::numeric;
    return;
  end if;
  return query select * from public.invite_link_preview_row_v2(v_link);
end;
$$;

-- Revoked from PUBLIC and anon, then granted to anon on purpose, as v1:
-- mantelier.app/i/<token> calls it before anyone has an account.
revoke execute on function public.get_invite_link_preview_v2(text) from public, anon;
grant execute on function public.get_invite_link_preview_v2(text) to anon, authenticated;

-- Same rate limit as v1: invite_link_code_lookup counts the misses.
create function public.get_invite_link_preview_by_code_v2(p_code text)
returns table (
  token text,
  state text,
  kind text,
  is_group boolean,
  needs_approval boolean,
  sender_name text,
  venue_type text,
  venue_id uuid,
  venue_name text,
  venue_city text,
  venue_country text,
  michelin_stars smallint,
  michelin_keys smallint,
  visited_on date,
  trip_title text,
  trip_start_date date,
  trip_end_date date,
  expires_at timestamptz,
  code text,
  card_photo_url text,
  card_focus_x numeric,
  card_focus_y numeric,
  card_zoom numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.invite_links;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  v_link := public.invite_link_code_lookup(p_code);
  if v_link.id is null then
    return query select null::text, 'not_found'::text, null::text, null::boolean,
      null::boolean, null::text, null::text, null::uuid, null::text, null::text,
      null::text, null::smallint, null::smallint, null::date, null::text,
      null::date, null::date, null::timestamptz, null::text,
      null::text, null::numeric, null::numeric, null::numeric;
    return;
  end if;
  return query select v_link.token, p.* from public.invite_link_preview_row_v2(v_link) p;
end;
$$;

revoke execute on function public.get_invite_link_preview_by_code_v2(text) from public, anon;
grant execute on function public.get_invite_link_preview_by_code_v2(text) to authenticated;

-- ============================================================
-- 5. The venue's own link, for its managers
-- ============================================================

-- The open link, if there is one, and how many followed through any of
-- the venue's links since the first: under 5 comes back null, and never
-- who.
create function public.get_venue_invite_link(p_venue_type text, p_venue_id uuid)
returns table (
  token text,
  code text,
  created_at timestamptz,
  followed_count bigint,
  followed_since timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Only the venue''s managers can see its link' using errcode = '42501';
  end if;
  return query
    select o.token, o.code, o.created_at,
           public.studio_suppress((
             select count(*) from public.invite_link_redemptions r
               join public.invite_links l on l.id = r.invite_id
              where l.kind = 'venue' and l.venue_type = p_venue_type
                and l.venue_id = p_venue_id and r.status = 'approved'
           )),
           (select min(l.created_at) from public.invite_links l
             where l.kind = 'venue' and l.venue_type = p_venue_type
               and l.venue_id = p_venue_id)
      from (select 1) one
      left join public.invite_links o
        on o.kind = 'venue' and o.venue_type = p_venue_type
       and o.venue_id = p_venue_id and o.revoked_at is null;
end;
$$;

revoke execute on function public.get_venue_invite_link(text, uuid) from public, anon;
grant execute on function public.get_venue_invite_link(text, uuid) to authenticated;

-- The open link, made the first time. p_replace stops the open one and
-- makes a new one, for a link that went somewhere it shouldn't.
create function public.create_venue_invite_link(
  p_venue_type text,
  p_venue_id uuid,
  p_replace boolean default false
)
returns table (token text, code text, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
  v_code text;
  v_bytes bytea;
  v_alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_link public.invite_links;
  i int;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Only the venue''s managers can share its link' using errcode = '42501';
  end if;
  if not public.invite_link_venue_exists(p_venue_type, p_venue_id) then
    raise exception 'This venue can''t be followed yet' using errcode = '22023';
  end if;

  -- Two managers at once get the same link, not a unique violation.
  perform pg_advisory_xact_lock(hashtext('venue_invite:' || p_venue_type || ':' || p_venue_id::text));

  select * into v_link from public.invite_links l
   where l.kind = 'venue' and l.venue_type = p_venue_type
     and l.venue_id = p_venue_id and l.revoked_at is null;
  if v_link.id is not null and not coalesce(p_replace, false) then
    return query select v_link.token, v_link.code, v_link.created_at;
    return;
  end if;
  if v_link.id is not null then
    update public.invite_links set revoked_at = now() where id = v_link.id;
  end if;

  -- Retried on the (astronomically unlikely) collision of either value.
  for attempt in 1..5 loop
    v_token := rtrim(translate(encode(
      decode(replace(gen_random_uuid()::text, '-', ''), 'hex')
      || decode(substr(replace(gen_random_uuid()::text, '-', ''), 1, 2), 'hex'),
      'base64'), '+/', '-_'), '=');
    v_token := left(v_token, 22);
    v_bytes := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
    end loop;
    begin
      insert into public.invite_links (
        token, code, created_by, kind, venue_type, venue_id, max_uses, expires_at
      )
      values (v_token, v_code, v_uid, 'venue', p_venue_type, p_venue_id, null, null)
      returning * into v_link;
      exit;
    exception when unique_violation then
      if attempt = 5 then raise; end if;
    end;
  end loop;

  return query select v_link.token, v_link.code, v_link.created_at;
end;
$$;

revoke execute on function public.create_venue_invite_link(text, uuid, boolean) from public, anon;
grant execute on function public.create_venue_invite_link(text, uuid, boolean) to authenticated;

commit;
