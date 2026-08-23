// Events V2 Near Me Phase N1 — the CurrentLocationProvider contract
// (lib/features/events/current_location_provider.dart). This is the ONE
// place in this codebase's test suite that hand-rolls a fake — not the
// established "no mocking framework" convention being broken, but the
// deliberate reason this interface exists at all: a small seam a real
// N2 adapter (backed by `geolocator`, not present in this phase) and a
// test fake can both implement, so the rest of the app never needs to
// know which one it's talking to. The fake below is test-only — nothing
// in `lib/` constructs it, and no production fallback implementation of
// CurrentLocationProvider exists anywhere in this codebase.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/current_location_provider.dart';
import 'package:michelin_passport/models/geo_coordinate.dart';

class _FakeCurrentLocationProvider implements CurrentLocationProvider {
  final CurrentLocationResult result;
  _FakeCurrentLocationProvider(this.result);

  @override
  Future<CurrentLocationResult> getCurrentLocation() async => result;
}

void main() {
  group('CurrentLocationProvider — success', () {
    test(
      'resolves to a CurrentLocationSuccess carrying the coordinate',
      () async {
        final coordinate = GeoCoordinate(latitude: 52.3676, longitude: 4.9041);
        final provider = _FakeCurrentLocationProvider(
          CurrentLocationSuccess(coordinate),
        );
        final result = await provider.getCurrentLocation();
        expect(result, isA<CurrentLocationSuccess>());
        expect((result as CurrentLocationSuccess).coordinate, coordinate);
      },
    );
  });

  group('CurrentLocationProvider — failure taxonomy', () {
    for (final type in CurrentLocationFailureType.values) {
      test('resolves to a CurrentLocationFailure carrying $type', () async {
        final provider = _FakeCurrentLocationProvider(
          CurrentLocationFailure(type),
        );
        final result = await provider.getCurrentLocation();
        expect(result, isA<CurrentLocationFailure>());
        expect((result as CurrentLocationFailure).type, type);
      });
    }

    test('permission denied and permanently denied are distinct types — '
        'a future UI needs to tell them apart (only the latter should '
        'ever route to Settings, never another in-app prompt)', () {
      expect(
        CurrentLocationFailureType.permissionDenied,
        isNot(CurrentLocationFailureType.permissionDeniedForever),
      );
    });

    test('services-disabled is distinct from a plain permission denial '
        '— no permission dialog would even fire in that state', () {
      expect(
        CurrentLocationFailureType.servicesDisabled,
        isNot(CurrentLocationFailureType.permissionDenied),
      );
    });
  });

  group('CurrentLocationResult — exhaustive matching', () {
    test('every result can be exhaustively switched over without a '
        'default case (compile-time proof the sealed hierarchy is '
        'closed)', () async {
      String describe(CurrentLocationResult result) => switch (result) {
        CurrentLocationSuccess() => 'success',
        CurrentLocationFailure(:final type) => 'failure:${type.name}',
      };

      final coordinate = GeoCoordinate(latitude: 0, longitude: 0);
      expect(describe(CurrentLocationSuccess(coordinate)), 'success');
      expect(
        describe(
          const CurrentLocationFailure(CurrentLocationFailureType.unavailable),
        ),
        'failure:unavailable',
      );
    });
  });

  group('CurrentLocationResult — equality', () {
    test('two successes with the same coordinate compare equal', () {
      final coordinate = GeoCoordinate(latitude: 1, longitude: 2);
      expect(
        CurrentLocationSuccess(coordinate),
        equals(CurrentLocationSuccess(coordinate)),
      );
    });

    test('two failures with the same type compare equal', () {
      expect(
        const CurrentLocationFailure(CurrentLocationFailureType.unavailable),
        equals(
          const CurrentLocationFailure(CurrentLocationFailureType.unavailable),
        ),
      );
    });

    test('a success and a failure are never equal', () {
      final coordinate = GeoCoordinate(latitude: 1, longitude: 2);
      expect(
        CurrentLocationSuccess(coordinate),
        isNot(
          equals(
            const CurrentLocationFailure(
              CurrentLocationFailureType.unavailable,
            ),
          ),
        ),
      );
    });
  });
}
