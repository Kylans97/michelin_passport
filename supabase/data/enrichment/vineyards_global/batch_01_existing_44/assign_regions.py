"""Batch 1: wine region and village for the estates already on production.

Reads vineyards_LIVE_20261124.csv (a read-only export of public.vineyards,
2026-11-24) and writes estate_regions_batch01.csv for review.

Nothing is inferred from a name match alone. Every row's region is a
decision written out in DECISIONS below, with the reason; the script only
checks it:

  * the region code exists in the atlas (wine_regions_LIVE_20261124.csv);
  * the village is a unit in that region's official commune list
    (wine_regions/outlines/communes/wr_NNNN.csv), looked up by its id;
  * where the estate's own coordinates are on production, they fall inside
    the region's drawn outline (outlines.json) and, outside Europe, inside
    the village unit's own polygon (outlines/geometry/*.geojson).

A check that fails turns the row to held_back. Run from the repo root:
    python3 -I supabase/data/enrichment/vineyards_global/batch_01_existing_44/assign_regions.py
"""
import csv
import glob
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
WR = os.path.join(HERE, '..', '..', 'wine_regions', 'outlines')

# vineyard_code: (region_code or None, village unit id or None, basis)
# basis says where the region and the village come from. "list" = the
# region printed on The World's 50 Best Vineyards 2026 list page, as stored
# in vineyards.region; "address" = the estate's own address on production.
DECISIONS = {
    'vine_0001': ('wr_0080', 'DE_06439004', 'list Rheingau; address 65366 Geisenheim-Johannisberg (Johannisberg is an Ortsteil of Geisenheim)'),
    'vine_0002': ('wr_0006', 'ES_01031', 'list Rioja; address 01300 Laguardia (Álava)'),
    'vine_0003': ('wr_0030', 'CL_COM_06310', 'list Colchagua Valley; address Millahue de Apalta, Santa Cruz'),
    'vine_0004': ('wr_0003', 'FR_51454', 'list Champagne; address 4 rue des Crayères, Reims'),
    'vine_0005': ('wr_0259', None, 'list Hemel-en-Aarde; address Hemel-en-Aarde Road, Hermanus. Village held: the region has three wards and nothing on production says which one; no coordinates'),
    'vine_0006': ('wr_0030', 'CL_COM_06310', 'list Colchagua Valley; address names no comuna, village from the estate pin inside the Santa Cruz comuna polygon'),
    'vine_0007': ('wr_0041', None, 'list Western Cape Province; address Klein Constantia Road, Constantia; Constantia is a one-unit region (ward), so no village'),
    'vine_0008': ('wr_0002', 'FR_33274', 'list Bordeaux; address 33650 Martillac'),
    'vine_0009': ('wr_0002', 'FR_33504', 'list Sauternes; the atlas has no Sauternes region, Bordeaux (wr_0002) is defined to include AOC Sauternes; address 33210 Sauternes'),
    'vine_0010': ('wr_0026', 'AR_DEP_50063', 'list Mendoza; address Las Compuertas, Luján de Cuyo'),
    'vine_0011': ('wr_0003', 'FR_51454', 'list Champagne; address 9 place Saint-Nicaise, 51722 Reims Cedex (company address, the Saint-Nicaise cellars are at the same place)'),
    'vine_0012': ('wr_0007', 'ES_47114', 'list Ribera del Duero; address 47300 Peñafiel. Peñafiel is marked possible-partial in the region list'),
    'vine_0013': ('wr_0031', None, 'list Casablanca Valley; Casablanca is a one-unit region (comuna Casablanca), so no village'),
    'vine_0014': ('wr_0002', 'FR_33318', 'list Bordeaux; address 33600 Pessac'),
    'vine_0016': ('wr_0008', 'PT_171004', 'list Douro Valley; address Gouvinhas, 5060-063 Sabrosa'),
    'vine_0017': ('wr_0051', None, 'list Margaret River; one-unit region (the GI), so no village'),
    'vine_0018': ('wr_0115', None, 'list Bekaa Valley; no commune list for this region and no address, so no village'),
    'vine_0019': ('wr_0030', 'CL_COM_06305', 'list Colchagua Valley; address Cunaco (a locality, not a comuna); village from the estate pin inside the Nancagua comuna polygon'),
    'vine_0020': ('wr_0117', None, 'list Maldonado; one-unit region (the departamento), so no village'),
    'vine_0022': ('wr_0010', 'IT_004003', 'list Piedmont; address Località San Cassiano 34, 12051 Alba (CN)'),
    'vine_0023': ('wr_0029', 'CL_COM_13202', 'list Maipo Valley; address Pirque, Región Metropolitana'),
    'vine_0024': (None, None, 'list Kent; the atlas has no Kent region (England has only Sussex, wr_0132); not placed in Sussex'),
    'vine_0025': ('wr_0006', 'ES_26071', 'list Rioja; address 26200 Haro'),
    'vine_0026': (None, None, 'list Empordà; the atlas has no Empordà region; not placed in Penedès or Cava'),
    'vine_0027': ('wr_0022', None, 'list Alexander Valley; the atlas has no Alexander Valley region, Sonoma County (wr_0022) is the county the address is in (Healdsburg, CA 95448); one-unit region, so no village'),
    'vine_0029': (None, None, 'list Texas Hill Country; not in the atlas'),
    'vine_0030': ('wr_0118', None, 'list Tokaj; the estate site publishes no address, so no village'),
    'vine_0031': ('wr_0053', None, 'list Marlborough; no address on production, so no village unit'),
    'vine_0032': ('wr_0026', 'AR_DEP_50063', 'list Mendoza; address Las Compuertas, Luján de Cuyo'),
    'vine_0034': ('wr_0021', None, 'list Napa Valley; one-unit region (the AVA), so no village'),
    'vine_0035': ('wr_0026', 'AR_DEP_50063', 'list Mendoza; address Agrelo, Luján de Cuyo'),
    'vine_0036': ('wr_0004', 'FR_26347', "list Rhône Valley; address 26600 Tain l'Hermitage"),
    'vine_0037': ('wr_0003', 'FR_51030', 'list Champagne; address 51160 Aÿ, a commune déléguée of Aÿ-Champagne since 2016'),
    'vine_0038': ('wr_0022', None, 'list Sonoma; address Healdsburg, CA 95448; one-unit region, so no village'),
    'vine_0039': ('wr_0054', None, "list Hawke's Bay; one-unit region, so no village"),
    'vine_0040': ('wr_0006', 'ES_26089', 'list Rioja; address N-232a Km 402, 26006 Logroño'),
    'vine_0041': ('wr_0051', None, 'list Margaret River; one-unit region, so no village'),
    'vine_0042': ('wr_0002', 'FR_33314', 'list Bordeaux; address 33250 Pauillac'),
    'vine_0043': ('wr_0037', None, 'list Stellenbosch; one-unit region (the district), so no village'),
    'vine_0044': ('wr_0006', 'ES_26034', 'list Rioja; address 26330 Briones'),
    'vine_0045': ('wr_0044', None, 'list Barossa Valley; one-unit region, so no village'),
    'vine_0046': ('wr_0037', None, 'list Stellenbosch; one-unit region, so no village'),
    'vine_0049': ('wr_0098', 'ES_08240', "list Alt Penedès; Penedès (wr_0098) is the region the list names. Sant Sadurní d'Anoia is also in Cava (wr_0189); not placed there"),
    'vine_0050': (None, None, 'list Salta; address Molinos, Salta. The only Salta region in the atlas is Cafayate (wr_0028, departamento Cafayate); Molinos is another departamento. IG Valles Calchaquíes is held back in the atlas'),
}


