#!/usr/bin/env python3
"""Round 4 of more wine regions (product owner, 2026-11-21: "oke laten we
nog meer wijngebieden toevoegen"): more of the United States, Canada,
Brazil, Mexico, Japan and China, and the European regions earlier rounds
held back. Research in <scratch>/round4/<group>.

    <venv with shapely>/bin/python -I build_round4_batch.py <scratch> import
    <venv with shapely>/bin/python -I build_round4_batch.py <scratch> sql

Reuses build_world_batch.py; see its docstring for the method.
Boundaries:
- United States: TTB's AVA polygons (AVA Map Explorer, CC0), checked
  against 27 CFR part 9; Long Island from the Census Bureau's county
  outlines for Nassau and Suffolk, since TTB's polygon follows the county
  lines into the water (7,312 km2 against the regulation's ~3,030).
- Brazil: Vale dos Vinhedos from Embrapa's DO line (GeoInfo 2121), Vale
  do Sao Francisco from IBGE's municipalities. Mexico: Queretaro, the
  country's one wine GI (IMPI, DOF 2025), from INEGI's state boundary.
- Japan: the NTA's GIs cover whole prefectures; MLIT N03 2026, CC BY 4.0.
  Hokkaido leaves out the islands Russia administers.
- Wuerttemberg from LGL Baden-Wuerttemberg's Gemarkungen (dl-de/by-2-0),
  the units its specification lists; Colares from DGT CAOP 2012.1 for the
  two pre-2013 freguesias. The rest from Eurostat LAU.
Points, with no official geometry to draw: Niagara Peninsula and
Okanagan Valley (published as PDF maps only), Campanha Gaucha (layer not
obtainable), Valle de Guadalupe (no GI), the Helan Mountain East Foothill
(defined by townships and state farms), Alentejo and Stajerska Slovenija
(defined by boundary lines).
"""

import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('bw', HERE / 'build_world_batch.py')
bw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bw)


def codes(start, slugs):
    return [(slug, f'wr_{start + i:04d}') for i, slug in enumerate(slugs)]


bw.BATCH = [
    ('US', 'round4/us_ca', 'us_ca_units.geojson', codes(134, [
        'sta-rita-hills', 'santa-maria-valley', 'russian-river-valley',
        'columbia-valley', 'walla-walla-valley', 'santa-cruz-mountains',
        'long-island', 'niagara-peninsula', 'okanagan-valley'])),
    ('BR', 'round4/br_mx', 'br_mx_units.geojson', codes(143, [
        'vale-dos-vinhedos', 'campanha-gaucha', 'vale-do-sao-francisco',
        'queretaro', 'valle-de-guadalupe'])),
    ('JP', 'round4/jp_cn', 'jp_cn_units.geojson', codes(148, [
        'yamanashi', 'hokkaido', 'nagano', 'ningxia_helan_mountain_east'])),
    ('DE', 'round4/europe_held', 'held_units.geojson', codes(152, [
        'wuerttemberg', 'vulkanland-steiermark', 'badacsony', 'amyndeon',
        'friuli-colli-orientali', 'colares', 'alentejo',
        'stajerska-slovenija'])),
]
bw.AT = ('AT', 'round4/europe_held', None, [])
# Representative points from GeoNames (each research folder's *_points.csv
# says what the point stands for); radius as for the Bekaa Valley.
bw.POINTS = {
    'wr_0141': (43.151, -79.394, 30, 'GeoNames 6174406 Vineland'),
    'wr_0142': (49.847, -119.519, 30, 'GeoNames 6092893 Okanagan Lake'),
    'wr_0144': (-30.781, -55.482, 30, "GeoNames 6323603 Sant'Ana do Livramento"),
    'wr_0147': (32.066, -116.608, 30, 'GeoNames 3980616 Guadalupe (valley)'),
    'wr_0151': (38.615, 106.067, 30, 'GeoNames 1784738 Zhenbeibu'),
    'wr_0158': (38.566, -7.904, 30, 'GeoNames 2268406 Evora'),
    'wr_0159': (46.473, 16.190, 30, 'GeoNames 8988601 Jeruzalem'),
}
bw.FIRST_APPELLATION = 425  # after wa_0424
bw.FIRST_GRAPE = 105  # after gr_0104
bw.CATALOGUE = 'grapes_production_20261121_r4.json'
bw.OUTPUT = 'wine_regions_seed_round4_v1.sql'


if __name__ == '__main__':
    scratch = pathlib.Path(sys.argv[1])
    if sys.argv[2] == 'import':
        bw.do_import(scratch)
    else:
        bw.do_sql()
