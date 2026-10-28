-- Trips: several destinations per trip, and trips shared with friends.
--
-- Written 2026-10-28 on feature/trips-redesign. NOT applied. Plan and the
-- product owner's decisions: docs/Architecture/
-- TRIPS_MULTI_DESTINATION_AND_SHARING_PLAN.md. Filename: the highest
-- migration on any branch when this was written was 20261020120000
-- (feature/editorial-selection, unapplied); this sorts after it.
--
-- Additive for the shipped 1.2.0 (13) build, which reads/writes
-- planned_trips.country_code (NOT NULL) and city and filters every trips/
-- venues read on its own user_id:
--   * planned_trips keeps both columns, kept equal to the trip's first
--     destination in both directions (triggers + save_trip_destinations);
--   * an installed build never sees trips shared with that user (its
--     .eq('user_id') reads only match its own), nor the new notification
--     types (get_notifications/_v2 and their counts exclude them).
-- Removing planned_trips.country_code/city is a later, third step.
--
-- Every SECURITY DEFINER function below carries its own
-- `revoke execute ... from public, anon` (CLAUDE.md).

begin;

-- ============================================================
-- 1. Tables
-- ============================================================

-- One row per destination (leg). A destination is always something the
-- catalogue knows (decision 1): a country, optionally narrowed to one
-- catalogue city. Pickers key on these codes, never on names.
create table public.planned_trip_destinations (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.planned_trips(id) on delete cascade,
  position      smallint not null check (position >= 0),
  country_code  char(2) not null references public.countries(country_code),
  city_id       uuid references public.cities(id),
  -- This leg's dates. Required on a multi-destination trip (decision 3,
  -- enforced by save_trip_destinations); NULL on a single-destination
  -- trip, whose one leg is the whole trip. Must sit inside the trip's
  -- range (deferred constraint trigger, section 3).
  start_date    date,
  end_date      date,
  created_at    timestamptz not null default now(),
  constraint planned_trip_destinations_dates_pair
    check ((start_date is null) = (end_date is null)),
  constraint planned_trip_destinations_dates_valid
    check (end_date is null or end_date >= start_date),
  unique (trip_id, position)
);

-- The same place twice in one trip is allowed (Paris, then Reims, then
-- Paris again), and legs may overlap in dates (a day trip from Paris) —
-- deliberately no uniqueness on place or dates.
create index planned_trip_destinations_trip_idx
  on public.planned_trip_destinations (trip_id);

