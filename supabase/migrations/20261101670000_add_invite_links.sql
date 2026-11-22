-- Invite links: a member shares a link from a visit, a trip or Friends.
-- Whoever opens it, signs in and taps Accept becomes friends with the
-- sender straight away and, for a visit, gets the same dinner in their
-- own Passport; for a trip, a place on it.
--
-- Written 2026-11-22. Plan and decisions (product owner, 2026-11-22):
-- https://claude.ai/artifact/RtHCcxFjz7pHsqcPBiGJ24
--   - a link is for one person or for a group (up to 12), chosen when
--     sharing; open for 14 days, trips included;
--   - nothing happens without the recipient's Accept;
--   - joining a trip through a GROUP link waits until the sender or the
--     trip's owner lets the person in; a one-person link joins directly;
--   - the sender can undo one person's use afterwards ("Remove");
--   - a shared visit keeps the sender's date: only the sender changes it,
--     and a change follows to every copy. If the sender deletes the
--     visit, the copy stays as the recipient's own and its date is free.
--
-- The public page mantelier.app/i/<token> reads get_invite_link_preview
-- as anon: the one function here deliberately executable by anon. It
-- shows the sender's name, the place and date, or a trip's name and
-- months (approved by the product owner), and nothing else. Lookup by
-- the short typed code is for signed-in members only and rate limited,
-- since 8 characters can be guessed where a 128-bit token cannot.
--
-- Notifications: four new types under a new subject_type. get_notifications_v7
-- returns them; v6 and every older reader, and every unread count, leave
-- them out, the way each earlier type was added.

begin;

-- ============================================================
-- 1. Tables
-- ============================================================

create table public.invite_links (
  id          uuid primary key default gen_random_uuid(),
  -- 22 url-safe characters from 128 random bits: what the URL carries.
  token       text not null unique,
  -- 8 characters of Crockford base32, for typing when the link is lost.
  code        text not null unique,
  created_by  uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('friend', 'visit', 'trip')),
  visit_id    uuid references public.visits(id) on delete cascade,
  trip_id     uuid references public.planned_trips(id) on delete cascade,
  -- 1 is a link for one person; more is a group link.
  max_uses    smallint not null default 1 check (max_uses between 1 and 12),
  use_count   smallint not null default 0 check (use_count >= 0),
  expires_at  timestamptz not null default (now() + interval '14 days'),
  revoked_at  timestamptz,
  created_at  timestamptz not null default now(),
  constraint invite_links_visit_target check ((kind = 'visit') = (visit_id is not null)),
  constraint invite_links_trip_target check ((kind = 'trip') = (trip_id is not null))
);

create index invite_links_created_by_idx on public.invite_links (created_by, created_at desc);

create table public.invite_link_redemptions (
  id              uuid primary key default gen_random_uuid(),
  invite_id       uuid not null references public.invite_links(id) on delete cascade,
  redeemed_by     uuid not null references public.profiles(id) on delete cascade,
  redeemed_at     timestamptz not null default now(),
  -- True only when this use created or accepted the friendship, so a
  -- Remove never ends a friendship that existed before the link.
  became_friends  boolean not null,
  visit_id        uuid references public.visits(id) on delete set null,
  trip_member_id  uuid references public.planned_trip_members(id) on delete set null,
  -- A trip through a group link waits as awaiting_approval and gets its
  -- planned_trip_members row only when approved, so planned_trip_members
  -- never holds a status a shipped build doesn't know.
  status          text not null default 'approved'
    check (status in ('approved', 'awaiting_approval', 'declined', 'removed')),
  decided_by      uuid references public.profiles(id) on delete set null,
  decided_at      timestamptz,
  unique (invite_id, redeemed_by)
);

create index invite_link_redemptions_redeemed_by_idx
  on public.invite_link_redemptions (redeemed_by);

-- Failed lookups by code, to rate limit guessing. Read and written only
-- by the RPCs below.
create table public.invite_link_code_attempts (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  attempted_at  timestamptz not null default now()
);

create index invite_link_code_attempts_user_idx
  on public.invite_link_code_attempts (user_id, attempted_at desc);

alter table public.invite_links enable row level security;
alter table public.invite_link_redemptions enable row level security;
alter table public.invite_link_code_attempts enable row level security;

-- The sender reads their own links; the person who used one and the
-- sender read its uses. No insert, update or delete policy: every write
-- goes through the RPCs below.
create policy invite_links_select on public.invite_links
  for select to authenticated
  using (created_by = auth.uid());

