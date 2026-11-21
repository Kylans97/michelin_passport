-- Wine verdicts, and wines kept without a visit. Asked for by the product
-- owner on 2026-11-21 ("Stel je kan bijhouden wat je echt lekker vond zou
-- je later zelf die wijn kunnen bestellen"), planned in the Wine Verdicts
-- Plan (https://claude.ai/artifact/FR6GKmiV91PrSzmJ48XHJb) and approved
-- the same day ("jaa dat wine verdicts plan mag je bouwen"). Written
-- 2026-11-21 on claude/wine-regions. The number is sort order, not a date:
-- written as 20261101630000, renumbered the same day (neither applied) to
-- follow 20261101630000_add_md_am_il_cy_countries.sql, so the countries
-- round 6 needs can be applied while this waits for the privacy policy.
--
-- PREPARED -- NOT APPLIED until the product owner approves, and only after
-- the privacy policy names verdicts, notes and wines kept without a visit
-- (as visit_wines went live on 2026-11-04: the policy first).
--
-- 1. visit_wines gains verdict and tasting_note. Purely additive: every
--    shipped build (1.6.0 in the App Store, 1.7.x in TestFlight) selects a
--    fixed column list and never sees them. Who may read a wine does not
--    change: a friend sees it, verdict and note included, when the visit
--    is shared (product owner: "dit mogen vrienden altijd zien inclusief
--    notitie"). A wine on a private visit stays private, or the visit
--    itself would show.
--
-- 2. cellar_wines: a wine drunk without a restaurant visit (at home, at an
--    estate, somewhere else). Its own table rather than a nullable
--    visit_wines.visit_id: shipped builds read every visit_wines row
--    expecting a visit id (visit_wine_repository.dart _cellarWine casts it
--    to String), so a row without one would break their Cellar. The same
--    call vineyard_visits and journey_travels made. Friends always read
--    these (the product owner's decision above), so there is no visibility
--    column. Linking a wine to an estate is vineyard_id, picked by the
--    member, exactly as on visit_wines; nothing is matched by name.
--
-- verdict: 'again' (Would drink again), 'fine' (It was fine),
-- 'not_for_me' (Not for me). NULL: no verdict given. A verdict never
-- makes a stamp; stamps come only from confirmed attendance.
--
-- No function is created here, so there is no execute grant to revoke.

begin;

-- ============================================================
-- 1. visit_wines -- verdict and note
-- ============================================================
alter table public.visit_wines
  add column verdict text
    check (verdict in ('again', 'fine', 'not_for_me')),
  add column tasting_note text
    check (char_length(tasting_note) between 1 and 280);

comment on column public.visit_wines.verdict is
  'What the member thought: again (Would drink again), fine, not_for_me. NULL: not given.';
comment on column public.visit_wines.tasting_note is
  'One line to remember the wine by, as the member wrote it. Visible wherever the wine is.';

-- ============================================================
-- 2. cellar_wines -- wines kept without a visit
-- ============================================================
create table public.cellar_wines (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  producer      text check (char_length(producer) between 1 and 120),
  wine_name     text check (char_length(wine_name) between 1 and 120),
  vintage       smallint check (vintage between 1800 and 2100),
  non_vintage   boolean not null default false,
  bottle_size   text check (bottle_size in ('glass', 'half', 'bottle', 'magnum', 'other')),
  vineyard_id   uuid references public.vineyards(id) on delete set null,
  verdict       text check (verdict in ('again', 'fine', 'not_for_me')),
  tasting_note  text check (char_length(tasting_note) between 1 and 280),
  setting       text not null default 'home'
    check (setting in ('home', 'estate', 'elsewhere')),
  place         text check (char_length(place) between 1 and 120),
  drunk_on      date,
  created_at    timestamptz not null default now(),
  constraint cellar_wines_says_something check (
    producer is not null or wine_name is not null or vintage is not null
    or non_vintage or bottle_size is not null
  ),
  constraint cellar_wines_year_or_nv check (not (non_vintage and vintage is not null))
);

create index cellar_wines_user_idx
  on public.cellar_wines (user_id, created_at desc);
create index cellar_wines_vineyard_idx
  on public.cellar_wines (vineyard_id) where vineyard_id is not null;

comment on table public.cellar_wines is
  'Wines a member drank without a restaurant visit. Friends read them; only the member writes.';

alter table public.cellar_wines enable row level security;

revoke all on public.cellar_wines from public, anon, authenticated;
grant select, insert, update, delete on public.cellar_wines to authenticated;

create policy cellar_wines_select on public.cellar_wines
  for select to authenticated
  using (user_id = auth.uid() or public.is_friend(user_id));

create policy cellar_wines_insert on public.cellar_wines
  for insert to authenticated
  with check (user_id = auth.uid());

create policy cellar_wines_update on public.cellar_wines
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy cellar_wines_delete on public.cellar_wines
  for delete to authenticated
  using (user_id = auth.uid());

commit;
