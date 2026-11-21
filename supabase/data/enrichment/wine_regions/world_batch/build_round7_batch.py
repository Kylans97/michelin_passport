#!/usr/bin/env python3
"""Round 7 of more wine regions (product owner, 2026-11-21: "oke kan je nog
meer ontbrekende wijngebieden toevoegen?"): more of Chile, Argentina and
Brazil, Australia and South Africa, the United States, Canada, Japan,
India and China. Research in <scratch>/round7/<group>.

    <venv with shapely>/bin/python -I build_round7_batch.py <scratch> import
    <venv with shapely>/bin/python -I build_round7_batch.py <scratch> sql

Reuses build_world_batch.py; see its docstring for the method.
Boundaries: Chile from the comunas Decreto 464 lists (BCN); Argentina's
INV I.G.s Añelo and General Roca (one departamento each, IGN Argentina)
and San Juan (the province); Altos de Pinto Bandeira from Embrapa's DO
line (no licence stated); Wine Australia's GI polygons (CC BY 4.0); the
SAWIS/VinPro Wine of Origin layer (no licence stated); TTB's AVA polygons
(CC0); Nova Scotia from StatCan (OGL Canada); Yamagata and Osaka from
MLIT N03 2026 (CC BY 4.0).
Points, with no open official geometry: Prince Edward County (a road
bounded strip), Nashik (GI map an image only), Yantai.
"""

import csv
import importlib.util
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('bw', HERE / 'build_world_batch.py')
bw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bw)


def codes(start, slugs):
    return [(slug, f'wr_{start + i:04d}') for i, slug in enumerate(slugs)]


GROUPS = {
    'sa': codes(239, [
        'valle-del-elqui', 'valle-del-limari', 'valle-del-aconcagua',
        'valle-de-san-antonio', 'valle-del-maule', 'valle-del-itata',
        'valle-del-bio-bio', 'anelo', 'general-roca', 'san-juan',
        'altos-de-pinto-bandeira']),
    'au_za': codes(250, [
        'eden_valley', 'mornington_peninsula', 'heathcote', 'rutherglen',
        'beechworth', 'orange', 'mudgee', 'great_southern',
        'canberra_district', 'hemel-en-aarde', 'durbanville', 'tulbagh',
        'robertson', 'cederberg', 'breedekloof']),
    'na_asia': codes(265, [
        'santa-lucia-highlands', 'anderson-valley', 'lodi',
        'sierra-foothills', 'monticello', 'prince-edward-county',
        'nova-scotia', 'yamagata', 'osaka', 'nashik', 'yantai']),
}
bw.BATCH = [
    ('CL', 'round7/sa', 'sa7_units.geojson', GROUPS['sa']),
    ('AU', 'round7/au_za', 'au_za7_units.geojson', GROUPS['au_za']),
    ('US', 'round7/na_asia', 'na_asia7_units.geojson', GROUPS['na_asia']),
]
bw.AT = ('AT', 'round7/sa', None, [])
bw.FIRST_APPELLATION = 717  # after wa_0716
bw.FIRST_GRAPE = 178  # after gr_0177
bw.CATALOGUE = 'grapes_production_20261121_r7.json'
bw.OUTPUT = 'wine_regions_seed_round7_v1.sql'

# Each group's geometry is published under a name of its own: round 7's
# sa_units.geojson would otherwise overwrite the Americas file of that name.
EXTRA_LINKS = []


def load_points(scratch):
    """Every row of each group's *_points.csv, as GeoNames points."""
    bw.POINTS = {}
    for group, entries in GROUPS.items():
        path = scratch / 'round7' / group / f'{group}_points.csv'
        rows = {r['slug']: r for r in csv.DictReader(open(path, encoding='utf-8'))}
        for slug, code in entries:
            if slug in rows:
                r = rows[slug]
                bw.POINTS[code] = (round(float(r['lat']), 3),
                                   round(float(r['lon']), 3), 30,
                                   f"GeoNames {r['geonames_id']}")


def add_aliases():
    """Synonyms of catalogue grapes (aliases_to_add.json, two sources
    each) as catalogue entries in new_grapes.json, which
    build_world_batch.py turns into alias updates, never new grapes."""
    for group in GROUPS:
        src = HERE / group / 'aliases_to_add.json'
        if not src.exists():
            continue
        by_grape = {}
        for a in json.load(open(src, encoding='utf-8')):
            by_grape.setdefault(a['grape'], []).append(a['alias'])
        path = HERE / group / 'new_grapes.json'
        rows = json.load(open(path, encoding='utf-8'))
        names = {r['name'] for r in rows}
        rows += [{'name': g, 'aliases': al} for g, al in by_grape.items()
                 if g not in names]
        path.write_text(json.dumps(rows, ensure_ascii=False, indent=1),
                        encoding='utf-8')


def add_extra_links():
    out = HERE.parent / bw.OUTPUT
    sql = out.read_text(encoding='utf-8')
    lines = []
    for region, grape, order in EXTRA_LINKS:
        code = re.search(r"\('(gr_\d{4})', '" + re.escape(grape) + "'",
                         sql).group(1)
        lines.append(
            'insert into public.wine_region_grapes (region_id, grape_id, '
            'local_note, display_order)\n'
            f"select r.id, g.id, null, {order} from public.wine_regions r, "
            f"public.grapes g where r.region_code = '{region}' and "
            f"g.grape_code = '{code}';")
    sql = sql.replace('\ncommit;\n', '\n' + '\n'.join(lines) + '\n\ncommit;\n')
    out.write_text(sql, encoding='utf-8')


if __name__ == '__main__':
    scratch = pathlib.Path(sys.argv[1])
    load_points(scratch)
    if sys.argv[2] == 'import':
        for group in GROUPS:
            for name in ('aliases_to_add.json',):
                p = scratch / 'round7' / group / name
                if p.exists():
                    (HERE / group).mkdir(exist_ok=True)
                    (HERE / group / name).write_text(
                        p.read_text(encoding='utf-8'), encoding='utf-8')
        bw.do_import(scratch)
        add_aliases()
    else:
        bw.do_sql()
        add_extra_links()
