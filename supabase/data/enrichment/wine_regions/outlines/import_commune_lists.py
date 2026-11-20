#!/usr/bin/env python3
"""Takes the researched commune lists (Spain, Portugal, Germany, Italy)
into communes/, in the one shape build_wine_region_outlines.py reads.

France comes from INAO's own open data through fr_communes.py instead.

    python3 -I import_commune_lists.py <dir with wr_NNNN.csv>

Two things happen here and nowhere else:
- `partial` is normalised: empty when the unit is wholly in the zone,
  otherwise the document's own wording.
- LEFT_OUT: a unit the official text includes only as one small enclave
  or one village is left out of the drawing rather than drawn whole,
  which would misstate the region. Each is named with its reason, and
  listed again in README.md.
"""

import csv
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
COLUMNS = ['region_code', 'gisco_id', 'official_name', 'lau_name',
           'province', 'partial', 'source_url']

LEFT_OUT = {
    'ES_09219': 'Miranda de Ebro: only the El Ternero enclave is in the '
                'Rioja zone; the municipality drawn whole would add ~100 km² '
                'of Burgos that is not.',
    'ES_42043': 'Burgo de Osma-Ciudad de Osma: only the village of '
                'Alcubilla del Marqués is in the Ribera del Duero zone.',
}


def main(src):
    for path in sorted(pathlib.Path(src).glob('wr_*.csv')):
        if path.stem <= 'wr_0005':
            continue  # France: fr_communes.py
        rows = list(csv.DictReader(open(path, encoding='utf-8')))
        kept, left = [], []
        for r in rows:
            if r['gisco_id'] in LEFT_OUT:
                left.append(r['gisco_id'])
                continue
            partial = r['partial'].strip()
            if partial.lower() in ('', 'no', 'false'):
                partial = ''
            kept.append({**{k: r[k] for k in COLUMNS}, 'partial': partial})
        with open(HERE / 'communes' / path.name, 'w', newline='',
                  encoding='utf-8') as f:
            w = csv.DictWriter(f, COLUMNS)
            w.writeheader()
            w.writerows(kept)
        print(f'{path.stem}: {len(kept)} kept, left out {left or "none"}')


if __name__ == '__main__':
    main(sys.argv[1])
