-- Events self-management, step 2 of the build order: cancelled_at (with a
-- temporary compatibility shim for the already-shipped app build that
-- still reads `status`), the owner UPDATE policy + column-restriction
-- trigger that let a host edit their own event without touching the
-- moderation machinery, and a participant-approval marker on the three
-- join tables so a host can attach a new co-participant to an already-
-- published event without the event itself coming down for review.
--
-- Does NOT touch venue claims, venue photo/about submissions, or drop
-- `events.status` — that drop waits for explicit confirmation that every
-- tester is on a build that no longer reads it (see CLAUDE.md's
-- three-step destructive-change rule).

begin;

-- ============================================================
-- 1. cancelled_at + the status compatibility shim
-- ============================================================
--
-- status (upcoming/cancelled/completed) is being retired: upcoming/
-- completed are derivable from end_date/end_time/timezone and nothing
-- should maintain a stored, driftable copy of a derivable value.
-- cancelled is the one state that must be stored (it's an assertion, not
-- a computation), so it moves to cancelled_at — null means not cancelled,
-- a timestamp means cancelled then.
--
-- status itself is NOT dropped here. The shipped Flutter app still reads
-- it via Event.isCancelled in 11 real call sites; dropping it now would
-- break event screens for any user on the currently-installed build, with
-- no way to roll that back faster than people update. So during this
-- transition both shapes must stay correct, not merely present: the shim
-- trigger below keeps status in sync with cancelled_at so an old build
-- never shows a cancelled event as still going ahead.

alter table public.events add column cancelled_at timestamptz;

-- TEMPORARY COMPATIBILITY SHIM — remove together with the `status` column
-- itself, on explicit confirmation that no installed app build still
-- reads `status` (see CLAUDE.md's three-step destructive-change rule).
-- Until then this keeps status='cancelled' whenever cancelled_at is set,
-- so an old build's Event.isCancelled (status == EventStatus.cancelled)
-- never reads a stale 'upcoming'/'completed' for an event that has
-- actually been cancelled via the new column. One-directional by design:
-- it only ever forces 'cancelled' in; it never computes upcoming/completed
-- back out, because nothing maintains those as meaningful once this ships
-- (see the "status stops being a maintained value" note elsewhere in this
-- project's event lifecycle docs).
create function public.sync_events_status_cancelled_shim()
returns trigger
language plpgsql
as $$
begin
  if new.cancelled_at is not null then
    new.status := 'cancelled';
  end if;
  return new;
end;
$$;

create trigger events_status_cancelled_shim
  before insert or update on public.events
  for each row execute function public.sync_events_status_cancelled_shim();

-- ============================================================
-- 2. Owner UPDATE policy + the column-restriction trigger
-- ============================================================
--
-- Edit rights key off submitted_by alone — never off an is_host/is_venue
-- join-table row, even for a genuine co-host. Confirmed directly: no RLS
-- policy anywhere today derives event-edit rights from a join-table row,
-- so this is new surface, not a tightening of an existing one. RLS is
-- row-level only, so it can authorize "this is your event" but cannot by
-- itself stop a host from writing moderation_status/submitted_by
-- directly — that boundary needs the trigger below, mirroring
-- enforce_manager_photo_reorder_only's exact shape: restrict specific
-- columns, only when current_user is authenticated, so service_role (and
-- any future SECURITY DEFINER review RPC, which runs as its owning role,
-- not 'authenticated') stays unrestricted.

create policy events_owner_update on public.events
  for update to authenticated
  using (submitted_by = auth.uid())
  with check (submitted_by = auth.uid());

-- cancelled_at is deliberately NOT in the restricted list below — a host
-- may cancel their own event at any time, published or not, with no
-- review step. Everything else about their own event (title,
-- description, dates, times, timezone, location, ...) is likewise
-- unrestricted by this trigger; only the moderation machinery is
-- protected.
--
-- events.reviewed_at/reviewed_by/review_note do not exist yet — they are
-- added by the submit_event/approve_event/reject_event RPCs (build order
-- step 4, mirroring approve_venue_about/reject_venue_about). This trigger
-- must be extended to list them alongside moderation_status/submitted_by
-- at that time; there is nothing to protect yet because the columns
-- don't exist.
create function public.enforce_event_host_edit_columns()
returns trigger
language plpgsql
as $$
begin
  if current_user = 'authenticated' then
    if new.moderation_status is distinct from old.moderation_status
      or new.submitted_by is distinct from old.submitted_by
    then
      raise exception
        'moderation_status and submitted_by can only change through review, not a host edit.';
    end if;
  end if;
  return new;
end;
$$;

create trigger events_host_edit_columns_only
  before update on public.events
  for each row execute function public.enforce_event_host_edit_columns();

-- ============================================================
-- 3. Participant approval marker — the three join tables
-- ============================================================
--
-- null = pending, a timestamp = approved. Lets a host attach a new
-- co-participant to an already-published event without the event itself
-- leaving moderation_status='published' for review — the event stays
-- live and visible; only the new, unapproved link stays invisible until
-- approved. No second submissions queue: approving one is a single
-- `update ... set approved_at = now()` from the dashboard (service_role,
-- consistent with "no in-app admin identity"), and rejecting one is
-- deleting the pending row — nothing more to build.
--
-- default now(): every existing row (34 restaurant links, 4 hotel links,
-- 0 chef links — confirmed directly before writing this) was admin/
-- import-authored and already live, so it backfills to "already
-- approved," a true no-op for current visibility. Any future plain
-- admin-authored insert (service_role, bypassing RLS for a new curated
-- event) also defaults to approved automatically, with zero new friction
-- on that existing workflow. Only the new host-edit insert policy below
-- explicitly overrides this default to null.

alter table public.event_restaurants add column approved_at timestamptz default now();
alter table public.event_hotels add column approved_at timestamptz default now();
alter table public.event_chefs add column approved_at timestamptz default now();

drop policy event_restaurants_public_read on public.event_restaurants;
create policy event_restaurants_public_read on public.event_restaurants
  for select to anon, authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.moderation_status = 'published')
    and approved_at is not null
  );

