// Events V2 Near Me Phase N1 — the pure GeoCoordinate value object
// (lib/models/geo_coordinate.dart). No Supabase, no GPS, no package
// dependency in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/geo_coordinate.dart';

void main() {
  group('GeoCoordinate — valid construction', () {
    test('accepts a normal real-world coordinate', () {
      final coordinate = GeoCoordinate(latitude: 52.3676, longitude: 4.9041);
      expect(coordinate.latitude, 52.3676);
      expect(coordinate.longitude, 4.9041);
    });

    test('accepts the exact boundary values', () {
      expect(
        () => GeoCoordinate(latitude: 90, longitude: 180),
        returnsNormally,
      );
      expect(
        () => GeoCoordinate(latitude: -90, longitude: -180),
        returnsNormally,
      );
    });

    test('accepts (0, 0)', () {
      expect(() => GeoCoordinate(latitude: 0, longitude: 0), returnsNormally);
    });
  });

  group('GeoCoordinate — invalid latitude', () {
    test('rejects latitude above 90', () {
      expect(
        () => GeoCoordinate(latitude: 90.1, longitude: 0),
        throwsArgumentError,
      );
    });

    test('rejects latitude below -90', () {
      expect(
        () => GeoCoordinate(latitude: -90.1, longitude: 0),
        throwsArgumentError,
      );
    });
  });

  group('GeoCoordinate — invalid longitude', () {
    test('rejects longitude above 180', () {
      expect(
        () => GeoCoordinate(latitude: 0, longitude: 180.1),
        throwsArgumentError,
      );
    });

    test('rejects longitude below -180', () {
      expect(
        () => GeoCoordinate(latitude: 0, longitude: -180.1),
        throwsArgumentError,
      );
    });
  });

  group('GeoCoordinate — equality', () {
    test('two coordinates with the same values compare equal', () {
      final a = GeoCoordinate(latitude: 52.3676, longitude: 4.9041);
      final b = GeoCoordinate(latitude: 52.3676, longitude: 4.9041);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a different latitude or longitude breaks equality', () {
      final a = GeoCoordinate(latitude: 52.3676, longitude: 4.9041);
      final b = GeoCoordinate(latitude: 52.0, longitude: 4.9041);
      final c = GeoCoordinate(latitude: 52.3676, longitude: 5.0);
      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
    });
  });
}
