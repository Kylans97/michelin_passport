#!/usr/bin/env python3
"""The wine regions of South Africa, Australia, New Zealand, Croatia,
Switzerland and Austria (product owner, 2026-11-20), from the research in
<scratch>/oceania_sa and <scratch>/alps_hr.

    <venv with shapely>/bin/python -I build_world_batch.py <scratch> import
        copies each region's official units into outlines/communes/ and,
        where the boundary data isn't Eurostat LAU, outlines/geometry/;
        then run scripts/build_wine_region_outlines.py
    <venv with shapely>/bin/python -I build_world_batch.py <scratch> sql
        writes wine_regions_seed_world_v1.sql from each country's
        style.json and new_grapes.json, with each region's point and radius
        taken from its built outline

Every region here is drawn. Boundaries: Wine Australia's GI polygons
(CC BY 4.0); Stats NZ territorial authorities and meshblocks (CC BY 4.0),
approximating the registered GIs for Marlborough, Nelson and North
Canterbury (the registered polygons themselves are not licensed for
publication); the SAWIS/VinPro Wine of Origin layer for South Africa (no
licence stated: permission to be asked); Eurostat LAU for Croatia,
Switzerland and Austria, from the municipalities the official texts list.
Each region's notes beside its commune list record the official text and
every judgement call.

Style content: only claims two independent sources support (see each
country's style.json "sources", copied beside this script). Grapes are
matched to the catalogue by name or alias, never added twice.
"""

import csv
import json
import math
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
OUTLINES = HERE.parent / 'outlines'

# (country, research folder, units file or None for LAU, [(slug, code,
# commune csv)]). Codes continue after wr_0036.
BATCH = [
    ('ZA', 'oceania_sa/za', 'za_units.geojson', [
        ('stellenbosch', 'wr_0037'), ('franschhoek', 'wr_0038'),
        ('paarl', 'wr_0039'), ('swartland', 'wr_0040'),
        ('constantia', 'wr_0041'), ('elgin', 'wr_0042'),
        ('walker-bay', 'wr_0043')]),
    ('AU', 'oceania_sa/au', 'au_units.geojson', [
        ('barossa_valley', 'wr_0044'), ('mclaren_vale', 'wr_0045'),
        ('clare_valley', 'wr_0046'), ('coonawarra', 'wr_0047'),
        ('adelaide_hills', 'wr_0048'), ('hunter', 'wr_0049'),
        ('yarra_valley', 'wr_0050'), ('margaret_river', 'wr_0051'),
        ('tasmania', 'wr_0052')]),
    ('NZ', 'oceania_sa/nz', 'nz_units.geojson', [
        ('marlborough', 'wr_0053'), ('hawkes-bay', 'wr_0054'),
        ('central-otago', 'wr_0055'), ('north-canterbury', 'wr_0056'),
        ('gisborne', 'wr_0057'), ('wairarapa', 'wr_0058'),
        ('nelson', 'wr_0059')]),
    ('HR', 'alps_hr/hr', None, [
        ('hrvatska-istra', 'wr_0060'),
        ('srednja-i-juzna-dalmacija', 'wr_0061'),
        ('slavonija', 'wr_0062'), ('hrvatsko-podunavlje', 'wr_0063'),
        ('plesivica', 'wr_0064')]),
    ('CH', 'alps_hr/ch', None, [
        ('valais', 'wr_0065'), ('vaud', 'wr_0066'), ('lavaux', 'wr_0067'),
        ('geneve', 'wr_0068'), ('ticino', 'wr_0069'),
        ('neuchatel', 'wr_0070'),
        # Graubünden's AOC is the whole canton, Engadin included; drawn as
        # the official wine region of art. 2a BR 917.400, the Bündner
        # Rheintal (Fläsch to Bonaduz), where the vines are.
        ('graubuenden', 'wr_0071', 'buendner_rheintal')]),
]
AT = ('AT', 'alps_hr/at', None, [
    ('wachau', 'wr_0072'), ('kremstal', 'wr_0073'), ('kamptal', 'wr_0074'),
    ('wagram', 'wr_0075'), ('weinviertel', 'wr_0076'),
    ('leithaberg', 'wr_0077'), ('neusiedlersee', 'wr_0078'),
    ('suedsteiermark', 'wr_0079')])
FIRST_APPELLATION = 44  # after wa_0043
FIRST_GRAPE = 32  # after gr_0031
CATALOGUE = 'grapes_production_20261120.json'
OUTPUT = 'wine_regions_seed_world_v1.sql'
# Regions shown as a point: code -> (latitude, longitude, radius_km, source).
POINTS = {}


def regions():
    for country, folder, units, entries in BATCH + ([AT] if AT[3] else []):
        for entry in entries:
            slug, code = entry[0], entry[1]
            csv_name = entry[2] if len(entry) > 2 else slug
            yield country, folder, units, slug, code, csv_name


