import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/venue_team_member.dart';

/// Mirrors venue_team_submissions' CHECKs (20261030150000).
const venueTeamNameMaxLength = 80;
const venueTeamBioMaxLength = 280;

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

  /// What the page shows, chef first.
  Future<List<VenueTeamMember>> loadCurrent({
    required String venueType,
    required String venueId,
  }) async {
    final rows = await _client
        .from('venue_team_current')
        .select('role, name, bio')
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
          'id, role, name, bio, status, submitted_at, review_note, removed_at',
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

  Future<void> submit({
    required String venueType,
    required String venueId,
    required VenueTeamRole role,
    required String name,
    String? bio,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    final trimmedBio = bio?.trim();
    await _client.from('venue_team_submissions').insert({
      'user_id': userId,
      'venue_type': venueType,
      'venue_id': venueId,
      'role': role.wireValue,
      'name': name.trim(),
      'bio': (trimmedBio == null || trimmedBio.isEmpty) ? null : trimmedBio,
    });
  }

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
