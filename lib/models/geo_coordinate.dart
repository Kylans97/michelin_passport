/// Events V2 Near Me Phase N1 — a plain, immutable geographic point.
/// Deliberately generic (not `EventCoordinate`/`EventLocation`): a
/// latitude/longitude pair is not an Events-specific concept, and this
/// codebase already has multiple independent "a venue/event has a
/// latitude/longitude" call sites ([Event.latitude]/[Event.longitude],
/// `MapRepository`'s restaurant/hotel coordinate columns) — [GeoCoordinate]
/// is intentionally the one shared value shape a future non-Events
/// feature could reuse without inventing a second one, while staying
/// small enough not to be "over-generalized" (no altitude, no accuracy,
/// no timestamp, no address/city/country — see the class doc below for
/// exactly what is deliberately excluded).
///
/// Carries no identity, no address/city/country, no timestamp, no
/// accuracy/precision metadata, and no persistence behavior (no
/// `toJson`/`fromJson` — see EVENTS_NEAR_ME_PHASE_N1_PRE_FINAL.md's
/// Privacy section for why this is a deliberate omission, not an
/// oversight: a resolved current-location coordinate is meant to live in
/// transient application state only).
class GeoCoordinate {
  final double latitude;
  final double longitude;

  /// Throws [ArgumentError] for an out-of-range value rather than
  /// silently clamping or accepting it — a coordinate this far out of
  /// range can only come from a genuine caller bug (e.g. a provider
  /// adapter that swapped latitude/longitude, or passed a raw device
  /// reading through unchecked), never a legitimate real-world GPS/
  /// catalogue value, so failing loudly at construction is safer than
  /// letting a corrupt value silently propagate into a distance
  /// calculation.
  GeoCoordinate({required this.latitude, required this.longitude}) {
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'must be between -90 and 90',
      );
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'must be between -180 and 180',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GeoCoordinate &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoCoordinate($latitude, $longitude)';
}
