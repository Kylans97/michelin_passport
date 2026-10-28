// One row of `public.get_trip_members()` (see
// supabase/migrations/20261021120000_add_trip_destinations_and_members.sql):
// the trip's owner plus everyone invited to or on it (declined
// invitations excluded). Members needn't be friends with each other, so
// names come from that security-definer RPC, never a profiles read.

enum TripMemberStatus {
  owner,
  pending,
  accepted;

  static TripMemberStatus fromWire(String? value) => switch (value) {
    'owner' => TripMemberStatus.owner,
    'accepted' => TripMemberStatus.accepted,
    _ => TripMemberStatus.pending,
  };
}

class TripMember {
  /// `planned_trip_members.id` — null for the owner, who has no row there.
  final String? memberId;
  final String userId;
  final TripMemberStatus status;
  final String? invitedBy;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  const TripMember({
    this.memberId,
    required this.userId,
    required this.status,
    this.invitedBy,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory TripMember.fromRow(Map<String, dynamic> row) => TripMember(
    memberId: row['member_id'] as String?,
    userId: row['user_id'] as String,
    status: TripMemberStatus.fromWire(row['status'] as String?),
    invitedBy: row['invited_by'] as String?,
    username: row['username'] as String?,
    displayName: row['display_name'] as String?,
    avatarUrl: row['avatar_url'] as String?,
  );

  /// Same fallback order as Friendship.label: a real name, then
  /// "@username", then a neutral default — never blank.
  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (username != null && username!.isNotEmpty) return '@$username';
    return 'Mantelier member';
  }
}

/// A trip someone invited the current user to, not yet answered.
class TripInvitation {
  final String memberId;
  final String tripId;
  final String tripTitle;
  final DateTime startDate;
  final DateTime endDate;
  final String? inviterLabel;

  const TripInvitation({
    required this.memberId,
    required this.tripId,
    required this.tripTitle,
    required this.startDate,
    required this.endDate,
    this.inviterLabel,
  });
}
