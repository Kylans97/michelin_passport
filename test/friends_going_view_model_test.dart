// Covers friendsGoingToEvent (Community/Friends Step 1A) — the pure
// presentation function that turns "RLS-visible attendee ids for one
// event" + "the caller's own accepted friends" into the sorted,
// self-excluded list EventFriendsGoingSection renders.
//
// The privacy-sensitive cases the task calls out (private attendance,
// pending request, stranger, blocked, unfriend-after-visible) are all
// decided by event_attendance_select/is_friend() before this function ever
// runs — getVisibleAttendeeUserIds only ever returns ids RLS already
// authorized. Those cases are RLS/repository concerns (see
// EventAttendanceRepository.getVisibleAttendeeUserIds's own doc comment
// and docs/Architecture/COMMUNITY_FRIENDS_UX.md's Step 1A section), not
// reachable inputs to this pure function, so they aren't re-asserted here.
// Duplicate attendance is likewise schema-impossible (event_attendance's
// unique(event_id, user_id)), not something this function defends against.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/friends_going_view_model.dart';
import 'package:michelin_passport/models/friendship.dart';

const _self = 'self-1';

Friendship _friend({
  required String id,
  String? displayName,
  String? username,
}) => Friendship(
  friendshipId: 'fs-$id',
  friendId: id,
  displayName: displayName,
  username: username,
);

void main() {
  group('friendsGoingToEvent', () {
    test('resolves a visible attendee id against the friends list', () {
      final zoe = _friend(id: 'f1', displayName: 'Zoe Chen');
      final result = friendsGoingToEvent(
        attendeeUserIds: ['f1'],
        friends: [zoe],
        selfUserId: _self,
      );
      expect(result, [zoe]);
    });

    test(
      'excludes the viewer\'s own id even if present in attendeeUserIds',
      () {
        final self = _friend(id: _self, displayName: 'Me');
        final friend = _friend(id: 'f1', displayName: 'Amy Adams');
        final result = friendsGoingToEvent(
          attendeeUserIds: [_self, 'f1'],
          friends: [self, friend],
          selfUserId: _self,
        );
        expect(result, [friend]);
      },
    );

    test('silently skips an attendee id with no matching friend entry', () {
      final friend = _friend(id: 'f1', displayName: 'Amy Adams');
      final result = friendsGoingToEvent(
        attendeeUserIds: ['f1', 'stranger-id'],
        friends: [friend],
        selfUserId: _self,
      );
      expect(result, [friend]);
    });

    test('empty attendeeUserIds yields an empty list', () {
      final result = friendsGoingToEvent(
        attendeeUserIds: const [],
        friends: [_friend(id: 'f1', displayName: 'Amy Adams')],
        selfUserId: _self,
      );
      expect(result, isEmpty);
    });

    test('empty friends yields an empty list even with attendee ids', () {
      final result = friendsGoingToEvent(
        attendeeUserIds: const ['f1', 'f2'],
        friends: const [],
        selfUserId: _self,
      );
      expect(result, isEmpty);
    });

    test('sorts alphabetically by label, case-insensitive', () {
      final zoe = _friend(id: 'f1', displayName: 'zoe Chen');
      final amy = _friend(id: 'f2', displayName: 'Amy Adams');
      final mo = _friend(id: 'f3', displayName: 'Mo Farah');
      final result = friendsGoingToEvent(
        attendeeUserIds: ['f1', 'f2', 'f3'],
        friends: [zoe, amy, mo],
        selfUserId: _self,
      );
      expect(result, [amy, mo, zoe]);
    });

    test('a displayName-less friend sorts by its "@username" label — "@" '
        'sorts before letters, ahead of any named friend', () {
      final noName = _friend(id: 'f1', username: 'zzz_user');
      final named = _friend(id: 'f2', displayName: 'Amy Adams');
      final result = friendsGoingToEvent(
        attendeeUserIds: ['f1', 'f2'],
        friends: [noName, named],
        selfUserId: _self,
      );
      expect(result, [noName, named]);
    });
  });
}
