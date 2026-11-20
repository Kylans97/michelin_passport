#!/usr/bin/env python3
"""Takes the Americas wine regions into the outline build, from the
research in <scratch>/americas/{us,sa}.

    <venv with shapely>/bin/python -I import_americas.py <scratch dir>

USA: TTB's own AVA polygons (AVA Map Explorer feature service, CC0, last
edited 2026-10-27; the written 27 CFR part 9 description takes
precedence), and for Sonoma County the US Census county boundary
(shoreline-clipped, 500k) - a county name is a legal US wine appellation
(27 CFR 4.25(a)(1)(iv)); no AVA or union of AVAs matches it.
Argentina and Chile: official administrative units (IGN departamentos,
Chile's comunas) named by the INV resolutions and Decreto 464.

The source polygons are stored in geometry/ simplified to ~100 m, which
is ten times finer than the ~1 km outline built from them, so nothing
the globe shows changes; it keeps the repo light (Willamette Valley
alone is 78,508 vertices at source).
"""

import json
import pathlib
import shutil
import sys

from shapely.geometry import mapping, shape

HERE = pathlib.Path(__file__).resolve().parent
STORE_TOLERANCE_DEG = 0.001  # ~100 m


def main(scratch):
    scratch = pathlib.Path(scratch) / 'americas'
    for part, name in (('us', 'us_units'), ('sa', 'sa_units')):
        src = scratch / part / f'{name}.geojson'
        if not src.exists():
            print(f'{part}: not there yet, skipped')
            continue
        features = []
        for f in json.load(open(src, encoding='utf-8'))['features']:
            geom = shape(f['geometry']).buffer(0).simplify(
                STORE_TOLERANCE_DEG, preserve_topology=True)
            features.append({'type': 'Feature', 'properties': f['properties'],
                             'geometry': json.loads(json.dumps(
                                 mapping(geom), default=list))})
        (HERE / 'geometry' / f'{name}.geojson').write_text(
            json.dumps({'type': 'FeatureCollection', 'features': features},
                       separators=(',', ':')), encoding='utf-8')
        for path in sorted((scratch / part).glob('wr_*')):
            if path.suffix in ('.csv', '.md'):
                shutil.copy(path, HERE / 'communes' / path.name)
        print(f'{part}: {len(features)} units, '
              f'{(HERE / "geometry" / f"{name}.geojson").stat().st_size} bytes')


if __name__ == '__main__':
    main(sys.argv[1])
