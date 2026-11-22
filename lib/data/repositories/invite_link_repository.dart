import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/invite_link.dart';

/// Invite links (supabase/migrations/20261101670000_add_invite_links.sql).
/// Every write is a SECURITY DEFINER RPC; their `raise exception`
/// messages are plain sentences meant for the screen, so callers show
/// `error.message` as is, the way VenueInviteRepository's callers do.
///
/// [preview] is the one call that works signed out: the entrance shows
/// who invited you before you have an account.
class InviteLinkRepository {
  InviteLinkRepository(this._client);

  final SupabaseClient _client;

  Future<CreatedInviteLink> create({
    required InviteLinkKind kind,
    String? visitId,
    String? tripId,
    int maxUses = 1,
  }) async {
    final rows = await _client.rpc(
      'create_invite_link',
      params: {
        'p_kind': kind.wire,
        'p_visit_id': visitId,
        'p_trip_id': tripId,
        'p_max_uses': maxUses,
      },
    );
    final row = (rows as List).cast<Map<String, dynamic>>().single;
    return CreatedInviteLink(
      id: row['id'] as String,
      token: row['token'] as String,
      code: row['code'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  Future<InviteLinkPreview> preview(String token) async {
    final rows = await _client.rpc(
      'get_invite_link_preview',
      params: {'p_token': token},
    );
    final row = (rows as List).cast<Map<String, dynamic>>().single;
    return InviteLinkPreview.fromRow(row, token: token);
  }

  /// A typed code; state 'not_found' when it matches nothing. Ten misses
  /// an hour, then the server refuses with its own message.
  Future<InviteLinkPreview> previewByCode(String code) async {
    final rows = await _client.rpc(
      'get_invite_link_preview_by_code',
      params: {'p_code': code},
    );
    final row = (rows as List).cast<Map<String, dynamic>>().single;
    return InviteLinkPreview.fromRow(row);
  }

  Future<InviteLinkResult> redeem(String token, {bool addVisit = true}) async {
    final result = await _client.rpc(
      'redeem_invite_link',
      params: {'p_token': token, 'p_add_visit': addVisit},
    );
    return InviteLinkResult.fromJson(result as Map<String, dynamic>);
  }

  Future<void> revoke(String inviteId) =>
      _client.rpc('revoke_invite_link', params: {'p_invite_id': inviteId});

  /// Let someone in on the trip, or not: the sender or the trip's owner.
  Future<void> decideJoin(String redemptionId, {required bool approve}) =>
      _client.rpc(
        'decide_invite_link_join',
        params: {'p_redemption_id': redemptionId, 'p_approve': approve},
      );

  /// Undo one person's use of the caller's link.
  Future<void> removeUse(String redemptionId) => _client.rpc(
    'remove_invite_link_redemption',
    params: {'p_redemption_id': redemptionId},
  );

  Future<List<MyInviteLink>> myLinks() async {
    final rows = await _client.rpc('get_my_invite_links');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MyInviteLink.fromRow)
        .toList();
  }

  Future<List<InviteLinkUse>> uses(String inviteId) async {
    final rows = await _client.rpc(
      'get_invite_link_redemptions',
      params: {'p_invite_id': inviteId},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(InviteLinkUse.fromRow)
        .toList();
  }

  /// Whether [visitId] is a copy shared by someone else, whose date then
  /// follows theirs. False when the server predates the column.
  Future<bool> isSharedCopy(String visitId) async {
    try {
      final row = await _client
          .from('visits')
          .select('shared_from_visit_id')
          .eq('id', visitId)
          .maybeSingle();
      return row?['shared_from_visit_id'] != null;
    } on PostgrestException {
      return false;
    }
  }
}
