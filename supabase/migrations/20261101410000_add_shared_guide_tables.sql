-- Shared tables for every guide beyond MICHELIN, The World's 50 Best and
-- Gault&Millau: one shape for all of them instead of one table per guide.
--
-- Written 2026-11-16 (branch claude/guide-inventory). The filename
-- timestamp is a sequence number, named after the highest migration on any
-- branch at the time (20261101400000, wishlist booking windows), not a
-- date. Decided by the product owner on 2026-11-16 ("begin met de drie
-- regionale 50 Best-lijsten en de gedeelde tabellen"); design and reasoning
-- in docs/Architecture/GUIDE_INVENTORY.md, "Schema sketch".
--
-- PREPARED -- NOT APPLIED until the product owner approves.
--
-- Why one shared shape. Every guide in the inventory measures in one of
-- three ways: a rank (lower is better), a score (higher is better, on the
-- guide's own maximum) or a tier (a small ordinal, higher is better). The
-- reason MICHELIN and 50 Best live in separate tables -- opposed scales in
-- one award_value column would sort one of them backwards
-- (DATABASE_ARCHITECTURE.md §3.6) -- is met here by keeping rank, score and
-- tier in separate typed columns, with guides.measure saying which one a
-- guide uses. Never one shared value column.
--
-- What stays as it is. award_history, worlds_50_best(_hotels) and
-- gault_millau_awards are read by shipped builds and are not touched.
-- The regional 50 Best lists deliberately do NOT go into worlds_50_best:
-- its unique (restaurant_id, year) and unique (year, rank) would collide
-- (The Chairman is No. 1 in Asia and ranked in the world list the same
-- year), and restaurants_full reads "current rank" as the row of the
-- maximum ranked year, so regional rows would replace the global rank in
-- installed builds.
--
-- inclusion_reason is not widened: a regional ranking does not make a
-- restaurant eligible for the catalogue. Entries whose restaurant is not in
-- the catalogue are logged in the staging files, not added.
--
-- Schema only; the guide rows and rankings are catalogue data, applied
-- separately after review (supabase/data/enrichment/regional_50_best/).
-- No function is created, so no revoke execute is needed. Every table and
-- the view follow §15.2: public read, no client write.

begin;

-- ============================================================
-- 1. guides -- one row per guide (or per separately ranked list)
-- ============================================================
create table public.guides (
  guide_code   text primary key
    check (guide_code ~ '^[a-z0-9_]+$'),
  name         text not null,
  publisher    text not null,
  venue_kind   text not null check (venue_kind in ('restaurant', 'hotel', 'both')),
  -- Which typed column of guide_awards carries the guide's fact.
  measure      text not null check (measure in ('rank', 'score', 'tier')),
  score_max    numeric(5,2),
  tier_max     smallint,
  -- Display labels per tier value, e.g. {"3": "3 Soles"}. Display only,
  -- never parsed back into a tier.
  tier_labels  jsonb,
  homepage_url text,
  terms_url    text,
  created_at   timestamptz not null default now(),
  constraint guides_measure_bounds check (
    (measure = 'score' and score_max is not null and tier_max is null)
    or (measure = 'tier' and tier_max is not null and score_max is null)
    or (measure = 'rank' and score_max is null and tier_max is null)
  )
);

comment on table public.guides is
  'Guides beyond MICHELIN, The World''s 50 Best and Gault&Millau. One row '
  'per guide or separately ranked list (Asia''s 50 Best is not Latin '
  'America''s). No colour column: gold stays reserved for MICHELIN stars '
  'and Keys. See docs/Architecture/GUIDE_INVENTORY.md.';

-- ============================================================
-- 2. guide_awards -- one row per venue per guide per edition
-- ============================================================
create table public.guide_awards (
  id                uuid primary key default gen_random_uuid(),
  guide_code        text not null references public.guides(guide_code),
  restaurant_id     uuid references public.restaurants(id) on delete cascade,
  hotel_id          uuid references public.hotels(id) on delete cascade,
  -- The edition label the publisher prints (La Liste's November 2026 list
  -- is its 2027 edition), checked per edition, never the import year.
  edition_year      smallint not null,
  -- Sub-list inside one edition, per guide: 'top_50', 'extended_51_100'.
  list_name         text not null default 'main',
  rank              smallint check (rank > 0),
  score             numeric(5,2) check (score >= 0),
  tier              smallint check (tier > 0),
  -- A named distinction kept verbatim, display only.
  distinction_label text,
  -- The page this row was verified against.
  source_url        text,
  announced_on      date,
  created_at        timestamptz not null default now(),
  constraint guide_awards_one_venue
    check (num_nonnulls(restaurant_id, hotel_id) = 1),
  constraint guide_awards_has_fact
    check (num_nonnulls(rank, score, tier, distinction_label) >= 1)
);

-- A venue appears at most once per guide edition (as worlds_50_best's
-- unique (restaurant_id, year)). Absence from an edition is no row --
-- never a zero, never a null rank.
create unique index guide_awards_restaurant_edition_uidx
  on public.guide_awards (guide_code, edition_year, restaurant_id)
  where restaurant_id is not null;
create unique index guide_awards_hotel_edition_uidx
  on public.guide_awards (guide_code, edition_year, hotel_id)
  where hotel_id is not null;

-- No two venues share a rank within one guide edition.
create unique index guide_awards_edition_rank_uidx
  on public.guide_awards (guide_code, edition_year, rank)
  where rank is not null;

create index guide_awards_restaurant_idx on public.guide_awards (restaurant_id);
create index guide_awards_hotel_idx on public.guide_awards (hotel_id);

comment on table public.guide_awards is
  'Recognition from the guides in public.guides, one row per venue per '
  'edition. rank, score and tier are separate columns because they sort in '
  'opposite directions; guides.measure says which one a guide uses.';

-- ============================================================
-- 3. guide_venue_links -- the match, made once and reused every edition
-- ============================================================
create table public.guide_venue_links (
  id            uuid primary key default gen_random_uuid(),
  guide_code    text not null references public.guides(guide_code),
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  hotel_id      uuid references public.hotels(id) on delete cascade,
  -- The publisher's own stable ID or slug, where it has one.
  external_id   text,
  -- The venue's page on the guide's site.
  profile_url   text,
  -- Why this listing is this venue: address, phone, website, an earlier
  -- verified ranking. Never the name.
  evidence      text not null,
  verified_at   date not null,
  created_at    timestamptz not null default now(),
  constraint guide_venue_links_one_venue
    check (num_nonnulls(restaurant_id, hotel_id) = 1)
);

create unique index guide_venue_links_restaurant_uidx
  on public.guide_venue_links (guide_code, restaurant_id)
  where restaurant_id is not null;
create unique index guide_venue_links_hotel_uidx
  on public.guide_venue_links (guide_code, hotel_id)
  where hotel_id is not null;
create unique index guide_venue_links_external_uidx
  on public.guide_venue_links (guide_code, external_id)
  where external_id is not null;
create unique index guide_venue_links_profile_uidx
  on public.guide_venue_links (guide_code, profile_url)
  where profile_url is not null;

comment on table public.guide_venue_links is
  'How a guide listing was matched to a catalogue venue, with evidence. '
  'Enrichment only: never identity, never a join key for anything but the '
  'guide itself.';

-- ============================================================
-- 4. guide_coverage -- what we hold, said out loud
-- ============================================================
create table public.guide_coverage (
  id            uuid primary key default gen_random_uuid(),
  guide_code    text not null references public.guides(guide_code),
  -- NULL means the whole list, not one country.
  country_code  char(2) references public.countries(country_code),
  edition_year  smallint not null,
  -- complete: every listing is either on a catalogue venue or logged as
  -- not in the catalogue. partial: some listings are still held back.
  coverage      text not null check (coverage in ('complete', 'partial')),
  -- Shown verbatim on the site, as the Gault&Millau guide page does today.
  note          text not null,
  created_at    timestamptz not null default now(),
  unique nulls not distinct (guide_code, edition_year, country_code)
);

comment on table public.guide_coverage is
  'Per guide edition (and optionally per country): whether every listing '
  'is accounted for, and the note the site shows about it.';

-- ============================================================
-- 5. guide_awards_current -- each guide's latest edition
-- ============================================================
-- Current = the guide's own latest edition, as restaurants_full reads
-- worlds_50_best: a venue that left the list has no current row.
create view public.guide_awards_current
  with (security_invoker = true)
  as
select
  ga.id,
  ga.guide_code,
  g.name as guide_name,
  g.measure,
  g.score_max,
  g.tier_max,
  ga.restaurant_id,
  ga.hotel_id,
  ga.edition_year,
  ga.list_name,
  ga.rank,
  ga.score,
  ga.tier,
  ga.distinction_label,
  ga.source_url
from public.guide_awards ga
join public.guides g on g.guide_code = ga.guide_code
where ga.edition_year = (
  select max(x.edition_year) from public.guide_awards x
  where x.guide_code = ga.guide_code
);

-- ============================================================
-- 6. Row level security -- public read, no client write (§15.2)
-- ============================================================
alter table public.guides enable row level security;
alter table public.guide_awards enable row level security;
alter table public.guide_venue_links enable row level security;
alter table public.guide_coverage enable row level security;

revoke all on public.guides, public.guide_awards, public.guide_venue_links,
  public.guide_coverage, public.guide_awards_current from anon, authenticated;
grant select on public.guides, public.guide_awards, public.guide_venue_links,
  public.guide_coverage, public.guide_awards_current to anon, authenticated;

create policy guides_public_read on public.guides
  for select to anon, authenticated using (true);
create policy guide_awards_public_read on public.guide_awards
  for select to anon, authenticated using (true);
create policy guide_venue_links_public_read on public.guide_venue_links
  for select to anon, authenticated using (true);
create policy guide_coverage_public_read on public.guide_coverage
  for select to anon, authenticated using (true);

commit;