create policy invite_link_redemptions_select on public.invite_link_redemptions
  for select to authenticated
  using (
    redeemed_by = auth.uid()
    or exists (
      select 1 from public.invite_links l
      where l.id = invite_id and l.created_by = auth.uid()
    )
  );

revoke all on public.invite_links from anon, authenticated;
revoke all on public.invite_link_redemptions from anon, authenticated;
revoke all on public.invite_link_code_attempts from anon, authenticated;
grant select on public.invite_links to authenticated;
grant select on public.invite_link_redemptions to authenticated;

-- ============================================================
-- 2. A shared visit's date follows the sender's
-- ============================================================

alter table public.visits
  add column shared_from_visit_id uuid references public.visits(id) on delete set null;

create index visits_shared_from_idx
  on public.visits (shared_from_visit_id)
  where shared_from_visit_id is not null;

-- RLS can't limit which columns an update touches, so a trigger does,
-- the way the venue photo framing columns are guarded. A member's own
-- write (current_user authenticated) may never set or change
-- shared_from_visit_id, nor change the date of a visit that is still a
-- copy. redeem_invite_link and the propagation below run as the owner;
-- so does the foreign key's own "set null" when the sender's visit goes.
create function public.visits_guard_shared_copy()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.shared_from_visit_id is not null then
      raise exception 'A shared visit can only be added through its invitation'
        using errcode = '42501';
    end if;
    return new;
  end if;
  if new.shared_from_visit_id is distinct from old.shared_from_visit_id then
    raise exception 'A shared visit stays linked to the original'
      using errcode = '42501';
  end if;
  if old.shared_from_visit_id is not null
     and new.visited_on is distinct from old.visited_on then
    raise exception 'The date of a shared visit is set by whoever shared it'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke execute on function public.visits_guard_shared_copy() from public, anon;

create trigger visits_guard_shared_copy
  before insert or update on public.visits
  for each row execute function public.visits_guard_shared_copy();

-- The sender moves the date: every copy moves with it. Stars and Keys
-- stay as each visit recorded them (visits_freeze_award_and_date keeps
-- them on update).
create function public.visits_propagate_shared_date()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.visits
     set visited_on = new.visited_on
   where shared_from_visit_id = new.id
     and visited_on is distinct from new.visited_on;
  return null;
end;
$$;

revoke execute on function public.visits_propagate_shared_date() from public, anon, authenticated;

create trigger visits_propagate_shared_date
  after update of visited_on on public.visits
  for each row
  when (new.visited_on is distinct from old.visited_on)
  execute function public.visits_propagate_shared_date();

-- ============================================================
-- 3. Helpers (internal: not callable by anyone but the owner)
-- ============================================================

-- 'O' reads as 0 and 'I'/'L' as 1, spaces and dashes are dropped: what
-- someone types from a screenshot still finds the code.
create function public.invite_link_normalize_code(p_value text)
returns text
language sql
immutable
set search_path = public
as $$
  select translate(upper(regexp_replace(coalesce(p_value, ''), '[\s-]', '', 'g')), 'OIL', '011');
$$;

revoke execute on function public.invite_link_normalize_code(text) from public, anon, authenticated;

-- Whether the sender is still on the trip: its owner or an accepted member.
create function public.invite_link_sender_on_trip(p_trip_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.planned_trips t
    where t.id = p_trip_id and t.user_id = p_user_id
  ) or exists (
    select 1 from public.planned_trip_members m
    where m.trip_id = p_trip_id and m.user_id = p_user_id and m.status = 'accepted'
  );
$$;

revoke execute on function public.invite_link_sender_on_trip(uuid, uuid) from public, anon, authenticated;

