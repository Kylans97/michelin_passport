-- Private Chefs Step 2B (continued) — "Background" section architecture.
--
-- PREPARED, NOT APPLIED. Additive only: does not touch restaurants,
-- hotels, events, profiles, or any other table outside the Private
-- Chefs domain, and does not modify
-- private_chef_restaurant_history/private_chefs/private_chef_photos in
-- any way.
--
-- ARCHITECTURE DECISION: the user-facing "Restaurant Provenance" section
-- is renamed to "Background" (a chef's relevant professional background
-- is broader than kitchen positions — hospitality, service, wine, and
-- education can all be curation-relevant), but the underlying data model
-- is NOT collapsed into one generalized/polymorphic table. Two options
-- were weighed:
--
--   OPTION A (chosen): keep private_chef_restaurant_history exactly as
--   it already is — deployed, tested, RLS'd, with its own correct XOR
--   canonical/text-fallback identity constraint and Michelin-attribution
--   handling already built into PrivateChefProvenanceRow — and add ONE
--   new, small, single-purpose private_chef_education table alongside
--   it. The "Background" UI section reads from both and renders them
--   together (restaurant items, then education items), but they remain
--   two distinct, simply-shaped tables underneath.
--
--   OPTION B (rejected): a single generalized private_chef_background
--   table with a background_type discriminator column and a growing set
--   of nullable fields depending on type (restaurant_id/restaurant_name
--   for one type, institution/program for another, and unknown fields
--   for whatever "wine/hospitality/other" turns out to need later).
--   Rejected because: (1) it would require reworking
--   private_chef_restaurant_history's already-shipped, already-tested
--   canonical/text-fallback/XOR/RLS/Michelin-attribution design for no
--   present benefit — that table already does its one job correctly;
--   (2) a polymorphic table with per-type-nullable columns is *worse*
--   for referential integrity and simplicity than two small typed
--   tables, not better — the whole point of avoiding "premature
--   complexity" is not building a schema shaped for hypothetical future
--   categories (wine/hospitality/other) that no real chef profile needs
--   yet; (3) restaurant background genuinely has a different, richer
--   shape (a canonical FK, a text-fallback XOR, and dynamically-resolved
--   Michelin recognition) than education background (an institution
--   name and a program name) — forcing them into one row shape with
--   optional columns either side would be the "CV system" the task
--   explicitly warns against, not a simplification of it.
--
-- private_chef_education deliberately mirrors private_chef_restaurant_history's
-- shape where it genuinely applies (synthetic uuid pk, private_chef_id FK
-- on delete cascade, display_order, created_at/updated_at with the
-- shared set_updated_at() trigger, RLS gated on parent-chef-published)
-- and is deliberately NOT a generic "institution catalogue" — no
-- separate institutions table, no polymorphic association, no degree-
-- level/qualification taxonomy. institution/program are plain text,
-- exactly as much structure as this MVP's one real use case (De Rooi
-- Pannen / Horeca Ondernemend Management) actually needs. period_text
-- (not start_date/end_date) matches
-- private_chef_restaurant_history.period_text's own established
-- reasoning: never invent precision a source doesn't actually support.
--
-- Not tappable in the UI by design (no canonical "institution" domain
-- exists or is planned) — this migration does not need to encode that;
-- it's a client-side rendering decision, not a data-model one.

begin;

create table public.private_chef_education (
  id               uuid primary key default gen_random_uuid(),
  private_chef_id  uuid not null references public.private_chefs(id) on delete cascade,
  institution      text not null,
  program          text not null,
  period_text      text,
  display_order    smallint not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create trigger private_chef_education_updated_at
  before update on public.private_chef_education
  for each row execute function public.set_updated_at();

-- "This chef's education background, in order" -- the only query the
-- Background section issues for this source, mirroring
-- private_chef_restaurant_history_chef_idx exactly.
create index private_chef_education_chef_idx
  on public.private_chef_education (private_chef_id);

alter table public.private_chef_education enable row level security;

-- Same read-audience decision as every other Private Chefs public table:
-- anon + authenticated, gated on the parent chef's publication_status,
-- matching private_chef_restaurant_history_public_read's exact
-- predicate shape.
create policy private_chef_education_public_read on public.private_chef_education
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.private_chefs pc
      where pc.id = private_chef_id
        and pc.publication_status = 'published'
    )
  );

-- No insert/update/delete policy for any client role -- admin-managed,
-- same as every other Private Chefs table.

grant select on public.private_chef_education to anon, authenticated;

commit;
