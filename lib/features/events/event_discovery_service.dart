import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/event_host_follow_repository.dart';
import '../../data/repositories/event_social_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/planned_trips_repository.dart';
import '../../models/event.dart';
import '../../models/event_attendance.dart';
import '../../models/event_discovery_item.dart';
import '../../models/event_trip_match.dart';
import '../../models/friendship.dart';
import '../../models/planned_trip.dart';
import 'event_discovery_ranking.dart';
import 'friends_going_view_model.dart';

// The capped Going count (Step 7's get_event_going_member_count) an event
// needs to clear before "popular" becomes its visible reason. Reuses the
// exact threshold the sibling get_event_attendance_count function already
// established for its own k-anonymity cutoff (that function is NOT called
// or modified here — only its precedent number) — a principled reuse of an
// existing convention rather than an arbitrary new one. Today's production
// Going counts (0-1) sit well below this, so "popular" will rarely if ever
// appear yet; per Step 8A §8, that is the correct, honest MVP behavior, not
// a bug to work around by lowering the bar to fake popularity.
const _popularThreshold = 5;

/// Events V2 Step 8A — turns a plain chronological [Event] list into a
/// ranked [EventDiscoveryItem] list: personalization is layered on top of,
/// never a replacement for, the base Events query EventsScreen already
/// runs. Every signal source (Trips, Friends Going, Followed Host, Friends
/// Interested, Popularity) loads independently and fails independently —
/// see [rankForDiscovery]'s own per-source try/catch — so a single failing
/// source degrades that one signal to "absent," never the whole screen to
/// an error state (Step 8A §15).
class EventDiscoveryService {
  EventDiscoveryService({
    required this.attendanceRepo,
    required this.friendshipRepo,
    required this.tripsRepo,
    required this.hostFollowRepo,
    required this.socialRepo,
  });

  final EventAttendanceRepository attendanceRepo;
  final FriendshipRepository friendshipRepo;
  final PlannedTripsRepository tripsRepo;
  final EventHostFollowRepository hostFollowRepo;
  final EventSocialRepository socialRepo;

  /// Ranks [events] for [userId] — a signed-out/unknown [userId] or an
  /// empty [events] list short-circuits straight to plain chronological
  /// order with no reason on any card, exactly matching cold start (Step
  /// 8A §17): zero signal sources are even attempted, not "attempted and
  /// found empty."
  Future<List<EventDiscoveryItem>> rankForDiscovery({
    required List<Event> events,
    required String? userId,
  }) async {
    if (userId == null || events.isEmpty) {
      return [for (final event in events) EventDiscoveryItem(event: event)];
    }

    final eventIds = [for (final event in events) event.id];

    // Start every signal source together, await in turn — this project's
    // established "parallel start, sequential await" convention (see
    // EventDetailScreen._load()) — never one source's failure blocking or
    // delaying another's result.
    final tripSignalsFuture = _safeTripSignals(userId: userId, events: events);
    final friendsFuture = _safeFriends();
    final goingUserIdsFuture = _safeVisibleUserIdsForEvents(
      eventIds: eventIds,
      status: EventIntentStatus.going,
    );
    final interestedUserIdsFuture = _safeVisibleUserIdsForEvents(
      eventIds: eventIds,
      status: EventIntentStatus.interested,
    );
    final followedHostNamesFuture = _safeFollowedHostNames(
      userId: userId,
      eventIds: eventIds,
    );

    final tripSignals = await tripSignalsFuture;
    final friends = await friendsFuture;
    final goingUserIds = await goingUserIdsFuture;
    final interestedUserIds = await interestedUserIdsFuture;
    final followedHostNames = await followedHostNamesFuture;

    var signalsByEventId = <String, EventRelevanceSignals>{};
    final needsPopularityCheck = <String>[];

    for (final event in events) {
      final goingFriends = friendsGoingToEvent(
        attendeeUserIds: goingUserIds[event.id] ?? const [],
        friends: friends,
        selfUserId: userId,
      );
      final interestedFriends = friendsGoingToEvent(
        attendeeUserIds: interestedUserIds[event.id] ?? const [],
        friends: friends,
        selfUserId: userId,
      );

      final signals = EventRelevanceSignals(
        tripMatch: tripSignals.containsKey(event.id),
        tripDestinationLabel: tripSignals[event.id],
        friendsGoingCount: goingFriends.length,
        singleFriendGoingName: goingFriends.length == 1
            ? goingFriends.first.label
            : null,
        followedHost: followedHostNames.containsKey(event.id),
        followedHostName: followedHostNames[event.id],
        friendsInterestedCount: interestedFriends.length,
        singleFriendInterestedName: interestedFriends.length == 1
            ? interestedFriends.first.label
            : null,
      );
      signalsByEventId[event.id] = signals;

      // Popularity is the weakest tier (Step 8A §8) — only worth checking
      // for events that don't already have a stronger reason, so an active
      // user's real personalization never pays for a popularity RPC call
      // it will never actually surface.
      if (primaryReasonFor(signals) == null) {
        needsPopularityCheck.add(event.id);
      }
    }

    if (needsPopularityCheck.isNotEmpty) {
      final popularEventIds = await _safePopularEventIds(needsPopularityCheck);
      if (popularEventIds.isNotEmpty) {
        signalsByEventId = {
          for (final entry in signalsByEventId.entries)
            entry.key: popularEventIds.contains(entry.key)
                ? entry.value.withPopular(true)
                : entry.value,
        };
      }
    }

    return rankEventsForDiscovery(
      events: events,
      signalsByEventId: signalsByEventId,
    );
  }

