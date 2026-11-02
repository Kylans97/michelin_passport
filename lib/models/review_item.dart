import 'photo_framing.dart';

/// What a review item is. Mirrors get_review_queue()'s `kind`
/// (20261017120000; the two event kinds from 20261018130000). Event
/// photos join in phase 4 of
/// docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md.
enum ReviewKind {
  venueClaim,
  venueAbout,
  venuePhoto,

  /// A venue's event, submitted or resubmitted, waiting for approval.
  venueEvent,

  /// A change a venue made to its live event: already live, shown so an
  /// admin sees it, and can take the event offline if it's wrong.
  venueEventEdit,

  /// A name, a text and optionally a portrait for a venue's chef,
  /// manager or sommelier (20261030170000; portraits and sommelier from
  /// 20261101170000).
  venueTeam,

  /// A venue's Instagram account (20261101170000).
  venueInstagram,

  /// A website or phone number a venue changed itself: already live,
  /// shown so an admin can check it now and then (20261101190000).
  venueContactEdit,

  /// A photo, rating, profile or event a member reported.
  contentReport,

  /// A venue or event a member couldn't find in Explore.
  missingListing;

  static ReviewKind? fromWire(String value) => switch (value) {
    'venue_claim' => ReviewKind.venueClaim,
    'venue_about' => ReviewKind.venueAbout,
    'venue_photo' => ReviewKind.venuePhoto,
    'venue_event' => ReviewKind.venueEvent,
    'venue_event_edit' => ReviewKind.venueEventEdit,
    'venue_team' => ReviewKind.venueTeam,
    'venue_instagram' => ReviewKind.venueInstagram,
    'venue_contact_edit' => ReviewKind.venueContactEdit,
    'content_report' => ReviewKind.contentReport,
    'missing_listing' => ReviewKind.missingListing,
    _ => null,
  };

  String get label => switch (this) {
    ReviewKind.venueClaim => 'Venue claim',
    ReviewKind.venueAbout => 'About text',
    ReviewKind.venuePhoto => 'Photo',
    ReviewKind.venueEvent => 'Event',
    ReviewKind.venueEventEdit => 'Change to a live event',
    ReviewKind.venueTeam => 'Team',
    ReviewKind.venueInstagram => 'Instagram',
    ReviewKind.venueContactEdit => 'Website or phone changed',
    ReviewKind.contentReport => 'Report',
    ReviewKind.missingListing => 'Missing listing',
  };

  /// The queue's group heading.
  String get heading => switch (this) {
    ReviewKind.venueClaim => 'VENUE CLAIMS',
    ReviewKind.venueAbout => 'ABOUT TEXTS',
    ReviewKind.venuePhoto => 'PHOTOS',
    ReviewKind.venueEvent => 'NEW EVENTS',
    ReviewKind.venueEventEdit => 'CHANGES TO LIVE EVENTS',
    ReviewKind.venueTeam => 'TEAM',
    ReviewKind.venueInstagram => 'INSTAGRAM',
    ReviewKind.venueContactEdit => 'WEBSITE AND PHONE CHANGES',
    ReviewKind.contentReport => 'REPORTED BY MEMBERS',
    ReviewKind.missingListing => 'MISSING LISTINGS',
  };

  bool get isEvent => this == venueEvent || this == venueEventEdit;

  /// Already live or nothing to approve: an admin marks it dealt with
  /// instead of approving or rejecting it.
  bool get isAcknowledgeOnly =>
      this == venueContactEdit || this == contentReport || this == missingListing;

  ReviewTopic get topic => switch (this) {
    ReviewKind.venueClaim => ReviewTopic.claims,
    ReviewKind.venueAbout ||
    ReviewKind.venueTeam ||
    ReviewKind.venueInstagram => ReviewTopic.profiles,
    ReviewKind.venuePhoto => ReviewTopic.photos,
    ReviewKind.venueEvent || ReviewKind.venueEventEdit => ReviewTopic.events,
    ReviewKind.venueContactEdit => ReviewTopic.contact,
    ReviewKind.contentReport || ReviewKind.missingListing => ReviewTopic.reports,
  };
}

/// The review queue's tabs, one per topic, so no topic disappears under
/// a long list of another (decided 2026-11-02).
enum ReviewTopic {
  claims('Claims'),
  profiles('Profiles'),
  photos('Photos'),
  events('Events'),
  contact('Contact'),
  reports('Reports');

  final String label;
  const ReviewTopic(this.label);
}

/// One field a venue changed on its live event: what it was, what it is.
class ReviewEventChange {
  final String field;
  final Object? oldValue;
  final Object? newValue;
  const ReviewEventChange(this.field, this.oldValue, this.newValue);
}

/// One thing waiting for an admin, as get_review_queue() returns it.
class ReviewItem {
  final ReviewKind kind;
  final String itemId;
  final String venueType;
  final String venueId;
  final String venueName;
  final String? venueCity;
  final String submittedBy;
  final String submitterLabel;
  final DateTime submittedAt;

  // venueClaim
  final String? claimRole;
  final String? claimBusinessEmail;
  final String? claimPhone;
  final String? claimNotes;

  // venueAbout
  final String? aboutText;

  // venuePhoto
  final String? photoStoragePath;
  final String? photoReplacesPhotoId;
  final String? photoDuplicateOf;
  final PhotoFraming photoFraming;

  // venueEvent / venueEventEdit
  final String? eventId;
  final String? eventName;
  final DateTime? eventStartDate;
  final List<ReviewEventChange> eventChanges;

  // venueTeam
  final String? teamRole;
  final String? teamName;
  final String? teamBio;

