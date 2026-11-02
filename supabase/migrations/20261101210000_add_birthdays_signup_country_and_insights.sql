-- Birthdays, home country at sign-up, and member insights for admins.
--
-- Decided by the product owner on 2026-11-02:
--   1. A member may add a birth date in Edit profile, optional. On the
--      day, Mantelier wishes them a happy birthday: an in-app notification
--      and a push, no email. They can switch the greeting off.
--   2. The home country (profiles.home_country_code, already editable in
--      Edit profile) may also be given at sign-up, optional.
--   3. Admins see members by country and by age group, as counts only —
--      never a person. A group of fewer than 5 shows no number.
--
-- Privacy:
--   - The birth date lives in its own table, profile_private, readable by
--     its owner alone; profiles stays as readable as it was. Nothing else
--     in the app shows it, to friends or anyone.
--   - At least 16, as the terms require: a later birth date is refused.
--   - Deleting an account deletes the row (on delete cascade from
--     profiles).
--   - Insights read the tables inside a SECURITY DEFINER function and
--     return only grouped counts, with groups under 5 suppressed.
--
-- The daily greeting runs at 07:00 UTC (08:00 or 09:00 in Amsterdam)
-- through pg_cron, enabled here. A 29 February birthday is greeted on 28
-- February in other years. One greeting per member per year, whatever
-- happens to the job.
--
-- Installed builds: a new notification type follows the established
-- pattern (20261030130000): this build's readers become v5, and v4 and
-- the unread counts installed builds call leave 'birthday' out, so an
-- older build neither lists it nor counts it in its badge.
--
-- Every new SECURITY DEFINER function carries its own
-- `revoke execute ... from public, anon` in this file (CLAUDE.md).
--
-- Real date: 2026-11-02. The filename is a sequence number, the next one
-- after the highest existing migration (20261101200000), per CLAUDE.md.

begin;

-- ============================================================
-- 1. Birth date, readable by its owner alone
-- ============================================================

create table public.profile_private (
  user_id           uuid primary key references public.profiles(id) on delete cascade,
  birth_date        date check (birth_date is null or birth_date >= date '1900-01-01'),
  birthday_greeting boolean not null default true,
  updated_at        timestamptz not null default now()
);

comment on table public.profile_private is
  'What a member keeps to themself: their birth date and whether Mantelier '
  'greets them on it. Readable and writable by its owner only.';

alter table public.profile_private enable row level security;

create policy profile_private_own_select on public.profile_private
  for select to authenticated using (user_id = auth.uid());
create policy profile_private_own_insert on public.profile_private
  for insert to authenticated with check (user_id = auth.uid());
create policy profile_private_own_update on public.profile_private
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on table public.profile_private from public, anon, authenticated;
grant select, insert, update on public.profile_private to authenticated;

-- At least 16 (the terms), checked against today rather than in a CHECK,
-- which may not depend on the date.
create function public.check_profile_private()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.birth_date is not null and new.birth_date > (current_date - interval '16 years')::date then
    raise exception 'Mantelier is for members aged 16 and over';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function public.check_profile_private() from public, anon;

create trigger profile_private_check
  before insert or update on public.profile_private
  for each row execute function public.check_profile_private();

-- ============================================================
-- 2. Home country at sign-up
-- ============================================================
-- The sign-up form may send home_country_code in the user metadata. Kept
-- only when it is a country the catalogue knows; anything else is
-- dropped, never an error, so sign-up can't fail on it.

create or replace function public.handle_new_user()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  insert into public.profiles (id, username, display_name, home_country_code)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    new.raw_user_meta_data ->> 'display_name',
    (select c.country_code from public.countries c
      where c.country_code = upper(new.raw_user_meta_data ->> 'home_country_code'))
  );
  return new;
end;
$function$;

revoke execute on function public.handle_new_user() from public, anon;

-- ============================================================
-- 3. The birthday notification
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
      'birthday'
    ));

-- A birthday's subject is the member's own profile.
alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim',
      'venue_about_submission', 'venue_photo_submission', 'event',
      'planned_trip_member', 'profile'
    ));

-- Who has a birthday today, in Amsterdam's calendar, and wants a greeting,
-- and hasn't had one this year. Called once a day by pg_cron; safe to call
-- again (it greets nobody twice in a year).
create function public.send_birthday_greetings()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Europe/Amsterdam')::date;
  v_leap boolean;
  v_count integer;
