-- Private Chefs — database foundation (Step 1).
--
-- Creates the three tables needed for the curated Private Chefs MVP:
--   1. public.private_chefs                  — public catalogue (admin-managed)
--   2. public.private_chef_restaurant_history — public provenance (admin-managed)
--   3. public.private_chef_enquiries          — user-owned "Request an Experience"
--
-- PREPARED, NOT APPLIED. No seed data, no Lucas/Jagers Catering/Parkheuvel
-- rows, no real chef data of any kind. See docs/Architecture/PRIVATE_CHEFS.md
-- for the full product/data architecture this implements.
--
-- Deliberately NOT created in this migration (see PRIVATE_CHEFS.md for why):
--   - private_chef_photos            — profile_image_url alone is sufficient
--     for MVP; a gallery table is a clean, independent future addition that
--     nothing here depends on.
--   - private_chef_internal_reviews  — the roster starts tiny; test-dinner
--     notes, review dimensions and selection decisions stay in internal
--     documentation/enrichment artifacts until a real operational workflow
--     justifies dedicated, sensitive database infrastructure for them.
--
-- Two explicit corrections from the Step 0 architecture doc, both applied
-- throughout this migration:
--
--   A. PUBLICATION = SELECTION. There is no `chasing_stars_selected`
--      boolean. `publication_status = 'published'` is the sole, authoritative
--      signal that a chef has been selected and approved by Chasing Stars
--      and may appear publicly — the app must never need
--      "published AND selected" to decide visibility. `selected_at` exists
--      only as an optional historical/audit timestamp (when curation first
--      approved this chef), set manually by the future admin workflow, never
--      read to gate visibility.
--
--   B. Provenance evidence does NOT live on the publicly-readable
--      `private_chef_restaurant_history` table. Step 0 proposed
--      `source_url`/`verified_at` there, reasoning that the app's own
--      repository layer would simply never SELECT those columns. That is
--      not a security boundary: RLS operates at row granularity, not
--      column granularity, in every policy this project already uses — any
--      client holding a valid `anon`/`authenticated` Supabase key can query
--      any column covered by a table's SELECT policy directly, regardless
--      of what the Flutter app's own repository happens to ask for. A
--      column that must never reach a client cannot be "kept out" by
--      client-side selectivity; it must not exist on a client-readable
--      table at all. Verification instead happens upstream of this table:
--      a provenance row is only ever entered here once a human has already
--      verified it (via internal documentation/enrichment artifacts), so
--      the table only ever contains publication-ready presentation data by
--      construction. RLS below therefore gates purely on the parent chef's
--      `publication_status` — there is no separate `verified_at` gate
--      because there is no unverified row to gate.
--
-- STEP 1A HARDENING (applied in place, this migration not yet deployed):
-- the original private_chef_enquiries INSERT policy only checked
-- `user_id = auth.uid()`, which left a direct-PostgREST-client gap — a
-- caller could insert a row with `status = 'confirmed'` or target a
-- draft/archived chef. The INSERT policy below now additionally
-- requires `status = 'submitted'` and that the target chef is currently
-- published; see the policy's own comment for the full reasoning and
-- the RLS-composition analysis for why this needs no SECURITY DEFINER.

begin;

