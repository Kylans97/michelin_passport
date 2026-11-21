#!/usr/bin/env python3
"""Rounds 1 and 2 of more wine regions (product owner, 2026-11-21: "ja begin daar
maar mee", on completing the classics plus Lebanon and Uruguay): Germany,
Italy, Spain, Portugal and France beyond the regions already in the app,
and Lebanon and Uruguay, whose estates are in The World's 50 Best
Vineyards. Research in <scratch>/classics/<country>.

    <venv with shapely>/bin/python -I build_classics_batch.py <scratch> import
    <venv with shapely>/bin/python -I build_classics_batch.py <scratch> sql

Reuses build_world_batch.py; see its docstring for the method. Germany
comes before France so Silvaner, with Sylvaner as its alias, is the one
catalogue entry. Boundaries: Eurostat LAU from the municipalities each
official text lists (the EU product specifications, INAO's commune
lists, the Spanish pliegos, the Italian disciplinari, the Portuguese
specifications); Uruguay's Canelones and Maldonado from INE Uruguay's
departments. Lebanon has no legally defined wine region: the Bekaa Valley
is a point (GeoNames 280281).

Round 2: Hungary (Tokaj, Villány, Eger, Somló), Slovenia (Goriška Brda,
Vipavska dolina, approximated by municipalities since their texts draw a
line), Greece (Santorini, Naoussa, Nemea), Belgium (Hageland, Haspengouw,
Heuvelland, Côtes de Sambre et Meuse), Luxembourg (Moselle
Luxembourgeoise), England (Sussex: East and West Sussex from ONS, with
Brighton and Hove, which the specification's map includes) and Georgia
(Kakheti: its eight municipalities, from OCHA COD-AB / Geostat; needs
20261101620000_add_ge_country.sql).
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
    ('DE', 'classics/de', None, codes(80, [
        'rheingau', 'pfalz', 'rheinhessen', 'nahe', 'franken', 'baden',
        'ahr'])),
    ('IT', 'classics/it', None, codes(87, [
        'valpolicella', 'soave', 'prosecco', 'alto_adige', 'friuli', 'etna',
        'franciacorta', 'taurasi'])),
    ('ES', 'classics/es', None, codes(95, [
        'priorat', 'rias_baixas', 'jerez', 'penedes', 'rueda', 'bierzo',
        'toro'])),
    ('PT', 'classics/pt', None, codes(102, [
        'vinho-verde', 'dao', 'bairrada', 'madeira', 'setubal'])),
    ('FR', 'classics/fr', None, codes(107, [
        'alsace', 'beaujolais', 'languedoc', 'roussillon', 'provence', 'jura',
        'cahors', 'savoie'])),
    ('UY', 'classics/lb_uy', 'lb_uy_units.geojson', codes(115, [
        'bekaa-valley', 'canelones', 'maldonado'])),
    # Round 2, "Europa breder" (product owner, 2026-11-21: "kunnen we al
    # met 2: Europa breder?"), in the same file so its grapes reuse round
    # 1's (Ribolla Gialla, Friulano).
    ('HU', 'europe2/hu_si_gr', None, codes(118, [
        'tokaj', 'villany', 'eger', 'somlo', 'goriska-brda',
        'vipavska-dolina', 'santorini', 'naoussa', 'nemea'])),
    ('BE', 'europe2/be_lu', None, codes(127, [
        'hagelandse_wijn', 'haspengouwse_wijn', 'heuvellandse_wijn',
        'cotes_de_sambre_et_meuse', 'moselle_luxembourgeoise'])),
    ('GB', 'europe2/gb_ge', 'gb_ge_units.geojson', codes(132, [
        'sussex', 'kakheti'])),
]
bw.AT = ('AT', 'classics/at', None, [])
bw.POINTS = {
    # Lebanon has no legally defined wine region (Law 216 of 2000; no
    # appellation area defined since): the valley as a GeoNames feature.
    'wr_0115': (33.833, 36.000, 30, 'GeoNames 280281 Bekaa Valley'),
}
bw.FIRST_APPELLATION = 209  # after wa_0208
bw.FIRST_GRAPE = 51  # after gr_0050
bw.CATALOGUE = 'grapes_production_20261121.json'
bw.OUTPUT = 'wine_regions_seed_classics_v1.sql'

# Values the research set that don't meet the two-source rule on review.
OVERRIDES = {
    # One of the two sources (Decanter) describes a single estate.
    ('lb_uy', 'maldonado', 'red_acidity'): None,
}


def apply_overrides():
    for (folder, slug, field), value in OVERRIDES.items():
        path = HERE / folder / 'style.json'
        rows = json.load(open(path, encoding='utf-8'))
        for r in rows:
            if r['slug'] == slug:
                r[field] = value
        path.write_text(json.dumps(rows, ensure_ascii=False, indent=1),
                        encoding='utf-8')


if __name__ == '__main__':
    scratch = pathlib.Path(sys.argv[1])
    if sys.argv[2] == 'import':
        bw.do_import(scratch)
        apply_overrides()
    else:
        bw.do_sql()
