import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/event_time.dart';
import '../../features/community/friends_activity.dart';
import '../../models/event.dart';
import '../../models/event_attendance.dart';
import '../../models/friendship.dart';
import 'events_repository.dart' show publishedEventsOnly;
import 'friendship_repository.dart';
import 'visited_repository.dart';

/// Loads Friends' Activity ([buildFriendActivity]) for the signed-in user.
///
/// No RPC and no migration: every query is a plain table read filtered to
/// the caller's accepted friends, so RLS decides what comes back exactly as
/// it does on a friend's profile — visits, Interested/Going and confirmed
/// attendance only where the friend chose `friends`, nothing once the
/// friendship ends or is blocked. Five queries regardless of how many
/// friends: friends, visits (+ one restaurants and one hotels lookup),
/// intents, stamps, and one events lookup shared by both.
class FriendActivityRepository {
  final SupabaseClient _client;
  final FriendshipRepository _friends;
  final VisitedRepository _visits;

  FriendActivityRepository(this._client)
    : _friends = FriendshipRepository(_client),
      _visits = VisitedRepository(_client);

  Future<List<FriendActivity>> load({List<Friendship>? friends}) async {
    final friendList = friends ?? await _friends.getFriends();
    final ids = [for (final f in friendList) f.friendId];
    if (ids.isEmpty) return const [];

    final (visitsByFriend, intentResult, stampResult) = await (
      _visits.loadPassportVenuesForUsers(ids),
      _client
          .from('event_attendance')
          .select('event_id, user_id, status, created_at')
          .inFilter('user_id', ids),
      _client
          .from('event_confirmed_attendance')
          .select('event_id, user_id, confirmed_at, rating')
          .inFilter('user_id', ids),
    ).wait;
    final intentRows = (intentResult as List).cast<Map<String, dynamic>>();
    final stampRows = (stampResult as List).cast<Map<String, dynamic>>();
    final eventsById = await _eventsById({
      for (final row in [...intentRows, ...stampRows])
        row['event_id'] as String,
    });

    final now = DateTime.now().toUtc();
    final intents = [
      for (final row in intentRows)
        if (eventsById[row['event_id'] as String] case final event?)
          if (event.cancelledAt == null &&
              !eventHasEnded(
                endAt: event.endAt,
                endDate: event.endDate,
                timezone: event.timezone,
                now: now,
              ))
            FriendEventIntent(
              userId: row['user_id'] as String,
              event: event,
              status: EventIntentStatus.fromDbValue(row['status'] as String?),
              createdAt: DateTime.parse(row['created_at'] as String),
            ),
    ];
    final stamps = [
      for (final row in stampRows)
        if (eventsById[row['event_id'] as String] case final event?)
          FriendEventStamp(
            userId: row['user_id'] as String,
            event: event,
            confirmedAt: DateTime.parse(row['confirmed_at'] as String),
            rating: (row['rating'] as num?)?.toInt(),
          ),
    ];

    return buildFriendActivity(
      friends: friendList,
      visitsByFriend: visitsByFriend,
      intents: intents,
      stamps: stamps,
    );
  }

  Future<Map<String, Event>> _eventsById(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('events')
        .select()
        .eq('moderation_status', publishedEventsOnly)
        .inFilter('id', ids.toList());
    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['id'].toString(): Event.fromJson(row),
    };
  }
}
