-- Carries a friend request's current status through to its notification,
-- the same way get_notifications() already returns invite_status for
-- venue invites. Without it, a friend_request_received row kept its
-- Accept/Decline forever: after the request was accepted, declined,
-- cancelled by the sender or the friendship later removed, tapping
-- either button made accept_/decline_friend_request raise "That friend
-- request is no longer available", which NotificationsScreen never
-- caught. More reachable since 2026-10-28, when incoming requests went
-- back onto FriendsScreen's own Requests tab and a request gained a
-- second place to be answered.
--
-- friendships is already LEFT JOINed here (alias f) for other_user_id;
-- this adds f.status as one more column, nothing new to join. Values:
-- 'pending' / 'accepted' / 'declined' / 'blocked' from the row, or NULL
-- when the friendship row no longer exists (cancelled by the sender, or
-- removed — both delete it) and for every non-friendship notification.
--
-- Additive for builds already in the wild: AppNotification reads columns
-- by name, so an extra one is ignored — the same reliance as
-- 20261009120000's claim_review_note. The new build treats a missing key
-- as "server predates this" and keeps the old always-show-buttons
-- behaviour, so build and migration can ship in either order.
--
-- Real date: 2026-10-28. The filename is a sequence number, the next one
-- after the highest existing migration (20261011120000), per CLAUDE.md.
--
-- CREATE OR REPLACE cannot change a function's return-table shape —
-- drop and recreate, same as every prior extension of this function.
-- The revoke/grant pair below is the same one it has always carried;
-- get_notifications() is SECURITY DEFINER, so the revoke from public,
-- anon has to be restated on every recreate.

begin;

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
  claim_review_note text,
  submission_venue_type text,
  submission_venue_id uuid,
  submission_venue_name text,
  submission_venue_city text,
  submission_review_note text,
  friendship_status text
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
    coalesce(clr.review_note, clh.review_note, clp.review_note) as claim_review_note,
    coalesce(vas.venue_type, vps.venue_type) as submission_venue_type,
    coalesce(vas.venue_id, vps.venue_id) as submission_venue_id,
    coalesce(subrf.name, subhf.name, subpf.display_name) as submission_venue_name,
    coalesce(subrf.city_name, subhf.city_name, subpf.home_city) as submission_venue_city,
    coalesce(vas.review_note, vps.review_note) as submission_review_note,
    f.status as friendship_status
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
