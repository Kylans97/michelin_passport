import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/venue_photo_pipeline.dart';

/// The private Storage bucket pending venue photo submissions land in —
/// see supabase/migrations/20260828120000_add_venue_claims_submissions_
/// rankings.sql §6. Distinct from the public `catalogue-media` bucket a
/// submission is manually copied into once approved (no automated
/// publish step exists yet — see that migration's own "how you approve"
/// notes). Private, not public: nobody but the submitter may read an
/// unreviewed photo, matching `visit-photos`' own private-bucket
/// reasoning for personal content.
const venuePhotoSubmissionsBucket = 'venue-photo-submissions';

/// Thrown when [validateVenuePhoto] rejects a photo before any network
/// call is made — its own type (rather than a generic exception) lets a
/// caller show [VenuePhotoValidationRejected.message] directly, matching
/// "weiger met een duidelijke melding welke eis niet gehaald is".
class VenuePhotoRejectedException implements Exception {
  const VenuePhotoRejectedException(this.rejection);
  final VenuePhotoValidationRejected rejection;

  @override
  String toString() => rejection.message;
}

final _random = Random();

class VenuePhotoSubmissionRepository {
  VenuePhotoSubmissionRepository(this._client);

  final SupabaseClient _client;

  /// Runs Layers 1 and 2 (validate -> strip EXIF -> hash), then uploads
  /// the result to the pending bucket and inserts the matching
  /// `venue_photo_submissions` row. `venue_type`/`venue_id` must be a
  /// venue the caller holds an approved claim on — enforced by that
  /// table's own RLS insert policy (`has_approved_venue_claim`), not
  /// re-checked here; a caller without one gets a Postgres permission
  /// error from the insert itself, same as every other RLS-gated write
  /// in this app.
  ///
  /// Throws [VenuePhotoRejectedException] if Layer 1 rejects the photo
  /// — before Storage or the database are touched at all. Layer 2's
  /// near-duplicate check runs server-side, inside the insert itself
  /// (`enforce_photo_duplicate_check`): a rejected-duplicate match
  /// throws the raw `PostgrestException` the trigger's `RAISE EXCEPTION`
  /// produces; an approved-duplicate match does NOT throw — the row is
  /// inserted with `duplicate_of_submission_id` set, which the returned
  /// row surfaces via that field so the caller can flag it, per "meld
  /// dat het een duplicaat is" (a notice, not a rejection).
  ///
  /// [replacesPhotoId] must be set when the venue is already at the
  /// 5-photo cap — `venue_photo_submissions_replacement_check` rejects
  /// the insert otherwise. Left null when the venue has fewer than 5
  /// published photos.
  Future<Map<String, dynamic>> submit({
    required String userId,
    required String venueType,
    required String venueId,
    required Uint8List rawBytes,
    String? replacesPhotoId,
  }) async {
    final validation = validateVenuePhoto(rawBytes);
    if (validation is VenuePhotoValidationRejected) {
      throw VenuePhotoRejectedException(validation);
    }

    final cleanBytes = stripExifFromVenuePhoto(rawBytes);
    final phash = computeVenuePhotoHash(cleanBytes);

    final uniqueId =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
    final storagePath = '$venueType/$venueId/$userId/$uniqueId.jpg';

    await _client.storage
        .from(venuePhotoSubmissionsBucket)
        .uploadBinary(
          storagePath,
          cleanBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    try {
      final row = await _client
          .from('venue_photo_submissions')
          .insert({
            'user_id': userId,
            'venue_type': venueType,
            'venue_id': venueId,
            'storage_path': storagePath,
            'phash': phash,
            'replaces_photo_id': ?replacesPhotoId,
          })
          .select()
          .single();
      return row;
    } catch (error, stackTrace) {
      // Same "clean up the orphaned object, still surface the original
      // error" shape as PhotoRepository.uploadPhoto — a rejected
      // near-duplicate or a missing-replacement error must not leave a
      // stray file in the bucket behind it.
      try {
        await _client.storage
            .from(venuePhotoSubmissionsBucket)
            .remove([storagePath]);
      } catch (cleanupError, cleanupStack) {
        debugPrint('VENUE PHOTO SUBMIT CLEANUP FAILED: $cleanupError');
        debugPrintStack(stackTrace: cleanupStack);
      }
      debugPrint('VENUE PHOTO SUBMIT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
