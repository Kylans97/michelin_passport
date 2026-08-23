import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:geolocator/geolocator.dart' as geolocator;

import '../../models/geo_coordinate.dart';
import 'current_location_provider.dart';
import 'location_settings_opener.dart';

/// Events V2 Near Me Phase N2.2 — the minimal seam between
/// [GeolocatorCurrentLocationProvider] and the `geolocator` package's own
/// static API. `Geolocator`'s methods are `static`, so nothing outside
/// this file could otherwise substitute a deterministic fake for them in
/// a test — this interface exists ONLY to make that possible, exposing
/// exactly the four calls [GeolocatorCurrentLocationProvider] actually
/// needs, nothing more. Deliberately NOT a mirror of the whole
/// `geolocator` package (no distance/bearing/open-settings methods live
/// here — those aren't used by this adapter; open-settings is an N2.4
/// concern). Public only so `test/` can implement a fake — production
/// code never needs to reference this type by name (the default
/// constructor argument below already wires the real implementation in).
abstract interface class GeolocatorGateway {
  Future<bool> isLocationServiceEnabled();
  Future<geolocator.LocationPermission> checkPermission();
  Future<geolocator.LocationPermission> requestPermission();
  Future<geolocator.Position> getCurrentPosition({
    required geolocator.LocationSettings locationSettings,
  });

  // Events V2 Near Me Phase N2.4 — added to the SAME seam rather than a
  // second gateway type (task §8's own first-listed preferred option):
  // both are plain, zero-logic forwards to `Geolocator`'s own static
  // Settings-navigation methods, exactly like the four calls above.
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// The real, production [GeolocatorGateway] — a direct, zero-logic
/// forward to `Geolocator`'s own static methods. This is the only place
/// in this codebase that ever calls those static methods directly.
class _RealGeolocatorGateway implements GeolocatorGateway {
  const _RealGeolocatorGateway();

  @override
  Future<bool> isLocationServiceEnabled() =>
      geolocator.Geolocator.isLocationServiceEnabled();

  @override
  Future<geolocator.LocationPermission> checkPermission() =>
      geolocator.Geolocator.checkPermission();

  @override
  Future<geolocator.LocationPermission> requestPermission() =>
      geolocator.Geolocator.requestPermission();

  @override
  Future<geolocator.Position> getCurrentPosition({
    required geolocator.LocationSettings locationSettings,
  }) => geolocator.Geolocator.getCurrentPosition(
    locationSettings: locationSettings,
  );