-- Who else is on a trip. The owner is planned_trips.user_id and never has
-- a row here, so the shipped build's owner-only reads keep working.
create table public.planned_trip_members (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.planned_trips(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  invited_by    uuid references public.profiles(id) on delete set null,
  status        text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  unique (trip_id, user_id)
);

create index planned_trip_members_user_idx
  on public.planned_trip_members (user_id, status);

-- ============================================================
-- 2. Membership helpers (used by RLS — SECURITY DEFINER so a policy on
--    one of these tables never recurses into its own policies)
-- ============================================================

-- The owner, or an accepted member.
create function public.is_trip_member(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.planned_trips t
    where t.id = p_trip_id and t.user_id = auth.uid()
  ) or exists (
    select 1 from public.planned_trip_members m
    where m.trip_id = p_trip_id
      and m.user_id = auth.uid()
      and m.status = 'accepted'
  );
$$;

revoke execute on function public.is_trip_member(uuid) from public, anon;
grant execute on function public.is_trip_member(uuid) to authenticated;

-- A member, or someone with a pending invitation — enough to see the
-- trip itself (title, dates, destinations) and decide, not its plans.
create function public.can_view_trip(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_trip_member(p_trip_id) or exists (
    select 1 from public.planned_trip_members m
    where m.trip_id = p_trip_id
      and m.user_id = auth.uid()
      and m.status = 'pending'
  );
$$;

revoke execute on function public.can_view_trip(uuid) from public, anon;
grant execute on function public.can_view_trip(uuid) to authenticated;

-- ============================================================
-- 3. Keeping planned_trips and its destinations in step
-- ============================================================

-- Every leg's dates sit inside its trip's dates. A deferred constraint
-- trigger on BOTH tables, so save_trip_destinations can move the trip's
-- dates and its legs in one transaction and be checked once, at commit.
-- An installed build narrowing a multi-leg trip's dates past a leg gets
-- an error instead of a silently clamped leg.
create function public.check_trip_leg_dates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip_id uuid;
begin
  -- Separate statements, not one CASE: NEW has no trip_id on
  -- planned_trips, and PL/pgSQL resolves every field in an expression.
  if tg_table_name = 'planned_trips' then
    v_trip_id := new.id;
  else
    v_trip_id := new.trip_id;
  end if;

  if exists (
    select 1
      from public.planned_trip_destinations d
      join public.planned_trips t on t.id = d.trip_id
     where d.trip_id = v_trip_id
       and d.start_date is not null
       and (d.start_date < t.start_date or d.end_date > t.end_date)
  ) then
    raise exception 'A destination''s dates must fall within the trip''s dates.'
      using errcode = '23514';
  end if;
  return null;
end;
$$;

revoke execute on function public.check_trip_leg_dates() from public, anon;

create constraint trigger planned_trip_destinations_leg_dates
  after insert or update on public.planned_trip_destinations
  deferrable initially deferred
  for each row execute function public.check_trip_leg_dates();

create constraint trigger planned_trips_leg_dates
  after update of start_date, end_date on public.planned_trips
  deferrable initially deferred
  for each row execute function public.check_trip_leg_dates();

-- A trip created any way other than save_trip_destinations (an installed
-- build's plain insert, or the new build's insert before it saves legs)
-- starts with one whole-country destination from its country_code.
create function public.add_default_trip_destination()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.planned_trip_destinations (trip_id, position, country_code)
  values (new.id, 0, new.country_code);
  return null;
end;
$$;

revoke execute on function public.add_default_trip_destination() from public, anon;

create trigger planned_trips_default_destination
  after insert on public.planned_trips
  for each row execute function public.add_default_trip_destination();

-- An installed build changing a trip's country moves the first
-- destination with it (dropping its city, which belonged to the old
-- country). When save_trip_destinations sets country_code it already
-- matches position 0, so this is a no-op there.
create function public.sync_first_trip_destination()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.planned_trip_destinations
     set country_code = new.country_code, city_id = null
   where trip_id = new.id
     and position = (
       select min(position) from public.planned_trip_destinations
        where trip_id = new.id
     )
     and country_code is distinct from new.country_code;
  return null;
end;
$$;

revoke execute on function public.sync_first_trip_destination() from public, anon;

create trigger planned_trips_sync_first_destination
  after update of country_code on public.planned_trips
  for each row
  when (new.country_code is distinct from old.country_code)
  execute function public.sync_first_trip_destination();

-- Backfill: one whole-country destination for every existing trip.
-- Free-text planned_trips.city is NOT mapped to a city_id — that would be
-- matching on a name. It stays on planned_trips.city, still shown.
insert into public.planned_trip_destinations (trip_id, position, country_code)
select t.id, 0, t.country_code
  from public.planned_trips t
 where not exists (
   select 1 from public.planned_trip_destinations d where d.trip_id = t.id
 );

-- ============================================================
-- 4. Saving destinations (owner only)
-- ============================================================

-- Replaces a trip's dates and its whole destination list atomically.
-- p_destinations: a JSON array, in itinerary order, of
--   {"country_code": "FR", "city_id": "<uuid>|null",
--    "start_date": "YYYY-MM-DD"|null, "end_date": "YYYY-MM-DD"|null}
-- Keeps planned_trips.country_code (and the legacy city text the installed
-- build displays) equal to the first destination.
create function public.save_trip_destinations(
  p_trip_id uuid,
  p_start_date date,
  p_end_date date,
  p_destinations jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
  v_first record;
begin
  if not exists (
    select 1 from public.planned_trips
     where id = p_trip_id and user_id = auth.uid()
  ) then
    raise exception 'Only the trip''s owner can change its destinations.'
      using errcode = '42501';
  end if;

  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'A trip needs a start date on or before its end date.'
      using errcode = '23514';
  end if;

  if jsonb_typeof(p_destinations) is distinct from 'array' then
    raise exception 'Destinations must be a list.' using errcode = '22023';
  end if;

  v_count := jsonb_array_length(p_destinations);
  if v_count = 0 then
    raise exception 'A trip needs at least one destination.'
      using errcode = '23514';
  end if;

  -- Decision 3: once there is more than one destination, every leg says
  -- when the traveller is there.
  if v_count > 1 and exists (
    select 1 from jsonb_array_elements(p_destinations) e
     where nullif(e ->> 'start_date', '') is null
        or nullif(e ->> 'end_date', '') is null
  ) then
    raise exception 'Each destination needs its dates when a trip has more than one.'
      using errcode = '23514';
  end if;

  -- A city must belong to its destination's country (codes, not names).
  if exists (
    select 1 from jsonb_array_elements(p_destinations) e
     where nullif(e ->> 'city_id', '') is not null
       and not exists (
         select 1 from public.cities c
          where c.id = (e ->> 'city_id')::uuid
            and c.country_code = upper(e ->> 'country_code')
       )
  ) then
    raise exception 'That city is not in that country.' using errcode = '23503';
  end if;

  update public.planned_trips
     set start_date = p_start_date, end_date = p_end_date
   where id = p_trip_id;

  delete from public.planned_trip_destinations where trip_id = p_trip_id;

  insert into public.planned_trip_destinations
    (trip_id, position, country_code, city_id, start_date, end_date)
  select p_trip_id,
         (e.ord - 1)::smallint,
         upper(e.value ->> 'country_code'),
         nullif(e.value ->> 'city_id', '')::uuid,
         nullif(e.value ->> 'start_date', '')::date,
         nullif(e.value ->> 'end_date', '')::date
    from jsonb_array_elements(p_destinations) with ordinality as e(value, ord);

  select d.country_code, c.name as city_name
    into v_first
    from public.planned_trip_destinations d
    left join public.cities c on c.id = d.city_id
   where d.trip_id = p_trip_id and d.position = 0;

  -- The installed build shows planned_trips.city as display text; keep it
  -- describing the first destination (null for a whole-country one).
  update public.planned_trips
     set country_code = v_first.country_code,
         city = v_first.city_name
   where id = p_trip_id;
end;
$$;

revoke execute on function public.save_trip_destinations(uuid, date, date, jsonb) from public, anon;
grant execute on function public.save_trip_destinations(uuid, date, date, jsonb) to authenticated;

-- ============================================================
-- 5. Notifications: two trip types, for the new build only
-- ============================================================

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
      'trip_invite_accepted'
    ));

alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim',
      'venue_about_submission', 'venue_photo_submission', 'event',
      'planned_trip_member'
    ));

