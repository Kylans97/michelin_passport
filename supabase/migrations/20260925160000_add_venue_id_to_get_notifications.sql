begin;

-- get_notifications() (just extended in 20260925140000) is missing one
-- column: invite_venue_id. The Notifications screen's accept/decline
-- handlers need the venue's own id to track venueInviteAccepted/Declined
-- (AnalyticsProperties.entityId, REQUIRED alongside entityType) — caught
-- while wiring the Dart side, not before, since invite_venue_type/_name/
-- _city alone looked sufficient until the analytics call site made clear
-- the raw id was still missing. Same drop+recreate reason as before:
-- CREATE OR REPLACE cannot change a function's return-table shape.

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
  invite_expires_at timestamptz
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
    vi.expires_at as invite_expires_at
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
  where n.recipient_id = auth.uid()
  order by n.created_at desc;
$$;

revoke execute on function public.get_notifications() from public, anon;
grant execute on function public.get_notifications() to authenticated;

commit;