-- ============================================================
-- 1. PRIVATE_CHEFS
-- ============================================================
--
-- Mirrors this project's own established catalogue-table conventions
-- (see restaurants/hotels/events): uuid pk via gen_random_uuid(), a
-- country_code FK to the existing public.countries table, text + check
-- for the publication-status taxonomy (matching event_type/status/
-- wishlist.entity_type rather than a native enum, since this taxonomy is
-- new and may grow), created_at/updated_at with the shared
-- set_updated_at() trigger (this is a genuinely mutable, admin-edited
-- catalogue row, same reasoning restaurants/hotels already use it for).
--
-- home_city is plain text, not a public.cities FK — same reasoning
-- events.city already established: a chef's home city must not be
-- restricted to the curated, Michelin-guide-edition-scoped city list
-- public.cities exists for. service_area_text is likewise free text, not
-- a normalized region table — private-chef service areas ("The
-- Netherlands and Belgium," "Available for destination dinners
-- worldwide") don't fit a fixed geography model, and nothing in this
-- MVP needs to filter on it structurally yet.

create table public.private_chefs (
  id                     uuid primary key default gen_random_uuid(),
  slug                   text not null unique,
  display_name           text not null,
  -- Optional secondary/brand identity — see PRIVATE_CHEFS.md §4/§46 for
  -- why one table with an optional business_name replaces a separate
  -- private_chef_businesses domain for MVP (validated directly against
  -- the Lucas / Jagers Catering reference case).
  business_name          text,
  biography              text,
  personalization_note   text,
  -- Location/service area — all nullable at the schema level (a draft
  -- profile mid-curation may not have every field filled in yet); the
  -- *publication* gate, not a NOT NULL constraint, is what should
  -- eventually enforce "a published chef has a known home city" as part
  -- of the human publication-standard checklist (PRIVATE_CHEFS.md §41),
  -- not a database-level block that would fight the draft workflow.
  home_city              text,
  home_country_code      char(2) references public.countries(country_code),
  service_area_text      text,
  travel_available       boolean not null default true,
  minimum_guests         smallint,
  maximum_guests         smallint,
  wine_pairing_available boolean not null default false,
  wine_note              text,
  -- Pricing — price_on_request defaults true (the premium-safe default;
  -- a chef only shows a number if curation deliberately sets one).
  -- Deliberately NO cross-field constraint tying price_on_request to
  -- pricing_from's presence/absence — private-dining pricing models can
  -- reasonably evolve, and over-constraining that interaction risks
  -- blocking a legitimate future pricing shape this MVP hasn't seen yet.
  price_on_request       boolean not null default true,
  pricing_from           numeric(10, 2),
  pricing_currency       char(3),
  pricing_unit           text,
  instagram_url          text,
  website_url            text,
  profile_image_url      text,
  languages              text[],
  publication_status     text not null default 'draft',
  -- Historical/audit only — see the file header's correction (A). Set
  -- manually by the future admin workflow; never read by RLS or the app
  -- to decide visibility.
  selected_at            timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint private_chefs_slug_format
    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint private_chefs_publication_status_valid
    check (publication_status in ('draft', 'published', 'archived')),
  constraint private_chefs_guest_range_valid check (
    (minimum_guests is null or minimum_guests > 0)
    and (maximum_guests is null or maximum_guests > 0)
    and (
      minimum_guests is null
      or maximum_guests is null
      or maximum_guests >= minimum_guests
    )
  ),
  constraint private_chefs_pricing_from_valid
    check (pricing_from is null or pricing_from >= 0),
  constraint private_chefs_pricing_currency_format
    check (pricing_currency is null or pricing_currency ~ '^[A-Z]{3}$'),
  constraint private_chefs_pricing_unit_valid
    check (pricing_unit is null or pricing_unit in ('per_person', 'per_experience'))
);

create trigger private_chefs_updated_at
  before update on public.private_chefs
  for each row execute function public.set_updated_at();

-- publication_status: the read policy's own filter predicate — every
-- public client read is "where publication_status = 'published'", so
-- this index directly serves that query, matching events_status_idx's
-- own precedent for a plain status-column index.
create index private_chefs_publication_status_idx
  on public.private_chefs (publication_status);

-- home_country_code: a natural future "chefs available in this country"
-- discovery query — matches events_country_idx's own precedent for
-- exactly this shape of catalogue-country index.
create index private_chefs_home_country_idx
  on public.private_chefs (home_country_code);

-- Note: slug's own `unique` constraint above already creates a unique
-- index automatically — no separate index needed for it.

-- ============================================================
-- 2. PRIVATE_CHEF_RESTAURANT_HISTORY
-- ============================================================
--
-- One chef -> many restaurant-history rows; one restaurant -> many
-- chefs' history rows — a genuine many-to-many, supported natively by
-- two plain FKs with no composite key, exactly like hotel_restaurants/
-- event_restaurants/event_hotels already do for their own many-to-many
-- relationships in this schema.
--
-- restaurant_id is nullable and restaurant_name_text is its text-only
-- fallback, per PRIVATE_CHEFS.md §12: a globally-facing product will
-- surface chef history at restaurants far outside the current
-- Michelin-catalogue scope, and forcing every provenance claim through
-- the canonical catalogue would either pressure premature/low-quality
-- catalogue additions (explicitly against this project's own inclusion
-- discipline) or silently drop legitimate context. The XOR-shaped check
-- constraint below (exactly one of the two identity paths populated,
-- never both, never neither) directly implements "if canonical
-- restaurant_id exists, that is authoritative — avoid duplicate/
-- conflicting restaurant identities" rather than merely requiring "at
-- least one."
--
-- role/period_text are free text, not enums or precise start/end dates:
-- role language is genuinely open-ended and international ("Sous Chef,"
-- "Trained under...," equivalents in other kitchen cultures), and
-- precise start/end dates would invite exactly the fabrication this
-- project's own product brief explicitly forbids ("do not invent...
-- employment dates, duration"). period_text lets an admin write only
-- what's actually known ("2019-2021," "Several seasons") without
-- implying false precision.
--
-- display_order exists beyond the task's own minimal field list because
-- PRIVATE_CHEFS.md's own future-testing checklist explicitly expects
-- "multiple provenance Restaurants, correctly ordered" — without a
-- controllable order, multiple history rows for one chef would fall
-- back to insertion order, which is too fragile for hand-curated
-- editorial content. is_current was considered and deliberately
-- dropped: nothing in this task's restated field list or test checklist
-- references "currently at" phrasing, and period_text free text
-- ("Head Chef, 2022-present") already conveys current status without a
-- second column — it can be added later with a simple additive
-- migration if a real product need for it emerges.
--
-- No source_url/verified_at here — see the file header's correction (B).

create table public.private_chef_restaurant_history (
  id                   uuid primary key default gen_random_uuid(),
  private_chef_id      uuid not null references public.private_chefs(id) on delete cascade,
  restaurant_id        uuid references public.restaurants(id) on delete set null,
  restaurant_name_text text,
  role                 text,
  period_text          text,
  display_order        smallint not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint private_chef_restaurant_history_identity_xor check (
    (restaurant_id is not null and restaurant_name_text is null)
    or (restaurant_id is null and restaurant_name_text is not null)
  )
);

create trigger private_chef_restaurant_history_updated_at
  before update on public.private_chef_restaurant_history
  for each row execute function public.set_updated_at();

create index private_chef_restaurant_history_chef_idx
  on public.private_chef_restaurant_history (private_chef_id);
create index private_chef_restaurant_history_restaurant_idx
  on public.private_chef_restaurant_history (restaurant_id);

-- ============================================================
-- 3. PRIVATE_CHEF_ENQUIRIES
-- ============================================================
--
-- "Request an Experience," not a booking — deliberately named
-- _enquiries, never _bookings, matching PRIVATE_CHEFS.md's own
-- enquiry-vs-booking distinction: this table represents a bespoke
-- request a member has made, not a confirmed reservation, and naming it
-- otherwise would misrepresent the product to both members and chefs.
--
-- location_text is NOT NULL: a private-dining enquiry with no location
-- context at all isn't actionable for a chef considering travel/
-- logistics, so this is the one field kept mandatory beyond ownership
-- itself. preferred_date, guest_count, occasion, message and
-- wine_pairing_interest are all nullable — "a bespoke enquiry can
-- reasonably start without them" (a host may be flexible on date, unsure
-- of exact guest count yet, or simply want to open a conversation with a
-- one-line message) — forcing them would fight the "bespoke, not
-- configurable e-commerce" positioning this whole domain is built
-- around. wine_pairing_interest is a nullable boolean, not
-- not-null-default-false, so "never asked/answered" stays distinguishable
-- from an explicit "no."
--
-- private_chef_id uses `on delete restrict`, not cascade: a member's own
-- enquiry is their own activity history, not the chef's data — losing it
-- because a catalogue row was later removed would contradict this
-- project's own "History Is Permanent" principle (DATABASE_GUIDE.md).
-- Chefs are admin-managed, low-volume, and expected to be archived
-- (publication_status = 'archived'), not hard-deleted, in the ordinary
-- course of business; restrict simply makes that expectation structural
-- — an attempt to delete a chef row with existing enquiries fails loudly
-- instead of silently erasing member history, forcing a conscious
-- decision rather than an accident.
--
-- user_id uses `on delete cascade`, matching every other user-owned
-- table in this schema exactly (visits, wishlist, event_attendance,
-- friendships) — if an account is deleted, that account's own personal
-- records go with it.
--
-- Status transitions are intentionally NOT client-writable at all in
-- this migration — see the RLS section below for why, mirroring
-- friendships' own "no INSERT/UPDATE policy at all, state transitions
-- go through a future SECURITY DEFINER RPC" precedent exactly.