def do_import(scratch):
    seen_units = set()
    for country, folder, units, slug, code, csv_name in regions():
        src = scratch / folder
        if code in POINTS:
            print(f'{code} {country} {slug}: point')
            continue
        rows = list(csv.DictReader(open(src / f'{csv_name}.csv',
                                        encoding='utf-8')))
        for r in rows:
            r['region_code'] = code
            # Some research wrote "no" rather than leaving it empty.
            if (r.get('partial') or '').strip().lower() in (
                    'no', 'false', 'none', 'n', '0'):
                r['partial'] = ''
        with open(OUTLINES / 'communes' / f'{code}.csv', 'w', newline='',
                  encoding='utf-8') as f:
            w = csv.DictWriter(f, ['region_code', 'gisco_id', 'official_name',
                                   'lau_name', 'province', 'partial',
                                   'source_url'], extrasaction='ignore')
            w.writeheader()
            w.writerows(rows)
        notes = src / f'{csv_name}_notes.md'
        if notes.exists():
            shutil.copy(notes, OUTLINES / 'communes' / f'{code}_notes.md')
        if units and units not in seen_units:
            seen_units.add(units)
            shutil.copy(src / units, OUTLINES / 'geometry' / units)
        print(f'{code} {country} {slug}: {len(rows)} units')
    for country, folder, *_ in BATCH + ([AT] if AT[3] else []):
        dest = HERE / pathlib.Path(folder).name
        dest.mkdir(exist_ok=True)
        for name in ('style.json', 'new_grapes.json'):
            if (scratch / folder / name).exists():
                shutil.copy(scratch / folder / name, dest / name)


def fold(text):
    import unicodedata
    text = unicodedata.normalize('NFKD', text.lower())
    return ''.join(c for c in text if not unicodedata.combining(c)).strip()


def q(text):
    if text is None:
        return 'null'
    return "'" + str(text).replace("'", "''") + "'"


def arr(items):
    inner = ','.join('"' + str(i).replace('"', '\\"') + '"' for i in items)
    return q('{' + inner + '}') + '::text[]'


def num(v):
    return 'null' if v is None else str(int(v))


def colour(value):
    """wine_appellations.colour allows red, white, rose, sparkling or
    mixed; the research sometimes lists several ('white, rosé, red')."""
    v = fold(value or '').replace('rosé', 'rose')
    parts = [p.strip() for p in v.replace(' and ', ',').split(',') if p.strip()]
    if len(parts) == 1 and parts[0] in ('red', 'white', 'rose', 'sparkling',
                                        'mixed'):
        return parts[0]
    return 'mixed'


def cap(s):
    return s[:1].upper() + s[1:] if s else s


