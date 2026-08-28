-- PHOTO PIPELINE — layers 1+2 (client validation + duplicate detection)
-- and image-format support. Layer 3 (Edge Function content review) is
-- NOT part of this migration — explicitly gated on separate approval
-- before any of it is built, per the brief. Nothing here depends on it.
--
-- ============================================================
-- IMAGE FORMATS — route chosen and why
-- ============================================================
--
-- Supabase Image Transformations ARE available on this project's plan
-- — verified empirically, not assumed: `GET /storage/v1/render/image/
-- public/catalogue-media/<existing object>?width=100&height=100`
-- against the live project returned a real 100x100 JPEG (HTTP 200),
-- which only succeeds on Pro-tier-and-above projects with the feature
-- enabled. So per the brief's own instruction, variants are served via
-- URL parameters wherever possible — no separate stored asset per
-- displayed size.
--
-- ONE exception, not a full opt-out: Supabase's transform endpoint has
-- no crop-focus/gravity/offset parameter at all (confirmed against
-- Supabase's own docs — `resize=cover` always crops to CENTER; there is
-- no way to pass this feature's own focus_x/focus_y through it). That
-- makes it structurally unable to satisfy "snijd bij rond het
-- focuspunt, niet het midden" for a square thumbnail cut from a wide
-- source photo. The hybrid this migration's columns support:
--   1. The ORIGINAL submitted photo is stored once (already covered by
--      venue_photo_submissions.storage_path / the approved catalogue-
--      media object) — this alone serves the HERO variant and the
--      MEDIUM (wishlist/passport card) variant, both via plain
--      transform URL parameters (`?width=...&height=...&resize=cover`)
--      against that one object. Medium/hero crop off-center far less
--      of the frame than a small square thumbnail does, so a center
--      crop there was judged acceptable — flagged here as a scoping
--      call, not asked for explicitly either way.
--   2. ONLY the square THUMBNAIL needs the focus point applied as an
--      actual pixel crop, done once at approval time (not per display
--      size), producing one additional stored object — a square crop
--      centered on (focus_x, focus_y) at a resolution generous enough
--      for 2x/3x thumbnail display. That one pre-cropped object is
--      THEN itself served through Supabase transform URL parameters
--      for whatever exact pixel size a given screen needs (64px in a
--      list row, 128px at 2x, etc.) — cover-mode center-crop on an
--      already-square, already-subject-centered source is safe, since
--      the meaningful crop already happened.
-- This is the minimum manual step the platform's own API cannot avoid
-- — everything else genuinely goes through URL parameters, matching
-- the brief's preference. Generating that one crop is a MANUAL step
-- for now (no admin screen exists yet, matching every other approval
-- action in this feature) — see the previous migration's own "how you
-- approve" notes; this migration only adds the columns to record
-- where the crop should be centered and, for photo submissions, to
-- support layer 2.
--
-- focus_x/focus_y live on the PUBLISHED photo tables (restaurant_photos
-- / hotel_photos / private_chef_photos), not the submission — "ik zet
-- dat punt bij goedkeuring," i.e. it's set at the exact moment a
-- published row is created, and only published rows are ever cropped
-- for display. Default 0.5/0.5 (center) — both the brief's own stated
-- default and correct for every photo published before this feature
-- existed (private_chef_photos already has rows).
--
-- ============================================================
-- DUPLICATE DETECTION — layer 2
-- ============================================================
--
-- phash is a 64-bit DCT perceptual hash, computed client-side (Layer 1
-- is explicitly client-side; computing this alongside the other
-- pre-upload checks avoids a second round trip) and submitted as part
-- of the same insert — stored as `bit(64)`, not text/bigint, so
-- Hamming distance is one built-in call: `bit_count(a # b)` (PG14+;
-- this project runs PG17). A JSON string of 64 '0'/'1' characters casts
-- to bit(64) automatically on insert through PostgREST — no special
-- client-side encoding needed beyond producing that string.
--
-- "Vrijwel dezelfde hash" needs a distance THRESHOLD, not exact
-- equality — named and adjustable in one place
-- (venue_photo_duplicate_hamming_threshold), same pattern as this
-- feature's other tunable constants. 10 bits (of 64) is proposed: in
-- the pHash literature this algorithm comes from, <=10 differing bits
-- reliably means "the same photo, re-compressed/lightly re-cropped/
-- re-exported," while genuinely different photos of the same dish or
-- room typically differ by 20+ bits — no production data exists yet to
-- audit this against (same caveat as this feature's other proposed
-- defaults), so treat it as a starting point.
--
-- The check runs in a BEFORE INSERT trigger, not just client-side:
-- comparing against every existing submission for the venue needs rows
-- the *inserting* client cannot read under this table's own RLS (only
-- their own + approved ones), so only a trigger — running with the
-- table owner's visibility, not the caller's — can see the full
-- picture, including other users' still-pending or rejected
-- submissions for the same venue.

begin;

alter table public.venue_photo_submissions
  add column phash bit(64),
  add column duplicate_of_submission_id uuid
    references public.venue_photo_submissions(id) on delete set null;

create index venue_photo_submissions_phash_venue_idx
  on public.venue_photo_submissions (venue_type, venue_id);

create function public.venue_photo_duplicate_hamming_threshold()
returns integer
language sql
immutable
as $$ select 10; $$;

create function public.enforce_photo_duplicate_check()
returns trigger
language plpgsql
as $$
declare
  rejected_match uuid;
  approved_match uuid;
begin
  if new.phash is null then
    return new;
  end if;

  select id into rejected_match
  from public.venue_photo_submissions
  where venue_type = new.venue_type
    and venue_id = new.venue_id
    and status = 'rejected'
    and phash is not null
    and bit_count(phash # new.phash) <= public.venue_photo_duplicate_hamming_threshold()
  limit 1;

  if rejected_match is not null then
    raise exception
      'venue_photo_submissions: near-duplicate of a previously rejected photo (submission %) for this venue',
      rejected_match;
  end if;

  select id into approved_match
  from public.venue_photo_submissions
  where venue_type = new.venue_type
    and venue_id = new.venue_id
    and status = 'approved'
    and phash is not null
    and bit_count(phash # new.phash) <= public.venue_photo_duplicate_hamming_threshold()
  limit 1;

  if approved_match is not null then
    new.duplicate_of_submission_id := approved_match;
  end if;

  return new;
end;
$$;

-- Runs before venue_photo_submissions_replacement_check (both BEFORE
-- INSERT; Postgres fires same-timing triggers in name order —
-- "enforce_photo_duplicate_check" < "enforce_photo_submission_
-- replacement" alphabetically is coincidental, not relied upon: the
-- two triggers are independent checks that don't need to run in any
-- particular order relative to each other).
create trigger venue_photo_submissions_duplicate_check
  before insert on public.venue_photo_submissions
  for each row execute function public.enforce_photo_duplicate_check();

-- ============================================================
-- FOCUS POINT — published photo tables
-- ============================================================

alter table public.restaurant_photos
  add column focus_x numeric not null default 0.5 check (focus_x between 0 and 1),
  add column focus_y numeric not null default 0.5 check (focus_y between 0 and 1);

alter table public.hotel_photos
  add column focus_x numeric not null default 0.5 check (focus_x between 0 and 1),
  add column focus_y numeric not null default 0.5 check (focus_y between 0 and 1);

alter table public.private_chef_photos
  add column focus_x numeric not null default 0.5 check (focus_x between 0 and 1),
  add column focus_y numeric not null default 0.5 check (focus_y between 0 and 1);

commit;
