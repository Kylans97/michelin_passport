import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/passport_venue.dart';
import 'hotel_repository.dart';
import 'restaurant_repository.dart';

/// One of the caller's own venue invites, sent or received, with its venue.
class VenueInvitePlan {
  final String id;
  final String fromUserId;
  final String toUserId;
  final PassportVenue venue;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const VenueInvitePlan({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.venue,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isAccepted => status == 'accepted';

  /// The other member: the recipient if [viewerId] sent it, else the sender.
  String otherUserId(String viewerId) =>
      fromUserId == viewerId ? toUserId : fromUserId;
}

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
/// and AppNotification's invite* fields), plus [loadPlansInMotion] for
/// Community → Friends' "Plans in motion" (2026-11-22), which reads the
/// caller's own invites directly: `venue_invites_select` already lets a
/// sender and a recipient read their own rows, and nobody else's.
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

  /// The caller's invites that are still a plan: pending and not expired,
  /// or accepted in the last [acceptedWithin]. Declined ones are never
  /// shown. Newest first. A venue that no longer resolves (removed from the
  /// catalogue) drops its invite rather than showing a blank row.
  Future<List<VenueInvitePlan>> loadPlansInMotion(
    String viewerId, {
    Duration acceptedWithin = const Duration(days: 30),
  }) async {
    final now = DateTime.now().toUtc();
    final rows = await _client
        .from('venue_invites')
        .select(
          'id, from_user_id, to_user_id, venue_type, venue_id, status, '
          'created_at, responded_at, expires_at',
        )
        .or('from_user_id.eq.$viewerId,to_user_id.eq.$viewerId')
        .inFilter('status', ['pending', 'accepted'])
        .order('created_at', ascending: false)
        .limit(20);
    final open = [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        if (switch (row['status']) {
          'pending' => DateTime.parse(row['expires_at'] as String).isAfter(now),
          'accepted' => switch (row['responded_at']) {
            final String at =>
              now.difference(DateTime.parse(at)) <= acceptedWithin,
            _ => false,
          },
          _ => false,
        })
          row,
    ];
    if (open.isEmpty) return const [];

    final restaurants = RestaurantRepository(_client);
    final hotels = HotelRepository(_client);
    final venues = await Future.wait([
      for (final row in open)
        (row['venue_type'] == 'hotel'
                ? hotels
                      .getById(row['venue_id'] as String)
                      .then((h) => h == null ? null : HotelVenue(h))
                : restaurants
                      .getById(row['venue_id'] as String)
                      .then((r) => r == null ? null : RestaurantVenue(r)))
            .then<PassportVenue?>((v) => v)
            .catchError((_) => null),
    ]);
    return [
      for (final (i, row) in open.indexed)
        if (venues[i] case final venue?)
          VenueInvitePlan(
            id: row['id'] as String,
            fromUserId: row['from_user_id'] as String,
            toUserId: row['to_user_id'] as String,
            venue: venue,
            status: row['status'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            respondedAt: switch (row['responded_at']) {
              final String at => DateTime.parse(at),
              _ => null,
            },
          ),
    ];
  }

  Future<void> acceptInvite(String inviteId) =>
      _client.rpc('accept_venue_invite', params: {'p_invite_id': inviteId});

  Future<void> declineInvite(String inviteId) =>
      _client.rpc('decline_venue_invite', params: {'p_invite_id': inviteId});
}
