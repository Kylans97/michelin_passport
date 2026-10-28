import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/review_item.dart';
import 'venue_photo_submission_repository.dart'
    show venuePhotoSubmissionsBucket;

/// In-app review for admins (20261017120000). Every call goes through an
/// RPC or Edge Function that checks is_admin() server-side; nothing here
/// writes a moderation column directly, and the app never holds the
/// service_role key.
class ReviewRepository {
  final SupabaseClient _client;
  ReviewRepository(this._client);

  /// Whether the signed-in user is an admin. False on any failure, so the
  /// Review row simply stays hidden.
  Future<bool> isAdmin() async {
    try {
      final result = await _client.rpc('is_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Everything waiting, oldest first. Kinds this build doesn't know are
  /// skipped.
  Future<List<ReviewItem>> loadQueue() async {
    final rows = await _client.rpc('get_review_queue');
    return [
      for (final row in rows as List)
        ?ReviewItem.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// A short-lived URL for a pending photo in the private bucket. Admins
  /// may read it (venue_photo_submissions_storage_admin_read).
  Future<String> signedPhotoUrl(String storagePath) => _client.storage
      .from(venuePhotoSubmissionsBucket)
      .createSignedUrl(storagePath, 3600);

  Future<void> approveClaim(ReviewItem item) => _client.rpc(
    'admin_approve_venue_claim',
    params: {'p_venue_type': item.venueType, 'p_claim_id': item.itemId},
  );

  Future<void> rejectClaim(ReviewItem item, String note) => _client.rpc(
    'admin_reject_venue_claim',
    params: {
      'p_venue_type': item.venueType,
      'p_claim_id': item.itemId,
      'p_review_note': note,
    },
  );

  Future<void> approveAbout(ReviewItem item) => _client.rpc(
    'admin_approve_venue_about',
    params: {'p_submission_id': item.itemId},
  );

  Future<void> rejectAbout(ReviewItem item, String note) => _client.rpc(
    'admin_reject_venue_about',
    params: {'p_submission_id': item.itemId, 'p_review_note': note},
  );

  /// Publishes a photo through the publish-venue-photo Edge Function,
  /// which copies it out of the private bucket, verifies the copy and
  /// approves it, recording this admin as the reviewer. Sends only the
  /// submission id — the function derives everything else itself.
  Future<void> approvePhoto(ReviewItem item) async {
    final response = await _client.functions.invoke(
      'publish-venue-photo',
      body: {'submission_id': item.itemId},
    );
    if (response.status != 200) {
      throw StateError('Could not publish the photo (${response.status}).');
    }
  }

  Future<void> rejectPhoto(ReviewItem item, String note) => _client.rpc(
    'admin_reject_venue_photo',
    params: {'p_submission_id': item.itemId, 'p_review_note': note},
  );
}
