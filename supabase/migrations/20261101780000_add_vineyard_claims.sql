-- Claiming a wine estate: vineyards become the fourth kind of venue a
-- member can claim and manage, after restaurants, hotels and private
-- chefs. Written 2026-11-25 on branch claude/venue-claim-onboarding.
-- Product owner, 2026-11-25: "Ja laten we dat claimen van wijngaarden
-- bouwen" (canvas https://claude.ai/artifact/TiM3WfXrgJDc3uZWkxffTT,
-- boards 7 and 8). The number is sort order, not a date: named after the
-- highest migration on any branch (20261101770000, prepared on
-- claude/vineyards-global).
--
-- PREPARED -- NOT APPLIED until the product owner approves.
--
-- This is the first release of it: the claim, the estate's own text and
-- photos, its website, followers and its invite link. Visits, opening
-- hours and estates hosting events come in a later migration; until then
-- event_vineyards keeps its participant-only check, untouched here.
--
-- Shaped exactly like the private chef tables, the closest precedent:
--   claims_vineyards          like claims_private_chefs (final shape,
--                             with role, business details, review note,
--                             'blocked', one pending claim per estate)
--   venue_managers_vineyards  like venue_managers_private_chefs: the
--                             single source of permission, active while
--                             revoked_at is null
--   vineyard_photos           like private_chef_photos (framing, card
--                             photo, max five, manager reorder only)
--   follows_vineyards         like follows_private_chefs
-- The claim triggers reuse the existing generic functions
-- (notify_admin_of_pending_venue_claim, notify_venue_claim_change,
-- notify_host_of_approved_venue_claim). The admin and welcome emails need
-- the notify-venue-claim and notify-venue-submission Edge Functions to
-- know claims_vineyards and 'vineyard'; that change is in the same
-- commit and deploys separately.
--
-- 'vineyard' is added to the venue_type checks the manager paths write
-- (about texts, photo submissions, contact edits, invite links), and the
-- functions that branch per type learn a vineyard branch. Every function
-- below is redefined from its current definition, read from a stack with
-- all earlier migrations replayed, with only the vineyard branch added.
-- CREATE OR REPLACE keeps each function's existing grants and revokes.
--
-- vineyards_full is deliberately NOT touched: claude/vineyards-global
-- (20261101770000) redefines it, and two branches redefining one view
-- would replay in an order that drops a column. The app reads an estate's
-- photos from vineyard_photos and its text from venue_about_current.
--
-- Facts stay ours: name, region, location and the World's 50 Best rank
-- are never editable by a manager. Only website_url is, through
-- set_venue_contact, which logs each change in venue_contact_edits. An
-- estate has no phone column yet, so set_venue_contact refuses a phone
-- for it, the way it does for a private chef.
--
-- Shipped builds: every change is additive. Builds without vineyard
-- claiming never write 'vineyard', never read the new tables, and the
-- functions behave exactly as before for the three existing types.

-- ── Claims ──────────────────────────────────────────────────────────────

create table public.claims_vineyards (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  vineyard_id    uuid not null references public.vineyards(id) on delete cascade,
  status         text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'blocked')),
  requested_at   timestamptz not null default now(),
  reviewed_at    timestamptz,
  reviewed_by    uuid references public.profiles(id) on delete set null,
  role           text not null check (role in ('owner', 'manager', 'chef', 'other')),
  business_email text not null,
  phone          text not null,
  notes          text,
  review_note    text
);

create unique index claims_vineyards_active_uidx
  on public.claims_vineyards (user_id, vineyard_id)
  where status in ('pending', 'approved', 'blocked');
create unique index claims_vineyards_one_pending_per_venue_uidx
  on public.claims_vineyards (vineyard_id)
  where status = 'pending';
create index claims_vineyards_vineyard_idx on public.claims_vineyards (vineyard_id);

alter table public.claims_vineyards enable row level security;

create policy claims_vineyards_own_read on public.claims_vineyards
  for select to authenticated using (user_id = auth.uid());
create policy claims_vineyards_insert on public.claims_vineyards
  for insert to authenticated
  with check (
    user_id = auth.uid() and status = 'pending'
    and reviewed_at is null and reviewed_by is null and review_note is null
  );

revoke all on table public.claims_vineyards from public, anon;
grant select, insert on table public.claims_vineyards to authenticated;
grant all on table public.claims_vineyards to service_role;

create trigger claims_vineyards_notify_admin_on_insert
  after insert on public.claims_vineyards
  for each row execute function public.notify_admin_of_pending_venue_claim();
create trigger claims_vineyards_notify_on_change
  after insert or update on public.claims_vineyards
  for each row execute function public.notify_venue_claim_change();
create trigger claims_vineyards_welcome_host_on_approval
  after update of status on public.claims_vineyards
  for each row execute function public.notify_host_of_approved_venue_claim();

-- ── Managers: the permission ────────────────────────────────────────────

create table public.venue_managers_vineyards (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  vineyard_id    uuid not null references public.vineyards(id) on delete cascade,
  claim_id       uuid not null references public.claims_vineyards(id) on delete restrict,
  granted_at     timestamptz not null default now(),
  granted_by     uuid references public.profiles(id) on delete set null,
  revoked_at     timestamptz,
  revoked_by     uuid references public.profiles(id) on delete set null,
  revoked_reason text,
  constraint venue_managers_vineyards_reason_iff_revoked
    check (revoked_at is null or revoked_reason is not null),
  constraint venue_managers_vineyards_revoked_by_iff_revoked
    check ((revoked_at is null) = (revoked_by is null))
);

create unique index venue_managers_vineyards_active_uidx
  on public.venue_managers_vineyards (user_id, vineyard_id)
  where revoked_at is null;
create index venue_managers_vineyards_vineyard_idx
  on public.venue_managers_vineyards (vineyard_id);

alter table public.venue_managers_vineyards enable row level security;

create policy venue_managers_vineyards_own_read on public.venue_managers_vineyards
  for select to authenticated using (user_id = auth.uid());

