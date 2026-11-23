-- Visits without a date: "I've been here, but I don't know when."
--
-- Written 2026-11-23 (product owner: "je moet een visit kunnen toevoegen
-- zonder datum, deze komt dan niet in je paspoort", then, choosing the
-- globe direction on the design canvas
-- https://claude.ai/artifact/TfEpmHfZkNdiUbFM2gFkY7: "let's do the globe
-- setup"). Named after 20261101690000 per CLAUDE.md's monotonic-sequence
-- rule. Not applied: prepared for review.
--
-- Its own table, not a nullable visits.visited_on. Shipped builds parse
-- visited_on as always present (lib/models/visit.dart: DateTime.parse(
-- json['visited_on'] as String)), for the member's own Passport and for
-- friends' too, so a single null row would break 1.8.0 and 1.9.0. The
-- rankings views also order by visited_on desc, which puts nulls first,
-- and the invite-link trigger copies visited_on between companions. A
-- separate table is invisible to all of them.
--
-- An undated visit is never a Passport stamp (CLAUDE.md: stamps come only
-- from confirmed attendance). It lights a country on My Map and shows as a
-- dashed pin. date_undated_visit() turns it into a real visits row, which
-- is when the stamp is earned, and removes the undated row in the same
-- transaction, so the two never exist side by side for one venue.
--
-- One row per member and venue: "been here" has no count without dates.
--
-- The award is frozen when the row is logged, as visits_freeze_award_and_
-- date does for visits (20261101450000): the venue's current stars or Keys,
-- whatever the client sends. The app says "when logged", since the date of
-- the visit itself is unknown. When the date is added, the new visits row
-- takes the venue's award at that moment through the visits trigger, the
-- same as a visit logged by hand that day.

begin;

-- ============================================================
-- 1. undated_visits
-- ============================================================
create table public.undated_visits (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  entity_type     text not null check (entity_type in ('restaurant', 'hotel')),
  entity_id       uuid not null,
  visibility      text not null default 'private'
    check (visibility in ('private', 'friends')),
  stars_at_visit  smallint,
  keys_at_visit   smallint,
  created_at      timestamptz not null default now(),
  constraint undated_visits_one_per_venue unique (user_id, entity_type, entity_id)
);

create index undated_visits_entity_idx
  on public.undated_visits (entity_type, entity_id);

comment on table public.undated_visits is
  'A member''s visit or stay whose date they don''t know. Never a Passport '
  'stamp; date_undated_visit() moves it into visits once the date is known. '
  'Its own table because shipped builds read visits.visited_on as never null.';

-- ============================================================
-- 2. The award, frozen when logged
-- ============================================================
create function public.undated_visits_freeze_award()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id
       or new.entity_type is distinct from old.entity_type
       or new.entity_id is distinct from old.entity_id then
      raise exception 'An undated visit cannot be moved to another venue or member'
        using errcode = 'check_violation';
    end if;
    new.stars_at_visit := old.stars_at_visit;
    new.keys_at_visit := old.keys_at_visit;
    new.created_at := old.created_at;
  elsif new.entity_type = 'restaurant' then
    new.stars_at_visit := (
      select r.michelin_stars from public.restaurants r where r.id = new.entity_id
    );
    new.keys_at_visit := null;
  else
    new.keys_at_visit := (
      select h.michelin_keys from public.hotels h where h.id = new.entity_id
    );
    new.stars_at_visit := null;
  end if;
  return new;
end;
$$;

-- Not SECURITY DEFINER (restaurants and hotels are world-readable, so the
-- trigger reads them as the caller), and a trigger function can't be
-- called directly; revoked anyway, as CLAUDE.md asks of every new function.
revoke execute on function public.undated_visits_freeze_award() from public, anon;

create trigger undated_visits_freeze_award
  before insert or update on public.undated_visits
  for each row execute function public.undated_visits_freeze_award();

-- ============================================================
-- 3. ROW LEVEL SECURITY
-- ============================================================
-- Same shape as visits and vineyard_visits: the owner reads and writes
-- their own rows, an accepted friend reads a 'friends' row, anon nothing.
alter table public.undated_visits enable row level security;

revoke all on public.undated_visits from public, anon, authenticated;
grant select, insert, update, delete on public.undated_visits to authenticated;

create policy undated_visits_select on public.undated_visits
  for select to authenticated
  using (
    user_id = auth.uid()
    or (visibility = 'friends' and public.is_friend(user_id))
  );

create policy undated_visits_insert on public.undated_visits
  for insert to authenticated
  with check (user_id = auth.uid());

create policy undated_visits_update on public.undated_visits
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy undated_visits_delete on public.undated_visits
  for delete to authenticated
  using (user_id = auth.uid());

-- ============================================================
-- 4. Adding the date
-- ============================================================
-- SECURITY INVOKER: both writes run under the caller's own RLS (their own
-- visits insert, their own undated delete), so it can do nothing the
-- client couldn't do in two calls. It exists to make the two one
-- transaction. visits' own trigger sets the award and refuses a date in
-- the future. Returns the new visits row, which is what earns the stamp.
create function public.date_undated_visit(p_undated_visit_id uuid, p_visited_on date)
returns public.visits
language plpgsql
set search_path = public
as $$
declare
  v_undated public.undated_visits;
  v_visit public.visits;
begin
  select * into v_undated
    from public.undated_visits
   where id = p_undated_visit_id
     and user_id = auth.uid()
     for update;
  if not found then
    raise exception 'No such visit without a date'
      using errcode = 'no_data_found';
  end if;

  insert into public.visits (user_id, entity_type, entity_id, visited_on, visibility)
  values (v_undated.user_id, v_undated.entity_type, v_undated.entity_id, p_visited_on, v_undated.visibility)
  returning * into v_visit;

  delete from public.undated_visits where id = v_undated.id;

  return v_visit;
end;
$$;

revoke execute on function public.date_undated_visit(uuid, date) from public, anon;
grant execute on function public.date_undated_visit(uuid, date) to authenticated;

commit;
