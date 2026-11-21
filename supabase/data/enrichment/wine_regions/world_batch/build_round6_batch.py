#!/usr/bin/env python3
"""Round 6 of more wine regions (product owner, 2026-11-21: "Start round 6:
Eastern Europe and the Eastern Mediterranean (Moravia, Romania, Bulgaria,
Serbia, Moldova, Armenia, Israel, Cyprus, Turkey, more of Greece), same
method as before"). Research in <scratch>/round6/<group>.

    <venv with shapely>/bin/python -I build_round6_batch.py <scratch> import
    <venv with shapely>/bin/python -I build_round6_batch.py <scratch> sql

Reuses build_world_batch.py; see its docstring for the method. Drawn from
the units each official text lists, on Eurostat LAU: Morava from vyhláška
254/2010 Sb. (katastrální území resolved to their obce through ČÚZK
RÚIAN), Dealu Mare, Cotnari and Murfatlar from their EU single documents
(villages checked against INS SIRUTA), the Greek PDOs and PGI Drama from
their technical files (ELSTAT 2021 settlements), Commandaria from its 14
named communities. Patras is the union of the four Patras PDOs, named
as appellations.
Points, where the text gives a line, a paper map or no area, or where
every unit is only partly in: Melnik, Sakar, Fruška Gora, the three
Moldovan PGIs, Samos (its text is unreadable), Krasochoria Lemesou,
Vayots Dzor (no registered GI found), Israel's Galilee, Judean Hills and
Negev (no open geometry; every point checked to lie inside the pre-1967
borders, nothing drawn or named beyond them) and Turkey's Thrace and
Cappadocia (no wine GI).
Needs 20261101640000_add_md_am_il_cy_countries.sql.
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
    'ce_se': codes(213, [
        'morava', 'dealu-mare', 'cotnari', 'murfatlar', 'melnik', 'sakar',
        'fruska-gora', 'codru', 'stefan-voda', 'valul-lui-traian']),
    'gr': codes(223, [
        'rapsani', 'mantinia', 'goumenissa', 'patras', 'drama', 'paros',
        'monemvasia', 'samos']),
    'me': codes(231, [
        'commandaria', 'krasochoria-lemesou', 'vayots-dzor', 'galilee',
        'judean-hills', 'negev', 'trakya', 'kapadokya']),
}
bw.BATCH = [
    ('CZ', 'round6/ce_se', None, GROUPS['ce_se']),
    ('GR', 'round6/gr', None, GROUPS['gr']),
    ('CY', 'round6/me', None, GROUPS['me']),
]
bw.AT = ('AT', 'round6/ce_se', None, [])
bw.FIRST_APPELLATION = 673  # after wa_0672
bw.FIRST_GRAPE = 147  # after gr_0146
bw.CATALOGUE = 'grapes_production_20261121_r6.json'
bw.OUTPUT = 'wine_regions_seed_round6_v1.sql'

# Crete (wr_0212, round 5) held Mandilaria back for want of a second
# source; round 6's Greek research found it (Wine Traveler), so Crete
# gains it after its six grapes.
EXTRA_LINKS = [('wr_0212', 'Mandilaria', 7)]


def load_points(scratch):
    """Every row of each group's *_points.csv, as GeoNames points."""
    bw.POINTS = {}
    for group, entries in GROUPS.items():
        path = scratch / 'round6' / group / f'{group}_points.csv'
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
                p = scratch / 'round6' / group / name
                if p.exists():
                    (HERE / group).mkdir(exist_ok=True)
                    (HERE / group / name).write_text(
                        p.read_text(encoding='utf-8'), encoding='utf-8')
        bw.do_import(scratch)
        add_aliases()
    else:
        bw.do_sql()
        add_extra_links()
