import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/photo_limits.dart';
import '../../models/visit_photo.dart';

/// Thrown by [PhotoRepository.uploadAttendancePhoto] when the attendance
/// already holds [maxEventAttendancePhotos] photos — Events V2 Step 4's
/// final photo-limit correction. Its own type (rather than a generic
/// exception/string) lets a caller distinguish "capacity reached" from any
/// other upload failure if a future UI ever wants to, though today's
/// `AttendancePhotosSection._addPhotos` treats it like any other per-photo
/// failure (this exception is a defense-in-depth backstop — the UI layer
/// already prevents reaching it in the normal case by disabling the Add
/// action and clamping multi-select at [maxEventAttendancePhotos]; see
/// `clampToRemainingCapacity`). Never thrown for Restaurant/Hotel visit
/// photos — [uploadPhoto] has no such check.
class AttendancePhotoLimitExceededException implements Exception {
  const AttendancePhotoLimitExceededException();

  @override
  String toString() =>
      'This attendance already has the maximum of $maxEventAttendancePhotos '
      'photos.';
}

// The private storage bucket visit/stay photos are uploaded to — see
// supabase/migrations/20260807120000_add_visit_photos_storage.sql. Private,
// not public: images are served via signed URLs (createSignedUrl(s)),
// never a public bucket URL, so storage.objects RLS (owner-only, matching
// the {userId}/{visitId}/{filename} path convention below) is the only
// thing guarding read access.
const visitPhotosBucket = 'visit-photos';

// Every column on public.photos this app reads. Listed explicitly, rather
// than select('*'), so a schema change is a visible diff here.
const _photoColumns =
    'id, user_id, visit_id, attendance_id, storage_path, caption, taken_at, '
    'is_public';

final _random = Random();

class PhotoRepository {
  PhotoRepository(this._client);

  final SupabaseClient _client;

