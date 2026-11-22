import '../../data/repositories/venue_invite_repository.dart'
    show VenueInvitePlan;
import '../../data/repositories/visit_wine_repository.dart' show CellarWine;
import '../../models/event_attendance.dart';
import '../../models/friendship.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';

/// Community → Friends' "Plans in motion" (Friends round one, 2026-11-22,
/// idea 2): what the viewer is already planning with friends. Built only
/// from the viewer's own invites and the trips they are on; a friend's own
/// trips never show unless the viewer is on them too.
sealed class FriendPlan {
  const FriendPlan();
}

/// A venue invite between the viewer and [friend].
class InviteFriendPlan extends FriendPlan {
  final VenueInvitePlan invite;
  final Friendship friend;
  final bool sentByViewer;

  const InviteFriendPlan({
    required this.invite,
    required this.friend,
    required this.sentByViewer,
  });

  PassportVenue get venue => invite.venue;

  /// The small-caps line above the venue.
  String get eyebrow => switch ((invite.isAccepted, sentByViewer)) {
    (true, true) => '${friend.label} said yes',
    (true, false) => "You're going with ${friend.label}",
    (false, true) => 'Waiting for ${friend.label}',
    (false, false) => '${friend.label} suggested going together',
  };
}

/// An upcoming trip the viewer shares with [companions], the friends on it.
class TripFriendPlan extends FriendPlan {
  final PlannedTrip trip;
  final List<Friendship> companions;

  const TripFriendPlan({required this.trip, required this.companions});

  /// "With Thomas and Bram", "With Thomas, Bram and 2 others".
  String get companionsLine {
    final names = [for (final f in companions) f.label];
    if (names.length == 1) return 'With ${names.first}';
    if (names.length == 2) return 'With ${names[0]} and ${names[1]}';
    return 'With ${names[0]}, ${names[1]} and ${names.length - 2} '
        '${names.length - 2 == 1 ? 'other' : 'others'}';
  }
}

/// The plans to show, at most [take]: accepted invites first (most
/// recently answered first), then shared trips (soonest first), then
/// pending invites (newest first). An invite with someone who is no longer
/// a friend is left out, as is a trip with no friend on it besides the
/// viewer, or one that has ended by [today].
List<FriendPlan> plansInMotion({
  required List<VenueInvitePlan> invites,
  required List<PlannedTrip> trips,
  required Map<String, Set<String>> membersByTrip,
  required List<Friendship> friends,
  required String viewerId,
  required DateTime today,
  int take = 3,
}) {
  final byId = {for (final f in friends) f.friendId: f};
  final day = DateTime(today.year, today.month, today.day);

  InviteFriendPlan? toPlan(VenueInvitePlan invite) {
    final friend = byId[invite.otherUserId(viewerId)];
    if (friend == null) return null;
    return InviteFriendPlan(
      invite: invite,
      friend: friend,
      sentByViewer: invite.fromUserId == viewerId,
    );
  }

  final accepted =
      [
        for (final i in invites)
          if (i.isAccepted) ?toPlan(i),
      ]..sort((a, b) {
        final at = a.invite.respondedAt ?? a.invite.createdAt;
        final bt = b.invite.respondedAt ?? b.invite.createdAt;
        return bt.compareTo(at);
      });
  final pending = [
    for (final i in invites)
      if (!i.isAccepted) ?toPlan(i),
  ]..sort((a, b) => b.invite.createdAt.compareTo(a.invite.createdAt));

  final shared = <TripFriendPlan>[];
  for (final trip in trips) {
    if (trip.endDate.isBefore(day)) continue;
    final people = {trip.userId, ...?membersByTrip[trip.id]}..remove(viewerId);
    final companions = [for (final id in people) ?byId[id]]
      ..sort((a, b) => a.label.compareTo(b.label));
    if (companions.isEmpty) continue;
    shared.add(TripFriendPlan(trip: trip, companions: companions));
  }
  shared.sort((a, b) => a.trip.startDate.compareTo(b.trip.startDate));

  return <FriendPlan>[...accepted, ...shared, ...pending].take(take).toList();
}

/// A wine a friend would drink again, with whose it is.
class FriendAgainWine {
  final Friendship friend;
  final CellarWine wine;

  const FriendAgainWine({required this.friend, required this.wine});
}

/// Pairs each wine with its friend, dropping any whose owner isn't in
/// [friends] (a friendship ended between the two reads).
List<FriendAgainWine> friendAgainWines({
  required List<({String userId, CellarWine wine})> wines,
  required List<Friendship> friends,
}) {
  final byId = {for (final f in friends) f.friendId: f};
  return [
    for (final w in wines)
      if (byId[w.userId] case final friend?)
        FriendAgainWine(friend: friend, wine: w.wine),
  ];
}

/// Everything Friends round one adds to Community → Friends beyond
/// Friends' Activity, loaded in one go so the tab has one extra loading
/// state, not four.
class FriendsTabExtras {
  final Map<String, EventIntentStatus> myIntents;
  final Set<String> myVisitedKeys;
  final List<FriendPlan> plans;
  final List<FriendAgainWine> wines;

  const FriendsTabExtras({
    this.myIntents = const {},
    this.myVisitedKeys = const {},
    this.plans = const [],
    this.wines = const [],
  });

  static const empty = FriendsTabExtras();
}
