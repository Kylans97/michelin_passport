import 'photo_framing.dart';

/// What a review item is. Mirrors get_review_queue()'s `kind`
/// (20261017120000). Events and event photos join in phase 3/4 of
/// docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md.
enum ReviewKind {
  venueClaim,
  venueAbout,
  venuePhoto;

  static ReviewKind? fromWire(String value) => switch (value) {
    'venue_claim' => ReviewKind.venueClaim,
    'venue_about' => ReviewKind.venueAbout,
    'venue_photo' => ReviewKind.venuePhoto,
    _ => null,
  };

  String get label => switch (this) {
    ReviewKind.venueClaim => 'Venue claim',
    ReviewKind.venueAbout => 'About text',
    ReviewKind.venuePhoto => 'Photo',
  };
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
  });

  /// Null for a kind this build doesn't know yet (a newer server), so
  /// the queue skips it instead of failing.
  static ReviewItem? fromJson(Map<String, dynamic> json) {
    final kind = ReviewKind.fromWire(json['kind'] as String);
    if (kind == null) return null;
    return ReviewItem(
      kind: kind,
      itemId: json['item_id'].toString(),
      venueType: json['venue_type'] as String,
      venueId: json['venue_id'].toString(),
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
    );
  }
}
