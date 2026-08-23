// Events V2 Near Me Phase N1 — EventNearMeLocation and the
// defaultEventNearMeRadiusKm constant (lib/models/event_near_me_location.
// dart). No Supabase, no GPS in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/event_near_me_location.dart';
import 'package:michelin_passport/models/geo_coordinate.dart';

GeoCoordinate _amsterdam() =>
    GeoCoordinate(latitude: 52.3676, longitude: 4.9041);

void main() {
  group('defaultEventNearMeRadiusKm', () {
    test('is the provisional V1 100km product decision', () {
      expect(defaultEventNearMeRadiusKm, 100.0);
    });
  });

  group('EventNearMeLocation — valid radius', () {
    test('uses the default radius when none is given', () {
      final location = EventNearMeLocation(coordinate: _amsterdam());
      expect(location.radiusKm, defaultEventNearMeRadiusKm);
    });

    test('accepts an explicit positive radius override', () {
      final location = EventNearMeLocation(
        coordinate: _amsterdam(),
        radiusKm: 25,
      );
      expect(location.radiusKm, 25);
    });
  });

  group('EventNearMeLocation — invalid radius', () {
    test('rejects a zero radius', () {
      expect(
        () => EventNearMeLocation(coordinate: _amsterdam(), radiusKm: 0),
        throwsArgumentError,
      );
    });

    test('rejects a negative radius', () {
      expect(
        () => EventNearMeLocation(coordinate: _amsterdam(), radiusKm: -10),
        throwsArgumentError,
      );
    });
  });

  group('EventNearMeLocation — equality', () {
    test('two locations with the same coordinate and radius compare '
        'equal', () {
      final a = EventNearMeLocation(coordinate: _amsterdam(), radiusKm: 50);
      final b = EventNearMeLocation(coordinate: _amsterdam(), radiusKm: 50);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a different radius breaks equality even with the same '
        'coordinate', () {
      final a = EventNearMeLocation(coordinate: _amsterdam(), radiusKm: 50);
      final b = EventNearMeLocation(coordinate: _amsterdam(), radiusKm: 100);
      expect(a, isNot(equals(b)));
    });
  });
}
