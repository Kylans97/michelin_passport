// Covers Friends round one (2026-11-22, ideas 1, 2 and 3 from the Friends
// Ideas canvas): the pure shaping behind Coming up, Recommended by, Where
// your tastes meet, cities, trips together and Plans in motion, the Taste
// tab, and the new Community FRIENDS sections.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/venue_invite_repository.dart';
import 'package:michelin_passport/data/repositories/visit_wine_repository.dart';
import 'package:michelin_passport/features/community/community_screen.dart';
import 'package:michelin_passport/features/community/friends_activity.dart';
import 'package:michelin_passport/features/community/friends_plans.dart';
import 'package:michelin_passport/features/friends/friend_profile_data.dart';
import 'package:michelin_passport/features/friends/friend_profile_screen.dart';
import 'package:michelin_passport/features/friends/friends_together_data.dart';
import 'package:michelin_passport/features/friends/tabs/friend_profile_taste_tab.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_attendance.dart';
import 'package:michelin_passport/models/friendship.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:michelin_passport/models/profile_identity.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';
import 'package:michelin_passport/models/visit_wine.dart';

const _elise = Friendship(
  friendshipId: 'f1',
  friendId: 'elise',
  displayName: 'Elise',
);
const _thomas = Friendship(
  friendshipId: 'f2',
  friendId: 'thomas',
  displayName: 'Thomas',
);

Restaurant _restaurant(
  String id, {
  String city = 'Antwerp',
  String country = 'BE',
}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: 'Restaurant $id',
  michelinStars: 1,
  inclusionReason: 'michelin_star',
  cityName: city,
  countryCode: country,
  countryName: country,
  flagEmoji: '',
  address: '1 Test Street',
);

Visit _visit(
  String id,
  String userId,
  String entityId,
  DateTime on, {
  double? rating,
}) => Visit(
  id: id,
  userId: userId,
  entityType: 'restaurant',
  entityId: entityId,
  visitedOn: on,
  rating: rating,
);

Event _event(String id, DateTime day, {DateTime? cancelledAt}) => Event(
  id: id,
  name: 'Event $id',
  startDate: day,
  endDate: day,
  countryCode: 'NL',
  eventType: EventType.dinner,
  createdAt: DateTime(2026, 1, 1),
  cancelledAt: cancelledAt,
);

PlannedTrip _trip(String id, String owner, DateTime start, DateTime end) =>
    PlannedTrip(
      id: id,
      userId: owner,
      title: 'Trip $id',
      startDate: start,
      endDate: end,
      countryCode: 'BE',
      createdAt: DateTime(2026, 1, 1),
    );

FriendVenueVisit _fv(Restaurant r, Visit v) =>
    FriendVenueVisit(RestaurantVenue(r), v);

