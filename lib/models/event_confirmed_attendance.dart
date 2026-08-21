// Maps a row from `public.event_confirmed_attendance` — deployed to
// production as part of Events V2 Step 1 database foundation, but unused
// by any Dart code until Step 4 (Confirmed Attendance + Post-Event
// Prompt). Structurally separate from `event_attendance` (see
// event_attendance.dart): `event_attendance` is pre-event INTENT
// (Interested/Going, disposable, superseded by a later state); this table
// is confirmed HISTORY (append-only in spirit — a user may edit or delete
// their own row, but it is never silently overwritten by an intent
// change). One row per (event, user), enforced by `unique(event_id,
// user_id)`.

/// The three permitted values of `event_confirmed_attendance.source` — the
/// provenance of how a confirmed-attendance row was created. Mirrors the
/// database CHECK constraint exactly; `tripCompletion` is not writable by
/// any code yet (Step 4's explicit scope boundary — Trip completion is a
/// future step), but the enum includes it now so the DB and Dart
/// vocabularies never drift out of sync as that future step is built.
enum EventAttendanceSource {
  manual('manual'),
  postEventPrompt('post_event_prompt'),
  tripCompletion('trip_completion');

  final String dbValue;
  const EventAttendanceSource(this.dbValue);

  /// Fails safe to [manual] — the least-assuming provenance — for a null
  /// or unrecognised value; the CHECK constraint guarantees one of the
  /// three legal values in practice, so this is only reached if the schema
  /// changes underneath us (matching every other `fromDbValue` in this
  /// codebase).
  static EventAttendanceSource fromDbValue(String? value) {
    for (final source in EventAttendanceSource.values) {
      if (source.dbValue == value) return source;
    }
    return EventAttendanceSource.manual;
  }
}

/// The two permitted values of `event_confirmed_attendance.visibility` —
/// identical shape to `AttendanceVisibility` (event_attendance.dart) and
/// `VisitVisibility` (visit.dart), but deliberately its own type rather
/// than reused: this codebase's own established convention (see
/// AttendanceVisibility's own doc comment) is that privacy on different
/// domain concepts stays as different types even when the shape matches,
/// so a future divergence (e.g. a third visibility tier on only one of
/// them) is a natural enum-value addition, never an awkward shared-type
/// retrofit.
enum ConfirmedAttendanceVisibility {
  private('private'),
  friends('friends');

  final String dbValue;
  const ConfirmedAttendanceVisibility(this.dbValue);

  /// Fails safe to [private] — the more restrictive option, and also the
  /// column's own database default — matching AttendanceVisibility/
  /// VisitVisibility's identical reasoning.
  static ConfirmedAttendanceVisibility fromDbValue(String? value) {
    for (final v in ConfirmedAttendanceVisibility.values) {
      if (v.dbValue == value) return v;
    }
    return ConfirmedAttendanceVisibility.private;
  }
}

class EventConfirmedAttendance {
  final String id;
  final String eventId;
  final String userId;
  final DateTime confirmedAt;
  final int? rating;

  /// Events V2 Step 4.1 — `event_confirmed_attendance.would_recommend`.
  /// Three-valued: `null` = no recommendation feedback supplied (never
  /// interpreted as "No" — matches the column's own DB comment exactly),
  /// `true` = Yes, `false` = No. Independent of [rating]: one answers "how
  /// good was it," the other answers "would you recommend it" — never
  /// derived from the other. Reads as plain `null` whenever the underlying
  /// JSON key is absent (a pre-migration row, or any row before this
  /// column existed) — [fromJson] never assumes a missing key means false.
  final bool? wouldRecommend;
  final String? comment;
  final ConfirmedAttendanceVisibility visibility;
  final EventAttendanceSource source;
  final DateTime createdAt;

  const EventConfirmedAttendance({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.confirmedAt,
    this.rating,
    this.wouldRecommend,
    this.comment,
    required this.visibility,
    required this.source,
    required this.createdAt,
  });

  factory EventConfirmedAttendance.fromJson(Map<String, dynamic> json) =>
      EventConfirmedAttendance(
        id: json['id'].toString(),
        eventId: json['event_id'].toString(),
        userId: json['user_id'].toString(),
        confirmedAt: DateTime.parse(json['confirmed_at'] as String),
        rating: (json['rating'] as num?)?.toInt(),
        wouldRecommend: json['would_recommend'] as bool?,
        comment: json['comment'] as String?,
        visibility: ConfirmedAttendanceVisibility.fromDbValue(
          json['visibility'] as String?,
        ),
        source: EventAttendanceSource.fromDbValue(json['source'] as String?),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
