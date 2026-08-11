-- Gault&Millau as a future fifth Chasing Stars Guide source. Additive only:
-- no existing table, column, or view is touched. Two new tables, mirroring
-- the existing award_history / worlds_50_best split in spirit but NOT their
-- exact shape — Gault&Millau's recognition is neither a single current
-- value (like michelin_stars) nor a single annual rank (like worlds_50_best)
-- alone; it is a score AND a toque count AND, in some markets, neither.
-- See supabase/data/enrichment/gault_millau/SCHEMA_DESIGN.md for the full
-- reasoning behind every column and constraint below, drawn directly from
-- research findings, not assumed.
--
-- PREPARED — NOT APPLIED. Do not run against any database, local or
-- remote, until reviewed. No supabase db push. No production connection.
--
-- Reviewed 2026-08-11 (production-readiness review — see
-- supabase/data/enrichment/gault_millau/PRODUCTION_READINESS_REVIEW.md):
-- table/column/constraint shape confirmed correct and unchanged from the
-- original draft; the only change made by that review is section 3 below
-- (RLS), which the original draft omitted. This migration still creates
-- ONLY the two gault_millau_* tables -- it deliberately does NOT touch
-- public.restaurants.inclusion_reason, which the same review found has no
-- CHECK-permitted value for a Gault&Millau-only restaurant. That is a
-- separate, cross-cutting change to a shared production table and is
-- explicitly out of scope here -- see the review doc §6.

-- ============================================================
-- 1. CORE RESTAURANT RECOGNITION — one row per restaurant per guide_year
-- ============================================================
--
-- Mirrors worlds_50_best's shape (annual snapshot, current = max(guide_year)
-- per restaurant, never overwritten) rather than award_history's
-- (is_current flag) — Gault&Millau publishes a full annual edition per
-- market, not a continuous stream of individual award changes, matching
-- worlds_50_best's own model more closely than award_history's.
--
-- score and toque_count are BOTH independently nullable and never derived
-- from one another by import logic — confirmed necessary by research:
--   - France's "Toques d'Or" (Gault&Millau Academy, ~10 restaurants) are
--     explicitly removed from numeric scoring while still listed/recommended.
--   - Germany abolished numeric scoring entirely in 2022; every German
--     restaurant has toques only, permanently, by design of that market's
--     own system — not a data gap.
--   - Belgium's "H!P" is a separate, structurally unscored casual-dining
--     selection (see recognition_type below).
-- A row with score IS NOT NULL always has that score independently
-- verified — never backfilled from a toque count, and vice versa.
create table public.gault_millau_awards (
  id                 uuid primary key default gen_random_uuid(),
  restaurant_id      uuid not null references public.restaurants(id) on delete cascade,
  guide_year         smallint not null,

  -- 0-20 scale, half-points, per every market researched. NULL for a
  -- restaurant in a tier/market that structurally has no numeric score
  -- (see recognition_type) — never coerced to a number, never guessed.
  score              numeric(3,1) check (score >= 0 and score <= 20),

  -- Independent of score. NULL means "not published/not applicable", not
  -- zero. The 0-5 range covers every market researched (France/NL/BE/CH/AT
  -- all use a 5-toque ceiling; Germany's 2 colour tiers are captured
  -- separately below, not folded into this range).
  toque_count        smallint check (toque_count between 0 and 5),

  -- Germany-specific: 5 Hauben can be "red" (a tier above "black" at the
  -- same count, per direct research confirmation) or "black". NULL for
  -- every market that doesn't publish this distinction (confirmed: France,
  -- NL, BE, CH, AT all use a single colour/tier per toque count). Genuinely
  -- a separate fact from toque_count, not a formatting detail — a 5-red and
  -- a 5-black restaurant are NOT equally ranked in Germany's own system.
  toque_colour       text check (toque_colour in ('black', 'red')),

  -- Distinguishes structurally different recognition types found across
  -- markets — see the CHECK values' provenance:
  --   'scored'            — the standard case: a numeric score (and usually
  --                          a toque count) was published.
  --   'unscored_top_tier' — France's Toques d'Or / Gault&Millau Academy:
  --                          the HIGHEST tier, deliberately removed from
  --                          scoring, not a data gap. score/toque_count are
  --                          both NULL by design for these rows; the
  --                          distinction lives in distinction_label instead.
  --   'unscored_casual'   — Belgium's H!P (and Switzerland/Croatia's
  --                          similarly-structured POP): a parallel,
  --                          continuously-updated casual-dining selection
  --                          that never carries a score or toque at all,
  --                          confirmed structurally distinct from the main
  --                          scored guide, not a lesser version of it.
  recognition_type   text not null default 'scored'
    check (recognition_type in ('scored', 'unscored_top_tier', 'unscored_casual')),

  -- Free text for a named tier/category worth preserving verbatim, e.g.
  -- "Toques d'Or", "Tables d'exception", "H!P of the Year 2026". Never
  -- parsed back into score/toque_count by any script — display-only.
  distinction_label  text,

  gault_millau_url   text,

  unique (restaurant_id, guide_year)
);

