// Covers Friends' Activity: buildFriendActivity (merge, order, milestones,
// unknown-friend rows dropped), its row copy, and the Community FRIENDS tab
// preview with "All activity".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/community/community_screen.dart';
import 'package:michelin_passport/features/community/friends_activity.dart';
import 'package:michelin_passport/features/community/friends_activity_screen.dart';
import 'package:michelin_passport/features/community/widgets/friend_activity_row.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_attendance.dart';
import 'package:michelin_passport/models/friendship.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

const _anna = Friendship(
  friendshipId: 'f1',
  friendId: 'anna',
  displayName: 'Anna',
);
const _bas = Friendship(
  friendshipId: 'f2',
  friendId: 'bas',
  displayName: 'Bas',
);

Restaurant _restaurant(String id, {String country = 'NL'}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: 'Restaurant $id',
  michelinStars: 1,
  inclusionReason: 'michelin_star',
  cityName: 'City',
  countryCode: country,
  countryName: country,
  flagEmoji: '',
  address: '1 Test Street',
);

const _hotel = Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: 'Test Hotel',
  michelinKeys: 1,
  cityName: 'Amsterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '',
  address: '1 Test Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Visit _visit(
  String id,
  String userId,
  String entityId,
  DateTime on, {
  String type = 'restaurant',
  int? stars,
  int? rating,
}) => Visit(
  id: id,
  userId: userId,
  entityType: type,
  entityId: entityId,
  visitedOn: on,
  starsAtVisit: stars,
  rating: rating,
);

Event _event(String id, {String name = 'Four Hands'}) => Event(
  id: id,
  name: name,
  startDate: DateTime.utc(2026, 11, 20),
  endDate: DateTime.utc(2026, 11, 20),
  countryCode: 'NL',
  eventType: EventType.dinner,
  createdAt: DateTime(2026, 1, 1),
);

VenueEntry _entry(PassportVenue venue, List<Visit> visits) =>
    VenueEntry(venue: venue, visits: visits);

