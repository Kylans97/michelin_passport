import '../../models/event.dart';
import '../../models/event_attendance.dart';
import '../../models/event_chronology.dart';
import '../../models/friendship.dart';
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/venue_entry.dart';
import '../../models/visit.dart';
import '../community/friends_activity.dart';
import 'friend_profile_data.dart' show wishlistVenueKey;
import 'friend_profile_screen.dart' show FriendVenueVisit;

/// Shapes for Friends round one (product owner, 2026-11-22: ideas 1, 2
/// and 3 from the Friends Ideas canvas, idea 4 later). Every function here
/// is pure and works only on rows the viewer can already read through
/// RLS: a friend's shared visits, their friends-visible Going/Interested,
/// trips both are on, and wines a friend may always show. Nothing widens
/// what a friend can see.
///
/// Saved events on a friend's wishlist are left out on purpose, although
/// RLS lets a friend read them: whether "saved" also means "shared with
/// friends" is still the product owner's call. Visit notes are left out
/// for the same reason.

/// A friend's score counts as a recommendation from this score up.
const friendRecommendationMinScore = 8.5;

/// The key a venue is matched on across two members' Passports: type and
/// id, never name (CLAUDE.md, "Identity").
String venueKey(PassportVenue venue) => wishlistVenueKey(venue);

/// Every venue key in [entries] that has at least one visit.
Set<String> visitedVenueKeys(List<VenueEntry> entries) => {
  for (final entry in entries)
    if (entry.visits.isNotEmpty) venueKey(entry.venue),
};

/// The viewer's own intent next to a friend's, as the one line shown under
/// an event: null when the viewer has none.
String? ownIntentLine({
  required EventIntentStatus? mine,
  required bool friendGoing,
  required bool friendInterested,
}) => switch (mine) {
  EventIntentStatus.going when friendGoing => "You're both going",
  EventIntentStatus.going => "You're going",
  EventIntentStatus.interested when friendInterested =>
    "You're both interested",
  EventIntentStatus.interested => "You're interested too",
  null => null,
};

// ── Community → Friends ─────────────────────────────────────────────────

/// One upcoming event with the friends going to or interested in it.
class EventWithFriends {
  final Event event;
  final List<Friendship> going;
  final List<Friendship> interested;
  final EventIntentStatus? mine;

  const EventWithFriends({
    required this.event,
    required this.going,
    required this.interested,
    required this.mine,
  });

  /// "Elise and Thomas are going", "Sanne is interested", or both halves
  /// joined with " · ".
  String get friendsLine {
    String names(List<Friendship> people) {
      final labels = [for (final p in people) p.label];
      if (labels.length <= 2) return labels.join(' and ');
      return '${labels.first} and ${labels.length - 1} others';
    }

    String verb(List<Friendship> people, String one, String many) =>
        people.length == 1 ? one : many;

    return [
      if (going.isNotEmpty) '${names(going)} ${verb(going, 'is', 'are')} going',
      if (interested.isNotEmpty)
        '${names(interested)} ${verb(interested, 'is', 'are')} interested',
    ].join(' · ');
  }

  String? get mineLine => ownIntentLine(
    mine: mine,
    friendGoing: going.isNotEmpty,
    friendInterested: interested.isNotEmpty,
  );
}

/// "Coming up with friends": the upcoming events in [activity] that
/// friends are going to or interested in, one entry per event, soonest
/// first. [activity] holds only events that haven't ended
/// (FriendActivityRepository drops the rest). A friend who is going is
/// never also listed as interested.
List<EventWithFriends> eventsWithFriends({
  required List<FriendActivity> activity,
  required Map<String, EventIntentStatus> myIntents,
}) {
  final events = <String, Event>{};
  final going = <String, Map<String, Friendship>>{};
  final interested = <String, Map<String, Friendship>>{};
  for (final item in activity) {
    if (item is! EventIntentActivity) continue;
    final id = item.event.id;
    events[id] = item.event;
    final bucket = item.status == EventIntentStatus.going ? going : interested;
    (bucket[id] ??= {})[item.friend.friendId] = item.friend;
  }
  final result = [
    for (final MapEntry(key: id, value: event) in events.entries)
      EventWithFriends(
        event: event,
        going: (going[id] ?? const {}).values.toList(),
        interested: [
          for (final f in (interested[id] ?? const {}).values)
            if (!(going[id]?.containsKey(f.friendId) ?? false)) f,
        ],
        mine: myIntents[id],
      ),
  ]..sort((a, b) => compareEventChronology(a.event, b.event));
  return result;
}

/// One venue friends scored highly, with each friend's best score there.
class VenueLovedByFriends {
  final PassportVenue venue;
  final List<({Friendship friend, double score, Visit visit})> scores;

