// Maps a row from `public.event_attendance` (see
// supabase/migrations/20260815120000_social_foundation_step2b_event_attendance.sql
// — additive, not yet applied). One row per (event, user) — its mere
// existence means "going"; there is no other status value in this MVP
// (see that migration's own header comment for why), so `status` is kept
// as the raw DB string rather than an enum with only one legal member.

/// The two permitted values of `event_attendance.visibility` — identical
/// shape to `VisitVisibility` (see lib/models/visit.dart) but kept as its
/// own type rather than reused: attendance and visit privacy are
/// different domain concepts that happen to share a shape today, not the
/// same concept twice.
enum AttendanceVisibility {
  private('private'),
  friends('friends');

  final String dbValue;
  const AttendanceVisibility(this.dbValue);

  /// Fails safe to [private] — the more restrictive option — for a null
  /// or unrecognised value, matching VisitVisibility.fromDbValue's own
  /// reasoning.
  static AttendanceVisibility fromDbValue(String? value) {
    for (final v in AttendanceVisibility.values) {
      if (v.dbValue == value) return v;
    }
    return AttendanceVisibility.private;
  }
}

class EventAttendance {
  final String id;
  final String eventId;
  final String userId;
  final String status;
  final AttendanceVisibility visibility;
  final DateTime createdAt;

  const EventAttendance({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.visibility,
    required this.createdAt,
  });

  factory EventAttendance.fromJson(Map<String, dynamic> json) =>
      EventAttendance(
        id: json['id'].toString(),
        eventId: json['event_id'].toString(),
        userId: json['user_id'].toString(),
        status: (json['status'] as String?) ?? 'going',
        visibility: AttendanceVisibility.fromDbValue(
          json['visibility'] as String?,
        ),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
