/// `pending`/`approved`/`rejected` — matches venue_about_submissions'
/// own status CHECK constraint exactly (no `blocked` fourth value here,
/// unlike VenueClaimStatus — a bad-faith about-text submission just gets
/// rejected; there's no separate "user is blocked from ever submitting
/// again" concept on this table). The app never sets any status past
/// `pending` itself; `approved`/`rejected` only ever arrive by being read
/// back from a row a human reviewer changed via the Supabase dashboard.
enum VenueAboutSubmissionStatus {
  pending,
  approved,
  rejected;

  static VenueAboutSubmissionStatus fromWire(String value) =>
      VenueAboutSubmissionStatus.values.firstWhere(
        (v) => v.name == value,
        orElse: () => VenueAboutSubmissionStatus.pending,
      );
}

/// One row read back from venue_about_submissions — just enough to show
/// "here's your most recent submission for this venue and its status,"
/// not a full mirror of the table. The venue's CURRENT (live, approved)
/// about text is a separate, simpler read — see
/// VenueAboutRepository.loadCurrentText(), backed by the venue_about_
/// current view — since an approved row here isn't necessarily the
/// latest one submitted (a later pending/rejected submission can exist
/// on top of an already-approved one).
class VenueAboutSubmission {
  final String id;
  final String aboutText;
  final VenueAboutSubmissionStatus status;
  final DateTime submittedAt;

  /// The reviewer's own note on a rejected submission — null on anything
  /// pending/approved, or when a reviewer rejected without leaving one.
  /// Mirrors VenuePhotoSubmissionSummary.reviewNote exactly (same
  /// column, same reasoning: a rejection with no reason reaches the
  /// manager as a bare status and nothing else to act on).
  final String? reviewNote;

  const VenueAboutSubmission({
    required this.id,
    required this.aboutText,
    required this.status,
    required this.submittedAt,
    this.reviewNote,
  });

  factory VenueAboutSubmission.fromJson(Map<String, dynamic> json) => VenueAboutSubmission(
    id: json['id'].toString(),
    aboutText: json['about_text'] as String,
    status: VenueAboutSubmissionStatus.fromWire(json['status'] as String),
    submittedAt: DateTime.parse(json['submitted_at'] as String),
    reviewNote: json['review_note'] as String?,
  );
}