  // Every event id -> the trip destination label (may itself be null —
  // "matched, but no city known" — see TripRelevanceReason's own fallback
  // copy) for every trip/event match found via the canonical
  // eventsMatchingTrip (event_trip_match.dart) — never a second matching
  // definition. A trip's own start_date ordering (loadTrips already sorts
  // ascending) makes the first trip a given event matches the one whose
  // destination is used, when an event improbably overlaps more than one
  // trip.
  Future<Map<String, String?>> _safeTripSignals({
    required String userId,
    required List<Event> events,
  }) async {
    try {
      final trips = await tripsRepo.loadTrips(userId);
      if (trips.isEmpty) return {};
      final result = <String, String?>{};
      for (final trip in trips) {
        for (final event in eventsMatchingTrip(events, trip)) {
          result.putIfAbsent(event.id, () => _tripDestinationLabel(trip));
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  String? _tripDestinationLabel(PlannedTrip trip) {
    final city = trip.city?.trim();
    return (city != null && city.isNotEmpty) ? city : null;
  }

  Future<List<Friendship>> _safeFriends() async {
    try {
      return await friendshipRepo.getFriends();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, List<String>>> _safeVisibleUserIdsForEvents({
    required List<String> eventIds,
    required EventIntentStatus status,
  }) async {
    try {
      return await attendanceRepo.getVisibleUserIdsForEvents(
        eventIds: eventIds,
        status: status,
      );
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, String?>> _safeFollowedHostNames({
    required String userId,
    required List<String> eventIds,
  }) async {
    try {
      return await hostFollowRepo.getFollowedHostEventNames(
        userId: userId,
        eventIds: eventIds,
      );
    } catch (_) {
      return {};
    }
  }

  // A genuine per-event RPC call (get_event_going_member_count has no
  // batched/array variant — see EventSocialRepository's own doc comment),
  // but only ever issued for events that reached this point without a
  // stronger reason, and only ever run in parallel, never sequentially.
  // Each call's own failure is caught individually so one event's RPC
  // error can never suppress another event's already-succeeded result.
  Future<List<String>> _safePopularEventIds(List<String> eventIds) async {
    final results = await Future.wait([
      for (final eventId in eventIds) _popularityCheck(eventId),
    ]);
    return [
      for (final (id, isPopular) in results)
        if (isPopular) id,
    ];
  }

  Future<(String, bool)> _popularityCheck(String eventId) async {
    try {
      final count = await socialRepo.getGoingMemberCount(eventId);
      return (eventId, count.count >= _popularThreshold);
    } catch (_) {
      return (eventId, false);
    }
  }
}
