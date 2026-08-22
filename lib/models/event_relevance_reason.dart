// Events V2 Step 8A — the closed relevance-reason vocabulary. A [Event]
// (see event.dart) may internally qualify for several of these at once
// (e.g. it's during a planned trip AND a friend is going); only the single
// strongest one — per the fixed hierarchy in
// EVENTS_V2_STEP_8_PERSONALIZED_DISCOVERY_AUDIT.md — is ever surfaced as an
// [EventDiscoveryItem.primaryReason]. Deliberately NOT arbitrary strings: a
// sealed hierarchy so every call site (ranking, the card, analytics
// attribution) switches on a closed, typed set rather than string-matching.
//
// Pure Dart, no Flutter import — matches every other file in lib/models/
// (event.dart, planned_trip.dart, friendship.dart, going_member_count.dart).
// Icon selection for the card is a presentation concern and lives in
// event_card.dart instead.
library;

/// The five tiers below chronology, in the exact hierarchy order Step 8A
/// §2 fixes. [index] IS the ranking tier — see
/// event_discovery_ranking.dart's own sort, which reads this ordering
/// directly rather than re-declaring it.
enum EventRelevanceReasonType {
  trip,
  friendGoing,
  followedHost,
  friendInterested,
  popular,
}

sealed class EventRelevanceReason {
  const EventRelevanceReason();

  EventRelevanceReasonType get type;

  /// The exact copy the card renders — short, human, editorial-feeling
  /// (Step 8A §11/§12), never a raw count-only fragment.
  String get label;
}

/// Strongest tier — the event overlaps a trip the viewer has planned (via
/// the existing canonical [eventMatchesTrip]/[eventsMatchingTrip],
/// event_trip_match.dart — never re-derived here). [destinationLabel] is
/// the trip's city when known; null falls back to the safe generic phrase
/// rather than fabricating a place name.
class TripRelevanceReason extends EventRelevanceReason {
  final String? destinationLabel;
  const TripRelevanceReason({this.destinationLabel});

  @override
  EventRelevanceReasonType get type => EventRelevanceReasonType.trip;

  @override
  String get label {
    final destination = destinationLabel?.trim();
    if (destination != null && destination.isNotEmpty) {
      return 'During your $destination trip';
    }
    return 'During your upcoming trip';
  }
}

/// One or more accepted friends have marked GOING (Step 7's Friends Going
/// architecture, reused as-is — never a second friendship/attendance
/// implementation). [singleFriendName] is only used when [count] == 1,
/// matching Friends Going's own existing "Ward is going" singular phrasing.
class FriendGoingRelevanceReason extends EventRelevanceReason {
  final int count;
  final String? singleFriendName;
  const FriendGoingRelevanceReason({
    required this.count,
    this.singleFriendName,
  });

  @override
  EventRelevanceReasonType get type => EventRelevanceReasonType.friendGoing;

  @override
  String get label {
    final name = singleFriendName?.trim();
    if (count == 1 && name != null && name.isNotEmpty) {
      return '$name is going';
    }
    return '$count friends are going';
  }
}

/// The event has a canonical host (`is_host = true` on exactly the linking
/// row — see [eventHostFollowQualifies] in event_host_qualification.dart)
/// that the viewer follows. Venue-only or participant-only links never
/// produce this reason — that rule is non-negotiable (Step 8A §6).
/// [hostName] is the followed entity's display name when cheaply resolved;
/// null falls back to the generic, privacy-safe phrase.
class FollowedHostRelevanceReason extends EventRelevanceReason {
  final String? hostName;
  const FollowedHostRelevanceReason({this.hostName});

  @override
  EventRelevanceReasonType get type => EventRelevanceReasonType.followedHost;

  @override
  String get label {
    final name = hostName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'Hosted by $name';
    }
    return 'From a place you follow';
  }
}

/// One or more accepted friends have marked INTERESTED — same Step 7
/// architecture as [FriendGoingRelevanceReason], resolved a second time
/// against the Interested status rather than a separate implementation.
/// Always ranks below Going (Step 8A §7 — Going always outranks
/// Interested).
class FriendInterestedRelevanceReason extends EventRelevanceReason {
  final int count;
  final String? singleFriendName;
  const FriendInterestedRelevanceReason({
    required this.count,
    this.singleFriendName,
  });

  @override
  EventRelevanceReasonType get type =>
      EventRelevanceReasonType.friendInterested;

  @override
  String get label {
    final name = singleFriendName?.trim();
    if (count == 1 && name != null && name.isNotEmpty) {
      return '$name is interested';
    }
    return '$count friends are interested';
  }
}

/// The weakest visible tier — the event's capped Going count (Step 7's
/// [GoingMemberCount]) clears the "popular" band. No exact number is ever
/// implied by this reason's copy — see event_discovery_service.dart's own
/// threshold comment for why a plain boolean, not a count, is all this
/// class carries.
class PopularRelevanceReason extends EventRelevanceReason {
  const PopularRelevanceReason();

  @override
  EventRelevanceReasonType get type => EventRelevanceReasonType.popular;

  @override
  String get label => 'Popular with Chasing Stars members';
}
