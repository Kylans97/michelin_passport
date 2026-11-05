-- SIGNUP WATCH: a weekly email about sign-ups that look automated. Written
-- 2026-11-04, asked for by the product owner. At this date production has
-- 25 accounts and nothing suspicious; this is here so a wave of fake
-- accounts is seen before it skews what venues read in Studio, or fills
-- the 5-person threshold that keeps real members anonymous.
--
-- It only reports. It blocks nothing, changes no account and stores
-- nothing: there is no new table, and every number is counted again from
-- auth.users when it runs. No address and no user id leaves this function.
-- The one thing named is an email domain, and only an uncommon one with 3
-- or more new accounts in the week.
--
-- signup_watch_report(until) counts the 7 days before `until` and sets a
-- flag for each of these:
--   many_signups   20 or more, and at least 3x the average of the 4 weeks
--                  before;
--   burst          10 or more in one clock hour;
--   unconfirmed    10 or more who didn't confirm their address, or 5 or
--                  more who together are at least half of the week;
--   shared_domain  3 or more on one domain outside the common mail
--                  providers (a disposable mail service, typically);
--   aliases        3 or more that are one mailbox: the part after a + is
--                  ignored everywhere, dots too at Gmail.
-- A flag means look, not that something is wrong: a launch or a mention
-- in the press sets off many_signups too. The numbers are starting points
-- chosen for an app this size, to raise when they turn out too low.
--
-- It can't see a patient bot: a few accounts a week on different real
-- mailboxes looks like members. Accounts deleted since signing up aren't
-- counted either.
--
-- The email goes out every week, also a quiet one, so that a week without
-- mail means the watch itself is broken rather than that all is well.
--
-- Same chain as the other admin emails: pg_cron -> pg_net -> the
-- notify-signup-watch Edge Function -> Resend. Its own secret, by this
-- project's one-secret-per-function convention. Out of band, before this
-- sends anything:
--   select vault.create_secret('<value>', 'notify_signup_watch_webhook_secret', ...);
--   supabase secrets set NOTIFY_SIGNUP_WATCH_WEBHOOK_SECRET=<value>
--   supabase functions deploy notify-signup-watch
-- A missing secret is a logged warning, nothing more.
--
-- Two new SECURITY DEFINER functions, each with its revoke below
-- (CLAUDE.md), authenticated included: only cron calls them, and the
-- report can also be run by hand from the dashboard.

begin;

create function public.signup_watch_report(p_until timestamptz default now())
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with common_domains(domain) as (
    values
      ('gmail.com'), ('outlook.com'), ('hotmail.com'), ('live.com'),
      ('msn.com'), ('icloud.com'), ('me.com'), ('mac.com'), ('yahoo.com'),
      ('aol.com'), ('gmx.com'), ('gmx.de'), ('proton.me'), ('protonmail.com'),
      ('hotmail.nl'), ('outlook.nl'), ('live.nl'), ('ziggo.nl'), ('kpnmail.nl'),
      ('xs4all.nl'), ('planet.nl'), ('home.nl'), ('telenet.be'), ('skynet.be'),
      ('hotmail.be'), ('outlook.be'), ('live.be'), ('hotmail.fr'), ('outlook.fr'),
      ('orange.fr'), ('hotmail.co.uk'), ('web.de'), ('t-online.de')
  ),
  week as (
    select u.created_at,
           u.email_confirmed_at,
           -- googlemail.com is the same mailbox as gmail.com.
           replace(split_part(lower(u.email), '@', 2), 'googlemail.com', 'gmail.com') as domain,
           split_part(split_part(lower(u.email), '@', 1), '+', 1) as local_part
      from auth.users u
     where u.created_at >= p_until - interval '7 days'
       and u.created_at < p_until
  ),
  counts as (
    select count(*) as signups,
           count(*) filter (where email_confirmed_at is null) as unconfirmed
      from week
  ),
  before as (
    select count(*) / 4.0 as weekly_average
      from auth.users u
     where u.created_at >= p_until - interval '35 days'
       and u.created_at < p_until - interval '7 days'
  ),
  busiest as (
    select coalesce(max(n), 0) as hour_count
      from (select count(*) as n from week group by date_trunc('hour', created_at)) h
  ),
  domains as (
    select domain, count(*) as accounts
      from week
     where domain <> ''
       and domain not in (select domain from common_domains)
     group by domain
    having count(*) >= 3
  ),
  mailboxes as (
    select count(*) as accounts
      from week
     where domain <> ''
     group by domain,
              case when domain = 'gmail.com' then replace(local_part, '.', '') else local_part end
    having count(*) >= 3
  ),
  flags as (
    select array_remove(array[
             case when c.signups >= 20 and c.signups >= 3 * b.weekly_average
                  then 'many_signups' end,
             case when h.hour_count >= 10 then 'burst' end,
             case when c.unconfirmed >= 10
                    or (c.unconfirmed >= 5 and c.unconfirmed * 2 >= c.signups)
                  then 'unconfirmed' end,
             case when exists (select 1 from domains) then 'shared_domain' end,
             case when exists (select 1 from mailboxes) then 'aliases' end
           ], null) as names
      from counts c, before b, busiest h
  )
  select jsonb_build_object(
    'until', p_until,
    'signups', c.signups,
    'unconfirmed', c.unconfirmed,
    'weekly_average_before', round(b.weekly_average, 1),
    'busiest_hour', h.hour_count,
    'total_accounts', (select count(*) from auth.users),
    'shared_domains', coalesce(
      (select jsonb_agg(jsonb_build_object('domain', d.domain, 'accounts', d.accounts)
                        order by d.accounts desc, d.domain)
         from domains d),
      '[]'::jsonb),
    'alias_groups', (select count(*) from mailboxes),
    'flags', to_jsonb(f.names)
  )
  from counts c, before b, busiest h, flags f;
$$;

revoke execute on function public.signup_watch_report(timestamptz) from public, anon, authenticated;

create function public.send_signup_watch()
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
    from vault.decrypted_secrets
   where name = 'notify_signup_watch_webhook_secret';

  if v_secret is null then
    raise warning 'send_signup_watch: webhook secret not found in vault — skipping this week';
    return;
  end if;

  perform net.http_post(
    url := 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/notify-signup-watch',
    body := public.signup_watch_report(),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    timeout_milliseconds := 5000
  );
end;
$$;

revoke execute on function public.send_signup_watch() from public, anon, authenticated;

-- Mondays at 07:00 UTC.
select cron.schedule(
  'signup-watch',
  '0 7 * * 1',
  'select public.send_signup_watch()'
);

commit;
