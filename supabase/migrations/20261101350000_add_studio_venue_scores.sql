-- STUDIO: WHAT MEMBERS SCORE A VENUE ON. Written 2026-11-04, asked for by
-- the product owner, for Studio's Pro tab: per restaurant and hotel, the
-- average per score, where it scores high and low, and how often each
-- score is filled in or left blank.
--
-- One function beside admin_studio_venue_report and
-- admin_studio_venue_insights, same rules: admin only, people not visits,
-- what the product owner sees is what the venue could later be given.
--
-- Each member counts once, on their latest visit or stay, like Rankings
-- (20261030180000), so a regular cannot outweigh everyone else. Private
-- visits count too, as they do in Rankings. A member who logged a visit
-- and scored nothing counts as blank on every score.
--
-- Stricter than Rankings' 3 raters: this goes to a venue per subject, so
-- the privacy policy's five applies. An average needs 5 members behind
-- it. Filled in and left blank add up to the members total, so hiding only
-- the small one would let it be worked out by subtraction: when either is
-- under 5 both are null and fill says which side is small ('most' when
-- most members filled it in, 'few' when almost nobody did). Under 5
-- members in all, every number is null.
--
-- The privacy policy must name this before this function is applied.
-- New SECURITY DEFINER function with its revoke below (CLAUDE.md).

begin;

create function public.admin_studio_venue_scores(p_venue_type text, p_venue_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef') then
    raise exception 'unknown venue type' using errcode = '22023';
  end if;

  with latest as (
    select distinct on (v.user_id) v.*
    from public.visits v
    where v.entity_type = p_venue_type and v.entity_id = p_venue_id
    order by v.user_id, v.visited_on desc, v.id desc
  ),
  members as (
    select count(*) as n from latest
  ),
  scores as (
    select d.key, d.ord, d.score
    from latest l
    cross join lateral (values
      ('overall', 0, l.rating),
      ('food', 1, l.food_rating::numeric),
      ('service', 2, l.service_rating::numeric),
      ('wine', 3, l.wine_rating::numeric),
      ('atmosphere', 4, l.atmosphere_rating::numeric),
      ('room', 5, l.room_rating::numeric),
      ('experience', 6, l.experience_rating::numeric),
      ('value', 7, l.value_rating::numeric)
    ) as d(key, ord, score)
    where p_venue_type = 'restaurant' and d.key not in ('room', 'experience')
       or p_venue_type = 'hotel' and d.key not in ('food', 'wine', 'atmosphere')
  ),
  per_score as (
    select key, min(ord) as ord, count(score) as filled,
           count(*) - count(score) as blank, avg(score) as average
    from scores
    group by key
  )
  select jsonb_build_object(
    'members', public.studio_suppress((select n from members)),
    'scores', case when (select n from members) < 5 then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
        'key', key,
        'average', case when filled >= 5 then round(average, 1) end,
        'filled', case when filled >= 5 and blank >= 5 then filled end,
        'blank', case when filled >= 5 and blank >= 5 then blank end,
        'fill', case when filled >= 5 and blank >= 5 then 'counted'
                     when filled >= 5 then 'most'
                     when blank >= 5 then 'few'
                     else 'hidden' end
      ) order by ord)
      from per_score
    ), '[]'::jsonb) end
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.admin_studio_venue_scores(text, uuid) from public, anon;
grant execute on function public.admin_studio_venue_scores(text, uuid) to authenticated;

commit;