def point_in_ring(x, y, ring):
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def in_polygons(x, y, polygons):
    """polygons: list of [outer, hole, ...] rings."""
    for rings in polygons:
        if point_in_ring(x, y, rings[0]) and not any(point_in_ring(x, y, h) for h in rings[1:]):
            return True
    return False


def geom_polygons(geom):
    if geom['type'] == 'Polygon':
        return [geom['coordinates']]
    if geom['type'] == 'MultiPolygon':
        return geom['coordinates']
    raise ValueError(geom['type'])


def main():
    regions = {r['region_code']: r for r in csv.DictReader(open(os.path.join(HERE, 'wine_regions_LIVE_20261124.csv'), encoding='utf-8'))}
    outlines = json.load(open(os.path.join(WR, 'outlines.json'), encoding='utf-8'))
    units = {}
    for f in glob.glob(os.path.join(WR, 'geometry', '*.geojson')):
        for feat in json.load(open(f, encoding='utf-8'))['features']:
            units[feat['properties']['unit_id']] = geom_polygons(feat['geometry'])

    def region_units(code):
        path = os.path.join(WR, 'communes', f'{code}.csv')
        if not os.path.exists(path):
            return None
        out = {}
        for r in csv.DictReader(open(path, encoding='utf-8')):
            out.setdefault(r['gisco_id'], r)
        return out

    estates = list(csv.DictReader(open(os.path.join(HERE, 'vineyards_LIVE_20261124.csv'), encoding='utf-8')))
    assert {e['vineyard_code'] for e in estates} == set(DECISIONS), 'decisions do not cover exactly the live estates'

    rows = []
    for e in estates:
        code = e['vineyard_code']
        region, village, basis = DECISIONS[code]
        checks, problems = [], []
        lat = None if e['lat'] in ('', 'NULL') else float(e['lat'])
        lng = None if e['lng'] in ('', 'NULL') else float(e['lng'])
        village_name = ''
        if region:
            r = regions.get(region)
            if not r:
                problems.append(f'{region} not in atlas')
            elif r['country_code'] != e['country_code']:
                problems.append(f"region country {r['country_code']} != estate {e['country_code']}")
            else:
                checks.append(f"{region} {r['name']} ({r['country_code']}) exists")
            lst = region_units(region)
            if village:
                if lst is None or village not in lst:
                    problems.append(f'{village} not in {region} commune list')
                else:
                    u = lst[village]
                    village_name = u['lau_name']
                    checks.append(f"{village} {u['lau_name']} ({u['province']}) in {region} list" + (f"; list marks it partial: {u['partial'][:80]}" if u.get('partial') else ''))
            elif lst is not None and len(lst) >= 2 and 'one-unit' in basis:
                problems.append(f'{region} has {len(lst)} units, not one')
            if lat is not None:
                if region in outlines:
                    if in_polygons(lng, lat, outlines[region]):
                        checks.append('estate pin inside region outline')
                    else:
                        problems.append('estate pin OUTSIDE region outline')
                if village and village in units:
                    if in_polygons(lng, lat, units[village]):
                        checks.append('estate pin inside village polygon')
                    else:
                        problems.append('estate pin OUTSIDE village polygon')
                elif lst and not village:
                    hits = [uid for uid in lst if uid in units and in_polygons(lng, lat, units[uid])]
                    if hits:
                        checks.append(f'estate pin inside unit {hits[0]}')
            else:
                checks.append('no estate pin on production, outline not checked')
        if problems:
            status = 'held_back'
        elif not region:
            status = 'no_region'
        elif not village:
            status = 'region_only'
        else:
            status = 'ready'
        rows.append({
            'vineyard_code': code, 'name': e['name'], 'country_code': e['country_code'],
            'list_region': e['region'], 'city': '' if e['city'] == 'NULL' else e['city'],
            'proposed_region_code': region or '', 'proposed_region_name': regions[region]['name'] if region in regions else '',
            'proposed_village_id': village or '', 'proposed_village_name': village_name,
            'status': status, 'basis': basis, 'checks': '; '.join(checks), 'problems': '; '.join(problems),
        })

    out = os.path.join(HERE, 'estate_regions_batch01.csv')
    with open(out, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    from collections import Counter
    print(Counter(r['status'] for r in rows))
    for r in rows:
        if r['problems'] or 'unit' in r['checks']:
            print(r['vineyard_code'], r['status'], r['problems'], '|', r['checks'])


if __name__ == '__main__':
    main()
