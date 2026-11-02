import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/venue_team_member.dart';
import '../services/venue_photo_pipeline.dart';
import 'venue_photo_submission_repository.dart'
    show VenuePhotoRejectedException, venuePhotoSubmissionsBucket;

/// Mirrors venue_team_submissions' CHECKs (20261030170000; the text
/// limit raised to 600 by 20261101170000).
const venueTeamNameMaxLength = 80;
const venueTeamBioMaxLength = 600;

final _random = Random.secure();

/// A venue's team on its page: a manager and a chef, each a name and a
/// short text, from the venue itself and reviewed before they show —
/// the same path as an about text (VenueAboutRepository).
///
/// RLS is the boundary: anyone reads the approved rows (through
/// venue_team_current), a manager reads their own submissions, and only
/// an active venue manager may insert, always as pending. Removing
/// someone needs no review and goes through remove_venue_team_member.
class VenueTeamRepository {
  VenueTeamRepository(this._client);

  final SupabaseClient _client;

  /// What the page shows, in the page's order.
  Future<List<VenueTeamMember>> loadCurrent({
    required String venueType,
    required String venueId,
  }) async {
    final rows = await _client
        .from('venue_team_current')
        .select('role, name, bio, photo_url')
        .eq('venue_type', venueType)
        .eq('venue_id', venueId);
    return VenueTeamMember.ordered([
      for (final row in rows as List)
        ?VenueTeamMember.fromJson(row as Map<String, dynamic>),
    ]);
  }

  /// The signed-in manager's latest submission per role, if any.
  Future<Map<VenueTeamRole, VenueTeamSubmission>> loadMyLatestSubmissions({
    required String venueType,
    required String venueId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};
    final rows = await _client
        .from('venue_team_submissions')
        .select(
          'id, role, name, bio, status, submitted_at, review_note, removed_at, '
          'photo_path, remove_photo',
        )
        .eq('user_id', userId)
        .eq('venue_type', venueType)
        .eq('venue_id', venueId)
        .order('submitted_at', ascending: false);
    final latest = <VenueTeamRole, VenueTeamSubmission>{};
    for (final row in rows as List) {
      final submission = VenueTeamSubmission.fromJson(
        row as Map<String, dynamic>,
      );
      if (submission != null) {
        latest.putIfAbsent(submission.role, () => submission);
      }
    }
    return latest;
  }

  /// Sends a name and text for [role], for review. [photoBytes] is a new
  /// portrait: checked and stripped like a venue photo (Layer 1 and the
  /// EXIF strip, venue_photo_pipeline.dart), uploaded to the manager's
  /// own folder in the private bucket, and published only on approval.
  /// Without it the role keeps its current portrait, unless
  /// [removePhoto] asks to take it off.
  ///
  /// Throws [VenuePhotoRejectedException] when the photo fails its check,
  /// before anything is uploaded.
  Future<void> submit({
    required String venueType,
    required String venueId,
    required VenueTeamRole role,
    required String name,
    String? bio,
    Uint8List? photoBytes,
    bool removePhoto = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    final trimmedBio = bio?.trim();

    String? photoPath;
    if (photoBytes != null) {
      final validation = validateVenuePhoto(photoBytes);
      if (validation is VenuePhotoValidationRejected) {
        throw VenuePhotoRejectedException(validation);
      }
      final prepared = prepareVenuePhoto(photoBytes);
      final unique =
          '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
      photoPath =
          '$venueType/$venueId/$userId/team_${role.wireValue}_$unique.${prepared.extension}';
      await _client.storage
          .from(venuePhotoSubmissionsBucket)
          .uploadBinary(
            photoPath,
            prepared.bytes,
            fileOptions: FileOptions(contentType: prepared.contentType),
          );
    }

    try {
      await _client.from('venue_team_submissions').insert({
        'user_id': userId,
        'venue_type': venueType,
        'venue_id': venueId,
        'role': role.wireValue,
        'name': name.trim(),
        'bio': (trimmedBio == null || trimmedBio.isEmpty) ? null : trimmedBio,
        'photo_path': ?photoPath,
        if (photoPath == null && removePhoto) 'remove_photo': true,
      });
    } catch (_) {
      // No stray upload left behind a failed insert.
      if (photoPath != null) {
        try {
          await _client.storage
              .from(venuePhotoSubmissionsBucket)
              .remove([photoPath]);
        } catch (cleanupError) {
          debugPrint('VENUE TEAM PHOTO CLEANUP FAILED: $cleanupError');
        }
      }
      rethrow;
    }
  }

  /// A short-lived link to a portrait still waiting for review, for the
  /// manager's own screens and preview.
  Future<String> signedPhotoUrl(String photoPath) => _client.storage
      .from(venuePhotoSubmissionsBucket)
      .createSignedUrl(photoPath, 3600);

  /// Takes the role off the page now, and withdraws anything still
  /// waiting for it.
  Future<void> remove({
    required String venueType,
    required String venueId,
    required VenueTeamRole role,
  }) => _client.rpc(
    'remove_venue_team_member',
    params: {
      'p_venue_type': venueType,
      'p_venue_id': venueId,
      'p_role': role.wireValue,
    },
  );
}
