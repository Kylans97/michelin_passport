import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/visit_photo.dart';

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
    'id, user_id, visit_id, storage_path, caption, taken_at, is_public';

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
}
