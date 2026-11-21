#!/usr/bin/env python3
"""Round 5 of more wine regions (product owner, 2026-11-21: "Start round 5:
fill Europe (Italy, Spain, the rest of Germany and Austria, Portugal,
France's southwest and Corsica, Greece's Crete), same method as before").
Research in <scratch>/round5/<group>.

    <venv with shapely>/bin/python -I build_round5_batch.py <scratch> import
    <venv with shapely>/bin/python -I build_round5_batch.py <scratch> sql

Reuses build_world_batch.py; see its docstring for the method. Every
drawn region comes from the municipalities its official text lists, on
Eurostat LAU: the Italian disciplinari (MASAF), the Spanish pliegos, the
German product specifications (Gemarkungen resolved to their Gemeinden
through each Land's ALKIS register), Weingesetz 2009 § 21 and the
Austrian DAC Verordnungen, the Portuguese cadernos and Portarias, INAO's
commune lists and the Cretan PDO specifications. Where a text names the
whole territory (Sardinia for Cannonau, Gipuzkoa and Bizkaia for
Txakoli, the Canary Islands), every unit of it is drawn.
Points, where the text gives a boundary line only or the drawing would
overstate the area: Castelli di Jesi and Valtellina (boundary lines),
Ribeira Sacra (defined by parishes, 19 of 20 municipios only partly in),
Açores (land below 100 m, 150 m on Graciosa).
"""

import importlib.util
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('bw', HERE / 'build_world_batch.py')
bw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bw)


def codes(start, slugs):
    return [(slug, f'wr_{start + i:04d}') for i, slug in enumerate(slugs)]


bw.BATCH = [
    ('IT', 'round5/it', None, codes(160, [
        'abruzzo', 'verdicchio-di-matelica', 'castelli-di-jesi',
        'primitivo-di-manduria', 'sardinia', 'gallura', 'marsala',
        'cerasuolo-di-vittoria', 'trentodoc', 'lugana',
        'lambrusco-di-sorbara', 'lambrusco-grasparossa', 'valtellina',
        'montefalco', 'fiano-di-avellino', 'greco-di-tufo'])),
    ('ES', 'round5/es', None, codes(176, [
        'ribeira_sacra', 'valdeorras', 'ribeiro', 'monterrei',
        'getariako_txakolina', 'bizkaiko_txakolina', 'navarra', 'cigales',
        'somontano', 'calatayud', 'campo_de_borja', 'jumilla', 'montsant',
        'cava', 'islas_canarias'])),
    ('DE', 'round5/de_at', None, codes(191, [
        'mittelrhein', 'saale-unstrut', 'sachsen', 'hessische-bergstrasse',
        'wien', 'carnuntum', 'thermenregion', 'traisental', 'weststeiermark',
        'rosalia', 'mittelburgenland', 'eisenberg'])),
    ('PT', 'round5/pt_fr_gr', None, codes(203, [
        'lisboa', 'tejo', 'acores', 'jurancon', 'madiran', 'bergerac',
        'gaillac', 'irouleguy', 'corsica', 'crete'])),
]
bw.AT = ('AT', 'round5/de_at', None, [])
# Representative points from GeoNames (each research folder's *_points.csv
# says what the point stands for); radius as for the Bekaa Valley.
bw.POINTS = {
    'wr_0162': (43.521, 13.244, 30, 'GeoNames 3175628 Jesi'),
    'wr_0172': (46.183, 9.917, 30, 'GeoNames 3164752 Valtellina (valley)'),
    'wr_0176': None,  # Ribeira Sacra, filled from es_points.csv
    'wr_0205': None,  # Açores, filled from pt_fr_gr_points.csv
}
bw.FIRST_APPELLATION = 508  # after wa_0507
bw.FIRST_GRAPE = 114  # after gr_0113
bw.CATALOGUE = 'grapes_production_20261121_r5.json'
bw.OUTPUT = 'wine_regions_seed_round5_v1.sql'

# Synonyms the research found for grapes already in the catalogue, each
# confirmed by two sources (round5/it notes, round5/pt_fr_gr/
# aliases_to_add.json). Written as catalogue entries in a new_grapes.json,
# which build_world_batch.py turns into alias updates, never new grapes.
ALIASES = {
    'it': {'Grenache': ['Cannonau'], 'Nebbiolo': ['Chiavennasca'],
           'Pinot Blanc': ['Pinot Bianco']},
    'pt_fr_gr': {'Tempranillo': ['Aragonez', 'Aragonês'],
                 'Sangiovese': ['Nielluccio', 'Niellucciu'],
                 'Vermentino': ['Malvoisie de Corse'],
                 'Cabernet Franc': ['Bouchy'],
                 'Muscat Blanc à Petits Grains': ['Muscat of Spina',
                                                  'Moschato Aspro']},
}

# Points written by the research, keyed by slug.
POINT_FILES = {'wr_0176': ('es', 'ribeira_sacra'),
               'wr_0205': ('pt_fr_gr', 'acores')}


def load_points(scratch):
    import csv
    for code, (folder, slug) in POINT_FILES.items():
        rows = csv.DictReader(open(scratch / 'round5' / folder /
                                   f'{folder}_points.csv', encoding='utf-8'))
        row = next(r for r in rows if r['slug'] == slug)
        bw.POINTS[code] = (round(float(row['lat']), 3),
                           round(float(row['lon']), 3), 30,
                           f"GeoNames {row['geonames_id']}")


def add_aliases():
    for folder, aliases in ALIASES.items():
        path = HERE / folder / 'new_grapes.json'
        rows = json.load(open(path, encoding='utf-8'))
        names = {r['name'] for r in rows}
        rows += [{'name': grape, 'aliases': extra}
                 for grape, extra in aliases.items() if grape not in names]
        path.write_text(json.dumps(rows, ensure_ascii=False, indent=1),
                        encoding='utf-8')


if __name__ == '__main__':
    scratch = pathlib.Path(sys.argv[1])
    load_points(scratch)
    if sys.argv[2] == 'import':
        bw.do_import(scratch)
        add_aliases()
    else:
        bw.do_sql()
