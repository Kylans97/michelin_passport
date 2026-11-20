-- Wine regions on the globe: where wine comes from, which grapes grow
-- there, how they taste, and the names a wine list uses for them. Asked for
-- by the product owner on 2026-11-20 ("a wine variant of the globe... when
-- you tap a region, what grapes grow there and what taste that gives; I
-- find wine lists organised by region hard"), from the "Wine regions
-- globe" canvas (https://claude.ai/artifact/DHKUpxQhmfhfu5bhAz61vp):
-- "just build it and fine-tune". Written 2026-11-20 (branch
-- claude/wine-regions). The number is sort order, not a date: named after
-- the highest migration on any branch.
--
-- PREPARED -- NOT APPLIED until the product owner approves.
--
-- Editorial reference content, not awards and not venue content. Every
-- row is written and reviewed by us (the way the Selection is chosen),
-- carries the source it was checked against, and is only visible once
-- publication_status = 'published' -- a draft never reaches the app.
-- Nothing here is gold.
--
-- A region is drawn on the globe as a soft patch around a point with an
-- approximate extent (radius_km), never as a border: no reliable open
-- dataset of wine-region boundaries exists, and a wrongly drawn border
-- reads as a fact. Sub-regions (Côte de Nuits under Burgundy) use
-- parent_id; the app shows top-level regions on the globe.
--
-- An appellation is a name as it appears on a wine list -- Chablis,
-- Meursault, Barolo -- pointing at its region, so searching what is on the
-- list always finds something. aliases holds other spellings and
-- languages (Bourgogne / Burgundy, Spätburgunder / Pinot Noir). Matching
-- is on these stored names only; nothing is inferred.
--
-- vineyards.wine_region_id links a 50 Best estate to its region, so the
-- wines a member logged against an estate light that region. Nullable;
-- shipped builds select vineyard columns explicitly and never see it.
--
-- No function is created here, so there is no execute grant to revoke.

begin;

-- ============================================================
-- 1. wine_regions
-- ============================================================
create table public.wine_regions (
  id                  uuid primary key default gen_random_uuid(),
  region_code         text not null unique,
  name                text not null,
  -- Other names a list or label uses ("Bourgogne" for Burgundy).
  aliases             text[] not null default '{}',
  country_code        char(2) not null references public.countries(country_code),
  parent_id           uuid references public.wine_regions(id) on delete restrict,
  -- The centre of the patch drawn on the globe, and roughly how far the
  -- region reaches. Approximate by design; see the header.
  latitude            double precision not null check (latitude between -90 and 90),
  longitude           double precision not null check (longitude between -180 and 180),
  radius_km           smallint not null default 40 check (radius_km between 5 and 400),
  -- One or two sentences: what the region is, in plain words.
  summary             text not null,
  -- "A red from here, in the glass", 1 (low) to 5 (high). NULL when the
  -- region is known for white or sparkling wine only.
  red_body            smallint check (red_body between 1 and 5),
  red_acidity         smallint check (red_acidity between 1 and 5),
  red_tannin          smallint check (red_tannin between 1 and 5),
  -- What it goes with, and how its labels rank quality, as written by us.
  pairing             text,
  label_note          text,
  source_url          text,
  publication_status  text not null default 'draft'
    check (publication_status in ('draft', 'published')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint wine_regions_code_format check (region_code ~ '^wr_[0-9]{4,}$')
);

create trigger wine_regions_updated_at
  before update on public.wine_regions
  for each row execute function public.set_updated_at();

create index wine_regions_country_idx on public.wine_regions (country_code);
create index wine_regions_parent_idx on public.wine_regions (parent_id);

-- ============================================================
-- 2. grapes
-- ============================================================
create table public.grapes (
  id                  uuid primary key default gen_random_uuid(),
  grape_code          text not null unique,
  name                text not null,
  aliases             text[] not null default '{}',
  colour              text not null check (colour in ('red', 'white')),
  summary             text not null,
  -- What you taste, a few words each ("Red cherry", "Raspberry").
  tastes              text[] not null default '{}',
  -- With age, if it changes ("mushroom, forest floor").
  aged_note           text,
  body                smallint check (body between 1 and 5),
  acidity             smallint check (acidity between 1 and 5),
  tannin              smallint check (tannin between 1 and 5),
  -- "Like this? Try ..." -- another grape and why.
  similar_grape_id    uuid references public.grapes(id) on delete set null,
  similar_note        text,
  source_url          text,
  publication_status  text not null default 'draft'
    check (publication_status in ('draft', 'published')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint grapes_code_format check (grape_code ~ '^gr_[0-9]{4,}$')
);

create trigger grapes_updated_at
  before update on public.grapes
  for each row execute function public.set_updated_at();

-- ============================================================
-- 3. wine_region_grapes -- which grapes a region is known for
-- ============================================================
create table public.wine_region_grapes (
  region_id      uuid not null references public.wine_regions(id) on delete cascade,
  grape_id       uuid not null references public.grapes(id) on delete cascade,
  -- What this grape becomes here ("earthy, elegant").
  local_note     text,
  display_order  smallint not null default 0,
  primary key (region_id, grape_id)
);

create index wine_region_grapes_grape_idx on public.wine_region_grapes (grape_id);

-- ============================================================
-- 4. wine_appellations -- the names on a wine list
-- ============================================================
create table public.wine_appellations (
  id                  uuid primary key default gen_random_uuid(),
  appellation_code    text not null unique,
  name                text not null,
  aliases             text[] not null default '{}',
  region_id           uuid not null references public.wine_regions(id) on delete cascade,
  colour              text not null
    check (colour in ('red', 'white', 'rose', 'sparkling', 'mixed')),
  -- What you get in the glass, a few words ("crisp, mineral").
  note                text not null,
  display_order       smallint not null default 0,
  publication_status  text not null default 'draft'
    check (publication_status in ('draft', 'published')),
  constraint wine_appellations_code_format
    check (appellation_code ~ '^wa_[0-9]{4,}$')
);

create index wine_appellations_region_idx on public.wine_appellations (region_id);

-- ============================================================
-- 5. vineyards.wine_region_id
-- ============================================================
alter table public.vineyards
  add column wine_region_id uuid references public.wine_regions(id) on delete set null;

create index vineyards_wine_region_idx
  on public.vineyards (wine_region_id)
  where wine_region_id is not null;

-- ============================================================
-- 6. ROW LEVEL SECURITY AND GRANTS
-- ============================================================
-- Reference content: world-readable once published, no client write; only
-- service_role writes. The project's default privileges grant ALL on
-- every new table to anon and authenticated (20260918130000); narrowed to
-- select so these tables do not depend on RLS alone.
alter table public.wine_regions       enable row level security;
alter table public.grapes             enable row level security;
alter table public.wine_region_grapes enable row level security;
alter table public.wine_appellations  enable row level security;

revoke all on public.wine_regions, public.grapes, public.wine_region_grapes,
  public.wine_appellations
  from public, anon, authenticated;
grant select on public.wine_regions, public.grapes, public.wine_region_grapes,
  public.wine_appellations
  to anon, authenticated;

create policy wine_regions_public_read on public.wine_regions
  for select to anon, authenticated
  using (publication_status = 'published');

create policy grapes_public_read on public.grapes
  for select to anon, authenticated
  using (publication_status = 'published');

-- A link is visible when both ends are.
create policy wine_region_grapes_public_read on public.wine_region_grapes
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.wine_regions r
      where r.id = region_id and r.publication_status = 'published'
    )
    and exists (
      select 1 from public.grapes g
      where g.id = grape_id and g.publication_status = 'published'
    )
  );

create policy wine_appellations_public_read on public.wine_appellations
  for select to anon, authenticated
  using (
    publication_status = 'published'
    and exists (
      select 1 from public.wine_regions r
      where r.id = region_id and r.publication_status = 'published'
    )
  );

comment on table public.wine_regions is
  'Wine regions for the globe''s wine layer. Editorial reference content, '
  'reviewed and sourced; drawn as a patch around a point, never a border.';
comment on table public.wine_appellations is
  'Names as they appear on a wine list, each pointing at its region.';

commit;
