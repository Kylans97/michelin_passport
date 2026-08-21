import '../../models/friendship.dart';

/// The accepted friends attending an event, ready to display (Community/
/// Friends Step 1A; reused as-is for Friends Interested by Events V2 Step
/// 7 — this function has never actually depended on Going specifically,
/// only on "a list of attendee ids RLS already confirmed visible," so
/// EventDetailScreen calls it a second time with Interested-status ids
/// rather than duplicating it). Every id in [attendeeUserIds] is already
/// RLS-confirmed visible to the caller — `event_attendance_select` only
/// ever returns the caller's own row or an accepted friend's
/// friends-visible row (see `is_friend()`), so this function's only jobs
/// are:
///
/// - self-exclusion (presentation only, not a security filter — RLS is
///   the actual authority; the viewer's own state is already shown via
///   the "I'm going"/"Going" button, not repeated here),
/// - resolving each remaining id against the caller's own already-fetched
///   friend list (avoids a profile lookup per attendee — see
///   [EventAttendanceRepository.getVisibleAttendeeUserIds]'s own doc
///   comment for why [friends] is the batched resolution source rather
///   than a new RPC),
/// - deterministic alphabetical ordering by display name.
///
/// An attendee id with no matching entry in [friends] is silently skipped
/// rather than shown as a nameless row — this should never happen if RLS
/// is behaving as documented (every non-self visible row IS an accepted
/// friend), but presentation code must never crash on an unexpected shape.
List<Friendship> friendsGoingToEvent({
  required List<String> attendeeUserIds,
  required List<Friendship> friends,
  required String selfUserId,
}) {
  final friendsById = {for (final f in friends) f.friendId: f};
  final result = <Friendship>[
    for (final id in attendeeUserIds)
      if (id != selfUserId && friendsById.containsKey(id)) friendsById[id]!,
  ];
  result.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return result;
}