-- Everything get_notifications_v2() returns (its definition in
-- 20261018130000), plus the trip columns. other_user_id for a trip
-- notification is the other party: the inviter for the invitee, the
-- invitee for the inviter.
create function public.get_notifications_v3()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text)
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
      end,
      case when n.subject_type = 'planned_trip_member'
        then case when tm.user_id = auth.uid() then tm.invited_by else tm.user_id end
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
    evh.venue_name as event_venue_name,
    tr.id as trip_id,
    tr.title as trip_title,
    tr.start_date as trip_start_date,
    tr.end_date as trip_end_date,
    tm.status as trip_member_status
  from public.notifications n
  left join public.friendships f
    on n.subject_type = 'friendship' and f.id = n.subject_id
  left join public.venue_invites vi
    on n.subject_type = 'venue_invite' and vi.id = n.subject_id
  left join public.restaurants_full rf
    on vi.venue_type = 'restaurant' and rf.id = vi.venue_id
  left join public.hotels_full hf
    on vi.venue_type = 'hotel' and hf.id = vi.venue_id
  left join public.planned_trip_members tm
    on n.subject_type = 'planned_trip_member' and tm.id = n.subject_id
  left join public.planned_trips tr
    on tr.id = tm.trip_id
  left join public.profiles p
    on p.id = coalesce(
      case when n.subject_type = 'friendship'
        then case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
      end,
      case when n.subject_type = 'venue_invite'
        then case when vi.from_user_id = auth.uid() then vi.to_user_id else vi.from_user_id end
      end,
      case when n.subject_type = 'planned_trip_member'
        then case when tm.user_id = auth.uid() then tm.invited_by else tm.user_id end
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

revoke execute on function public.get_notifications_v3() from public, anon;
grant execute on function public.get_notifications_v3() to authenticated;

-- What the installed 1.2.0 build reads: everything it read before, never
-- the trip types. Same columns and order as 20261018130000's v2, so
-- create or replace is enough; it now reads through v3. get_notifications
-- (v1) already reads through v2, so it inherits the filter.
create or replace function public.get_notifications_v2()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id, type, subject_type, subject_id, is_read, created_at,
         other_user_id, other_username, other_display_name, other_avatar_url,
         listing_subject_type, listing_name, listing_city, invite_venue_type,
         invite_venue_id, invite_venue_name, invite_venue_city, invite_note,
         invite_status, invite_expires_at, claim_venue_type, claim_venue_id,
         claim_venue_name, claim_venue_city, claim_review_note,
         submission_venue_type, submission_venue_id, submission_venue_name,
         submission_venue_city, submission_review_note, friendship_status,
         event_name, event_start_date, event_review_note, event_venue_type,
         event_venue_id, event_venue_name
    from public.get_notifications_v3()
   where type not in ('trip_invite_received', 'trip_invite_accepted');
$function$;

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
      'trip_invite_received', 'trip_invite_accepted'
    );
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
    and type not in ('trip_invite_received', 'trip_invite_accepted');
