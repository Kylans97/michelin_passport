import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/friendship.dart';

class FriendshipRepository {
  FriendshipRepository(this._client);

  final SupabaseClient _client;

  // Returns accepted friends for the current user.
  Future<List<Friendship>> getFriends(String userId) async {
    final sent = await _client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, addressee:profiles!addressee_id(display_name, tier)')
        .eq('requester_id', userId)
        .eq('status', 'accepted');

    final received = await _client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, requester:profiles!requester_id(display_name, tier)')
        .eq('addressee_id', userId)
        .eq('status', 'accepted');

    return [
      ...(sent as List).map((r) => Friendship.asRequester(r as Map<String, dynamic>, userId)),
      ...(received as List).map((r) => Friendship.asAddressee(r as Map<String, dynamic>, userId)),
    ];
  }

  // Returns incoming pending friend requests (where current user is the addressee).
  Future<List<Friendship>> getPendingRequests(String userId) async {
    final rows = await _client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, requester:profiles!requester_id(display_name, tier)')
        .eq('addressee_id', userId)
        .eq('status', 'pending');

    return (rows as List)
        .map((r) => Friendship.asAddressee(r as Map<String, dynamic>, userId))
        .toList();
  }

  // Searches profiles by display_name (case-insensitive partial match).
  // Excludes the current user.
  Future<List<Map<String, dynamic>>> searchUsers(
    String query,
    String currentUserId,
  ) async {
    if (query.trim().isEmpty) return [];
    final rows = await _client
        .from('profiles')
        .select('id, display_name, tier')
        .ilike('display_name', '%$query%')
        .neq('id', currentUserId)
        .limit(20);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  // Sends a friend request to another user.
  Future<void> sendRequest({
    required String requesterId,
    required String addresseeId,
  }) async {
    try {
      await _client.from('friendships').insert({
        'requester_id': requesterId,
        'addressee_id': addresseeId,
        'status': 'pending',
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  // Accepts an incoming friend request by friendship id.
  Future<void> acceptRequest(String friendshipId) async {
    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  // Declines or cancels a friendship.
  Future<void> declineOrRemove(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  // Returns the total number of accepted friends.
  Future<int> getFriendCount(String userId) async {
    final sent = await _client
        .from('friendships')
        .select('id')
        .eq('requester_id', userId)
        .eq('status', 'accepted');
    final received = await _client
        .from('friendships')
        .select('id')
        .eq('addressee_id', userId)
        .eq('status', 'accepted');
    return (sent as List).length + (received as List).length;
  }
}