def do_sql():
    from shapely.geometry import MultiPolygon, Polygon
    outlines = json.load(open(OUTLINES / 'outlines.json', encoding='utf-8'))
    catalogue = json.load(open(HERE / CATALOGUE, encoding='utf-8'))
    by_name = {}
    for g in catalogue:
        for n in [g['name']] + (g['aliases'] or []):
            by_name.setdefault(fold(n), g['grape_code'])
    # Shiraz is Syrah's alias already; Tribidrag/Crljenak Kaštelanski are
    # Zinfandel's (Croatia's research), added to its aliases below.
    new_grapes, extra_aliases = [], {}
    next_grape = FIRST_GRAPE
    for country, folder, *_ in BATCH + ([AT] if AT[3] else []):
        path = HERE / pathlib.Path(folder).name / 'new_grapes.json'
        if not path.exists():
            continue
        for g in json.load(open(path, encoding='utf-8')):
            names = [g['name']] + g.get('aliases', [])
            existing = next((by_name[fold(n)] for n in names
                             if fold(n) in by_name), None)
            if existing:
                for n in names:
                    if fold(n) not in by_name:
                        extra_aliases.setdefault(existing, []).append(n)
                        by_name[fold(n)] = existing
                continue
            code = f'gr_{next_grape:04d}'
            next_grape += 1
            for n in names:
                by_name[fold(n)] = code
            new_grapes.append((code, g))

    out = ['-- Generated by build_world_batch.py. See its docstring and each',
           "-- region's notes; style.json holds every claim's sources.",
           '', 'begin;', '']
    region_rows, link_rows, app_rows, unmatched = [], [], [], []
    next_app = FIRST_APPELLATION
    for country, folder, units, slug, code, csv_name in regions():
        style = {s['slug']: s for s in json.load(open(
            HERE / pathlib.Path(folder).name / 'style.json', encoding='utf-8'))}
        s = style[slug]
        country = s.get('country', country)
        if code in POINTS:
            lat, lng, radius, _ = POINTS[code]

            class pt:  # noqa: N801 - a point's coordinates, like shapely's
                x, y = lng, lat
        else:
            polys = outlines[code]
            mp = MultiPolygon([Polygon(p[0], p[1:]) for p in polys])
            pt = mp.representative_point()
            km2 = mp.area * 111.32 ** 2 * math.cos(math.radians(pt.y))
            radius = min(400, max(5, round(math.sqrt(km2 / math.pi))))
        source = next(iter(s.get('sources', {}).get('summary', [])), None)
        region_rows.append(
            f"  ({q(code)}, {q(s['name'])}, {arr(s.get('aliases', []))}, "
            f"{q(country)}, {pt.y:.3f}, {pt.x:.3f}, {radius},\n"
            f"   {q(s['summary'])},\n"
            f"   {num(s.get('red_body'))}, {num(s.get('red_acidity'))}, "
            f"{num(s.get('red_tannin'))}, {q(s.get('pairing'))}, "
            f"{q(s.get('label_note'))},\n   {q(source)}, 'published')")
        for i, g in enumerate(s.get('grapes', []), 1):
            gcode = by_name.get(fold(g['name']))
            if not gcode:
                unmatched.append(f'{code} {g["name"]}')
                continue
            link_rows.append(f"  ({q(code)}, {q(gcode)}, "
                             f"{q(g.get('local_note'))}, {i})")
        for i, a in enumerate(s.get('appellations', []), 1):
            app_rows.append(
                f"  ('wa_{next_app:04d}', {q(a['name'])}, "
                f"{arr(a.get('aliases', []))}, {q(code)}, {q(colour(a['colour']))}, "
                f"{q(a.get('note') or '')}, {i})")
            next_app += 1

    out += ['insert into public.wine_regions',
            '  (region_code, name, aliases, country_code, latitude, '
            'longitude, radius_km,',
            '   summary, red_body, red_acidity, red_tannin, pairing, '
            'label_note,',
            '   source_url, publication_status)', 'values',
            ',\n'.join(region_rows) + ';', '']
    if new_grapes:
        rows = []
        for code, g in new_grapes:
            rows.append(
                f"  ({q(code)}, {q(g['name'])}, {arr(g.get('aliases', []))}, "
                f"{q(g['colour'])},\n   {q(g['summary'])},\n   "
                f"{arr([cap(t) for t in g.get('tastes') or []])}, "
                f"{q(g.get('aged_note'))}, {num(g.get('body'))}, "
                f"{num(g.get('acidity'))}, {num(g.get('tannin'))}, "
                "'published')")
        out += ['insert into public.grapes',
                '  (grape_code, name, aliases, colour, summary, tastes, '
                'aged_note,',
                '   body, acidity, tannin, publication_status)', 'values',
                ',\n'.join(rows) + ';', '']
        for code, g in new_grapes:
            sim = g.get('similar')
            target = sim and by_name.get(fold(sim['name']))
            if target:
                out.append(
                    'update public.grapes g set similar_grape_id = s.id, '
                    f"similar_note = {q(sim.get('note'))} from public.grapes s"
                    f" where s.grape_code = {q(target)} and "
                    f'g.grape_code = {q(code)};')
    for code, names in extra_aliases.items():
        out.append(f'update public.grapes set aliases = aliases || '
                   f'{arr(names)} where grape_code = {q(code)};')
    out += ['', 'insert into public.wine_region_grapes '
            '(region_id, grape_id, local_note, display_order)',
            'select r.id, g.id, v.note, v.ord', 'from (values',
            ',\n'.join(link_rows),
            ') as v(region, grape, note, ord)',
            'join public.wine_regions r on r.region_code = v.region',
            'join public.grapes g on g.grape_code = v.grape;', '']
    if app_rows:
        out += ['insert into public.wine_appellations',
                '  (appellation_code, name, aliases, region_id, colour, note, '
                'display_order,', '   publication_status)',
                "select v.code, v.name, v.aliases, r.id, v.colour, v.note, "
                "v.ord, 'published'", 'from (values', ',\n'.join(app_rows),
                ') as v(code, name, aliases, region, colour, note, ord)',
                'join public.wine_regions r on r.region_code = v.region;', '']
    out += ['commit;', '']
    (HERE.parent / OUTPUT).write_text(
        '\n'.join(out), encoding='utf-8')
    print(f'{len(region_rows)} regions, {len(new_grapes)} new grapes '
          f'({", ".join(g["name"] for _, g in new_grapes)}), '
          f'{len(link_rows)} links, {len(app_rows)} names, '
          f'aliases added to {sorted(extra_aliases)}')
    if unmatched:
        print('UNMATCHED grapes (left out):', unmatched)


if __name__ == '__main__':
    scratch = pathlib.Path(sys.argv[1])
    {'import': lambda: do_import(scratch), 'sql': do_sql}[sys.argv[2]]()