create table public.private_chef_enquiries (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references public.profiles(id) on delete cascade,
  private_chef_id        uuid not null references public.private_chefs(id) on delete restrict,
  preferred_date         date,
  location_text          text not null,
  guest_count            smallint,
  occasion               text,
  message                text,
  wine_pairing_interest  boolean,
  status                 text not null default 'submitted',
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint private_chef_enquiries_status_valid check (
    status in ('submitted', 'contacted', 'in_discussion', 'confirmed', 'closed', 'declined')
  ),
  constraint private_chef_enquiries_guest_count_valid
    check (guest_count is null or guest_count > 0)
);

create trigger private_chef_enquiries_updated_at
  before update on public.private_chef_enquiries
  for each row execute function public.set_updated_at();

-- "My own enquiries" (member-facing future screen).
create index private_chef_enquiries_user_idx
  on public.private_chef_enquiries (user_id);
-- "Enquiries for this chef" (future admin/curation view).
create index private_chef_enquiries_chef_idx
  on public.private_chef_enquiries (private_chef_id);
-- Future admin triage queue, filtered by status.
create index private_chef_enquiries_status_idx
  on public.private_chef_enquiries (status);
-- Future admin queue, chronological.
create index private_chef_enquiries_created_at_idx
  on public.private_chef_enquiries (created_at);

