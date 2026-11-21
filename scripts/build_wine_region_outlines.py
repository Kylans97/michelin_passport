#!/usr/bin/env python3
"""Builds the wine regions' outlines from their official commune lists.

A region's outline is the union of the municipalities its official
specification lists (supabase/data/enrichment/wine_regions/outlines/
communes/<region_code>.csv, one row per municipality, with its source),
drawn from the EU's official municipality boundaries: Eurostat GISCO
LAU 2024, 1:1M (© EuroGeographics for the administrative boundaries).
Nothing is traced by hand and nothing is matched across countries.

    python3 -m venv /tmp/geo && /tmp/geo/bin/pip install shapely
    curl -o lau2024.geojson https://gisco-services.ec.europa.eu/distribution/v2/lau/geojson/LAU_RG_01M_2024_4326.geojson
    /tmp/geo/bin/python scripts/build_wine_region_outlines.py lau2024.geojson

Units finer than a municipality (BAG woonplaatsen, CBS buurten and
wijken for the Dutch zones) come from outlines/geometry/*.geojson.

Writes, next to the commune lists:
  outlines.json            {region_code: [[ring, ...], ...]} per polygon,
                           rings as [lng, lat] pairs, outer ring first
  wine_region_outlines.sql the updates that load them into wine_regions

The outline is simplified for a globe, not for a legal boundary: gaps
and notches under ~1.5 km closed, about 1 km of tolerance (both scaled
down for a zone under ~40 km across), parts under
4 km² dropped, coordinates to 3 decimals
(about 100 m). It shows where a region is, not which side of a road a
vineyard falls on.
"""

import csv
import json
import pathlib
import sys

from shapely.geometry import MultiPolygon, Polygon, shape
from shapely.ops import unary_union

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'supabase/data/enrichment/wine_regions/outlines'
TOLERANCE_DEG = 0.012  # ~1 km at these latitudes
CLOSE_DEG = 0.015  # gaps and notches under ~1.5 km close up
MIN_PART_KM2 = 4.0
# Only an overlap smaller than this share of the smaller region is a
# simplification sliver. Anything larger is real: one region inside another
# (Vijlen in Mergelland) or a legal overlap (the Beaujolais crus are also
# inside AOC Bourgogne), and both regions keep it.
SLIVER_SHARE = 0.06
LAU_SOURCE = 'Eurostat GISCO LAU 2024 (© EuroGeographics)'
KM2_PER_DEG2_AT_45N = 111.32 * 111.32 * 0.707


