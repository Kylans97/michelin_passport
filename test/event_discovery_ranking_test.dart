// Events V2 Step 8A — exhaustive coverage of the pure ranking core
// (lib/features/events/event_discovery_ranking.dart,
// lib/models/event_relevance_reason.dart,
// lib/models/event_discovery_item.dart): the fixed relevance hierarchy,
// deduplication (every event exactly once), multiple-reasons-collapse-to-
// strongest, deterministic tie-breaking, and the cold-start
// (zero-personalization) fallback to plain chronological order. No
// Supabase dependency anywhere in this file — see event_discovery_ranking
// .dart's own doc comment for why this is deliberately pure and
// independently testable (Step 8A §10).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/event_discovery_ranking.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_relevance_reason.dart';

Event _event({required String id, required DateTime startAt, String? city}) =>
    Event(
      id: id,
      name: 'Event $id',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 3)),
      countryCode: 'NL',
      city: city,
      eventType: EventType.dinner,
      status: EventStatus.upcoming,
      createdAt: DateTime.utc(2026, 1, 1),
    );

final _t1 = DateTime.utc(2026, 9, 1);
final _t2 = DateTime.utc(2026, 9, 5);
final _t3 = DateTime.utc(2026, 9, 10);

void main() {
  group('rankEventsForDiscovery — no signals at all', () {
    test('collapses to plain chronological order, exactly the base list '
        'order, with a null reason on every item (cold start, Step 8A '
        '§17)', () {
      final events = [
        _event(id: 'c', startAt: _t3),
        _event(id: 'a', startAt: _t1),
        _event(id: 'b', startAt: _t2),
      ];
      // Simulate the base query's own start_at-ascending order.
      final sorted = [events[1], events[2], events[0]];
      final ranked = rankEventsForDiscovery(
        events: sorted,
        signalsByEventId: const {},
      );
      expect(ranked.map((i) => i.event.id).toList(), ['a', 'b', 'c']);
      expect(ranked.every((i) => i.primaryReason == null), isTrue);
    });
  });

  group('rankEventsForDiscovery — hierarchy ordering (Step 8A §2)', () {
    test('Trip outranks Friend Going', () {
      final events = [
        _event(id: 'a', startAt: _t1),
        _event(id: 'b', startAt: _t2),
      ];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: {
          'a': const EventRelevanceSignals(friendsGoingCount: 3),
          'b': const EventRelevanceSignals(tripMatch: true),
        },
      );
      expect(ranked.first.event.id, 'b');
      expect(ranked.first.primaryReason, isA<TripRelevanceReason>());
    });

    test('Friend Going outranks Followed Host', () {
      final events = [
        _event(id: 'a', startAt: _t1),
        _event(id: 'b', startAt: _t2),
      ];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: {
          'a': const EventRelevanceSignals(followedHost: true),
          'b': const EventRelevanceSignals(friendsGoingCount: 1),
        },
      );
      expect(ranked.first.event.id, 'b');
      expect(ranked.first.primaryReason, isA<FriendGoingRelevanceReason>());
    });

    test('Followed Host outranks Friend Interested', () {
      final events = [
        _event(id: 'a', startAt: _t1),
        _event(id: 'b', startAt: _t2),
      ];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: {
          'a': const EventRelevanceSignals(friendsInterestedCount: 4),
          'b': const EventRelevanceSignals(followedHost: true),
        },
      );
      expect(ranked.first.event.id, 'b');
      expect(ranked.first.primaryReason, isA<FollowedHostRelevanceReason>());
    });

    test('Friend Interested outranks Popularity', () {
      final events = [
        _event(id: 'a', startAt: _t1),
        _event(id: 'b', startAt: _t2),
      ];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: {
          'a': const EventRelevanceSignals(popular: true),
          'b': const EventRelevanceSignals(friendsInterestedCount: 1),
        },
      );
      expect(ranked.first.event.id, 'b');
      expect(
        ranked.first.primaryReason,
        isA<FriendInterestedRelevanceReason>(),
      );
    });

    test('Popularity outranks plain chronology (no reason)', () {
      final events = [
        // Later start date, but popular — still ranks first.
        _event(id: 'a', startAt: _t3),
        _event(id: 'b', startAt: _t1),
      ];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: {'a': const EventRelevanceSignals(popular: true)},
      );
      expect(ranked.first.event.id, 'a');
      expect(ranked.first.primaryReason, isA<PopularRelevanceReason>());
      expect(ranked.last.event.id, 'b');
      expect(ranked.last.primaryReason, isNull);
    });

    test('within the same tier, earlier event ranks first', () {
      final events = [
        _event(id: 'a', startAt: _t3),
        _event(id: 'b', startAt: _t1),
        _event(id: 'c', startAt: _t2),
      ];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: {
          'a': const EventRelevanceSignals(tripMatch: true),
          'b': const EventRelevanceSignals(tripMatch: true),
          'c': const EventRelevanceSignals(tripMatch: true),
        },
      );
      expect(ranked.map((i) => i.event.id).toList(), ['b', 'c', 'a']);
    });
  });

  group('rankEventsForDiscovery — multiple reasons collapse to strongest '
      '(Step 8A §18)', () {
    test('an event qualifying for all five tiers simultaneously shows '
        'only Trip', () {
      final events = [_event(id: 'a', startAt: _t1)];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: {
          'a': const EventRelevanceSignals(
            tripMatch: true,
            tripDestinationLabel: 'Maastricht',
            friendsGoingCount: 2,
            followedHost: true,
            friendsInterestedCount: 3,
            popular: true,
          ),
        },
      );
      expect(ranked.single.primaryReason, isA<TripRelevanceReason>());
      expect(
        (ranked.single.primaryReason! as TripRelevanceReason).destinationLabel,
        'Maastricht',
      );
    });
  });

  group('rankEventsForDiscovery — deduplication (Step 8A §10/§18)', () {
    test('every event appears exactly once regardless of signal strength', () {
      final events = [
        _event(id: 'a', startAt: _t1),
        _event(id: 'b', startAt: _t2),
        _event(id: 'c', startAt: _t3),
      ];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: {
          'a': const EventRelevanceSignals(tripMatch: true),
          'b': const EventRelevanceSignals(friendsGoingCount: 5),
        },
      );
      expect(ranked.length, 3);
      expect(ranked.map((i) => i.event.id).toSet(), {'a', 'b', 'c'});
    });

    test('a missing signals-map entry is treated as no signal, never an '
        'error (Step 8A §15)', () {
      final events = [_event(id: 'a', startAt: _t1)];
      final ranked = rankEventsForDiscovery(
        events: events,
        signalsByEventId: const {},
      );
      expect(ranked.single.primaryReason, isNull);
    });
  });

  group('rankEventsForDiscovery — deterministic tie-breaking', () {
    test('two events at the exact same instant and tier sort by id, '
        'stable across repeated calls', () {
      final events = [
        _event(id: 'z', startAt: _t1),
        _event(id: 'a', startAt: _t1),
      ];
      final first = rankEventsForDiscovery(
        events: events,
        signalsByEventId: const {},
      );
      final second = rankEventsForDiscovery(
        events: events,
        signalsByEventId: const {},
      );
      expect(first.map((i) => i.event.id).toList(), ['a', 'z']);
      expect(second.map((i) => i.event.id).toList(), ['a', 'z']);
    });
  });

  group('EventRelevanceReason.label — exact copy contract', () {
    test('Trip: destination known -> "During your X trip"', () {
      expect(
        const TripRelevanceReason(destinationLabel: 'Maastricht').label,
        'During your Maastricht trip',
      );
    });

    test('Trip: destination unknown -> safe generic phrase', () {
      expect(const TripRelevanceReason().label, 'During your upcoming trip');
    });

    test('Friend Going: single friend -> "X is going"', () {
      expect(
        const FriendGoingRelevanceReason(
          count: 1,
          singleFriendName: 'Ward',
        ).label,
        'Ward is going',
      );
    });

    test('Friend Going: multiple -> "N friends are going"', () {
      expect(
        const FriendGoingRelevanceReason(count: 2).label,
        '2 friends are going',
      );
    });

    test('Followed Host: name known -> "Hosted by X"', () {
      expect(
        const FollowedHostRelevanceReason(hostName: 'Parkheuvel').label,
        'Hosted by Parkheuvel',
      );
    });

    test('Followed Host: name unknown -> privacy-safe generic phrase', () {
      expect(
        const FollowedHostRelevanceReason().label,
        'From a place you follow',
      );
    });

    test('Friend Interested: single friend -> "X is interested"', () {
      expect(
        const FriendInterestedRelevanceReason(
          count: 1,
          singleFriendName: 'Amy',
        ).label,
        'Amy is interested',
      );
    });

    test('Popular: no exact count ever appears in the copy', () {
      final label = const PopularRelevanceReason().label;
      expect(label, isNot(contains(RegExp(r'[0-9]'))));
    });
  });

  group('EventRelevanceSignals.withPopular', () {
    test('sets popular without disturbing any other field', () {
      const signals = EventRelevanceSignals(
        tripMatch: true,
        tripDestinationLabel: 'Maastricht',
        friendsGoingCount: 2,
      );
      final updated = signals.withPopular(true);
      expect(updated.popular, isTrue);
      expect(updated.tripMatch, isTrue);
      expect(updated.tripDestinationLabel, 'Maastricht');
      expect(updated.friendsGoingCount, 2);
    });
  });
}
