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

    // Query user_tiers view for the authoritative tier.
    final tierRows = await _client
        .from('user_tiers')
        .select('tier, total_visits')
        .eq('user_id', userId)
        .limit(1);

    final tierName = (tierRows as List).isNotEmpty
        ? (tierRows.first['tier'] as String?) ?? 'Explorer'
        : 'Explorer';

    return UserProfile.fromSupabase(
      profileRow: profileRows.first as Map<String, dynamic>,
      visited: visited,
      tierFromDb: tierName,
    );
  }

  // Returns the community tier distribution from the tier_stats view.
  // Each entry: { tier: String, user_count: int }
  Future<List<Map<String, dynamic>>> getCommunityStats() async {
    final rows = await _client
        .from('tier_stats')
        .select('tier, user_count')
        .order('tier_order');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateDisplayName({
    required String userId,
    required String displayName,
  }) async {
    await _client
        .from('profiles')
        .update({'display_name': displayName, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }
}
