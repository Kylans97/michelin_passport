/// An accepted friendship, from the current user's point of view — the
/// shape `public.get_friends()` returns (see the Social Foundation Step 1
/// migration). `friendId` is always "the other person," regardless of
/// which side of the original request the current user was on; the RPC
/// itself already resolves that orientation server-side.
class Friendship {
  final String friendshipId;
  final String friendId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  const Friendship({
    required this.friendshipId,
    required this.friendId,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory Friendship.fromRow(Map<String, dynamic> row) => Friendship(
    friendshipId: row['friendship_id'] as String,
    friendId: row['friend_id'] as String,
    username: row['username'] as String?,
    displayName: row['display_name'] as String?,
    avatarUrl: row['avatar_url'] as String?,
  );

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (username != null && username!.isNotEmpty) return '@$username';
    return 'Chasing Stars member';
  }
}

/// A still-pending friend request — either one the current user sent
/// (outgoing) or received (incoming). Two separate factories rather than
/// one generic row shape because `get_incoming_friend_requests`/
/// `get_outgoing_friend_requests` return the other participant under a
/// different column name (`requester_id` vs `addressee_id`) — see the
/// migration.
class FriendRequest {
  final String friendshipId;
  final String otherUserId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  const FriendRequest({
    required this.friendshipId,
    required this.otherUserId,
    this.username,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory FriendRequest.fromIncomingRow(Map<String, dynamic> row) =>
      FriendRequest(
        friendshipId: row['friendship_id'] as String,
        otherUserId: row['requester_id'] as String,
        username: row['username'] as String?,
        displayName: row['display_name'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  factory FriendRequest.fromOutgoingRow(Map<String, dynamic> row) =>
      FriendRequest(
        friendshipId: row['friendship_id'] as String,
        otherUserId: row['addressee_id'] as String,
        username: row['username'] as String?,
        displayName: row['display_name'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (username != null && username!.isNotEmpty) return '@$username';
    return 'Chasing Stars member';
  }
}
