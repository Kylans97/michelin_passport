/// One row from `get_blocked_users()` — a user the current account has
/// blocked (never the reverse: the RPC only ever returns blocks *you*
/// created, matching `unblock_user`'s own "only the blocker may unblock"
/// rule).
class BlockedUser {
  final String friendshipId;
  final String userId;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final DateTime? blockedAt;

  const BlockedUser({
    required this.friendshipId,
    required this.userId,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.blockedAt,
  });

  factory BlockedUser.fromRow(Map<String, dynamic> row) => BlockedUser(
    friendshipId: row['friendship_id'] as String,
    userId: row['user_id'] as String,
    displayName: row['display_name'] as String?,
    username: row['username'] as String?,
    avatarUrl: row['avatar_url'] as String?,
    blockedAt: row['blocked_at'] == null
        ? null
        : DateTime.parse(row['blocked_at'] as String),
  );

  /// Same display fallback as [ProfileIdentity.label].
  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (username != null && username!.isNotEmpty) return '@$username';
    return 'Mantelier member';
  }
}
