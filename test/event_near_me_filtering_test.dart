// Events V2 Near Me Phase N1 — the pure distance/inclusion core
// (lib/features/events/event_near_me_filtering.dart) plus its
// composition with the existing applyDiscoveryFilters (Date/Theme/
// Social) and Step 8A ranking (event_discovery_ranking.dart). No
// Supabase, no GPS, no permission dependency anywhere in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/event_discovery_filtering.dart';
import 'package:michelin_passport/features/events/event_discovery_ranking.dart';
import 'package:michelin_passport/features/events/event_near_me_filtering.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_discovery_filters.dart';
import 'package:michelin_passport/models/event_near_me_location.dart';
import 'package:michelin_passport/models/event_relevance_reason.dart';
import 'package:michelin_passport/models/geo_coordinate.dart';

Event _event({
  required String id,
  double? latitude,
  double? longitude,
  String countryCode = 'NL',
  DateTime? startDate,
  EventType eventType = EventType.dinner,
}) => Event(
  id: id,
  name: 'Event $id',
  latitude: latitude,
  longitude: longitude,
  startDate: startDate ?? DateTime.utc(2026, 9, 10),
  endDate: startDate ?? DateTime.utc(2026, 9, 10),
  countryCode: countryCode,
  eventType: eventType,
  status: EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

final _amsterdam = GeoCoordinate(latitude: 52.3676, longitude: 4.9041);
final _rotterdam = GeoCoordinate(latitude: 51.9225, longitude: 4.4792);
final _maastricht = GeoCoordinate(latitude: 50.8514, longitude: 5.6910);

void main() {
  group('eventGeoDistanceKm — known distance vectors', () {
    test('the same coordinate is 0 km from itself', () {
      expect(eventGeoDistanceKm(_amsterdam, _amsterdam), 0.0);
    });

    test('exactly 1 degree of latitude at the same longitude is ~111.3 '
        'km — the well-known spherical-Earth meridian-degree distance, '
        'proving the formula is a genuine great-circle calculation, not '
        'a placeholder', () {
      final a = GeoCoordinate(latitude: 52.0, longitude: 4.0);
      final b = GeoCoordinate(latitude: 53.0, longitude: 4.0);
      expect(eventGeoDistanceKm(a, b), closeTo(111.32, 1.0));
    });

    test('Amsterdam <-> Rotterdam (a nearby Dutch city) is well under '
        '100 km', () {
      final distance = eventGeoDistanceKm(_amsterdam, _rotterdam);
      expect(distance, greaterThan(0));
      expect(distance, lessThan(100));
    });

    test('Amsterdam <-> Maastricht is clearly over 100 km', () {
      expect(eventGeoDistanceKm(_amsterdam, _maastricht), greaterThan(100));
    });

    test('distance is symmetric: A to B equals B to A', () {
      expect(
        eventGeoDistanceKm(_amsterdam, _maastricht),
        eventGeoDistanceKm(_maastricht, _amsterdam),
      );
    });
  });

  group('eventQualifiesForNearMe — radius boundary (Phase N1 §10)', () {
    test('an Event exactly at the Near-me center qualifies (0 km <= any '
        'positive radius)', () {
      final location = EventNearMeLocation(coordinate: _amsterdam);
      final event = _event(
        id: 'center',
        latitude: _amsterdam.latitude,
        longitude: _amsterdam.longitude,
      );
      expect(eventQualifiesForNearMe(event, location), isTrue);
    });

    test('distance == radius is included, not excluded — the radius is '
        'derived from the actual computed distance to this exact event '
        'so the boundary comparison is float-for-float exact, never an '
        'approximated hand-calculation', () {
      const eventCoordinateLat = 52.9;
      final event = _event(
        id: 'boundary',
        latitude: eventCoordinateLat,
        longitude: _amsterdam.longitude,
      );
      final exactDistance = eventGeoDistanceKm(
        _amsterdam,
        GeoCoordinate(
          latitude: eventCoordinateLat,
          longitude: _amsterdam.longitude,
        ),
      );
      final location = EventNearMeLocation(
        coordinate: _amsterdam,
        radiusKm: exactDistance,
      );
      expect(eventQualifiesForNearMe(event, location), isTrue);
    });

    test('a hair inside the radius qualifies', () {
      const eventCoordinateLat = 52.9;
      final eventCoordinate = GeoCoordinate(
        latitude: eventCoordinateLat,
        longitude: _amsterdam.longitude,
      );
      final event = _event(
        id: 'just-inside',
        latitude: eventCoordinateLat,
        longitude: _amsterdam.longitude,
      );
      final exactDistance = eventGeoDistanceKm(_amsterdam, eventCoordinate);
      final location = EventNearMeLocation(
        coordinate: _amsterdam,
        radiusKm: exactDistance + 0.5,
      );
      expect(eventQualifiesForNearMe(event, location), isTrue);
    });

    test('a hair outside the radius does not qualify', () {
      const eventCoordinateLat = 52.9;
      final eventCoordinate = GeoCoordinate(
        latitude: eventCoordinateLat,
        longitude: _amsterdam.longitude,
      );
      final event = _event(
        id: 'just-outside',
        latitude: eventCoordinateLat,
        longitude: _amsterdam.longitude,
      );
      final exactDistance = eventGeoDistanceKm(_amsterdam, eventCoordinate);
      final location = EventNearMeLocation(
        coordinate: _amsterdam,
        radiusKm: exactDistance - 0.5,
      );
      expect(eventQualifiesForNearMe(event, location), isFalse);
    });

    test('an Event far outside the radius does not qualify', () {
      final location = EventNearMeLocation(coordinate: _amsterdam);
      final event = _event(
        id: 'maastricht',
        latitude: _maastricht.latitude,
        longitude: _maastricht.longitude,
      );
      expect(eventQualifiesForNearMe(event, location), isFalse);
    });
  });

  group('eventQualifiesForNearMe — NULL coordinates (Phase N1 §19, '
      'never a proxy)', () {
    final location = EventNearMeLocation(coordinate: _amsterdam);

    test('NULL latitude excludes the Event, regardless of longitude', () {
      final event = _event(id: 'no-lat', longitude: _amsterdam.longitude);
      expect(eventQualifiesForNearMe(event, location), isFalse);
    });

    test('NULL longitude excludes the Event, regardless of latitude', () {
      final event = _event(id: 'no-lng', latitude: _amsterdam.latitude);
      expect(eventQualifiesForNearMe(event, location), isFalse);
    });

    test('both NULL excludes the Event', () {
      final event = _event(id: 'no-coords');
      expect(eventQualifiesForNearMe(event, location), isFalse);
    });
  });

  group('eventQualifiesForNearMe — cross-border, purely geometric '
      '(Phase N1 §20)', () {
    test('a Belgian Event well within the Dutch-centered radius '
        'qualifies — country is never consulted', () {
      // Antwerp, Belgium — close to the Dutch border.
      final antwerp = GeoCoordinate(latitude: 51.2194, longitude: 4.4025);
      final location = EventNearMeLocation(
        coordinate: _amsterdam,
        radiusKm: eventGeoDistanceKm(_amsterdam, antwerp) + 5,
      );
      final event = _event(
        id: 'antwerp',
        latitude: antwerp.latitude,
        longitude: antwerp.longitude,
        countryCode: 'BE',
      );
      expect(eventQualifiesForNearMe(event, location), isTrue);
    });
  });

  group('applyDiscoveryFilters — nearMeLocation composition (Phase N1 '
      '§21)', () {
    test('nearMeLocation alone narrows to only qualifying Events, '
        'preserving the existing empty-filters-unchanged behavior when '
        'null', () {
      final events = [
        _event(
          id: 'near',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
        _event(
          id: 'far',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
        _event(id: 'no-coords'),
      ];
      final location = EventNearMeLocation(coordinate: _amsterdam);
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters.empty,
        userSignedIn: true,
        nearMeLocation: location,
      );
      expect(result.map((e) => e.id), ['near']);
    });

    test('an unrelated existing caller that never passes nearMeLocation '
        'is completely unaffected — empty filters still return the '
        'input list unchanged', () {
      final events = [_event(id: 'a'), _event(id: 'b')];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters.empty,
        userSignedIn: true,
      );
      expect(result, same(events));
    });

    test('Near me AND Date: both dimensions must hold', () {
      final events = [
        _event(
          id: 'near-in-range',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
          startDate: DateTime.utc(2026, 9, 15),
        ),
        _event(
          id: 'near-out-of-range',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
          startDate: DateTime.utc(2026, 11, 1),
        ),
        _event(
          id: 'far-in-range',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
          startDate: DateTime.utc(2026, 9, 15),
        ),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(
          dateRange: EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 1),
            to: DateTime.utc(2026, 9, 30),
          ),
        ),
        userSignedIn: true,
        nearMeLocation: EventNearMeLocation(coordinate: _amsterdam),
      );
      expect(result.map((e) => e.id), ['near-in-range']);
    });

    test('Near me AND Theme: theme-matching id set still applies '
        'alongside distance', () {
      final events = [
        _event(
          id: 'near-wine',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
        _event(
          id: 'near-no-wine',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
        _event(
          id: 'far-wine',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(tagSlugs: {'wine'}),
        userSignedIn: true,
        tagMatchingEventIds: {'near-wine', 'far-wine'},
        nearMeLocation: EventNearMeLocation(coordinate: _amsterdam),
      );
      expect(result.map((e) => e.id), ['near-wine']);
    });

    test('Near me AND Social: signed-out + active Social is still a '
        'deterministic empty result, unaffected by Near me', () {
      final events = [
        _event(
          id: 'near',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.friendsGoing},
        ),
        userSignedIn: false,
        nearMeLocation: EventNearMeLocation(coordinate: _amsterdam),
      );
      expect(result, isEmpty);
    });

    test('Near me AND Social (signed in): social-qualifying id set still '
        'applies alongside distance', () {
      final events = [
        _event(
          id: 'near-going',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
        _event(
          id: 'near-not-going',
          latitude: _amsterdam.latitude,
          longitude: _amsterdam.longitude,
        ),
        _event(
          id: 'far-going',
          latitude: _maastricht.latitude,
          longitude: _maastricht.longitude,
        ),
      ];
      final result = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters(
          social: {EventSocialFilter.friendsGoing},
        ),
        userSignedIn: true,
        socialQualifyingEventIds: {'near-going', 'far-going'},
        nearMeLocation: EventNearMeLocation(coordinate: _amsterdam),
      );
      expect(result.map((e) => e.id), ['near-going']);
    });
  });

  group('Ranking regression — Near me determines inclusion only, Step '
      '8A still ranks (Phase N1 §22)', () {
    test('among Near-me-qualifying Events, a farther Event with a '
        'stronger Step 8A signal (Trip) still outranks a closer Event '
        'with no signal at all — Near me is never a ranking tier', () {
      final closer = _event(
        id: 'closer-5km',
        latitude: 52.40, // ~5km from Amsterdam
        longitude: 4.90,
      );
      final farther = _event(
        id: 'farther-40km-trip',
        latitude: 52.70, // ~40km from Amsterdam, still within 100km
        longitude: 4.90,
      );
      final events = [closer, farther];
      final location = EventNearMeLocation(coordinate: _amsterdam);

      final qualifying = applyDiscoveryFilters(
        events: events,
        filters: EventDiscoveryFilters.empty,
        userSignedIn: true,
        nearMeLocation: location,
      );
      // Both survive the Near-me filter — sanity check the fixture
      // actually exercises "farther but still within radius."
      expect(qualifying.map((e) => e.id).toSet(), {
        'closer-5km',
        'farther-40km-trip',
      });

      final ranked = rankEventsForDiscovery(
        events: qualifying,
        signalsByEventId: {
          'farther-40km-trip': const EventRelevanceSignals(tripMatch: true),
        },
      );
      expect(ranked.first.event.id, 'farther-40km-trip');
      expect(ranked.first.primaryReason, isA<TripRelevanceReason>());
      // The closer Event has no signal — no fabricated "5km away"
      // relevance reason was ever invented for it.
      expect(ranked.last.event.id, 'closer-5km');
      expect(ranked.last.primaryReason, isNull);
    });
  });
}
