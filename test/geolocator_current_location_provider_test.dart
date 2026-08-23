// Events V2 Near Me Phase N2.2 — deterministic unit coverage for
// GeolocatorCurrentLocationProvider's own plugin-outcome ->
// CurrentLocationResult mapping. No physical device, no simulator
// permission prompt, no real GPS, no OS Settings interaction — every
// `geolocator` call is intercepted via the adapter's own
// GeolocatorGateway seam (introduced in N2.2 specifically to make this
// possible; Geolocator's own methods are static and otherwise
// unsubstitutable). This does not test the `geolocator` plugin itself —
// only this app's own mapping/orchestration layer around it.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:michelin_passport/features/events/current_location_provider.dart';
import 'package:michelin_passport/features/events/geolocator_current_location_provider.dart';

Position _position({double latitude = 50.8514, double longitude = 5.6909}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 1, 1),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// A hand-rolled fake — not a mocking framework — implementing exactly
/// the four-method [GeolocatorGateway] contract, matching this
/// codebase's own established "no Mock/Fake classes except where a
/// deliberate testability seam was introduced for exactly this purpose"
/// convention (see `current_location_provider_test.dart`'s own doc
/// comment on the same reasoning, N1). Records call counts/arguments in
/// memory only, purely for test assertions — never anything resembling
/// production telemetry.
class _FakeGeolocatorGateway implements GeolocatorGateway {
  bool serviceEnabled = true;
  LocationPermission checkPermissionResult = LocationPermission.whileInUse;
  LocationPermission requestPermissionResult = LocationPermission.whileInUse;
  Position? position;
  Object? positionError;
  // Events V2 Near Me Phase N2.4 additions — same hand-rolled-fake shape
  // as the four pre-existing members above, extended (not replaced) now
  // that GeolocatorGateway itself grew the two Settings-navigation calls.
  bool openAppSettingsResult = true;
  Object? openAppSettingsError;
  bool openLocationSettingsResult = true;
  Object? openLocationSettingsError;

  int isLocationServiceEnabledCallCount = 0;
  int checkPermissionCallCount = 0;
  int requestPermissionCallCount = 0;
  int getCurrentPositionCallCount = 0;
  int openAppSettingsCallCount = 0;
  int openLocationSettingsCallCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async {
    isLocationServiceEnabledCallCount++;
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCallCount++;
    return checkPermissionResult;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCallCount++;
    return requestPermissionResult;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) async {
    getCurrentPositionCallCount++;
    if (positionError != null) throw positionError!;
    return position ?? _position();
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCallCount++;
    if (openAppSettingsError != null) throw openAppSettingsError!;
    return openAppSettingsResult;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCallCount++;
    if (openLocationSettingsError != null) throw openLocationSettingsError!;
    return openLocationSettingsResult;
  }
}