  @override
  Future<bool> openAppSettings() => geolocator.Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() =>
      geolocator.Geolocator.openLocationSettings();
}

/// Events V2 Near Me Phase N2.1/N2.2 — the first, and only, concrete
/// [CurrentLocationProvider] implementation in this codebase. Wraps
/// `geolocator`'s own permission + position APIs (via [GeolocatorGateway]
/// — see that type's own doc comment for why the seam exists); every
/// `geolocator`-specific type stops at this file's own boundary —
/// nothing that depends on [CurrentLocationProvider] ever needs to
/// import `package:geolocator` itself (see `current_location_provider.
/// dart`'s own doc comment on why that seam exists).
///
/// One-shot only, matching the interface's own contract exactly: this
/// class calls `getCurrentPosition` exactly once per [getCurrentLocation]
/// call, and NEVER a stream method (confirmed absent from this file — no
/// `Stream`-typed member exists anywhere in [GeolocatorGateway] itself,
/// so calling one isn't merely avoided by convention, it's structurally
/// unavailable through this seam). No field/state is retained between
/// calls, no caching, no background listening; nothing in this class
/// persists, logs, or transmits a coordinate beyond returning it to the
/// caller.
///
/// N2.1 introduced this file with direct `Geolocator.*` static calls;
/// N2.2 introduced [GeolocatorGateway] purely to make those calls
/// deterministically testable — production behavior and the public
/// [CurrentLocationProvider] contract are both unchanged by that
/// refactor (confirmed by N2.1's own test suite, `current_location_
/// provider_test.dart`, still passing unmodified). Nothing in this
/// codebase constructs this class from production code yet (see N2.1's
/// own scope boundary: no production caller, no UI wiring, no reachable
/// permission prompt — still true after N2.2).
class GeolocatorCurrentLocationProvider
    implements CurrentLocationProvider, LocationSettingsOpener {
  /// [gateway] defaults to the real `geolocator`-backed implementation —
  /// every production call site (none yet exist) constructs this with no
  /// arguments and gets real device behavior. The parameter exists only
  /// so `test/` can substitute a deterministic fake; it is not part of
  /// this class's own meaningful public contract.
  const GeolocatorCurrentLocationProvider({
    @visibleForTesting
    GeolocatorGateway gateway = const _RealGeolocatorGateway(),
  })
    // An initializing formal (`this._gateway`) would force the public
    // parameter itself to be named `_gateway`, which a test file in a
    // different library could never reference (Dart's per-file privacy)
    // — the whole reason this parameter exists. The public name must
    // stay `gateway`, mapped explicitly to the private field below.
    // ignore: prefer_initializing_formals
    : _gateway = gateway;

  final GeolocatorGateway _gateway;

  /// Near Me's own fixed 100km radius (see `event_near_me_location.dart`)
  /// has no need for meter-level GPS precision. `LocationAccuracy.low`
  /// resolves to roughly ~1000m on iOS / ~500m on Android per
  /// `geolocator`'s own documented tolerances — well under 1% of the
  /// 100km radius itself, an entirely negligible margin for a "which
  /// Events are within range" decision, while costing meaningfully less
  /// battery/time than `medium`/`high`/`best`. Deliberately never
  /// `best`/`bestForNavigation` — this feature is calm destination
  /// discovery, not turn-by-turn navigation.
  static const _accuracy = geolocator.LocationAccuracy.low;

  @override
  Future<CurrentLocationResult> getCurrentLocation() async {
    try {
      if (!await _gateway.isLocationServiceEnabled()) {
        return const CurrentLocationFailure(
          CurrentLocationFailureType.servicesDisabled,
        );
      }

      var permission = await _gateway.checkPermission();
      if (permission == geolocator.LocationPermission.denied) {
        permission = await _gateway.requestPermission();
      }

      switch (permission) {
        case geolocator.LocationPermission.denied:
          return const CurrentLocationFailure(
            CurrentLocationFailureType.permissionDenied,
          );
        case geolocator.LocationPermission.deniedForever:
          return const CurrentLocationFailure(
            CurrentLocationFailureType.permissionDeniedForever,
          );
        case geolocator.LocationPermission.unableToDetermine:
          // Web-only, per geolocator's own doc comment on
          // LocationPermission.unableToDetermine — never returned on
          // iOS/Android, the only two platforms this app ships to.
          // Mapped to the generic `unavailable` category rather than a
          // new domain case that would exist solely for a platform this
          // app doesn't target.
          return const CurrentLocationFailure(
            CurrentLocationFailureType.unavailable,
          );
        case geolocator.LocationPermission.whileInUse:
        case geolocator.LocationPermission.always:
          break; // Proceed to acquisition below.
      }

      final position = await _gateway.getCurrentPosition(
        locationSettings: const geolocator.LocationSettings(
          accuracy: _accuracy,
        ),
      );
      // GeoCoordinate's own [-90,90]/[-180,180] validation (N1, unchanged)
      // runs here for free — an out-of-range plugin value throws
      // ArgumentError, caught by the generic clause below and mapped to
      // `unavailable` rather than ever reaching CurrentLocationSuccess
      // with a corrupt coordinate.
      return CurrentLocationSuccess(
        GeoCoordinate(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on geolocator.LocationServiceDisabledException {
      // Services can also be disabled in the window between the
      // isLocationServiceEnabled() check above and the actual
      // acquisition call — geolocator itself throws this exception for
      // that race, so it's handled here too, not only via the upfront
      // check.
      return const CurrentLocationFailure(
        CurrentLocationFailureType.servicesDisabled,
      );
    } on geolocator.PermissionDeniedException {
      return const CurrentLocationFailure(
        CurrentLocationFailureType.permissionDenied,
      );
    } on TimeoutException {
      return const CurrentLocationFailure(
        CurrentLocationFailureType.unavailable,
      );
    } catch (_) {
      // Any other unexpected plugin/platform failure — including a
      // GeoCoordinate ArgumentError for an out-of-range plugin value —
      // never rethrown, per CurrentLocationProvider's own contract
      // ("never throws for an expected failure mode"). An exception
      // generic enough to reach this clause is, by definition, not one
      // of the specific categories above, so `unavailable` — not a more
      // specific one — is the only honest mapping; no raw exception
      // detail is ever exposed past this boundary.
      return const CurrentLocationFailure(
        CurrentLocationFailureType.unavailable,
      );
    }
  }

  // Events V2 Near Me Phase N2.4 — [LocationSettingsOpener]'s own
  // "never throws" contract (`location_settings_opener.dart`) held here
  // defensively: `Geolocator.openAppSettings`/`openLocationSettings`
  // already return `bool` rather than throwing per their own doc
  // comments, but an unexpected platform channel failure is still caught
  // and mapped to `false` rather than ever propagating past this
  // boundary (task §18 — "do not crash", "no new domain failure state
  // for failure to open Settings").
  @override
  Future<bool> openAppSettings() async {
    try {
      return await _gateway.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await _gateway.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
