-- VENUE CLAIMS, SUBMITTED CONTENT, CORRECTIONS AND COMMUNITY RANKINGS —
-- database and RLS only, no UI in this slice.
--
-- ============================================================
-- WHAT ALREADY EXISTS — read first, nothing below duplicates it
-- ============================================================
--
-- 1. "Community rankings" for restaurants already exist:
--    `public.restaurant_rankings` (20260824120000), sourced from
--    `visits.rating` (a personal, dated visit log; multiple visits per
--    user are normal and expected), restaurant-only, all-time (no
--    rolling window), threshold hardcoded inline (>= 3 raters, chosen
--    by a one-off production data audit at authoring time, not a named
--    constant). This migration does NOT touch, extend or replace it —
--    what this task asks for is a genuinely different mechanism: one
--    CURRENT rating per user per venue (not a dated history; a new
--    rating overwrites the old one), across all three venue types
--    (restaurant/hotel/private chef, not restaurants only), on a
--    rolling 365-day window, excluding a venue's own approved
--    claimants, with an adjustable named threshold. That is `public.
--    venue_ratings` + `public.venue_community_rankings` below — a
--    parallel, purpose-built table, not a migration of `visits`.
--    Reconciling the two (or retiring one) is a product decision, out
--    of scope here — flagging it rather than guessing.
--
-- 2. "Submitted events, pending review" already exists in the exact
--    shape this task wants: `public.events.moderation_status`
--    ('draft'/'submitted'/'published'/'archived'/'rejected',
--    20260819140000) plus the typed `event_restaurants`/`event_hotels`/
--    `event_chefs` join tables. This migration does NOT create a new
--    events-submission table — it adds `events.submitted_by` and the
--    INSERT/SELECT policies needed to let an approved claimant submit
--    an event for their own venue through that existing machinery (see
--    §9 below). Building a second events table would duplicate this.
--
-- 3. "Published venue photos, capped at 5" already exists for private
--    chefs: `public.private_chef_photos` + `enforce_private_chef_photo_
--    limit()` (20260818120000). No restaurant/hotel equivalent exists.
--    This migration adds `restaurant_photos`/`hotel_photos`, mirroring
--    that exact shape (same columns, same max-5 trigger pattern, same
--    admin-only-write RLS) rather than inventing a different one — see
--    §4.
--
-- ============================================================
-- ARCHITECTURAL CHOICES — stated so they can be overridden
-- ============================================================
--
-- CLAIMS use three typed-FK tables (claims_restaurants/claims_hotels/
-- claims_private_chefs), not one polymorphic table — this schema's
-- consistent, repeated, explicit precedent for a NEW catalogue-linking
-- relationship (follows_restaurants/follows_hotels/follows_private_
-- chefs; event_restaurants/event_hotels/event_chefs; see
-- EVENTS_V2_ARCHITECTURE.md §6.2/§6.3's "Recommendation: B, dedicated
-- typed join tables" reasoning). A claim is exactly this shape: a
-- membership fact linking one user to one venue.
--
-- SUBMITTED CONTENT (venue_about_submissions, venue_photo_submissions,
-- venue_corrections) and RATINGS (venue_ratings) instead use ONE table
-- each with a polymorphic (venue_type, venue_id) pair, no FK — matching
-- `visits`/`wishlist`/`photos`' own established reasoning (DATABASE_
-- ARCHITECTURE.md §15.6/line 323): these are content RECORDS about a
-- venue, not membership relationships, and a cross-venue-type query
-- ("this venue's current about text," "this venue's community rating"
-- regardless of type) is exactly the shape that reasoning was written
-- for. Authorization against the typed claims tables is centralized in
-- one helper function (`has_approved_venue_claim`, §2) so every content
-- table's policy stays a one-line call instead of repeating a three-way
-- branch. This is a genuine judgment call, not a dictated precedent —
-- flagged here deliberately.
--
-- CORRECTIONS are NOT gated by an approved claim, unlike the other
-- three submission types — re-reading the brief, "CORRECTIEMELDINGEN"
-- is its own heading, separate from "INGEDIENDE CONTENT," and a
-- crowd-sourced "this address is wrong" report is only useful if any
-- signed-in user can file one, not only a venue's own claimant. If that
-- reading is wrong, the insert policy in §7 is the one line to change.
--
-- STATUS VALUES stay English ('open'/'resolved', not 'open'/
-- 'afgehandeld') to match every other status/taxonomy column in this
-- schema, which is English throughout even though this migration was
-- specified in Dutch.
--
-- MINIMUM PHOTO RESOLUTION cannot be enforced at this layer at all —
-- Supabase Storage buckets validate MIME type and byte size (both
-- enforced below) but have no concept of image pixel dimensions, and a
-- CHECK constraint can't inspect file bytes. Enforcing "minimale
-- resolutie" needs either a client-side check before upload or a
-- server-side Edge Function that inspects the object after upload and
-- removes/flags it if too small — neither exists yet. Stated here
-- rather than silently claiming this requirement is met.
--
-- PREPARED, NOT APPLIED.

