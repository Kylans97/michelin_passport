#!/usr/bin/env python3
"""Takes the nine Dutch protected wine regions (BOB) into the outline
build, from the research in <src>/communes_nl and <src>/dl_nl.

    python3 -I import_nl_regions.py <scratch dir>

The Dutch zones are small, so a whole municipality would often misstate
them badly. Where an official unit finer than a municipality matches the
product dossier's own text, it is used instead (all PDOK open data):
- BAG woonplaats Vijlen (Kadaster, CC0) for BOB Vijlen;
- CBS buurt "Verspreide huizen Oolde" (Wijk- en Buurtkaart 2024,
  CC BY 4.0) for BOB Oolde;
- CBS wijken 01-04 of Beekdaelen (= former gemeente Nuth, merged 2019)
  for Nuth inside BOB Mergelland.
These are written to geometry/nl_finer_units.geojson, keyed by unit_id.

NOT_DRAWN: three zones no official unit can draw without misstating
them. They are published with a point and no outline; their named
municipalities go to communes_reference/ for the record only.
"""

import csv
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
COLUMNS = ['region_code', 'gisco_id', 'official_name', 'lau_name',
           'province', 'partial', 'source_url']

REGIONS = {
    'achterhoek-winterswijk': 'wr_0012',
    'maasvallei-limburg': 'wr_0013',
    'mergelland': 'wr_0014',
    'oolde': 'wr_0015',
    'rivierenland': 'wr_0016',
    'schouwen-duiveland': 'wr_0017',
    'twente': 'wr_0018',
    'vijlen': 'wr_0019',
    'voerendaalse-bergen': 'wr_0020',
}

NOT_DRAWN = {
    'wr_0013': 'Maasvallei Limburg is a strip "tot op de middenterrassen" '
               'on both Maas banks, 155 km², fixed by roads and canals; its '
               'eleven municipalities are 5-7x that.',
    'wr_0016': 'Rivierenland is 5 km either side of the river centrelines, '
               'clipped at borders; the 13 municipalities the dossier names '
               'are only part of it, and no official geometry exists.',
    'wr_0020': 'Voerendaalse Bergen is six named slopes, about 900 ha; the '
               'municipality of Voerendaal is 3.5x that.',
}

FINER = [
    ('dl_nl/vijlen_bag_woonplaats_1431.geojson', 'identificatie', 'NL_WP'),
    ('dl_nl/oolde_cbs_buurt_BU02620206.geojson', 'buurtcode', 'NL_'),
    ('dl_nl/mergelland_nuth_cbs_wijken_GM1954_01-04.geojson', 'wijkcode',
     'NL_'),
]


def unit_key(row):
    kind, uid = row['unit_type'], row['unit_id']
    if kind == 'lau':
        return uid
    if kind == 'woonplaats':
        return 'NL_WP' + uid
    return 'NL_' + uid  # buurt / wijk codes already carry BU / WK


def main(src):
    src = pathlib.Path(src)
    features = []
    for path, prop, prefix in FINER:
        for f in json.load(open(src / path, encoding='utf-8'))['features']:
            f['properties'] = {'unit_id': prefix + str(f['properties'][prop])}
            features.append(f)
    (HERE / 'geometry').mkdir(exist_ok=True)
    (HERE / 'geometry' / 'nl_finer_units.geojson').write_text(
        json.dumps({'type': 'FeatureCollection', 'features': features}),
        encoding='utf-8')

    (HERE / 'communes_reference').mkdir(exist_ok=True)
    for slug, code in REGIONS.items():
        rows = list(csv.DictReader(
            open(src / 'communes_nl' / f'{slug}.csv', encoding='utf-8')))
        out = [{
            'region_code': code,
            'gisco_id': unit_key(r),
            'official_name': r['unit_name'],
            'lau_name': r['unit_name'],
            'province': '',
            'partial': '' if r.get('partial', '').strip().lower() in
                       ('', 'no') else 'yes: see notes',
            'source_url': r['source_url'],
        } for r in rows]
        folder = 'communes_reference' if code in NOT_DRAWN else 'communes'
        with open(HERE / folder / f'{code}.csv', 'w', newline='',
                  encoding='utf-8') as f:
            w = csv.DictWriter(f, COLUMNS)
            w.writeheader()
            w.writerows(out)
        notes = (src / 'communes_nl' / f'{slug}_notes.md').read_text(
            encoding='utf-8')
        if code in NOT_DRAWN:
            notes = f'**Not drawn:** {NOT_DRAWN[code]}\n\n' + notes
        (HERE / folder / f'{code}_notes.md').write_text(notes,
                                                         encoding='utf-8')
        print(f'{code} {slug}: {len(out)} units -> {folder}/')


if __name__ == '__main__':
    main(sys.argv[1])