-- ============================================================
-- 4. RLS
-- ============================================================
--
-- Read audience decision: anon + authenticated, matching restaurants/
-- hotels/events/hotel_restaurants/event_restaurants/event_hotels exactly
-- — every existing admin-managed catalogue table in this project is
-- readable by anon as well as authenticated (this app's Explore/Guides/
-- Events discovery content is not gated behind sign-in), and nothing
-- about Private Chefs makes it a more sensitive *catalogue* surface than
-- those — it is a curated discovery domain, same category as Guides.
-- (The *enquiry* table below is a completely different case: genuinely
-- private user activity, authenticated-only, owner-scoped.)

alter table public.private_chefs enable row level security;

create policy private_chefs_public_read on public.private_chefs
  for select to anon, authenticated
  using (publication_status = 'published');

-- Deliberately no insert/update/delete policy for any client role — a
-- brand-new admin-managed catalogue table, matching restaurants/hotels/
-- events exactly: writes happen only via the service role through
-- import/admin scripts, never through the app.

alter table public.private_chef_restaurant_history enable row level security;

-- Gated purely on the parent chef's publication status — no separate
-- verified_at condition, because (per correction B, file header) a row
-- only ever exists here once already verified; there is no unverified
-- state within this table to additionally filter out.
create policy private_chef_restaurant_history_public_read
  on public.private_chef_restaurant_history
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.private_chefs pc
      where pc.id = private_chef_id
        and pc.publication_status = 'published'
    )
  );

-- Same reasoning as private_chefs — no client write policy at all.

alter table public.private_chef_enquiries enable row level security;