$$;

create function public.get_unread_notification_count_v3()
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

revoke execute on function public.get_unread_notification_count_v3() from public, anon;
grant execute on function public.get_unread_notification_count_v3() to authenticated;

-- ============================================================
-- 6. Membership RPCs
-- ============================================================

-- Detaches a person's own plans from a trip they no longer belong to —
-- kept as standalone plans, the same as deleting a trip does
-- (planned_venues.trip_id ON DELETE SET NULL). Internal: no grants.
create function public.detach_member_plans(p_trip_id uuid, p_user_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.planned_venues
     set trip_id = null
   where trip_id = p_trip_id and user_id = p_user_id;
$$;

revoke execute on function public.detach_member_plans(uuid, uuid) from public, anon, authenticated;

-- Removes a membership row together with its notifications.
create function public.delete_trip_membership(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member public.planned_trip_members%rowtype;
begin
  delete from public.planned_trip_members where id = p_member_id
  returning * into v_member;
  if v_member.id is null then
    return;
  end if;
  perform public.detach_member_plans(v_member.trip_id, v_member.user_id);
  delete from public.notifications
   where subject_type = 'planned_trip_member' and subject_id = p_member_id;
end;
$$;

revoke execute on function public.delete_trip_membership(uuid) from public, anon, authenticated;

-- Decision 4: any member (the owner or an accepted member) can invite one
-- of their own friends. Re-inviting someone who declined re-opens the row.
create function public.invite_to_trip(p_trip_id uuid, p_friend_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_id uuid;
  v_owner uuid;
begin
  if not public.is_trip_member(p_trip_id) then
    raise exception 'Only someone on this trip can invite to it.'
      using errcode = '42501';
  end if;

  if not public.is_friend(p_friend_id) then
    raise exception 'You can only invite your friends.' using errcode = '42501';
  end if;

  select user_id into v_owner from public.planned_trips where id = p_trip_id;
  if p_friend_id = v_owner then
    raise exception 'That person already owns this trip.' using errcode = '23505';
  end if;

  insert into public.planned_trip_members (trip_id, user_id, invited_by)
  values (p_trip_id, p_friend_id, auth.uid())
  on conflict (trip_id, user_id) do update
    set status = 'pending',
        invited_by = excluded.invited_by,
        created_at = now(),
        responded_at = null
    where planned_trip_members.status = 'declined'
  returning id into v_member_id;

  if v_member_id is null then
    raise exception 'That person is already invited to or on this trip.'
      using errcode = '23505';
  end if;

  insert into public.notifications (recipient_id, type, subject_type, subject_id)
  values (p_friend_id, 'trip_invite_received', 'planned_trip_member', v_member_id);

  return v_member_id;
end;
$$;

revoke execute on function public.invite_to_trip(uuid, uuid) from public, anon;
grant execute on function public.invite_to_trip(uuid, uuid) to authenticated;

create function public.respond_to_trip_invite(p_member_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member public.planned_trip_members%rowtype;
begin
  update public.planned_trip_members
     set status = case when p_accept then 'accepted' else 'declined' end,
         responded_at = now()
   where id = p_member_id
     and user_id = auth.uid()
     and status = 'pending'
  returning * into v_member;

  if v_member.id is null then
    raise exception 'There is no open invitation to answer.'
      using errcode = '42501';
  end if;

  if p_accept and v_member.invited_by is not null then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (v_member.invited_by, 'trip_invite_accepted', 'planned_trip_member', v_member.id);
  end if;
end;
$$;

revoke execute on function public.respond_to_trip_invite(uuid, boolean) from public, anon;
grant execute on function public.respond_to_trip_invite(uuid, boolean) to authenticated;

-- A member leaves; their own plans on the trip become standalone plans.
-- The owner can't leave their own trip (they delete it instead).
create function public.leave_trip(p_trip_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_id uuid;
begin
  select id into v_member_id
    from public.planned_trip_members
   where trip_id = p_trip_id and user_id = auth.uid();
  if v_member_id is null then
    raise exception 'You are not on this trip.' using errcode = '42501';
  end if;
  perform public.delete_trip_membership(v_member_id);
end;
$$;

revoke execute on function public.leave_trip(uuid) from public, anon;
grant execute on function public.leave_trip(uuid) to authenticated;

-- The owner removes anyone; whoever sent an invitation may withdraw it
-- while it's still pending (open point 2, settled as proposed).
create function public.remove_trip_member(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
      from public.planned_trip_members m
      join public.planned_trips t on t.id = m.trip_id
     where m.id = p_member_id
       and (
         t.user_id = auth.uid()
         or (m.invited_by = auth.uid() and m.status = 'pending')
       )
  ) then
    raise exception 'You can''t remove that person from this trip.'
      using errcode = '42501';
  end if;
  perform public.delete_trip_membership(p_member_id);
end;
$$;

revoke execute on function public.remove_trip_member(uuid) from public, anon;
grant execute on function public.remove_trip_member(uuid) to authenticated;

-- Everyone on (or invited to) a trip, with enough profile to show them —
-- members needn't be friends with each other, so profiles' own RLS can't
-- be relied on here. The owner is included with status 'owner'.
create function public.get_trip_members(p_trip_id uuid)
returns table (
  member_id uuid, user_id uuid, status text, invited_by uuid,
  username text, display_name text, avatar_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select null::uuid, t.user_id, 'owner'::text, null::uuid,
         p.username, p.display_name, p.avatar_url
    from public.planned_trips t
    join public.profiles p on p.id = t.user_id
   where t.id = p_trip_id and public.can_view_trip(p_trip_id)
  union all
  select m.id, m.user_id, m.status, m.invited_by,
         p.username, p.display_name, p.avatar_url
    from public.planned_trip_members m
    join public.profiles p on p.id = m.user_id
   where m.trip_id = p_trip_id
     and m.status <> 'declined'
     and public.can_view_trip(p_trip_id);
$$;

revoke execute on function public.get_trip_members(uuid) from public, anon;
grant execute on function public.get_trip_members(uuid) to authenticated;

-- ============================================================
-- 7. Unfriending and blocking (decision 5)
-- ============================================================

-- When two people stop being friends, each is removed from the other's
-- trips that haven't ended yet; past trips are untouched. A trip ending
-- today still counts as current. Trips owned by a third person are left
-- alone (open point 1, settled as proposed).
create function public.remove_from_future_trips_on_unfriend()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_a uuid := coalesce(new.requester_id, old.requester_id);
  v_b uuid := coalesce(new.addressee_id, old.addressee_id);
  v_member_id uuid;
begin
  for v_member_id in
    select m.id
      from public.planned_trip_members m
      join public.planned_trips t on t.id = m.trip_id
     where t.end_date >= current_date
       and (
         (t.user_id = v_a and m.user_id = v_b)
         or (t.user_id = v_b and m.user_id = v_a)
       )
  loop
    perform public.delete_trip_membership(v_member_id);
  end loop;
  return null;
end;
$$;

revoke execute on function public.remove_from_future_trips_on_unfriend() from public, anon;

-- Unfriend = deleting an accepted friendship (friendships_delete policy).
create trigger friendships_unfriend_trips
  after delete on public.friendships
  for each row
  when (old.status = 'accepted')
  execute function public.remove_from_future_trips_on_unfriend();

-- Block = block_user() updating an existing row to 'blocked', or
-- inserting a new blocked row.
create trigger friendships_block_trips_update
  after update of status on public.friendships
  for each row
  when (new.status = 'blocked' and old.status is distinct from 'blocked')
  execute function public.remove_from_future_trips_on_unfriend();

create trigger friendships_block_trips_insert
  after insert on public.friendships
  for each row
  when (new.status = 'blocked')
  execute function public.remove_from_future_trips_on_unfriend();

-- ============================================================
-- 8. RLS
-- ============================================================

alter table public.planned_trip_destinations enable row level security;
alter table public.planned_trip_members enable row level security;

revoke all on public.planned_trip_destinations from anon;
revoke all on public.planned_trip_members from anon;

-- Reads only; every write goes through the RPCs and triggers above.
grant select on public.planned_trip_destinations to authenticated;
grant select on public.planned_trip_members to authenticated;
revoke insert, update, delete on public.planned_trip_destinations from authenticated;
revoke insert, update, delete on public.planned_trip_members from authenticated;

create policy planned_trip_destinations_select on public.planned_trip_destinations
  for select to authenticated
  using (public.can_view_trip(trip_id));

create policy planned_trip_members_select on public.planned_trip_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_trip_member(trip_id));

-- planned_trips: members and pending invitees can read; writes stay
-- owner-only (the existing insert/update/delete policies are unchanged).
drop policy planned_trips_select on public.planned_trips;
create policy planned_trips_select on public.planned_trips
  for select to authenticated
  using (user_id = auth.uid() or public.can_view_trip(id));

-- planned_venues: members see every plan on a shared trip; each person
-- still writes only their own rows, and may only attach a plan to a trip
-- they are on (previously any trip id would have been accepted).
drop policy planned_venues_select on public.planned_venues;
create policy planned_venues_select on public.planned_venues
  for select to authenticated
  using (
    user_id = auth.uid()
    or (trip_id is not null and public.is_trip_member(trip_id))
  );

drop policy planned_venues_insert on public.planned_venues;
create policy planned_venues_insert on public.planned_venues
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (trip_id is null or public.is_trip_member(trip_id))
  );

drop policy planned_venues_update on public.planned_venues;
create policy planned_venues_update on public.planned_venues
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (trip_id is null or public.is_trip_member(trip_id))
  );

commit;