-- What a link points at, for the page, the app and the sender's list.
-- Never ids, never a username: the sender's display name and the place.
create function public.invite_link_summary(p_invite_id uuid)
returns table (
  sender_name text,
  venue_type text,
  venue_name text,
  venue_city text,
  michelin_stars smallint,
  michelin_keys smallint,
  visited_on date,
  trip_title text,
  trip_start_date date,
  trip_end_date date
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(nullif(trim(p.display_name), ''), p.username),
    v.entity_type,
    coalesce(r.name, h.name),
    coalesce(rc.name, hc.name),
    v.stars_at_visit,
    v.keys_at_visit,
    v.visited_on,
    t.title,
    t.start_date,
    t.end_date
  from public.invite_links l
  join public.profiles p on p.id = l.created_by
  left join public.visits v on v.id = l.visit_id
  left join public.restaurants r on v.entity_type = 'restaurant' and r.id = v.entity_id
  left join public.cities rc on rc.id = r.city_id
  left join public.hotels h on v.entity_type = 'hotel' and h.id = v.entity_id
  left join public.cities hc on hc.id = h.city_id
  left join public.planned_trips t on t.id = l.trip_id
  where l.id = p_invite_id;
$$;

revoke execute on function public.invite_link_summary(uuid) from public, anon, authenticated;

-- ============================================================
-- 4. Creating, previewing and revoking a link
-- ============================================================

create function public.create_invite_link(
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
    where l.created_by = v_uid and l.revoked_at is null and l.expires_at > now()
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

-- The state of a link for whoever is looking: 'open', 'expired',
-- 'unavailable' (used up, cancelled, trip over or gone, or a block
-- between the two people: deliberately one neutral word), and for a
-- signed-in viewer 'own' or 'accepted'.
create function public.invite_link_state(p_link public.invite_links, p_viewer uuid)
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
    when p_viewer is not null and exists (
      select 1 from public.friendships f
      where f.status = 'blocked'
        and least(f.requester_id, f.addressee_id) = least(p_link.created_by, p_viewer)
        and greatest(f.requester_id, f.addressee_id) = greatest(p_link.created_by, p_viewer)
    ) then 'unavailable'
    else 'open'
  end;
$$;

revoke execute on function public.invite_link_state(public.invite_links, uuid) from public, anon, authenticated;

create function public.invite_link_preview_row(p_link public.invite_links)
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
  if v_state = 'unavailable' then
    return query select v_state, null::text, null::boolean, null::boolean,
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

-- The web page and the app before sign-in: by token only. Deliberately
-- granted to anon below. An unknown token answers 'unavailable', the
-- same as a used one.
create function public.get_invite_link_preview(p_token text)
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
  v_link public.invite_links;
begin
  select * into v_link from public.invite_links l where l.token = p_token;
  if v_link.id is null then
    return query select 'unavailable'::text, null::text, null::boolean, null::boolean,
      null::text, null::text, null::text, null::text, null::smallint, null::smallint,
      null::date, null::text, null::date, null::date, null::timestamptz, null::text;
    return;
  end if;
  return query select * from public.invite_link_preview_row(v_link);
end;
$$;

-- Revoked from PUBLIC and anon like every other function here, then
-- granted to anon on purpose: mantelier.app/i/<token> calls it before
-- anyone has an account. It returns only the summary above.
revoke execute on function public.get_invite_link_preview(text) from public, anon;
grant execute on function public.get_invite_link_preview(text) to anon, authenticated;

-- Ten failed codes an hour per member, then a pause.
create function public.invite_link_code_lookup(p_code text)
returns public.invite_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_link public.invite_links;
begin
  if (
    select count(*) from public.invite_link_code_attempts a
    where a.user_id = v_uid and a.attempted_at > now() - interval '1 hour'
  ) >= 10 then
    raise exception 'Too many codes tried. Please wait an hour and try again.'
      using errcode = '54000';
  end if;
  select * into v_link from public.invite_links l
   where l.code = public.invite_link_normalize_code(p_code);
  if v_link.id is null then
    insert into public.invite_link_code_attempts (user_id) values (v_uid);
  end if;
  return v_link;
end;
$$;

revoke execute on function public.invite_link_code_lookup(text) from public, anon, authenticated;

-- Volatile, not stable: a miss writes an attempt. A miss answers with a
-- row in state 'not_found' rather than an error, since an error would roll
-- the attempt back and the limit would never count.
create function public.get_invite_link_preview_by_code(p_code text)
returns table (
  token text,
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
      null::boolean, null::text, null::text, null::text, null::text, null::smallint,
      null::smallint, null::date, null::text, null::date, null::date,
      null::timestamptz, null::text;
    return;
  end if;
  return query select v_link.token, p.* from public.invite_link_preview_row(v_link) p;
end;
$$;

revoke execute on function public.get_invite_link_preview_by_code(text) from public, anon;
grant execute on function public.get_invite_link_preview_by_code(text) to authenticated;

create function public.revoke_invite_link(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.invite_links
     set revoked_at = now()
   where id = p_invite_id
     and created_by = auth.uid()
     and revoked_at is null;
  if not found then
    raise exception 'That link is no longer open' using errcode = '42501';
  end if;
end;
$$;

revoke execute on function public.revoke_invite_link(uuid) from public, anon;
grant execute on function public.revoke_invite_link(uuid) to authenticated;

-- ============================================================
-- 5. Notifications: types, subject, push hand-off
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
      'trip_invite_accepted',
      'followed_venue_event',
      'birthday',
      'booking_window_opening',
      -- to the sender: someone accepted their link
      'invite_link_accepted',
      -- to the sender: someone wants to join their trip through a group link
      'invite_link_join_request',
      -- to the person who used the link: let in, or not
      'invite_link_join_approved',
      'invite_link_join_declined'
    ));

alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim',
      'venue_about_submission', 'venue_photo_submission', 'event',
      'planned_trip_member', 'profile', 'booking_reminder',
      'invite_link_redemption'
    ));

