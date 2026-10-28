-- A venue's card photo: which approved photo shows on the small cards
-- (Explore, search, Passport, Wishlist, Rankings, Guides, the private
-- chef card), and how it is framed there — independent of the header.
-- Asked for by the product owner on 2026-10-28: a restaurant may want a
-- different photo, or a different crop of the same one, for the small
-- picture than for the big header.
--
-- Option B of that day's write-up: it lives on the published photo
-- tables, where order (display_order) and header framing (focus_x/
-- focus_y/zoom, 20261014120000) already live.
--   - is_card: at most one per venue (partial unique index). None
--     flagged means "the cover" — the lowest display_order photo — so a
--     venue that never chooses keeps exactly today's card.
--   - card_focus_x/card_focus_y/card_zoom on EVERY photo: the card crop,
--     separate from the header crop, so even when the card photo is the
--     cover it can be zoomed differently for the small picture.
-- Deleting or replacing the card photo needs nothing special: no flag
-- left means the cover again. approve_venue_photo keeps the flag on a
-- replacement for the card photo (card crop reset, new image).
--
-- set_venue_card_photo() is the only way a manager changes either —
-- SECURITY DEFINER, is_active_venue_manager() as the only permission
-- source, same shape as reorder_venue_photos/set_venue_photo_framing;
-- the column-lock trigger now also refuses direct writes to the four new
-- columns. This extends the rule revised on 2026-10-28 (order and
-- framing) with "which approved photo is the card" — still never the
-- image or its alt text.
--
-- restaurants_full/hotels_full gain card_photo_url/card_focus_x/
-- card_focus_y/card_zoom from a second LATERAL (flagged first, then
-- lowest display_order), appended at the end. cover_photo_url and its
-- framing are unchanged and still mean the header cover, so installed
-- builds keep showing the cover on cards until they update.
--
-- Rollout order: migration before the build that selects these columns.
--
-- Real date: 2026-10-28. The filename is a sequence number, the next one
-- after the highest existing migration (20261014120000), per CLAUDE.md.

begin;

-- ============================================================
-- 1. Columns, and at most one card photo per venue
-- ============================================================

alter table public.restaurant_photos
  add column is_card boolean not null default false,
  add column card_focus_x numeric not null default 0.5 check (card_focus_x between 0 and 1),
  add column card_focus_y numeric not null default 0.5 check (card_focus_y between 0 and 1),
  add column card_zoom numeric not null default 1 check (card_zoom between 1 and 4);
alter table public.hotel_photos
  add column is_card boolean not null default false,
  add column card_focus_x numeric not null default 0.5 check (card_focus_x between 0 and 1),
  add column card_focus_y numeric not null default 0.5 check (card_focus_y between 0 and 1),
  add column card_zoom numeric not null default 1 check (card_zoom between 1 and 4);
alter table public.private_chef_photos
  add column is_card boolean not null default false,
  add column card_focus_x numeric not null default 0.5 check (card_focus_x between 0 and 1),
  add column card_focus_y numeric not null default 0.5 check (card_focus_y between 0 and 1),
  add column card_zoom numeric not null default 1 check (card_zoom between 1 and 4);

create unique index restaurant_photos_one_card_uidx
  on public.restaurant_photos (restaurant_id) where is_card;
create unique index hotel_photos_one_card_uidx
  on public.hotel_photos (hotel_id) where is_card;
create unique index private_chef_photos_one_card_uidx
  on public.private_chef_photos (private_chef_id) where is_card;

-- ============================================================
-- 2. Direct client UPDATEs may not touch the card columns either.
-- ============================================================

create or replace function public.enforce_manager_photo_reorder_only()
returns trigger
language plpgsql
as $$
begin
  if current_user = 'authenticated' then
    if new.image_url is distinct from old.image_url
      or new.alt_text is distinct from old.alt_text
      or new.focus_x is distinct from old.focus_x
      or new.focus_y is distinct from old.focus_y
      or new.zoom is distinct from old.zoom
      or new.is_card is distinct from old.is_card
      or new.card_focus_x is distinct from old.card_focus_x
      or new.card_focus_y is distinct from old.card_focus_y
      or new.card_zoom is distinct from old.card_zoom
    then
      raise exception 'Only display_order may be changed directly by a venue manager; framing goes through set_venue_photo_framing(), the card photo through set_venue_card_photo().';
    end if;
  end if;
  return new;
end;
$$;

