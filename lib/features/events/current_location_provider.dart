import '../../models/geo_coordinate.dart';

/// Events V2 Near Me Phase N1 — the seam a future N2 phase provides a
/// real adapter for (backed by the `geolocator` package, not added in
/// this phase). This interface itself has ZERO dependency on
/// `geolocator`, on any native location API, or on any concrete
/// permission-check implementation — only [CurrentLocationProvider] is
/// public N1 surface; nothing in this codebase implements it with real
/// device access yet, and nothing calls it from production code yet
/// either. A future concrete adapter (N2) implements this interface by
/// wrapping `geolocator`'s own permission + position APIs and mapping
/// its results onto [CurrentLocationResult]/[CurrentLocationFailureType]
/// — those OS/package-specific details never leak past that one adapter.
///
/// One-shot only, by design (Near Me Location Architecture Audit's own
/// "No Location Caching"/"No Continuous Tracking" sections) — this
/// interface has no `Stream`-returning method, no `watchPosition`
/// equivalent, and is not expected to ever grow one for this feature.
abstract interface class CurrentLocationProvider {
  /// Resolves the device's current location once. Never throws for an
  /// expected failure mode (permission denied, services disabled,
  /// resolution timeout/unavailable) — those are represented as a
  /// [CurrentLocationFailure] result instead, so a caller can exhaustively
  /// `switch` over [CurrentLocationResult] without a try/catch. Should
  /// request coarse/reduced accuracy only when a real adapter exists (see
  /// the Near Me Location Architecture Audit's "Battery/Performance"
  /// section) — this interface intentionally has no accuracy parameter,
  /// since city/region-level discovery has exactly one accuracy need, not
  /// a caller-configurable one.
  Future<CurrentLocationResult> getCurrentLocation();
}

/// The outcome of one [CurrentLocationProvider.getCurrentLocation] call —
/// a closed, exhaustively-matchable set of exactly two shapes. Sealed
/// (mirrors this codebase's own established pattern, e.g.
/// `lib/features/map/models/map_pin.dart`'s sealed `MapPin`), so any
/// future consumer's `switch` is a compile error if a new case is ever
/// added without being handled.
sealed class CurrentLocationResult {
  const CurrentLocationResult();
}

/// Location resolved successfully.
class CurrentLocationSuccess extends CurrentLocationResult {
  final GeoCoordinate coordinate;
  const CurrentLocationSuccess(this.coordinate);

  @override
  bool operator ==(Object other) =>
      other is CurrentLocationSuccess && other.coordinate == coordinate;

  @override
  int get hashCode => coordinate.hashCode;
}

/// Location could not be resolved — [type] is the minimal, OS-agnostic
/// reason a future UI needs to distinguish, never a raw `geolocator`
/// exception, error code, or platform-specific string (Near Me Location
/// Architecture Audit §27's own "do not create 20 error cases... do not
/// expose geolocator-specific enum values").
class CurrentLocationFailure extends CurrentLocationResult {
  final CurrentLocationFailureType type;
  const CurrentLocationFailure(this.type);

  @override
  bool operator ==(Object other) =>
      other is CurrentLocationFailure && other.type == type;

  @override
  int get hashCode => type.hashCode;
}

/// The minimal set of distinct failure reasons a future N2 UI needs to
/// show different recovery copy for (Near Me Location Architecture
/// Audit's own "Permission UX"/"Failure / Loading" sections) — kept
/// deliberately small; every value here maps to a genuinely different
/// user-facing recovery action, not a technical implementation detail.
enum CurrentLocationFailureType {
  /// The user has not granted permission yet, or declined once — a
  /// future request may still show the system prompt again.
  permissionDenied,

  /// The user has permanently declined (platform-specific semantics:
  /// e.g. iOS's own single-decline-then-Settings-only model, Android's
  /// "don't ask again") — only "open Settings" can recover this, never
  /// another in-app prompt.
  permissionDeniedForever,

  /// Location services are off device-wide — distinct from a per-app
  /// permission denial; no permission dialog would even fire in this
  /// state (Near Me Location Architecture Audit §21's own explicit
  /// requirement not to conflate the two).
  servicesDisabled,

  /// Permission was granted and services are on, but a position could
  /// not be resolved (timeout, no signal, transient platform failure).
  unavailable,
}
