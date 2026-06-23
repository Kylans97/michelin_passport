class Friendship {
  final String id;
  final String requesterId;
  final String addresseeId;
  final String status; // pending / accepted
  final String friendDisplayName;
  final String friendId;
  final String? friendTier;

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.friendDisplayName,
    required this.friendId,
    this.friendTier,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  // Build from a friendships row where the current user is the requester.
  factory Friendship.asRequester(Map<String, dynamic> row, String currentUserId) {
    final addressee = row['addressee'] as Map<String, dynamic>? ?? {};
    return Friendship(
      id: row['id'].toString(),
      requesterId: currentUserId,
      addresseeId: row['addressee_id'].toString(),
      status: (row['status'] as String?) ?? 'pending',
      friendDisplayName: (addressee['display_name'] as String?) ?? 'Unknown',
      friendId: row['addressee_id'].toString(),
      friendTier: addressee['tier'] as String?,
    );
  }

  // Build from a friendships row where the current user is the addressee.
  factory Friendship.asAddressee(Map<String, dynamic> row, String currentUserId) {
    final requester = row['requester'] as Map<String, dynamic>? ?? {};
    return Friendship(
      id: row['id'].toString(),
      requesterId: row['requester_id'].toString(),
      addresseeId: currentUserId,
      status: (row['status'] as String?) ?? 'pending',
      friendDisplayName: (requester['display_name'] as String?) ?? 'Unknown',
      friendId: row['requester_id'].toString(),
      friendTier: requester['tier'] as String?,
    );
  }
}