void main() {
  group('buildFriendActivity', () {
    test('merges visits, intents and stamps newest first', () {
      final items = buildFriendActivity(
        friends: const [_anna, _bas],
        visitsByFriend: {
          'anna': [
            _entry(RestaurantVenue(_restaurant('r1')), [
              _visit('v1', 'anna', 'r1', DateTime(2026, 10, 1)),
            ]),
          ],
        },
        intents: [
          FriendEventIntent(
            userId: 'bas',
            event: _event('e1'),
            status: EventIntentStatus.going,
            createdAt: DateTime(2026, 10, 20),
          ),
        ],
        stamps: [
          FriendEventStamp(
            userId: 'anna',
            event: _event('e2'),
            confirmedAt: DateTime(2026, 10, 10),
          ),
        ],
      );
      expect(items.map((i) => i.runtimeType), [
        EventIntentActivity,
        EventStampActivity,
        VisitActivity,
      ]);
      expect(items.first.friend.friendId, 'bas');
    });

    test('drops rows of anyone who is not (or no longer) a friend', () {
      final items = buildFriendActivity(
        friends: const [_anna],
        visitsByFriend: {
          'stranger': [
            _entry(RestaurantVenue(_restaurant('r1')), [
              _visit('v1', 'stranger', 'r1', DateTime(2026, 10, 1)),
            ]),
          ],
        },
        intents: [
          FriendEventIntent(
            userId: 'stranger',
            event: _event('e1'),
            status: EventIntentStatus.interested,
            createdAt: DateTime(2026, 10, 20),
          ),
        ],
        stamps: const [],
      );
      expect(items, isEmpty);
    });

    test('first-in-country skips the very first stamp, marks new ones', () {
      final items = buildFriendActivity(
        friends: const [_anna],
        visitsByFriend: {
          'anna': [
            _entry(RestaurantVenue(_restaurant('r1')), [
              _visit('v1', 'anna', 'r1', DateTime(2026, 1, 1)),
            ]),
            _entry(RestaurantVenue(_restaurant('r2', country: 'JP')), [
              _visit('v2', 'anna', 'r2', DateTime(2026, 2, 1)),
            ]),
            _entry(_hotelVenue, [
              _visit('v3', 'anna', 'h1', DateTime(2026, 3, 1), type: 'hotel'),
            ]),
          ],
        },
        intents: const [],
        stamps: const [],
      );
      final byVisit = {
        for (final i in items.cast<VisitActivity>()) i.visit.id: i.milestones,
      };
      expect(byVisit['v1'], isEmpty);
      expect(byVisit['v2'], hasLength(1));
      expect(
        (byVisit['v2']!.single as FirstInCountryMilestone).countryCode,
        'JP',
      );
      expect(byVisit['v3'], isEmpty); // back in NL — not a first
    });

    test('counts distinct starred restaurants; repeat visits do not count', () {
      final entries = [
        for (var i = 1; i <= 10; i++)
          _entry(RestaurantVenue(_restaurant('r$i')), [
            _visit('v$i', 'anna', 'r$i', DateTime(2026, 1, i), stars: 1),
            if (i == 1)
              _visit('v1b', 'anna', 'r1', DateTime(2026, 1, 2), stars: 1),
          ]),
        _entry(RestaurantVenue(_restaurant('r3star')), [
          _visit('v3s', 'anna', 'r3star', DateTime(2026, 2, 1), stars: 3),
        ]),
      ];
      final items = buildFriendActivity(
        friends: const [_anna],
        visitsByFriend: {'anna': entries},
        intents: const [],
        stamps: const [],
      ).cast<VisitActivity>();

      final tenth = items.singleWhere(
        (i) => i.milestones.any((m) => m is StarredCountMilestone),
      );
      expect(tenth.visit.id, 'v10');
      expect((tenth.milestones.single as StarredCountMilestone).count, 10);
      final threeStar = items.singleWhere((i) => i.visit.id == 'v3s');
      expect(threeStar.milestones, [isA<FirstThreeStarMilestone>()]);
    });
  });

  group('row copy', () {
    test('sentences per kind', () {
      final going = EventIntentActivity(
        friend: _anna,
        sortDate: DateTime(2026),
        event: _event('e1'),
        status: EventIntentStatus.going,
      );
      final interested = EventIntentActivity(
        friend: _anna,
        sortDate: DateTime(2026),
        event: _event('e1'),
        status: EventIntentStatus.interested,
      );
      final stay = VisitActivity(
        friend: _anna,
        sortDate: DateTime(2026),
        venue: _hotelVenue,
        visit: _visit('v', 'anna', 'h1', DateTime(2026), type: 'hotel'),
      );
      expect(activitySentence(going).$2, 'is going to');
      expect(activitySentence(interested).$2, 'is interested in');
      expect(activitySentence(stay).$2, 'stayed at');
    });

    test('milestone labels and date-only formatting', () {
      expect(
        milestoneLabel(const FirstInCountryMilestone('JP'), {'JP': 'Japan'}),
        'First in Japan',
      );
      expect(
        milestoneLabel(const StarredCountMilestone(25), const {}),
        '25th MICHELIN-starred restaurant',
      );
      final now = DateTime(2026, 10, 30);
      expect(formatActivityDate(DateTime(2026, 10, 3), now: now), '3 Oct');
      expect(formatActivityDate(DateTime(2025, 10, 3), now: now), '3 Oct 2025');
    });
  });

  group('Community FRIENDS tab', () {
    List<FriendActivity> activity(int n) => [
      for (var i = 0; i < n; i++)
        EventIntentActivity(
          friend: _anna,
          sortDate: DateTime(2026, 10, 30 - i),
          event: _event('e$i', name: 'Dinner $i'),
          status: EventIntentStatus.going,
        ),
    ];

    Widget wrap(List<FriendActivity> items) => MaterialApp(
      home: CommunityScreen(
        loadCommunityRankings: () async => [],
        loadUpcomingEvents: () async => [],
        loadFriends: () async => const [_anna],
        loadFriendActivity: (_) async => items,
      ),
    );

    testWidgets('previews five items and links to all activity', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(activity(7)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();

      expect(find.byType(FriendActivityRow), findsNWidgets(5));
      expect(
        find.text('Activity from your friends will appear here.'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('All activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All activity'));
      await tester.pumpAndSettle();
      expect(find.byType(FriendsActivityScreen), findsOneWidget);
    });

    testWidgets('nothing shared keeps the quiet empty line', (tester) async {
      await tester.pumpWidget(wrap(const []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();
      expect(
        find.text('Activity from your friends will appear here.'),
        findsOneWidget,
      );
      expect(find.text('All activity'), findsNothing);
    });
  });
}

const _hotelVenue = HotelVenue(_hotel);
