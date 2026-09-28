-- Two schema gaps identified while investigating photo ordering/review
-- for the (not-yet-built) photo management feature — see the chat
-- report this migration was requested from for the full reasoning.
-- Schema and RLS only; no photo-upload UI exists yet and none is added
-- here.
--
-- 1. display_order already lives on restaurant_photos/hotel_photos/
--    private_chef_photos (the APPROVED set — added 20260818120000/
--    20260828120000, long before this task) — exactly where "ordering
--    is a property of the approved set" says it should. What was
--    missing: those three tables have ONLY a public SELECT policy today
--    (confirmed live) — no client role can update anything on them at
--    all. This migration adds a narrow UPDATE path for an active venue
--    manager, restricted to display_order.
--
--    Postgres RLS has no column-level equivalent to USING/WITH CHECK —
--    a policy can restrict WHICH ROWS are updatable, never which
--    COLUMNS within an allowed row may change. So the actual column
--    restriction here is a BEFORE UPDATE trigger comparing OLD/NEW on
--    image_url/alt_text/focus_x/focus_y, not the policy itself — the
--    policy only answers "may this row be touched at all." One shared
--    trigger function across all three tables, same reasoning
--    notify_venue_claim_change() already established: the four
--    compared columns have identical names on all three tables, so one
--    function body works attached to any of them.
--
--    The trigger only enforces when current_user = 'authenticated' —
--    service_role/postgres (dashboard corrections, admin scripts,
--    the eventual review-approval workflow) bypass RLS already and
--    must stay free to edit every column; this must not block them.
--    "admin-only" for those four columns means exactly that: admin
--    keeps full access, only the new manager-facing path is narrowed.
--
-- 2. venue_photo_submissions has no column at all for a reviewer's
--    note today (confirmed live: id/user_id/venue_type/venue_id/
--    storage_path/replaces_photo_id/status/submitted_at/reviewed_at/
--    reviewed_by/phash/duplicate_of_submission_id — nothing else).
--    review_note (text, nullable — a rejection without a note must
--    still be possible, per explicit instruction) closes that gap.
--    Deliberately NOT mirroring venue_managers_*.revoked_reason's own
--    "required whenever revoked" CHECK constraint — that was a
--    different, explicit decision for that table; this one was asked
--    for as unconditionally nullable.

begin;

-- ============================================================
-- 1a. RLS — an active manager may update their own venue's photo rows.
--     Row-scoping only; see the trigger below for the actual column
--     restriction.
-- ============================================================

create policy restaurant_photos_manager_reorder on public.restaurant_photos
  for update to authenticated
  using (public.is_active_venue_manager('restaurant', restaurant_id))
  with check (public.is_active_venue_manager('restaurant', restaurant_id));

create policy hotel_photos_manager_reorder on public.hotel_photos
  for update to authenticated
  using (public.is_active_venue_manager('hotel', hotel_id))
  with check (public.is_active_venue_manager('hotel', hotel_id));

create policy private_chef_photos_manager_reorder on public.private_chef_photos
  for update to authenticated
  using (public.is_active_venue_manager('private_chef', private_chef_id))
  with check (public.is_active_venue_manager('private_chef', private_chef_id));

grant update on public.restaurant_photos to authenticated;
grant update on public.hotel_photos to authenticated;
grant update on public.private_chef_photos to authenticated;

-- ============================================================
-- 1b. Column-immutability trigger — the actual "display_order only"
--     enforcement. Not security definer (a plain per-row check, no
--     elevated privilege needed) — matches enforce_restaurant_photo_
--     limit()/enforce_hotel_photo_limit()/enforce_photo_submission_
--     replacement()'s own style exactly, none of which are security
--     definer or have an explicit revoke either (a `returns trigger`
--     function is never callable as a client RPC regardless of grants,
--     so there is nothing for a revoke to close here).
-- ============================================================

create function public.enforce_manager_photo_reorder_only()
returns trigger
language plpgsql
as $$
begin
  if current_user = 'authenticated' then
    if new.image_url is distinct from old.image_url
      or new.alt_text is distinct from old.alt_text
      or new.focus_x is distinct from old.focus_x
      or new.focus_y is distinct from old.focus_y
    then
      raise exception 'Only display_order may be changed by a venue manager.';
    end if;
  end if;
  return new;
end;
$$;

create trigger restaurant_photos_manager_reorder_only
  before update on public.restaurant_photos
  for each row execute function public.enforce_manager_photo_reorder_only();
create trigger hotel_photos_manager_reorder_only
  before update on public.hotel_photos
  for each row execute function public.enforce_manager_photo_reorder_only();
create trigger private_chef_photos_manager_reorder_only
  before update on public.private_chef_photos
  for each row execute function public.enforce_manager_photo_reorder_only();

-- ============================================================
-- 2. review_note — a reviewer's own note on a photo submission,
--    surfaced to the manager (e.g. "this needs to be a photo of you").
--    Written only by service_role today, same as reviewed_at/
--    reviewed_by — no new client-facing write path is added here.
-- ============================================================

alter table public.venue_photo_submissions add column review_note text;

commit;
