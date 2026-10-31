// withAvatar on the identity models: a resolved photo replaces the
// never-populated avatar_url, null keeps what was there, and nothing else
// changes.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/friendship.dart';
import 'package:michelin_passport/models/profile_identity.dart';

void main() {
  test('Friendship.withAvatar', () {
    const f = Friendship(
      friendshipId: 'fs',
      friendId: 'u1',
      username: 'anna',
      displayName: 'Anna',
    );
    final withPhoto = f.withAvatar('https://x/a.jpg');
    expect(withPhoto.avatarUrl, 'https://x/a.jpg');
    expect(withPhoto.friendId, 'u1');
    expect(withPhoto.label, 'Anna');
    expect(f.withAvatar(null).avatarUrl, isNull);
  });

  test('FriendRequest.withAvatar keeps the request', () {
    final r = FriendRequest(
      friendshipId: 'fs',
      otherUserId: 'u2',
      username: 'bas',
      createdAt: DateTime(2026, 10, 31),
    );
    final withPhoto = r.withAvatar('https://x/b.jpg');
    expect(withPhoto.avatarUrl, 'https://x/b.jpg');
    expect(withPhoto.createdAt, DateTime(2026, 10, 31));
  });

  test('ProfileIdentity.withAvatar keeps status and member number', () {
    const p = ProfileIdentity(
      id: 'u3',
      username: 'cas',
      relationshipStatus: RelationshipStatus.accepted,
      memberNumber: 42,
    );
    final withPhoto = p.withAvatar('https://x/c.jpg');
    expect(withPhoto.avatarUrl, 'https://x/c.jpg');
    expect(withPhoto.relationshipStatus, RelationshipStatus.accepted);
    expect(withPhoto.memberNumber, 42);
  });
}
