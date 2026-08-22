// Events V2 Discovery Taxonomy Phase B — the pure filtering core
// (lib/features/events/event_discovery_filtering.dart): AND-across-
// dimensions / OR-within-dimension inclusion logic, date intersection,
// social resolution, and — critically — proof that filtering never
// changes Step 8A's own ranking hierarchy. No Supabase dependency
// anywhere in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/event_discovery_filtering.dart';
import 'package:michelin_passport/features/events/event_discovery_ranking.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_discovery_filters.dart';
import 'package:michelin_passport/models/event_relevance_reason.dart';
import 'package:michelin_passport/models/friendship.dart';

Event _event({
  required String id,
  DateTime? startDate,
  DateTime? endDate,
  EventType eventType = EventType.dinner,
  String countryCode = 'NL',
  bool cancelled = false,
}) => Event(
  id: id,
  name: 'Event $id',
  startDate: startDate ?? DateTime.utc(2026, 9, 10),
  endDate: endDate ?? startDate ?? DateTime.utc(2026, 9, 10),
  countryCode: countryCode,
  eventType: eventType,
  status: cancelled ? EventStatus.cancelled : EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

Friendship _friend(String id) =>
    Friendship(friendshipId: 'f-$id', friendId: id);

void main() {
  group('eventIntersectsDateRange', () {
    final event = _event(
      id: 'a',
      startDate: DateTime.utc(2026, 10, 10),
      endDate: DateTime.utc(2026, 10, 12),
    );

    test('a date fully inside the span intersects', () {
      expect(
        eventIntersectsDateRange(
          event,
          DateTime.utc(2026, 10, 11),
          DateTime.utc(2026, 10, 11),
        ),
        isTrue,
      );
    });

    test('a filter range starting mid-span still intersects (Phase B §9 '
        'worked example: Event 10-12 Oct, filter 11 Oct)', () {
      expect(
        eventIntersectsDateRange(event, DateTime.utc(2026, 10, 11), null),
        isTrue,
      );
    });

    test('a range entirely before the span does not intersect', () {
      expect(
        eventIntersectsDateRange(
          event,
          DateTime.utc(2026, 10, 1),
          DateTime.utc(2026, 10, 5),
        ),
        isFalse,
      );
    });

    test('a range entirely after the span does not intersect', () {
      expect(
        eventIntersectsDateRange(
          event,
          DateTime.utc(2026, 10, 20),
          DateTime.utc(2026, 10, 25),
        ),
        isFalse,
      );
    });

    test('an open range (both null) always intersects', () {
      expect(eventIntersectsDateRange(event, null, null), isTrue);
    });

    test('exact boundary touch (range ends exactly on event start) '
        'intersects', () {
      expect(
        eventIntersectsDateRange(event, null, DateTime.utc(2026, 10, 10)),
        isTrue,
      );
    });
  });

  group('applyDiscoveryFilters — empty filter', () {
    test('returns the input list completely unchanged (Phase B §29/§35 '
        'invariant)', () {
      final events = [_event(id: 'a'), _event(id: 'b')];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(),
        userSignedIn: true,
      );
      expect(
        identical(result, events) ||
            result.map((e) => e.id).toList() == ['a', 'b'],
        isTrue,
      );
      expect(result.length, 2);
    });
  });

  group('applyDiscoveryFilters — single dimension', () {
    test('one Type: matches only that type', () {
      final events = [
        _event(id: 'dinner', eventType: EventType.dinner),
        _event(id: 'lunch', eventType: EventType.lunch),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(eventTypes: {EventType.lunch}),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id), ['lunch']);
    });

    test('multiple Types: OR within Type', () {
      final events = [
        _event(id: 'dinner', eventType: EventType.dinner),
        _event(id: 'lunch', eventType: EventType.lunch),
        _event(id: 'gala', eventType: EventType.gala),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(
          eventTypes: {EventType.dinner, EventType.lunch},
        ),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id).toSet(), {'dinner', 'lunch'});
    });

    test('one Tag: matches only events in the resolved tag-matching set', () {
      final events = [_event(id: 'a'), _event(id: 'b')];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(tagSlugs: {'wine'}),
        userSignedIn: true,
        tagMatchingEventIds: {'a'},
      );
      expect(result.map((e) => e.id), ['a']);
    });

    test('multiple Tags: OR within Theme — the resolved id set already '
        'represents the union, this just proves membership is used '
        'correctly', () {
      final events = [_event(id: 'a'), _event(id: 'b'), _event(id: 'c')];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(tagSlugs: {'wine', 'guest_chef'}),
        userSignedIn: true,
        tagMatchingEventIds: {'a', 'b'}, // union already resolved upstream
      );
      expect(result.map((e) => e.id).toSet(), {'a', 'b'});
    });

    test('one Country: matches only that country', () {
      final events = [
        _event(id: 'nl', countryCode: 'NL'),
        _event(id: 'dk', countryCode: 'DK'),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(countryCodes: {'NL'}),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id), ['nl']);
    });

    test('multiple Countries: OR within Country', () {
      final events = [
        _event(id: 'nl', countryCode: 'NL'),
        _event(id: 'be', countryCode: 'BE'),
        _event(id: 'dk', countryCode: 'DK'),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(countryCodes: {'NL', 'BE'}),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id).toSet(), {'nl', 'be'});
    });

    test('one Social filter: matches only the resolved qualifying set', () {
      final events = [_event(id: 'a'), _event(id: 'b')];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.friendsGoing},
        ),
        userSignedIn: true,
        socialQualifyingEventIds: {'b'},
      );
      expect(result.map((e) => e.id), ['b']);
    });
  });

  group('applyDiscoveryFilters — AND across dimensions', () {
    test('Type + Country: an event must satisfy BOTH', () {
      final events = [
        _event(id: 'match', eventType: EventType.dinner, countryCode: 'NL'),
        _event(id: 'wrong-type', eventType: EventType.lunch, countryCode: 'NL'),
        _event(
          id: 'wrong-country',
          eventType: EventType.dinner,
          countryCode: 'DK',
        ),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(
          eventTypes: {EventType.dinner},
          countryCodes: {'NL'},
        ),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id), ['match']);
    });
  });

  group('applyDiscoveryFilters — signed-out behavior', () {
    test('a social filter while signed out returns a deterministic empty '
        'result, not an error', () {
      final events = [_event(id: 'a'), _event(id: 'b')];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.friendsGoing},
        ),
        userSignedIn: false,
      );
      expect(result, isEmpty);
    });

    test('non-social filters (Type/Theme/Country/Date) still work '
        'perfectly fine while signed out', () {
      final events = [
        _event(id: 'a', eventType: EventType.dinner),
        _event(id: 'b', eventType: EventType.lunch),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(eventTypes: {EventType.dinner}),
        userSignedIn: false,
      );
      expect(result.map((e) => e.id), ['a']);
    });
  });

  group('applyDiscoveryFilters — cancelled events', () {
    test('a cancelled event that matches every active dimension is still '
        'included — filtering does not introduce a new cancellation rule '
        'beyond whatever the base list already contains', () {
      final events = [
        _event(id: 'cancelled', eventType: EventType.dinner, cancelled: true),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(eventTypes: {EventType.dinner}),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id), ['cancelled']);
    });
  });

  group('applyDiscoveryFilters — date-only / full-time Events remain '
      'correct', () {
    test('a genuine date-only Event (no clock time) still resolves its '
        'calendar-date intersection correctly', () {
      final dateOnly = Event(
        id: 'date-only',
        name: 'Date Only',
        startDate: DateTime.utc(2026, 9, 18),
        endDate: DateTime.utc(2026, 9, 18),
        countryCode: 'NL',
        eventType: EventType.dinner,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final result = applyDiscoveryFilters(
        events: [dateOnly],
        filters: EventDiscoveryFilters(
          dateRange: EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 18),
            to: DateTime.utc(2026, 9, 18),
          ),
        ),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id), ['date-only']);
    });

    test('a full-time Event (start+end clock known) filters purely on its '
        'calendar dates, never its clock time', () {
      final fullTime = Event(
        id: 'full-time',
        name: 'Full Time',
        startAt: DateTime.utc(2026, 9, 18, 18, 30),
        endAt: DateTime.utc(2026, 9, 18, 22, 0),
        timezone: 'Europe/Amsterdam',
        countryCode: 'NL',
        eventType: EventType.dinner,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final result = applyDiscoveryFilters(
        events: [fullTime],
        filters: EventDiscoveryFilters(
          dateRange: EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 18),
            to: DateTime.utc(2026, 9, 18),
          ),
        ),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id), ['full-time']);
    });

    test('a multi-day date-only Event intersects a filter range landing '
        'anywhere inside its span', () {
      final multiDay = Event(
        id: 'multi-day',
        name: 'Multi Day',
        startDate: DateTime.utc(2026, 9, 15),
        endDate: DateTime.utc(2026, 9, 18),
        countryCode: 'NL',
        eventType: EventType.festival,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final result = applyDiscoveryFilters(
        events: [multiDay],
        filters: EventDiscoveryFilters(
          dateRange: EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 17),
            to: DateTime.utc(2026, 9, 17),
          ),
        ),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id), ['multi-day']);
    });
  });

  group('resolveSocialQualifyingEventIds — zero-signal behavior', () {
    test('zero accepted friends produces an empty Friends Going result, '
        'no error', () {
      final result = resolveSocialQualifyingEventIds(
        social: {EventSocialFilter.friendsGoing},
        eventIds: ['a', 'b'],
        goingUserIdsByEvent: {
          'a': ['stranger-1'],
        },
        interestedUserIdsByEvent: const {},
        friends: const [], // zero accepted friends
        selfUserId: 'me',
        followedHostNamesByEvent: const {},
      );
      expect(result, isEmpty);
    });

    test('zero followed hosts produces an empty Following result, no '
        'error', () {
      final result = resolveSocialQualifyingEventIds(
        social: {EventSocialFilter.following},
        eventIds: ['a', 'b'],
        goingUserIdsByEvent: const {},
        interestedUserIdsByEvent: const {},
        friends: const [],
        selfUserId: 'me',
        followedHostNamesByEvent: const {}, // zero followed hosts
      );
      expect(result, isEmpty);
    });

    test('a genuine friend Going qualifies the event', () {
      final result = resolveSocialQualifyingEventIds(
        social: {EventSocialFilter.friendsGoing},
        eventIds: ['a'],
        goingUserIdsByEvent: {
          'a': ['friend-1'],
        },
        interestedUserIdsByEvent: const {},
        friends: [_friend('friend-1')],
        selfUserId: 'me',
        followedHostNamesByEvent: const {},
      );
      expect(result, {'a'});
    });

    test('OR within Social: Friends Going OR Following qualifies an event '
        'satisfying either one alone', () {
      final result = resolveSocialQualifyingEventIds(
        social: {EventSocialFilter.friendsGoing, EventSocialFilter.following},
        eventIds: ['going-only', 'following-only', 'neither'],
        goingUserIdsByEvent: {
          'going-only': ['friend-1'],
        },
        interestedUserIdsByEvent: const {},
        friends: [_friend('friend-1')],
        selfUserId: 'me',
        followedHostNamesByEvent: {'following-only': 'Some Host'},
      );
      expect(result, {'going-only', 'following-only'});
    });
  });

  group('Combination scenarios (Phase B §30)', () {
    late List<Event> catalogue;

    setUp(() {
      catalogue = [
        _event(id: 'A', eventType: EventType.dinner, countryCode: 'NL'),
        _event(id: 'B', eventType: EventType.lunch, countryCode: 'NL'),
        _event(id: 'C', eventType: EventType.dinner, countryCode: 'DK'),
        _event(id: 'D', eventType: EventType.gala, countryCode: 'NL'),
      ];
    });

    test('A. Friends Going + Wine', () {
      final result = applyDiscoveryFilters(
        events: catalogue,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.friendsGoing},
          tagSlugs: {'wine'},
        ),
        userSignedIn: true,
        tagMatchingEventIds: {'A', 'B'},
        socialQualifyingEventIds: {'A', 'C'},
      );
      expect(result.map((e) => e.id).toSet(), {'A'}); // intersection
    });

    test('B. Friends Interested + Dinner', () {
      final result = applyDiscoveryFilters(
        events: catalogue,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.friendsInterested},
          eventTypes: {EventType.dinner},
        ),
        userSignedIn: true,
        socialQualifyingEventIds: {'A', 'D'},
      );
      expect(result.map((e) => e.id).toSet(), {
        'A',
      }); // A is dinner+interested, D is gala
    });

    test('C. Following + Four Hands', () {
      final result = applyDiscoveryFilters(
        events: catalogue,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.following},
          tagSlugs: {'four_hands'},
        ),
        userSignedIn: true,
        tagMatchingEventIds: {'C', 'D'},
        socialQualifyingEventIds: {'D'},
      );
      expect(result.map((e) => e.id).toSet(), {'D'});
    });

    test('D. Netherlands + Wine', () {
      final result = applyDiscoveryFilters(
        events: catalogue,
        filters: EventDiscoveryFilters(
          countryCodes: {'NL'},
          tagSlugs: {'wine'},
        ),
        userSignedIn: true,
        tagMatchingEventIds: {'A', 'C'}, // C is Denmark, excluded by country
      );
      expect(result.map((e) => e.id).toSet(), {'A'});
    });

    test('E. Lunch + date range', () {
      final dated = [
        _event(
          id: 'lunch-in-range',
          eventType: EventType.lunch,
          startDate: DateTime.utc(2026, 9, 15),
        ),
        _event(
          id: 'lunch-out-of-range',
          eventType: EventType.lunch,
          startDate: DateTime.utc(2026, 10, 15),
        ),
        _event(
          id: 'dinner-in-range',
          eventType: EventType.dinner,
          startDate: DateTime.utc(2026, 9, 15),
        ),
      ];
      final result = applyDiscoveryFilters(
        events: dated,
        filters: EventDiscoveryFilters(
          eventTypes: {EventType.lunch},
          dateRange: EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 1),
            to: DateTime.utc(2026, 9, 30),
          ),
        ),
        userSignedIn: true,
      );
      expect(result.map((e) => e.id), ['lunch-in-range']);
    });

    test('F. Following + Guest Chef + Netherlands', () {
      final result = applyDiscoveryFilters(
        events: catalogue,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.following},
          tagSlugs: {'guest_chef'},
          countryCodes: {'NL'},
        ),
        userSignedIn: true,
        tagMatchingEventIds: {'A', 'C', 'D'}, // C excluded by country
        socialQualifyingEventIds: {'A', 'D'},
      );
      expect(result.map((e) => e.id).toSet(), {'A', 'D'});
    });

    test('G. Friends Going + Wine + Dinner + Netherlands + date range — '
        'every dimension must hold simultaneously', () {
      final wide = [
        _event(
          id: 'qualifies',
          eventType: EventType.dinner,
          countryCode: 'NL',
          startDate: DateTime.utc(2026, 9, 15),
        ),
        _event(
          id: 'wrong-country',
          eventType: EventType.dinner,
          countryCode: 'DK',
          startDate: DateTime.utc(2026, 9, 15),
        ),
        _event(
          id: 'wrong-date',
          eventType: EventType.dinner,
          countryCode: 'NL',
          startDate: DateTime.utc(2026, 12, 1),
        ),
      ];
      final result = applyDiscoveryFilters(
        events: wide,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.friendsGoing},
          tagSlugs: {'wine'},
          eventTypes: {EventType.dinner},
          countryCodes: {'NL'},
          dateRange: EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 1),
            to: DateTime.utc(2026, 9, 30),
          ),
        ),
        userSignedIn: true,
        tagMatchingEventIds: {'qualifies', 'wrong-country', 'wrong-date'},
        socialQualifyingEventIds: {'qualifies', 'wrong-country', 'wrong-date'},
      );
      expect(result.map((e) => e.id), ['qualifies']);
    });
  });

  group('Ranking regression — filtering never changes Step 8A hierarchy '
      '(Phase B §31)', () {
    test('an Event qualifying under a Wine filter can still rank first '
        'because it independently matches Trip — filtering determines '
        'inclusion, ranking determines relevance reason, and the two '
        'never interfere', () {
      final events = [
        _event(id: 'trip-match', startDate: DateTime.utc(2026, 9, 20)),
        _event(id: 'no-trip', startDate: DateTime.utc(2026, 9, 10)),
      ];
      final filtered = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(tagSlugs: {'wine'}),
        userSignedIn: true,
        tagMatchingEventIds: {'trip-match', 'no-trip'},
      );
      // Both events pass the filter. Now rank them exactly as Step 8A
      // would, completely independent of the filter that was applied.
      final ranked = rankEventsForDiscovery(
        events: filtered,
        signalsByEventId: {
          'trip-match': const EventRelevanceSignals(tripMatch: true),
        },
      );
      // Trip outranks chronology despite starting later — proves ranking
      // logic is untouched by the fact a filter narrowed the input.
      expect(ranked.first.event.id, 'trip-match');
      expect(ranked.first.primaryReason, isA<TripRelevanceReason>());
    });

    test('a Friends-Going-filtered result set can still show Trip as its '
        'primary relevance reason, never a synthetic "Friends Going" '
        'reason', () {
      final events = [_event(id: 'a')];
      final filtered = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.friendsGoing},
        ),
        userSignedIn: true,
        socialQualifyingEventIds: {'a'},
      );
      final ranked = rankEventsForDiscovery(
        events: filtered,
        signalsByEventId: {
          'a': const EventRelevanceSignals(
            tripMatch: true,
            friendsGoingCount: 1,
          ),
        },
      );
      // Trip outranks Friend Going in the fixed hierarchy — the filter
      // being "Friends Going" does not force that to become the shown
      // reason.
      expect(ranked.single.primaryReason, isA<TripRelevanceReason>());
    });

    test('no fake Type/Tag relevance reason is ever created — a Wine-'
        'filtered, signal-less Event has a null primaryReason, exactly '
        'like cold start with no filter at all', () {
      final events = [_event(id: 'a')];
      final filtered = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(tagSlugs: {'wine'}),
        userSignedIn: true,
        tagMatchingEventIds: {'a'},
      );
      final ranked = rankEventsForDiscovery(
        events: filtered,
        signalsByEventId: const {},
      );
      expect(ranked.single.primaryReason, isNull);
    });
  });
}
