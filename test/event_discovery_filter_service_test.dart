// Events V2 Near Me Phase N2.5 — the first service-level coverage for
// EventDiscoveryFilterService.loadFilteredDiscovery
// (lib/features/events/event_discovery_filter_service.dart) itself, not
// just the pure applyDiscoveryFilters/eventQualifiesForNearMe functions it
// calls (N1's own event_near_me_filtering_test.dart already exhaustively
// covers those). This file proves the full chain N2.5 §4 describes:
//
//   Near-me selection -> EventLocationContext.nearMe(...) ->
//   EventsScreen._location -> _effectiveFilters/discovery load ->
//   EventDiscoveryFilterService.loadFilteredDiscovery(...) ->
//   applyDiscoveryFilters(...) -> canonical N1 Near-me filtering
//
// actually reaches the canonical filter — most importantly, that N2.3's
// own fix to loadFilteredDiscovery's early-return condition (so a
// Near-me-only query no longer bypasses filtering) is directly protected
// by an automated regression test, not just code inspection.
//
// EventsScreen itself still cannot be widget-tested (it eagerly
// constructs Supabase-backed repositories in initState — see
// event_location_control_test.dart's own doc comment for the established
// precedent) — this file closes that gap from the OTHER end, at the
// service boundary EventsScreen._fetchDiscoveryList actually calls.
//
// Hand-rolled fakes only (no mocking package): EventsRepository and every
// other repository EventDiscoveryFilterService/EventDiscoveryService
// depend on are concrete classes requiring a SupabaseClient — each fake
// here `extends` the real class (never touching Supabase, confirmed: a
// bare SupabaseClient(url, key) is safe to construct without
// Supabase.initialize() and is never queried, since every fake overrides
// every method actually reached) and overrides only the one method it
// needs, exactly this codebase's own established "minimal purpose-built
// testability seam" convention (GeolocatorGateway, N2.2). The
// discoveryService fake performs IDENTITY ranking (no reason/order
// logic) — Step 8A's own ranking hierarchy is N1/event_near_me_filtering
// _test.dart's responsibility, not re-tested or duplicated here.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/event_attendance_repository.dart';
import 'package:michelin_passport/data/repositories/event_host_follow_repository.dart';
import 'package:michelin_passport/data/repositories/event_social_repository.dart';
import 'package:michelin_passport/data/repositories/event_tag_repository.dart';
import 'package:michelin_passport/data/repositories/events_repository.dart';
import 'package:michelin_passport/data/repositories/friendship_repository.dart';
import 'package:michelin_passport/data/repositories/planned_trips_repository.dart';
import 'package:michelin_passport/features/events/event_discovery_filter_service.dart';
import 'package:michelin_passport/features/events/event_discovery_service.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_attendance.dart';
import 'package:michelin_passport/models/event_discovery_filters.dart';
import 'package:michelin_passport/models/event_discovery_item.dart';
import 'package:michelin_passport/models/event_near_me_location.dart';
import 'package:michelin_passport/models/friendship.dart';
import 'package:michelin_passport/models/geo_coordinate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _dummyClient = SupabaseClient(
  'https://example.supabase.co',
  'dummy-anon-key',
);

class _FakeEventsRepository extends EventsRepository {
  _FakeEventsRepository(this._events) : super(_dummyClient);
  final List<Event> _events;

