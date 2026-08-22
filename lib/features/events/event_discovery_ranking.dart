import '../../models/event.dart';
import '../../models/event_discovery_item.dart';
import '../../models/event_relevance_reason.dart';

/// Per-event relevance inputs the ranking function consumes, already
/// resolved by event_discovery_service.dart from Trips/Friends/Follow/
/// Popularity signals. Booleans/counts/optional display strings only — this
/// class never touches Supabase and never knows HOW a signal was resolved,
/// only THAT it applies to a given event. Kept separate from
/// [EventRelevanceReason] itself: a reason is "the one thing to show," a
/// signals bundle is "everything this event happens to qualify for," which
/// the ranking function below reduces down to the single strongest reason.
class EventRelevanceSignals {
  final bool tripMatch;
  final String? tripDestinationLabel;
  final int friendsGoingCount;
  final String? singleFriendGoingName;
  final bool followedHost;
  final String? followedHostName;
  final int friendsInterestedCount;
  final String? singleFriendInterestedName;
  final bool popular;

  const EventRelevanceSignals({
    this.tripMatch = false,
    this.tripDestinationLabel,
    this.friendsGoingCount = 0,
    this.singleFriendGoingName,
    this.followedHost = false,
    this.followedHostName,
    this.friendsInterestedCount = 0,
    this.singleFriendInterestedName,
    this.popular = false,
  });

  static const none = EventRelevanceSignals();

  /// Returns a copy with [popular] set — the one field the discovery
  /// service fills in as a second pass, after tiers 1-4 are already known
  /// (see that file's own "only where needed" popularity comment).
  EventRelevanceSignals withPopular(bool value) => EventRelevanceSignals(
    tripMatch: tripMatch,
    tripDestinationLabel: tripDestinationLabel,
    friendsGoingCount: friendsGoingCount,
    singleFriendGoingName: singleFriendGoingName,
    followedHost: followedHost,
    followedHostName: followedHostName,
    friendsInterestedCount: friendsInterestedCount,
    singleFriendInterestedName: singleFriendInterestedName,
    popular: value,
  );
}

/// Resolves the strongest [EventRelevanceReason] for one event's signals,
/// per the fixed hierarchy (Step 8A §2): Trip > Friend Going > Followed
/// Host > Friend Interested > Popularity > (no visible reason — chronology
/// is the fallback, never rendered as a reason itself). An event may
/// satisfy several signals simultaneously; only the first (strongest)
/// match below is ever returned.
EventRelevanceReason? primaryReasonFor(EventRelevanceSignals signals) {
  if (signals.tripMatch) {
    return TripRelevanceReason(destinationLabel: signals.tripDestinationLabel);
  }
  if (signals.friendsGoingCount > 0) {
    return FriendGoingRelevanceReason(
      count: signals.friendsGoingCount,
      singleFriendName: signals.singleFriendGoingName,
    );
  }
  if (signals.followedHost) {
    return FollowedHostRelevanceReason(hostName: signals.followedHostName);
  }
  if (signals.friendsInterestedCount > 0) {
    return FriendInterestedRelevanceReason(
      count: signals.friendsInterestedCount,
      singleFriendName: signals.singleFriendInterestedName,
    );
  }
  if (signals.popular) {
    return const PopularRelevanceReason();
  }
  return null;
}

/// Builds the ranked, deduplicated discovery list — pure, deterministic, no
/// ML/randomization/opaque score (Step 8A §10). Every entry in [events]
/// appears in the result exactly once; [signalsByEventId] is a lookup keyed
/// by [Event.id] — a missing entry is treated as [EventRelevanceSignals.
/// none], never an error, since failure-isolated personalization loading
/// may legitimately have no signals for some or all events (Step 8A §15).
///
/// Ordering: relevance tier ascending (Trip first, then Friend Going,
/// Followed Host, Friend Interested, Popular, then "no reason" last),
/// then [Event.startAt] ascending within a tier, then [Event.id] ascending
/// as a final, purely-mechanical tiebreaker for two events sharing the
/// exact same instant — never a meaningful ranking signal itself. A user
/// with zero personalization state (cold start) gets every event with a
/// null [EventDiscoveryItem.primaryReason], which collapses this sort to
/// plain [Event.startAt] order — the exact same order [events] was already
/// in, since EventsRepository.loadEvents already orders by start_at.
List<EventDiscoveryItem> rankEventsForDiscovery({
  required List<Event> events,
  required Map<String, EventRelevanceSignals> signalsByEventId,
}) {
  final items = [
    for (final event in events)
      EventDiscoveryItem(
        event: event,
        primaryReason: primaryReasonFor(
          signalsByEventId[event.id] ?? EventRelevanceSignals.none,
        ),
      ),
  ];
  items.sort((a, b) {
    final tierCompare = _tierOf(
      a.primaryReason,
    ).compareTo(_tierOf(b.primaryReason));
    if (tierCompare != 0) return tierCompare;
    final startCompare = a.event.startAt.compareTo(b.event.startAt);
    if (startCompare != 0) return startCompare;
    return a.event.id.compareTo(b.event.id);
  });
  return items;
}

int _tierOf(EventRelevanceReason? reason) {
  if (reason == null) return EventRelevanceReasonType.values.length;
  return reason.type.index;
}
