"""Builds assets/globe/countries.bin — the country outlines My Map's globe
draws — from Natural Earth's 1:50m Admin 0 countries.

Natural Earth is public domain (https://www.naturalearthdata.com/about/terms-of-use/).
Source used for the committed asset, pinned to a release tag:
https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_50m_admin_0_countries.geojson

Usage:
    python3 scripts/build_globe_outlines.py ne_50m_admin_0_countries.geojson

Format (little endian), read by lib/features/map/globe/globe_outlines.dart:
    b'GLB1'
    u16 country count
    per country:
        2 bytes  ISO 3166-1 alpha-2 code (ISO_A2_EH, else ISO_A2; b'--' when
                 Natural Earth has none — those outlines draw but never tint)
        u16      ring count (outer rings and holes; the reader fills with
                 even-odd, so the distinction needs no flag)
        per ring:
            u16  point count
            per point: i16 lon * 32767/180, i16 lat * 32767/90

Rings are simplified with Douglas-Peucker at TOLERANCE degrees (about 2 km),
below what the globe's maximum zoom can show.
"""

import json
import struct
import sys
from pathlib import Path

TOLERANCE = 0.02
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'globe' / 'countries.bin'


def _perp_dist(p, a, b):
    (x, y), (x1, y1), (x2, y2) = p, a, b
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
    return ((x - x1 - t * dx) ** 2 + (y - y1 - t * dy) ** 2) ** 0.5


def simplify(points):
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        start, end = stack.pop()
        best, index = 0.0, -1
        for i in range(start + 1, end):
            d = _perp_dist(points[i], points[start], points[end])
            if d > best:
                best, index = d, i
        if best > TOLERANCE:
            keep[index] = True
            stack.append((start, index))
            stack.append((index, end))
    return [p for p, k in zip(points, keep) if k]


def main(source):
    features = json.loads(Path(source).read_text())['features']
    out = bytearray(b'GLB1')
    out += struct.pack('<H', len(features))
    total = 0
    for feature in features:
        props = feature['properties']
        code = props.get('ISO_A2_EH')
        if code in (None, '-99'):
            code = props.get('ISO_A2')
        if code in (None, '-99') or len(code) != 2:
            code = '--'
        geometry = feature['geometry']
        polygons = (
            geometry['coordinates']
            if geometry['type'] == 'MultiPolygon'
            else [geometry['coordinates']]
        )
        rings = []
        for polygon in polygons:
            for ring in polygon:
                simplified = simplify([tuple(p[:2]) for p in ring])
                # A ring that collapses to fewer than 4 points (closing point
                # included) is a speck no zoom level can show.
                if len(simplified) >= 4:
                    rings.append(simplified)
        out += code.encode('ascii')
        out += struct.pack('<H', len(rings))
        for ring in rings:
            out += struct.pack('<H', len(ring))
            total += len(ring)
            for lon, lat in ring:
                out += struct.pack(
                    '<hh',
                    round(max(-180, min(180, lon)) * 32767 / 180),
                    round(max(-90, min(90, lat)) * 32767 / 90),
                )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(bytes(out))
    print(f'{len(features)} countries, {total} points, {len(out)} bytes -> {OUT}')


if __name__ == '__main__':
    main(sys.argv[1])
