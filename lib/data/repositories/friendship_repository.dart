import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/blocked_user.dart';
import '../../models/friendship.dart';
import '../../models/profile_identity.dart';
import 'member_avatar_repository.dart';

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
///
/// Every identity read is enriched with the member's photo through
/// [MemberAvatarRepository] — the identity RPCs themselves still return
/// only the never-populated `avatar_url` (so build 1.5.0 keeps working
/// against them unchanged); photos that the viewer may not see, or every
/// photo before 20261031120000 is applied, fall back to initials.
class FriendshipRepository {
  FriendshipRepository(this._client, {MemberAvatarRepository? avatars})
    : _avatars = avatars ?? MemberAvatarRepository(_client);

  final SupabaseClient _client;
  final MemberAvatarRepository _avatars;

  Future<List<Friendship>> getFriends() async {
    final rows = await _client.rpc('get_friends');
    final friends = (rows as List)
        .map((r) => Friendship.fromRow(r as Map<String, dynamic>))
        .toList();
    final urls = await _avatars.urlsFor(friends.map((f) => f.friendId));
    return [for (final f in friends) f.withAvatar(urls[f.friendId])];
  }

  Future<List<FriendRequest>> getIncomingRequests() async {
    final rows = await _client.rpc('get_incoming_friend_requests');
    return _withRequestAvatars(
      (rows as List)
          .map((r) => FriendRequest.fromIncomingRow(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<FriendRequest>> getOutgoingRequests() async {
    final rows = await _client.rpc('get_outgoing_friend_requests');
    return _withRequestAvatars(
      (rows as List)
          .map((r) => FriendRequest.fromOutgoingRow(r as Map<String, dynamic>))
          .toList(),
    );
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
    final results = (rows as List)
        .map((r) => ProfileIdentity.fromRow(r as Map<String, dynamic>))
        .toList();
    final urls = await _avatars.urlsFor(results.map((p) => p.id));
    return [for (final p in results) p.withAvatar(urls[p.id])];
  }

  Future<List<FriendRequest>> _withRequestAvatars(
    List<FriendRequest> requests,
  ) async {
    final urls = await _avatars.urlsFor(requests.map((r) => r.otherUserId));
    return [for (final r in requests) r.withAvatar(urls[r.otherUserId])];
  }

  Future<ProfileIdentity?> getProfileIdentity(String userId) async {
    final rows = await _client.rpc(
      'get_profile_identity',
      params: {'target_user_id': userId},
    );
    final list = rows as List;
    if (list.isEmpty) return null;
    final identity = ProfileIdentity.fromRow(
      list.first as Map<String, dynamic>,
    );
    final urls = await _avatars.urlsFor([identity.id]);
    return identity.withAvatar(urls[identity.id]);
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

  // Only the person who set blocked_by may unblock — unblock_user's own
  // rule. Calling this on a block the current user didn't create throws.
  Future<void> unblockUser(String targetUserId) =>
      _client.rpc('unblock_user', params: {'target_user_id': targetUserId});

  // get_blocked_users() resolves the "other party" server-side, since
  // friendships is self-referencing (requester_id/addressee_id) with no
  // fixed column for it — see the RPC's own comment.
  Future<List<BlockedUser>> getBlockedUsers() async {
    final rows = await _client.rpc('get_blocked_users');
    // No photo lookup: a block hides the photo both ways by design.
    return (rows as List)
        .map((r) => BlockedUser.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  // Direct table delete — removes an accepted friendship, or cancels a
  // still-pending request the current user sent. RLS (friendships_delete)
  // restricts this to a row the caller is actually part of, in
  // 'pending'/'accepted' status only.
  Future<void> removeFriendship(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }
}
