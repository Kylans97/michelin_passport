-- Opening hours on a restaurant's page, kept by the restaurant itself.
--
-- Decided by the product owner on 2026-11-02: a claimed venue adds and
-- changes its opening hours without an admin's check. Unlike an about
-- text, a photo or the team, hours are practical facts the venue
-- changes often (a holiday week, a new lunch service), and a delay for
-- review would leave the page wrong in the meantime. So they go live at
-- once, the way photo order and framing do. Who changed them last, and
-- when, is recorded on each row.
--
-- Restaurants only: a hotel's own opening hours say little, and its
-- restaurants are venues of their own.
--
-- Shape: per weekday (ISO, 1 = Monday) none, one or two ranges, such as
-- lunch and dinner. A weekday without a row is closed, once the
-- restaurant has any row at all; with no rows the page shows nothing,
-- never "closed every day". A range whose closing time is earlier than
-- its opening time runs past midnight (18:00–01:00).
--
-- Writes go only through set_restaurant_opening_hours(), which checks
-- is_active_venue_manager() (the single source of edit permission,
-- CLAUDE.md), validates the whole week and replaces it in one go. There
-- is no client insert, update or delete on the table.
--
-- Every new SECURITY DEFINER function carries its own
-- `revoke execute ... from public, anon` in this file (CLAUDE.md).
--
-- Real date: 2026-11-02. The filename is a sequence number, the next one
-- after the highest existing migration (20261101170000), per CLAUDE.md.

begin;

create table public.restaurant_opening_hours (
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  weekday       smallint not null check (weekday between 1 and 7),
  slot          smallint not null check (slot in (1, 2)),
  opens_at      time not null,
  closes_at     time not null,
  updated_at    timestamptz not null default now(),
  updated_by    uuid references public.profiles(id) on delete set null,
  primary key (restaurant_id, weekday, slot),
  check (opens_at <> closes_at)
);

alter table public.restaurant_opening_hours enable row level security;

-- Catalogue-like: anyone may read, nobody writes directly.
create policy restaurant_opening_hours_read on public.restaurant_opening_hours
  for select to anon, authenticated using (true);

revoke all on table public.restaurant_opening_hours from public, anon, authenticated;
grant select (restaurant_id, weekday, slot, opens_at, closes_at, updated_at)
  on public.restaurant_opening_hours to anon, authenticated;

-- Replaces the whole week. p_hours is a JSON array of
-- {"weekday": 1-7, "opens": "HH:MM", "closes": "HH:MM"}; an empty array
-- takes the hours off the page. At most two ranges a day; a day's
-- second range starts after its first one closes, and a range past
-- midnight must be the day's last.
create function public.set_restaurant_opening_hours(
  p_restaurant_id uuid,
  p_hours jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows record;
  v_prev_closes time;
  v_prev_overnight boolean;
begin
  if not public.is_active_venue_manager('restaurant', p_restaurant_id) then
    raise exception 'Not a manager of this restaurant';
  end if;
  if p_hours is null or jsonb_typeof(p_hours) <> 'array' then
    raise exception 'p_hours must be a JSON array';
  end if;
  if jsonb_array_length(p_hours) > 14 then
    raise exception 'At most two ranges a day';
  end if;

  -- Read the week once, as rows, and check it whole before any write.
  -- Per day in opening order: at most two, no overlap, a range past
  -- midnight last.
  for v_rows in
    select h.weekday, t.opens_at, t.closes_at,
           row_number() over (partition by h.weekday order by t.opens_at) as n
      from jsonb_to_recordset(p_hours) as h(weekday smallint, opens text, closes text)
      cross join lateral (select h.opens::time as opens_at, h.closes::time as closes_at) t
      order by h.weekday, t.opens_at
  loop
    if v_rows.weekday is null or v_rows.weekday not between 1 and 7 then
      raise exception 'weekday must be 1-7, got %', v_rows.weekday;
    end if;
    if v_rows.opens_at is null or v_rows.closes_at is null
       or v_rows.opens_at = v_rows.closes_at then
      raise exception 'Every range on day % needs an opening and a different closing time', v_rows.weekday;
    end if;
    if v_rows.n > 2 then
      raise exception 'At most two ranges on day %', v_rows.weekday;
    end if;
    if v_rows.n = 2 then
      if v_prev_overnight then
        raise exception 'On day % a range past midnight must be the last one', v_rows.weekday;
      end if;
      if v_rows.opens_at < v_prev_closes then
        raise exception 'The ranges on day % overlap', v_rows.weekday;
      end if;
    end if;
    v_prev_closes := v_rows.closes_at;
    v_prev_overnight := v_rows.closes_at < v_rows.opens_at;
  end loop;

  delete from public.restaurant_opening_hours where restaurant_id = p_restaurant_id;
  insert into public.restaurant_opening_hours
    (restaurant_id, weekday, slot, opens_at, closes_at, updated_at, updated_by)
  select p_restaurant_id, h.weekday,
         row_number() over (partition by h.weekday order by h.opens::time),
         h.opens::time, h.closes::time, now(), auth.uid()
    from jsonb_to_recordset(p_hours) as h(weekday smallint, opens text, closes text);
end;
$$;

revoke execute on function public.set_restaurant_opening_hours(uuid, jsonb) from public, anon;
grant execute on function public.set_restaurant_opening_hours(uuid, jsonb) to authenticated;

commit;
