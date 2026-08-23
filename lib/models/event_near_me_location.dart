import 'geo_coordinate.dart';

/// Events V2 Near Me Phase N1 — the V1 default/only radius. **Provisional
/// product decision, not an architectural constraint**: 100 km was chosen
/// (see EVENTS_NEAR_ME_LOCATION_ARCHITECTURE_AUDIT.md's "Near Me
/// Definition"/"Radius Model" sections) because Chasing Stars Events are
/// rare and destination-worthy — a typical "5 km nearby restaurant"
/// radius would be wrong for this catalogue. Named and centralized here
/// specifically so this single number is never scattered as a literal
/// `100`/`100.0` across call sites — changing the product decision later
/// means changing this one constant, not hunting for every use.
const double defaultEventNearMeRadiusKm = 100.0;

/// A resolved "Near me" location context — already-resolved domain
/// state, deliberately carrying NO permission/provider concerns (see
/// `current_location_provider.dart` for where acquiring [coordinate] in
/// the first place is modeled). Immutable, value-comparable.
///
/// V1 does not expose [radiusKm] as a user control — [defaultEventNearMeRadiusKm]
/// is used unless a caller (e.g. a future test, or a future V2 UI
/// decision) explicitly overrides it; this class still validates and
/// stores whatever radius it's given rather than hard-coding the
/// default internally, so the domain type itself never has to change if
/// that product decision changes later.
class EventNearMeLocation {
  final GeoCoordinate coordinate;
  final double radiusKm;

  EventNearMeLocation({
    required this.coordinate,
    this.radiusKm = defaultEventNearMeRadiusKm,
  }) {
    if (radiusKm <= 0) {
      throw ArgumentError.value(radiusKm, 'radiusKm', 'must be positive');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is EventNearMeLocation &&
      other.coordinate == coordinate &&
      other.radiusKm == radiusKm;

  @override
  int get hashCode => Object.hash(coordinate, radiusKm);

  @override
  String toString() => 'EventNearMeLocation($coordinate, ${radiusKm}km)';
}