begin;

-- ============================================================
-- 1. CLAIMS — claims_restaurants / claims_hotels / claims_private_chefs
-- ============================================================
--
-- Same shape as follows_restaurants/follows_hotels/follows_private_
-- chefs (id, user_id, {venue}_id, unique membership), plus the
-- moderation fields this task asks for: status, requested_at,
-- reviewed_at, reviewed_by. "Eén gebruiker kan meerdere venues
-- claimen; een venue kan meerdere gekoppelde gebruikers hebben" is the
-- default many-to-many shape of this table — no extra constraint
-- needed for it.
--
-- The unique constraint is a PARTIAL index on (user_id, venue_id) WHERE
-- status IN ('pending','approved') rather than a plain unique(user_id,
-- venue_id): a plain constraint would permanently block a second claim
-- attempt after a rejection, with no way back in short of an admin
-- manually deleting the row. A rejected claim frees the pair for a new
-- attempt; a pending or approved one still blocks a duplicate.

create table public.claims_restaurants (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  status        text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  requested_at  timestamptz not null default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references public.profiles(id) on delete set null
);

create table public.claims_hotels (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  hotel_id      uuid not null references public.hotels(id) on delete cascade,
  status        text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  requested_at  timestamptz not null default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references public.profiles(id) on delete set null
);

create table public.claims_private_chefs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  private_chef_id uuid not null references public.private_chefs(id) on delete cascade,
  status          text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  requested_at    timestamptz not null default now(),
  reviewed_at     timestamptz,
  reviewed_by     uuid references public.profiles(id) on delete set null
);

create unique index claims_restaurants_active_uidx
  on public.claims_restaurants (user_id, restaurant_id)
  where status in ('pending', 'approved');
create unique index claims_hotels_active_uidx
  on public.claims_hotels (user_id, hotel_id)
  where status in ('pending', 'approved');
create unique index claims_private_chefs_active_uidx
  on public.claims_private_chefs (user_id, private_chef_id)
  where status in ('pending', 'approved');

-- Composite indexes above already serve "this user's claims" (user_id
-- leftmost); each venue side needs its own index for "who has claimed
-- this venue" (admin review queues).
create index claims_restaurants_restaurant_idx on public.claims_restaurants (restaurant_id);
create index claims_hotels_hotel_idx on public.claims_hotels (hotel_id);
create index claims_private_chefs_chef_idx on public.claims_private_chefs (private_chef_id);

alter table public.claims_restaurants enable row level security;
alter table public.claims_hotels enable row level security;
alter table public.claims_private_chefs enable row level security;

-- Owner-only read: a claim is private application state, not public
-- discovery content — nobody, anon or authenticated, sees another
-- user's claim, pending or approved.
create policy claims_restaurants_own_read on public.claims_restaurants
  for select to authenticated using (user_id = auth.uid());
