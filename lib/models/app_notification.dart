/// The notification types this app can create today — wire values match
/// `notifications.type`'s own CHECK constraint exactly (see the
/// migration). `push` is a separate, later project; this enum is purely
/// about what's already stored, not about how it might one day be
/// delivered outside the app.
enum AppNotificationType {
  friendRequestReceived,
  friendRequestAccepted,
  missingListingAdded,
  venueInviteReceived,
  venueInviteAccepted,
  venueInviteDeclined;

  static AppNotificationType fromWire(String value) => switch (value) {
    'friend_request_received' => AppNotificationType.friendRequestReceived,
    'friend_request_accepted' => AppNotificationType.friendRequestAccepted,
    'missing_listing_added' => AppNotificationType.missingListingAdded,
    'venue_invite_received' => AppNotificationType.venueInviteReceived,
    'venue_invite_accepted' => AppNotificationType.venueInviteAccepted,
    'venue_invite_declined' => AppNotificationType.venueInviteDeclined,
    _ => throw ArgumentError('Unknown notification type: $value'),
  };
}

/// One row from `get_notifications()` — already joined with per-type
/// display context server-side (see the RPC's own comment for why a
/// plain client-side join can't do this: `profiles_read` is fully
/// owner-only, so a friend-request notification's "other person" is only
/// reachable through this security-definer function, same as
/// FriendRequest/Friendship elsewhere in this app).
///
/// Only the fields relevant to [type] are ever non-null — a
/// [friendRequestReceived]/[friendRequestAccepted] notification carries
/// the `other*` fields, a [missingListingAdded] one carries the
/// `listing*` fields, a [venueInviteReceived]/[venueInviteAccepted]/
/// [venueInviteDeclined] one carries both `other*` (the invite's other
/// participant) and `invite*`, never all three groups at once.
class AppNotification {
  final String id;
  final AppNotificationType type;
  final String subjectType;
  final String subjectId;
  final bool isRead;
  final DateTime createdAt;

  final String? otherUserId;
  final String? otherUsername;
  final String? otherDisplayName;
  final String? otherAvatarUrl;

  final String? listingSubjectType;
  final String? listingName;
  final String? listingCity;

  // subjectId doubles as the invite id when subjectType == 'venue_invite'
  // (same convention `_accept`/`_decline` already use for friendship rows
  // in NotificationsScreen) — no separate inviteId field needed.
  final String? inviteVenueType;
  final String? inviteVenueId;
  final String? inviteVenueName;
  final String? inviteVenueCity;
  final String? inviteNote;
  final String? inviteStatus;
  final DateTime? inviteExpiresAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.subjectType,
    required this.subjectId,
    required this.isRead,
    required this.createdAt,
    this.otherUserId,
    this.otherUsername,
    this.otherDisplayName,
    this.otherAvatarUrl,
    this.listingSubjectType,
    this.listingName,
    this.listingCity,
    this.inviteVenueType,
    this.inviteVenueId,
    this.inviteVenueName,
    this.inviteVenueCity,
    this.inviteNote,
    this.inviteStatus,
    this.inviteExpiresAt,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) => AppNotification(
    id: row['id'] as String,
    type: AppNotificationType.fromWire(row['type'] as String),
    subjectType: row['subject_type'] as String,
    subjectId: row['subject_id'] as String,
    isRead: row['is_read'] as bool,
    createdAt: DateTime.parse(row['created_at'] as String),
    otherUserId: row['other_user_id'] as String?,
    otherUsername: row['other_username'] as String?,
    otherDisplayName: row['other_display_name'] as String?,
    otherAvatarUrl: row['other_avatar_url'] as String?,
    listingSubjectType: row['listing_subject_type'] as String?,
    listingName: row['listing_name'] as String?,
    listingCity: row['listing_city'] as String?,
    inviteVenueType: row['invite_venue_type'] as String?,
    inviteVenueId: row['invite_venue_id'] as String?,
    inviteVenueName: row['invite_venue_name'] as String?,
    inviteVenueCity: row['invite_venue_city'] as String?,
    inviteNote: row['invite_note'] as String?,
    inviteStatus: row['invite_status'] as String?,
    inviteExpiresAt: row['invite_expires_at'] == null
        ? null
        : DateTime.parse(row['invite_expires_at'] as String),
  );

  /// True only for a still-`pending` invite whose [inviteExpiresAt] has
  /// passed — never a stored status, computed at read time (see
  /// send_venue_invite's own migration comment for why). The recipient's
  /// row for it must stay visible and marked "Expired", never disappear —
  /// confirmed as an explicit product requirement, not a default guess.
  bool get inviteIsExpired =>
      inviteStatus == 'pending' &&
      inviteExpiresAt != null &&
      inviteExpiresAt!.isBefore(DateTime.now());

  /// Same fallback order as Friendship/FriendRequest.label elsewhere in
  /// this app: a real name, then "@username", then a neutral default —
  /// never a blank row.
  String get otherLabel {
    final name = otherDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final username = otherUsername?.trim();
    if (username != null && username.isNotEmpty) return '@$username';
    return 'Mantelier member';
  }
}
