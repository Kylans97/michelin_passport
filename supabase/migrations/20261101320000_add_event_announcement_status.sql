-- events.announcement_status: an event is either "official" (the venue or
-- organiser announced it itself, the meaning every existing event has) or
-- "expected" (we know of it from a secondary source, e.g. trade press, and the
-- venue has not announced it yet). Expected events are shown with an
-- "Expected" label; the secondary source is kept in expected_source_url, never
-- in official_url.
--
-- Written 2026-11-05, on the product owner's decision of that day (source-C
-- events from world_event_overview_20261105.csv: "als wij het al weten maar het
-- is nog niet officieel ... expected"). Sold out needs no migration:
-- events.availability_status already allows 'sold_out'
-- (20260819140000_events_v2_host_venue_moderation.sql); the app now shows it.
--
-- Filename timestamp is a sequence number only: after 20261101300000 (the
-- highest on main when written) and after 20261101310000_add_bh_ky_mu_countries
-- (prepared on branch claude/overnight-world-events, not applied). If either
-- ordering no longer holds when this is applied, rename this file to follow
-- the highest migration; it has not been applied anywhere.
--
-- Additive only. Every existing row becomes 'official' through the default,
-- which is what it already was. An app build that predates this column ignores
-- it and would show an expected event WITHOUT its label: do not set any event
-- to 'expected' until the build that reads it has shipped (release note).
--
-- Who may change it: only review/editorial paths, never a host edit. There is
-- no client UPDATE path on events (20261018130000 section 5); the host-edit
-- column lock below is extended to the two new columns as defence in depth,
-- exactly as it already covers the moderation columns. Expected -> official is
-- done by the same production path that inserts curated events (service_role),
-- setting official_url at the same time.

begin;

alter table public.events
  add column announcement_status text not null default 'official'
    constraint events_announcement_status_check
      check (announcement_status in ('official', 'expected')),
  add column expected_source_url text,
  add constraint events_expected_needs_source
    check (announcement_status = 'official' or expected_source_url is not null);

comment on column public.events.announcement_status is
  'official: announced by the venue or organiser itself. expected: known from '
  'a secondary source (expected_source_url), not yet announced; shown with an '
  '"Expected" label.';
comment on column public.events.expected_source_url is
  'The secondary source an expected event rests on. official_url stays for the '
  'venue''s or organiser''s own announcement.';

-- The host-edit column lock (last defined in 20261018130000), extended to the
-- two new columns. Body otherwise identical.
create or replace function public.enforce_event_host_edit_columns()
returns trigger
language plpgsql
as $$
begin
  if current_user = 'authenticated' then
    if new.moderation_status is distinct from old.moderation_status
      or new.submitted_by is distinct from old.submitted_by
      or new.submitted_at is distinct from old.submitted_at
      or new.reviewed_at is distinct from old.reviewed_at
      or new.reviewed_by is distinct from old.reviewed_by
      or new.review_note is distinct from old.review_note
    then
      raise exception
        'Moderation and review columns can only change through review, not a host edit.';
    end if;
    if new.announcement_status is distinct from old.announcement_status
      or new.expected_source_url is distinct from old.expected_source_url
    then
      raise exception
        'Announcement status can only change editorially, not through a host edit.';
    end if;
  end if;
  return new;
end;
$$;

commit;