create policy claims_hotels_own_read on public.claims_hotels
  for select to authenticated using (user_id = auth.uid());
create policy claims_private_chefs_own_read on public.claims_private_chefs
  for select to authenticated using (user_id = auth.uid());

-- Any signed-in user may file a claim on themselves — this is the
-- request, not the grant; nothing becomes true until the status
-- changes, and only the reviewer (service role — see §10) can do that.
create policy claims_restaurants_insert on public.claims_restaurants
  for insert to authenticated with check (user_id = auth.uid());
create policy claims_hotels_insert on public.claims_hotels
  for insert to authenticated with check (user_id = auth.uid());
create policy claims_private_chefs_insert on public.claims_private_chefs
  for insert to authenticated with check (user_id = auth.uid());

-- No update/delete policy for anon or authenticated on any of the
-- three tables: "alleen ik mag goedkeuren of afwijzen" is enforced by
-- there being no client-facing path to change `status` at all — only
-- the service role (bypasses RLS) can, via §11's manual workflow.

grant select, insert on public.claims_restaurants to authenticated;
grant select, insert on public.claims_hotels to authenticated;
grant select, insert on public.claims_private_chefs to authenticated;

-- ============================================================
-- 2. has_approved_venue_claim — shared authorization helper
-- ============================================================
--
-- Same style as the existing profile_is_visible() helper (production
-- schema v1, §15.3): language sql, stable, security definer (so a
-- caller who can't directly see another row in claims_* — irrelevant
-- here since every branch is already scoped to auth.uid(), but kept
-- for consistency with the established helper-function shape), search
-- path pinned. Every downstream policy calls this instead of repeating
-- a three-way branch over claims_restaurants/claims_hotels/claims_
-- private_chefs.

create function public.has_approved_venue_claim(p_venue_type text, p_venue_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.claims_restaurants c
    where p_venue_type = 'restaurant'
      and c.restaurant_id = p_venue_id
      and c.user_id = auth.uid()
      and c.status = 'approved'
    union all
    select 1 from public.claims_hotels c
    where p_venue_type = 'hotel'
      and c.hotel_id = p_venue_id
      and c.user_id = auth.uid()
      and c.status = 'approved'
    union all
    select 1 from public.claims_private_chefs c
    where p_venue_type = 'private_chef'
      and c.private_chef_id = p_venue_id
      and c.user_id = auth.uid()
      and c.status = 'approved'
  );
$$;

revoke execute on function public.has_approved_venue_claim(text, uuid) from public;
grant execute on function public.has_approved_venue_claim(text, uuid) to authenticated;

-- ============================================================
-- 3. venue_about_submissions — pending "about" text per venue
-- ============================================================
--
-- 900-char cap mirrors private_chefs.biography's own hard limit
-- (20260818120000) — the closest existing precedent for "editorial
-- venue-about text," reused here for the same reason it was chosen
-- there rather than left unbounded.
--
-- No copy-back onto restaurants/hotels/private_chefs: "only the
-- service role writes the catalogue" (DATABASE_ARCHITECTURE.md §15.2)
-- stays true unmodified. A venue's current about text is DERIVED —
-- the latest approved submission for that venue, via the
-- venue_about_current view below — never written into an existing
-- catalogue table's column.

create table public.venue_about_submissions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  venue_type    text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id      uuid not null,
  about_text    text not null check (char_length(about_text) <= 900),
  status        text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  submitted_at  timestamptz not null default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references public.profiles(id) on delete set null
);

create index venue_about_submissions_venue_idx
  on public.venue_about_submissions (venue_type, venue_id);

alter table public.venue_about_submissions enable row level security;

create policy venue_about_submissions_own_read on public.venue_about_submissions
  for select to authenticated using (user_id = auth.uid());

