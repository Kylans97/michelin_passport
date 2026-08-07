// Maps a row from `public.photos` (see
// supabase/migrations/20260805141519_production_schema_v1.sql). Only the
// columns this app's per-visit/stay photo feature actually uses are
// modelled. `entity_type`/`entity_id` also exist on this table (photos can,
// in principle, exist without a visit_id) but are never read back by this
// app — every load here goes by `visit_id`, never by venue id, matching the
// product rule PHOTO -> VISIT/STAY -> VENUE (never PHOTO -> VENUE directly).
// There is no `created_at`/inserted-at column on this table — `takenAt` is
// the closest thing, and is what this app sorts by.
class VisitPhoto {
  final String id;
  final String userId;
  final String visitId;
  final String storagePath;
  final String? caption;
  final DateTime? takenAt;
  final bool isPublic;

  const VisitPhoto({
    required this.id,
    required this.userId,
    required this.visitId,
    required this.storagePath,
    this.caption,
    this.takenAt,
    required this.isPublic,
  });

  factory VisitPhoto.fromJson(Map<String, dynamic> json) => VisitPhoto(
    id: json['id'].toString(),
    userId: json['user_id'].toString(),
    visitId: json['visit_id'].toString(),
    storagePath: (json['storage_path'] as String?) ?? '',
    caption: json['caption'] as String?,
    takenAt: json['taken_at'] != null
        ? DateTime.tryParse(json['taken_at'] as String)
        : null,
    isPublic: (json['is_public'] as bool?) ?? true,
  );
}
