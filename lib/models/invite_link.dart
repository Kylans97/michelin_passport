/// Invite links (20261101670000): a member shares `mantelier.app/i/<token>`
/// from a visit, a trip or Friends; whoever accepts becomes their friend
/// and gets the visit or a place on the trip.
library;

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String inviteDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "May 2027", "May to June 2027", "December 2026 to January 2027".
String inviteMonths(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${_months[start.month - 1]} ${start.year}';
  }
  if (start.year == end.year) {
    return '${_months[start.month - 1]} to ${_months[end.month - 1]} ${end.year}';
  }
  return '${_months[start.month - 1]} ${start.year} to '
      '${_months[end.month - 1]} ${end.year}';
}

enum InviteLinkKind {
  friend('friend'),
  visit('visit'),
  trip('trip');

  const InviteLinkKind(this.wire);
  final String wire;

  static InviteLinkKind? fromWire(String? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

/// What a link looks like to whoever opens it. [state] is 'open',
/// 'expired', 'unavailable', 'own', 'accepted', or for a typed code that
/// matched nothing, 'not_found'.
class InviteLinkPreview {
  final String token;
  final String state;
  final InviteLinkKind? kind;
  final bool isGroup;
  final bool needsApproval;
  final String? senderName;
  final String? venueType;
  final String? venueName;
  final String? venueCity;
  final int? michelinStars;
  final int? michelinKeys;
  final DateTime? visitedOn;
  final String? tripTitle;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;
  final String? code;

  const InviteLinkPreview({
    required this.token,
    required this.state,
    this.kind,
    this.isGroup = false,
    this.needsApproval = false,
    this.senderName,
    this.venueType,
    this.venueName,
    this.venueCity,
    this.michelinStars,
    this.michelinKeys,
    this.visitedOn,
    this.tripTitle,
    this.tripStartDate,
    this.tripEndDate,
    this.code,
  });

  bool get isOpen => state == 'open';

  String get sender =>
      (senderName ?? '').trim().isEmpty ? 'A member' : senderName!;
  String get senderFirstName => sender.split(RegExp(r'\s+')).first;

  /// "Hof van Cleve, 14 November 2026" or "Piemonte in May, May 2027".
  String? get targetLine => switch (kind) {
    InviteLinkKind.visit when venueName != null && visitedOn != null =>
      '$venueName, ${inviteDate(visitedOn!)}',
    InviteLinkKind.trip when tripTitle != null && tripStartDate != null =>
      '$tripTitle, ${inviteMonths(tripStartDate!, tripEndDate ?? tripStartDate!)}',
    _ => null,
  };

  /// The message the share sheet starts with. No dashes in copy.
  String shareMessage(String url) {
    final name = sender;
    return switch (kind) {
      InviteLinkKind.visit =>
        '$name invited you to Mantelier. We had '
            '${venueType == 'hotel' ? 'a stay' : 'dinner'} at $venueName on '
            '${inviteDate(visitedOn!)}. Accept and it goes straight into '
            'your Passport.\n$url',
      InviteLinkKind.trip =>
        '$name invited you on a trip: $tripTitle, '
            '${inviteMonths(tripStartDate!, tripEndDate ?? tripStartDate!)}. '
            'Join on Mantelier.\n$url',
      _ =>
        '$name invited you to Mantelier. Find unique events, experience '
            'impeccable hospitality, share memories with friends.\n$url',
    };
  }

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  factory InviteLinkPreview.fromRow(
    Map<String, dynamic> row, {
    String? token,
  }) => InviteLinkPreview(
    token: token ?? (row['token'] as String?) ?? '',
    state: row['state'] as String,
    kind: InviteLinkKind.fromWire(row['kind'] as String?),
    isGroup: (row['is_group'] as bool?) ?? false,
    needsApproval: (row['needs_approval'] as bool?) ?? false,
    senderName: row['sender_name'] as String?,
    venueType: row['venue_type'] as String?,
    venueName: row['venue_name'] as String?,
    venueCity: row['venue_city'] as String?,
    michelinStars: (row['michelin_stars'] as num?)?.toInt(),
    michelinKeys: (row['michelin_keys'] as num?)?.toInt(),
    visitedOn: _date(row['visited_on']),
    tripTitle: row['trip_title'] as String?,
    tripStartDate: _date(row['trip_start_date']),
    tripEndDate: _date(row['trip_end_date']),
    code: row['code'] as String?,
  );
}

/// What redeem_invite_link did.
class InviteLinkResult {
  final InviteLinkKind? kind;
  final bool becameFriends;
  final String? visitId;
  final bool visitAlreadyPresent;
  final String? tripId;

  /// 'joined', 'already_on_trip', 'awaiting_approval', 'sender_left', or
  /// null for a link that isn't a trip's.
  final String? tripState;

  const InviteLinkResult({
    this.kind,
    this.becameFriends = false,
    this.visitId,
    this.visitAlreadyPresent = false,
    this.tripId,
    this.tripState,
  });

  factory InviteLinkResult.fromJson(Map<String, dynamic> json) =>
      InviteLinkResult(
        kind: InviteLinkKind.fromWire(json['kind'] as String?),
        becameFriends: (json['became_friends'] as bool?) ?? false,
        visitId: json['visit_id'] as String?,
        visitAlreadyPresent: (json['visit_already_present'] as bool?) ?? false,
        tripId: json['trip_id'] as String?,
        tripState: json['trip_state'] as String?,
      );
}

/// A link just made, ready for the share sheet.
class CreatedInviteLink {
  final String id;
  final String token;
  final String code;
  final DateTime expiresAt;

  const CreatedInviteLink({
    required this.id,
    required this.token,
    required this.code,
    required this.expiresAt,
  });

  String get url => inviteLinkUrl(token);
}

String inviteLinkUrl(String token) => 'https://mantelier.app/i/$token';

/// One of the caller's own links, for Friends' "Open links".
class MyInviteLink {
  final String id;
  final String token;
  final String code;
  final InviteLinkKind? kind;
  final int maxUses;
  final int useCount;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime createdAt;
  final String? venueName;
  final DateTime? visitedOn;
  final String? tripTitle;
  final String? lastUsedByName;

  const MyInviteLink({
    required this.id,
    required this.token,
    required this.code,
    required this.kind,
    required this.maxUses,
    required this.useCount,
    required this.expiresAt,
    required this.revokedAt,
    required this.createdAt,
    this.venueName,
    this.visitedOn,
    this.tripTitle,
    this.lastUsedByName,
  });

  bool get isGroup => maxUses > 1;
  bool get isRevoked => revokedAt != null;
  bool isExpired(DateTime now) => !expiresAt.isAfter(now);
  bool get isUsedUp => useCount >= maxUses;
  bool isOpen(DateTime now) => !isRevoked && !isExpired(now) && !isUsedUp;

  String get title => switch (kind) {
    InviteLinkKind.visit when venueName != null && visitedOn != null =>
      '$venueName, ${visitedOn!.day} ${_months[visitedOn!.month - 1]}',
    InviteLinkKind.trip when tripTitle != null => tripTitle!,
    _ => 'Friend link',
  };

  factory MyInviteLink.fromRow(Map<String, dynamic> row) => MyInviteLink(
    id: row['id'] as String,
    token: row['token'] as String,
    code: row['code'] as String,
    kind: InviteLinkKind.fromWire(row['kind'] as String?),
    maxUses: (row['max_uses'] as num).toInt(),
    useCount: (row['use_count'] as num).toInt(),
    expiresAt: DateTime.parse(row['expires_at'] as String),
    revokedAt: row['revoked_at'] == null
        ? null
        : DateTime.parse(row['revoked_at'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
    venueName: row['venue_name'] as String?,
    visitedOn: row['visited_on'] == null
        ? null
        : DateTime.parse(row['visited_on'] as String),
    tripTitle: row['trip_title'] as String?,
    lastUsedByName: row['last_used_by_name'] as String?,
  );
}

/// One person who used one of the caller's links.
class InviteLinkUse {
  final String id;
  final String userId;
  final String? username;
  final String? displayName;

  /// 'approved', 'awaiting_approval', 'declined' or 'removed'.
  final String status;
  final DateTime redeemedAt;

  const InviteLinkUse({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.status,
    required this.redeemedAt,
  });

  String get label => (displayName ?? '').trim().isNotEmpty
      ? displayName!
      : (username != null ? '@$username' : 'A member');

  factory InviteLinkUse.fromRow(Map<String, dynamic> row) => InviteLinkUse(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    username: row['username'] as String?,
    displayName: row['display_name'] as String?,
    status: row['status'] as String,
    redeemedAt: DateTime.parse(row['redeemed_at'] as String),
  );
}

/// The token in a `mantelier.app/i/<token>` link, or in pasted text that
/// contains one; null when there is none.
String? inviteTokenFrom(String? text) {
  if (text == null) return null;
  final match = RegExp(
    r'mantelier\.app/i/([A-Za-z0-9_-]{16,64})',
  ).firstMatch(text);
  return match?.group(1);
}