-- 20261101400000's function, unchanged apart from the type list.
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
                  'booking_window_opening', 'invite_link_accepted',
                  'invite_link_join_request');
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
-- 6. Using a link
-- ============================================================

-- Accept: in one transaction, with the link locked so a group link can't
-- be used past its maximum by two people at once. Every refusal is one
-- of three plain sentences; a block reads exactly like a used link.
-- By token only: a typed code is first turned into its token by
-- get_invite_link_preview_by_code, which is where guessing is counted.
create function public.redeem_invite_link(p_token text, p_add_visit boolean default true)
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
  elsif v_state = 'expired' then
    raise exception 'This invitation has expired.' using errcode = '22023';
  elsif v_state <> 'open' then
    raise exception 'This invitation is no longer available.' using errcode = '22023';
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

-- Let someone in, or not: the sender or the trip's owner.
create function public.decide_invite_link_join(p_redemption_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_redemption public.invite_link_redemptions;
  v_link public.invite_links;
  v_trip public.planned_trips;
  v_member_id uuid;
begin
  select * into v_redemption from public.invite_link_redemptions r
   where r.id = p_redemption_id for update;
  select * into v_link from public.invite_links l where l.id = v_redemption.invite_id;
  select * into v_trip from public.planned_trips t where t.id = v_link.trip_id;

  if v_redemption.id is null
     or v_redemption.status <> 'awaiting_approval'
     or v_uid is null
     or v_uid not in (v_link.created_by, v_trip.user_id) then
    raise exception 'There is no request to answer.' using errcode = '42501';
  end if;

  if p_approve then
    if v_trip.end_date < current_date then
      raise exception 'This trip is over.' using errcode = '22023';
    end if;
    insert into public.planned_trip_members (trip_id, user_id, invited_by, status, responded_at)
    values (v_trip.id, v_redemption.redeemed_by, v_link.created_by, 'accepted', now())
    on conflict (trip_id, user_id) do update
      set status = 'accepted', responded_at = now()
    returning id into v_member_id;
  end if;

  update public.invite_link_redemptions
     set status = case when p_approve then 'approved' else 'declined' end,
         trip_member_id = v_member_id,
         decided_by = v_uid,
         decided_at = now()
   where id = v_redemption.id;

  -- The request is answered: it leaves the sender's list.
  delete from public.notifications
   where type = 'invite_link_join_request'
     and subject_type = 'invite_link_redemption'
     and subject_id = v_redemption.id;

  insert into public.notifications (recipient_id, type, subject_type, subject_id)
  values (
    v_redemption.redeemed_by,
    case when p_approve then 'invite_link_join_approved' else 'invite_link_join_declined' end,
    'invite_link_redemption',
    v_redemption.id
  );
end;
$$;

revoke execute on function public.decide_invite_link_join(uuid, boolean) from public, anon;
grant execute on function public.decide_invite_link_join(uuid, boolean) to authenticated;

-- Undo one person's use: the friendship it made, the visit it copied,
-- the place on the trip. The person is not notified, as with unfriending.
-- Their place in the maximum does not come back.
create function public.remove_invite_link_redemption(p_redemption_id uuid)
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
     or v_redemption.status = 'removed' then
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

-- ============================================================
-- 7. The sender's lists
-- ============================================================

-- Links of the last 60 days, open or used, newest first.
create function public.get_my_invite_links()
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
     and l.created_at > now() - interval '60 days'
   order by l.created_at desc;
$$;

revoke execute on function public.get_my_invite_links() from public, anon;
grant execute on function public.get_my_invite_links() to authenticated;

-- Who used one of the caller's links.
create function public.get_invite_link_redemptions(p_invite_id uuid)
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
   order by r.redeemed_at;
$$;

revoke execute on function public.get_invite_link_redemptions(uuid) from public, anon;
grant execute on function public.get_invite_link_redemptions(uuid) to authenticated;

-- ============================================================
-- 8. Readers: v7 for this build; v6 and older without the new types
-- ============================================================
-- v6's body becomes get_notifications_v7_base, untouched. v7 adds the
-- link's columns and fills other_user_* for the new subject; a new v6,
-- which installed builds call, is the base without the new types. v5 is
-- the reader every older one goes through, so it gets the same filter.
-- The unread counts follow the same steps.

alter function public.get_notifications_v6() rename to get_notifications_v7_base;
revoke execute on function public.get_notifications_v7_base() from public, anon, authenticated;

create function public.get_notifications_v7()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text, link_kind text, link_venue_name text, link_visited_on date, link_trip_id uuid, link_trip_title text, link_redemption_status text, link_became_friends boolean, link_visit_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    n.id, n.type, n.subject_type, n.subject_id, n.is_read, n.created_at,
    coalesce(n.other_user_id, lp.id),
    coalesce(n.other_username, lp.username),
    coalesce(n.other_display_name, lp.display_name),
    coalesce(n.other_avatar_url, lp.avatar_url),
    n.listing_subject_type, n.listing_name, n.listing_city,
    n.invite_venue_type, n.invite_venue_id, n.invite_venue_name, n.invite_venue_city,
    n.invite_note, n.invite_status, n.invite_expires_at,
    n.claim_venue_type, n.claim_venue_id, n.claim_venue_name, n.claim_venue_city,
    n.claim_review_note,
    n.submission_venue_type, n.submission_venue_id, n.submission_venue_name,
    n.submission_venue_city, n.submission_review_note,
    n.friendship_status,
    n.event_name, n.event_start_date, n.event_review_note, n.event_venue_type,
    n.event_venue_id, n.event_venue_name,
    n.trip_id, n.trip_title, n.trip_start_date, n.trip_end_date, n.trip_member_status,
    n.booking_restaurant_id, n.booking_restaurant_name, n.booking_planned_month,
    n.booking_opens_on, n.booking_opens_time, n.booking_timezone,
    l.kind,
    s.venue_name,
    s.visited_on,
    l.trip_id,
    s.trip_title,
    r.status,
    r.became_friends,
    r.visit_id
  from public.get_notifications_v7_base() n
  left join public.invite_link_redemptions r
    on n.subject_type = 'invite_link_redemption' and r.id = n.subject_id
  left join public.invite_links l on l.id = r.invite_id
  left join lateral public.invite_link_summary(l.id) s on l.id is not null
  -- The other person: whoever used the link when the sender reads it,
  -- the sender when the person who used it reads it.
  left join public.profiles lp
    on r.id is not null
   and lp.id = case when r.redeemed_by = auth.uid() then l.created_by else r.redeemed_by end;
$function$;

revoke execute on function public.get_notifications_v7() from public, anon;
grant execute on function public.get_notifications_v7() to authenticated;

create function public.get_notifications_v6()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text, booking_restaurant_id uuid, booking_restaurant_name text, booking_planned_month date, booking_opens_on date, booking_opens_time time, booking_timezone text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v7_base()
   where type not in ('invite_link_accepted', 'invite_link_join_request',
                      'invite_link_join_approved', 'invite_link_join_declined');
$function$;

revoke execute on function public.get_notifications_v6() from public, anon;
grant execute on function public.get_notifications_v6() to authenticated;

-- Same signature as before, so create or replace keeps v4 and older
-- reading through it.
create or replace function public.get_notifications_v5()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v6_rows()
   where type not in ('booking_window_opening',
                      'invite_link_accepted', 'invite_link_join_request',
                      'invite_link_join_approved', 'invite_link_join_declined');
$function$;

alter function public.get_unread_notification_count_v6() rename to get_unread_notification_count_v7;

create function public.get_unread_notification_count_v6()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in ('invite_link_accepted', 'invite_link_join_request',
                     'invite_link_join_approved', 'invite_link_join_declined');
$$;

revoke execute on function public.get_unread_notification_count_v6() from public, anon;
grant execute on function public.get_unread_notification_count_v6() to authenticated;

create or replace function public.get_unread_notification_count_v5()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type not in ('booking_window_opening',
                     'invite_link_accepted', 'invite_link_join_request',
                     'invite_link_join_approved', 'invite_link_join_declined');
$$;

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
    and type not in ('birthday', 'booking_window_opening',
                     'invite_link_accepted', 'invite_link_join_request',
                     'invite_link_join_approved', 'invite_link_join_declined');
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
    and type not in ('followed_venue_event', 'birthday', 'booking_window_opening',
                     'invite_link_accepted', 'invite_link_join_request',
                     'invite_link_join_approved', 'invite_link_join_declined');
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
      'followed_venue_event', 'birthday', 'booking_window_opening',
      'invite_link_accepted', 'invite_link_join_request',
      'invite_link_join_approved', 'invite_link_join_declined'
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
      'followed_venue_event', 'birthday', 'booking_window_opening',
      'invite_link_accepted', 'invite_link_join_request',
      'invite_link_join_approved', 'invite_link_join_declined'
    );
$$;

commit;
