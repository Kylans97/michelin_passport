import '../../models/event.dart';
import '../../models/event_attendance.dart';
import '../../models/friendship.dart';
import '../../models/passport_venue.dart';
import '../../models/venue_entry.dart';
import '../../models/visit.dart';

/// Community → Friends → Friends' Activity: what the people you are friends
/// with have done lately, merged across friends and newest first.
///
/// Derived, never authored (FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md §4.3):
/// every item is built from rows the viewer can already read through RLS —
/// visits and confirmed attendances the friend marked `friends`, and their
/// friends-visible Interested/Going. Nothing here widens what a friend can
/// see; it only puts what is already visible in one place. Milestones are
/// counted over those same visible visits only, so a private visit never
/// shows up indirectly as "10th starred restaurant".
///
/// Personal community-ranking ratings (`venue_ratings`) are deliberately
/// absent: they are owner-only by design (20260828120000), and the rating a
/// friend shares is the one on their visit.
sealed class FriendActivity {
  final Friendship friend;

  /// When it happened, used only for ordering. A visit's is its calendar
  /// date (no clock time exists for it); intents and stamps use the moment
  /// the row was written.
  final DateTime sortDate;

  const FriendActivity({required this.friend, required this.sortDate});
}

/// A milestone reached by one visit, shown on that visit's own row rather
/// than as a separate item, so the same dinner never appears twice.
sealed class FriendMilestone {
  const FriendMilestone();
}

/// The friend's first shared venue in a country.
class FirstInCountryMilestone extends FriendMilestone {
  final String countryCode;
  const FirstInCountryMilestone(this.countryCode);
}

/// The Nth distinct MICHELIN-starred restaurant, at one of
/// [starredRestaurantMilestones].
class StarredCountMilestone extends FriendMilestone {
  final int count;
  const StarredCountMilestone(this.count);
}

/// The friend's first three-star restaurant.
class FirstThreeStarMilestone extends FriendMilestone {
  const FirstThreeStarMilestone();
}

/// A visit (restaurant) or stay (hotel), with any milestones it reached.
/// Each visit is also a Passport stamp in this app's one-stamp-per-visit
/// model.
class VisitActivity extends FriendActivity {
  final PassportVenue venue;
  final Visit visit;
  final List<FriendMilestone> milestones;

  const VisitActivity({
    required super.friend,
    required super.sortDate,
    required this.venue,
    required this.visit,
    this.milestones = const [],
  });
}

/// Interested in, or going to, an event that hasn't ended yet. Never a
/// stamp — only confirmed attendance is.
class EventIntentActivity extends FriendActivity {
  final Event event;
  final EventIntentStatus status;

  const EventIntentActivity({
    required super.friend,
    required super.sortDate,
    required this.event,
    required this.status,
  });
}

/// Confirmed attendance at an event — the event's Passport stamp.
class EventStampActivity extends FriendActivity {
  final Event event;
  final int? rating;

  const EventStampActivity({
    required super.friend,
    required super.sortDate,
    required this.event,
    this.rating,
  });
}

/// One friend's friends-visible intent row, already joined to its event.
class FriendEventIntent {
  final String userId;
  final Event event;
  final EventIntentStatus status;
  final DateTime createdAt;

  const FriendEventIntent({
    required this.userId,
    required this.event,
    required this.status,
    required this.createdAt,
  });
}

/// One friend's friends-visible confirmed attendance, joined to its event.
class FriendEventStamp {
  final String userId;
  final Event event;
  final DateTime confirmedAt;
  final int? rating;

  const FriendEventStamp({
    required this.userId,
    required this.event,
    required this.confirmedAt,
    this.rating,
  });
}

/// Distinct starred restaurants that count as a milestone. The first
/// starred restaurant is not one: for most members it is simply their
/// first stamp.
const starredRestaurantMilestones = [10, 25, 50, 100, 150, 200, 250, 300];

/// Builds the merged feed, newest first.
///
/// [visitsByFriend] is each friend's visible Passport, keyed by friend id;
/// [intents] should hold only events that haven't ended (an intent for a
/// past event is either a stamp by now or no longer news). Anything
/// belonging to someone not in [friends] is dropped, so a row that slips
/// through for a just-removed friend never renders without a name.
List<FriendActivity> buildFriendActivity({
  required List<Friendship> friends,
  required Map<String, List<VenueEntry>> visitsByFriend,
  required List<FriendEventIntent> intents,
  required List<FriendEventStamp> stamps,
}) {
  final byId = {for (final f in friends) f.friendId: f};
  final items = <FriendActivity>[];

  for (final MapEntry(key: friendId, value: entries)
      in visitsByFriend.entries) {
    final friend = byId[friendId];
    if (friend == null) continue;
    items.addAll(_visitActivities(friend, entries));
  }
  for (final intent in intents) {
    final friend = byId[intent.userId];
    if (friend == null) continue;
    items.add(
      EventIntentActivity(
        friend: friend,
        sortDate: intent.createdAt,
        event: intent.event,
        status: intent.status,
      ),
    );
  }
  for (final stamp in stamps) {
    final friend = byId[stamp.userId];
    if (friend == null) continue;
    items.add(
      EventStampActivity(
        friend: friend,
        sortDate: stamp.confirmedAt,
        event: stamp.event,
        rating: stamp.rating,
      ),
    );
  }

  items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
  return items;
}

/// One friend's visits as activities, with milestones worked out in the
/// order the visits happened (oldest first; same-day visits by id, so the
/// result never depends on query order).
List<VisitActivity> _visitActivities(
  Friendship friend,
  List<VenueEntry> entries,
) {
  final chronological =
      [
        for (final entry in entries)
          for (final visit in entry.visits) (venue: entry.venue, visit: visit),
      ]..sort((a, b) {
        final byDate = a.visit.visitedOn.compareTo(b.visit.visitedOn);
        return byDate != 0 ? byDate : a.visit.id.compareTo(b.visit.id);
      });

  final seenCountries = <String>{};
  final starredRestaurants = <String>{};
  var seenThreeStar = false;
  final result = <VisitActivity>[];

  for (final (index, (:venue, :visit)) in chronological.indexed) {
    final milestones = <FriendMilestone>[];

    final country = venue.countryCode.toUpperCase();
    // The very first stamp is trivially "first in" its country; only a new
    // country after that is news.
    if (country.isNotEmpty && seenCountries.add(country) && index > 0) {
      milestones.add(FirstInCountryMilestone(country));
    }

    if (venue case RestaurantVenue(:final restaurant)) {
      final stars = visit.starsAtVisit ?? 0;
      if (stars >= 1 && starredRestaurants.add(restaurant.id)) {
        if (starredRestaurantMilestones.contains(starredRestaurants.length)) {
          milestones.add(StarredCountMilestone(starredRestaurants.length));
        }
      }
      if (stars == 3 && !seenThreeStar) {
        seenThreeStar = true;
        milestones.add(const FirstThreeStarMilestone());
      }
    }

    result.add(
      VisitActivity(
        friend: friend,
        sortDate: visit.visitedOn,
        venue: venue,
        visit: visit,
        milestones: milestones,
      ),
    );
  }
  return result;
}
