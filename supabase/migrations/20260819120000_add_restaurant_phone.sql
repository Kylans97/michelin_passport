-- Restaurant Enrichment Step 1D — generic contact architecture.
--
-- Adds a single nullable `phone` column to `public.restaurants` and
-- exposes it through `restaurants_full`. No format constraint on the
-- column: this must never reject a legitimate international number.
-- Stores the human-readable canonical representation only (e.g.
-- "+31 (0)10 436 07 66") -- the Flutter app derives a machine-safe `tel:`
-- URI from this at call time (see lib/core/utils/phone_utils.dart) rather
-- than storing a second representation.
--
-- IMPORTANT — why this migration recreates the view instead of relying on
-- `r.*`: `restaurants_full` (see
-- 20260811220000_gault_millau_provenance_and_hall_of_fame_fix.sql)
-- previously selected `r.*` from `public.restaurants` before its derived
-- columns. That looked like it would auto-expose any new restaurants
-- column with zero view change, but validating this locally proved that
-- assumption wrong: a Postgres view expands `r.*` into a concrete,
-- ordinal-positioned column list AT CREATE TIME, not on every query — it
-- does not track the base table's columns live. Once `phone` is added to
-- `restaurants`, a plain `create or replace view ... select r.*, ...`
-- fails outright with "cannot change name of view column ... to phone",
-- because the new column lands in the MIDDLE of the view's existing
-- ordinal positions (right after updated_at, before is_in_hotel) —
-- `CREATE OR REPLACE VIEW` only ever allows appending new output columns
-- at the very end, never inserting one partway through. This is exactly
-- the "column ordinal position" hazard the Gault&Millau migration's own
-- header comment warned about for hand-added columns; `r.*` turns out to
-- carry the same hazard implicitly, since it re-expands on every
-- `CREATE OR REPLACE`.
--
-- The fix, validated locally: replace `r.*` with an explicit, ordinal-
-- pinned list of every current `restaurants` column (mirroring this
-- project's own established "never select *" convention already used for
-- every Dart-side *FullColumns constant), then append `phone` as a new
-- final column after the view's existing derived columns
-- (is_hall_of_fame). This is a genuine append-only change — every
-- existing output column keeps its exact name and ordinal position — so
-- `CREATE OR REPLACE VIEW` succeeds and, critically, PRESERVES the view's
-- existing grants automatically (confirmed locally: a `drop view` +
-- `create view` resets grants to just the owner, requiring them to be
-- manually restored, whereas `create or replace view` left every existing
-- grantee untouched in the local test). No `drop view` is used here for
-- exactly that reason — production's anon/authenticated SELECT grants on
-- this view are far too important to risk on a manual re-grant.
--
-- No RLS change: `restaurants_public_read` is a table-level `select`
-- policy on `restaurants` (no column-level restriction exists on this
-- table today, confirmed against information_schema.column_privileges),
-- so it already covers the new `phone` column exactly like every other
-- restaurants column. No client write grant exists or is added -- this
-- remains an admin/service-role-managed catalogue column, matching every
-- other practical-info field (website_url, michelin_url, google_place_id).
--
-- Deliberately restaurants-only, not hotels -- Restaurant Enrichment Step
-- 1D's explicit scope. Hotel phone parity (HotelDetailScreen has the
-- identical always-null onCall seam, and hotels_full has the same `h.*`
-- -expansion hazard this migration just worked around) is a natural,
-- separate follow-up, not implemented here.

begin;

alter table public.restaurants add column phone text;

comment on column public.restaurants.phone is
  'Official restaurant phone number, human-readable international format '
  '(e.g. "+31 (0)10 436 07 66"). Nullable -- most restaurants have none '
  'populated yet. No format constraint: must never reject a legitimate '
  'international number. Not a URI -- the Flutter app derives a tel: URI '
  'from this at call time, see lib/core/utils/phone_utils.dart.';

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
  (hr.id is not null or r.property_name is not null) as is_in_hotel,
  coalesce(h.name, r.property_name)                  as hotel_name,
  h.id                                                as hotel_id,
  ci.name                                             as city_name,
  ci.region                                           as region,
  co.name                                             as country_name,
  co.flag_emoji                                       as flag_emoji,
  w.rank                                              as worlds_50_best_rank,
  st_y(r.location::geometry)                          as latitude,
  st_x(r.location::geometry)                          as longitude,
  exists (
    select 1 from public.worlds_50_best hof
    where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame'
  )                                                    as is_hall_of_fame,
  r.phone                                              as phone
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null);

comment on view public.restaurants_full is
  'Read model for the Flutter app -- every restaurants column (explicit '
  'list, not r.* -- see this migration''s own header comment for why) '
  'plus derived is_in_hotel/hotel_name/hotel_id/city_name/region/'
  'country_name/flag_emoji/worlds_50_best_rank/latitude/longitude/'
  'is_hall_of_fame/phone. is_hall_of_fame is derived from '
  'worlds_50_best.list_type = ''hall_of_fame'', never from '
  'restaurants.inclusion_reason -- see the column comment on '
  'restaurants.inclusion_reason for why.';

commit;
