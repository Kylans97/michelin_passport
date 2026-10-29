import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

const globeOutlinesAsset = 'assets/globe/countries.bin';

/// One country's outline rings as earth-frame unit vectors — x, y, z
/// triples in a [Float32List], so the painter rotates them with a few
/// multiplies per point per frame instead of re-running trigonometry.
/// [code] is ISO 3166-1 alpha-2, matching `countries.country_code`; `--`
/// for the handful of Natural Earth features with no code (they draw, but
/// never tint).
class GlobeCountry {
  final String code;
  final List<Float32List> rings;

  /// Unit vector at the middle of the country and the angular radius (in
  /// radians) that contains every ring point — lets the painter skip a
  /// country that sits wholly on the far side without projecting it.
  final double centerX;
  final double centerY;
  final double centerZ;
  final double radius;

  const GlobeCountry({
    required this.code,
    required this.rings,
    required this.centerX,
    required this.centerY,
    required this.centerZ,
    required this.radius,
  });
}

/// Natural Earth 1:50m country outlines, decoded from the bundled
/// [globeOutlinesAsset] (built by scripts/build_globe_outlines.py — see
/// that script for the format). Bundled rather than fetched so the globe
/// costs no tiles, no egress and no API key, and works fully offline.
class GlobeOutlines {
  final List<GlobeCountry> countries;
  const GlobeOutlines(this.countries);

  static Future<GlobeOutlines>? _cached;

  /// Decoded once per app run; every later My Map visit reuses it.
  static Future<GlobeOutlines> load() => _cached ??= rootBundle
      .load(globeOutlinesAsset)
      .then(
        (data) => GlobeOutlines.decode(
          data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes),
        ),
      );

  static GlobeOutlines decode(ByteData data) {
    if (data.lengthInBytes < 6 ||
        String.fromCharCodes([
              data.getUint8(0),
              data.getUint8(1),
              data.getUint8(2),
              data.getUint8(3),
            ]) !=
            'GLB1') {
      throw const FormatException('Not a GLB1 globe outline asset');
    }
    var offset = 4;
    int u16() {
      final v = data.getUint16(offset, Endian.little);
      offset += 2;
      return v;
    }

    int i16() {
      final v = data.getInt16(offset, Endian.little);
      offset += 2;
      return v;
    }

    final countryCount = u16();
    final countries = <GlobeCountry>[];
    for (var c = 0; c < countryCount; c++) {
      final code = String.fromCharCodes([
        data.getUint8(offset),
        data.getUint8(offset + 1),
      ]);
      offset += 2;
      final ringCount = u16();
      final rings = <Float32List>[];
      var sx = 0.0, sy = 0.0, sz = 0.0;
      for (var r = 0; r < ringCount; r++) {
        final n = u16();
        final ring = Float32List(n * 3);
        for (var i = 0; i < n; i++) {
          final lon = i16() * 180 / 32767 * math.pi / 180;
          final lat = i16() * 90 / 32767 * math.pi / 180;
          final cosLat = math.cos(lat);
          final x = cosLat * math.cos(lon);
          final y = cosLat * math.sin(lon);
          final z = math.sin(lat);
          ring[i * 3] = x;
          ring[i * 3 + 1] = y;
          ring[i * 3 + 2] = z;
          sx += x;
          sy += y;
          sz += z;
        }
        rings.add(ring);
      }
      var len = math.sqrt(sx * sx + sy * sy + sz * sz);
      // A country whose points average to (nearly) zero — impossible for
      // anything smaller than a hemisphere — simply never gets culled.
      final degenerate = len < 1e-9;
      if (degenerate) {
        sx = 1;
        len = 1;
      }
      final cx = sx / len, cy = sy / len, cz = sz / len;
      var minDot = 1.0;
      for (final ring in rings) {
        for (var i = 0; i < ring.length; i += 3) {
          final d = ring[i] * cx + ring[i + 1] * cy + ring[i + 2] * cz;
          if (d < minDot) minDot = d;
        }
      }
      countries.add(
        GlobeCountry(
          code: code,
          rings: rings,
          centerX: cx,
          centerY: cy,
          centerZ: cz,
          radius: degenerate ? math.pi : math.acos(minDot.clamp(-1.0, 1.0)),
        ),
      );
    }
    return GlobeOutlines(countries);
  }
}
