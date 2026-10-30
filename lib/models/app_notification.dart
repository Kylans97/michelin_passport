/// The notification types this app can create today — wire values match
/// `notifications.type`'s own CHECK constraint exactly (see the
/// migration). Push (20261030130000) delivers some of these to the phone
/// as well; this enum is about what's stored, which is the same either way.
enum AppNotificationType {
  friendRequestReceived,
  friendRequestAccepted,
  missingListingAdded,
  venueInviteReceived,
  venueInviteAccepted,
  venueInviteDeclined,
  venueClaimReceived,
  venueClaimApproved,
  // Deliberately no separate "blocked" case — the database trigger fires
  // this exact same type for both a rejected and a blocked claim (that
  // distinction is information for the reviewer, not the requester; see
  // notify_venue_claim_change()'s own migration comment), so there is
  // nothing for this enum to distinguish either.
  venueClaimRejected,
  // The review loop's missing link: notify_venue_submission_review()
  // fires these on venue_about_submissions/venue_photo_submissions going
  // pending -> approved/rejected — see that trigger's own migration
  // comment for why there is no "received" counterpart to these four
  // (unlike the claim types above): the in-app confirmation shown at
  // submission time already covers that half.
  venueAboutApproved,
  venueAboutRejected,
  venuePhotoApproved,
  venuePhotoRejected,
  // A venue's own event (20261018130000): admin_approve_event /
  // admin_reject_event notify the submitter. Only get_notifications_v2
  // returns these; get_notifications() hides them from older builds.
  eventApproved,
  eventRejected,
  // Shared trips (20261022120000): invite_to_trip notifies the invitee,
  // respond_to_trip_invite the inviter when they accept. Only
  // get_notifications_v3 returns these.
  tripInviteReceived,
  tripInviteAccepted,
  // A venue the recipient follows published an event (20261030130000):
  // fanned out to the host venue's followers. Only get_notifications_v4
  // returns it.
  followedVenueEvent;

  static AppNotificationType fromWire(String value) => switch (value) {
    'friend_request_received' => AppNotificationType.friendRequestReceived,
    'friend_request_accepted' => AppNotificationType.friendRequestAccepted,
    'missing_listing_added' => AppNotificationType.missingListingAdded,
    'venue_invite_received' => AppNotificationType.venueInviteReceived,
    'venue_invite_accepted' => AppNotificationType.venueInviteAccepted,
    'venue_invite_declined' => AppNotificationType.venueInviteDeclined,
    'venue_claim_received' => AppNotificationType.venueClaimReceived,
    'venue_claim_approved' => AppNotificationType.venueClaimApproved,
    'venue_claim_rejected' => AppNotificationType.venueClaimRejected,
    'venue_about_approved' => AppNotificationType.venueAboutApproved,
    'venue_about_rejected' => AppNotificationType.venueAboutRejected,
    'venue_photo_approved' => AppNotificationType.venuePhotoApproved,
    'venue_photo_rejected' => AppNotificationType.venuePhotoRejected,
    'event_approved' => AppNotificationType.eventApproved,
    'event_rejected' => AppNotificationType.eventRejected,
    'trip_invite_received' => AppNotificationType.tripInviteReceived,
    'trip_invite_accepted' => AppNotificationType.tripInviteAccepted,
    'followed_venue_event' => AppNotificationType.followedVenueEvent,
    _ => throw ArgumentError('Unknown notification type: $value'),
  };

  /// [fromWire], but null for a type this build doesn't know — a newer
  /// server's — so the list skips that one row instead of failing whole.
  static AppNotificationType? tryFromWire(String value) {
    try {
      return fromWire(value);
    } on ArgumentError {
      return null;
    }
  }
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
/// participant) and `invite*`, a [venueClaimReceived]/
/// [venueClaimApproved]/[venueClaimRejected] one carries only `claim*` —
/// there is no "other person" on a claim, it's a status update about the
/// claimant's own request — and a [venueAboutApproved]/
/// [venueAboutRejected]/[venuePhotoApproved]/[venuePhotoRejected] one
/// carries only `submission*`, same reasoning as claims.
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

  // subjectId doubles as the claim id when subjectType == 'venue_claim' —
  // same convention as inviteVenueId above. claimReviewNote mirrors
  // submissionReviewNote's own rule below — only ever non-null on a
  // rejected (or blocked) claim, written by reject_venue_claim.
  final String? claimVenueType;
  final String? claimVenueId;
  final String? claimVenueName;
  final String? claimVenueCity;
  final String? claimReviewNote;