begin
  v_leap := extract(day from (make_date(extract(year from v_today)::int, 3, 1) - 1)) = 29;
  insert into public.notifications (recipient_id, type, subject_type, subject_id)
  select pp.user_id, 'birthday', 'profile', pp.user_id
    from public.profile_private pp
   where pp.birthday_greeting
     and pp.birth_date is not null
     and (
       (extract(month from pp.birth_date) = extract(month from v_today)
        and extract(day from pp.birth_date) = extract(day from v_today))
       or (not v_leap
           and extract(month from pp.birth_date) = 2 and extract(day from pp.birth_date) = 29
           and extract(month from v_today) = 2 and extract(day from v_today) = 28)
     )
     and not exists (
       select 1 from public.notifications n
        where n.recipient_id = pp.user_id and n.type = 'birthday'
          and (n.created_at at time zone 'Europe/Amsterdam')::date
              >= make_date(extract(year from v_today)::int, 1, 1)
     );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.send_birthday_greetings() from public, anon, authenticated;

create extension if not exists pg_cron;

select cron.schedule(
  'birthday-greetings',
  '0 7 * * *',
  'select public.send_birthday_greetings()'
);

-- The push hand-off gains the type: 20261030130000's function, unchanged
-- apart from the type list.
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
   where type in ('friend_request_received', 'followed_venue_event', 'birthday');
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
-- 4. Readers: v5 for this build, v4 and older without birthdays
-- ============================================================
-- v4 becomes v5 under its new name, body untouched (a birthday row needs
-- no extra columns). A new v4, which installed builds call, is v5 without
-- birthdays; v3 reads v4, and v2 and v1 read v3, so they inherit it. The
-- unread counts follow the same steps.

alter function public.get_notifications_v4() rename to get_notifications_v5;

create function public.get_notifications_v4()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select *
    from public.get_notifications_v5()
   where type <> 'birthday';
$function$;

revoke execute on function public.get_notifications_v4() from public, anon;
grant execute on function public.get_notifications_v4() to authenticated;

alter function public.get_unread_notification_count_v4() rename to get_unread_notification_count_v5;

create function public.get_unread_notification_count_v4()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and is_read = false
    and type <> 'birthday';
$$;

revoke execute on function public.get_unread_notification_count_v4() from public, anon;
grant execute on function public.get_unread_notification_count_v4() to authenticated;

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
    and type not in ('followed_venue_event', 'birthday');
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
      'followed_venue_event', 'birthday'
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
      'followed_venue_event', 'birthday'
    );
$$;

-- ============================================================
-- 5. Member insights for admins: counts only, small groups hidden
-- ============================================================
-- One row per group: dimension 'total', 'country' (bucket is the country
-- code, 'none' when not given) or 'age' (16-24 … 65+, 'none'). members is
-- the count, or null when fewer than 5; new_last_30_days likewise. The
-- total is always given.

create function public.admin_get_member_insights()
returns table (
  dimension text,
  bucket text,
  members integer,
  new_last_30_days integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then raise exception 'Not an admin'; end if;
  return query
  with m as (
    select p.id,
           coalesce(p.home_country_code, 'none') as country,
           p.created_at >= now() - interval '30 days' as is_new,
           case
             when pp.birth_date is null then 'none'
             else case
               when extract(year from age(current_date, pp.birth_date)) < 25 then '16-24'
               when extract(year from age(current_date, pp.birth_date)) < 35 then '25-34'
               when extract(year from age(current_date, pp.birth_date)) < 45 then '35-44'
               when extract(year from age(current_date, pp.birth_date)) < 55 then '45-54'
               when extract(year from age(current_date, pp.birth_date)) < 65 then '55-64'
               else '65+'
             end
           end as age_group
      from public.profiles p
      left join public.profile_private pp on pp.user_id = p.id
  ),
  g as (
    select 'total'::text as dimension, 'all'::text as bucket,
           count(*)::int as n, count(*) filter (where is_new)::int as n_new from m
    union all
    select 'country', country, count(*)::int, count(*) filter (where is_new)::int
      from m group by country
    union all
    select 'age', age_group, count(*)::int, count(*) filter (where is_new)::int
      from m group by age_group
  )
  -- The total says nothing about anyone, so it is never hidden.
  select g.dimension, g.bucket,
         case when g.n < 5 and g.dimension <> 'total' then null else g.n end,
         case when g.n_new < 5 and g.dimension <> 'total' then null else g.n_new end
    from g;
end;
$$;

revoke execute on function public.admin_get_member_insights() from public, anon;
grant execute on function public.admin_get_member_insights() to authenticated;

commit;
