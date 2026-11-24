/// Invite links (20261101670000): a member shares `mantelier.app/i/<token>`
/// from a visit, a trip or Friends; whoever accepts becomes their friend
/// and gets the visit or a place on the trip. A venue's managers share
/// the venue's own standing link (20261101750000); whoever opens it
/// follows the venue, and nothing else.
library;

import 'photo_framing.dart';

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
  trip('trip'),
  venue('venue');

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
/// 'expired', 'unavailable', 'own', 'accepted', for a venue the viewer
/// already follows 'following', or for a typed code that matched nothing,
/// 'not_found'.
class InviteLinkPreview {
  final String token;
  final String state;
  final InviteLinkKind? kind;
  final bool isGroup;
  final bool needsApproval;
  final String? senderName;
  final String? venueType;

  /// For a venue link only: what to open after following.
  final String? venueId;
  final String? venueName;
  final String? venueCity;
  final String? venueCountry;
  final int? michelinStars;
  final int? michelinKeys;
  final DateTime? visitedOn;
  final String? tripTitle;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;
  final String? code;

  /// A venue link's card photo, cropped as the venue framed it.
  final String? cardPhotoUrl;
  final PhotoFraming cardFraming;

  const InviteLinkPreview({
    required this.token,
    required this.state,
    this.kind,
    this.isGroup = false,
    this.needsApproval = false,
    this.senderName,
    this.venueType,
    this.venueId,
    this.venueName,
    this.venueCity,
    this.venueCountry,
    this.michelinStars,
    this.michelinKeys,
    this.visitedOn,
    this.tripTitle,
    this.tripStartDate,
    this.tripEndDate,
    this.code,
    this.cardPhotoUrl,
    this.cardFraming = PhotoFraming.center,
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

  /// "Kruishoutem, Belgium", as far as it is known.
  String? get venuePlace {
    final parts = [
      venueCity,
      venueCountry,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// The message the share sheet starts with. No dashes in copy.
  String shareMessage(String url) {
    final name = sender;
    return switch (kind) {
      InviteLinkKind.venue => venueShareMessage(venueName ?? 'We', url),
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
    venueId: row['venue_id'] as String?,
    venueName: row['venue_name'] as String?,
    venueCity: row['venue_city'] as String?,
    venueCountry: row['venue_country'] as String?,
    michelinStars: (row['michelin_stars'] as num?)?.toInt(),
    michelinKeys: (row['michelin_keys'] as num?)?.toInt(),
    visitedOn: _date(row['visited_on']),
    tripTitle: row['trip_title'] as String?,
    tripStartDate: _date(row['trip_start_date']),
    tripEndDate: _date(row['trip_end_date']),
    code: row['code'] as String?,
    cardPhotoUrl: row['card_photo_url'] as String?,
    cardFraming: PhotoFraming(
      focusX: (row['card_focus_x'] as num?)?.toDouble() ?? 0.5,
      focusY: (row['card_focus_y'] as num?)?.toDouble() ?? 0.5,
      zoom: (row['card_zoom'] as num?)?.toDouble() ?? 1,
    ),
  );
}

/// What a venue's link says when its manager shares it. It speaks for the
/// venue: whoever shares it is never named. No dashes in copy.
String venueShareMessage(String venueName, String url) =>
    '$venueName invites you to follow them on Mantelier, for their events '
    'and evenings worth keeping.\n$url';

/// A venue's standing link, for its managers (get_venue_invite_link).
/// [followedCount] is null under 5: the venue never sees small numbers,
/// and never who.
class VenueInviteLink {
  final String? token;
  final String? code;
  final DateTime? createdAt;
  final int? followedCount;
  final DateTime? followedSince;

  const VenueInviteLink({
    this.token,
    this.code,
    this.createdAt,
    this.followedCount,
    this.followedSince,
  });

  String? get url => token == null ? null : inviteLinkUrl(token!);

  /// "23 followed through your link", "Fewer than 5 so far", or for a
  /// venue that never made one, "Not shared yet".
  String get summary {
    if (followedSince == null) return 'Not shared yet';
    final n = followedCount;
    if (n == null) return 'Fewer than 5 followed so far';
    return '$n followed through your link';
  }

  /// "R4CW 7KMB": two blocks of four, easier to read aloud or type.
  String? get displayCode => code == null || code!.length != 8
      ? code
      : '${code!.substring(0, 4)} ${code!.substring(4)}';

  factory VenueInviteLink.fromRow(Map<String, dynamic> row) => VenueInviteLink(
    token: row['token'] as String?,
    code: row['code'] as String?,
    createdAt: row['created_at'] == null
        ? null
        : DateTime.parse(row['created_at'] as String),
    followedCount: (row['followed_count'] as num?)?.toInt(),
    followedSince: row['followed_since'] == null
        ? null
        : DateTime.parse(row['followed_since'] as String),
  );
}

/// What redeem_invite_link did.
class InviteLinkResult {
  final InviteLinkKind? kind;
  final bool becameFriends;
  final String? visitId;
  final bool visitAlreadyPresent;
  final String? tripId;

  /// For a venue link: the venue now followed.
  final String? venueType;
  final String? venueId;

  /// 'joined', 'already_on_trip', 'awaiting_approval', 'sender_left', or
  /// null for a link that isn't a trip's.
  final String? tripState;

  const InviteLinkResult({
    this.kind,
    this.becameFriends = false,
    this.visitId,
    this.visitAlreadyPresent = false,
    this.tripId,
    this.venueType,
    this.venueId,
    this.tripState,
  });

  factory InviteLinkResult.fromJson(Map<String, dynamic> json) =>
      InviteLinkResult(
        kind: InviteLinkKind.fromWire(json['kind'] as String?),
        becameFriends: (json['became_friends'] as bool?) ?? false,
        visitId: json['visit_id'] as String?,
        visitAlreadyPresent: (json['visit_already_present'] as bool?) ?? false,
        tripId: json['trip_id'] as String?,
        venueType: json['venue_type'] as String?,
        venueId: json['venue_id'] as String?,
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
    _ => isGroup ? 'Group link for $maxUses' : 'Personal link',
  };

  /// "12 days left", "Last day", or why it no longer works.
  String timeLine(DateTime now) {
    if (isRevoked) return 'Cancelled';
    if (isExpired(now)) return 'Expired';
    if (isUsedUp) return 'Used';
    final days = (expiresAt.difference(now).inHours / 24).ceil();
    return days <= 1 ? 'Last day' : '$days days left';
  }

  /// The line under [title]: "Personal link · 13 days left" style, e.g.
  /// "12 days left", "3 of 8 joined · 12 days left", or for a visit or
  /// trip shared with a group, "Group link for 8 · 12 days left".
  String statusLine(DateTime now) {
    final usage = [
      if (isGroup && useCount > 0) '$useCount of $maxUses joined',
      if (!isGroup && useCount > 0 && lastUsedByName != null)
        'Accepted by $lastUsedByName',
    ];
    // "Used" says nothing the line about who used it hasn't.
    final time = isUsedUp && !isRevoked && usage.isNotEmpty
        ? null
        : timeLine(now);
    return [
      if (isGroup && kind != InviteLinkKind.friend) 'Group link for $maxUses',
      ...usage,
      ?time,
    ].join(' · ');
  }

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