-- ============================================================
-- 3. set_venue_card_photo() — choose the card photo and its crop, or
--    (p_photo_id null) go back to "the cover".
-- ============================================================

create function public.set_venue_card_photo(
  p_venue_type text,
  p_venue_id uuid,
  p_photo_id uuid,
  p_focus_x numeric,
  p_focus_y numeric,
  p_zoom numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
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
  if p_photo_id is not null and (
    p_focus_x is null or p_focus_y is null or p_zoom is null
    or p_focus_x not between 0 and 1
    or p_focus_y not between 0 and 1
    or p_zoom not between 1 and 4
  ) then
    raise exception 'Framing out of range: focus 0..1, zoom 1..4';
  end if;

  -- Clear the current card photo first (the partial unique index allows
  -- one flag per venue), then flag the chosen one — or none, which means
  -- the cover again.
  if p_venue_type = 'restaurant' then
    update public.restaurant_photos set is_card = false
      where restaurant_id = p_venue_id and is_card;
    if p_photo_id is not null then
      update public.restaurant_photos
        set is_card = true, card_focus_x = p_focus_x, card_focus_y = p_focus_y, card_zoom = p_zoom
        where id = p_photo_id and restaurant_id = p_venue_id;
      get diagnostics v_row_count = row_count;
    end if;
  elsif p_venue_type = 'hotel' then
    update public.hotel_photos set is_card = false
      where hotel_id = p_venue_id and is_card;
    if p_photo_id is not null then
      update public.hotel_photos
        set is_card = true, card_focus_x = p_focus_x, card_focus_y = p_focus_y, card_zoom = p_zoom
        where id = p_photo_id and hotel_id = p_venue_id;
      get diagnostics v_row_count = row_count;
    end if;
  else
    update public.private_chef_photos set is_card = false
      where private_chef_id = p_venue_id and is_card;
    if p_photo_id is not null then
      update public.private_chef_photos
        set is_card = true, card_focus_x = p_focus_x, card_focus_y = p_focus_y, card_zoom = p_zoom
        where id = p_photo_id and private_chef_id = p_venue_id;
      get diagnostics v_row_count = row_count;
    end if;
  end if;

  if p_photo_id is not null and v_row_count <> 1 then
    raise exception 'photo % is not one of this venue''s own photos', p_photo_id;
  end if;
end;
$$;

revoke execute on function public.set_venue_card_photo(text, uuid, uuid, numeric, numeric, numeric) from public, anon;
grant execute on function public.set_venue_card_photo(text, uuid, uuid, numeric, numeric, numeric) to authenticated;

-- ============================================================
-- 4. approve_venue_photo() keeps the card choice on a replacement.
--    Same signature; dashboard-only ACL restated.
-- ============================================================

create or replace function public.approve_venue_photo(
  p_submission_id uuid,
  p_reviewed_by uuid,
  p_image_url text
)
returns table (published_id uuid, image_url text, display_order smallint, submission_id uuid)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_sub public.venue_photo_submissions;
  -- Confirmed 2026-10-05 against a real published row (private_chef_photos)
  -- cross-checked against storage.objects, not assumed from an example.
  v_prefix constant text :=
    'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/';
  v_object_path text;
  v_display_order smallint;
  v_new_id uuid;
  v_was_card boolean := false;
begin
  -- No auth.uid() check — see approve_venue_claim's own comment.

  -- Table-qualified throughout this function too — display_order/
  -- image_url are among this function's own RETURNS TABLE OUT
  -- parameters (published_id, image_url, display_order, submission_id),
  -- so a bare reference to either inside max()/RETURNING is genuinely
  -- ambiguous, not just inconsistent style. See approve_venue_claim's
  -- own comment for the same issue caught the same way (42702 at
  -- CREATE time).
  if p_reviewed_by is null or not exists (select 1 from public.profiles p where p.id = p_reviewed_by) then
    raise exception 'p_reviewed_by must be a real profiles.id, got %', p_reviewed_by;
  end if;

  select * into v_sub from public.venue_photo_submissions vps
    where vps.id = p_submission_id and vps.status = 'pending' for update;
  if v_sub.id is null then
    raise exception 'venue_photo_submissions % is not pending (or does not exist)', p_submission_id;
  end if;

  -- Trust nothing about the hand-typed URL: it must be the real
  -- catalogue-media public prefix, and an object must actually exist at
  -- the path it names. A typo'd URL fails the call instead of publishing
  -- a broken image. This cannot and does not verify the object is
  -- actually a photo of the right venue — that's still a human looking
  -- at it before approving, same as the review step already requires.
  if p_image_url is null or left(p_image_url, length(v_prefix)) is distinct from v_prefix then
    raise exception 'p_image_url must start with %', v_prefix;
  end if;
  v_object_path := substring(p_image_url from length(v_prefix) + 1);
  if not exists (
    select 1 from storage.objects where bucket_id = 'catalogue-media' and name = v_object_path
  ) then
    raise exception 'No object at % in the catalogue-media bucket — copy the file there before approving', v_object_path;
  end if;

  if v_sub.replaces_photo_id is not null then
    -- Preserve position rather than append: a manager replacing their
    -- 3rd photo means "swap it," not "replace it and also demote it to
    -- last." Also sidesteps the 5-cap trigger entirely, since a slot is
    -- freed before the new row is inserted.
    if v_sub.venue_type = 'restaurant' then
      delete from public.restaurant_photos rp
        where rp.id = v_sub.replaces_photo_id and rp.restaurant_id = v_sub.venue_id
        returning rp.display_order, rp.is_card into v_display_order, v_was_card;
    elsif v_sub.venue_type = 'hotel' then
      delete from public.hotel_photos hp
        where hp.id = v_sub.replaces_photo_id and hp.hotel_id = v_sub.venue_id
        returning hp.display_order, hp.is_card into v_display_order, v_was_card;
    else
      delete from public.private_chef_photos pcp
        where pcp.id = v_sub.replaces_photo_id and pcp.private_chef_id = v_sub.venue_id
        returning pcp.display_order, pcp.is_card into v_display_order, v_was_card;
    end if;
    if v_display_order is null then
      raise exception 'replaces_photo_id % does not belong to venue % (%)',
        v_sub.replaces_photo_id, v_sub.venue_id, v_sub.venue_type;
    end if;
    -- The deleted row's bytes stay in catalogue-media — this function
    -- has no way to delete a Storage object. Orphaned, reported in this
    -- migration's own header, not fixed here.
  else
    -- Append after the current maximum. Zero photos yet -> coalesce
    -- gives 0, matching the column's own default. A gap left by an
    -- earlier deletion is never filled here — harmless, since every
    -- render path already just orders by display_order, and
    -- reorder_venue_photos fully renumbers 0..n-1 on its own next call
    -- regardless of what the values were before.
    if v_sub.venue_type = 'restaurant' then
      select coalesce(max(rp.display_order) + 1, 0) into v_display_order
        from public.restaurant_photos rp where rp.restaurant_id = v_sub.venue_id;
    elsif v_sub.venue_type = 'hotel' then
      select coalesce(max(hp.display_order) + 1, 0) into v_display_order
        from public.hotel_photos hp where hp.hotel_id = v_sub.venue_id;
    else
      select coalesce(max(pcp.display_order) + 1, 0) into v_display_order
        from public.private_chef_photos pcp where pcp.private_chef_id = v_sub.venue_id;
    end if;
  end if;

  -- The framing the manager chose at upload (focus_x/focus_y/zoom,
  -- 20261014120000) is carried onto the published row. alt_text stays
  -- at the published table's own default (null): the submission still
  -- carries none. A replacement for the venue's chosen card photo stays
  -- the card photo (is_card, 20261015120000); its card framing starts
  -- centred, since the old crop was for a different image.
  if v_sub.venue_type = 'restaurant' then
    insert into public.restaurant_photos (restaurant_id, image_url, display_order, focus_x, focus_y, zoom, is_card)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom, coalesce(v_was_card, false))
      returning id into v_new_id;
  elsif v_sub.venue_type = 'hotel' then
    insert into public.hotel_photos (hotel_id, image_url, display_order, focus_x, focus_y, zoom, is_card)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom, coalesce(v_was_card, false))
      returning id into v_new_id;
  else
    insert into public.private_chef_photos (private_chef_id, image_url, display_order, focus_x, focus_y, zoom, is_card)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom, coalesce(v_was_card, false))
      returning id into v_new_id;
  end if;

  update public.venue_photo_submissions
    set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by
    where id = p_submission_id;

  return query select v_new_id, p_image_url, v_display_order, p_submission_id;
