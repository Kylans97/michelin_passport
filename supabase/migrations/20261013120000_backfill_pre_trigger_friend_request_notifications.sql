-- Gives every still-pending friend request that has no notification the
-- friend_request_received notification it would have got had the trigger
-- existed when it was sent.
--
-- friendships has existed since 20260813120000; notifications and its
-- friendships_notify_on_change trigger arrived in 20260924130000, which
-- only fires on new rows and created nothing for requests already
-- pending. Production's first notification is 2026-09-25 13:56 UTC, and
-- a read-only check on 2026-10-28 found exactly 4 pending requests, all
-- sent 2026-09-23, with no notification: answerable since 2026-10-28 on
-- FriendsScreen's Requests tab, but never shown in Notifications.
--
-- created_at is the friendship's own created_at, not now(): each
-- notification is dated when the request actually arrived, which is the
-- moment the trigger would have stamped. They arrive unread (the column
-- default), so each recipient gets an unread badge once.
--
-- Matches on subject_id + type only, so it is safe to re-run, and inserts
-- nothing on a fresh replay (no friendships exist there). Before
-- applying, re-run the read-only count of pending friendships with no
-- friend_request_received notification: it should still be 4, minus any
-- answered since 2026-10-28.
--
-- Not an in-between backfill under CLAUDE.md's naming exception: no later
-- migration depends on these rows, so it is named after the highest
-- migration (20261012120000). Real date: 2026-10-28.

begin;

insert into public.notifications (recipient_id, type, subject_type, subject_id, created_at)
select f.addressee_id, 'friend_request_received', 'friendship', f.id, f.created_at
from public.friendships f
where f.status = 'pending'
  and not exists (
    select 1
    from public.notifications n
    where n.subject_type = 'friendship'
      and n.subject_id = f.id
      and n.type = 'friend_request_received'
  );

commit;
