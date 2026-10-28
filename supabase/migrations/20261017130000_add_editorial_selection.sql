-- The Selection: a list of restaurants chosen by our own editors, the
-- fourth way a restaurant can enter the catalogue next to a MICHELIN
-- star, the current World's 50 Best list and the Best of the Best hall
-- of fame. Decided by the product owner on 2026-10-28 (the scope rule in
-- DATABASE_ARCHITECTURE.md / START_HERE.md was widened the same day); the
-- first two entries are Tacite and Petit Péché, Amsterdam, prepared in
-- supabase/data/enrichment/editorial_selection/.
--
-- Written 2026-10-28. Named after the highest existing migration
-- (20261017120000), not after a date.
--
-- PREPARED — NOT APPLIED. Do not push until reviewed.
--
-- Shown in the app as "Mantelier Selection" (per country: "Mantelier
-- Selection Netherlands"). The brand name stays out of every identifier
-- here on purpose: the app's name is still being settled, and a rename
-- must never need a migration.
--
-- A Selection entry is our editorial judgement, not an award. It is never
-- rendered in gold (reserved for MICHELIN stars and Keys), and a
-- restaurant that is in the Selection without a star carries
-- michelin_stars NULL, as for every other unstarred row — never 0, never
-- "no award".

-- ============================================================
-- 1. Widen restaurants.inclusion_reason to permit 'editorial_selection'
-- ============================================================
--
-- inclusion_reason stays creation provenance only (see the column comment
-- set by 20260811220000): it says why a row
-- was created and is never read to decide whether a restaurant is in the
-- Selection today. editorial_selections below is that source.
--
-- All five currently valid values are kept; no existing row is rewritten.
alter table public.restaurants
  drop constraint inclusion_reason_valid;

alter table public.restaurants
  add constraint inclusion_reason_valid
    check (inclusion_reason in ('michelin_star', 'worlds_50_best',
                                 'hall_of_fame', 'bib_gourmand',
                                 'gault_millau', 'editorial_selection'));

comment on column public.restaurants.inclusion_reason is
  'Creation provenance only: the primary reason this row was originally '
  'created (michelin_star / worlds_50_best / hall_of_fame / bib_gourmand / '
  'gault_millau / editorial_selection). A single historical fact, written '
  'once at insert and never rewritten as recognition changes. MUST NOT be '
  'read to derive current guide recognition of any kind -- current '
  'recognition lives in award_history, worlds_50_best, gault_millau_awards '
  'and editorial_selections. See '
  'docs/Architecture/Michelin_Database/GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md.';

-- ============================================================
-- 2. editorial_selections — who is in the Selection, and since when
-- ============================================================
--
-- One row per time a restaurant enters the Selection. Leaving it sets
-- removed_on instead of deleting the row, so a member's Passport can still
-- say a restaurant was in the Selection when they went. Current membership
-- is removed_on IS NULL; the partial unique index keeps it to one current
-- entry per restaurant.
--
-- Any restaurant can be in it, starred or not. There is no country column:
-- the per-country list ("Selection Netherlands") is restaurants.country_code,
-- never a second copy of it.
--
-- Restaurants only for now. Hotels have no inclusion_reason and the scope
-- rule for hotels is unchanged; widening this to hotels is its own decision.
create table public.editorial_selections (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references public.restaurants(id) on delete cascade,
  selected_on    date not null,
  removed_on     date,
  created_at     timestamptz not null default now(),
  constraint editorial_selections_dates_valid
    check (removed_on is null or removed_on >= selected_on)
);

create unique index editorial_selections_one_current_idx
  on public.editorial_selections (restaurant_id)
  where removed_on is null;

create index editorial_selections_restaurant_idx
  on public.editorial_selections (restaurant_id);

comment on table public.editorial_selections is
  'Restaurants in our own editorial Selection (shown as "Mantelier '
  'Selection"). Current membership is removed_on IS NULL. Editorial '
  'judgement, not an award: never rendered in gold.';

-- ============================================================
-- 3. ROW LEVEL SECURITY — public read, no client write
-- ============================================================
--
-- A catalogue table (DATABASE_ARCHITECTURE.md §15.2): world-readable, and
-- no insert/update/delete policy, so only service_role writes. No function
-- is created here, so there is no execute grant to revoke.
--
-- The project's default privileges grant ALL on every new public table to
-- anon and authenticated (see 20260918130000). RLS already denies their
-- writes; the grant is narrowed to select as well, so the table does not
-- depend on RLS alone.
alter table public.editorial_selections enable row level security;

revoke all on public.editorial_selections from anon, authenticated;
grant select on public.editorial_selections to anon, authenticated;

create policy editorial_selections_public_read on public.editorial_selections
  for select to anon, authenticated
  using (true);