create policy private_chef_enquiries_select on public.private_chef_enquiries
  for select to authenticated
  using (user_id = auth.uid());

-- The hard guarantee the task requires: the database, not Flutter,
-- enforces three independent conditions on every client INSERT, all
-- evaluated against the row being inserted, so a direct PostgREST client
-- cannot bypass any of them by skipping the app entirely:
--
--   1. user_id = auth.uid()
--      A client cannot create an enquiry for another user.
--
--   2. status = 'submitted'
--      A client cannot create an enquiry pre-set to 'confirmed',
--      'closed', or any other status. The column's own
--      `default 'submitted'` (above) is necessary but NOT sufficient —
--      a direct API client can supply any value it likes for a
--      column with a default, so the initial state is additionally
--      enforced here as a hard WITH CHECK condition, not left to the
--      default alone.
--
--   3. the target chef is currently published
--      exists (select 1 from private_chefs pc where pc.id =
--      private_chef_id and pc.publication_status = 'published').
--      A client cannot open an enquiry against a draft (not yet public)
--      or archived (no longer public) chef — the FK to private_chefs(id)
--      alone only proves the row exists, not that it's currently
--      publicly selected.
--
--      RLS composition note: this subquery does NOT need
--      `security definer` to work correctly. It runs under the same
--      `authenticated` role executing the outer INSERT, so Postgres
--      applies private_chefs' own row security to it — and that
--      policy (`private_chefs_public_read`, above) already restricts
--      `authenticated` to `publication_status = 'published'` rows only.
--      A draft/archived chef is therefore invisible to this subquery
--      for a normal client, regardless of the explicit status filter
--      also written here — the two constraints reinforce each other
--      rather than depending on either alone, and neither depends on
--      bypassing RLS. The explicit `publication_status = 'published'`
--      condition is intentionally kept even though it is presently
--      implied by private_chefs' own SELECT policy: if that policy's
--      definition ever changes, this WITH CHECK does not silently
--      change behavior with it.
--
-- Once inserted, ownership, status, and the chef relationship are all
-- immutable by any client write path — there is no UPDATE policy at all
-- (see below), so nothing beyond this INSERT-time check can ever weaken
-- these guarantees for an existing row.
create policy private_chef_enquiries_insert on public.private_chef_enquiries
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'submitted'
    and exists (
      select 1 from public.private_chefs pc
      where pc.id = private_chef_id
        and pc.publication_status = 'published'
    )
  );

-- No UPDATE policy at all, deliberately — mirrors friendships' own
-- "every state transition subtler than plain row ownership goes through
-- a SECURITY DEFINER RPC, never a raw client update" precedent exactly.
-- A member must not be able to edit their own enquiry's status (e.g.
-- self-declare 'confirmed'), reassign it to a different chef, or change
-- its user_id — none of which a plain owner-scoped UPDATE policy could
-- prevent cleanly, since "user_id = auth.uid()" as a USING clause says
-- nothing about which *columns* an authorized update may touch. A future
-- status-transition RPC (not built in this migration) is the correct
-- place to add that column-level discipline. No DELETE policy either —
-- an enquiry, once submitted, is a durable record of member activity;
-- silent client-side deletion would work against the same "History Is
-- Permanent" reasoning already applied to the FK behavior above.

-- ============================================================
-- 5. GRANTS
-- ============================================================
--
-- Table-level GRANT is required in addition to RLS for a brand-new
-- table — RLS alone is a no-op without it, confirmed the hard way during
-- Social Foundation Step 1 (see that migration's own commentary). Grants
-- below are scoped to exactly what each table's RLS policies actually
-- allow — no UPDATE/DELETE grant on private_chef_enquiries, since no
-- policy exists for either and granting the bare privilege with no
-- matching policy would be dead, least-privilege-violating surface area.

grant select on public.private_chefs to anon, authenticated;
grant select on public.private_chef_restaurant_history to anon, authenticated;
grant select, insert on public.private_chef_enquiries to authenticated;

commit;
