begin;

-- ============================================================
-- Missing listing reports — "I searched for something and it wasn't
-- there" reports for restaurants, hotels, and events, submitted from
-- Explore's and Events' own "no results" empty states.
-- ============================================================
--
-- venue_corrections was considered and rejected: its venue_type CHECK
-- only allows ('restaurant', 'hotel', 'private_chef') — no 'event' — and
-- its venue_id is `not null` with no default, i.e. it structurally
-- assumes a row that already exists. A missing-listing report has no id
-- to put there. Events specifically are a poor fit for that table's
-- assumptions in a second way too: they're time-bound and possibly
-- already over by the time anyone reviews the report, unlike a
-- restaurant/hotel correction tied to a permanent catalogue row.
--
-- One table for all three subject types, not one per type or one for
-- venues plus a separate one for events: the fields a reporter actually
-- fills in (type, name, city, why it belongs, optional reporter contact)
-- are identical regardless of subject_type, and the form itself is one
-- shared form — splitting the table would only duplicate that shape.
create table public.missing_listing_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  subject_type text not null
    check (subject_type in ('restaurant', 'hotel', 'event')),
  name text not null,
  city text not null,
  -- The most important field — free text explaining why this belongs in
  -- the catalogue. Required: a report with no reasoning is close to
  -- worthless to act on, which is exactly the case this column exists to
  -- rule out.
  message text not null,
  -- "I work here" — a soft signal for follow-up contact, never a claim
  -- of the listing and never independently verified here. Verification
  -- belongs to the separate claim flow (claims_restaurants/claims_hotels/
  -- claims_private_chefs, already prepared in the same original
  -- 20260828120000 migration file) built later.
  works_here boolean not null default false,
  reporter_role text,
  reporter_contact text,
  created_at timestamptz not null default now(),
  -- Enforced here, not just client-side in the form: a client-side-only
  -- check would leave a real gap the moment any other write path (a
  -- future admin tool, a script, a bug) ever inserts a row.
  constraint reporter_details_required_if_works_here
    check (not works_here or (reporter_role is not null and reporter_contact is not null))
);

comment on table public.missing_listing_reports is
  'Reports of a missing restaurant/hotel/event, submitted from a search '
  'empty state. Insert-only for authenticated users — nobody, including '
  'the reporter, can read these back through the API; the operator reads '
  'them via the Supabase dashboard.';

-- Same insert-only, no-select-to-anyone shape as venue_link_clicks
-- (20260829120000) — the precedent for "admin reads via dashboard only",
-- not venue_corrections (which grants owner-read, the opposite of what
-- this table needs).
alter table public.missing_listing_reports enable row level security;

create policy missing_listing_reports_insert on public.missing_listing_reports
  for insert to authenticated
  with check (reporter_id = auth.uid());

grant insert on public.missing_listing_reports to authenticated;

commit;
