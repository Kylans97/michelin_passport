-- VENUE CLAIMS — Phase 1: claimant-submitted details, a real "blocked"
-- status, and notifications for the request lifecycle.
--
-- ============================================================
-- WHAT ALREADY EXISTS — read first, nothing below duplicates it
-- ============================================================
--
-- claims_restaurants/claims_hotels/claims_private_chefs,
-- has_approved_venue_claim(), venue_about_submissions,
-- restaurant_photos/hotel_photos, venue_photo_submissions (+ its private
-- storage bucket), venue_corrections, venue_ratings/
-- venue_community_rankings, and events.submitted_by + the claimant-submit
-- RLS on events/event_restaurants/event_hotels/event_chefs were all
-- built by 20260828120000_add_venue_claims_submissions_rankings.sql and
-- confirmed live in production (queried directly, not assumed from the
-- migration file alone). This migration only adds what that one
-- deliberately left out: the claimant's own submitted context (role/
-- contact), a genuine "blocked" status distinct from "rejected", and the
-- notifications this feature's own brief asks for (none of which existed
-- for claims before this).
--
-- ============================================================
-- ARCHITECTURAL CHOICES
-- ============================================================
--
-- ROLE is a fixed 4-value CHECK (owner/manager/chef/other), matching the
-- brief's own enumerated list exactly, rather than free text — a claimant
-- picks one, they don't type it.
--
-- BUSINESS_EMAIL/PHONE stay plain `text not null`, unconstrained beyond
-- that — same convention missing_listing_reports.reporter_contact already
-- uses for the identical "a way to reach a claimant" purpose. Format
-- validation belongs client-side (Flutter form validation), not a DB
-- CHECK that would need to correctly handle every valid email/phone
-- shape.
--
-- BLOCKED is a real 4th status, not a rename of "rejected" — confirmed
-- explicitly rather than assumed. Unlike "rejected" (which the existing
-- partial unique index already lets a user re-attempt after — a
-- deliberate, pre-existing design choice this migration does not touch),
-- "blocked" must permanently close the door: the partial unique index's
-- own predicate is widened to also cover 'blocked', so a new claim
-- attempt on the same (user, venue) pair while a blocked row exists hits
-- the same unique-violation a pending/approved one already would. There
-- is still no client-facing way to SET blocked (or any status) — exactly
-- like approve/reject today, it's a manual dashboard/service-role action.
--
-- NOTIFICATION COPY: rejected and blocked deliberately produce the SAME
-- notification type/copy for the claimant — "that distinction is
-- information for me, not for the requester" (explicit instruction). The
-- trigger below only ever fires a rejection-shaped notification on the
-- transition OUT of 'pending' (a fresh decision on a live request) — a
-- LATER escalation from an already-rejected claim to blocked (a separate,
-- later admin action, not a decision on a pending request) intentionally
-- does not fire a second notification.
--
-- PRIVATE_CHEF added to missing_listing_reports.subject_type: the claim
-- flow's own "type + search, not found -> report it" step needs to cover
-- all three venue types the claims tables already do; the report sheet
-- only had restaurant/hotel/event.
--
-- PREPARED, NOT APPLIED.

begin;

-- ============================================================
-- 1. Claimant-submitted details on all three claims tables
-- ============================================================

alter table public.claims_restaurants
  add column role text not null check (role in ('owner', 'manager', 'chef', 'other')),
  add column business_email text not null,
  add column phone text not null,
  add column notes text;

alter table public.claims_hotels
  add column role text not null check (role in ('owner', 'manager', 'chef', 'other')),
  add column business_email text not null,
  add column phone text not null,
  add column notes text;

alter table public.claims_private_chefs
  add column role text not null check (role in ('owner', 'manager', 'chef', 'other')),
  add column business_email text not null,
  add column phone text not null,
  add column notes text;

-- ============================================================
-- 2. A real "blocked" status
-- ============================================================

alter table public.claims_restaurants
  drop constraint claims_restaurants_status_check,
  add constraint claims_restaurants_status_check
    check (status in ('pending', 'approved', 'rejected', 'blocked'));

alter table public.claims_hotels
  drop constraint claims_hotels_status_check,
  add constraint claims_hotels_status_check
    check (status in ('pending', 'approved', 'rejected', 'blocked'));

alter table public.claims_private_chefs
  drop constraint claims_private_chefs_status_check,
  add constraint claims_private_chefs_status_check
    check (status in ('pending', 'approved', 'rejected', 'blocked'));

-- Widen the partial unique index's own predicate so a blocked row keeps
-- blocking a new attempt on the same (user, venue) pair, the same way a
-- pending/approved one already does. Postgres has no ALTER INDEX for a
-- predicate change — drop and recreate under the same name.
drop index public.claims_restaurants_active_uidx;
create unique index claims_restaurants_active_uidx
  on public.claims_restaurants (user_id, restaurant_id)
  where status in ('pending', 'approved', 'blocked');