  // Every photo attached to one visit/stay, newest-taken first. Loaded by
  // visit_id — never by the venue's id — so repeat visits/stays to the
  // same restaurant/hotel keep fully independent photo sets (PHOTO ->
  // VISIT/STAY -> VENUE, never PHOTO -> VENUE directly).
  Future<List<VisitPhoto>> loadPhotosForVisit(String visitId) async {
    final rows = await _client
        .from('photos')
        .select(_photoColumns)
        .eq('visit_id', visitId)
        .order('taken_at', ascending: false);
    return (rows as List)
        .map((row) => VisitPhoto.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Signed, time-limited URLs for a batch of storage paths — one request
  // regardless of how many photos, never one per photo. The bucket is
  // private, so this is the only way to actually display an image; the
  // returned map is keyed by storage_path for easy lookup per photo.
  Future<Map<String, String>> resolveDisplayUrls(
    List<String> storagePaths, {
    int expiresInSeconds = 3600,
  }) async {
    if (storagePaths.isEmpty) return {};
    final signed = await _client.storage
        .from(visitPhotosBucket)
        .createSignedUrls(storagePaths, expiresInSeconds);
    return {
      for (final s in signed)
        if (s.path.isNotEmpty && s.signedUrl.isNotEmpty) s.path: s.signedUrl,
    };
  }

  // Events V2 Step 4's photo-limit correction is deliberately NOT applied
  // here — Restaurant/Hotel visit photos have no maximum, and this method
  // must stay that way unless a future task gives it its own explicit
  // limit. See uploadAttendancePhoto below for the attendance-only check.
  //
  // Uploads [bytes] for one visit/stay and inserts the matching
  // public.photos row. [entityType]/[entityId] are the venue the visit/stay
  // itself belongs to (Visit.entityType/Visit.entityId) — public.photos
  // requires them (both `not null`), even though every read in this app
  // goes by visit_id, never entity_id.
  //
  // Storage path is {userId}/{visitId}/{uniqueFilename} — every segment
  // user- and visit-scoped (matching storage.objects' RLS policies) and
  // never colliding, since the filename combines a microsecond timestamp
  // with a random suffix.
  Future<VisitPhoto> uploadPhoto({
    required String userId,
    required String visitId,
    required String entityType,
    required String entityId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final uniqueId =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
    final storagePath = '$userId/$visitId/$uniqueId.$fileExtension';
    final contentType = fileExtension == 'jpg' ? 'jpeg' : fileExtension;

    await _client.storage
        .from(visitPhotosBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$contentType'),
        );

    try {
      final row = await _client
          .from('photos')
          .insert({
            'user_id': userId,
            'visit_id': visitId,
            'entity_type': entityType,
            'entity_id': entityId,
            'storage_path': storagePath,
            'taken_at': DateTime.now().toIso8601String(),
          })
          .select(_photoColumns)
          .single();
      return VisitPhoto.fromJson(row);
    } catch (error, stackTrace) {
      // The row failed after the object was already uploaded — clean up
      // the orphaned storage object rather than leaving a file behind that
      // nothing references. Best-effort: if the cleanup itself fails, log
      // it but still surface the original error to the caller.
      try {
        await _client.storage.from(visitPhotosBucket).remove([storagePath]);
      } catch (cleanupError, cleanupStack) {
        debugPrint('UPLOAD PHOTO CLEANUP FAILED: $cleanupError');
        debugPrintStack(stackTrace: cleanupStack);
      }
      debugPrint('UPLOAD PHOTO ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // Deletes a photo. The public.photos row — the source of truth for
  // whether this photo still "exists" in the app — is deleted first and
  // is what the caller's success/failure result reflects: if this throws,
  // nothing changed and the photo still shows in the UI, safe to retry.
  // Storage cleanup runs after and is best-effort: if it fails, an
  // orphaned object is left behind (invisible — nothing references it any
  // more) and logged, but is deliberately not surfaced as a user-facing
  // failure, since the delete the user actually asked for (make the photo
  // disappear) already succeeded. Scoped by both id and the photo's own
  // user_id — belt-and-suspenders alongside RLS, which is the actual
  // security boundary.
  Future<void> deletePhoto(VisitPhoto photo) async {
    await _client
        .from('photos')
        .delete()
        .eq('id', photo.id)
        .eq('user_id', photo.userId);
    try {
      await _client.storage.from(visitPhotosBucket).remove([photo.storagePath]);
    } catch (error, stackTrace) {
      debugPrint('DELETE PHOTO STORAGE CLEANUP FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Deletes every photo attached to one visit/stay — storage objects
  // first (best-effort; a failure there is logged, not fatal, matching
  // deletePhoto's reasoning above), then every public.photos row for
  // [visitId]. Used before deleting the visit/stay row itself:
  // photos.visit_id has NO `on delete cascade` (confirmed against the
  // production schema — a plain `references public.visits(id)`), so a
  // visit/stay row with photos still referencing it cannot be deleted
  // until this runs; the row delete below is allowed to throw and
  // propagate so the caller never proceeds to delete the visit/stay while
  // photo rows might still exist.
  Future<void> deleteAllPhotosForVisit({
    required String userId,
    required String visitId,
  }) async {
    final photos = await loadPhotosForVisit(visitId);
    if (photos.isEmpty) return;

    try {
      await _client.storage.from(visitPhotosBucket).remove([
        for (final p in photos) p.storagePath,
      ]);
    } catch (error, stackTrace) {
      debugPrint('DELETE VISIT PHOTOS STORAGE CLEANUP FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    await _client
        .from('photos')
        .delete()
        .eq('visit_id', visitId)
        .eq('user_id', userId);
  }

  // ── Events V2 Step 4 — confirmed Attendance photos ────────────────────
  //
  // Same bucket, same storage-path convention, same upload/delete shape as
  // the visit methods above — no new photo system, per explicit
  // instruction. The one structural difference: `photos.attendance_id`
  // (unlike `visit_id`) has `on delete cascade` to
  // `event_confirmed_attendance`, so the DB row-level cleanup that
  // [deleteAllPhotosForVisit] does explicitly happens automatically here —
  // see [deleteAllPhotosForAttendance]'s own doc comment for why storage
  // cleanup still can't be automatic and must still run first.

  // Every photo attached to one confirmed attendance, newest-taken first —
  // loaded by attendance_id, never by event.id, matching the same
  // PHOTO -> ATTENDANCE -> EVENT rule loadPhotosForVisit's own doc comment
  // states for PHOTO -> VISIT -> VENUE (never PHOTO -> VENUE directly): a
  // future repeat-attendance model must never accidentally merge two
  // separate attendances' photos just because they're for the same event.
  Future<List<VisitPhoto>> loadPhotosForAttendance(String attendanceId) async {
    final rows = await _client
        .from('photos')
        .select(_photoColumns)
        .eq('attendance_id', attendanceId)
        .order('taken_at', ascending: false);
    return (rows as List)
        .map((row) => VisitPhoto.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // The current photo count for one attendance — a lightweight `select
  // id` (never the full _photoColumns) since this is only ever used as a
  // capacity check, not to render anything. No `count: CountOption.exact`
  // head-request variant is used here (unlike this app's raw-SQL/curl
  // introspection elsewhere) simply because nothing else in this
  // repository's Dart layer has established that pattern yet — a plain
  // row fetch is more than cheap enough at a maximum of
  // maxEventAttendancePhotos rows.
  Future<int> _attendancePhotoCount(String attendanceId) async {
    final rows = await _client
        .from('photos')
        .select('id')
        .eq('attendance_id', attendanceId);
    return (rows as List).length;
  }

  // Uploads [bytes] for one confirmed attendance and inserts the matching
  // public.photos row — entity_type='event', entity_id=[eventId] (the
  // canonical Event, per the Step 4 photos pre-apply report's confirmed
  // semantics), attendance_id=[attendanceId] (this user's own historical
  // experience), visit_id left null. Storage path
  // {userId}/{attendanceId}/{uniqueFilename}, matching uploadPhoto's own
  // convention exactly (owner-scoped, matching storage.objects' RLS).
  //
  // Events V2 Step 4's final photo-limit correction: throws
  // [AttendancePhotoLimitExceededException] — before touching Storage or
  // inserting anything — if the attendance already holds
  // [maxEventAttendancePhotos] photos. This is deliberately a
  // check-then-act count query, not a database-enforced constraint: a
  // genuinely race-safe version (immune to two concurrent uploads to the
  // SAME attendance from two different devices in the same instant) would
  // need either a `SELECT ... FOR UPDATE` row lock scoped to the
  // attendance or a counting trigger + CHECK constraint on a denormalized
  // count column — disproportionate schema complexity for what is, in
  // practice, always a single user on a single device uploading through
  // one sequential (`await`-in-a-loop) picker flow. Documented here
  // rather than built: this is the strongest reasonable MVP enforcement
  // at the application/repository layer, and it is real enforcement (not
  // presentation-only) — a client that bypasses the UI's own disabled
  // Add-button/clamped-selection guard entirely and calls this method
  // directly still cannot exceed the limit through this code path.
  Future<VisitPhoto> uploadAttendancePhoto({
    required String userId,
    required String attendanceId,
    required String eventId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final currentCount = await _attendancePhotoCount(attendanceId);
    if (!canAddAttendancePhoto(currentCount)) {
      throw const AttendancePhotoLimitExceededException();
    }

    final uniqueId =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
    final storagePath = '$userId/$attendanceId/$uniqueId.$fileExtension';
    final contentType = fileExtension == 'jpg' ? 'jpeg' : fileExtension;

    await _client.storage
        .from(visitPhotosBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$contentType'),
        );

    try {
      final row = await _client
          .from('photos')
          .insert({
            'user_id': userId,
            'attendance_id': attendanceId,
            'entity_type': 'event',
            'entity_id': eventId,
            'storage_path': storagePath,
            'taken_at': DateTime.now().toIso8601String(),
          })
          .select(_photoColumns)
          .single();
      return VisitPhoto.fromJson(row);
    } catch (error, stackTrace) {
      try {
        await _client.storage.from(visitPhotosBucket).remove([storagePath]);
      } catch (cleanupError, cleanupStack) {
        debugPrint('UPLOAD ATTENDANCE PHOTO CLEANUP FAILED: $cleanupError');
        debugPrintStack(stackTrace: cleanupStack);
      }
      debugPrint('UPLOAD ATTENDANCE PHOTO ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // Removes every storage object for one confirmed attendance's photos —
  // STORAGE ONLY, deliberately never deletes the photos rows themselves
  // (unlike deleteAllPhotosForVisit): `photos.attendance_id ... on delete
  // cascade` already removes those rows automatically the moment the
  // caller deletes the event_confirmed_attendance row, so this method's
  // one job is the thing the database cascade structurally cannot do —
  // remove the actual files from Storage. Must be called BEFORE deleting
  // the attendance row (the photo rows — and therefore their
  // storage_paths — are only queryable while the attendance still
  // exists); see EventConfirmedAttendanceRepository.deleteConfirmedAttendance
  // for the caller enforcing this order. Best-effort, matching every other
  // storage cleanup in this class: a failure here is logged, not fatal —
  // the attendance deletion the user actually asked for must not be
  // blocked by a storage-layer hiccup.
  Future<void> deleteAllPhotosForAttendance({
    required String attendanceId,
  }) async {
    final photos = await loadPhotosForAttendance(attendanceId);
    if (photos.isEmpty) return;
    try {
      await _client.storage.from(visitPhotosBucket).remove([
        for (final p in photos) p.storagePath,
      ]);
    } catch (error, stackTrace) {
      debugPrint('DELETE ATTENDANCE PHOTOS STORAGE CLEANUP FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
