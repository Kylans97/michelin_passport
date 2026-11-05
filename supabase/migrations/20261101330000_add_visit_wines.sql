-- VISIT WINES: the wines a member noted on a visit or stay. Written
-- 2026-11-04, asked for by the product owner ("goed eten gaat samen met goede
-- wijn"). Every field is optional, but a row must say something.
--
-- A table of its own, since one evening can have several wines. A wine is
-- exactly as visible as its visit: the owner always, friends only when the
-- visit's visibility is 'friends' (the rule photos_read has used since
-- 20260814120000). visit_id and user_id both cascade, so deleting a visit or
-- an account removes its wines.
--
-- user_id is on the row so a member's own earlier wines can be suggested
-- without a join. The insert policy requires that the visit is the member's
-- own, so a wine can't be attached to someone else's visit.
--
-- vintage NULL with non_vintage false: the year wasn't noted. non_vintage
-- true: a wine with no year (NV Champagne). Those are different things.
--
-- Filename: 20261101320000 is taken by the unapplied
-- add_event_announcement_status on claude/event-expected-soldout, so this
-- takes the next number. Whichever is applied second may need renaming to
-- follow the highest applied one. No SECURITY DEFINER function here.

begin;

create table public.visit_wines (
  id            uuid primary key default gen_random_uuid(),
  visit_id      uuid not null references public.visits(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  producer      text check (char_length(producer) between 1 and 120),
  wine_name     text check (char_length(wine_name) between 1 and 120),
  vintage       smallint check (vintage between 1800 and 2100),
  non_vintage   boolean not null default false,
  bottle_size   text check (bottle_size in ('glass', 'half', 'bottle', 'magnum', 'other')),
  display_order smallint not null default 0,
  created_at    timestamptz not null default now(),
  constraint visit_wines_says_something check (
    producer is not null or wine_name is not null or vintage is not null
    or non_vintage or bottle_size is not null
  ),
  constraint visit_wines_year_or_nv check (not (non_vintage and vintage is not null))
);

create index visit_wines_visit_idx on public.visit_wines (visit_id, display_order);
create index visit_wines_user_idx on public.visit_wines (user_id);

alter table public.visit_wines enable row level security;

create policy visit_wines_read on public.visit_wines
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.visits v
      where v.id = visit_wines.visit_id
        and v.visibility = 'friends'
        and public.is_friend(v.user_id)
    )
  );

create policy visit_wines_insert on public.visit_wines
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.visits v
      where v.id = visit_wines.visit_id and v.user_id = auth.uid()
    )
  );

create policy visit_wines_update on public.visit_wines
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.visits v
      where v.id = visit_wines.visit_id and v.user_id = auth.uid()
    )
  );

create policy visit_wines_delete on public.visit_wines
  for delete to authenticated
  using (user_id = auth.uid());

revoke all on public.visit_wines from public, anon, authenticated;
grant select, insert, update, delete on public.visit_wines to authenticated;

commit;
