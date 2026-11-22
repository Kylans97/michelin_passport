-- Studio: the features added since the Studio report was written
-- (20261101230000), as one more report. Asked for by the product owner on
-- 2026-11-22: "van alle dingen die we hebben toegevoegd de afgelopen tijd
-- wil ik ook de data hebben in mantelier studio. Zeker nu we het hele wijn
-- ding hebben toegevoegd ook. Dus dit nog voor die nieuwe build." Written
-- 2026-11-22 on claude/signup-flow; the number is sort order: the next
-- after 20261101650000, the highest on any branch.
--
-- PREPARED -- NOT APPLIED until the product owner approves.
--
-- admin_studio_features_report(p_days) returns, for the last p_days days
-- where a period applies:
--   wine           wines logged on visits and kept in the Cellar, the
--                  verdicts and notes, the Cellar's settings, estates linked
--   top_estates    the estates most linked, visited and wishlisted
--   vineyards      estate visits and estates on wishlists
--   journeys       trains and ships travelled and wishlisted
--   wishlist       wishlist entries per kind
--   friends        friendships accepted and pending
--   sign_in        how accounts sign in: Apple, an email code, a password
--   push           devices registered for push
--   booking        booking reminders set
--   news           published articles, opens and readers, top articles
--
-- Counts only, never a person, the same rule as admin_studio_report. A
-- tasting note is counted, never returned. Who may call it is the same
-- too: an admin whose session passed two-step sign-in, the aal check first
-- so a password-only session gets 'mfa_required'.
--
-- sign_in reads auth.users and auth.identities (security definer): Apple
-- is an 'apple' identity; a password is a non-empty encrypted_password;
-- everything else signed in with an email code. An Apple account that
-- also set a password counts as Apple.
--
-- No new table, no new tracking: it reads what the app already records.

