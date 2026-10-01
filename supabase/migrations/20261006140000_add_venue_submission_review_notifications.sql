-- Closes the last link in the review loop: a manager submits an about-
-- text or photo change, and today nothing tells them what happened to it
-- — approval and rejection each just update a row's status column and
-- stop. notify_venue_claim_change (20260927120000_add_venue_claim_
-- details_and_notifications.sql) already solved this exact problem for
-- claims; this mirrors its shape rather than inventing a second
-- convention for the same kind of event.
--
-- A trigger on the status change, not inside approve_venue_about/
-- reject_venue_about/approve_venue_photo/reject_venue_photo (none of
-- which this migration touches) — a trigger fires whether the change
-- came from an RPC, the notify-venue-submission Edge Function's own
-- admin path, or manual SQL against the dashboard, so a review done by
-- hand can never silently skip notifying the submitter the way logic
-- living inside the RPCs alone could.
--
-- Mirrors notify_admin_of_pending_venue_submission's own shape too, not
-- just notify_venue_claim_change's: ONE shared function attached to both
-- venue_about_submissions and venue_photo_submissions, branching on
-- TG_TABLE_NAME rather than writing the same logic twice.
--
-- Deliberately narrower than the claims trigger: no "received"
-- notification here. The in-app confirmation shown at submission time
-- already tells a manager their change went to review; a claim has no
-- equivalent immediate confirmation screen, which is why that trigger
-- covers INSERT too. Only the two decisions a manager cannot otherwise
-- learn about — approved, rejected — are covered, so this is an AFTER
-- UPDATE trigger only, not AFTER INSERT OR UPDATE.

begin;

-- ============================================================
-- 1. Notifications — 4 new types + 2 new subject_types
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
      'venue_claim_rejected',
      'venue_about_approved',
      'venue_about_rejected',
      'venue_photo_approved',
      'venue_photo_rejected'
    ));

alter table public.notifications
  drop constraint notifications_subject_type_check,
  add constraint notifications_subject_type_check
    check (subject_type in (
      'friendship', 'missing_listing_report', 'venue_invite', 'venue_claim',
      'venue_about_submission', 'venue_photo_submission'
    ));

-- ============================================================
-- 2. The trigger — fires the same way on both submission tables
-- ============================================================

create function public.notify_venue_submission_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject_type text;
  v_type_prefix text;
begin
  if TG_TABLE_NAME = 'venue_about_submissions' then
    v_subject_type := 'venue_about_submission';
    v_type_prefix := 'venue_about';
  else
    v_subject_type := 'venue_photo_submission';
    v_type_prefix := 'venue_photo';
  end if;

  if old.status = 'pending' and new.status = 'approved' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.user_id, v_type_prefix || '_approved', v_subject_type, new.id);
  elsif old.status = 'pending' and new.status = 'rejected' then
    insert into public.notifications (recipient_id, type, subject_type, subject_id)
    values (new.user_id, v_type_prefix || '_rejected', v_subject_type, new.id);
  end if;

  return new;
end;
$$;

revoke execute on function public.notify_venue_submission_review() from public, anon;

create trigger venue_about_submissions_notify_on_review
  after update on public.venue_about_submissions
  for each row execute function public.notify_venue_submission_review();

create trigger venue_photo_submissions_notify_on_review
  after update on public.venue_photo_submissions
  for each row execute function public.notify_venue_submission_review();

-- ============================================================
-- 3. get_notifications() — add submission_* columns
--
-- CREATE OR REPLACE cannot change a function's return-table shape (this
-- project's own established gotcha) — drop and recreate, same as every
-- prior extension of this function.
--
-- One set of submission_* columns shared by both venue_about_submission
-- and venue_photo_submission rows (coalesced across two joins, one per
-- table), mirroring claim_venue_* being one shared set across three
-- claim tables rather than a separate column family per source table.
-- submission_review_note is how the rejection notification carries the
-- reviewer's note (chosen over "lead somewhere the note is visible" —
-- there is no separate screen a submission's own review state is shown
-- on today to lead to).
-- ============================================================

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
  claim_venue_city text,
  submission_venue_type text,
  submission_venue_id uuid,
  submission_venue_name text,
  submission_venue_city text,
  submission_review_note text
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
    coalesce(clrf.city_name, clhf.city_name, clpf.home_city) as claim_venue_city,
    coalesce(vas.venue_type, vps.venue_type) as submission_venue_type,
    coalesce(vas.venue_id, vps.venue_id) as submission_venue_id,
    coalesce(subrf.name, subhf.name, subpf.display_name) as submission_venue_name,
    coalesce(subrf.city_name, subhf.city_name, subpf.home_city) as submission_venue_city,
    coalesce(vas.review_note, vps.review_note) as submission_review_note
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
  where n.recipient_id = auth.uid()
  order by n.created_at desc;
$$;

revoke execute on function public.get_notifications() from public, anon;
grant execute on function public.get_notifications() to authenticated;

commit;
