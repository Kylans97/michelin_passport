-- Approval RPCs — replaces the manual copy-two-ids-by-hand snippets in
-- docs/Engineering/VENUE_CLAIM_OPERATIONS.md with one line of SQL per
-- approval/rejection. Still run entirely from the Supabase Dashboard's
-- SQL Editor as service_role, which bypasses RLS — that is the existing
-- pattern (see this migration's own investigation report in chat) and it
-- stays. No admin role, no is_admin column, no JWT claim, no in-app
-- review screen. See CLAUDE.md's own "Venue permissions"/"Venue-supplied
-- content" sections for the underlying model this implements.
--
-- ============================================================
-- WHY SIX FUNCTIONS DO NOT CHECK auth.uid()
-- ============================================================
-- Every other SECURITY DEFINER RPC in this schema (accept_friend_request,
-- send_venue_invite, reorder_venue_photos, is_active_venue_manager) opens
-- with `if auth.uid() is null then raise exception 'Not authenticated'`,
-- because they're called by a signed-in app user with a real JWT. These
-- six are the opposite case: called only from the Dashboard as
-- service_role, where auth.uid() is ALWAYS null by construction. Copying
-- that guard here would make every legitimate call fail. Omitting it is
-- deliberate, not an oversight — see the repeated comment on each
-- function below, and the REVOKE section at the bottom, which is what
-- actually stands between a signed-in user and calling these through
-- PostgREST.
--
-- ============================================================
-- WHY reviewed_by/granted_by ARE AN EXPLICIT REQUIRED ARGUMENT
-- ============================================================
-- service_role has no auth.uid() to read, so these can't self-populate
-- the reviewer the way a client-called RPC would. null is legal per the
-- column's own nullability but dishonest given what the column is FOR
-- (an audit trail of who reviewed what); a hardcoded id would silently
-- misattribute every future reviewer's work to one person. p_reviewed_by
-- uuid, required, validated against a real profiles.id, is the answer
-- that stays correct if a later in-app admin screen ever passes
-- auth.uid() instead of a dashboard-pasted id — same function, same
-- signature, different caller.
--
-- ============================================================
-- review_note ON THREE MORE TABLES
-- ============================================================
-- venue_about_submissions never got a review_note column (only
-- venue_photo_submissions did, in 20261002120000) — added here so
-- reject_venue_about has somewhere to put the reason. NOTE: nothing in
-- the Flutter app reads it yet (VenueAboutSubmission has no reviewNote
-- field, unlike its photo-submission counterpart, which already renders
-- one in VenueManagementScreen) — this column will be written and
-- invisible until that catches up. Real follow-up debt, not fixed here.
--
-- claims_restaurants/_hotels/_private_chefs never got one either —
-- discovered while building reject_venue_claim, not anticipated going
-- in. Their only text field is `notes`, which is the CLAIMANT's own
-- submitted note, not a reviewer's rejection reason — reusing it would
-- silently overwrite the claimant's own words. Fixed the same way, same
-- migration, same reasoning already applied one line up.
--
-- ============================================================
-- approve_venue_photo's image_url ARGUMENT
-- ============================================================
-- venue_photo_submissions.storage_path is a path inside the PRIVATE
-- venue-photo-submissions bucket (public = false, confirmed live);
-- restaurant_photos/hotel_photos/private_chef_photos.image_url is a full
-- public URL into the PUBLIC catalogue-media bucket (public = true,
-- confirmed live, sample URL confirmed against storage.objects). Moving
-- the actual file between them is a Storage-API operation no SQL
-- function can perform — storage.objects is metadata only, the bytes
-- live outside Postgres. So the destination URL is an explicit
-- p_image_url argument, supplied after a human (or, later, some other
-- process — the signature doesn't care) puts the file in catalogue-media
-- by hand first. This function does not trust that argument blindly: it
-- requires the exact catalogue-media public-URL prefix (confirmed
-- 2026-10-05 against a real published row, not assumed from a quoted
-- example) and requires a matching storage.objects row to actually
-- exist for that path — a typo'd URL fails the call instead of
-- publishing a broken image. It does not, and cannot, verify the object
-- is actually a photo of the right venue; that's still a human looking
-- at the image before approving, same as today.
--
-- Known, reported, not fixed here: deleting a replaced published photo
-- (the replaces_photo_id path below) removes only the database row —
-- its bytes stay in catalogue-media, orphaned. This function has no way
-- to delete a Storage object either. Will accumulate invisibly until
-- something cleans it up; out of scope for this migration.
--
-- ============================================================
-- GRANTS — WIDER THAN THIS PROJECT'S STANDING PATTERN, DELIBERATELY
-- ============================================================
-- CLAUDE.md's own standing rule is `revoke execute ... from public,
-- anon` on every new SECURITY DEFINER function, because this project's
-- Supabase instance auto-grants anon (via PUBLIC) execute on every new
-- public function. That rule is necessary but NOT sufficient here:
-- querying information_schema.routine_privileges on existing functions
-- shows `authenticated` also holds EXECUTE on all of them (including
-- trigger-only functions that were never meant to be called directly),
-- via a separate Supabase default-privilege mechanism for the
-- `authenticated` role specifically. Every other RPC in this schema
-- WANTS authenticated to call it. These six do not — a signed-in user
-- must never be able to approve their own claim through PostgREST — so
-- the revoke below is `from public, anon, authenticated`, one role wider
-- than the documented pattern. postgres/service_role keep EXECUTE via
-- ownership/role membership; no explicit grant needed for them.

begin;

-- ============================================================
-- 0. review_note columns
-- ============================================================

alter table public.venue_about_submissions add column review_note text;
alter table public.claims_restaurants add column review_note text;
alter table public.claims_hotels add column review_note text;
alter table public.claims_private_chefs add column review_note text;

-- ============================================================
-- 1. approve_venue_claim / reject_venue_claim
--
-- p_venue_type is required (unlike the about/photo functions below):
-- claims live in three separate physical tables, not one polymorphic
-- table with its own venue_type column, so p_claim_id alone can't say
-- which table to look in. Matches is_active_venue_manager/
-- reorder_venue_photos's own "venue_type first" argument order.
-- ============================================================

create function public.approve_venue_claim(
  p_venue_type text,
  p_claim_id uuid,
  p_reviewed_by uuid
)
returns table (id uuid, status text, reviewed_at timestamptz, reviewed_by uuid, review_note text)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid;
  v_venue_id uuid;
  v_active_exists boolean;
begin
  -- No auth.uid() check: called only via service_role from the Dashboard,
  -- where auth.uid() is always null. The revoke at the bottom of this
  -- migration (from public, anon, authenticated) is the authorization
  -- boundary, not an in-function check — see this migration's own header.

  -- Every bare column reference below is explicitly table-qualified —
  -- not just style. RETURNS TABLE(id uuid, status text, ...) implicitly
  -- declares id/status/reviewed_at/reviewed_by/review_note as plpgsql
  -- variables in scope for the WHOLE function body, not only at RETURN;
  -- an unqualified `where id = ...` is genuinely ambiguous between that
  -- OUT parameter and the table column, and Postgres rejects it at
  -- CREATE time (42702) — caught during this function's own validation,
  -- not a style preference.
  if p_reviewed_by is null or not exists (select 1 from public.profiles p where p.id = p_reviewed_by) then
    raise exception 'p_reviewed_by must be a real profiles.id, got %', p_reviewed_by;
  end if;

  if p_venue_type = 'restaurant' then
    select cr.user_id, cr.restaurant_id into v_user_id, v_venue_id
      from public.claims_restaurants cr where cr.id = p_claim_id and cr.status = 'pending' for update;
  elsif p_venue_type = 'hotel' then
    select ch.user_id, ch.hotel_id into v_user_id, v_venue_id
      from public.claims_hotels ch where ch.id = p_claim_id and ch.status = 'pending' for update;
  elsif p_venue_type = 'private_chef' then
    select cp.user_id, cp.private_chef_id into v_user_id, v_venue_id
      from public.claims_private_chefs cp where cp.id = p_claim_id and cp.status = 'pending' for update;
  else
    raise exception 'Unknown venue_type: %', p_venue_type;
  end if;

  if v_user_id is null then
    raise exception 'claim % is not pending (or does not exist) for venue_type %', p_claim_id, p_venue_type;
  end if;

  if p_venue_type = 'restaurant' then
    v_active_exists := exists (
      select 1 from public.venue_managers_restaurants vm
      where vm.user_id = v_user_id and vm.restaurant_id = v_venue_id and vm.revoked_at is null
    );
  elsif p_venue_type = 'hotel' then
    v_active_exists := exists (
      select 1 from public.venue_managers_hotels vm
      where vm.user_id = v_user_id and vm.hotel_id = v_venue_id and vm.revoked_at is null
    );
  else
    v_active_exists := exists (
      select 1 from public.venue_managers_private_chefs vm
      where vm.user_id = v_user_id and vm.private_chef_id = v_venue_id and vm.revoked_at is null
    );
  end if;

  if v_active_exists then
    raise exception 'user % already has an active manager grant for this %', v_user_id, p_venue_type;
  end if;

  if p_venue_type = 'restaurant' then
    update public.claims_restaurants cr
      set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by
      where cr.id = p_claim_id;
    insert into public.venue_managers_restaurants (user_id, restaurant_id, claim_id, granted_at, granted_by)
      values (v_user_id, v_venue_id, p_claim_id, now(), p_reviewed_by);
    return query select cr.id, cr.status, cr.reviewed_at, cr.reviewed_by, cr.review_note
      from public.claims_restaurants cr where cr.id = p_claim_id;
  elsif p_venue_type = 'hotel' then
    update public.claims_hotels ch
      set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by
      where ch.id = p_claim_id;
    insert into public.venue_managers_hotels (user_id, hotel_id, claim_id, granted_at, granted_by)
      values (v_user_id, v_venue_id, p_claim_id, now(), p_reviewed_by);
    return query select ch.id, ch.status, ch.reviewed_at, ch.reviewed_by, ch.review_note
      from public.claims_hotels ch where ch.id = p_claim_id;
  else
    update public.claims_private_chefs cp
      set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by
      where cp.id = p_claim_id;
    insert into public.venue_managers_private_chefs (user_id, private_chef_id, claim_id, granted_at, granted_by)
      values (v_user_id, v_venue_id, p_claim_id, now(), p_reviewed_by);
    return query select cp.id, cp.status, cp.reviewed_at, cp.reviewed_by, cp.review_note
      from public.claims_private_chefs cp where cp.id = p_claim_id;
  end if;
end;
$$;

create function public.reject_venue_claim(
  p_venue_type text,
  p_claim_id uuid,
  p_reviewed_by uuid,
  p_review_note text
)
returns table (id uuid, status text, reviewed_at timestamptz, reviewed_by uuid, review_note text)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_row_count integer;
begin
  -- No auth.uid() check — see approve_venue_claim's own comment above,
  -- same reasoning applies verbatim.

  -- Table-qualified throughout — see approve_venue_claim's own comment
  -- on why a bare `id`/`status` here is genuinely ambiguous against this
  -- function's own RETURNS TABLE OUT parameters, not just a style choice.
  if p_reviewed_by is null or not exists (select 1 from public.profiles p where p.id = p_reviewed_by) then
    raise exception 'p_reviewed_by must be a real profiles.id, got %', p_reviewed_by;
  end if;

  if p_venue_type = 'restaurant' then
    update public.claims_restaurants cr
      set status = 'rejected', reviewed_at = now(), reviewed_by = p_reviewed_by, review_note = p_review_note
      where cr.id = p_claim_id and cr.status = 'pending';
    get diagnostics v_row_count = row_count;
    if v_row_count = 0 then
      raise exception 'claim % is not pending (or does not exist) for venue_type restaurant', p_claim_id;
    end if;
    return query select cr.id, cr.status, cr.reviewed_at, cr.reviewed_by, cr.review_note
      from public.claims_restaurants cr where cr.id = p_claim_id;
  elsif p_venue_type = 'hotel' then
    update public.claims_hotels ch
      set status = 'rejected', reviewed_at = now(), reviewed_by = p_reviewed_by, review_note = p_review_note
      where ch.id = p_claim_id and ch.status = 'pending';
    get diagnostics v_row_count = row_count;
    if v_row_count = 0 then
      raise exception 'claim % is not pending (or does not exist) for venue_type hotel', p_claim_id;
    end if;
    return query select ch.id, ch.status, ch.reviewed_at, ch.reviewed_by, ch.review_note
      from public.claims_hotels ch where ch.id = p_claim_id;
  elsif p_venue_type = 'private_chef' then
    update public.claims_private_chefs cp
      set status = 'rejected', reviewed_at = now(), reviewed_by = p_reviewed_by, review_note = p_review_note
      where cp.id = p_claim_id and cp.status = 'pending';
    get diagnostics v_row_count = row_count;
    if v_row_count = 0 then
      raise exception 'claim % is not pending (or does not exist) for venue_type private_chef', p_claim_id;
    end if;
    return query select cp.id, cp.status, cp.reviewed_at, cp.reviewed_by, cp.review_note
      from public.claims_private_chefs cp where cp.id = p_claim_id;
  else
    raise exception 'Unknown venue_type: %', p_venue_type;
  end if;
end;
$$;

-- ============================================================
-- 2. approve_venue_about / reject_venue_about
--
-- No p_venue_type argument: venue_about_submissions is one polymorphic
-- table carrying its own venue_type/venue_id columns — resolved from the
-- row itself, never asked for separately. This is the asymmetry with the
-- claim functions above, not an inconsistency: claims are three physical
-- tables, this is one.
-- ============================================================

create function public.approve_venue_about(p_submission_id uuid, p_reviewed_by uuid)
returns public.venue_about_submissions
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_result public.venue_about_submissions;
begin
  -- No auth.uid() check — see approve_venue_claim's own comment; same
  -- reasoning, every function in this migration.

  if p_reviewed_by is null or not exists (select 1 from public.profiles p where p.id = p_reviewed_by) then
    raise exception 'p_reviewed_by must be a real profiles.id, got %', p_reviewed_by;
  end if;

  update public.venue_about_submissions
    set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by
    where id = p_submission_id and status = 'pending'
    returning * into v_result;

  if v_result.id is null then
    raise exception 'venue_about_submissions % is not pending (or does not exist)', p_submission_id;
  end if;
  -- Nothing else to do: venue_about_current resolves "latest approved"
  -- by reviewed_at desc nulls last, submitted_at desc — an earlier
  -- approved row for the same venue is automatically superseded by this
  -- one without needing to touch it.
  return v_result;
end;
$$;

create function public.reject_venue_about(p_submission_id uuid, p_reviewed_by uuid, p_review_note text)
returns public.venue_about_submissions
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_result public.venue_about_submissions;
begin
  -- No auth.uid() check — see approve_venue_claim's own comment.

  if p_reviewed_by is null or not exists (select 1 from public.profiles p where p.id = p_reviewed_by) then
    raise exception 'p_reviewed_by must be a real profiles.id, got %', p_reviewed_by;
  end if;

  update public.venue_about_submissions
    set status = 'rejected', reviewed_at = now(), reviewed_by = p_reviewed_by, review_note = p_review_note
    where id = p_submission_id and status = 'pending'
    returning * into v_result;

  if v_result.id is null then
    raise exception 'venue_about_submissions % is not pending (or does not exist)', p_submission_id;
  end if;
  return v_result;
end;
$$;

-- ============================================================
-- 3. approve_venue_photo / reject_venue_photo
-- ============================================================

create function public.approve_venue_photo(
  p_submission_id uuid,
  p_reviewed_by uuid,
  p_image_url text
)
returns table (published_id uuid, image_url text, display_order smallint, submission_id uuid)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_sub public.venue_photo_submissions;
  -- Confirmed 2026-10-05 against a real published row (private_chef_photos)
  -- cross-checked against storage.objects, not assumed from an example.
  v_prefix constant text :=
    'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/';
  v_object_path text;
  v_display_order smallint;
  v_new_id uuid;
begin
  -- No auth.uid() check — see approve_venue_claim's own comment.

  -- Table-qualified throughout this function too — display_order/
  -- image_url are among this function's own RETURNS TABLE OUT
  -- parameters (published_id, image_url, display_order, submission_id),
  -- so a bare reference to either inside max()/RETURNING is genuinely
  -- ambiguous, not just inconsistent style. See approve_venue_claim's
  -- own comment for the same issue caught the same way (42702 at
  -- CREATE time).
  if p_reviewed_by is null or not exists (select 1 from public.profiles p where p.id = p_reviewed_by) then
    raise exception 'p_reviewed_by must be a real profiles.id, got %', p_reviewed_by;
  end if;

  select * into v_sub from public.venue_photo_submissions vps
    where vps.id = p_submission_id and vps.status = 'pending' for update;
  if v_sub.id is null then
    raise exception 'venue_photo_submissions % is not pending (or does not exist)', p_submission_id;
  end if;

  -- Trust nothing about the hand-typed URL: it must be the real
  -- catalogue-media public prefix, and an object must actually exist at
  -- the path it names. A typo'd URL fails the call instead of publishing
  -- a broken image. This cannot and does not verify the object is
  -- actually a photo of the right venue — that's still a human looking
  -- at it before approving, same as the review step already requires.
  if p_image_url is null or left(p_image_url, length(v_prefix)) is distinct from v_prefix then
    raise exception 'p_image_url must start with %', v_prefix;
  end if;
  v_object_path := substring(p_image_url from length(v_prefix) + 1);
  if not exists (
    select 1 from storage.objects where bucket_id = 'catalogue-media' and name = v_object_path
  ) then
    raise exception 'No object at % in the catalogue-media bucket — copy the file there before approving', v_object_path;
  end if;

  if v_sub.replaces_photo_id is not null then
    -- Preserve position rather than append: a manager replacing their
    -- 3rd photo means "swap it," not "replace it and also demote it to
    -- last." Also sidesteps the 5-cap trigger entirely, since a slot is
    -- freed before the new row is inserted.
    if v_sub.venue_type = 'restaurant' then
      delete from public.restaurant_photos rp
        where rp.id = v_sub.replaces_photo_id and rp.restaurant_id = v_sub.venue_id
        returning rp.display_order into v_display_order;
    elsif v_sub.venue_type = 'hotel' then
      delete from public.hotel_photos hp
        where hp.id = v_sub.replaces_photo_id and hp.hotel_id = v_sub.venue_id
        returning hp.display_order into v_display_order;
    else
      delete from public.private_chef_photos pcp
        where pcp.id = v_sub.replaces_photo_id and pcp.private_chef_id = v_sub.venue_id
        returning pcp.display_order into v_display_order;
    end if;
    if v_display_order is null then
      raise exception 'replaces_photo_id % does not belong to venue % (%)',
        v_sub.replaces_photo_id, v_sub.venue_id, v_sub.venue_type;
    end if;
    -- The deleted row's bytes stay in catalogue-media — this function
    -- has no way to delete a Storage object. Orphaned, reported in this
    -- migration's own header, not fixed here.
  else
    -- Append after the current maximum. Zero photos yet -> coalesce
    -- gives 0, matching the column's own default. A gap left by an
    -- earlier deletion is never filled here — harmless, since every
    -- render path already just orders by display_order, and
    -- reorder_venue_photos fully renumbers 0..n-1 on its own next call
    -- regardless of what the values were before.
    if v_sub.venue_type = 'restaurant' then
      select coalesce(max(rp.display_order) + 1, 0) into v_display_order
        from public.restaurant_photos rp where rp.restaurant_id = v_sub.venue_id;
    elsif v_sub.venue_type = 'hotel' then
      select coalesce(max(hp.display_order) + 1, 0) into v_display_order
        from public.hotel_photos hp where hp.hotel_id = v_sub.venue_id;
    else
      select coalesce(max(pcp.display_order) + 1, 0) into v_display_order
        from public.private_chef_photos pcp where pcp.private_chef_id = v_sub.venue_id;
    end if;
  end if;

  -- alt_text/focus_x/focus_y are deliberately left at the published
  -- table's own defaults (null / 0.5 / 0.5): the submission carries none
  -- of these today. Known, reported, not this task's problem to solve.
  if v_sub.venue_type = 'restaurant' then
    insert into public.restaurant_photos (restaurant_id, image_url, display_order)
      values (v_sub.venue_id, p_image_url, v_display_order)
      returning id into v_new_id;
  elsif v_sub.venue_type = 'hotel' then
    insert into public.hotel_photos (hotel_id, image_url, display_order)
      values (v_sub.venue_id, p_image_url, v_display_order)
      returning id into v_new_id;
  else
    insert into public.private_chef_photos (private_chef_id, image_url, display_order)
      values (v_sub.venue_id, p_image_url, v_display_order)
      returning id into v_new_id;
  end if;

  update public.venue_photo_submissions
    set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by
    where id = p_submission_id;

  return query select v_new_id, p_image_url, v_display_order, p_submission_id;
end;
$$;

create function public.reject_venue_photo(p_submission_id uuid, p_reviewed_by uuid, p_review_note text)
returns public.venue_photo_submissions
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_result public.venue_photo_submissions;
begin
  -- No auth.uid() check — see approve_venue_claim's own comment.

  if p_reviewed_by is null or not exists (select 1 from public.profiles p where p.id = p_reviewed_by) then
    raise exception 'p_reviewed_by must be a real profiles.id, got %', p_reviewed_by;
  end if;

  update public.venue_photo_submissions
    set status = 'rejected', reviewed_at = now(), reviewed_by = p_reviewed_by, review_note = p_review_note
    where id = p_submission_id and status = 'pending'
    returning * into v_result;

  if v_result.id is null then
    raise exception 'venue_photo_submissions % is not pending (or does not exist)', p_submission_id;
  end if;
  return v_result;
end;
$$;

-- ============================================================
-- 4. Grants — see this migration's own header for why this is
--    "from public, anon, authenticated", one role wider than the
--    standing CLAUDE.md pattern.
-- ============================================================

revoke execute on function public.approve_venue_claim(text, uuid, uuid) from public, anon, authenticated;
revoke execute on function public.reject_venue_claim(text, uuid, uuid, text) from public, anon, authenticated;
revoke execute on function public.approve_venue_about(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.reject_venue_about(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function public.approve_venue_photo(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function public.reject_venue_photo(uuid, uuid, text) from public, anon, authenticated;

commit;
