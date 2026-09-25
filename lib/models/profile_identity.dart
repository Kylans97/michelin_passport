/// The current user's relationship to another profile, relative to
/// `auth.uid()` — exactly the shape `public.search_profiles` and
/// `public.get_profile_identity` return (see the Social Foundation Step 1
/// migration). `blocked` never appears here: both RPCs already exclude a
/// blocked-either-direction pair from their results entirely, rather than
/// surfacing a status Flutter would have to specifically hide.
enum RelationshipStatus {
  /// No friendship row exists yet — show "Add friend".
  none,

  /// The current user sent this request and it hasn't been responded to.
  pendingSent,

  /// The other user sent this request and it's awaiting the current
  /// user's response.
  pendingReceived,

  accepted,

  /// The current user's own outgoing request was declined. Distinct from
  /// [none] so the UI can show "unavailable" rather than a fresh
  /// "Add friend" the RPC would just reject again (see
  /// send_friend_request's own re-request rule).
  declined;

  static RelationshipStatus fromDb(String? value) => switch (value) {
    'accepted' => RelationshipStatus.accepted,
    'pending_sent' => RelationshipStatus.pendingSent,
    'pending_received' => RelationshipStatus.pendingReceived,
    'declined' => RelationshipStatus.declined,
    _ => RelationshipStatus.none,
  };
}

/// Minimal, identity-only view of another profile — everything
/// `search_profiles`/`get_profile_identity` are allowed to return, and
/// nothing else (no email, no visit/rating/photo/trip data ever flows
/// through this model). Used for both search results and the Friend/
/// Non-Friend Profile screen, since both are the exact same shape.
class ProfileIdentity {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final RelationshipStatus relationshipStatus;

  // Only populated by get_profile_identity() (20260925130000_add_member_
  // number_to_profile_identity.sql) — search_profiles() doesn't select
  // this column, so a ProfileIdentity built from a search result always
  // has memberNumber null here, same as the two pre-existing test
  // accounts a real get_profile_identity() call can also legitimately
  // return null for (see 20260925120000_add_profiles_member_number.sql).
  final int? memberNumber;

  const ProfileIdentity({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    required this.relationshipStatus,
    this.memberNumber,
  });

  factory ProfileIdentity.fromRow(Map<String, dynamic> row) => ProfileIdentity(
    id: row['id'] as String,
    username: row['username'] as String?,
    displayName: row['display_name'] as String?,
    avatarUrl: row['avatar_url'] as String?,
    relationshipStatus: RelationshipStatus.fromDb(
      row['relationship_status'] as String?,
    ),
    memberNumber: row['member_number'] as int?,
  );

  /// display_name when set, falling back to @username, falling back to a
  /// neutral label — a profile can legally have neither populated yet.
  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (username != null && username!.isNotEmpty) return '@$username';
    return 'Mantelier member';
  }
}