create policy venue_about_submissions_public_read on public.venue_about_submissions
  for select to anon, authenticated using (status = 'approved');

create policy venue_about_submissions_insert on public.venue_about_submissions
  for insert to authenticated with check (
    user_id = auth.uid()
    and public.has_approved_venue_claim(venue_type, venue_id)
  );

-- No update/delete for anon/authenticated — see §1's closing note.

grant select, insert on public.venue_about_submissions to authenticated;
grant select on public.venue_about_submissions to anon;

-- The base table already grants anon/authenticated read of approved
-- rows (above), so this view is safe as security_invoker — unlike
-- venue_community_rankings (§8), which must aggregate across rows the
-- caller cannot individually see.
create view public.venue_about_current
with (security_invoker = true)
as
select distinct on (venue_type, venue_id)
  venue_type, venue_id, about_text, reviewed_at as approved_at
from public.venue_about_submissions
where status = 'approved'
order by venue_type, venue_id, reviewed_at desc nulls last, submitted_at desc;

grant select on public.venue_about_current to anon, authenticated;

-- ============================================================
-- 4. restaurant_photos / hotel_photos — the missing published-photo
--    destinations, mirroring private_chef_photos exactly
-- ============================================================

create table public.restaurant_photos (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references public.restaurants(id) on delete cascade,
  image_url      text not null,
  alt_text       text,
  display_order  smallint not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint restaurant_photos_display_order_unique unique (restaurant_id, display_order)
);

create table public.hotel_photos (
  id             uuid primary key default gen_random_uuid(),
  hotel_id       uuid not null references public.hotels(id) on delete cascade,
  image_url      text not null,
  alt_text       text,
  display_order  smallint not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint hotel_photos_display_order_unique unique (hotel_id, display_order)
);

create trigger restaurant_photos_updated_at
  before update on public.restaurant_photos
  for each row execute function public.set_updated_at();
create trigger hotel_photos_updated_at
  before update on public.hotel_photos
  for each row execute function public.set_updated_at();

create function public.enforce_restaurant_photo_limit()
returns trigger
language plpgsql
as $$
begin
  if (
    select count(*) from public.restaurant_photos
    where restaurant_id = new.restaurant_id
  ) >= 5 then
    raise exception
      'restaurant_photos: restaurant % already has the maximum of 5 photos',
      new.restaurant_id;
  end if;
  return new;
end;
$$;

create function public.enforce_hotel_photo_limit()
returns trigger
language plpgsql
as $$
begin
  if (
    select count(*) from public.hotel_photos
    where hotel_id = new.hotel_id
  ) >= 5 then
    raise exception
      'hotel_photos: hotel % already has the maximum of 5 photos',
      new.hotel_id;
  end if;
  return new;
end;
$$;

create trigger restaurant_photos_max_five
  before insert on public.restaurant_photos
  for each row execute function public.enforce_restaurant_photo_limit();
create trigger hotel_photos_max_five
  before insert on public.hotel_photos
  for each row execute function public.enforce_hotel_photo_limit();

create index restaurant_photos_restaurant_idx on public.restaurant_photos (restaurant_id);
create index hotel_photos_hotel_idx on public.hotel_photos (hotel_id);

alter table public.restaurant_photos enable row level security;
alter table public.hotel_photos enable row level security;

-- Same predicate shape as private_chef_photos_public_read: gated on
-- the parent venue's own live/published state, not a separate flag.
create policy restaurant_photos_public_read on public.restaurant_photos
  for select to anon, authenticated using (
    exists (select 1 from public.restaurants r where r.id = restaurant_id and r.status = 'open')
  );
create policy hotel_photos_public_read on public.hotel_photos
  for select to anon, authenticated using (
    exists (select 1 from public.hotels h where h.id = hotel_id and h.status = 'open')
  );

-- No insert/update/delete policy for any client role — admin-managed,
-- exactly like private_chef_photos. A submission never writes here
-- directly; only the manual approval step (§11) does, via service role.

