-- The award a visit records, and its date, come from the database, not
-- from whatever the client sends.
--
-- Written 2026-11-16. Named after 20261101440000_enforce_event_attendance_
-- eligibility per CLAUDE.md's monotonic-sequence rule. PENDING A PRODUCT
-- DECISION: prepared, not approved. Independent of 20261101420000–440000.
--
-- The gap: visits_insert / visits_update (confirmed live on 2026-11-16)
-- check only user_id = auth.uid(). stars_at_visit and keys_at_visit are
-- whatever the client sends, and they feed the Passport and the rankings;
-- visited_on has no upper bound.
--
-- What the app actually does (add_visit_flow.dart, visited_repository.dart):
--   - a restaurant visit sends stars_at_visit = the restaurant's CURRENT
--     michelin_stars and no keys; a hotel stay sends keys_at_visit = the
--     hotel's CURRENT michelin_keys and no stars — whatever date is picked;
--   - an edit (updateVisitDetails) never changes the venue or the frozen
--     award;
--   - the date picker stops at today (lastDate: now, device-local).
-- This trigger does exactly that on the server, so a shipped build sees
-- no difference: on insert it overwrites the two award columns from the
-- venue row instead of trusting them; on update it keeps the old values
-- and refuses a change of venue. Overwriting rather than rejecting is what
-- keeps every build in the wild working.
--
-- The future-date guard uses the latest calendar date anywhere on earth
-- (Pacific/Kiritimati, UTC+14), so "today" on any member's phone is always
-- accepted and nothing later is. A plain current_date (UTC) would reject a
-- visit logged for today shortly after midnight in Amsterdam.
--
-- Not SECURITY DEFINER: restaurants and hotels are world-readable, so the
-- trigger reads them as the caller. The revoke below is hygiene, not a
-- gap (a trigger function can't be called directly).
--
-- Production on 2026-11-16: 37 visits; none dated in the future, none
-- whose stars/keys differ from the venue's current award. The trigger
-- only acts on new writes, so a later change of a venue's award never
-- rewrites an existing visit.

begin;

create function public.visits_freeze_award_and_date()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    if new.entity_type is distinct from old.entity_type
       or new.entity_id is distinct from old.entity_id then
      raise exception 'A visit cannot be moved to another venue'
        using errcode = 'check_violation';
    end if;
    new.stars_at_visit := old.stars_at_visit;
    new.keys_at_visit := old.keys_at_visit;
  elsif new.entity_type = 'restaurant' then
    new.stars_at_visit := (
      select r.michelin_stars from public.restaurants r where r.id = new.entity_id
    );
    new.keys_at_visit := null;
  elsif new.entity_type = 'hotel' then
    new.keys_at_visit := (
      select h.michelin_keys from public.hotels h where h.id = new.entity_id
    );
    new.stars_at_visit := null;
  end if;

  if new.visited_on > (now() at time zone 'Pacific/Kiritimati')::date
     and (tg_op = 'INSERT' or new.visited_on is distinct from old.visited_on) then
    raise exception 'A visit cannot be dated in the future'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

revoke execute on function public.visits_freeze_award_and_date() from public, anon;

create trigger visits_freeze_award_and_date
  before insert or update on public.visits
  for each row execute function public.visits_freeze_award_and_date();

commit;