drop policy event_hotels_public_read on public.event_hotels;
create policy event_hotels_public_read on public.event_hotels
  for select to anon, authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.moderation_status = 'published')
    and approved_at is not null
  );

drop policy event_chefs_public_read on public.event_chefs;
create policy event_chefs_public_read on public.event_chefs
  for select to anon, authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.moderation_status = 'published')
    and approved_at is not null
  );

-- event_{restaurants,hotels,chefs}_own_submission_read (added
-- 20260828120000) is untouched and already correct for this: it shows
-- every row for an event the caller submitted, pending or approved, with
-- no approved_at condition — a host can already see their own
-- not-yet-approved attachment.

-- ============================================================
-- 4. INSERT/DELETE for a host editing an already-published event's
--    participants
-- ============================================================
--
-- No is_active_venue_manager() gate here, unlike the existing
-- *_claimant_insert policies — deliberately. is_active_venue_manager
-- asks "do you manage this venue", which is the right question for a
-- manager attaching their OWN venue (a statement about themselves,
-- nothing to review — the claimant_insert policies below are untouched
-- and keep that gate) and the wrong one for crediting someone else (a
-- four-hands dinner is defined by a guest the host does not manage). The
-- safety for THAT case doesn't live in who may insert — it lives in the
-- approval marker added in section 3: a host-added link is invisible
-- until approved, so who may insert stops mattering once nothing reaches
-- the public before review. The only conditions left are ownership
-- (submitted_by = auth.uid()) and forcing the link to land pending.
--
-- approved_at's column default (now(), section 3) does NOT fight this:
-- a DEFAULT only fills in a value the INSERT statement omits, and a
-- WITH CHECK clause only validates whatever value the row ends up
-- with — it cannot force one. Relying on the default/check alone would
-- mean a plain insert that omits approved_at lands as now() and gets
-- correctly REJECTED by `approved_at is null` below (fails safe, but
-- opaque), while an insert that explicitly set a non-null approved_at
-- would be rejected too, rather than silently overridden. "Forced to
-- null regardless of what is sent" needs an actual override, so the
-- trigger below unconditionally sets approved_at := null before the
-- check ever runs, for this case specifically — leaving the column
-- default, and therefore the backfill no-op, completely untouched for
-- every other insert (service_role/admin, and the claimant_insert path
-- for a still-submitted event, both unaffected since the trigger only
-- fires when the underlying event is already published).
--
-- Knowingly accepted, not overlooked: a host can insert pending links to
-- any number of canonical venues this way. Every one is invisible until
-- approved and every one lands in the same review queue. At thirteen
-- users this isn't worth rate-limiting; the mitigation is the one used
-- everywhere else in this model — revoke the host's manager/organiser
-- grant if the privilege is abused. See EVENTS_V2_ARCHITECTURE.md §19
-- for the same note recorded against the architecture.

create function public.force_pending_link_on_published_event()
returns trigger
language plpgsql
as $$
declare
  v_moderation_status text;
begin
  if current_user = 'authenticated' then
    select moderation_status into v_moderation_status
    from public.events where id = new.event_id;

    if v_moderation_status = 'published' then
      new.approved_at := null;
    end if;
  end if;
  return new;
end;
$$;

create trigger event_restaurants_force_pending_on_published
  before insert on public.event_restaurants
  for each row execute function public.force_pending_link_on_published_event();

create trigger event_hotels_force_pending_on_published
  before insert on public.event_hotels
  for each row execute function public.force_pending_link_on_published_event();

create trigger event_chefs_force_pending_on_published
  before insert on public.event_chefs
  for each row execute function public.force_pending_link_on_published_event();

create policy event_restaurants_host_edit_insert on public.event_restaurants
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'published'
    )
    and approved_at is null
  );

create policy event_hotels_host_edit_insert on public.event_hotels
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'published'
    )
    and approved_at is null
  );

create policy event_chefs_host_edit_insert on public.event_chefs
  for insert to authenticated with check (
    exists (
      select 1 from public.events e
      where e.id = event_id and e.submitted_by = auth.uid() and e.moderation_status = 'published'
    )
    and approved_at is null
  );

-- DELETE is not scoped to moderation_status = 'published': a host
-- removing a participant doesn't assert anything new about a third party
-- (unlike adding one), so it needs no approval gate and no "even after
-- publication" carve-out — it's just as safe during draft/submitted as
-- after publication. No delete policy existed on any of these three
-- tables before this migration, so this is new surface in every
-- moderation_status, not a narrowing of anything that worked before.

create policy event_restaurants_host_delete on public.event_restaurants
  for delete to authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.submitted_by = auth.uid())
    and public.is_active_venue_manager('restaurant', restaurant_id)
  );

create policy event_hotels_host_delete on public.event_hotels
  for delete to authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.submitted_by = auth.uid())
    and public.is_active_venue_manager('hotel', hotel_id)
  );

create policy event_chefs_host_delete on public.event_chefs
  for delete to authenticated using (
    exists (select 1 from public.events e where e.id = event_id and e.submitted_by = auth.uid())
    and public.is_active_venue_manager('private_chef', chef_id)
  );

commit;
