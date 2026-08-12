// Covers the Social Foundation Step 1 models: RelationshipStatus,
// ProfileIdentity, Friendship, FriendRequest — pure row-mapping and
// label-fallback logic, no Supabase involved.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/friendship.dart';
import 'package:michelin_passport/models/profile_identity.dart';

void main() {
  group('RelationshipStatus.fromDb', () {
    test('maps every known DB value', () {
      expect(
        RelationshipStatus.fromDb('accepted'),
        RelationshipStatus.accepted,
      );
      expect(
        RelationshipStatus.fromDb('pending_sent'),
        RelationshipStatus.pendingSent,
      );
      expect(
        RelationshipStatus.fromDb('pending_received'),
        RelationshipStatus.pendingReceived,
      );
      expect(
        RelationshipStatus.fromDb('declined'),
        RelationshipStatus.declined,
      );
    });

    test('null and unrecognized values fall back to none', () {
      expect(RelationshipStatus.fromDb(null), RelationshipStatus.none);
      expect(RelationshipStatus.fromDb('blocked'), RelationshipStatus.none);
      expect(RelationshipStatus.fromDb('garbage'), RelationshipStatus.none);
    });
  });

  group('ProfileIdentity.label', () {
    test('prefers display name', () {
      final identity = ProfileIdentity.fromRow({
        'id': 'u1',
        'username': 'kylan',
        'display_name': 'Kylan S.',
        'avatar_url': null,
        'relationship_status': null,
      });
      expect(identity.label, 'Kylan S.');
    });

    test('falls back to @username when display name is empty', () {
      final identity = ProfileIdentity.fromRow({
        'id': 'u1',
        'username': 'kylan',
        'display_name': '',
        'avatar_url': null,
        'relationship_status': null,
      });
      expect(identity.label, '@kylan');
    });

    test('falls back to a neutral label when both are missing', () {
      final identity = ProfileIdentity.fromRow({
        'id': 'u1',
        'username': null,
        'display_name': null,
        'avatar_url': null,
        'relationship_status': null,
      });
      expect(identity.label, 'Chasing Stars member');
    });

    test('fromRow maps relationship_status correctly', () {
      final identity = ProfileIdentity.fromRow({
        'id': 'u1',
        'username': 'kylan',
        'display_name': 'Kylan',
        'avatar_url': 'https://example.com/a.png',
        'relationship_status': 'pending_received',
      });
      expect(identity.relationshipStatus, RelationshipStatus.pendingReceived);
      expect(identity.avatarUrl, 'https://example.com/a.png');
    });
  });

  group('Friendship.fromRow / label', () {
    test('maps get_friends() row shape', () {
      final friend = Friendship.fromRow({
        'friendship_id': 'f1',
        'friend_id': 'u2',
        'username': 'userb',
        'display_name': 'User B',
        'avatar_url': null,
      });
      expect(friend.friendshipId, 'f1');
      expect(friend.friendId, 'u2');
      expect(friend.label, 'User B');
    });

    test('label falls back to @username with no display name', () {
      final friend = Friendship.fromRow({
        'friendship_id': 'f1',
        'friend_id': 'u2',
        'username': 'userb',
        'display_name': null,
        'avatar_url': null,
      });
      expect(friend.label, '@userb');
    });
  });

  group('FriendRequest.fromIncomingRow / fromOutgoingRow', () {
    test('incoming row uses requester_id as the other participant', () {
      final request = FriendRequest.fromIncomingRow({
        'friendship_id': 'f1',
        'requester_id': 'u1',
        'username': 'usera',
        'display_name': 'User A',
        'avatar_url': null,
        'created_at': '2026-08-12T22:17:58.558246+00:00',
      });
      expect(request.otherUserId, 'u1');
      expect(request.label, 'User A');
    });

    test('outgoing row uses addressee_id as the other participant', () {
      final request = FriendRequest.fromOutgoingRow({
        'friendship_id': 'f1',
        'addressee_id': 'u2',
        'username': 'userb',
        'display_name': 'User B',
        'avatar_url': null,
        'created_at': '2026-08-12T22:17:58.558246+00:00',
      });
      expect(request.otherUserId, 'u2');
      expect(request.label, 'User B');
    });
  });
}