grant select on public.restaurant_photos to anon, authenticated;
grant select on public.hotel_photos to anon, authenticated;

-- ============================================================
-- 5. venue_photo_submissions — pending photos, capped-replacement rule
-- ============================================================
--
-- replaces_photo_id has no FK: the row it names lives in whichever of
-- restaurant_photos/hotel_photos/private_chef_photos matches venue_
-- type, so no single FK target exists — same "resolved by whoever
-- reads it, not enforced by a constraint" reasoning as visits.entity_id/
-- wishlist.entity_id already use for their own no-FK polymorphic
-- pointers. The trigger below only checks it is NOT NULL when the venue
-- is already at the 5-photo cap; it does not (and structurally cannot,
-- without the FK) verify the id actually belongs to that venue — the
-- manual review step (§11) is expected to catch a wrong id.

create table public.venue_photo_submissions (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  venue_type         text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id           uuid not null,
  storage_path       text not null,
  replaces_photo_id  uuid,
  status             text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  submitted_at       timestamptz not null default now(),
  reviewed_at        timestamptz,
  reviewed_by        uuid references public.profiles(id) on delete set null
);

create index venue_photo_submissions_venue_idx
  on public.venue_photo_submissions (venue_type, venue_id);

-- "Een inzending die daar overheen gaat moet aangeven welke bestaande
-- foto vervangen wordt": if the venue already has 5 published photos
-- and this submission doesn't name one to replace, reject it outright
-- rather than accepting an unreviewable, unpublishable submission.
create function public.enforce_photo_submission_replacement()
returns trigger
language plpgsql
as $$
declare
  published_count integer;
begin
  if new.venue_type = 'restaurant' then
    select count(*) into published_count from public.restaurant_photos
    where restaurant_id = new.venue_id;
  elsif new.venue_type = 'hotel' then
    select count(*) into published_count from public.hotel_photos
    where hotel_id = new.venue_id;
  else
    select count(*) into published_count from public.private_chef_photos
    where private_chef_id = new.venue_id;
  end if;

  if published_count >= 5 and new.replaces_photo_id is null then
    raise exception
      'venue_photo_submissions: venue % (%) already has % published photos — a submission at the cap must set replaces_photo_id',
      new.venue_id, new.venue_type, published_count;
  end if;

  return new;
end;
$$;

create trigger venue_photo_submissions_replacement_check
  before insert on public.venue_photo_submissions
  for each row execute function public.enforce_photo_submission_replacement();

alter table public.venue_photo_submissions enable row level security;

create policy venue_photo_submissions_own_read on public.venue_photo_submissions
  for select to authenticated using (user_id = auth.uid());

create policy venue_photo_submissions_public_read on public.venue_photo_submissions
  for select to anon, authenticated using (status = 'approved');

create policy venue_photo_submissions_insert on public.venue_photo_submissions
  for insert to authenticated with check (
    user_id = auth.uid()
    and public.has_approved_venue_claim(venue_type, venue_id)
  );

grant select, insert on public.venue_photo_submissions to authenticated;
grant select on public.venue_photo_submissions to anon;

-- ============================================================
-- 6. Storage — private pending-photo bucket
-- ============================================================
--
-- Private (public = false), distinct from the existing public
-- `catalogue-media` bucket (20260818150000): nobody but the submitter
-- may read an unreviewed photo. Approval moves the object across
-- buckets by hand (§11) — catalogue-media is the existing, already-
-- public destination, no new public bucket needed.
--
-- JPEG/PNG only (not the webp/heic the other two buckets allow) and
-- 5 MiB, both direct readings of "Beperk bij upload tot JPEG en PNG,
-- maximaal een paar MB" — 5 MiB is this migration's proposed reading
-- of "a couple MB," adjustable in one line if a different number was
-- meant. Minimum resolution is NOT enforced here — see the file header.
--
-- Object path: {venue_type}/{venue_id}/{user_id}/{filename} — every
-- policy below reads storage.foldername(name) the same way visit-
-- photos' bucket policies already do ([1]/[2]/[3] are the three folder
-- segments, filename excluded).

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'venue-photo-submissions',
  'venue-photo-submissions',
  false,
  5242880, -- 5 MiB per object
  array['image/jpeg', 'image/png']
)
on conflict (id) do nothing;