drop index public.claims_hotels_active_uidx;
create unique index claims_hotels_active_uidx
  on public.claims_hotels (user_id, hotel_id)
  where status in ('pending', 'approved', 'blocked');

drop index public.claims_private_chefs_active_uidx;
create unique index claims_private_chefs_active_uidx
  on public.claims_private_chefs (user_id, private_chef_id)
  where status in ('pending', 'approved', 'blocked');

-- ============================================================
-- 3. missing_listing_reports gains a private_chef subject type
-- ============================================================

alter table public.missing_listing_reports
  drop constraint missing_listing_reports_subject_type_check,
  add constraint missing_listing_reports_subject_type_check
    check (subject_type in ('restaurant', 'hotel', 'event', 'private_chef'));

-- ============================================================
-- 4. Notifications — 3 new types + a venue_claim subject_type
-- ============================================================

alter table public.notifications
  drop constraint notifications_type_check,
  add constraint notifications_type_check
    check (type in (
      'friend_request_received',
      'friend_request_accepted',
      'missing_listing_added',
      'venue_invite_received',
      'venue_invite_accepted',
      'venue_invite_declined',
      'venue_claim_received',
      'venue_claim_approved',
      'venue_claim_rejected'
    ));

alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim'
    ));

-- ============================================================
-- 5. Claims trigger — fires the same way on all three typed tables
-- ============================================================
--
-- One function, not three: unlike notify_venue_invite_change (which
-- needs venue_invites' own from_user_id/to_user_id columns), everything
-- this notification needs — id, user_id, status — has an identical name
-- on all three claims tables, so the SAME function body works attached to
-- any of them with no per-table branching or TG_ARGV needed. Which venue
-- was claimed is resolved later, in get_notifications() (§6), not stored
-- redundantly on the notification row itself.

create function public.notify_venue_claim_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.user_id, 'venue_claim_received', 'venue_claim', new.id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'approved' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.user_id, 'venue_claim_approved', 'venue_claim', new.id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status in ('rejected', 'blocked') then
    -- Same notification type for both — see file header. A LATER
    -- rejected -> blocked escalation does not match old.status =
    -- 'pending' here, so it never fires a second notification.
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.user_id, 'venue_claim_rejected', 'venue_claim', new.id);
  end if;
  return new;
end;
$$;

revoke execute on function public.notify_venue_claim_change() from public, anon;

create trigger claims_restaurants_notify_on_change
  after insert or update on public.claims_restaurants
  for each row execute function public.notify_venue_claim_change();
create trigger claims_hotels_notify_on_change
  after insert or update on public.claims_hotels
  for each row execute function public.notify_venue_claim_change();
create trigger claims_private_chefs_notify_on_change
  after insert or update on public.claims_private_chefs
  for each row execute function public.notify_venue_claim_change();

-- ============================================================
-- 6. get_notifications() — add claim_venue_* columns
-- ============================================================
--
-- CREATE OR REPLACE cannot change a function's return-table shape (hit
-- this exact error already, twice, earlier this project) — drop and
-- recreate, same as every prior extension of this function.

drop function public.get_notifications();

create function public.get_notifications()
returns table (
  id uuid,
  type text,
  subject_type text,
  subject_id uuid,
  is_read boolean,
  created_at timestamptz,
  other_user_id uuid,
  other_username text,
  other_display_name text,
  other_avatar_url text,
  listing_subject_type text,
  listing_name text,
  listing_city text,
  invite_venue_type text,
  invite_venue_id uuid,
  invite_venue_name text,
  invite_venue_city text,
  invite_note text,
  invite_status text,
  invite_expires_at timestamptz,
  claim_venue_type text,
  claim_venue_id uuid,
  claim_venue_name text,
  claim_venue_city text
)
language sql
stable
security definer
set search_path = public
as $$
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
      case when clp.id is not null then 'private_chef' end
    ) as claim_venue_type,
    coalesce(clr.restaurant_id, clh.hotel_id, clp.private_chef_id) as claim_venue_id,
    coalesce(clrf.name, clhf.name, clpf.display_name) as claim_venue_name,
    coalesce(clrf.city_name, clhf.city_name, clpf.home_city) as claim_venue_city
  from public.notifications n
  left join public.friendships f
    on n.subject_type = 'friendship' and f.id = n.subject_id
  left join public.venue_invites vi
    on n.subject_type = 'venue_invite' and vi.id = n.subject_id
  left join public.restaurants_full rf
    on vi.venue_type = 'restaurant' and rf.id = vi.venue_id
  left join public.hotels_full hf
    on vi.venue_type = 'hotel' and hf.id = vi.venue_id
  left join public.profiles p
    on p.id = coalesce(
      case when n.subject_type = 'friendship'
        then case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
      end,
      case when n.subject_type = 'venue_invite'
        then case when vi.from_user_id = auth.uid() then vi.to_user_id else vi.from_user_id end
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
  where n.recipient_id = auth.uid()
  order by n.created_at desc;
$$;

revoke execute on function public.get_notifications() from public, anon;
grant execute on function public.get_notifications() to authenticated;

commit;
