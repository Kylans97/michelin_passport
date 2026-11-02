import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../features/review/member_insights_screen.dart' show MemberInsight;
import '../../models/review_item.dart';
import 'events_repository.dart';
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
  /// Members by country and age group, counts only (groups under 5 come
  /// back without a number). Admins only; the RPC refuses anyone else.
  Future<List<MemberInsight>> loadMemberInsights() async {
    final rows = await _client.rpc('admin_get_member_insights');
    return [
      for (final row in rows as List)
        MemberInsight.fromJson(row as Map<String, dynamic>),
    ];
  }

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

  /// Publishes a submitted event and tells the venue.
  /// A submission with a new portrait is published through
  /// publish-venue-photo (copy to catalogue-media, verify, approve), the
  /// way a venue photo is; one without goes straight to the RPC, which
  /// refuses one with a photo.
  Future<void> approveTeam(ReviewItem item) async {
    if (item.teamPhotoPath == null) {
      await _client.rpc(
        'admin_approve_venue_team',
        params: {'p_submission_id': item.itemId},
      );
      return;
    }
    final response = await _client.functions.invoke(
      'publish-venue-photo',
      body: {'team_submission_id': item.itemId},
    );
    if (response.status != 200) {
      throw StateError('Could not publish the photo (${response.status}).');
    }
  }

  Future<void> rejectTeam(ReviewItem item, String note) => _client.rpc(
    'admin_reject_venue_team',
    params: {'p_submission_id': item.itemId, 'p_review_note': note},
  );

  Future<void> approveInstagram(ReviewItem item) => _client.rpc(
    'admin_approve_venue_instagram',
    params: {'p_submission_id': item.itemId},
  );

  Future<void> rejectInstagram(ReviewItem item, String note) => _client.rpc(
    'admin_reject_venue_instagram',
    params: {'p_submission_id': item.itemId, 'p_review_note': note},
  );

  Future<void> markContactEditSeen(ReviewItem item) => _client.rpc(
    'admin_mark_venue_contact_edit_seen',
    params: {'p_edit_id': item.itemId},
  );

  Future<void> resolveContentReport(ReviewItem item) => _client.rpc(
    'admin_resolve_content_report',
    params: {'p_report_id': item.itemId},
  );

  Future<void> markMissingListingHandled(ReviewItem item) => _client.rpc(
    'admin_mark_missing_listing_handled',
    params: {'p_report_id': item.itemId},
  );

  Future<void> approveEvent(ReviewItem item) => _client.rpc(
    'admin_approve_event',
    params: {'p_event_id': item.eventId},
  );

  /// Sends a submitted event back with a note — or, for a live one, takes
  /// it offline. The venue sees the note either way.
  Future<void> rejectEvent(ReviewItem item, String note) => _client.rpc(
    'admin_reject_event',
    params: {'p_event_id': item.eventId, 'p_review_note': note},
  );

  /// Clears a change to a live event from the queue.
  Future<void> markEventEditSeen(ReviewItem item) => _client.rpc(
    'admin_mark_event_edit_seen',
    params: {'p_edit_id': item.itemId},
  );

  /// The event itself, in any status. Admins may read unpublished events
  /// (events_admin_read).
  Future<Event?> loadEvent(String eventId) => EventsRepository(_client).loadEventById(eventId);
}