create policy venue_photo_submissions_storage_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'venue-photo-submissions'
    and (storage.foldername(name))[3] = auth.uid()::text
  );

create policy venue_photo_submissions_storage_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'venue-photo-submissions'
    and (storage.foldername(name))[3] = auth.uid()::text
    and public.has_approved_venue_claim(
      (storage.foldername(name))[1],
      ((storage.foldername(name))[2])::uuid
    )
  );

-- No delete policy: a submitter cannot withdraw an uploaded object
-- once sent, matching the "no update/delete on the submission row
-- either" stance above. Not asked for; can be added later if wanted.

-- ============================================================
-- 7. venue_corrections — simple, unstructured correction reports
-- ============================================================
--
-- Deliberately NOT gated by has_approved_venue_claim — see the file
-- header's "CORRECTIONS are NOT gated" note. No category/structured
-- field, exactly as asked: "die komen pas als ik zie wat er binnenkomt."

create table public.venue_corrections (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  venue_type  text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id    uuid not null,
  message     text not null,
  created_at  timestamptz not null default now(),
  status      text not null default 'open'
    check (status in ('open', 'resolved'))
);

create index venue_corrections_venue_idx on public.venue_corrections (venue_type, venue_id);

alter table public.venue_corrections enable row level security;

-- Owner-only read, no public/approved-content read policy at all: a
-- correction report is never itself published content, unlike the
-- about-text/photo submissions above — only the reporter and the
-- reviewer (service role) ever see it.
create policy venue_corrections_own_read on public.venue_corrections
  for select to authenticated using (user_id = auth.uid());

create policy venue_corrections_insert on public.venue_corrections
  for insert to authenticated with check (user_id = auth.uid());

grant select, insert on public.venue_corrections to authenticated;

-- ============================================================
-- 8. venue_ratings + venue_community_rankings
-- ============================================================
--
-- One row per (user, venue) — "een nieuwe beoordeling vervangt de
-- vorige" is an upsert (insert ... on conflict (user_id, venue_type,
-- venue_id) do update), not a new row; updated_at (via the shared
-- set_updated_at() trigger) is "de datum van de meest recente" and
-- also anchors the rolling 365-day window below, so a rating a user
-- never revisits ages out even without an explicit new submission.
--
-- The claim-exclusion rule is enforced in the INSERT/UPDATE policies'
-- WITH CHECK, not only client-side — RLS is a database mechanism, so
-- this satisfies "dwing dat af in de database, niet alleen in de UI"
-- without a separate trigger.
--
-- Row-level privacy mirrors restaurant_rankings' own stated design
-- exactly (20260824120000): individual ratings are owner-only readable,
-- never public even in single-row form — only the aggregate view
-- exposes venue-level numbers, via SECURITY DEFINER, never a user id.

create table public.venue_ratings (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  venue_type  text not null check (venue_type in ('restaurant', 'hotel', 'private_chef')),
  venue_id    uuid not null,
  rating      smallint not null check (rating between 1 and 10),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, venue_type, venue_id)
);

create trigger venue_ratings_updated_at
  before update on public.venue_ratings
  for each row execute function public.set_updated_at();

create index venue_ratings_venue_idx on public.venue_ratings (venue_type, venue_id);

alter table public.venue_ratings enable row level security;

create policy venue_ratings_own_read on public.venue_ratings
  for select to authenticated using (user_id = auth.uid());