create function public.admin_studio_features_report(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days  integer := least(greatest(coalesce(p_days, 30), 1), 365);
  v_since timestamptz;
  v_since_date date;
  v_result jsonb;
begin
  if coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'mfa_required' using errcode = '42501';
  end if;
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  v_since := now() - make_interval(days => v_days);
  v_since_date := (v_since at time zone 'utc')::date;

  with
  wines as (
    select user_id, verdict, tasting_note, vineyard_id, created_at,
           'visit'::text as source, null::text as setting
      from public.visit_wines
    union all
    select user_id, verdict, tasting_note, vineyard_id, created_at,
           'cellar', setting
      from public.cellar_wines
  ),
  wine as (
    select jsonb_build_object(
      'logged_on_visits',  count(*) filter (where source = 'visit'),
      'kept_in_cellar',    count(*) filter (where source = 'cellar'),
      'added_in_period',   count(*) filter (where created_at >= v_since),
      'members',           count(distinct user_id),
      'members_in_period', count(distinct user_id) filter (where created_at >= v_since),
      'again',             count(*) filter (where verdict = 'again'),
      'fine',              count(*) filter (where verdict = 'fine'),
      'not_for_me',        count(*) filter (where verdict = 'not_for_me'),
      'no_verdict',        count(*) filter (where verdict is null),
      'with_note',         count(*) filter (where tasting_note is not null),
      'linked_to_estate',  count(*) filter (where vineyard_id is not null),
      'cellar_home',       count(*) filter (where setting = 'home'),
      'cellar_estate',     count(*) filter (where setting = 'estate'),
      'cellar_elsewhere',  count(*) filter (where setting = 'elsewhere')
    ) as doc
    from wines
  ),
  estate_rows as (
    select vineyard_id, count(*) as wines, 0::bigint as visits, 0::bigint as wishlist
      from wines where vineyard_id is not null group by vineyard_id
    union all
    select vineyard_id, 0, count(*), 0 from public.vineyard_visits group by vineyard_id
    union all
    select entity_id, 0, 0, count(*) from public.wishlist
      where entity_type = 'vineyard' group by entity_id
  ),
  top_estates as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'vineyard_id', x.vineyard_id,
      'name',        v.name,
      'region',      v.region,
      'country',     v.country_code,
      'wines',       x.wines,
      'visits',      x.visits,
      'wishlist',    x.wishlist
    ) order by x.wines + x.visits + x.wishlist desc, v.name), '[]'::jsonb) as doc
    from (
      select vineyard_id, sum(wines) as wines, sum(visits) as visits,
             sum(wishlist) as wishlist
      from estate_rows group by vineyard_id
      order by sum(wines) + sum(visits) + sum(wishlist) desc
      limit 10
    ) x
    join public.vineyards v on v.id = x.vineyard_id
  ),
  vineyards as (
    select jsonb_build_object(
      'visits',           (select count(*) from public.vineyard_visits),
      'visits_in_period', (select count(*) from public.vineyard_visits where visited_on >= v_since_date),
      'visitors',         (select count(distinct user_id) from public.vineyard_visits),
      'wishlist',         (select count(*) from public.wishlist where entity_type = 'vineyard')
    ) as doc
  ),
  journeys as (
    select jsonb_build_object(
      'travels',           (select count(*) from public.journey_travels),
      'travels_in_period', (select count(*) from public.journey_travels where departed_on >= v_since_date),
      'travellers',        (select count(distinct user_id) from public.journey_travels),
      'wishlist',          (select count(*) from public.wishlist where entity_type = 'journey'),
      'top', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'name', t.name, 'kind', t.kind, 'travels', t.travels, 'wishlist', t.wishlist
        ) order by t.travels + t.wishlist desc, t.name), '[]'::jsonb)
        from (
          select j.name, j.kind,
                 (select count(*) from public.journey_travels jt where jt.journey_id = j.id) as travels,
                 (select count(*) from public.wishlist w
                   where w.entity_type = 'journey' and w.entity_id = j.id) as wishlist
          from public.journeys j
        ) t
        where t.travels + t.wishlist > 0
        limit 10
      )
    ) as doc
  ),
  wishlist as (
    select coalesce(jsonb_object_agg(entity_type, n), '{}'::jsonb) as doc
    from (select entity_type, count(*) as n from public.wishlist group by entity_type) k
  ),
  friends as (
    select jsonb_build_object(
      'accepted',           count(*) filter (where status = 'accepted'),
      'pending',            count(*) filter (where status = 'pending'),
      'accepted_in_period', count(*) filter (where status = 'accepted' and responded_at >= v_since),
      'members_with_friends', (
        select count(distinct m) from (
          select requester_id as m from public.friendships where status = 'accepted'
          union
          select addressee_id from public.friendships where status = 'accepted'
        ) x
      )
    ) as doc
    from public.friendships
  ),
  account_methods as (
    select u.created_at,
           case
             when exists (select 1 from auth.identities i
                           where i.user_id = u.id and i.provider = 'apple') then 'apple'
             when coalesce(u.encrypted_password, '') <> '' then 'password'
             else 'email_code'
           end as method
    from auth.users u
    join public.profiles p on p.id = u.id
  ),
  sign_in as (
    select jsonb_build_object(
      'apple',                count(*) filter (where method = 'apple'),
      'email_code',           count(*) filter (where method = 'email_code'),
      'password',             count(*) filter (where method = 'password'),
      'apple_in_period',      count(*) filter (where method = 'apple' and created_at >= v_since),
      'email_code_in_period', count(*) filter (where method = 'email_code' and created_at >= v_since),
      'password_in_period',   count(*) filter (where method = 'password' and created_at >= v_since)
    ) as doc
    from account_methods
  ),
  push as (
    select jsonb_build_object(
      'devices',        count(*),
      'members',        count(distinct user_id),
      'production',     count(*) filter (where apns_environment = 'production'),
      'seen_in_period', count(*) filter (where last_seen_at >= v_since)
    ) as doc
    from public.push_devices
  ),
  booking as (
    select jsonb_build_object(
      'reminders', count(*),
      'members',   count(distinct user_id),
      'upcoming',  count(*) filter (where opens_on >= current_date)
    ) as doc
    from public.booking_reminders
  ),
  news as (
    select jsonb_build_object(
      'published', (select count(*) from public.news_articles
                     where status = 'published' and published_at <= now()),
      'opens',     (select count(*) from public.news_article_opens where opened_at >= v_since),
      'readers',   (select count(distinct user_id) from public.news_article_opens where opened_at >= v_since),
      'top', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'title', t.title, 'opens', t.opens, 'readers', t.readers
        ) order by t.opens desc, t.title), '[]'::jsonb)
        from (
          select a.title, count(*) as opens, count(distinct o.user_id) as readers
          from public.news_article_opens o
          join public.news_articles a on a.id = o.article_id
          where o.opened_at >= v_since
          group by a.id, a.title
          order by count(*) desc
          limit 5
        ) t
      )
    ) as doc
  )
  select jsonb_build_object(
    'days',         v_days,
    'generated_at', now(),
    'wine',         (select doc from wine),
    'top_estates',  (select doc from top_estates),
    'vineyards',    (select doc from vineyards),
    'journeys',     (select doc from journeys),
    'wishlist',     (select doc from wishlist),
    'friends',      (select doc from friends),
    'sign_in',      (select doc from sign_in),
    'push',         (select doc from push),
    'booking',      (select doc from booking),
    'news',         (select doc from news)
  ) into v_result;

  return v_result;
end;
$$;

-- CLAUDE.md: every new SECURITY DEFINER function revokes from public and
-- anon in the migration that creates it. The function checks is_admin()
-- and aal2 itself; authenticated keeps execute so an admin can call it.
revoke execute on function public.admin_studio_features_report(integer) from public, anon;
grant execute on function public.admin_studio_features_report(integer) to authenticated;
