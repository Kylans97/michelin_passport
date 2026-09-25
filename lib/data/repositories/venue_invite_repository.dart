import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/passport_venue.dart';

/// Every write goes through a SECURITY DEFINER RPC (send_venue_invite/
/// accept_venue_invite/decline_venue_invite —
/// supabase/migrations/20260925140000_add_venue_invites.sql), mirroring
/// FriendshipRepository exactly: every RPC throws a PostgrestException
/// carrying its own plain-English `raise exception` message (self-invite,
/// not friends, already invited, no longer available) — that message is
/// already UI-safe; callers should surface `error.message`, not translate
/// it further.
///
/// Reads happen through `get_notifications()` (see NotificationsRepository
/// and AppNotification's invite* fields) — there is no separate "list my
/// sent/received invites" read here by design (see
/// EDITORIAL_REDESIGN_TRACKING.md's "Scope explicitly left out").
class VenueInviteRepository {
  VenueInviteRepository(this._client);

  final SupabaseClient _client;

  /// Returns the created invite's own id — unlike every other write here
  /// (and unlike FriendshipRepository's identical write RPCs), the caller
  /// genuinely needs this back: [AnalyticsEvent.venueInviteSent] requires
  /// [AnalyticsProperties.inviteId], which doesn't exist before this call
  /// returns. `send_venue_invite` returns the full `venue_invites` row
  /// (a single composite, not a set), so PostgREST hands it back as one
  /// JSON object, not a list.
  Future<String> sendInvite({
    required String toUserId,
    required PassportVenue venue,
    String? note,
  }) async {
    final (venueType, venueId) = switch (venue) {
      RestaurantVenue(:final restaurant) => ('restaurant', restaurant.id),
      HotelVenue(:final hotel) => ('hotel', hotel.id),
    };
    final result = await _client.rpc(
      'send_venue_invite',
      params: {
        'p_to_user_id': toUserId,
        'p_venue_type': venueType,
        'p_venue_id': venueId,
        'p_note': note,
      },
    );
    return (result as Map<String, dynamic>)['id'] as String;
  }

  Future<void> acceptInvite(String inviteId) =>
      _client.rpc('accept_venue_invite', params: {'p_invite_id': inviteId});

  Future<void> declineInvite(String inviteId) =>
      _client.rpc('decline_venue_invite', params: {'p_invite_id': inviteId});
}