create policy venue_ratings_insert on public.venue_ratings
  for insert to authenticated with check (
    user_id = auth.uid()
    and not public.has_approved_venue_claim(venue_type, venue_id)
  );

create policy venue_ratings_update on public.venue_ratings
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and not public.has_approved_venue_claim(venue_type, venue_id)
  );

grant select, insert, update on public.venue_ratings to authenticated;

-- Two named, adjustable constants — the one place to change either.
-- Both are set to 5 by product direction, but they are NOT the same
-- knob and are kept as two separate functions rather than one shared
-- constant:
--   - venue_ranking_min_reviews: the display gate. Below this many
--     ratings in the window, a venue doesn't appear at all, full stop
--     — no amount of shrinkage makes a 1-review venue meaningful to
--     show as "ranked."
--   - venue_ranking_bayesian_m: the shrinkage weight in the Bayesian
--     average below (score = v/(v+m)*R + m/(v+m)*C). It's the number
--     of "phantom average-C votes" blended into every venue's own
--     rating — at v = m, a venue's own mean R and the global mean C
--     are weighted exactly 50/50; a venue with far more than m reviews
--     is dominated by its own R, one with few by C. Raising m pulls
--     every venue's score harder toward the global average (more
--     conservative ranking, needs more evidence to stand out);
--     lowering it lets a venue's own few ratings swing its score
--     further, faster.
-- Both happen to be 5 today; changing one does not need to change the
-- other.
create function public.venue_ranking_min_reviews()
returns integer
language sql
immutable
as $$ select 5; $$;

create function public.venue_ranking_bayesian_m()
returns numeric
language sql
immutable
as $$ select 5; $$;

create view public.venue_community_rankings
with (security_invoker = false)
as
with recent_ratings as (
  -- Same rolling 365-day window as the rest of this feature — C is
  -- computed from these same rows, never from all-time history, so a
  -- venue's score is never pulled toward ratings that have themselves
  -- already aged out of relevance.
  select venue_type, venue_id, rating
  from public.venue_ratings
  where updated_at >= now() - interval '365 days'
),
-- C: the mean across ALL venues (every type) in the window, computed
-- once — a single global reference point every venue's own average is
-- blended toward, per the brief's own "C het gemiddelde over alle
-- venues in het venster" (not a separate C per venue type).
global_mean as (
  select avg(rating)::numeric as c from recent_ratings
),
aggregated as (
  select
    venue_type,
    venue_id,
    avg(rating)::numeric as venue_mean,
    count(*)::integer as review_count
  from recent_ratings
  group by venue_type, venue_id
  having count(*) >= public.venue_ranking_min_reviews()
),
scored as (
  select
    a.venue_type,
    a.venue_id,
    a.review_count,
    round(a.venue_mean, 2) as community_rating,
    round(
      (a.review_count::numeric / (a.review_count + public.venue_ranking_bayesian_m())) * a.venue_mean
      + (public.venue_ranking_bayesian_m() / (a.review_count + public.venue_ranking_bayesian_m())) * gm.c,
      3
    ) as bayesian_score
  from aggregated a
  cross join global_mean gm
)
select
  'restaurant'::text as venue_type,
  rf.id              as venue_id,
  rf.name,
  rf.city_name       as city,
  rf.flag_emoji      as country_flag,
  s.community_rating,
  s.review_count,
  s.bayesian_score
from scored s
join public.restaurants_full rf on rf.id = s.venue_id and s.venue_type = 'restaurant'
where rf.status = 'open'
union all
select
  'hotel',
  hf.id,
  hf.name,
  hf.city_name,
  hf.flag_emoji,
  s.community_rating,
  s.review_count,
  s.bayesian_score
from scored s
join public.hotels_full hf on hf.id = s.venue_id and s.venue_type = 'hotel'
where hf.status = 'open'
union all
select
  'private_chef',
  pc.id,
  pc.display_name,
  pc.home_city,
  co.flag_emoji,
  s.community_rating,
  s.review_count,
  s.bayesian_score
