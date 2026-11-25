-- Website sign-ins, counted for Studio's Website tab. Written 2026-11-25.
--
-- Product owner, 2026-11-25, on the plan for website visitor numbers in
-- Studio: "ja graag voor 3" (count how many members signed in on the
-- website, with one added sentence in the privacy policy). The privacy
-- policy sentence ships before this is applied, the same order as every
-- other tracking change.
--
-- One row each time a member finishes signing in on mantelier.app
-- (password, Apple or email code, and two-step where they have it). The
-- website writes it itself, best effort; nothing is recorded for the app,
-- which signs in through its own screens and is counted in
-- app_usage_events already. Cloudflare's visitor numbers cannot be joined
-- to this: they hold no person, so these are two separate counts.
--
-- Same shape as app_usage_events: self-attributed insert only, no read
-- policy for any client role, cascades from profiles on account deletion.
-- Kept 24 months like every other raw usage table (20261101260000), then
-- only the monthly total remains in usage_monthly_totals, with no user id:
-- prune_website_sign_ins() runs monthly through pg_cron, five minutes after
-- prune_usage_records(). A separate function rather than a new version of
-- prune_usage_records(), so this migration does not replace that one.
--
-- admin_studio_website_report(p_days) returns the counts for Studio, with
-- the same guard as admin_studio_report: aal2 first, then is_admin(). The
-- studio-web-analytics Edge Function calls it as the signed-in admin before
-- it asks Cloudflare anything, so it is also that function's admin check.

begin;

create table public.website_sign_ins (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  signed_in_at timestamptz not null default now()
);

create index website_sign_ins_at_idx on public.website_sign_ins (signed_in_at desc);
create index website_sign_ins_user_idx on public.website_sign_ins (user_id);

alter table public.website_sign_ins enable row level security;

-- signed_in_at is left to its default: a client may not backdate a row.
create policy website_sign_ins_insert on public.website_sign_ins
  for insert to authenticated
  with check (user_id = auth.uid() and signed_in_at >= now() - interval '1 minute');

grant insert on public.website_sign_ins to authenticated;

create function public.admin_studio_website_report(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days   integer := least(greatest(coalesce(p_days, 30), 1), 365);
  v_since  timestamptz := now() - make_interval(days => v_days);
  v_before timestamptz := now() - make_interval(days => 2 * v_days);
begin
  if coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'mfa_required' using errcode = '42501';
  end if;
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'days', v_days,
    'members_signed_in', (select count(distinct user_id) from public.website_sign_ins
                           where signed_in_at >= v_since),
    'sign_ins',          (select count(*) from public.website_sign_ins
                           where signed_in_at >= v_since),
    'members_signed_in_before', (select count(distinct user_id) from public.website_sign_ins
                                  where signed_in_at >= v_before and signed_in_at < v_since)
  );
end;
$$;

revoke execute on function public.admin_studio_website_report(integer) from public, anon;
grant execute on function public.admin_studio_website_report(integer) to authenticated;

create function public.prune_website_sign_ins()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cut timestamptz := date_trunc('month', now()) - interval '24 months';
  v_n bigint;
begin
  insert into public.usage_monthly_totals (metric, entity_type, entity_id, detail, month, total, people)
  select 'website_sign_in', null, null, null,
         date_trunc('month', signed_in_at)::date, count(*), count(distinct user_id)
  from public.website_sign_ins where signed_in_at < v_cut
  group by 5
  on conflict on constraint usage_monthly_totals_key do nothing;
  delete from public.website_sign_ins where signed_in_at < v_cut;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke execute on function public.prune_website_sign_ins() from public, anon, authenticated;

select cron.schedule(
  'prune-website-sign-ins',
  '20 3 2 * *',
  'select public.prune_website_sign_ins()'
);

commit;