void main() {
  group('GeolocatorCurrentLocationProvider — successful path', () {
    test('A. permission already granted (whileInUse): success, no '
        'permission request, position requested exactly once', () async {
      final gateway = _FakeGeolocatorGateway()
        ..serviceEnabled = true
        ..checkPermissionResult = LocationPermission.whileInUse
        ..position = _position(latitude: 50.8514, longitude: 5.6909);
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(result, isA<CurrentLocationSuccess>());
      final success = result as CurrentLocationSuccess;
      expect(success.coordinate.latitude, 50.8514);
      expect(success.coordinate.longitude, 5.6909);
      expect(gateway.requestPermissionCallCount, 0);
      expect(gateway.getCurrentPositionCallCount, 1);
    });

    test('A2. permission already granted (always): success, no '
        'permission request', () async {
      final gateway = _FakeGeolocatorGateway()
        ..checkPermissionResult = LocationPermission.always;
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(result, isA<CurrentLocationSuccess>());
      expect(gateway.requestPermissionCallCount, 0);
      expect(gateway.getCurrentPositionCallCount, 1);
    });

    test('B. permission becomes granted after one request: success, '
        'request occurred exactly once, position requested exactly '
        'once', () async {
      final gateway = _FakeGeolocatorGateway()
        ..checkPermissionResult = LocationPermission.denied
        ..requestPermissionResult = LocationPermission.whileInUse;
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(result, isA<CurrentLocationSuccess>());
      expect(gateway.requestPermissionCallCount, 1);
      expect(gateway.getCurrentPositionCallCount, 1);
    });
  });

  group('GeolocatorCurrentLocationProvider — failure: servicesDisabled', () {
    test('services disabled before permission handling -> '
        'servicesDisabled; permission never checked/requested; position '
        'never requested', () async {
      final gateway = _FakeGeolocatorGateway()..serviceEnabled = false;
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(
        result,
        const CurrentLocationFailure(
          CurrentLocationFailureType.servicesDisabled,
        ),
      );
      expect(gateway.checkPermissionCallCount, 0);
      expect(gateway.requestPermissionCallCount, 0);
      expect(gateway.getCurrentPositionCallCount, 0);
    });
  });

  group('GeolocatorCurrentLocationProvider — failure: permissionDenied', () {
    test('denied -> request -> still denied: permissionDenied; request '
        'occurred exactly once; position never requested', () async {
      final gateway = _FakeGeolocatorGateway()
        ..checkPermissionResult = LocationPermission.denied
        ..requestPermissionResult = LocationPermission.denied;
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(
        result,
        const CurrentLocationFailure(
          CurrentLocationFailureType.permissionDenied,
        ),
      );
      expect(gateway.requestPermissionCallCount, 1);
      expect(gateway.getCurrentPositionCallCount, 0);
    });
  });

  group('GeolocatorCurrentLocationProvider — failure: '
      'permissionDeniedForever', () {
    test('checkPermission() directly returns deniedForever: no request '
        'is made (the OS will not show a dialog); position never '
        'requested', () async {
      final gateway = _FakeGeolocatorGateway()
        ..checkPermissionResult = LocationPermission.deniedForever;
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(
        result,
        const CurrentLocationFailure(
          CurrentLocationFailureType.permissionDeniedForever,
        ),
      );
      expect(gateway.requestPermissionCallCount, 0);
      expect(gateway.getCurrentPositionCallCount, 0);
    });

    test('denied -> request -> deniedForever: permissionDeniedForever; '
        'position never requested', () async {
      final gateway = _FakeGeolocatorGateway()
        ..checkPermissionResult = LocationPermission.denied
        ..requestPermissionResult = LocationPermission.deniedForever;
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(
        result,
        const CurrentLocationFailure(
          CurrentLocationFailureType.permissionDeniedForever,
        ),
      );
      expect(gateway.requestPermissionCallCount, 1);
      expect(gateway.getCurrentPositionCallCount, 0);
    });
  });

  group('GeolocatorCurrentLocationProvider — unableToDetermine (web-only, '
      'unreachable on iOS/Android but mapped deterministically anyway)', () {
    test(
      'unableToDetermine -> unavailable; position never requested',
      () async {
        final gateway = _FakeGeolocatorGateway()
          ..checkPermissionResult = LocationPermission.unableToDetermine;
        final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

        final result = await provider.getCurrentLocation();

        expect(
          result,
          const CurrentLocationFailure(CurrentLocationFailureType.unavailable),
        );
        expect(gateway.getCurrentPositionCallCount, 0);
      },
    );
  });

  group('GeolocatorCurrentLocationProvider — exception mapping', () {
    test('LocationServiceDisabledException during acquisition -> '
        'servicesDisabled', () async {
      final gateway = _FakeGeolocatorGateway()
        ..positionError = const LocationServiceDisabledException();
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(
        result,
        const CurrentLocationFailure(
          CurrentLocationFailureType.servicesDisabled,
        ),
      );
    });

    test('PermissionDeniedException -> permissionDenied', () async {
      final gateway = _FakeGeolocatorGateway()
        ..positionError = const PermissionDeniedException('denied');
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(
        result,
        const CurrentLocationFailure(
          CurrentLocationFailureType.permissionDenied,
        ),
      );
    });

    test('TimeoutException -> unavailable', () async {
      final gateway = _FakeGeolocatorGateway()
        ..positionError = TimeoutException('timed out');
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(
        result,
        const CurrentLocationFailure(CurrentLocationFailureType.unavailable),
      );
    });

    test('an unexpected exception (e.g. StateError) -> unavailable, '
        'never rethrown', () async {
      final gateway = _FakeGeolocatorGateway()
        ..positionError = StateError('unexpected plugin failure');
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(
        result,
        const CurrentLocationFailure(CurrentLocationFailureType.unavailable),
      );
    });
  });

  group('GeolocatorCurrentLocationProvider — coordinate transfer', () {
    test('a successful plugin position is passed into GeoCoordinate '
        'unchanged', () async {
      final gateway = _FakeGeolocatorGateway()
        ..position = _position(latitude: 50.8514, longitude: 5.6909);
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      final success = result as CurrentLocationSuccess;
      expect(success.coordinate.latitude, 50.8514);
      expect(success.coordinate.longitude, 5.6909);
    });
  });

  group('GeolocatorCurrentLocationProvider — invalid platform coordinate '
      '(N1 GeoCoordinate validation, unchanged)', () {
    test('a plugin position outside the valid latitude/longitude range '
        'never produces CurrentLocationSuccess — the adapter\'s generic '
        'exception handling maps GeoCoordinate\'s own ArgumentError to '
        'unavailable', () async {
      final gateway = _FakeGeolocatorGateway()
        ..position = _position(latitude: 200, longitude: 5.6909);
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      final result = await provider.getCurrentLocation();

      expect(result, isA<CurrentLocationFailure>());
      expect(
        (result as CurrentLocationFailure).type,
        CurrentLocationFailureType.unavailable,
      );
    });
  });

  group('GeolocatorCurrentLocationProvider — call order / side effects', () {
    test(
      'the service-enabled check occurs before any permission call',
      () async {
        final gateway = _FakeGeolocatorGateway()..serviceEnabled = false;
        final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

        await provider.getCurrentLocation();

        expect(gateway.isLocationServiceEnabledCallCount, 1);
        expect(gateway.checkPermissionCallCount, 0);
      },
    );

    test('permission is requested at most once per getCurrentLocation() '
        'call, even when still denied afterward', () async {
      final gateway = _FakeGeolocatorGateway()
        ..checkPermissionResult = LocationPermission.denied
        ..requestPermissionResult = LocationPermission.denied;
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      await provider.getCurrentLocation();

      expect(gateway.requestPermissionCallCount, 1);
    });

    test('getCurrentPosition is never called when permission is invalid '
        '(denied)', () async {
      final gateway = _FakeGeolocatorGateway()
        ..checkPermissionResult = LocationPermission.denied
        ..requestPermissionResult = LocationPermission.denied;
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      await provider.getCurrentLocation();

      expect(gateway.getCurrentPositionCallCount, 0);
    });

    test('getCurrentPosition is called exactly once on the successful '
        'path — never zero, never more than once', () async {
      final gateway = _FakeGeolocatorGateway();
      final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

      await provider.getCurrentLocation();

      expect(gateway.getCurrentPositionCallCount, 1);
    });
  });

  group(
    'GeolocatorCurrentLocationProvider — LocationSettingsOpener (N2.4)',
    () {
      test('openAppSettings forwards the gateway result', () async {
        final gateway = _FakeGeolocatorGateway()..openAppSettingsResult = true;
        final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

        final opened = await provider.openAppSettings();

        expect(opened, isTrue);
        expect(gateway.openAppSettingsCallCount, 1);
      });

      test('openAppSettings maps an unexpected gateway exception to false, '
          'never rethrows', () async {
        final gateway = _FakeGeolocatorGateway()
          ..openAppSettingsError = Exception('platform channel failure');
        final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

        final opened = await provider.openAppSettings();

        expect(opened, isFalse);
      });

      test('openLocationSettings forwards the gateway result', () async {
        final gateway = _FakeGeolocatorGateway()
          ..openLocationSettingsResult = false;
        final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

        final opened = await provider.openLocationSettings();

        expect(opened, isFalse);
        expect(gateway.openLocationSettingsCallCount, 1);
      });

      test('openLocationSettings maps an unexpected gateway exception to '
          'false, never rethrows', () async {
        final gateway = _FakeGeolocatorGateway()
          ..openLocationSettingsError = Exception('platform channel failure');
        final provider = GeolocatorCurrentLocationProvider(gateway: gateway);

        final opened = await provider.openLocationSettings();

        expect(opened, isFalse);
      });
    },
  );
}
