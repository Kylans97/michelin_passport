// Maps a row from `public.event_attendance` — confirmed deployed to
// production (Social Foundation Step 2B, widened by Events V2 Step 1's
// 20260819141000_events_v2_attendance_interested_going.sql). One row per
// (event, user). See event_intent.dart for the pure state-machine/
// visibility-derivation/analytics-mapping functions built on top of the
// two enums below — kept in a separate file so those functions can also
// import analytics_event.dart without this file needing to.

/// The two permitted values of `event_attendance.status` (Events V2 Step
/// 1's widened CHECK constraint: `interested | going`). A user cannot be
/// simultaneously Interested and Going in the authoritative transactional
/// state — one status per row, never two independent booleans.
enum EventIntentStatus {
  interested('interested'),
  going('going');

  final String dbValue;
  const EventIntentStatus(this.dbValue);

  /// Fails safe to [interested] — the lighter-commitment state — for a
  /// null or unrecognised value; the CHECK constraint guarantees one of
  /// the two legal values in practice, so this is only reached if the
  /// schema changes underneath us (matching EventType/EventStatus's own
  /// fail-safe convention).
  static EventIntentStatus fromDbValue(String? value) {
    for (final status in EventIntentStatus.values) {
      if (status.dbValue == value) return status;
    }
    return EventIntentStatus.interested;
  }
}

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
  final EventIntentStatus status;
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
        status: EventIntentStatus.fromDbValue(json['status'] as String?),
        visibility: AttendanceVisibility.fromDbValue(
          json['visibility'] as String?,
        ),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