create index gault_millau_awards_restaurant_idx
  on public.gault_millau_awards (restaurant_id);

create index gault_millau_awards_guide_year_idx
  on public.gault_millau_awards (guide_year);

-- ============================================================
-- 2. SPECIAL EDITORIAL AWARDS — Chef of the Year and similar
-- ============================================================
--
-- Deliberately a SEPARATE table from core recognition above, per direct
-- instruction and per research finding: these are annual editorial
-- honours to a PERSON (a chef, sommelier, host), not a restaurant's guide
-- placement — a restaurant can hold no G&M score at all in a given
-- market/year and still have staff who won an award, and the award
-- category taxonomy itself is confirmed NOT standardized globally (every
-- national G&M organization sets its own slate and naming — France uses
-- "Grand de Demain de l'Année", Czechia uses "Young Talent of the Year",
-- for what is recognisably the same *kind* of honour but never the same
-- string). award_category is therefore an open, market-scoped vocabulary,
-- not a fixed enum — a CHECK constraint here would misrepresent findings.
--
-- No uniqueness constraint on (country_code, guide_year, award_category):
-- confirmed some categories have multiple winners in the same year/market
-- (Switzerland's "Entdeckung des Jahres" / Discovery of the Year), and
-- Belgium runs three simultaneous regional "Young Chef" winners in one
-- edition — a hard constraint here would be actively wrong, not merely
-- unused.
create table public.gault_millau_special_awards (
  id                          uuid primary key default gen_random_uuid(),

  -- Nullable: an award winner's restaurant is not guaranteed to already
  -- exist in Chasing Stars' catalogue (the whole point of the "new
  -- restaurant candidates" workflow), and some awards may be closer to a
  -- personal/career honour than a single-restaurant fact. ON DELETE SET
  -- NULL rather than CASCADE — a restaurant being removed from the
  -- catalogue must never silently delete the historical fact that someone
  -- won an award there.
  restaurant_id               uuid references public.restaurants(id) on delete set null,

  -- Kept even though restaurant_id (when present) already implies a
  -- country, because restaurant_id can be null — this is then the only
  -- reliable market scope for the row.
  country_code                char(2) not null references public.countries(country_code),

  guide_year                  smallint not null,
  award_category               text not null,
  award_category_local_name    text,
  winner_name                  text,
  restaurant_name_at_time       text,
  gault_millau_url              text,
  source_url                    text,

  created_at                    timestamptz not null default now()
);

create index gault_millau_special_awards_restaurant_idx
  on public.gault_millau_special_awards (restaurant_id);

create index gault_millau_special_awards_country_year_idx
  on public.gault_millau_special_awards (country_code, guide_year);

-- ============================================================
-- 3. ROW LEVEL SECURITY — public read, no client write
-- ============================================================
--
-- Added during the 2026-08-11 production-readiness review: the first draft
-- of this migration omitted RLS entirely, which DATABASE_ARCHITECTURE.md
-- §15.2 ("Catalogue tables — public read, no write") requires of every
-- catalogue table -- without it, the anon key embedded in the Flutter
-- binary could write to these tables directly. Policy text is copied
-- verbatim from that section's pattern (see hotels_public_read there),
-- applied to both new tables. No INSERT/UPDATE/DELETE policy is created on
-- either table -- absence of a policy is the denial; only service_role
-- (which bypasses RLS) may ever write here, exactly as for every other
-- catalogue table.
alter table public.gault_millau_awards enable row level security;

create policy gault_millau_awards_public_read on public.gault_millau_awards
  for select to anon, authenticated
  using (true);

alter table public.gault_millau_special_awards enable row level security;

create policy gault_millau_special_awards_public_read on public.gault_millau_special_awards
  for select to anon, authenticated
  using (true);
