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

  // PROFILE PRIVACY & DISCOVERABILITY V1 — [userId] is always the
  // caller's own id at every real call site (Privacy Settings only ever
  // reads/writes the signed-in user's own row), which is also the only
  // row `profiles_read`/`profiles_update` RLS permits either of these to
  // touch — a user cannot read or write another user's is_discoverable
  // through this repository, enforced server-side, not just by this
  // method's own calling convention. Governs Find Friends discovery
  // ONLY — see the column's own migration comment
  // (`20260825160000_profile_privacy_discoverability_v1.sql`) for why
  // this never affects visits/wishlist/photos/Trips/event visibility.
  Future<bool> getDiscoverable(String userId) async {
    final row = await _client
        .from('profiles')
        .select('is_discoverable')
        .eq('id', userId)
        .limit(1)
        .single();
    return row['is_discoverable'] as bool? ?? true;
  }

  Future<void> setDiscoverable({
    required String userId,
    required bool value,
  }) async {
    await _client
        .from('profiles')
        .update({'is_discoverable': value})
        .eq('id', userId);
  }
}
