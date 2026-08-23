import 'package:latlong2/latlong.dart';
import '../../models/event.dart';
import '../../models/event_near_me_location.dart';
import '../../models/geo_coordinate.dart';

/// Events V2 Near Me Phase N1 — the pure, Supabase-free, GPS-free core of
/// Near-me inclusion. Mirrors `event_discovery_filtering.dart`'s own
/// split (pure inclusion logic, kept entirely separate from however the
/// two coordinates involved were actually obtained) — nothing in this
/// file ever reads a device position or a network response.
///
/// Reuses `latlong2` (already a dependency — the exact package `My Map`
/// already uses for tile rendering, see `lib/features/map/`) rather than
/// hand-rolling a second spherical-distance formula in this codebase.
/// `latlong2`'s own `LatLng`/`Distance`/`LengthUnit` types are used only
/// internally here and never appear in this function's own signature —
/// every caller in this codebase speaks [GeoCoordinate], never a
/// `latlong2` type directly, so a future change of distance-calculation
/// package would only ever touch this one file.
const _distanceHaversine = DistanceHaversine(roundResult: false);

/// Great-circle distance between [a] and [b], in kilometers, via the
/// Haversine formula. Deterministic, no device/network dependency.
/// `roundResult: false` avoids `latlong2`'s own default meter-rounding —
/// irrelevant at a 100km discovery radius, but keeps this a genuine
/// continuous distance rather than one with an arbitrary 1-meter step
/// baked in.
double eventGeoDistanceKm(GeoCoordinate a, GeoCoordinate b) {
  return _distanceHaversine.as(
    LengthUnit.Kilometer,
    LatLng(a.latitude, a.longitude),
    LatLng(b.latitude, b.longitude),
  );
}

/// Whether [event] qualifies under [location] — the sole Near-me
/// inclusion rule (Near Me Location Architecture Audit §9/§16/§19/§20):
///
/// - [Event.latitude]/[Event.longitude] both present: qualifies iff the
///   great-circle distance to [EventNearMeLocation.coordinate] is less
///   than or equal to [EventNearMeLocation.radiusKm] (an exact-boundary
///   distance counts as included, never excluded).
/// - Either coordinate `null`: never qualifies. No fallback to city or
///   country, no venue-proxy coordinate, no participant coordinate —
///   this project has an explicit, hard-won discipline of never
///   fabricating an Event's location (see the Near Me Location
///   Architecture Audit's "Production Coordinate Coverage" section), and
///   silently substituting a city-centre guess here would violate it.
/// - Purely geometric — an Event's `country_code` is never consulted.
///   A Belgian Event 40km from a Dutch coordinate qualifies exactly like
///   a Dutch one at the same distance; Near Me is never silently ANDed
///   with an inferred country.
bool eventQualifiesForNearMe(Event event, EventNearMeLocation location) {
  final latitude = event.latitude;
  final longitude = event.longitude;
  if (latitude == null || longitude == null) return false;

  final eventCoordinate = GeoCoordinate(
    latitude: latitude,
    longitude: longitude,
  );
  return eventGeoDistanceKm(location.coordinate, eventCoordinate) <=
      location.radiusKm;
}