  const VenueLovedByFriends({required this.venue, required this.scores});

  double get topScore => scores.first.score;
}

/// "Loved by your friends": venues friends scored
/// [friendRecommendationMinScore] or higher that aren't in the viewer's
/// own Passport ([myVisitedKeys]), best first, then the most friends.
List<VenueLovedByFriends> venuesLovedByFriends({
  required List<FriendActivity> activity,
  required Set<String> myVisitedKeys,
}) {
  final venues = <String, PassportVenue>{};
  final best =
      <String, Map<String, ({Friendship friend, double score, Visit visit})>>{};
  for (final item in activity) {
    if (item is! VisitActivity) continue;
    final score = item.visit.rating;
    if (score == null || score < friendRecommendationMinScore) continue;
    final key = venueKey(item.venue);
    if (myVisitedKeys.contains(key)) continue;
    venues[key] = item.venue;
    final byFriend = best[key] ??= {};
    final current = byFriend[item.friend.friendId];
    if (current == null || score > current.score) {
      byFriend[item.friend.friendId] = (
        friend: item.friend,
        score: score,
        visit: item.visit,
      );
    }
  }
  final result = [
    for (final MapEntry(key: key, value: byFriend) in best.entries)
      VenueLovedByFriends(
        venue: venues[key]!,
        scores: byFriend.values.toList()
          ..sort((a, b) => b.score.compareTo(a.score)),
      ),
  ];
  result.sort((a, b) {
    final byScore = b.topScore.compareTo(a.topScore);
    if (byScore != 0) return byScore;
    final byCount = b.scores.length.compareTo(a.scores.length);
    if (byCount != 0) return byCount;
    return a.venue.name.compareTo(b.venue.name);
  });
  return result;
}

// ── Friend profile ──────────────────────────────────────────────────────

/// One event on a friend's "Coming up", with the viewer's own intent.
class FriendUpcomingEvent {
  final Event event;
  final EventIntentStatus friendStatus;
  final EventIntentStatus? mine;

  const FriendUpcomingEvent({
    required this.event,
    required this.friendStatus,
    required this.mine,
  });

  String? get mineLine => ownIntentLine(
    mine: mine,
    friendGoing: friendStatus == EventIntentStatus.going,
    friendInterested: friendStatus == EventIntentStatus.interested,
  );

  /// Both have an intent: the event belongs in "Events you could go to
  /// together".
  bool get isShared => mine != null;
}

/// A friend's upcoming events, soonest first. An event in both lists
/// counts as Going; a cancelled event is left out.
List<FriendUpcomingEvent> friendUpcomingEvents({
  required List<Event> going,
  required List<Event> interested,
  required Map<String, EventIntentStatus> myIntents,
}) {
  final goingIds = {for (final e in going) e.id};
  return [
    for (final e in going)
      if (e.cancelledAt == null)
        FriendUpcomingEvent(
          event: e,
          friendStatus: EventIntentStatus.going,
          mine: myIntents[e.id],
        ),
    for (final e in interested)
      if (!goingIds.contains(e.id) && e.cancelledAt == null)
        FriendUpcomingEvent(
          event: e,
          friendStatus: EventIntentStatus.interested,
          mine: myIntents[e.id],
        ),
  ]..sort((a, b) => compareEventChronology(a.event, b.event));
}

/// "Recommended by {name}": the friend's best visit per venue, scored
/// [friendRecommendationMinScore] or higher, at venues not in the viewer's
/// Passport. Best first, the most recent first on a tie.
List<FriendVenueVisit> recommendedByFriend({
  required List<FriendVenueVisit> visits,
  required Set<String> myVisitedKeys,
}) {
  final best = <String, FriendVenueVisit>{};
  for (final fv in visits) {
    final score = fv.visit.rating;
    if (score == null || score < friendRecommendationMinScore) continue;
    final key = venueKey(fv.venue);
    if (myVisitedKeys.contains(key)) continue;
    final current = best[key];
    if (current == null || score > current.visit.rating!) best[key] = fv;
  }
  return best.values.toList()..sort((a, b) {
    final byScore = b.visit.rating!.compareTo(a.visit.rating!);
    if (byScore != 0) return byScore;
    return b.visit.visitedOn.compareTo(a.visit.visitedOn);
  });
}

/// A venue both have been to, with each one's latest rated score (null
/// when that one didn't rate it).
class SharedVenueScores {
  final PassportVenue venue;
  final double? theirs;
  final double? mine;
  final DateTime lastVisited;

  const SharedVenueScores({
    required this.venue,
    required this.theirs,
    required this.mine,
    required this.lastVisited,
  });
}