end;
$$;

revoke execute on function public.approve_venue_photo(uuid, uuid, text) from public, anon, authenticated;

-- ============================================================
-- 5. Card photo on the two full views (cover columns unchanged).
-- ============================================================

create or replace view public.restaurants_full
  with (security_invoker = true)
  as
select
  r.id,
  r.restaurant_code,
  r.name,
  r.michelin_stars,
  r.inclusion_reason,
  r.cuisine_id,
  r.city_id,
  r.country_code,
  r.address,
  r.location,
  r.google_place_id,
  r.michelin_url,
  r.website_url,
  r.booking_url,
  r.property_name,
  r.status,
  r.status_since,
  r.status_note,
  r.created_at,
  r.updated_at,
  hr.id is not null or r.property_name is not null as is_in_hotel,
  coalesce(h.name, r.property_name) as hotel_name,
  h.id as hotel_id,
  ci.name as city_name,
  ci.region,
  co.name as country_name,
  co.flag_emoji,
  w.rank as worlds_50_best_rank,
  st_y(r.location::geometry) as latitude,
  st_x(r.location::geometry) as longitude,
  (exists (
    select 1 from public.worlds_50_best hof
    where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame'
  )) as is_hall_of_fame,
  r.phone,
  (r.ends_on is not null and r.ends_on < current_date) as is_expired,
  r.starts_on,
  r.ends_on,
  r.parent_venue_type,
  r.parent_venue_id,
  r.opening_weekdays,
  r.missing_listing_report_id,
  cover.image_url as cover_photo_url,
  cover.focus_x as cover_focus_x,
  cover.focus_y as cover_focus_y,
  cover.zoom as cover_zoom,
  card.image_url as card_photo_url,
  card.card_focus_x,
  card.card_focus_y,
  card.card_zoom
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null)
left join lateral (
  select rp.image_url, rp.focus_x, rp.focus_y, rp.zoom
  from public.restaurant_photos rp
  where rp.restaurant_id = r.id
  order by rp.display_order
  limit 1
) cover on true
left join lateral (
  select rp.image_url, rp.card_focus_x, rp.card_focus_y, rp.card_zoom
  from public.restaurant_photos rp
  where rp.restaurant_id = r.id
  order by rp.is_card desc, rp.display_order
  limit 1
) card on true;

