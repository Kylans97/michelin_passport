begin;

-- ============================================================
-- Fresh Finds — links a restaurant/hotel/event back to the
-- missing_listing_reports row that led to it being added, so Explore can
-- show "found by you, added by us" without ever reading
-- missing_listing_reports itself.
-- ============================================================
--
-- Deliberately a back-reference on the venue tables, not a forward
-- reference read from missing_listing_reports: that table has no select
-- policy for anyone but the operator (dashboard/service role only, see
-- 20260924120000's own comment) -- exposing "which reports have been
-- actioned" would mean punching a new hole in a privacy boundary just
-- established. restaurants/hotels/events are already world-readable
-- (hotels_public_read/restaurants_public_read/events_public_read,
-- 20260805141519/20260810160000), so storing the pointer there needs no
-- new grant, RPC, or view -- Explore just filters on "is this column set"
-- against data it already reads.
--
-- A real foreign key here, unlike the polymorphic type+id columns
-- elsewhere in this schema (content_reports, venue_corrections,
-- missing_listing_reports itself, notifications): each of these three
-- columns only ever points at ONE table, so there's no polymorphism to
-- avoid. `on delete set null`: if a report is ever deleted, the venue it
-- led to stays -- it just loses the attribution, never cascades into
-- deleting a real catalogue row.
--
-- Set by hand on the same INSERT that creates the row -- every catalogue
-- insert today is already a script/SQL statement a human reviews and runs
-- (see import_catalogue.py's REMOTE_CONFIRM_TOKEN gate), so this is one
-- more column in an INSERT already being written by hand, not new
-- tooling. The report's own id is only visible via the dashboard, same
-- as reading missing_listing_reports at all.
alter table public.restaurants
  add column missing_listing_report_id uuid
    references public.missing_listing_reports(id) on delete set null;

alter table public.hotels
  add column missing_listing_report_id uuid
    references public.missing_listing_reports(id) on delete set null;

alter table public.events
  add column missing_listing_report_id uuid
    references public.missing_listing_reports(id) on delete set null;

-- Partial indexes -- Fresh Finds' own query is exactly "rows where this
-- is set, newest first", and the column is null for the overwhelming
-- majority of rows in each table.
create index restaurants_missing_listing_report_idx
  on public.restaurants (created_at desc)
  where missing_listing_report_id is not null;

create index hotels_missing_listing_report_idx
  on public.hotels (created_at desc)
  where missing_listing_report_id is not null;

create index events_missing_listing_report_idx
  on public.events (created_at desc)
  where missing_listing_report_id is not null;

commit;
