import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/friendship.dart';
import '../../models/profile_identity.dart';

/// Every friendship read/write goes through a Postgres RPC (Social
/// Foundation Step 1 migration), never a raw `.from('friendships')`
/// select/insert/update — see the migration's own comments for why:
/// state transitions (send/accept/decline/block) have rules subtler than
/// plain row ownership, and every identity-bearing read needs to work
/// regardless of the *other* person's `profiles.is_public` (profile
/// discoverability is deliberately not gated by that flag — see
/// FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md), which plain PostgREST
/// embedding through `profiles_read` RLS would silently break for a
/// private-profile friend. Only `remove` is a direct table operation —
/// removing a friendship is plain row ownership with no state-machine
/// subtlety, and the RLS `friendships_delete` policy already allows it.
class FriendshipRepository {
  FriendshipRepository(this._client);

  final SupabaseClient _client;

  Future<List<Friendship>> getFriends() async {
    final rows = await _client.rpc('get_friends');
    return (rows as List)
        .map((r) => Friendship.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequest>> getIncomingRequests() async {
    final rows = await _client.rpc('get_incoming_friend_requests');
    return (rows as List)
        .map((r) => FriendRequest.fromIncomingRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequest>> getOutgoingRequests() async {
    final rows = await _client.rpc('get_outgoing_friend_requests');
    return (rows as List)
        .map((r) => FriendRequest.fromOutgoingRow(r as Map<String, dynamic>))
        .toList();
  }

  // Minimum 2 characters, matching search_profiles' own floor — the RPC
  // returns an empty result for anything shorter, but checking here first
  // saves a round trip while the user is still mid-keystroke.
  Future<List<ProfileIdentity>> searchProfiles(String query) async {
    if (query.trim().length < 2) return [];
    final rows = await _client.rpc(
      'search_profiles',
      params: {'query': query.trim()},
    );
    return (rows as List)
        .map((r) => ProfileIdentity.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<ProfileIdentity?> getProfileIdentity(String userId) async {
    final rows = await _client.rpc(
      'get_profile_identity',
      params: {'target_user_id': userId},
    );
    final list = rows as List;
    if (list.isEmpty) return null;
    return ProfileIdentity.fromRow(list.first as Map<String, dynamic>);
  }

  // Every write RPC below throws a PostgrestException carrying the RPC's
  // own plain-English `raise exception` message (self-friend, already
  // pending, previously declined, blocked, not authorised, etc.) — the
  // exception's own message is already UI-safe; callers should surface
  // `error.message`, not translate it further.

  Future<void> sendRequest(String targetUserId) => _client.rpc(
    'send_friend_request',
    params: {'target_user_id': targetUserId},
  );

  Future<void> acceptRequest(String friendshipId) => _client.rpc(
    'accept_friend_request',
    params: {'friendship_id': friendshipId},
  );

  Future<void> declineRequest(String friendshipId) => _client.rpc(
    'decline_friend_request',
    params: {'friendship_id': friendshipId},
  );

  Future<void> blockUser(String targetUserId) =>
      _client.rpc('block_user', params: {'target_user_id': targetUserId});

  // Direct table delete — removes an accepted friendship, or cancels a
  // still-pending request the current user sent. RLS (friendships_delete)
  // restricts this to a row the caller is actually part of, in
  // 'pending'/'accepted' status only.
  Future<void> removeFriendship(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }
}
