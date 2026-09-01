-- POP-UPS AND TEMPORARY VENUES — extends restaurants/hotels/private_chefs
-- rather than adding a new table. A pop-up is not a fourth venue type; it
-- is a restaurant, hotel or private chef with a shelf life, and usually
-- (not always) a relationship to an existing venue.
--
-- ============================================================
-- FIELDS, PER TABLE
-- ============================================================
--
-- starts_on / ends_on (date): both null means an ordinary permanent
-- venue — the existing, unchanged meaning of every current row. A venue
-- with ends_on set is, by definition, temporary; that single fact is
-- the entire distinction this migration adds. No separate is_popup
-- boolean exists or is needed — it would just be a cache of "ends_on is
-- not null" that could drift from the dates themselves.
--
-- parent_venue_type / parent_venue_id: generic, no single-table FK —
-- Petit Péché-on-the-beach is a restaurant with a restaurant parent; a
-- hotel's beach club is a restaurant with a HOTEL parent; Lucas
-- popping up somewhere for eight weekends is a private chef with a
-- private chef parent. A real FK can only ever point at one table, so
-- this follows the same typed-discriminator-with-no-FK shape this
-- schema already uses for exactly this "points at one of several
-- catalogue tables" problem (venue_type/venue_id on claims_*/venue_
-- ratings/venue_photo_submissions/venue_about_submissions/venue_
-- corrections, 20260828120000) — resolved by the application/admin
-- layer, not enforced by a constraint the database structurally cannot
-- express. Both columns are optional together: a pop-up with no parent
-- is a normal, expected case (a brand-new concept with no prior
-- venue), not an error state.
--
-- opening_pattern: modelled as `opening_weekdays smallint[]`, an array
-- of ISO 8601 weekday numbers (1=Monday .. 7=Sunday — the same numbering
-- Postgres's own `extract(isodow from date)` returns, so a future "is
-- this venue open on date X" query is a one-line `extract(isodow from
-- x) = any(opening_weekdays)`, no lookup table needed). "Alleen vrijdag
-- tot en met zondag" is simply `{5,6,7}`. NULL means no weekday
-- restriction — the venue's own normal schedule applies, exactly like
-- every existing permanent venue today (this column defaulting to null
-- changes nothing about any current row).
--
-- Deliberately NOT built: opening TIMES, exceptions/holidays, multiple
-- date ranges per venue (a pop-up that runs two separate weekends a
-- month apart), or recurrence rules beyond a weekly weekday set. Any of
-- those would start to be a real calendar/scheduling system, which is
-- explicitly out of scope — `opening_weekdays` answers exactly one
-- question ("which days of the week, within [starts_on, ends_on],
-- does this run") and nothing more. If a venue's actual pattern doesn't
-- fit that (irregular one-off dates), leave the array null and let the
-- venue's own about-text/description carry the nuance in prose — the
-- same fallback this schema already leans on for other cases language
-- can express more precisely than a taxonomy can (see
-- private_chef_restaurant_history.period_text's own identical
-- reasoning).
--
-- ============================================================
-- WHY status (venue_status) IS UNTOUCHED AND UNRELATED
-- ============================================================
--
-- restaurants/hotels already have `status public.venue_status`
-- ('open'/'temporarily_closed'/'permanently_closed') — a DIFFERENT
-- axis, describing whether an otherwise-permanent venue is currently
-- operating, not whether it has a scheduled run at all. This migration
-- does not derive, sync, or validate `status` against `starts_on`/
-- `ends_on` in any way — a pop-up's `status` still defaults to 'open'
-- like any other new row and is set the same way every other row's
-- status already is (manually, by whoever curates the catalogue). Two
-- independent facts about a venue, not one collapsed into the other.
--
-- ============================================================
-- VISIBILITY — nothing here changes, on purpose
-- ============================================================
--
-- "Een verlopen pop-up verdwijnt niet uit de app": no RLS policy is
-- touched by this migration. restaurants_public_read/hotels_public_
-- read are already unconditional (`using (true)`); private_chefs_
-- public_read already gates on publication_status, unrelated to these
-- new columns. An expired pop-up stays exactly as readable as it was
-- the day before it expired — recognizing "expired" is simply `ends_on
-- < current_date` on a real, always-current date column, computable by
-- any query or view without a separate flag to keep in sync. What
-- reads that fact and decides whether to still show it is a screen-
-- level decision for later, not something this migration or its RLS
-- makes on any screen's behalf.
--
-- Everywhere this recognizability actually has downstream consequences
-- (rankings, event-discovery, search) is catalogued separately, NOT
-- changed here — see the accompanying report, not this file, for that
-- list. This migration only adds the columns and their constraints.
--
-- PREPARED, NOT APPLIED.

begin;

-- ============================================================
-- 1. RESTAURANTS
-- ============================================================

alter table public.restaurants
  add column starts_on date,
  add column ends_on   date,
  add column parent_venue_type text
    check (parent_venue_type is null or parent_venue_type in ('restaurant', 'hotel', 'private_chef')),
  add column parent_venue_id uuid,
  add column opening_weekdays smallint[]
    check (opening_weekdays is null or opening_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]);

alter table public.restaurants
  add constraint restaurants_ends_on_requires_starts_on
    check (ends_on is null or starts_on is not null),
  add constraint restaurants_parent_venue_paired
    check ((parent_venue_type is null) = (parent_venue_id is null)),
  add constraint restaurants_parent_not_self
    check (parent_venue_type is distinct from 'restaurant' or parent_venue_id is distinct from id);

-- "Which pop-ups belong to this parent" — the natural query direction;
-- there is no equivalent "which venues does X pop-up have" query (a
-- venue has at most one parent, already indexed by its own primary key).
create index restaurants_parent_venue_idx
  on public.restaurants (parent_venue_type, parent_venue_id)
  where parent_venue_id is not null;

-- "Which venues are currently/soon temporary" — sparse by construction
-- (null for every permanent venue, the overwhelming majority of rows).
create index restaurants_ends_on_idx
  on public.restaurants (ends_on)
  where ends_on is not null;

-- ============================================================
-- 2. HOTELS
-- ============================================================

alter table public.hotels
  add column starts_on date,
  add column ends_on   date,
  add column parent_venue_type text
    check (parent_venue_type is null or parent_venue_type in ('restaurant', 'hotel', 'private_chef')),
  add column parent_venue_id uuid,
  add column opening_weekdays smallint[]
    check (opening_weekdays is null or opening_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]);

alter table public.hotels
  add constraint hotels_ends_on_requires_starts_on
    check (ends_on is null or starts_on is not null),
  add constraint hotels_parent_venue_paired
    check ((parent_venue_type is null) = (parent_venue_id is null)),
  add constraint hotels_parent_not_self
    check (parent_venue_type is distinct from 'hotel' or parent_venue_id is distinct from id);

create index hotels_parent_venue_idx
  on public.hotels (parent_venue_type, parent_venue_id)
  where parent_venue_id is not null;

create index hotels_ends_on_idx
  on public.hotels (ends_on)
  where ends_on is not null;

-- ============================================================
-- 3. PRIVATE_CHEFS
-- ============================================================

alter table public.private_chefs
  add column starts_on date,
  add column ends_on   date,
  add column parent_venue_type text
    check (parent_venue_type is null or parent_venue_type in ('restaurant', 'hotel', 'private_chef')),
  add column parent_venue_id uuid,
  add column opening_weekdays smallint[]
    check (opening_weekdays is null or opening_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]);

alter table public.private_chefs
  add constraint private_chefs_ends_on_requires_starts_on
    check (ends_on is null or starts_on is not null),
  add constraint private_chefs_parent_venue_paired
    check ((parent_venue_type is null) = (parent_venue_id is null)),
  add constraint private_chefs_parent_not_self
    check (parent_venue_type is distinct from 'private_chef' or parent_venue_id is distinct from id);

create index private_chefs_parent_venue_idx
  on public.private_chefs (parent_venue_type, parent_venue_id)
  where parent_venue_id is not null;

create index private_chefs_ends_on_idx
  on public.private_chefs (ends_on)
  where ends_on is not null;

commit;
