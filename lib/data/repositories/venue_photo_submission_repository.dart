import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/published_venue_photo.dart';
import '../../models/venue_photo_submission_status.dart';
import '../services/venue_photo_pipeline.dart';

/// {venue_type} -> the table its APPROVED photos live in — mirrors the
/// same three-way split is_active_venue_manager()/reorder_venue_photos()
/// already use on the database side.
String _publishedTableFor(String venueType) => switch (venueType) {
  'restaurant' => 'restaurant_photos',
  'hotel' => 'hotel_photos',
  'private_chef' => 'private_chef_photos',
  _ => throw ArgumentError('Unknown venue_type: $venueType'),
};

String _venueColumnFor(String venueType) => switch (venueType) {
  'restaurant' => 'restaurant_id',
  'hotel' => 'hotel_id',
  'private_chef' => 'private_chef_id',
  _ => throw ArgumentError('Unknown venue_type: $venueType'),
};

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

  /// The venue's current PUBLISHED photos — restaurant_photos/
  /// hotel_photos/private_chef_photos, whichever matches [venueType] —
  /// display_order ascending, so index 0 is always the one that appears
  /// first. Readable by anyone (public_read policy), not manager-gated —
  /// same as the public detail page itself would read.
  Future<List<PublishedVenuePhoto>> loadPublishedPhotos({
    required String venueType,
    required String venueId,
  }) async {
    final rows = await _client
        .from(_publishedTableFor(venueType))
        .select('id, image_url, alt_text, display_order')
        .eq(_venueColumnFor(venueType), venueId)
        .order('display_order');
    return [
      for (final row in rows as List)
        PublishedVenuePhoto.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// The signed-in user's own PENDING or REJECTED submissions for this
  /// venue, newest first — never approved ones (see
  /// VenuePhotoSubmissionSummary's own doc comment for why). Reads only
  /// this user's own rows, matching venue_photo_submissions_own_read's
  /// own scope (`user_id = auth.uid()`) — no explicit .eq('user_id', ...)
  /// needed for correctness, since RLS already restricts it, but added
  /// anyway for the same explicitness this app's other repositories
  /// already use over RLS-only scoping.
  Future<List<VenuePhotoSubmissionSummary>> loadMyOpenSubmissions({
    required String venueType,
    required String venueId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from('venue_photo_submissions')
        .select(
          'id, storage_path, status, review_note, submitted_at, replaces_photo_id',
        )
        .eq('user_id', userId)
        .eq('venue_type', venueType)
        .eq('venue_id', venueId)
        .inFilter('status', ['pending', 'rejected'])
        .order('submitted_at', ascending: false);
    return [
      for (final row in rows as List)
        VenuePhotoSubmissionSummary.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Signed, time-limited URLs for a batch of PRIVATE-bucket storage
  /// paths — one request regardless of how many photos, mirroring
  /// PhotoRepository.resolveDisplayUrls' own established shape/expiry
  /// exactly. The only way to actually display a pending submission's
  /// photo, since the bucket is private.
  Future<Map<String, String>> resolveDisplayUrls(
    List<String> storagePaths, {
    int expiresInSeconds = 3600,
  }) async {
    if (storagePaths.isEmpty) return {};
    final signed = await _client.storage
        .from(venuePhotoSubmissionsBucket)
        .createSignedUrls(storagePaths, expiresInSeconds);
    return {
      for (final s in signed)
        if (s.path.isNotEmpty && s.signedUrl.isNotEmpty) s.path: s.signedUrl,
    };
  }

  /// Reorders the venue's PUBLISHED photos via reorder_venue_photos —
  /// never a direct display_order write. [photoIds] must be the venue's
  /// COMPLETE photo id list in the desired new order (the RPC itself
  /// rejects a partial or duplicate list — see
  /// 20261003120000_add_reorder_venue_photos_rpc.sql).
  Future<void> reorderPhotos({
    required String venueType,
    required String venueId,
    required List<String> photoIds,
  }) => _client.rpc(
    'reorder_venue_photos',
    params: {'p_venue_type': venueType, 'p_venue_id': venueId, 'p_photo_ids': photoIds},
  );
}
