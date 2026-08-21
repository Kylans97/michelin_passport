// Maps a row from `public.photos` (see
// supabase/migrations/20260805141519_production_schema_v1.sql). Only the
// columns this app's photo features actually use are modelled.
// `entity_type`/`entity_id` also exist on this table but are never read
// back by this app — every load here goes by `visit_id` or `attendance_id`,
// never by venue id, matching the product rule PHOTO -> VISIT/STAY/
// ATTENDANCE -> VENUE (never PHOTO -> VENUE directly). There is no
// `created_at`/inserted-at column on this table — `takenAt` is the closest
// thing, and is what this app sorts by.
//
// Events V2 Step 4 widened this from visit-only to polymorphic: exactly one
// of [visitId]/[attendanceId] is ever non-null for a given row (never both,
// never neither, matching PhotoRepository.uploadPhoto/uploadAttendancePhoto
// — see photos_insert's own RLS for the database-side half of this rule).
// Kept as one model, not split into VisitPhoto/AttendancePhoto, mirroring
// this codebase's own established "one polymorphic model, parallel UI"
// pattern already used for Visit (restaurant/hotel).
class VisitPhoto {
  final String id;
  final String userId;
  final String? visitId;
  final String? attendanceId;
  final String storagePath;
  final String? caption;
  final DateTime? takenAt;
  final bool isPublic;

  const VisitPhoto({
    required this.id,
    required this.userId,
    this.visitId,
    this.attendanceId,
    required this.storagePath,
    this.caption,
    this.takenAt,
    required this.isPublic,
  });

  factory VisitPhoto.fromJson(Map<String, dynamic> json) => VisitPhoto(
    id: json['id'].toString(),
    userId: json['user_id'].toString(),
    visitId: json['visit_id']?.toString(),
    attendanceId: json['attendance_id']?.toString(),
    storagePath: (json['storage_path'] as String?) ?? '',
    caption: json['caption'] as String?,
    takenAt: json['taken_at'] != null
        ? DateTime.tryParse(json['taken_at'] as String)
        : null,
    isPublic: (json['is_public'] as bool?) ?? true,
  );
}
