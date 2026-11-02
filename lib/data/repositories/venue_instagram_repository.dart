import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/venue_about_submission.dart';

/// Instagram's own rule for an account name, as the CHECK on
/// venue_instagram_submissions.handle has it (20261101170000).
final _handlePattern = RegExp(r'^[A-Za-z0-9._]{1,30}$');

/// The account name in whatever a venue typed: "@name", "name", or a
/// link to the profile ("instagram.com/name", with or without https,
/// www, a trailing slash or a query). Null when it isn't one — a link to
/// a post or reel, another site, or a name with characters Instagram
/// doesn't allow.
String? normalizeInstagramHandle(String input) {
  var value = input.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('@')) value = value.substring(1);
  final looksLikeLink = value.contains('/') || value.contains('instagram.');
  if (looksLikeLink) {
    final uri = Uri.tryParse(
      value.startsWith('http') ? value : 'https://$value',
    );
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host != 'instagram.com' && host != 'www.instagram.com') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 1) return null;
    value = segments.single;
  }
  return _handlePattern.hasMatch(value) ? value : null;
}

/// The profile link the app opens for [handle].
Uri instagramProfileUri(String handle) =>
    Uri.https('www.instagram.com', '/$handle/');

/// A manager's own latest Instagram submission, with its review status.
class VenueInstagramSubmission {
  final String id;
  final String handle;
  final VenueAboutSubmissionStatus status;
  final String? reviewNote;
  final DateTime? removedAt;

  const VenueInstagramSubmission({
    required this.id,
    required this.handle,
    required this.status,
    this.reviewNote,
    this.removedAt,
  });

  factory VenueInstagramSubmission.fromJson(Map<String, dynamic> json) =>
      VenueInstagramSubmission(
        id: json['id'].toString(),
        handle: json['handle'] as String,
        status: VenueAboutSubmissionStatus.fromWire(json['status'] as String),
        reviewNote: json['review_note'] as String?,
        removedAt: json['removed_at'] == null
            ? null
            : DateTime.parse(json['removed_at'] as String),
      );

  bool get isOpen =>
      status == VenueAboutSubmissionStatus.pending && removedAt == null;
}

/// A venue's Instagram account: the venue sends it, an admin approves it,
/// the page shows the latest approved one (venue_instagram_current).
/// Same path as the about text and the team. Taking it off needs no
/// review and goes through remove_venue_instagram.
class VenueInstagramRepository {
  VenueInstagramRepository(this._client);

  final SupabaseClient _client;

  /// The handle the page shows, or null.
  Future<String?> loadCurrent({
    required String venueType,
    required String venueId,
  }) async {
    final row = await _client
        .from('venue_instagram_current')
        .select('handle')
        .eq('venue_type', venueType)
        .eq('venue_id', venueId)
        .maybeSingle();
    return row?['handle'] as String?;
  }

  Future<VenueInstagramSubmission?> loadMyLatest({
    required String venueType,
    required String venueId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('venue_instagram_submissions')
        .select('id, handle, status, review_note, removed_at')
        .eq('user_id', userId)
        .eq('venue_type', venueType)
        .eq('venue_id', venueId)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : VenueInstagramSubmission.fromJson(row);
  }

  /// [handle] must already be normalized (normalizeInstagramHandle).
  Future<void> submit({
    required String venueType,
    required String venueId,
    required String handle,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    await _client.from('venue_instagram_submissions').insert({
      'user_id': userId,
      'venue_type': venueType,
      'venue_id': venueId,
      'handle': handle,
    });
  }

  Future<void> remove({required String venueType, required String venueId}) =>
      _client.rpc(
        'remove_venue_instagram',
        params: {'p_venue_type': venueType, 'p_venue_id': venueId},
      );
}