from scored s
join public.private_chefs pc on pc.id = s.venue_id and s.venue_type = 'private_chef'
left join public.countries co on co.country_code = pc.home_country_code
where pc.publication_status = 'published'
-- Sort by the Bayesian score, not the raw average — community_rating
-- stays in the output for display ("4.8 · 12 reviews"), but ordering
-- by it would let one 10/10 rating outrank a venue with fifty 9s.
order by bayesian_score desc, review_count desc, name asc;

revoke all on public.venue_community_rankings from public;
revoke all on public.venue_community_rankings from anon;
revoke all on public.venue_community_rankings from authenticated;
grant select on public.venue_community_rankings to anon;
grant select on public.venue_community_rankings to authenticated;

-- ============================================================
-- 9. EVENTS — let an approved claimant submit an event for their venue
-- ============================================================
--
-- Reuses the existing moderation_status gate (§ file header, point 2)
-- instead of a new table. submitted_by is nullable and additive —
-- every existing event stays null (admin/import-authored), unaffected.
--
-- Two-step insert, two-step check: the events row alone can't be
-- validated against "a venue I have an approved claim on" (it carries
-- no venue reference itself — that only exists once an event_
-- restaurants/event_hotels/event_chefs row links it), so events_
-- claimant_insert only constrains authorship + starting status; the
-- three join-table insert policies below are what actually check the
-- claim, at the point a specific venue gets attached.

alter table public.events
  add column submitted_by uuid references public.profiles(id) on delete set null;

-- A submitter must be able to see their own pending/rejected event —
-- the existing events_public_read policy only ever shows 'published'
-- rows, which would otherwise make a user's own submission invisible
-- to them, violating nothing but also serving nobody.
create policy events_own_submission_read on public.events
  for select to authenticated using (submitted_by = auth.uid());

create policy events_claimant_insert on public.events
  for insert to authenticated with check (
    submitted_by = auth.uid()
    and moderation_status = 'submitted'
  );

-- Tightened to match "niemand mag pending content van een ander zien":
-- previously `using (true)` (unconditional), which — before this
-- migration, when no non-published event could exist via the app at
-- all — was harmless, but would have exposed a submitter's pending
-- links to everyone the moment user-submitted events became possible.
drop policy event_restaurants_public_read on public.event_restaurants;
create policy event_restaurants_public_read on public.event_restaurants
  for select to anon, authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.moderation_status = 'published')
  );
create policy event_restaurants_own_submission_read on public.event_restaurants
  for select to authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.submitted_by = auth.uid())
  );
create policy event_restaurants_claimant_insert on public.event_restaurants
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'submitted'
    )
    and public.has_approved_venue_claim('restaurant', restaurant_id)
  );

drop policy event_hotels_public_read on public.event_hotels;
create policy event_hotels_public_read on public.event_hotels
  for select to anon, authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.moderation_status = 'published')
  );
create policy event_hotels_own_submission_read on public.event_hotels
  for select to authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.submitted_by = auth.uid())
  );
create policy event_hotels_claimant_insert on public.event_hotels
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'submitted'
    )
    and public.has_approved_venue_claim('hotel', hotel_id)
  );

drop policy event_chefs_public_read on public.event_chefs;
create policy event_chefs_public_read on public.event_chefs
  for select to anon, authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.moderation_status = 'published')
  );
create policy event_chefs_own_submission_read on public.event_chefs
  for select to authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.submitted_by = auth.uid())
  );
create policy event_chefs_claimant_insert on public.event_chefs
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'submitted'
    )
    and public.has_approved_venue_claim('private_chef', chef_id)
  );

grant insert on public.events to authenticated;
grant insert on public.event_restaurants to authenticated;
grant insert on public.event_hotels to authenticated;
grant insert on public.event_chefs to authenticated;

commit;
