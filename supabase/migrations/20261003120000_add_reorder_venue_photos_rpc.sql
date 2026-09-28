-- reorder_venue_photos — the RPC recommended in the chat report
-- accompanying 20261002120000_add_manager_photo_reorder_and_review_note.sql:
-- an active manager reorders their venue's already-APPROVED photos
-- (restaurant_photos/hotel_photos/private_chef_photos) via a two-phase
-- reassignment through negative placeholders, inside this function's own
-- implicit transaction, writing only display_order. No photo-upload UI
-- exists yet and none is added here — schema/RPC only.
--
-- WHY THIS FUNCTION MUST DO ITS OWN AUTHORIZATION CHECK, NOT RELY ON RLS:
-- security definer means this function's internal UPDATEs execute with
-- the owning role's privileges, which bypasses RLS on restaurant_photos/
-- hotel_photos/private_chef_photos entirely (same reason has_approved_
-- venue_claim()/is_active_venue_manager() themselves have to be security
-- definer — to read across rows RLS would otherwise hide). That also
-- means 20261002120000's own column-immutability trigger (which only
-- enforces when current_user = 'authenticated') does NOT fire during
-- this function's writes either, since current_user becomes the
-- function's owner while it runs — so the only thing keeping this
-- function scoped to "an active manager, display_order only" is this
-- function's own body: the explicit is_active_venue_manager() check
-- below, and the fact that every UPDATE statement in phases 1 and 2 sets
-- display_order and nothing else.
--
-- NOT dynamic SQL (no EXECUTE/format(%I)): this schema has never once
-- used dynamic SQL to target one of several typed tables — every other
-- place this exact "restaurant/hotel/private_chef" split shows up
-- (has_approved_venue_claim, is_active_venue_manager,
-- notify_venue_claim_change) branches with static, repeated SQL instead.
-- Matched here for the same reason, even though it means the two-phase
-- loop body is written out three times rather than parameterized.
--
-- WHY THE CALLER MUST NAME EVERY ONE OF THE VENUE'S PHOTOS, NOT A SUBSET:
-- a partial list would leave the display_order of any omitted photo
-- meaningless relative to the new arrangement — there is no "leave it
-- where it was" that stays coherent once its neighbors have moved. The
-- count check below enforces this; a genuine partial-reorder use case,
-- if one ever appears, is a deliberate product decision to widen this,
-- not an oversight.

begin;

create function public.reorder_venue_photos(
  p_venue_type text,
  p_venue_id uuid,
  p_photo_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expected_count integer;
  v_photo_id uuid;
  v_idx integer;
  v_row_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef') then
    raise exception 'Unknown venue_type: %', p_venue_type;
  end if;
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Not an active manager of this venue';
  end if;
  if p_photo_ids is null or array_length(p_photo_ids, 1) is null then
    raise exception 'p_photo_ids must not be empty';
  end if;
  if array_length(p_photo_ids, 1)
      <> (select count(*) from (select distinct unnest(p_photo_ids)) d)
  then
    raise exception 'p_photo_ids contains a duplicate id';
  end if;

  v_expected_count := case p_venue_type
    when 'restaurant' then
      (select count(*) from public.restaurant_photos where restaurant_id = p_venue_id)
    when 'hotel' then
      (select count(*) from public.hotel_photos where hotel_id = p_venue_id)
    else
      (select count(*) from public.private_chef_photos where private_chef_id = p_venue_id)
  end;

  if array_length(p_photo_ids, 1) <> v_expected_count then
    raise exception
      'p_photo_ids must name exactly this venue''s % published photo(s) — got %',
      v_expected_count, array_length(p_photo_ids, 1);
  end if;

  -- Phase 1: move every named photo to a negative, per-position-unique
  -- placeholder. Never collides with a real (>= 0) display_order, and
  -- never collides with another placeholder within this same pass
  -- (each is keyed off its own position in the array) — so the existing
  -- immediate (non-deferrable) unique(venue_id, display_order)
  -- constraint is satisfied after every single statement here.
  v_idx := 0;
  foreach v_photo_id in array p_photo_ids loop
    if p_venue_type = 'restaurant' then
      update public.restaurant_photos set display_order = -1 - v_idx
        where id = v_photo_id and restaurant_id = p_venue_id;
    elsif p_venue_type = 'hotel' then
      update public.hotel_photos set display_order = -1 - v_idx
        where id = v_photo_id and hotel_id = p_venue_id;
    else
      update public.private_chef_photos set display_order = -1 - v_idx
        where id = v_photo_id and private_chef_id = p_venue_id;
    end if;
    get diagnostics v_row_count = row_count;
    if v_row_count <> 1 then
      raise exception 'photo % is not one of this venue''s own photos', v_photo_id;
    end if;
    v_idx := v_idx + 1;
  end loop;

  -- Phase 2: assign the real, final 0-based positions in exactly the
  -- order the caller supplied. Every id in p_photo_ids was already
  -- proven (phase 1) to belong to p_venue_id, so no venue-scoping
  -- predicate is needed again here.
  v_idx := 0;
  foreach v_photo_id in array p_photo_ids loop
    if p_venue_type = 'restaurant' then
      update public.restaurant_photos set display_order = v_idx where id = v_photo_id;
    elsif p_venue_type = 'hotel' then
      update public.hotel_photos set display_order = v_idx where id = v_photo_id;
    else
      update public.private_chef_photos set display_order = v_idx where id = v_photo_id;
    end if;
    v_idx := v_idx + 1;
  end loop;
end;
$$;

revoke execute on function public.reorder_venue_photos(text, uuid, uuid[]) from public, anon;
grant execute on function public.reorder_venue_photos(text, uuid, uuid[]) to authenticated;

commit;
