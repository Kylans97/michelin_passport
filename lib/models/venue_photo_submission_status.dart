/// `pending`/`approved`/`rejected` — matches venue_photo_submissions' own
/// status CHECK constraint exactly. Mirrors VenueAboutSubmissionStatus's
/// own shape (no `blocked` fourth value here either, for the same
/// reason: a bad-faith photo just gets rejected, there is no separate
/// "blocked from submitting again" concept on this table). The app never
/// sets any status past `pending` itself.
enum VenuePhotoSubmissionStatus {
  pending,
  approved,
  rejected;

  static VenuePhotoSubmissionStatus fromWire(String value) => VenuePhotoSubmissionStatus.values
      .firstWhere((v) => v.name == value, orElse: () => VenuePhotoSubmissionStatus.pending);
}

/// One row read back from venue_photo_submissions — a manager's own
/// pending or rejected photo, with enough to show its status and (when
/// rejected) the reviewer's own note. Approved submissions are not
/// surfaced through this model at all — once approved, the photo lives
/// in the published set (PublishedVenuePhoto) instead, and this row's
/// only remaining purpose is history.
class VenuePhotoSubmissionSummary {
  final String id;
  final String storagePath;
  final VenuePhotoSubmissionStatus status;
  final String? reviewNote;
  final DateTime submittedAt;

  /// The published photo this submission will replace once approved, or
  /// null when the venue was under the 5-photo cap at submission time —
  /// mirrors venue_photo_submissions.replaces_photo_id exactly (already
  /// existed on the table; this is the first client-side reader of it).
  /// Not shown anywhere in VenueManagementScreen's own UI today — added
  /// so the owner preview's photo-order merge can mirror
  /// approve_venue_photo's own swap-vs-append rule (see
  /// venue_preview_photo_merge.dart).
  final String? replacesPhotoId;

  const VenuePhotoSubmissionSummary({
    required this.id,
    required this.storagePath,
    required this.status,
    this.reviewNote,
    required this.submittedAt,
    this.replacesPhotoId,
  });

  factory VenuePhotoSubmissionSummary.fromJson(Map<String, dynamic> json) =>
      VenuePhotoSubmissionSummary(
        id: json['id'].toString(),
        storagePath: json['storage_path'] as String,
        status: VenuePhotoSubmissionStatus.fromWire(json['status'] as String),
        reviewNote: json['review_note'] as String?,
        submittedAt: DateTime.parse(json['submitted_at'] as String),
        replacesPhotoId: json['replaces_photo_id'] as String?,
      );
}
