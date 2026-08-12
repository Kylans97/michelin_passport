import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';
import '../../models/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<UserProfile> getProfile({
    required String userId,
    required List<Restaurant> visited,
  }) async {
    final profileRows = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .limit(1);

    if ((profileRows as List).isEmpty) {
      throw Exception('Profile not found for user $userId');
    }

    return UserProfile.fromSupabase(
      profileRow: profileRows.first,
      visited: visited,
      email: _client.auth.currentUser?.email ?? '',
    );
  }

  // Sets display name and/or username (whichever is passed). The
  // database's profiles_username_format CHECK and profiles_username_key
  // unique index remain the real authority — a caller should validate
  // with UsernameRules first for UX, then be ready to catch a
  // PostgrestException with code 23505 (taken) or 23514 (invalid format)
  // from this call regardless.
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? username,
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null) payload['display_name'] = displayName;
    if (username != null) payload['username'] = username;
    if (payload.isEmpty) return;
    await _client.from('profiles').update(payload).eq('id', userId);
  }

  // Best-effort availability hint (debounced typing feedback) — not
  // authoritative; a race between the check and the actual update is
  // still possible and is still safely caught by the real DB constraint.
  Future<bool> isUsernameAvailable(String candidate) async {
    final result = await _client.rpc(
      'username_available',
      params: {'candidate': candidate},
    );
    return result as bool;
  }
}