  // subjectId doubles as the submission id when subjectType ==
  // 'venue_about_submission'/'venue_photo_submission' — same convention
  // as inviteVenueId/claimVenueId above. submissionReviewNote is only
  // ever non-null on a rejected submission (approve_venue_about/
  // approve_venue_photo never write one) — how the rejection
  // notification carries the reviewer's note.
  final String? submissionVenueType;
  final String? submissionVenueId;
  final String? submissionVenueName;
  final String? submissionVenueCity;
  final String? submissionReviewNote;

  // The friendship's CURRENT status when subjectType == 'friendship'
  // (20261012120000): 'pending'/'accepted'/'declined'/'blocked', or null
  // once the friendship row is gone (cancelled by the sender, or
  // removed). [hasFriendshipStatus] is false when the server predates
  // that column — the only way to tell "no such column" from "row gone".
  final String? friendshipStatus;
  final bool hasFriendshipStatus;

  // subjectId doubles as the event id when subjectType == 'event'
  // (get_notifications_v2). eventReviewNote is only ever set on a
  // rejected event — the note admin_reject_event requires.
  final String? eventName;
  final DateTime? eventStartDate;
  final String? eventReviewNote;
  final String? eventVenueName;

  // subjectId doubles as the planned_trip_members id when subjectType ==
  // 'planned_trip_member' (get_notifications_v3) — what
  // respond_to_trip_invite takes. tripMemberStatus is the membership's
  // CURRENT status ('pending'/'accepted'/'declined'), or null once it's
  // gone (withdrawn, removed, trip deleted).
  final String? tripId;
  final String? tripTitle;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;
  final String? tripMemberStatus;

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
    this.claimVenueType,
    this.claimVenueId,
    this.claimVenueName,
    this.claimVenueCity,
    this.claimReviewNote,
    this.submissionVenueType,
    this.submissionVenueId,
    this.submissionVenueName,
    this.submissionVenueCity,
    this.submissionReviewNote,
    this.friendshipStatus,
    this.hasFriendshipStatus = false,
    this.eventName,
    this.eventStartDate,
    this.eventReviewNote,
    this.eventVenueName,
    this.tripId,
    this.tripTitle,
    this.tripStartDate,
    this.tripEndDate,
    this.tripMemberStatus,
  });

  /// [fromRow], but null for a notification type this build doesn't know.
  static AppNotification? tryFromRow(Map<String, dynamic> row) {
    if (AppNotificationType.tryFromWire(row['type'] as String) == null) return null;
    return AppNotification.fromRow(row);
  }

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
    claimVenueType: row['claim_venue_type'] as String?,
    claimVenueId: row['claim_venue_id'] as String?,
    claimVenueName: row['claim_venue_name'] as String?,
    claimVenueCity: row['claim_venue_city'] as String?,
    claimReviewNote: row['claim_review_note'] as String?,
    submissionVenueType: row['submission_venue_type'] as String?,
    submissionVenueId: row['submission_venue_id'] as String?,
    submissionVenueName: row['submission_venue_name'] as String?,
    submissionVenueCity: row['submission_venue_city'] as String?,
    submissionReviewNote: row['submission_review_note'] as String?,
    friendshipStatus: row['friendship_status'] as String?,
    hasFriendshipStatus: row.containsKey('friendship_status'),
    eventName: row['event_name'] as String?,
    eventStartDate: row['event_start_date'] == null
        ? null
        : DateTime.parse('${row['event_start_date']}T00:00:00Z'),
    eventReviewNote: row['event_review_note'] as String?,
    eventVenueName: row['event_venue_name'] as String?,
    tripId: row['trip_id'] as String?,
    tripTitle: row['trip_title'] as String?,
    tripStartDate: row['trip_start_date'] == null
        ? null
        : DateTime.parse(row['trip_start_date'] as String),
    tripEndDate: row['trip_end_date'] == null
        ? null
        : DateTime.parse(row['trip_end_date'] as String),
    tripMemberStatus: row['trip_member_status'] as String?,
  );

  /// Whether a friend_request_received row should still offer
  /// Accept/Decline. Against a server that predates friendship_status it
  /// keeps the old always-offer behaviour, so this build and that
  /// migration can ship in either order.
  bool get friendRequestIsPending =>
      !hasFriendshipStatus || friendshipStatus == 'pending';

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