revoke all on table public.venue_managers_vineyards from public, anon;
grant select on table public.venue_managers_vineyards to authenticated;
grant all on table public.venue_managers_vineyards to service_role;

-- ── Published photos ────────────────────────────────────────────────────

create table public.vineyard_photos (
  id            uuid primary key default gen_random_uuid(),
  vineyard_id   uuid not null references public.vineyards(id) on delete cascade,
  image_url     text not null,
  alt_text      text,
  display_order smallint not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  focus_x       numeric not null default 0.5 check (focus_x between 0 and 1),
  focus_y       numeric not null default 0.5 check (focus_y between 0 and 1),
  zoom          numeric not null default 1 check (zoom between 1 and 4),
  is_card       boolean not null default false,
  card_focus_x  numeric not null default 0.5 check (card_focus_x between 0 and 1),
  card_focus_y  numeric not null default 0.5 check (card_focus_y between 0 and 1),
  card_zoom     numeric not null default 1 check (card_zoom between 1 and 4),
  constraint vineyard_photos_display_order_unique unique (vineyard_id, display_order)
);

create index vineyard_photos_vineyard_idx on public.vineyard_photos (vineyard_id);
create unique index vineyard_photos_one_card_uidx
  on public.vineyard_photos (vineyard_id) where is_card;

alter table public.vineyard_photos enable row level security;

-- Estates are public catalogue rows (vineyards_public_read), so their
-- published photos are too.
create policy vineyard_photos_public_read on public.vineyard_photos
  for select to anon, authenticated using (true);
-- Direct reorder only; the trigger below refuses every other column.
create policy vineyard_photos_manager_reorder on public.vineyard_photos
  for update to authenticated
  using (public.is_active_venue_manager('vineyard', vineyard_id))
  with check (public.is_active_venue_manager('vineyard', vineyard_id));

revoke all on table public.vineyard_photos from public, anon;
grant select on table public.vineyard_photos to anon;
grant select, update on table public.vineyard_photos to authenticated;
grant all on table public.vineyard_photos to service_role;

create function public.enforce_vineyard_photo_limit()
returns trigger
language plpgsql
as $$
begin
  if (
    select count(*) from public.vineyard_photos
    where vineyard_id = new.vineyard_id
  ) >= 5 then
    raise exception
      'vineyard_photos: estate % already has the maximum of 5 photos',
      new.vineyard_id;
  end if;
  return new;
end;
$$;
-- A trigger function, not SECURITY DEFINER; revoked anyway, per the
-- project rule for every new function.
revoke execute on function public.enforce_vineyard_photo_limit() from public, anon;

create trigger vineyard_photos_max_five
  before insert on public.vineyard_photos
  for each row execute function public.enforce_vineyard_photo_limit();
create trigger vineyard_photos_manager_reorder_only
  before update on public.vineyard_photos
  for each row execute function public.enforce_manager_photo_reorder_only();
create trigger vineyard_photos_updated_at
  before update on public.vineyard_photos
  for each row execute function public.set_updated_at();

-- ── Following an estate ─────────────────────────────────────────────────