create or replace view public.hotels_full
  with (security_invoker = true)
  as
select
  h.id,
  h.hotel_code,
  h.name,
  h.michelin_keys,
  h.city_id,
  h.country_code,
  h.address,
  h.location,
  h.google_place_id,
  h.michelin_url,
  h.website_url,
  h.booking_url,
  h.status,
  h.status_since,
  h.status_note,
  h.created_at,
  h.updated_at,
  coalesce(hr.restaurant_count, 0) > 0 as has_michelin_restaurant,
  coalesce(hr.restaurant_count, 0) as restaurant_count,
  ci.name as city_name,
  ci.region,
  co.name as country_name,
  co.flag_emoji,
  st_y(h.location::geometry) as latitude,
  st_x(h.location::geometry) as longitude,
  w.rank as worlds_50_best_rank,
  w.year as worlds_50_best_year,
  (h.ends_on is not null and h.ends_on < current_date) as is_expired,
  h.starts_on,
  h.ends_on,
  h.parent_venue_type,
  h.parent_venue_id,
  h.opening_weekdays,
  h.missing_listing_report_id,
  cover.image_url as cover_photo_url,
  cover.focus_x as cover_focus_x,
  cover.focus_y as cover_focus_y,
  cover.zoom as cover_zoom,
  card.image_url as card_photo_url,
  card.card_focus_x,
  card.card_focus_y,
  card.card_zoom
from public.hotels h
join public.cities ci on ci.id = h.city_id
join public.countries co on co.country_code = h.country_code
left join (
  select hotel_id, count(*) as restaurant_count
  from public.hotel_restaurants
  group by hotel_id
) hr on hr.hotel_id = h.id
left join public.worlds_50_best_hotels w
  on w.hotel_id = h.id
 and w.year = (select max(year) from public.worlds_50_best_hotels where rank is not null)
left join lateral (
  select hp.image_url, hp.focus_x, hp.focus_y, hp.zoom
  from public.hotel_photos hp
  where hp.hotel_id = h.id
  order by hp.display_order
  limit 1
) cover on true
left join lateral (
  select hp.image_url, hp.card_focus_x, hp.card_focus_y, hp.card_zoom
  from public.hotel_photos hp
  where hp.hotel_id = h.id
  order by hp.is_card desc, hp.display_order
  limit 1
) card on true;

commit;