  /// A new portrait, in the private bucket; null when the submission
  /// keeps the current one. [teamRemovePhoto] asks to take it off.
  final String? teamPhotoPath;
  final bool teamRemovePhoto;

  final String? instagramHandle;

  // venueContactEdit
  final String? contactField;
  final String? contactOldValue;
  final String? contactNewValue;

  // contentReport
  final String? reportContentType;
  final String? reportContentId;
  final String? reportReason;
  final String? reportDetails;

  // missingListing
  final String? missingSubjectType;
  final String? missingName;
  final String? missingCity;
  final String? missingMessage;
  final bool missingWorksHere;
  final String? missingReporterRole;
  final String? missingReporterContact;

  /// Whether the server named a venue for this item; a missing listing
  /// and most reports have none.
  bool get hasVenue => venueType.isNotEmpty && venueId.isNotEmpty;

  /// The queue row's first line.
  String get rowTitle => switch (kind) {
    ReviewKind.venueEvent || ReviewKind.venueEventEdit =>
      eventName ?? 'Untitled event',
    ReviewKind.missingListing =>
      '${missingName ?? 'Unnamed'} · ${missingCity ?? ''}',
    ReviewKind.contentReport =>
      'A reported ${reportContentType ?? 'item'}'
          '${eventName != null ? ': $eventName' : ''}',
    _ => [venueName, ?venueCity].join(' · '),
  };

  const ReviewItem({
    required this.kind,
    required this.itemId,
    required this.venueType,
    required this.venueId,
    required this.venueName,
    this.venueCity,
    required this.submittedBy,
    required this.submitterLabel,
    required this.submittedAt,
    this.claimRole,
    this.claimBusinessEmail,
    this.claimPhone,
    this.claimNotes,
    this.aboutText,
    this.photoStoragePath,
    this.photoReplacesPhotoId,
    this.photoDuplicateOf,
    this.photoFraming = PhotoFraming.center,
    this.eventId,
    this.eventName,
    this.eventStartDate,
    this.eventChanges = const [],
    this.teamRole,
    this.teamName,
    this.teamBio,
    this.teamPhotoPath,
    this.teamRemovePhoto = false,
    this.instagramHandle,
    this.contactField,
    this.contactOldValue,
    this.contactNewValue,
    this.reportContentType,
    this.reportContentId,
    this.reportReason,
    this.reportDetails,
    this.missingSubjectType,
    this.missingName,
    this.missingCity,
    this.missingMessage,
    this.missingWorksHere = false,
    this.missingReporterRole,
    this.missingReporterContact,
  });

  /// Null for a kind this build doesn't know yet (a newer server), so
  /// the queue skips it instead of failing.
  static ReviewItem? fromJson(Map<String, dynamic> json) {
    final kind = ReviewKind.fromWire(json['kind'] as String);
    if (kind == null) return null;
    return ReviewItem(
      kind: kind,
      itemId: json['item_id'].toString(),
      venueType: (json['venue_type'] as String?) ?? '',
      venueId: (json['venue_id'] ?? '').toString(),
      venueName: (json['venue_name'] as String?) ?? 'Unknown venue',
      venueCity: json['venue_city'] as String?,
      submittedBy: json['submitted_by'].toString(),
      submitterLabel:
          (json['submitter_label'] as String?) ?? 'Mantelier member',
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      claimRole: json['claim_role'] as String?,
      claimBusinessEmail: json['claim_business_email'] as String?,
      claimPhone: json['claim_phone'] as String?,
      claimNotes: json['claim_notes'] as String?,
      aboutText: json['about_text'] as String?,
      photoStoragePath: json['photo_storage_path'] as String?,
      photoReplacesPhotoId: json['photo_replaces_photo_id']?.toString(),
      photoDuplicateOf: json['photo_duplicate_of']?.toString(),
      photoFraming: PhotoFraming.fromJson(json, prefix: 'photo_'),
      eventId: json['event_id']?.toString(),
      eventName: json['event_name'] as String?,
      eventStartDate: json['event_start_date'] == null
          ? null
          : DateTime.parse('${json['event_start_date']}T00:00:00Z'),
      eventChanges: [
        for (final entry
            in ((json['event_changes'] as Map?) ?? const {}).entries)
          ReviewEventChange(
            entry.key as String,
            (entry.value as Map?)?['old'],
            (entry.value as Map?)?['new'],
          ),
      ]..sort((a, b) => a.field.compareTo(b.field)),
      teamRole: json['team_role'] as String?,
      teamName: json['team_name'] as String?,
      teamBio: json['team_bio'] as String?,
      teamPhotoPath: json['team_photo_path'] as String?,
      teamRemovePhoto: (json['team_remove_photo'] as bool?) ?? false,
      instagramHandle: json['instagram_handle'] as String?,
      contactField: json['contact_field'] as String?,
      contactOldValue: json['contact_old_value'] as String?,
      contactNewValue: json['contact_new_value'] as String?,
      reportContentType: json['report_content_type'] as String?,
      reportContentId: json['report_content_id']?.toString(),
      reportReason: json['report_reason'] as String?,
      reportDetails: json['report_details'] as String?,
      missingSubjectType: json['missing_subject_type'] as String?,
      missingName: json['missing_name'] as String?,
      missingCity: json['missing_city'] as String?,
      missingMessage: json['missing_message'] as String?,
      missingWorksHere: (json['missing_works_here'] as bool?) ?? false,
      missingReporterRole: json['missing_reporter_role'] as String?,
      missingReporterContact: json['missing_reporter_contact'] as String?,
    );
  }
}