create table public.follows_vineyards (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  vineyard_id uuid not null references public.vineyards(id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint follows_vineyards_user_id_vineyard_id_key unique (user_id, vineyard_id)
);

create index follows_vineyards_vineyard_idx on public.follows_vineyards (vineyard_id);

alter table public.follows_vineyards enable row level security;

create policy follows_vineyards_select on public.follows_vineyards
  for select to authenticated using (user_id = auth.uid());
create policy follows_vineyards_insert on public.follows_vineyards
  for insert to authenticated with check (user_id = auth.uid());
create policy follows_vineyards_delete on public.follows_vineyards
  for delete to authenticated using (user_id = auth.uid());

revoke all on table public.follows_vineyards from public, anon;
grant select, insert, delete on table public.follows_vineyards to authenticated;
grant all on table public.follows_vineyards to service_role;

-- ── 'vineyard' on the manager paths' type checks ────────────────────────

alter table public.venue_about_submissions
  drop constraint venue_about_submissions_venue_type_check,
  add constraint venue_about_submissions_venue_type_check
    check (venue_type in ('restaurant', 'hotel', 'private_chef', 'vineyard'));
alter table public.venue_photo_submissions
  drop constraint venue_photo_submissions_venue_type_check,
  add constraint venue_photo_submissions_venue_type_check
    check (venue_type in ('restaurant', 'hotel', 'private_chef', 'vineyard'));
alter table public.venue_contact_edits
  drop constraint venue_contact_edits_venue_type_check,
  add constraint venue_contact_edits_venue_type_check
    check (venue_type in ('restaurant', 'hotel', 'private_chef', 'vineyard'));
alter table public.invite_links
  drop constraint invite_links_venue_type_check,
  add constraint invite_links_venue_type_check
    check (venue_type in ('restaurant', 'hotel', 'private_chef', 'vineyard'));

-- ── Functions that branch per venue type ────────────────────────────────
-- Each is its current definition with a vineyard branch added; nothing
-- else in them changes.

CREATE OR REPLACE FUNCTION public.is_active_venue_manager(p_venue_type text, p_venue_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.venue_managers_restaurants m
    where p_venue_type = 'restaurant'
      and m.restaurant_id = p_venue_id
      and m.user_id = auth.uid()
      and m.revoked_at is null
    union all
    select 1 from public.venue_managers_hotels m
    where p_venue_type = 'hotel'
      and m.hotel_id = p_venue_id
      and m.user_id = auth.uid()
      and m.revoked_at is null
    union all
    select 1 from public.venue_managers_private_chefs m
    where p_venue_type = 'private_chef'
      and m.private_chef_id = p_venue_id
      and m.user_id = auth.uid()
      and m.revoked_at is null
    union all
    select 1 from public.venue_managers_vineyards m
    where p_venue_type = 'vineyard'
      and m.vineyard_id = p_venue_id
      and m.user_id = auth.uid()
      and m.revoked_at is null
  );
$function$;

CREATE OR REPLACE FUNCTION public.approve_venue_claim(p_venue_type text, p_claim_id uuid, p_reviewed_by uuid)
 RETURNS TABLE(id uuid, status text, reviewed_at timestamp with time zone, reviewed_by uuid, review_note text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  elsif p_venue_type = 'vineyard' then
    select cv.user_id, cv.vineyard_id into v_user_id, v_venue_id
      from public.claims_vineyards cv where cv.id = p_claim_id and cv.status = 'pending' for update;
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
  elsif p_venue_type = 'vineyard' then
    v_active_exists := exists (
      select 1 from public.venue_managers_vineyards vm
      where vm.user_id = v_user_id and vm.vineyard_id = v_venue_id and vm.revoked_at is null
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
  elsif p_venue_type = 'vineyard' then
    update public.claims_vineyards cv
      set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by
      where cv.id = p_claim_id;
    insert into public.venue_managers_vineyards (user_id, vineyard_id, claim_id, granted_at, granted_by)
      values (v_user_id, v_venue_id, p_claim_id, now(), p_reviewed_by);
    return query select cv.id, cv.status, cv.reviewed_at, cv.reviewed_by, cv.review_note
      from public.claims_vineyards cv where cv.id = p_claim_id;
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
$function$;

CREATE OR REPLACE FUNCTION public.reject_venue_claim(p_venue_type text, p_claim_id uuid, p_reviewed_by uuid, p_review_note text)
 RETURNS TABLE(id uuid, status text, reviewed_at timestamp with time zone, reviewed_by uuid, review_note text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  elsif p_venue_type = 'vineyard' then
    update public.claims_vineyards cv
      set status = 'rejected', reviewed_at = now(), reviewed_by = p_reviewed_by, review_note = p_review_note
      where cv.id = p_claim_id and cv.status = 'pending';
    get diagnostics v_row_count = row_count;
    if v_row_count = 0 then
      raise exception 'claim % is not pending (or does not exist) for venue_type vineyard', p_claim_id;
    end if;
    return query select cv.id, cv.status, cv.reviewed_at, cv.reviewed_by, cv.review_note
      from public.claims_vineyards cv where cv.id = p_claim_id;
  else
    raise exception 'Unknown venue_type: %', p_venue_type;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.approve_venue_photo(p_submission_id uuid, p_reviewed_by uuid, p_image_url text)
 RETURNS TABLE(published_id uuid, image_url text, display_order smallint, submission_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_sub public.venue_photo_submissions;
  -- Confirmed 2026-10-05 against a real published row (private_chef_photos)
  -- cross-checked against storage.objects, not assumed from an example.
  v_prefix constant text :=
    'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/';
  v_object_path text;
  v_display_order smallint;
  v_new_id uuid;
  v_was_card boolean := false;
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
        returning rp.display_order, rp.is_card into v_display_order, v_was_card;
    elsif v_sub.venue_type = 'hotel' then
      delete from public.hotel_photos hp
        where hp.id = v_sub.replaces_photo_id and hp.hotel_id = v_sub.venue_id
        returning hp.display_order, hp.is_card into v_display_order, v_was_card;
    elsif v_sub.venue_type = 'vineyard' then
      delete from public.vineyard_photos vp
        where vp.id = v_sub.replaces_photo_id and vp.vineyard_id = v_sub.venue_id
        returning vp.display_order, vp.is_card into v_display_order, v_was_card;
    else
      delete from public.private_chef_photos pcp
        where pcp.id = v_sub.replaces_photo_id and pcp.private_chef_id = v_sub.venue_id
        returning pcp.display_order, pcp.is_card into v_display_order, v_was_card;
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
    elsif v_sub.venue_type = 'vineyard' then
      select coalesce(max(vp.display_order) + 1, 0) into v_display_order
        from public.vineyard_photos vp where vp.vineyard_id = v_sub.venue_id;
    else
      select coalesce(max(pcp.display_order) + 1, 0) into v_display_order
        from public.private_chef_photos pcp where pcp.private_chef_id = v_sub.venue_id;
    end if;
  end if;

  -- The framing the manager chose at upload (focus_x/focus_y/zoom,
  -- 20261014120000) is carried onto the published row. alt_text stays
  -- at the published table's own default (null): the submission still
  -- carries none. A replacement for the venue's chosen card photo stays
  -- the card photo (is_card, 20261015120000); its card framing starts
  -- centred, since the old crop was for a different image.
  if v_sub.venue_type = 'restaurant' then
    insert into public.restaurant_photos (restaurant_id, image_url, display_order, focus_x, focus_y, zoom, is_card)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom, coalesce(v_was_card, false))
      returning id into v_new_id;
  elsif v_sub.venue_type = 'hotel' then
    insert into public.hotel_photos (hotel_id, image_url, display_order, focus_x, focus_y, zoom, is_card)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom, coalesce(v_was_card, false))
      returning id into v_new_id;
  elsif v_sub.venue_type = 'vineyard' then
    insert into public.vineyard_photos (vineyard_id, image_url, display_order, focus_x, focus_y, zoom, is_card)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom, coalesce(v_was_card, false))
      returning id into v_new_id;
  else
    insert into public.private_chef_photos (private_chef_id, image_url, display_order, focus_x, focus_y, zoom, is_card)
      values (v_sub.venue_id, p_image_url, v_display_order, v_sub.focus_x, v_sub.focus_y, v_sub.zoom, coalesce(v_was_card, false))
      returning id into v_new_id;
  end if;

  update public.venue_photo_submissions
    set status = 'approved', reviewed_at = now(), reviewed_by = p_reviewed_by
    where id = p_submission_id;

  return query select v_new_id, p_image_url, v_display_order, p_submission_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.enforce_photo_submission_replacement()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  published_count integer;
begin
  if new.venue_type = 'restaurant' then
    select count(*) into published_count from public.restaurant_photos
    where restaurant_id = new.venue_id;
  elsif new.venue_type = 'hotel' then
    select count(*) into published_count from public.hotel_photos
    where hotel_id = new.venue_id;
  elsif new.venue_type = 'vineyard' then
    select count(*) into published_count from public.vineyard_photos
    where vineyard_id = new.venue_id;
  else
    select count(*) into published_count from public.private_chef_photos
    where private_chef_id = new.venue_id;
  end if;

  if published_count >= 5 and new.replaces_photo_id is null then
    raise exception
      'venue_photo_submissions: venue % (%) already has % published photos — a submission at the cap must set replaces_photo_id',
      new.venue_id, new.venue_type, published_count;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.reorder_venue_photos(p_venue_type text, p_venue_id uuid, p_photo_ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_expected_count integer;
  v_photo_id uuid;
  v_idx integer;
  v_row_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef', 'vineyard') then
    raise exception 'Unknown venue_type: %', p_venue_type;
  end if;
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Not an active manager of this venue';
  end if;
  if p_photo_ids is null or array_length(p_photo_ids, 1) is null then
    raise exception 'p_photo_ids must not be empty';
  end if;
  if array_length(p_photo_ids, 1)
      <> (select count(*) from (select distinct unnest(p_photo_ids)) d)
  then
    raise exception 'p_photo_ids contains a duplicate id';
  end if;

  v_expected_count := case p_venue_type
    when 'restaurant' then
      (select count(*) from public.restaurant_photos where restaurant_id = p_venue_id)
    when 'hotel' then
      (select count(*) from public.hotel_photos where hotel_id = p_venue_id)
    when 'vineyard' then
      (select count(*) from public.vineyard_photos where vineyard_id = p_venue_id)
    else
      (select count(*) from public.private_chef_photos where private_chef_id = p_venue_id)
  end;

  if array_length(p_photo_ids, 1) <> v_expected_count then
    raise exception
      'p_photo_ids must name exactly this venue''s % published photo(s) — got %',
      v_expected_count, array_length(p_photo_ids, 1);
  end if;

  -- Phase 1: move every named photo to a negative, per-position-unique
  -- placeholder. Never collides with a real (>= 0) display_order, and
  -- never collides with another placeholder within this same pass
  -- (each is keyed off its own position in the array) — so the existing
  -- immediate (non-deferrable) unique(venue_id, display_order)
  -- constraint is satisfied after every single statement here.
  v_idx := 0;
  foreach v_photo_id in array p_photo_ids loop
    if p_venue_type = 'restaurant' then
      update public.restaurant_photos set display_order = -1 - v_idx
        where id = v_photo_id and restaurant_id = p_venue_id;
    elsif p_venue_type = 'hotel' then
      update public.hotel_photos set display_order = -1 - v_idx
        where id = v_photo_id and hotel_id = p_venue_id;
    elsif p_venue_type = 'vineyard' then
      update public.vineyard_photos set display_order = -1 - v_idx
        where id = v_photo_id and vineyard_id = p_venue_id;
    else
      update public.private_chef_photos set display_order = -1 - v_idx
        where id = v_photo_id and private_chef_id = p_venue_id;
    end if;
    get diagnostics v_row_count = row_count;
    if v_row_count <> 1 then
      raise exception 'photo % is not one of this venue''s own photos', v_photo_id;
    end if;
    v_idx := v_idx + 1;
  end loop;

  -- Phase 2: assign the real, final 0-based positions in exactly the
  -- order the caller supplied. Every id in p_photo_ids was already
  -- proven (phase 1) to belong to p_venue_id, so no venue-scoping
  -- predicate is needed again here.
  v_idx := 0;
  foreach v_photo_id in array p_photo_ids loop
    if p_venue_type = 'restaurant' then
      update public.restaurant_photos set display_order = v_idx where id = v_photo_id;
    elsif p_venue_type = 'hotel' then
      update public.hotel_photos set display_order = v_idx where id = v_photo_id;
    elsif p_venue_type = 'vineyard' then
      update public.vineyard_photos set display_order = v_idx where id = v_photo_id;
    else
      update public.private_chef_photos set display_order = v_idx where id = v_photo_id;
    end if;
    v_idx := v_idx + 1;
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_venue_photo_framing(p_venue_type text, p_photo_id uuid, p_focus_x numeric, p_focus_y numeric, p_zoom numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_venue_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef', 'vineyard') then
    raise exception 'Unknown venue_type: %', p_venue_type;
  end if;
  if p_focus_x is null or p_focus_y is null or p_zoom is null
    or p_focus_x not between 0 and 1
    or p_focus_y not between 0 and 1
    or p_zoom not between 1 and 4
  then
    raise exception 'Framing out of range: focus 0..1, zoom 1..4';
  end if;

  v_venue_id := case p_venue_type
    when 'restaurant' then
      (select rp.restaurant_id from public.restaurant_photos rp where rp.id = p_photo_id)
    when 'hotel' then
      (select hp.hotel_id from public.hotel_photos hp where hp.id = p_photo_id)
    when 'vineyard' then
      (select vp.vineyard_id from public.vineyard_photos vp where vp.id = p_photo_id)
    else
      (select pcp.private_chef_id from public.private_chef_photos pcp where pcp.id = p_photo_id)
  end;
  if v_venue_id is null then
    raise exception 'No % photo %', p_venue_type, p_photo_id;
  end if;
  if not public.is_active_venue_manager(p_venue_type, v_venue_id) then
    raise exception 'Not an active manager of this venue';
  end if;

  if p_venue_type = 'restaurant' then
    update public.restaurant_photos
      set focus_x = p_focus_x, focus_y = p_focus_y, zoom = p_zoom
      where id = p_photo_id;
  elsif p_venue_type = 'hotel' then
    update public.hotel_photos
      set focus_x = p_focus_x, focus_y = p_focus_y, zoom = p_zoom
      where id = p_photo_id;
  elsif p_venue_type = 'vineyard' then
    update public.vineyard_photos
      set focus_x = p_focus_x, focus_y = p_focus_y, zoom = p_zoom
      where id = p_photo_id;
  else
    update public.private_chef_photos
      set focus_x = p_focus_x, focus_y = p_focus_y, zoom = p_zoom
      where id = p_photo_id;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_venue_card_photo(p_venue_type text, p_venue_id uuid, p_photo_id uuid, p_focus_x numeric, p_focus_y numeric, p_zoom numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef', 'vineyard') then
    raise exception 'Unknown venue_type: %', p_venue_type;
  end if;
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Not an active manager of this venue';
  end if;
  if p_photo_id is not null and (
    p_focus_x is null or p_focus_y is null or p_zoom is null
    or p_focus_x not between 0 and 1
    or p_focus_y not between 0 and 1
    or p_zoom not between 1 and 4
  ) then
    raise exception 'Framing out of range: focus 0..1, zoom 1..4';
  end if;

  -- Clear the current card photo first (the partial unique index allows
  -- one flag per venue), then flag the chosen one — or none, which means
  -- the cover again.
  if p_venue_type = 'restaurant' then
    update public.restaurant_photos set is_card = false
      where restaurant_id = p_venue_id and is_card;
    if p_photo_id is not null then
      update public.restaurant_photos
        set is_card = true, card_focus_x = p_focus_x, card_focus_y = p_focus_y, card_zoom = p_zoom
        where id = p_photo_id and restaurant_id = p_venue_id;
      get diagnostics v_row_count = row_count;
    end if;
  elsif p_venue_type = 'hotel' then
    update public.hotel_photos set is_card = false
      where hotel_id = p_venue_id and is_card;
    if p_photo_id is not null then
      update public.hotel_photos
        set is_card = true, card_focus_x = p_focus_x, card_focus_y = p_focus_y, card_zoom = p_zoom
        where id = p_photo_id and hotel_id = p_venue_id;
      get diagnostics v_row_count = row_count;
    end if;
  elsif p_venue_type = 'vineyard' then
    update public.vineyard_photos set is_card = false
      where vineyard_id = p_venue_id and is_card;
    if p_photo_id is not null then
      update public.vineyard_photos
        set is_card = true, card_focus_x = p_focus_x, card_focus_y = p_focus_y, card_zoom = p_zoom
        where id = p_photo_id and vineyard_id = p_venue_id;
      get diagnostics v_row_count = row_count;
    end if;
  else
    update public.private_chef_photos set is_card = false
      where private_chef_id = p_venue_id and is_card;
    if p_photo_id is not null then
      update public.private_chef_photos
        set is_card = true, card_focus_x = p_focus_x, card_focus_y = p_focus_y, card_zoom = p_zoom
        where id = p_photo_id and private_chef_id = p_venue_id;
      get diagnostics v_row_count = row_count;
    end if;
  end if;

  if p_photo_id is not null and v_row_count <> 1 then
    raise exception 'photo % is not one of this venue''s own photos', p_photo_id;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_venue_contact(p_venue_type text, p_venue_id uuid, p_website text, p_phone text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_website text := nullif(btrim(p_website), '');
  v_phone text := nullif(btrim(p_phone), '');
  v_old_website text;
  v_old_phone text;
begin
  if p_venue_type not in ('restaurant', 'hotel', 'private_chef', 'vineyard') then
    raise exception 'Unknown venue type %', p_venue_type;
  end if;
  if not public.is_active_venue_manager(p_venue_type, p_venue_id) then
    raise exception 'Not a manager of this venue';
  end if;

  if v_website is not null and (
       char_length(v_website) > 500
       or v_website !~* '^https?://[^\s/?#]+\.[^\s/?#]{2,}([/?#]\S*)?$'
     ) then
    raise exception 'The website must be a full address, like https://www.yourvenue.com';
  end if;
  if v_phone is not null and (
       char_length(v_phone) > 30
       or v_phone !~ '^\+?[0-9 ()./-]+$'
       or char_length(regexp_replace(v_phone, '[^0-9]', '', 'g')) < 6
     ) then
    raise exception 'The phone number may hold digits, spaces and + ( ) . / - only, with at least six digits';
  end if;
  if p_venue_type = 'private_chef' and v_phone is not null then
    raise exception 'A private chef page has no phone number';
  end if;
  if p_venue_type = 'vineyard' and v_phone is not null then
    raise exception 'An estate page has no phone number yet';
  end if;

  if p_venue_type = 'restaurant' then
    select website_url, phone into v_old_website, v_old_phone
      from public.restaurants where id = p_venue_id for update;
    update public.restaurants
       set website_url = v_website, phone = v_phone
     where id = p_venue_id
       and (website_url is distinct from v_website or phone is distinct from v_phone);
  elsif p_venue_type = 'hotel' then
    select website_url, phone into v_old_website, v_old_phone
      from public.hotels where id = p_venue_id for update;
    update public.hotels
       set website_url = v_website, phone = v_phone
     where id = p_venue_id
       and (website_url is distinct from v_website or phone is distinct from v_phone);
  elsif p_venue_type = 'vineyard' then
    select website_url into v_old_website
      from public.vineyards where id = p_venue_id for update;
    update public.vineyards
       set website_url = v_website
     where id = p_venue_id and website_url is distinct from v_website;
  else
    select website_url into v_old_website
      from public.private_chefs where id = p_venue_id for update;
    update public.private_chefs
       set website_url = v_website
     where id = p_venue_id and website_url is distinct from v_website;
  end if;

  if v_old_website is distinct from v_website then
    insert into public.venue_contact_edits (venue_type, venue_id, field, old_value, new_value, edited_by)
    values (p_venue_type, p_venue_id, 'website', v_old_website, v_website, auth.uid());
  end if;
  if p_venue_type not in ('private_chef', 'vineyard') and v_old_phone is distinct from v_phone then
    insert into public.venue_contact_edits (venue_type, venue_id, field, old_value, new_value, edited_by)
    values (p_venue_type, p_venue_id, 'phone', v_old_phone, v_phone, auth.uid());
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.invite_link_venue_exists(p_venue_type text, p_venue_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case p_venue_type
    when 'restaurant' then exists (select 1 from public.restaurants r where r.id = p_venue_id)
    when 'hotel' then exists (select 1 from public.hotels h where h.id = p_venue_id)
    when 'private_chef' then exists (
      select 1 from public.private_chefs c
      where c.id = p_venue_id and c.publication_status = 'published'
    )
    when 'vineyard' then exists (select 1 from public.vineyards v where v.id = p_venue_id)
    else false
  end;
$function$;

CREATE OR REPLACE FUNCTION public.invite_link_venue_followed_by(p_venue_type text, p_venue_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case p_venue_type
    when 'restaurant' then exists (
      select 1 from public.follows_restaurants f
      where f.restaurant_id = p_venue_id and f.user_id = p_user_id)
    when 'hotel' then exists (
      select 1 from public.follows_hotels f
      where f.hotel_id = p_venue_id and f.user_id = p_user_id)
    when 'private_chef' then exists (
      select 1 from public.follows_private_chefs f
      where f.private_chef_id = p_venue_id and f.user_id = p_user_id)
    when 'vineyard' then exists (
      select 1 from public.follows_vineyards f
      where f.vineyard_id = p_venue_id and f.user_id = p_user_id)
    else false
  end;
$function$;

CREATE OR REPLACE FUNCTION public.invite_link_venue_follow(p_venue_type text, p_venue_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_venue_type = 'restaurant' then
    insert into public.follows_restaurants (user_id, restaurant_id)
    values (p_user_id, p_venue_id) on conflict do nothing;
  elsif p_venue_type = 'hotel' then
    insert into public.follows_hotels (user_id, hotel_id)
    values (p_user_id, p_venue_id) on conflict do nothing;
  elsif p_venue_type = 'private_chef' then
    insert into public.follows_private_chefs (user_id, private_chef_id)
    values (p_user_id, p_venue_id) on conflict do nothing;
  elsif p_venue_type = 'vineyard' then
    insert into public.follows_vineyards (user_id, vineyard_id)
    values (p_user_id, p_venue_id) on conflict do nothing;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.invite_link_venue_summary(p_venue_type text, p_venue_id uuid)
 RETURNS TABLE(venue_name text, venue_city text, venue_country text, michelin_stars smallint, michelin_keys smallint, card_photo_url text, card_focus_x numeric, card_focus_y numeric, card_zoom numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select r.name, c.name, co.name, r.michelin_stars::smallint, null::smallint,
         r.card_photo_url, r.card_focus_x, r.card_focus_y, r.card_zoom
    from public.restaurants_full r
    left join public.cities c on c.id = r.city_id
    left join public.countries co on co.country_code = c.country_code
   where p_venue_type = 'restaurant' and r.id = p_venue_id
  union all
  select h.name, c.name, co.name, null::smallint, h.michelin_keys::smallint,
         h.card_photo_url, h.card_focus_x, h.card_focus_y, h.card_zoom
    from public.hotels_full h
    left join public.cities c on c.id = h.city_id
    left join public.countries co on co.country_code = c.country_code
   where p_venue_type = 'hotel' and h.id = p_venue_id
  union all
  select coalesce(nullif(trim(pc.business_name), ''), pc.display_name),
         pc.home_city, co.name, null::smallint, null::smallint,
         ph.image_url, ph.card_focus_x, ph.card_focus_y, ph.card_zoom
    from public.private_chefs pc
    left join public.countries co on co.country_code = pc.home_country_code
    left join lateral (
      select p.image_url, p.card_focus_x, p.card_focus_y, p.card_zoom
        from public.private_chef_photos p
       where p.private_chef_id = pc.id
       order by p.is_card desc, p.display_order
       limit 1
    ) ph on true
   where p_venue_type = 'private_chef' and pc.id = p_venue_id
     and pc.publication_status = 'published'
  union all
  select v.name, v.city, co.name, null::smallint, null::smallint,
         vp.image_url, vp.card_focus_x, vp.card_focus_y, vp.card_zoom
    from public.vineyards v
    left join public.countries co on co.country_code = v.country_code
    left join lateral (
      select p.image_url, p.card_focus_x, p.card_focus_y, p.card_zoom
        from public.vineyard_photos p
       where p.vineyard_id = v.id
       order by p.is_card desc, p.display_order
       limit 1
    ) vp on true
   where p_venue_type = 'vineyard' and v.id = p_venue_id;
$function$;

CREATE OR REPLACE FUNCTION public.get_review_queue()
 RETURNS TABLE(kind text, item_id uuid, venue_type text, venue_id uuid, venue_name text, venue_city text, submitted_by uuid, submitter_label text, submitted_at timestamp with time zone, claim_role text, claim_business_email text, claim_phone text, claim_notes text, about_text text, photo_storage_path text, photo_replaces_photo_id uuid, photo_duplicate_of uuid, photo_focus_x numeric, photo_focus_y numeric, photo_zoom numeric, event_id uuid, event_name text, event_start_date date, event_changes jsonb, team_role text, team_name text, team_bio text, team_photo_path text, team_remove_photo boolean, instagram_handle text, contact_field text, contact_old_value text, contact_new_value text, report_content_type text, report_content_id uuid, report_reason text, report_details text, missing_subject_type text, missing_name text, missing_city text, missing_message text, missing_works_here boolean, missing_reporter_role text, missing_reporter_contact text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then
    raise exception 'Not an admin';
  end if;
  return query
  with items as (
    select 'venue_claim'::text as kind, c.id as item_id, 'restaurant'::text as venue_type,
           c.restaurant_id as venue_id, c.user_id, c.requested_at as at,
           c.role, c.business_email, c.phone, c.notes,
           null::text as about_text, null::text as storage_path, null::uuid as replaces,
           null::uuid as dup, null::numeric as fx, null::numeric as fy, null::numeric as z,
           null::uuid as ev_id, null::jsonb as changes,
           null::text as t_role, null::text as t_name, null::text as t_bio,
           null::text as t_photo, null::boolean as t_remove_photo, null::text as ig_handle,
           null::text as c_field, null::text as c_old, null::text as c_new,
           null::text as r_type, null::uuid as r_id, null::text as r_reason, null::text as r_details,
           null::text as m_type, null::text as m_name, null::text as m_city, null::text as m_message,
           null::boolean as m_works_here, null::text as m_role, null::text as m_contact
      from public.claims_restaurants c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'hotel', c.hotel_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.claims_hotels c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'private_chef', c.private_chef_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.claims_private_chefs c where c.status = 'pending'
    union all
    select 'venue_claim', c.id, 'vineyard', c.vineyard_id, c.user_id, c.requested_at,
           c.role, c.business_email, c.phone, c.notes,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.claims_vineyards c where c.status = 'pending'
    union all
    select 'venue_about', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           s.about_text, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_about_submissions s where s.status = 'pending'
    union all
    select 'venue_photo', s.id, s.venue_type, s.venue_id, s.user_id, s.submitted_at,
           null, null, null, null,
           null, s.storage_path, s.replaces_photo_id, s.duplicate_of_submission_id,
           s.focus_x, s.focus_y, s.zoom, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_photo_submissions s where s.status = 'pending'
    union all
    select 'venue_event', e.id, h.venue_type, h.venue_id, e.submitted_by,
           coalesce(e.submitted_at, e.created_at),
           null, null, null, null,
           null, null, null, null, null, null, null, e.id, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.events e
      left join lateral public.event_host_venue(e.id) h on true
     where e.moderation_status = 'submitted' and e.cancelled_at is null
    union all
    select 'venue_event_edit', x.id, h.venue_type, h.venue_id, x.edited_by, x.edited_at,
           null, null, null, null,
           null, null, null, null, null, null, null, x.event_id, x.changes,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.event_edits x
      left join lateral public.event_host_venue(x.event_id) h on true
     where x.seen_at is null
    union all
    select 'venue_team', t.id, t.venue_type, t.venue_id, t.user_id, t.submitted_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           t.role, t.name, t.bio, t.photo_path, t.remove_photo, null,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_team_submissions t
     where t.status = 'pending' and t.removed_at is null
    union all
    select 'venue_instagram', g.id, g.venue_type, g.venue_id, g.user_id, g.submitted_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, g.handle,
           null, null, null, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_instagram_submissions g
     where g.status = 'pending' and g.removed_at is null
    union all
    select 'venue_contact_edit', k.id, k.venue_type, k.venue_id, k.edited_by, k.edited_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           k.field, k.old_value, k.new_value, null, null, null, null,
           null, null, null, null, null, null, null
      from public.venue_contact_edits k
     where k.seen_at is null
    union all
    -- The venue a reported event is hosted by, so the queue row names it.
    select 'content_report', cr.id,
           case when cr.content_type = 'event' then h.venue_type end,
           case when cr.content_type = 'event' then h.venue_id end,
           cr.reporter_id, cr.created_at,
           null, null, null, null,
           null, null, null, null, null, null, null,
           case when cr.content_type = 'event' then cr.content_id end, null,
           null, null, null, null, null, null,
           null, null, null, cr.content_type, cr.content_id, cr.reason, cr.details,
           null, null, null, null, null, null, null
      from public.content_reports cr
      left join lateral (
        select hv.venue_type, hv.venue_id from public.event_host_venue(cr.content_id) hv
         where cr.content_type = 'event'
      ) h on true
     where cr.status = 'open'
    union all
    select 'missing_listing', m.id, null, null, m.reporter_id, m.created_at,
           null, null, null, null,
           null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null,
           null, null, null, null, null, null, null,
           m.subject_type, m.name, m.city, m.message, m.works_here, m.reporter_role, m.reporter_contact
      from public.missing_listing_reports m
     where m.handled_at is null
       and not exists (select 1 from public.restaurants r where r.missing_listing_report_id = m.id)
       and not exists (select 1 from public.hotels ho where ho.missing_listing_report_id = m.id)
       and not exists (select 1 from public.events ev2 where ev2.missing_listing_report_id = m.id)
  )
  select i.kind, i.item_id, i.venue_type, i.venue_id,
         coalesce(r.name, h.name, pc.display_name, vy.name) as venue_name,
         coalesce(rc.name, hc.name, pc.home_city, vy.city) as venue_city,
         i.user_id,
         coalesce(nullif(trim(p.display_name), ''), '@' || p.username, 'Mantelier member') as submitter_label,
         i.at,
         i.role, i.business_email, i.phone, i.notes,
         i.about_text, i.storage_path, i.replaces, i.dup, i.fx, i.fy, i.z,
         i.ev_id, ev.name, ev.start_date, i.changes,
         i.t_role, i.t_name, i.t_bio, i.t_photo, i.t_remove_photo, i.ig_handle,
         i.c_field, i.c_old, i.c_new,
         i.r_type, i.r_id, i.r_reason, i.r_details,
         i.m_type, i.m_name, i.m_city, i.m_message, i.m_works_here, i.m_role, i.m_contact
    from items i
    left join public.restaurants r on i.venue_type = 'restaurant' and r.id = i.venue_id
    left join public.cities rc on rc.id = r.city_id
    left join public.hotels h on i.venue_type = 'hotel' and h.id = i.venue_id
    left join public.cities hc on hc.id = h.city_id
    left join public.private_chefs pc on i.venue_type = 'private_chef' and pc.id = i.venue_id
    left join public.vineyards vy on i.venue_type = 'vineyard' and vy.id = i.venue_id
    left join public.profiles p on p.id = i.user_id
    left join public.events ev on ev.id = i.ev_id
   order by i.at;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_notifications_v6_rows()
 RETURNS TABLE(id uuid, type text, subject_type text, subject_id uuid, is_read boolean, created_at timestamp with time zone, other_user_id uuid, other_username text, other_display_name text, other_avatar_url text, listing_subject_type text, listing_name text, listing_city text, invite_venue_type text, invite_venue_id uuid, invite_venue_name text, invite_venue_city text, invite_note text, invite_status text, invite_expires_at timestamp with time zone, claim_venue_type text, claim_venue_id uuid, claim_venue_name text, claim_venue_city text, claim_review_note text, submission_venue_type text, submission_venue_id uuid, submission_venue_name text, submission_venue_city text, submission_review_note text, friendship_status text, event_name text, event_start_date date, event_review_note text, event_venue_type text, event_venue_id uuid, event_venue_name text, trip_id uuid, trip_title text, trip_start_date date, trip_end_date date, trip_member_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    n.id,
    n.type,
    n.subject_type,
    n.subject_id,
    n.is_read,
    n.created_at,
    coalesce(
      case when n.subject_type = 'friendship'
        then case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
      end,
      case when n.subject_type = 'venue_invite'
        then case when vi.from_user_id = auth.uid() then vi.to_user_id else vi.from_user_id end
      end,
      case when n.subject_type = 'planned_trip_member'
        then case when tm.user_id = auth.uid() then tm.invited_by else tm.user_id end
      end
    ) as other_user_id,
    p.username as other_username,
    p.display_name as other_display_name,
    p.avatar_url as other_avatar_url,
    mlr.subject_type as listing_subject_type,
    mlr.name as listing_name,
    mlr.city as listing_city,
    vi.venue_type as invite_venue_type,
    vi.venue_id as invite_venue_id,
    coalesce(rf.name, hf.name) as invite_venue_name,
    coalesce(rf.city_name, hf.city_name) as invite_venue_city,
    vi.note as invite_note,
    vi.status as invite_status,
    vi.expires_at as invite_expires_at,
    coalesce(
      case when clr.id is not null then 'restaurant' end,
      case when clh.id is not null then 'hotel' end,
      case when clp.id is not null then 'private_chef' end,
      case when clv.id is not null then 'vineyard' end
    ) as claim_venue_type,
    coalesce(clr.restaurant_id, clh.hotel_id, clp.private_chef_id, clv.vineyard_id) as claim_venue_id,
    coalesce(clrf.name, clhf.name, clpf.display_name, clvf.name) as claim_venue_name,
    coalesce(clrf.city_name, clhf.city_name, clpf.home_city, clvf.city) as claim_venue_city,
    coalesce(clr.review_note, clh.review_note, clp.review_note, clv.review_note) as claim_review_note,
    coalesce(vas.venue_type, vps.venue_type) as submission_venue_type,
    coalesce(vas.venue_id, vps.venue_id) as submission_venue_id,
    coalesce(subrf.name, subhf.name, subpf.display_name, subvf.name) as submission_venue_name,
    coalesce(subrf.city_name, subhf.city_name, subpf.home_city, subvf.city) as submission_venue_city,
    coalesce(vas.review_note, vps.review_note) as submission_review_note,
    f.status as friendship_status,
    ev.name as event_name,
    ev.start_date as event_start_date,
    ev.review_note as event_review_note,
    evh.venue_type as event_venue_type,
    evh.venue_id as event_venue_id,
    evh.venue_name as event_venue_name,
    tr.id as trip_id,
    tr.title as trip_title,
    tr.start_date as trip_start_date,
    tr.end_date as trip_end_date,
    tm.status as trip_member_status
  from public.notifications n
  left join public.friendships f
    on n.subject_type = 'friendship' and f.id = n.subject_id
  left join public.venue_invites vi
    on n.subject_type = 'venue_invite' and vi.id = n.subject_id
  left join public.restaurants_full rf
    on vi.venue_type = 'restaurant' and rf.id = vi.venue_id
  left join public.hotels_full hf
    on vi.venue_type = 'hotel' and hf.id = vi.venue_id
  left join public.planned_trip_members tm
    on n.subject_type = 'planned_trip_member' and tm.id = n.subject_id
  left join public.planned_trips tr
    on tr.id = tm.trip_id
  left join public.profiles p
    on p.id = coalesce(
      case when n.subject_type = 'friendship'
        then case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
      end,
      case when n.subject_type = 'venue_invite'
        then case when vi.from_user_id = auth.uid() then vi.to_user_id else vi.from_user_id end
      end,
      case when n.subject_type = 'planned_trip_member'
        then case when tm.user_id = auth.uid() then tm.invited_by else tm.user_id end
      end
    )
  left join public.missing_listing_reports mlr
    on n.subject_type = 'missing_listing_report' and mlr.id = n.subject_id
  left join public.claims_restaurants clr
    on n.subject_type = 'venue_claim' and clr.id = n.subject_id
  left join public.claims_hotels clh
    on n.subject_type = 'venue_claim' and clh.id = n.subject_id
  left join public.claims_private_chefs clp
    on n.subject_type = 'venue_claim' and clp.id = n.subject_id
  left join public.restaurants_full clrf on clrf.id = clr.restaurant_id
  left join public.hotels_full clhf on clhf.id = clh.hotel_id
  left join public.private_chefs_full clpf on clpf.id = clp.private_chef_id
  left join public.claims_vineyards clv
    on n.subject_type = 'venue_claim' and clv.id = n.subject_id
  left join public.vineyards clvf on clvf.id = clv.vineyard_id
  left join public.venue_about_submissions vas
    on n.subject_type = 'venue_about_submission' and vas.id = n.subject_id
  left join public.venue_photo_submissions vps
    on n.subject_type = 'venue_photo_submission' and vps.id = n.subject_id
  left join public.restaurants_full subrf
    on coalesce(vas.venue_type, vps.venue_type) = 'restaurant'
    and subrf.id = coalesce(vas.venue_id, vps.venue_id)
  left join public.hotels_full subhf
    on coalesce(vas.venue_type, vps.venue_type) = 'hotel'
    and subhf.id = coalesce(vas.venue_id, vps.venue_id)
  left join public.private_chefs_full subpf
    on coalesce(vas.venue_type, vps.venue_type) = 'private_chef'
    and subpf.id = coalesce(vas.venue_id, vps.venue_id)
  left join public.vineyards subvf
    on coalesce(vas.venue_type, vps.venue_type) = 'vineyard'
    and subvf.id = coalesce(vas.venue_id, vps.venue_id)
  left join public.events ev
    on n.subject_type = 'event' and ev.id = n.subject_id
  left join lateral public.event_host_venue(ev.id) evh on true
  where n.recipient_id = auth.uid()
  order by n.created_at desc;
$function$;

