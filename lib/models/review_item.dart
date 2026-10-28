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
  venueEventEdit;

  static ReviewKind? fromWire(String value) => switch (value) {
    'venue_claim' => ReviewKind.venueClaim,
    'venue_about' => ReviewKind.venueAbout,
    'venue_photo' => ReviewKind.venuePhoto,
    'venue_event' => ReviewKind.venueEvent,
    'venue_event_edit' => ReviewKind.venueEventEdit,
    _ => null,
  };

  String get label => switch (this) {
    ReviewKind.venueClaim => 'Venue claim',
    ReviewKind.venueAbout => 'About text',
    ReviewKind.venuePhoto => 'Photo',
    ReviewKind.venueEvent => 'Event',
    ReviewKind.venueEventEdit => 'Change to a live event',
  };

  /// The queue's group heading.
  String get heading => switch (this) {
    ReviewKind.venueClaim => 'VENUE CLAIMS',
    ReviewKind.venueAbout => 'ABOUT TEXTS',
    ReviewKind.venuePhoto => 'PHOTOS',
    ReviewKind.venueEvent => 'EVENTS',
    ReviewKind.venueEventEdit => 'CHANGES TO LIVE EVENTS',
  };

  bool get isEvent => this == venueEvent || this == venueEventEdit;
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
    );
  }
}
