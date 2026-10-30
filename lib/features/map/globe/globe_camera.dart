import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Where the globe is looking: the point at the middle of the disc, in
/// degrees, and how far in it is zoomed (1 = the whole globe fits).
/// Immutable and Flutter-widget-free, so projection, fitting and
/// clustering stay unit-testable without pumping a widget.
class GlobeCamera {
  static const double minZoom = 1;
  static const double maxZoom = 60;

  /// Latitude is kept off the poles so a drag never flips the globe over.
  static const double maxLatitude = 80;

  final double latitude;
  final double longitude;
  final double zoom;

  const GlobeCamera({
    required this.latitude,
    required this.longitude,
    this.zoom = minZoom,
  });

  /// Normalises longitude into [-180, 180) and clamps latitude and zoom.
  GlobeCamera copyWith({double? latitude, double? longitude, double? zoom}) =>
      GlobeCamera(
        latitude: (latitude ?? this.latitude).clamp(-maxLatitude, maxLatitude),
        longitude: wrapLongitude(longitude ?? this.longitude),
        zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom),
      );

  /// Interpolates towards [to] along the shorter way round in longitude.
  /// Zoom interpolates in log space so a fly-in feels evenly paced.
  GlobeCamera lerpTo(GlobeCamera to, double t) {
    final dLon = wrapLongitude(to.longitude - longitude);
    return GlobeCamera(
      latitude: latitude + (to.latitude - latitude) * t,
      longitude: wrapLongitude(longitude + dLon * t),
      zoom: math.exp(math.log(zoom) + (math.log(to.zoom) - math.log(zoom)) * t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlobeCamera &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(latitude, longitude, zoom);

  @override
  String toString() => 'GlobeCamera($latitude, $longitude, ×$zoom)';
}

double wrapLongitude(double lon) => (lon + 180) % 360 - 180;

/// The globe's radius at zoom 1 for a viewport — leaves a margin for the
/// atmosphere glow.
double globeBaseRadius(Size size) => math.min(size.width, size.height) * 0.42;

/// An orthographic projection of [camera] into a viewport of [size]: the
/// globe is centred, the camera's point faces the viewer.
class GlobeProjection {
  final GlobeCamera camera;
  final Size size;
  final Offset center;
  final double radius;
  final double _sinLat0, _cosLat0, _sinLon0, _cosLon0;

  GlobeProjection(this.camera, this.size)
    : center = Offset(size.width / 2, size.height / 2),
      radius = globeBaseRadius(size) * camera.zoom,
      _sinLat0 = math.sin(camera.latitude * math.pi / 180),
      _cosLat0 = math.cos(camera.latitude * math.pi / 180),
      _sinLon0 = math.sin(camera.longitude * math.pi / 180),
      _cosLon0 = math.cos(camera.longitude * math.pi / 180);

  /// Rotates an earth-frame unit vector into view space. Returns
  /// (x right, y up, z towards the viewer); z > 0 is the visible side.
  (double, double, double) rotate(double ex, double ey, double ez) {
    final c = ex * _cosLon0 + ey * _sinLon0;
    return (
      ey * _cosLon0 - ex * _sinLon0,
      _cosLat0 * ez - _sinLat0 * c,
      _sinLat0 * ez + _cosLat0 * c,
    );
  }

  /// Screen position and depth of a latitude/longitude in degrees.
  (Offset, double) project(double latitude, double longitude) {
    final (ex, ey, ez) = unitVector(latitude, longitude);
    final (x, y, z) = rotate(ex, ey, ez);
    return (toScreen(x, y), z);
  }

  Offset toScreen(double x, double y) =>
      Offset(center.dx + x * radius, center.dy - y * radius);
}

(double, double, double) unitVector(double latitude, double longitude) {
  final lat = latitude * math.pi / 180;
  final lon = longitude * math.pi / 180;
  final cosLat = math.cos(lat);
  return (cosLat * math.cos(lon), cosLat * math.sin(lon), math.sin(lat));
}

/// Angle in degrees between two points on the sphere.
double angularDistance(double lat1, double lon1, double lat2, double lon2) {
  final (ax, ay, az) = unitVector(lat1, lon1);
  final (bx, by, bz) = unitVector(lat2, lon2);
  final dot = (ax * bx + ay * by + az * bz).clamp(-1.0, 1.0);
  return math.acos(dot) * 180 / math.pi;
}

/// The camera that frames every point: centred on their spherical mean,
/// zoomed so the farthest one sits comfortably inside the disc. A single
/// point (or a tight cluster) gets [singlePointZoom]; points spread over
/// more than a hemisphere get the whole globe. [fallback] is used when
/// there are no points, or when they average out to no direction at all
/// (spread evenly round the world).
GlobeCamera fitGlobeCamera(
  List<(double, double)> points, {
  required GlobeCamera fallback,
  double singlePointZoom = 6,
}) {
  if (points.isEmpty) return fallback.copyWith(zoom: GlobeCamera.minZoom);
  var sx = 0.0, sy = 0.0, sz = 0.0;
  for (final (lat, lon) in points) {
    final (x, y, z) = unitVector(lat, lon);
    sx += x;
    sy += y;
    sz += z;
  }
  final len = math.sqrt(sx * sx + sy * sy + sz * sz);
  if (len < 1e-6 * points.length) {
    return fallback.copyWith(zoom: GlobeCamera.minZoom);
  }
  final lat = math.asin((sz / len).clamp(-1.0, 1.0)) * 180 / math.pi;
  final lon = math.atan2(sy, sx) * 180 / math.pi;
  var spread = 0.0;
  for (final (pLat, pLon) in points) {
    spread = math.max(spread, angularDistance(lat, lon, pLat, pLon));
  }
  final double zoom;
  if (spread >= 70) {
    zoom = GlobeCamera.minZoom;
  } else {
    // A point `spread` degrees from the middle lands at radius·sin(spread)
    // from the disc's centre; keep that within ~85% of the zoom-1 radius.
    final sinSpread = math.sin(spread * math.pi / 180);
    zoom = sinSpread < 1e-6 ? singlePointZoom : 0.85 / sinSpread;
  }
  return GlobeCamera(
    latitude: lat,
    longitude: lon,
  ).copyWith(zoom: math.min(zoom, singlePointZoom));
}

/// One marker on screen: either a single item or several that sit too
/// close together to tap apart at the current zoom.
class GlobeCluster<T> {
  final List<T> members;
  final Offset position;

  /// 0–1 — markers fade out as they near the globe's edge, rather than
  /// popping out of existence as they cross it.
  final double opacity;

  const GlobeCluster(this.members, this.position, this.opacity);
}

/// Projects [items] and greedily merges the visible ones that fall within
/// [mergeDistance] pixels of a cluster's first member. Items on the far
/// side of the globe are left out entirely. Order is preserved, so the same
/// view always produces the same clusters.
List<GlobeCluster<T>> clusterOnGlobe<T>(
  List<T> items, {
  required GlobeProjection projection,
  required double Function(T) latitude,
  required double Function(T) longitude,
  double mergeDistance = 30,
}) {
  final anchors = <Offset>[];
  final members = <List<T>>[];
  final sums = <Offset>[];
  final depths = <double>[];
  for (final item in items) {
    final (position, z) = projection.project(latitude(item), longitude(item));
    if (z <= _hideDepth) continue;
    var merged = false;
    for (var i = 0; i < anchors.length; i++) {
      if ((anchors[i] - position).distance < mergeDistance) {
        members[i].add(item);
        sums[i] += position;
        depths[i] = math.max(depths[i], z);
        merged = true;
        break;
      }
    }
    if (!merged) {
      anchors.add(position);
      members.add([item]);
      sums.add(position);
      depths.add(z);
    }
  }
  return [
    for (var i = 0; i < anchors.length; i++)
      GlobeCluster(
        members[i],
        sums[i] / members[i].length.toDouble(),
        ((depths[i] - _hideDepth) / (_fullDepth - _hideDepth)).clamp(0.0, 1.0),
      ),
  ];
}

const _hideDepth = 0.06;
const _fullDepth = 0.25;