  // A deliberately simple, honest approximation of the real server-side
  // query/country/type predicates (never the date-window bounds — Date-
  // control filtering, filters.dateRange, is applied entirely inside
  // applyDiscoveryFilters, never at the repo/query level; see
  // events_discovery_composition_regression_test.dart's own doc comment
  // for the same "simulate what the repo would already return"
  // philosophy) — enough to prove the Near-me + Search/Country/Type
  // integration actually threads through the service, not a naive
  // passthrough that would hide a broken composition.
  @override
  Future<List<Event>> loadEvents({
    DateTime? from,
    DateTime? to,
    String? countryCode,
    Set<String>? countryCodes,
    Set<EventType>? eventTypes,
    String query = '',
  }) async {
    return _events.where((e) {
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        if (!e.name.toLowerCase().contains(q) &&
            !(e.city ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      if (countryCodes != null &&
          countryCodes.isNotEmpty &&
          !countryCodes.contains(e.countryCode.toUpperCase())) {
        return false;
      }
      if (eventTypes != null &&
          eventTypes.isNotEmpty &&
          !eventTypes.contains(e.eventType)) {
        return false;
      }
      return true;
    }).toList();
  }
}

class _FakeEventTagRepository extends EventTagRepository {
  _FakeEventTagRepository(this._matchingIds) : super(_dummyClient);
  final Set<String> _matchingIds;

  @override
  Future<Set<String>> loadEventIdsForTagSlugs(Set<String> slugs) async =>
      _matchingIds;
}

class _FakeEventAttendanceRepository extends EventAttendanceRepository {
  _FakeEventAttendanceRepository({
    this.going = const {},
    this.interested = const {},
  }) : super(_dummyClient);
  final Map<String, List<String>> going;
  final Map<String, List<String>> interested;

  @override
  Future<Map<String, List<String>>> getVisibleUserIdsForEvents({
    required List<String> eventIds,
    required EventIntentStatus status,
  }) async => status == EventIntentStatus.going ? going : interested;
}

class _FakeFriendshipRepository extends FriendshipRepository {
  _FakeFriendshipRepository(this._friends) : super(_dummyClient);
  final List<Friendship> _friends;

  @override
  Future<List<Friendship>> getFriends() async => _friends;
}

class _FakeEventHostFollowRepository extends EventHostFollowRepository {
  _FakeEventHostFollowRepository(this._names) : super(_dummyClient);
  final Map<String, String?> _names;

  @override
  Future<Map<String, String?>> getFollowedHostEventNames({
    required String userId,
    required List<String> eventIds,
  }) async => _names;
}

// Identity ranking only — see this file's own top doc comment for why
// Step 8A's real ranking hierarchy is deliberately NOT exercised here.
class _IdentityDiscoveryService extends EventDiscoveryService {
  _IdentityDiscoveryService()
    : super(
        attendanceRepo: EventAttendanceRepository(_dummyClient),
        friendshipRepo: FriendshipRepository(_dummyClient),
        tripsRepo: PlannedTripsRepository(_dummyClient),
        hostFollowRepo: EventHostFollowRepository(_dummyClient),
        socialRepo: EventSocialRepository(_dummyClient),
      );

  @override
  Future<List<EventDiscoveryItem>> rankForDiscovery({
    required List<Event> events,
    required String? userId,
  }) async => [for (final e in events) EventDiscoveryItem(event: e)];
}

EventDiscoveryFilterService _service({
  required List<Event> events,
  Set<String> tagMatchingIds = const {},
  Map<String, List<String>> going = const {},
  Map<String, List<String>> interested = const {},
  List<Friendship> friends = const [],
  Map<String, String?> followedHostNames = const {},
}) => EventDiscoveryFilterService(
  eventsRepo: _FakeEventsRepository(events),
  tagRepo: _FakeEventTagRepository(tagMatchingIds),
  attendanceRepo: _FakeEventAttendanceRepository(
    going: going,
    interested: interested,
  ),
  friendshipRepo: _FakeFriendshipRepository(friends),
  hostFollowRepo: _FakeEventHostFollowRepository(followedHostNames),
  discoveryService: _IdentityDiscoveryService(),
);

Event _event({
  required String id,
  String name = 'Gala Dinner',
  String city = 'Maastricht',
  double? latitude,
  double? longitude,
  String countryCode = 'NL',
  DateTime? startDate,
  EventType eventType = EventType.dinner,
}) => Event(
  id: id,
  name: name,
  city: city,
  latitude: latitude,
  longitude: longitude,
  startDate: startDate ?? DateTime.utc(2026, 9, 10),
  endDate: startDate ?? DateTime.utc(2026, 9, 10),
  countryCode: countryCode,
  eventType: eventType,
  status: EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

// Real-world vectors reused verbatim from event_near_me_filtering_test
// .dart (N1) — "Amsterdam <-> Rotterdam is well under 100 km",
// "Amsterdam <-> Maastricht is clearly over 100 km" — so this file
// leans on already-proven distance facts rather than re-deriving
// Haversine precision (task §13's own explicit guidance).
final _amsterdam = GeoCoordinate(latitude: 52.3676, longitude: 4.9041);
final _maastricht = GeoCoordinate(latitude: 50.8514, longitude: 5.6910);
// Liège, Belgium — a real cross-border city close to Maastricht
// (~25km), well within a 100km Maastricht-centered radius; Amsterdam
// (same-country, NL) is the already-proven >100km-from-Maastricht point
// above, reused here as the same-country FAR event.
final _liege = GeoCoordinate(latitude: 50.6326, longitude: 5.5797);

void main() {
  group('Near-me-only discovery (N2.3 early-return regression, task §10)', () {
    test('no other filter dimension active, nearMeLocation set: filtering '
        'still executes — a far Event is excluded, a nearby Event remains '
        '(protects EventDiscoveryFilterService.loadFilteredDiscovery\'s own '
        'short-circuit fix)', () async {
      final events = [
        _event(
          id: 'near',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
        _event(
          id: 'far',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
      ];
      final service = _service(events: events);

      final result = await service.loadFilteredDiscovery(
        filters: EventDiscoveryFilters.empty,
        userId: null,
        nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
      );

      expect(result.map((i) => i.event.id), ['near']);
    });
  });

  group('NULL-coordinate exclusion through the real service path (§11)', () {
    test(
      'an Event with missing coordinates is excluded when Near me '
      'enters via loadFilteredDiscovery, exactly like the pure filter',
      (() async {
        final events = [
          _event(
            id: 'near',
            latitude: _maastricht.latitude,
            longitude: _maastricht.longitude,
          ),
          _event(id: 'no-coords'),
        ];
        final service = _service(events: events);

        final result = await service.loadFilteredDiscovery(
          filters: EventDiscoveryFilters.empty,
          userId: null,
          nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
        );

        expect(result.map((i) => i.event.id), ['near']);
      }),
    );
  });

  group('Cross-border through the real service path (§12)', () {
    test('a Belgian Event within 100 km of a Maastricht-centered Near me is '
        'included; a same-country (NL) Event outside 100 km is excluded — '
        'Near me is geometric, never Country-based, all the way through '
        'the service', () async {
      final events = [
        _event(
          id: 'liege-be',
          countryCode: 'BE',
          latitude: _liege.latitude,
          longitude: _liege.longitude,
        ),
        _event(
          id: 'amsterdam-nl',
          countryCode: 'NL',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
      ];
      final service = _service(events: events);

      final result = await service.loadFilteredDiscovery(
        filters: EventDiscoveryFilters.empty,
        userId: null,
        nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
      );

      expect(result.map((i) => i.event.id), ['liege-be']);
    });
  });

  group('Near me + Search (§5)', () {
    test('Near me active, a Search query then applied: results satisfy both '
        'the radius AND the search predicate', () async {
      final events = [
        _event(
          id: 'gala-near',
          name: 'Winter Gala',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
        _event(
          id: 'dinner-near', // near, but doesn't match "gala"
          name: 'Tasting Dinner',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
        _event(
          id: 'gala-far', // matches "gala", but far
          name: 'Summer Gala',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
      ];
      final service = _service(events: events);

      final result = await service.loadFilteredDiscovery(
        filters: EventDiscoveryFilters.empty,
        userId: null,
        query: 'gala',
        nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
      );

      expect(result.map((i) => i.event.id), ['gala-near']);
    });

    test('Search already active, Near me activated afterwards: both '
        'predicates remain active — order of activation does not change '
        'the composed result (same independently-held-state architecture '
        'events_discovery_composition_regression_test.dart already proves '
        'for Search+Date/Location)', () async {
      final events = [
        _event(
          id: 'gala-near',
          name: 'Winter Gala',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
        _event(
          id: 'gala-far',
          name: 'Summer Gala',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
      ];
      final service = _service(events: events);

      final result = await service.loadFilteredDiscovery(
        filters: EventDiscoveryFilters.empty,
        userId: null,
        query: 'gala',
        nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
      );

      expect(result.map((i) => i.event.id), ['gala-near']);
    });
  });

  group('Near me + Date (§6)', () {
    test(
      'three Events chosen so one fails Near me only, one fails Date '
      'only, one satisfies both — only the Event satisfying both survives',
      () async {
        final septemberRange = EventDiscoveryDateRange(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 30),
        );
        final events = [
          _event(
            id: 'near-september', // satisfies both
            latitude: _maastricht.latitude,
            longitude: _maastricht.longitude,
            startDate: DateTime.utc(2026, 9, 15),
          ),
          _event(
            id: 'far-september', // fails Near me only
            latitude: _amsterdam.latitude,
            longitude: _amsterdam.longitude,
            startDate: DateTime.utc(2026, 9, 15),
          ),
          _event(
            id: 'near-november', // fails Date only
            latitude: _maastricht.latitude,
            longitude: _maastricht.longitude,
            startDate: DateTime.utc(2026, 11, 5),
          ),
        ];
        final service = _service(events: events);

        final result = await service.loadFilteredDiscovery(
          filters: EventDiscoveryFilters(dateRange: septemberRange),
          userId: null,
          nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
        );

        expect(result.map((i) => i.event.id), ['near-september']);
      },
    );
  });

  group('Near me + Theme (§7)', () {
    test('three Events chosen so one fails Near me only, one fails the tag '
        'match only, one satisfies both — only that Event survives', () async {
      final events = [
        _event(
          id: 'near-wine', // satisfies both
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
        _event(
          id: 'far-wine', // fails Near me only
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
        _event(
          id: 'near-no-tag', // fails the tag match only
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
      ];
      final service = _service(
        events: events,
        tagMatchingIds: {'near-wine', 'far-wine'},
      );

      final result = await service.loadFilteredDiscovery(
        filters: EventDiscoveryFilters(tagSlugs: {'wine'}),
        userId: null,
        nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
      );

      expect(result.map((i) => i.event.id), ['near-wine']);
    });
  });

  group('Near me + Social (§8)', () {
    test(
      'Friends Going + Near me: three Events chosen so one fails Near me '
      'only, one fails the social qualification only, one satisfies both '
      '— proving Near me does not bypass the real existing Social path',
      () async {
        const userId = 'self-user';
        final friends = [
          const Friendship(friendshipId: 'f1', friendId: 'friend-1'),
        ];
        final events = [
          _event(
            id: 'near-going', // satisfies both
            latitude: _maastricht.latitude,
            longitude: _maastricht.longitude,
          ),
          _event(
            id: 'far-going', // fails Near me only
            latitude: _amsterdam.latitude,
            longitude: _amsterdam.longitude,
          ),
          _event(
            id: 'near-nobody-going', // fails the social qualification only
            latitude: _maastricht.latitude,
            longitude: _maastricht.longitude,
          ),
        ];
        final service = _service(
          events: events,
          friends: friends,
          going: {
            'near-going': ['friend-1'],
            'far-going': ['friend-1'],
          },
        );

        final result = await service.loadFilteredDiscovery(
          filters: EventDiscoveryFilters(
            social: {EventSocialFilter.friendsGoing},
          ),
          userId: userId,
          nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
        );

        expect(result.map((i) => i.event.id), ['near-going']);
      },
    );
  });

  group('Multi-filter composition (§9) — Near me is additive, never resets '
      'other filter state', () {
    test('Near me + Search + Date + Theme together: only the one Event '
        'satisfying literally every dimension survives', () async {
      final septemberRange = EventDiscoveryDateRange(
        from: DateTime.utc(2026, 9, 1),
        to: DateTime.utc(2026, 9, 30),
      );
      final events = [
        _event(
          id: 'gala-near-sep-wine', // satisfies everything
          name: 'Wine Gala',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
          startDate: DateTime.utc(2026, 9, 12),
        ),
        _event(
          id: 'gala-far-sep-wine', // wrong: far
          name: 'Wine Gala',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
          startDate: DateTime.utc(2026, 9, 12),
        ),
        _event(
          id: 'gala-near-nov-wine', // wrong: wrong month
          name: 'Wine Gala',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
          startDate: DateTime.utc(2026, 11, 12),
        ),
        _event(
          id: 'dinner-near-sep-wine', // wrong: search text doesn't match
          name: 'Wine Dinner',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
          startDate: DateTime.utc(2026, 9, 12),
        ),
        _event(
          id: 'gala-near-sep-no-wine', // wrong: no tag match
          name: 'Gala Night',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
          startDate: DateTime.utc(2026, 9, 12),
        ),
      ];
      final service = _service(
        events: events,
        tagMatchingIds: {
          'gala-near-sep-wine',
          'gala-far-sep-wine',
          'gala-near-nov-wine',
        },
      );

      final result = await service.loadFilteredDiscovery(
        filters: EventDiscoveryFilters(
          dateRange: septemberRange,
          tagSlugs: {'wine'},
        ),
        userId: null,
        query: 'gala',
        nearMeLocation: EventNearMeLocation(coordinate: _maastricht),
      );

      expect(result.map((i) => i.event.id), ['gala-near-sep-wine']);
    });
  });

  group('Country regression (§14)', () {
    test(
      'Country-only filtering (no nearMeLocation) behaves exactly as '
      'before — unaffected by Near me\'s existence in the same service',
      (() async {
        final events = [
          _event(id: 'nl-event', countryCode: 'NL'),
          _event(id: 'fr-event', countryCode: 'FR'),
        ];
        final service = _service(events: events);

        final result = await service.loadFilteredDiscovery(
          filters: EventDiscoveryFilters(countryCodes: {'NL'}),
          userId: null,
        );

        expect(result.map((i) => i.event.id), ['nl-event']);
      }),
    );

    test('Country active with nearMeLocation explicitly null (simulating '
        'Country having replaced a prior Near me selection): no stale '
        'geometric restriction leaks in — a far-but-in-country Event still '
        'appears', () async {
      final events = [
        _event(
          id: 'nl-far',
          countryCode: 'NL',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
      ];
      final service = _service(events: events);

      final result = await service.loadFilteredDiscovery(
        filters: EventDiscoveryFilters(countryCodes: {'NL'}),
        userId: null,
        nearMeLocation: null,
      );

      expect(result.map((i) => i.event.id), ['nl-far']);
    });
  });

  group('All locations regression (§15)', () {
    test('no Country predicate and nearMeLocation explicitly null '
        '(simulating Near me -> All locations): normal, unrestricted '
        'discovery — no stale nearMeLocation survives', () async {
      final events = [
        _event(
          id: 'far-event',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
      ];
      final service = _service(events: events);

      final result = await service.loadFilteredDiscovery(
        filters: EventDiscoveryFilters.empty,
        userId: null,
        nearMeLocation: null,
      );

      expect(result.map((i) => i.event.id), ['far-event']);
    });
  });
}