def main(lau_path):
    regions = {}
    for path in sorted((OUT / 'communes').glob('wr_*.csv')):
        rows = list(csv.DictReader(open(path, encoding='utf-8')))
        # One row per name in the official text; several can fall in one
        # municipality (Portugal's 2013 unions, Perl's Ortsteile).
        regions[path.stem] = list({r['gisco_id']: r for r in rows}.values())
    wanted = {r['gisco_id'] for rows in regions.values() for r in rows}

    geoms = {}
    # Official units finer than a municipality (the Dutch zones), keyed
    # by unit_id: see outlines/import_nl_regions.py.
    unit_sources = {}
    for path in sorted((OUT / 'geometry').glob('*.geojson')):
        for f in json.load(open(path, encoding='utf-8'))['features']:
            gid = f['properties']['unit_id']
            if gid in wanted:
                geoms[gid] = shape(f['geometry']).buffer(0)
                unit_sources[gid] = _dataset(f['properties'].get('source'),
                                             path.stem)
    for f in json.load(open(lau_path, encoding='utf-8'))['features']:
        gid = f['properties']['GISCO_ID']
        if gid in wanted:
            geoms[gid] = shape(f['geometry']).buffer(0)
    missing = sorted(wanted - geoms.keys())
    if missing:
        sys.exit(f'Not in the LAU file: {missing}')

    # 1. Each region on its own: union, close, simplify.
    simple_by_code = {}
    for code, rows in regions.items():
        merged = unary_union([geoms[r['gisco_id']] for r in rows])
        # Close the hairline gaps the 1:1M generalisation leaves between
        # neighbouring municipalities, and the notches under ~1.5 km that
        # read as noise on a globe, then simplify. Grows nothing: what is
        # buffered out is buffered back in.
        # A zone a few km across (Vijlen, Oolde) gets proportionally finer
        # treatment, or it would collapse to a triangle.
        minx, miny, maxx, maxy = merged.bounds
        scale = min(1.0, max(maxx - minx, maxy - miny) / 0.6)
        close, tolerance = CLOSE_DEG * scale, TOLERANCE_DEG * scale
        merged = merged.buffer(close, join_style='round').buffer(
            -close, join_style='round')
        simple_by_code[code] = merged.simplify(
            tolerance, preserve_topology=True).buffer(0)

    # The country of a region: the prefix of its units' ids (FR_, AU_GI_,
    # NZ_TA_, ...).
    country_of = {code: rows[0]['gisco_id'].split('_')[0]
                  for code, rows in regions.items()}

    # 2. Neighbours, simplified separately, overlap in thin slivers along
    # their shared border, which paint darker at close zoom. The later
    # region gives the overlap up, so they meet edge to edge. A larger
    # overlap is real (nesting, or a legal overlap) and is left alone.
    codes = sorted(simple_by_code)
    for i, a in enumerate(codes):
        for b in codes[i + 1:]:
            ga, gb = simple_by_code[a], simple_by_code[b]
            if not ga.intersects(gb):
                continue
            overlap = ga.intersection(gb).area
            # Across a national border an overlap is never a legal one, so
            # it is always a sliver (the Mosel against the Luxembourg
            # Moselle, Brda against Friuli).
            cross_border = country_of[a] != country_of[b]
            if overlap == 0 or (not cross_border and overlap >
                                SLIVER_SHARE * min(ga.area, gb.area)):
                continue
            simple_by_code[b] = gb.difference(ga).buffer(0)

    # 3. Write.
    outlines, sql = {}, []
    for code, rows in regions.items():
        simple = simple_by_code[code]
        parts = simple.geoms if isinstance(simple, MultiPolygon) else [simple]
        polys = []
        for p in parts:
            if not isinstance(p, Polygon):
                continue
            if p.area * KM2_PER_DEG2_AT_45N < MIN_PART_KM2:
                continue
            rings = [p.exterior] + [
                h for h in p.interiors
                if Polygon(h).area * KM2_PER_DEG2_AT_45N >= MIN_PART_KM2
            ]
            polys.append([
                [[round(x, 3), round(y, 3)] for x, y in ring.coords]
                for ring in rings
            ])
        outlines[code] = polys
        points = sum(len(r) for p in polys for r in p)
        sources = sorted({r['source_url'] for r in rows})
        partial = sum(1 for r in rows if r['partial'])
        print(f'{code}: {len(rows)} municipalities ({partial} partial), '
              f'{len(polys)} parts, {points} points')
        datasets = sorted({unit_sources.get(r['gisco_id'], LAU_SOURCE)
                           for r in rows})
        note = (f'Union of {len(rows)} official units from the official '
                f'definition; boundaries: {"; ".join(datasets)}; simplified '
                f'to ~1 km, overlaps with neighbours removed.')
        sql.append(
            'update public.wine_regions set\n'
            f"  outline = '{json.dumps(polys, separators=(',', ':'))}'::jsonb,\n"
            f"  outline_source = {quote(note)},\n"
            f"  outline_source_url = {quote(' ; '.join(sources))}\n"
            f"where region_code = '{code}';\n")

    (OUT / 'outlines.json').write_text(
        json.dumps(outlines, separators=(',', ':')), encoding='utf-8')
    (OUT / 'wine_region_outlines.sql').write_text(
        '-- Generated by scripts/build_wine_region_outlines.py from\n'
        '-- outlines/communes/*.csv. Do not edit by hand: change a commune\n'
        '-- list and run the script again.\n\n' + '\n'.join(sql),
        encoding='utf-8')


def _dataset(source, stem):
    """The dataset a unit comes from, short enough for a note: the part of
    its source before the first parenthesis or comma."""
    if not source:
        return {'nl_finer_units': 'PDOK: Kadaster BAG woonplaatsen and CBS '
                                  'Wijk- en Buurtkaart 2024'}.get(stem, stem)
    for sep in (' (', ', ', ' via '):
        if sep in source:
            source = source.split(sep)[0]
    return source.strip()


def quote(text):
    return "'" + text.replace("'", "''") + "'"


if __name__ == '__main__':
    main(sys.argv[1])
