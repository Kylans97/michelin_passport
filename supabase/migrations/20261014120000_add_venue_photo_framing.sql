-- Venue photo framing: a focus point (focus_x/focus_y, 0..1) plus a
-- zoom factor (zoom, 1..4) per photo, set by the venue's own manager and
-- honoured everywhere the photo is shown — the detail-page hero and
-- every card (Explore, search, Passport, Wishlist, Rankings, Guides).
-- Until now every venue photo was a plain centred crop: focus_x/focus_y
-- have existed on the published tables since 20260828130000 but nothing
-- ever wrote or read them, and there was no zoom at all.
--
-- Two ways in, both deliberately low-friction:
--   1. At upload. venue_photo_submissions gains focus_x/focus_y/zoom; the
--      manager frames the photo in UploadVenuePhotoScreen, and
--      approve_venue_photo carries the values onto the published row.
--   2. After publication. set_venue_photo_framing() lets an active
--      manager re-frame one of their venue's published photos directly,
--      with no new review — the image itself (image_url) and alt_text
--      stay locked. Same shape as reorder_venue_photos: SECURITY DEFINER,
--      is_active_venue_manager() as the only permission source.
--
-- This revises a settled CLAUDE.md decision on purpose (decided by the
-- product owner on 2026-10-28): a manager may now change display_order
-- AND framing on published photos, never the image or its alt text.
-- Framing is presentation of the same verified photo, not new content,
-- so it needs no review. enforce_manager_photo_reorder_only() still
-- refuses every direct client UPDATE to focus_x/focus_y/zoom (and now
-- zoom too), so framing changes only ever go through the RPC's checks —
-- the same "RPC only, never a direct write" rule display_order follows.
--
-- Rendering semantics (matching news_articles.focus_x/focus_y's existing
-- use): with BoxFit.cover, Alignment(focus_x * 2 - 1, focus_y * 2 - 1),
-- then scaled by zoom around that same alignment point. One framing
-- serves both the wide header and the square card.
--
-- restaurants_full/hotels_full gain cover_focus_x/cover_focus_y/
-- cover_zoom from the same LATERAL cover-photo join that already
-- supplies cover_photo_url, appended at the end (CREATE OR REPLACE VIEW
-- can only add columns there); otherwise identical to 20261006120000.
--
-- Rollout order matters: the new build selects focus_x/focus_y/zoom by
-- name, which fails against a database without these columns, so this
-- goes to production BEFORE that build. Builds already installed select
-- their own explicit column lists and are unaffected.
--
-- Real date: 2026-10-28. The filename is a sequence number, the next one
-- after the highest existing migration (20261013120000), per CLAUDE.md.

begin;

-- ============================================================
-- 1. Columns
-- ============================================================

alter table public.restaurant_photos
  add column zoom numeric not null default 1 check (zoom between 1 and 4);
alter table public.hotel_photos
  add column zoom numeric not null default 1 check (zoom between 1 and 4);
alter table public.private_chef_photos
  add column zoom numeric not null default 1 check (zoom between 1 and 4);

alter table public.venue_photo_submissions
  add column focus_x numeric not null default 0.5 check (focus_x between 0 and 1),
  add column focus_y numeric not null default 0.5 check (focus_y between 0 and 1),
  add column zoom numeric not null default 1 check (zoom between 1 and 4);

-- ============================================================
-- 2. Direct client UPDATEs still may not touch framing (zoom added to
--    the existing list). Not security definer, same as before.
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
    then
      raise exception 'Only display_order may be changed directly by a venue manager; framing goes through set_venue_photo_framing().';
    end if;
  end if;
  return new;
end;
$$;

-- ============================================================
-- 3. set_venue_photo_framing() — the only way a manager changes a
--    published photo's framing.
-- ============================================================

create function public.set_venue_photo_framing(
  p_venue_type text,
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
  v_venue_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef') then
    raise exception 'Unknown venue_type: %', p_venue_type;
  end if;
  if p_focus_x is null or p_focus_y is null or p_zoom is null
    or p_focus_x not between 0 and 1
    or p_focus_y not between 0 and 1
    or p_zoom not between 1 and 4
  then
    raise exception 'Framing out of range: focus 0..1, zoom 1..4';
  end if;

  v_venue_id := case p_venue_type
    when 'restaurant' then
      (select rp.restaurant_id from public.restaurant_photos rp where rp.id = p_photo_id)
    when 'hotel' then
      (select hp.hotel_id from public.hotel_photos hp where hp.id = p_photo_id)
    else
      (select pcp.private_chef_id from public.private_chef_photos pcp where pcp.id = p_photo_id)
  end;
  if v_venue_id is null then
    raise exception 'No % photo %', p_venue_type, p_photo_id;
  end if;
  if not public.is_active_venue_manager(p_venue_type, v_venue_id) then
    raise exception 'Not an active manager of this venue';
  end if;

  if p_venue_type = 'restaurant' then
    update public.restaurant_photos
      set focus_x = p_focus_x, focus_y = p_focus_y, zoom = p_zoom
      where id = p_photo_id;
  elsif p_venue_type = 'hotel' then
    update public.hotel_photos
      set focus_x = p_focus_x, focus_y = p_focus_y, zoom = p_zoom
      where id = p_photo_id;
  else
    update public.private_chef_photos
      set focus_x = p_focus_x, focus_y = p_focus_y, zoom = p_zoom
      where id = p_photo_id;
  end if;
end;
$$;

revoke execute on function public.set_venue_photo_framing(text, uuid, numeric, numeric, numeric) from public, anon;
grant execute on function public.set_venue_photo_framing(text, uuid, numeric, numeric, numeric) to authenticated;

-- ============================================================
-- 4. approve_venue_photo() carries the submission's framing across.
--    Same signature and return type, so CREATE OR REPLACE keeps its
--    existing ACL (dashboard / service_role only); the revoke is
--    restated anyway so this file says so on its own.
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
        returning rp.display_order into v_display_order;
    elsif v_sub.venue_type = 'hotel' then
      delete from public.hotel_photos hp
        where hp.id = v_sub.replaces_photo_id and hp.hotel_id = v_sub.venue_id
        returning hp.display_order into v_display_order;
    else
      delete from public.private_chef_photos pcp
        where pcp.id = v_sub.replaces_photo_id and pcp.private_chef_id = v_sub.venue_id
        returning pcp.display_order into v_display_order;
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
  -- carries none.
  if v_sub.venue_type = 'restaurant' then
    insert into public.restaurant_photos (restaurant_id, image_url, display_order, focus_x, focus_y, zoom)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom)
      returning id into v_new_id;
  elsif v_sub.venue_type = 'hotel' then
    insert into public.hotel_photos (hotel_id, image_url, display_order, focus_x, focus_y, zoom)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom)
      returning id into v_new_id;
  else
    insert into public.private_chef_photos (private_chef_id, image_url, display_order, focus_x, focus_y, zoom)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom)
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
-- 5. Cover framing on the two full views.
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
  cover.zoom as cover_zoom
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
) cover on true;

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
  cover.zoom as cover_zoom
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
) cover on true;

commit;