void main() {
  group('ownIntentLine', () {
    test('says both only when both share the same intent', () {
      expect(
        ownIntentLine(
          mine: EventIntentStatus.going,
          friendGoing: true,
          friendInterested: false,
        ),
        "You're both going",
      );
      expect(
        ownIntentLine(
          mine: EventIntentStatus.going,
          friendGoing: false,
          friendInterested: true,
        ),
        "You're going",
      );
      expect(
        ownIntentLine(
          mine: EventIntentStatus.interested,
          friendGoing: true,
          friendInterested: false,
        ),
        "You're interested too",
      );
      expect(
        ownIntentLine(mine: null, friendGoing: true, friendInterested: false),
        isNull,
      );
    });
  });

  group('eventsWithFriends', () {
    test('one entry per event, soonest first, going wins over interested', () {
      final later = _event('late', DateTime.utc(2026, 12, 20));
      final sooner = _event('soon', DateTime.utc(2026, 12, 1));
      final activity = <FriendActivity>[
        EventIntentActivity(
          friend: _elise,
          sortDate: DateTime(2026, 11, 1),
          event: later,
          status: EventIntentStatus.going,
        ),
        EventIntentActivity(
          friend: _elise,
          sortDate: DateTime(2026, 11, 2),
          event: later,
          status: EventIntentStatus.interested,
        ),
        EventIntentActivity(
          friend: _thomas,
          sortDate: DateTime(2026, 11, 3),
          event: later,
          status: EventIntentStatus.going,
        ),
        EventIntentActivity(
          friend: _thomas,
          sortDate: DateTime(2026, 11, 4),
          event: sooner,
          status: EventIntentStatus.interested,
        ),
      ];
      final result = eventsWithFriends(
        activity: activity,
        myIntents: {'late': EventIntentStatus.interested},
      );
      expect([for (final e in result) e.event.id], ['soon', 'late']);
      expect(result[0].friendsLine, 'Thomas is interested');
      expect(result[0].mineLine, isNull);
      expect(result[1].friendsLine, 'Elise and Thomas are going');
      expect(result[1].interested, isEmpty);
      expect(result[1].mineLine, "You're interested too");
    });
  });

  group('venuesLovedByFriends', () {
    test('keeps high scores at places the viewer has not been, best first', () {
      final a = _restaurant('a');
      final b = _restaurant('b');
      final known = _restaurant('known');
      VisitActivity act(Friendship f, Restaurant r, double score) =>
          VisitActivity(
            friend: f,
            sortDate: DateTime(2026, 10, 1),
            venue: RestaurantVenue(r),
            visit: _visit(
              '${f.friendId}${r.id}$score',
              f.friendId,
              r.id,
              DateTime(2026, 10, 1),
              rating: score,
            ),
          );
      final result = venuesLovedByFriends(
        activity: [
          act(_elise, a, 9.0),
          act(_thomas, a, 8.5),
          act(_elise, b, 9.5),
          act(_thomas, b, 7.0),
          act(_elise, known, 10),
        ],
        myVisitedKeys: {'r:known'},
      );
      expect(
        [for (final v in result) v.venue.name],
        ['Restaurant b', 'Restaurant a'],
      );
      expect(result[0].scores.length, 1, reason: '7.0 is below the bar');
      expect(
        [for (final s in result[1].scores) s.friend.label],
        ['Elise', 'Thomas'],
      );
    });
  });

  group('friend profile shaping', () {
    test('friendUpcomingEvents merges, prefers going, skips cancelled', () {
      final e1 = _event('e1', DateTime.utc(2026, 12, 5));
      final e2 = _event('e2', DateTime.utc(2026, 12, 1));
      final gone = _event(
        'gone',
        DateTime.utc(2026, 12, 2),
        cancelledAt: DateTime(2026, 11, 1),
      );
      final result = friendUpcomingEvents(
        going: [e1, gone],
        interested: [e1, e2],
        myIntents: {'e1': EventIntentStatus.going},
      );
      expect([for (final e in result) e.event.id], ['e2', 'e1']);
      expect(result[1].friendStatus, EventIntentStatus.going);
      expect(result[1].mineLine, "You're both going");
      expect(result.where((e) => e.isShared).length, 1);
    });

    test('recommendedByFriend: best visit per new venue, above the bar', () {
      final r1 = _restaurant('r1');
      final r2 = _restaurant('r2');
      final r3 = _restaurant('r3');
      final result = recommendedByFriend(
        visits: [
          _fv(
            r1,
            _visit('v1', 'elise', 'r1', DateTime(2026, 3, 1), rating: 8.5),
          ),
          _fv(
            r1,
            _visit('v2', 'elise', 'r1', DateTime(2026, 5, 1), rating: 9.5),
          ),
          _fv(
            r2,
            _visit('v3', 'elise', 'r2', DateTime(2026, 4, 1), rating: 8.0),
          ),
          _fv(
            r3,
            _visit('v4', 'elise', 'r3', DateTime(2026, 4, 1), rating: 9.0),
          ),
        ],
        myVisitedKeys: {'r:r3'},
      );
      expect([for (final fv in result) fv.visit.id], ['v2']);
    });

    test('sharedVenueScores pairs latest rated scores per place', () {
      final r1 = _restaurant('r1');
      final r2 = _restaurant('r2');
      final theirs = [
        VenueEntry(
          venue: RestaurantVenue(r1),
          visits: [
            _visit('t1', 'elise', 'r1', DateTime(2026, 6, 1), rating: 9),
          ],
        ),
        VenueEntry(
          venue: RestaurantVenue(r2),
          visits: [_visit('t2', 'elise', 'r2', DateTime(2026, 2, 1))],
        ),
      ];
      final mine = [
        VenueEntry(
          venue: RestaurantVenue(r1),
          visits: [
            _visit('m1', 'me', 'r1', DateTime(2026, 1, 1), rating: 7),
            _visit('m2', 'me', 'r1', DateTime(2026, 8, 1), rating: 9.5),
          ],
        ),
      ];
      final result = sharedVenueScores(theirs: theirs, mine: mine);
      expect(result.single.theirs, 9);
      expect(result.single.mine, 9.5);
      expect(result.single.lastVisited, DateTime(2026, 8, 1));
    });

    test('friendCities and topCountryCodes count places and visits', () {
      final a1 = _restaurant('a1');
      final a2 = _restaurant('a2');
      final p1 = _restaurant('p1', city: 'Paris', country: 'FR');
      final visits = [
        _fv(a1, _visit('1', 'elise', 'a1', DateTime(2026, 1, 1))),
        _fv(a1, _visit('2', 'elise', 'a1', DateTime(2026, 2, 1))),
        _fv(a2, _visit('3', 'elise', 'a2', DateTime(2026, 3, 1))),
        _fv(p1, _visit('4', 'elise', 'p1', DateTime(2026, 4, 1))),
      ];
      final cities = friendCities(visits);
      expect([for (final c in cities) c.cityName], ['Antwerp', 'Paris']);
      expect(cities.first.placeCount, 2);
      expect(topCountryCodes(visits), ['BE', 'FR']);
    });

    test('tripsWithFriend keeps current trips the friend is on', () {
      final today = DateTime(2026, 11, 22);
      final result = tripsWithFriend(
        trips: [
          _trip('own', 'me', DateTime(2027, 2, 14), DateTime(2027, 2, 16)),
          _trip('hers', 'elise', DateTime(2027, 5, 7), DateTime(2027, 5, 10)),
          _trip('past', 'me', DateTime(2026, 9, 1), DateTime(2026, 9, 3)),
          _trip('now', 'me', DateTime(2026, 11, 20), DateTime(2026, 11, 22)),
        ],
        membersByTrip: {
          'own': {'elise'},
          'past': {'elise'},
          'now': {'elise'},
        },
        friendId: 'elise',
        today: today,
      );
      expect([for (final t in result) t.id], ['now', 'own', 'hers']);
    });
  });

  group('plansInMotion', () {
    VenueInvitePlan invite(
      String id, {
      required String from,
      required String to,
      String status = 'pending',
      DateTime? respondedAt,
    }) => VenueInvitePlan(
      id: id,
      fromUserId: from,
      toUserId: to,
      venue: RestaurantVenue(_restaurant(id)),
      status: status,
      createdAt: DateTime(2026, 11, 1),
      respondedAt: respondedAt,
    );

    test('accepted invites, then shared trips, then pending', () {
      final plans = plansInMotion(
        invites: [
          invite('pending', from: 'thomas', to: 'me'),
          invite(
            'yes',
            from: 'me',
            to: 'elise',
            status: 'accepted',
            respondedAt: DateTime(2026, 11, 10),
          ),
          invite('stranger', from: 'me', to: 'gone'),
        ],
        trips: [
          _trip('solo', 'me', DateTime(2027, 1, 1), DateTime(2027, 1, 2)),
          _trip('shared', 'me', DateTime(2027, 2, 1), DateTime(2027, 2, 3)),
        ],
        membersByTrip: {
          'shared': {'thomas', 'elise'},
        },
        friends: const [_elise, _thomas],
        viewerId: 'me',
        today: DateTime(2026, 11, 22),
      );
      expect(plans.length, 3);
      final accepted = plans[0] as InviteFriendPlan;
      expect(accepted.eyebrow, 'Elise said yes');
      final trip = plans[1] as TripFriendPlan;
      expect(trip.companionsLine, 'With Elise and Thomas');
      final pending = plans[2] as InviteFriendPlan;
      expect(pending.eyebrow, 'Thomas suggested going together');
    });
  });

  group('Taste tab', () {
    testWidgets('shows countries, shared scores, cities and wines', (
      tester,
    ) async {
      final r1 = _restaurant('r1');
      final mineVisit = _visit(
        'm1',
        'me',
        'r1',
        DateTime(2026, 8, 1),
        rating: 8.0,
      );
      final hers = _visit(
        't1',
        'elise',
        'r1',
        DateTime(2026, 6, 1),
        rating: 9.0,
      );
      final entries = [
        VenueEntry(venue: RestaurantVenue(r1), visits: [hers]),
      ];
      final data = FriendProfileLayoutData(
        identity: const ProfileIdentity(
          id: 'elise',
          displayName: 'Elise',
          relationshipStatus: RelationshipStatus.accepted,
        ),
        myIdentity: null,
        visitedEntries: entries,
        visits: flattenFriendVisits(entries),
        wishlist: const [],
        myWishlist: const [],
        sharedKeys: const {},
        stats: FriendProfileStats.from(entries),
        coverPhotoByVisitId: const {},
        countryNameByCode: const {'BE': 'Belgium'},
        myVisitedEntries: [
          VenueEntry(venue: RestaurantVenue(r1), visits: [mineVisit]),
        ],
        wines: const [
          CellarWine(
            wine: VisitWine(
              wineName: 'Savagnin',
              vintage: 2020,
              verdict: WineVerdict.again,
              tastingNote: 'Salty and nutty.',
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FriendProfileTasteTab(data: data)),
        ),
      );
      expect(find.text('Most often in Belgium.'), findsOneWidget);
      expect(find.text('WHERE YOUR TASTES MEET'), findsOneWidget);
      expect(find.text('9.0'), findsOneWidget);
      expect(find.text('8.0'), findsOneWidget);
      expect(find.text("ELISE'S CITIES"), findsOneWidget);
      expect(find.text('Antwerp'), findsOneWidget);
      expect(find.text('Savagnin 2020'), findsOneWidget);
      expect(find.text('AGAIN'), findsOneWidget);
      expect(find.text('Salty and nutty.'), findsOneWidget);
    });
  });

  group('Community FRIENDS tab', () {
    testWidgets('shows plans, coming up and loved places', (tester) async {
      final r1 = _restaurant('r1');
      final activity = <FriendActivity>[
        EventIntentActivity(
          friend: _elise,
          sortDate: DateTime(2026, 11, 1),
          event: _event('e1', DateTime.utc(2026, 12, 12)),
          status: EventIntentStatus.going,
        ),
        VisitActivity(
          friend: _thomas,
          sortDate: DateTime(2026, 10, 1),
          venue: RestaurantVenue(r1),
          visit: _visit(
            'v1',
            'thomas',
            'r1',
            DateTime(2026, 10, 1),
            rating: 9.5,
          ),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(
            loadCommunityRankings: () async => [],
            loadUpcomingEvents: () async => [],
            loadFriends: () async => const [_elise, _thomas],
            loadFriendActivity: (_) async => activity,
            loadFriendsExtras: (_) async => FriendsTabExtras(
              myIntents: const {'e1': EventIntentStatus.interested},
              plans: [
                TripFriendPlan(
                  trip: _trip(
                    't1',
                    'me',
                    DateTime(2027, 2, 14),
                    DateTime(2027, 2, 16),
                  ),
                  companions: const [_thomas],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();

      expect(find.text('Plans in motion'), findsOneWidget);
      expect(find.text('Trip t1'), findsOneWidget);
      expect(find.text('Coming up with friends'), findsOneWidget);
      expect(find.text("YOU'RE INTERESTED TOO"), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Loved by your friends'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('Thomas 9.5'), findsOneWidget);
    });
  });
}