double? _latestScore(List<Visit> visits) {
  final rated = visits.where((v) => v.rating != null).toList()
    ..sort((a, b) => b.visitedOn.compareTo(a.visitedOn));
  return rated.isEmpty ? null : rated.first.rating;
}

/// "Where your tastes meet": every venue in both Passports, most recently
/// visited by either first. Compared per place only: no overall match
/// figure and no ranking of friends.
List<SharedVenueScores> sharedVenueScores({
  required List<VenueEntry> theirs,
  required List<VenueEntry> mine,
}) {
  final mineByKey = {
    for (final e in mine)
      if (e.visits.isNotEmpty) venueKey(e.venue): e,
  };
  final result = <SharedVenueScores>[];
  for (final entry in theirs) {
    if (entry.visits.isEmpty) continue;
    final own = mineByKey[venueKey(entry.venue)];
    if (own == null) continue;
    final dates = [
      for (final v in [...entry.visits, ...own.visits]) v.visitedOn,
    ];
    result.add(
      SharedVenueScores(
        venue: entry.venue,
        theirs: _latestScore(entry.visits),
        mine: _latestScore(own.visits),
        lastVisited: dates.reduce((a, b) => a.isAfter(b) ? a : b),
      ),
    );
  }
  return result..sort((a, b) => b.lastVisited.compareTo(a.lastVisited));
}

/// One city in a friend's Passport, with their visits there newest first.
class FriendCity {
  final String cityName;
  final String countryCode;
  final List<FriendVenueVisit> visits;

  const FriendCity({
    required this.cityName,
    required this.countryCode,
    required this.visits,
  });

  /// Distinct venues, the number shown on the tile.
  int get placeCount => {for (final v in visits) venueKey(v.venue)}.length;
}

String _cityOf(PassportVenue venue) => switch (venue) {
  RestaurantVenue(:final restaurant) => restaurant.cityName,
  HotelVenue(:final hotel) => hotel.cityName,
};

/// The friend's cities, the most places first. A city is keyed on name
/// and country together, so two cities sharing a name stay apart.
List<FriendCity> friendCities(List<FriendVenueVisit> visits) {
  final byCity = <String, List<FriendVenueVisit>>{};
  for (final fv in visits) {
    final city = _cityOf(fv.venue).trim();
    if (city.isEmpty) continue;
    (byCity['${fv.venue.countryCode}|$city'] ??= []).add(fv);
  }
  final result = [
    for (final group in byCity.values)
      FriendCity(
        cityName: _cityOf(group.first.venue).trim(),
        countryCode: group.first.venue.countryCode,
        visits: group,
      ),
  ];
  return result..sort((a, b) {
    final byCount = b.placeCount.compareTo(a.placeCount);
    if (byCount != 0) return byCount;
    return a.cityName.compareTo(b.cityName);
  });
}

/// The countries with the most of the friend's visits, at most [take],
/// for the one quiet line at the top of Taste. A country counts once per
/// visit.
List<String> topCountryCodes(List<FriendVenueVisit> visits, {int take = 2}) {
  final counts = <String, int>{};
  for (final fv in visits) {
    final code = fv.venue.countryCode.toUpperCase();
    if (code.isEmpty) continue;
    counts[code] = (counts[code] ?? 0) + 1;
  }
  final codes = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return codes.take(take).toList();
}

/// The trips in [trips] (the viewer's own and those they accepted) that
/// [friendId] is also on, as owner or accepted member, and that haven't
/// ended by [today]. Soonest first.
List<PlannedTrip> tripsWithFriend({
  required List<PlannedTrip> trips,
  required Map<String, Set<String>> membersByTrip,
  required String friendId,
  required DateTime today,
}) {
  final day = DateTime(today.year, today.month, today.day);
  return [
    for (final trip in trips)
      if ((trip.userId == friendId ||
              (membersByTrip[trip.id]?.contains(friendId) ?? false)) &&
          !trip.endDate.isBefore(day))
        trip,
  ]..sort((a, b) => a.startDate.compareTo(b.startDate));
}

/// Country names that read with "the" in a sentence ("Most often in the
/// Netherlands"), by ISO code.
const _countriesWithThe = {
  'NL',
  'GB',
  'US',
  'AE',
  'PH',
  'CZ',
  'MV',
  'BS',
  'DO',
  'CF',
  'KY',
  'VA',
};

/// [name] as it reads inside a sentence: "the Netherlands", "Spain".
String countryInSentence(String code, String name) =>
    _countriesWithThe.contains(code.toUpperCase()) &&
        !name.toLowerCase().startsWith('the ')
    ? 'the $name'
    : name;
