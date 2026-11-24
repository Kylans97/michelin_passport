"""Batch 2: The World's 50 Best Vineyards 2026 ranks 51 to 100, four of the
six estates held back from ranks 1 to 50, and the five Dutch estates staged
in vineyards_editorial/.

Reads research/*.csv (one row per estate, every value from the estate's own
site or the organiser's pages; method in README.md) and
../../vineyards_editorial/vineyards_editorial_staging.csv, then:

  * gives ranks 51..100 the codes vine_0056..vine_0105 in rank order
    (vine_0051..0055 are the Dutch estates; 1..50 keep theirs);
  * applies one written region and village decision per estate (DECISIONS,
    with the reason), never found by name: the village is looked up by its
    id in that region's official commune list;
  * checks each decision as batch 1 did (region exists in the estate's
    country, village in the region's list, estate pin inside the region
    outline and, outside Europe, inside the village polygon) and holds back
    any row that fails;
  * writes batch02_estates.csv for review and prepared_batch02.sql.

Run from the repo root:
    python3 -I supabase/data/enrichment/vineyards_global/batch_02_w50b/assemble_batch02.py
"""
import csv
import glob
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ENR = os.path.join(HERE, '..', '..')
WR = os.path.join(ENR, 'wine_regions', 'outlines')
REGIONS_LIVE = os.path.join(HERE, '..', 'batch_01_existing_44', 'wine_regions_LIVE_20261124.csv')

TOP50_ANNOUNCED = '2026-11-18'
EXT_ANNOUNCED = '2026-11-09'  # the organiser's 51-100 article, published 2026-11-09
EXT_SOURCE = 'https://www.the50.com/stories/News/the-50-best-vineyards-2026-the-51-100-list.html'

# code: (region_code or None, village unit id or None, basis)
DECISIONS = {
    'vine_0056': ('wr_0108', 'FR_69218', 'list Beaujolais; address 69220 Saint-Lager'),
    'vine_0057': ('wr_0003', 'FR_51230', 'list Champagne; address 51200 Épernay'),
    'vine_0058': ('wr_0132', 'GB_CTYUA_E10000032', 'list Sussex; address West Chiltington, West Sussex (county unit)'),
    'vine_0059': ('wr_0072', 'AT_31304', 'list Wachau; address 3601 Dürnstein'),
    'vine_0060': (None, None, 'held back (age gate only); list Kartli, no atlas region either'),
    'vine_0061': ('wr_0023', None, 'list Willamette Valley; one-unit region (the AVA)'),
    'vine_0062': ('wr_0109', 'FR_34015', 'list Languedoc; address 34360 Assignan (the pin is the cellar, also in Assignan per the note)'),
    'vine_0063': ('wr_0010', 'IT_004013', 'list Barolo; Piedmont (wr_0010) contains all of Barolo DOCG; address Fraz. Vergne, 12060 Barolo'),
    'vine_0064': ('wr_0021', None, 'list Napa Valley; one-unit region (the AVA)'),
    'vine_0065': ('wr_0009', 'DE_07231008', 'list Mosel; address 54470 Bernkastel-Kues'),
    'vine_0066': ('wr_0003', 'FR_51454', 'list Champagne; address 51100 Reims'),
    'vine_0067': ('wr_0003', 'FR_51454', 'list Champagne; address 51100 Reims'),
    'vine_0068': ('wr_0008', 'PT_170123', 'list Douro Valley; address Vale de Mendiz, 5085 Pinhão; the freguesia union holding Vale de Mendiz'),
    'vine_0069': ('wr_0010', 'IT_004055', 'list Piedmont; address 12060 Castiglione Falletto'),
    'vine_0070': ('wr_0026', None, 'list Mendoza; address names no departamento, village from the estate pin (checked below)'),
    'vine_0071': ('wr_0098', 'ES_08154', 'list Penedès; address 08796 Pacs del Penedès'),
    'vine_0072': (None, None, "list Santa Clara; the atlas has no Santa Clara region. Monte Bello lies in the Santa Cruz Mountains AVA (wr_0139) by reputation only: no pin, and the estate's own statement was not read. Not placed"),
    'vine_0073': ('wr_0003', 'FR_51030', 'list Champagne; address 51160 Aÿ-Champagne'),
    'vine_0074': ('wr_0142', None, 'list Okanagan Valley; no commune list for this region, so no village'),
    'vine_0075': ('wr_0133', None, 'list Kakheti; the estate publishes no address, so no village'),
    'vine_0076': ('wr_0132', 'GB_CTYUA_E10000032', 'list Sussex; address Mannings Heath, Horsham, West Sussex'),
    'vine_0077': ('wr_0158', None, 'list Alentejo; no commune list for this region, so no village'),
    'vine_0078': (None, None, 'list Montevideo; the atlas has Canelones and Maldonado only. Not placed'),
    'vine_0079': ('wr_0118', 'HU_12469', 'list Tokaj; address 3908 Rátka'),
    'vine_0080': ('wr_0051', None, 'list Margaret River; one-unit region'),
    'vine_0081': ('wr_0207', None, 'list Madiran; no address published, so no village'),
    'vine_0082': ('wr_0168', 'IT_022205', 'list Trentino; Trentodoc (wr_0168) is the atlas region for Trentino and lists Trento; address 38123 Trento'),
    'vine_0083': ('wr_0250', None, 'list Eden Valley; one-unit region'),
    'vine_0084': ('wr_0045', None, 'list McLaren Vale; one-unit region'),
    'vine_0085': ('wr_0026', 'AR_DEP_50063', 'list Mendoza; address Agrelo, Luján de Cuyo'),
    'vine_0086': (None, None, 'list Thracian Lowlands; the atlas has Melnik and Sakar only. Not placed'),
    'vine_0087': ('wr_0055', 'NZ_TA_070', 'list Central Otago; address Wānaka, which is in Queenstown-Lakes District'),
    'vine_0088': ('wr_0026', 'AR_DEP_50126', 'list Mendoza (also inside Valle de Uco, wr_0027; placed where the list names it); address Tupungato'),
    'vine_0089': ('wr_0029', 'CL_COM_13202', 'list Maipo Valley; address Pirque'),
    'vine_0090': ('wr_0002', 'FR_33238', 'list Bordeaux; address 33850 Léognan'),
    'vine_0091': (None, None, 'list Douro Valley, but the row is the Lodge in Vila Nova de Gaia, which is not in the Douro demarcated region (wr_0008 list). Not placed'),
    'vine_0092': ('wr_0003', 'FR_51576', 'list Champagne; address 51150 Tours-sur-Marne'),
    'vine_0093': ('wr_0021', None, 'list Napa Valley; one-unit region'),
    'vine_0094': (None, None, "list and postal address Franschhoek (wr_0038), but the estate's own printed GPS (-33.8225, 18.93) lies inside the Paarl district (wr_0039), not Franschhoek. Conflict: not placed"),
    'vine_0095': ('wr_0005', 'FR_18241', 'list Loire Valley; address Chavignol, 18300 Sancerre'),
    'vine_0096': ('wr_0002', 'FR_33314', 'list Bordeaux; address 33250 Pauillac'),
    'vine_0097': ('wr_0132', 'GB_CTYUA_E10000011', 'list Sussex; address Ditchling Common, East Sussex'),
    'vine_0098': ('wr_0008', 'PT_181917', 'list Douro Valley; address Valença do Douro, Tabuaço'),
    'vine_0099': ('wr_0151', None, 'list Helan; no commune list for this region, so no village'),
    'vine_0100': ('wr_0167', 'IT_088012', 'list Sicily; the atlas has no Sicily region, and the address commune Vittoria is in exactly one atlas region, Cerasuolo di Vittoria (wr_0167)'),
    'vine_0101': ('wr_0002', 'FR_33268', 'list Bordeaux; address 33460 Margaux-Cantenac'),
    'vine_0102': ('wr_0001', 'FR_21054', 'list Burgundy; address 21200 Beaune (the house in town)'),
    'vine_0103': ('wr_0002', 'FR_33238', 'list Bordeaux; address 33850 Léognan'),
    'vine_0104': (None, None, 'list Castilla y León; Sardón de Duero is not in Ribera del Duero (wr_0007 list). Not placed'),
    'vine_0105': ('wr_0124', 'EL_60010112', 'list Santorini; address Pyrgos (community of Pyrgos Kallistis)'),
    # Held back from ranks 1-50 on 2026-11-20, rechecked 2026-11-24.
    'vine_0021': ('wr_0097', 'ES_11020', 'list Jerez; address Jerez de la Frontera'),
    'vine_0028': ('wr_0029', 'CL_COM_13201', 'list Maipo Valley; city Puente Alto from the contact page'),
    'vine_0033': ('wr_0026', None, 'list Mendoza; the estate names Mendoza but no town, so no village'),
    'vine_0047': ('wr_0003', 'FR_51030', 'list Champagne; address Mareuil-sur-Ay, 51160 Aÿ-Champagne'),
    'vine_0015': (None, None, 'still held back: age gate only'),
    'vine_0048': (None, None, 'still held back: age gate only'),
    # Dutch estates, product owner's picks (vineyards_editorial/).
    'vine_0051': ('wr_0014', 'NL_GM0935', 'estate states BOB Mergelland; address 6213 NE Maastricht'),
    'vine_0052': ('wr_0017', None, 'BOB Schouwen-Duiveland per RVO; one-unit region'),
    'vine_0053': ('wr_0013', None, 'BOB Maasvallei Limburg stated by the estate and RVO; the region is not drawn and has no commune list, so no village'),
    'vine_0054': ('wr_0014', 'NL_GM0938', 'estate states BOB Mergelland for still wines; Ulestraten is in gemeente Meerssen (BAG nummeraanduiding 0938...)'),
    'vine_0055': ('wr_0019', None, 'Vijlen: the address (BAG woonplaats Vijlen, 1431) is the whole one-unit region; the estate never claims the BOB, so this places the estate, not its wine. Also inside Mergelland (gemeente Vaals); placed in the more specific region'),
}


def point_in_ring(x, y, ring):
    inside, j = False, len(ring) - 1
    for i in range(len(ring)):
        xi, yi, xj, yj = ring[i][0], ring[i][1], ring[j][0], ring[j][1]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def in_polygons(x, y, polygons):
    return any(point_in_ring(x, y, p[0]) and not any(point_in_ring(x, y, h) for h in p[1:]) for p in polygons)


def geom_polygons(g):
    return [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']


def region_units(code):
    path = os.path.join(WR, 'communes', f'{code}.csv')
    if not os.path.exists(path):
        return None
    out = {}
    for r in csv.DictReader(open(path, encoding='utf-8')):
        out.setdefault(r['gisco_id'], r)
    return out


def load_rows():
    rows = []
    for f in sorted(glob.glob(os.path.join(HERE, 'research', 'ranks_*.csv'))):
        for r in csv.DictReader(open(f, encoding='utf-8')):
            rank = int(r['rank'])
            rows.append({**r, 'vineyard_code': f'vine_{rank + 5:04d}', 'rank': rank, 'list_type': 'extended_51_100',
                         'inclusion_reason': 'worlds_50_best_vineyards',
                         'source_url': r['estate_page_url'] or EXT_SOURCE, 'announced_on': EXT_ANNOUNCED,
                         'rank_source_url': EXT_SOURCE})
    top50 = {r['vineyard_code']: r for r in csv.DictReader(open(os.path.join(ENR, 'worlds_50_best_vineyards', 'worlds_50_best_vineyards_2026.csv'), encoding='utf-8'))}
    for r in csv.DictReader(open(os.path.join(HERE, 'research', 'held_back_recheck.csv'), encoding='utf-8')):
        o = top50[r['vineyard_code']]
        rows.append({**r, 'rank': int(o['rank']), 'list_type': 'top_50', 'country_name': o['country_name'],
                     'website_url': r['website_url'] or o['website_url'],
                     'inclusion_reason': 'worlds_50_best_vineyards',
                     'source_url': o['estate_page_url'], 'announced_on': TOP50_ANNOUNCED,
                     'rank_source_url': o['estate_page_url']})
    for r in csv.DictReader(open(os.path.join(ENR, 'vineyards_editorial', 'vineyards_editorial_staging.csv'), encoding='utf-8')):
        rows.append({**r, 'rank': None, 'list_type': None, 'inclusion_reason': 'editorial_selection',
                     'source_url': r['estate_page_url'], 'announced_on': None, 'rank_source_url': None})
    return rows


def main():
    regions = {r['region_code']: r for r in csv.DictReader(open(REGIONS_LIVE, encoding='utf-8'))}
    outlines = json.load(open(os.path.join(WR, 'outlines.json'), encoding='utf-8'))
    units = {}
    for f in glob.glob(os.path.join(WR, 'geometry', '*.geojson')):
        for feat in json.load(open(f, encoding='utf-8'))['features']:
            units[feat['properties']['unit_id']] = geom_polygons(feat['geometry'])

    rows = load_rows()
    codes = [r['vineyard_code'] for r in rows]
    assert len(codes) == len(set(codes)), 'duplicate code'
    assert set(codes) == set(DECISIONS), set(codes) ^ set(DECISIONS)

    out = []
    for r in rows:
        code = r['vineyard_code']
        region, village, basis = DECISIONS[code]
        checks, problems = [], []
        lat = float(r['latitude']) if r.get('latitude') else None
        lng = float(r['longitude']) if r.get('longitude') else None
        village_name = ''
        if region:
            reg = regions.get(region)
            if not reg:
                problems.append(f'{region} not in atlas')
            elif reg['country_code'] != r['country_code']:
                problems.append(f"region country {reg['country_code']} != estate {r['country_code']}")
            else:
                checks.append(f"{region} {reg['name']} exists")
            lst = region_units(region)
            if village:
                if lst is None or village not in lst:
                    problems.append(f'{village} not in {region} list')
                else:
                    village_name = lst[village]['lau_name']
                    checks.append(f'{village} {village_name} in list' + (' (partial)' if lst[village].get('partial') else ''))
            elif lst is not None and len(lst) >= 2 and 'one-unit' in basis:
                problems.append(f'{region} has {len(lst)} units, not one')
            if lat is not None:
                if region in outlines:
                    if in_polygons(lng, lat, outlines[region]):
                        checks.append('pin inside region outline')
                    else:
                        problems.append('pin OUTSIDE region outline')
                if village and village in units:
                    if in_polygons(lng, lat, units[village]):
                        checks.append('pin inside village polygon')
                    else:
                        problems.append('pin OUTSIDE village polygon')
                elif lst and not village:
                    hits = [u for u in lst if u in units and in_polygons(lng, lat, units[u])]
                    if hits:
                        checks.append(f'pin inside unit {hits[0]}')
                        if len(lst) >= 2 and 'village from the estate pin' in basis:
                            village, village_name = hits[0], lst[hits[0]]['lau_name']
            elif 'village from the estate pin' in basis:
                problems.append('no pin to place the village')
        held = r['verification_status'] == 'held_back' or basis.startswith('held back') or basis.startswith('still held back')
        status = ('held_back' if held or problems else
                  'no_region' if not region else
                  'region_only' if not village else 'ready')
        out.append({
            'vineyard_code': code, 'rank': r['rank'] or '', 'list_type': r['list_type'] or '',
            'inclusion_reason': r['inclusion_reason'], 'name': r['official_name'],
            'country_code': r['country_code'], 'list_region': r['region'], 'city': r['city'],
            'address': r['address'], 'latitude': r['latitude'], 'longitude': r['longitude'],
            'website_url': r['website_url'], 'source_url': r['source_url'],
            'announced_on': r['announced_on'] or '', 'rank_source_url': r['rank_source_url'] or '',
            'research_status': r['verification_status'],
            'region_code': region or '', 'region_name': regions[region]['name'] if region in regions else '',
            'village_id': village or '', 'village_name': village_name,
            'status': status, 'basis': basis, 'checks': '; '.join(checks), 'problems': '; '.join(problems),
        })

    with open(os.path.join(HERE, 'batch02_estates.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(out[0]))
        w.writeheader()
        w.writerows(sorted(out, key=lambda x: x['vineyard_code']))
    write_sql([o for o in out if o['status'] != 'held_back'])
    from collections import Counter
    print(Counter(o['status'] for o in out))
    for o in out:
        if o['problems'] or o['status'] == 'held_back':
            print(o['vineyard_code'], o['name'], o['status'], o['problems'])


def q(v):
    return 'null' if v in (None, '') else "'" + str(v).replace("'", "''") + "'"


def write_sql(rows):
    vals = []
    for o in sorted(rows, key=lambda x: x['vineyard_code']):
        loc = (f"st_setsrid(st_makepoint({float(o['longitude'])}, {float(o['latitude'])}), 4326)::geography"
               if o['latitude'] else 'null')
        vals.append(f"  ({q(o['vineyard_code'])}, {q(o['name'])}, {q(o['country_code'])}, {q(o['list_region'])}, "
                    f"{q(o['city'])}, {q(o['address'])}, {loc}, {q(o['website_url'])}, {q(o['inclusion_reason'])}, "
                    f"{q(o['source_url'])}, {q(o['region_code'])}, {q(o['village_id'])}, "
                    f"{o['rank'] or 'null'}, {q(o['list_type'])}, {q(o['rank_source_url'])}, "
                    f"{('date ' + q(o['announced_on'])) if o['announced_on'] else 'null'})")
    n = len(rows)
    ranked = sum(1 for o in rows if o['rank'])
    sql = f"""-- Batch 2 of the wine estates database: {n} estates.
-- The World's 50 Best Vineyards 2026 ranks 51-100 (minus held rows), four
-- estates held back from ranks 1-50 on 2026-11-20 and rechecked, and the
-- five Dutch estates (editorial_selection, product owner's picks).
-- Generated by assemble_batch02.py from batch02_estates.csv; held_back rows
-- stay out. location only where the estate itself publishes a pin; NULL
-- otherwise, never geocoded. Region and village by vineyard_code and
-- region_code; the village foreign key refuses a village outside its region.
-- PREPARED -- review before applying.
-- Refuses (nothing written) if any of these codes already exists.

begin;

create temporary table b2 (
  vineyard_code text, name text, country_code char(2), region text, city text,
  address text, location geography(Point,4326), website_url text,
  inclusion_reason text, source_url text, region_code text, commune_code text,
  rank smallint, list_type text, rank_source_url text, announced_on date
) on commit drop;

insert into b2 values
{(','+chr(10)).join(vals)};

do $$
begin
  if exists (select 1 from public.vineyards v join b2 using (vineyard_code)) then
    raise exception 'a batch 2 code already exists; refusing to insert twice';
  end if;
  if exists (select 1 from b2 where region_code is not null
             and not exists (select 1 from public.wine_regions r where r.region_code = b2.region_code)) then
    raise exception 'a region code is missing';
  end if;
end $$;

with ins as (
  insert into public.vineyards (vineyard_code, name, country_code, region, city, address, location,
    website_url, inclusion_reason, source_url, wine_region_id, commune_code)
  select b.vineyard_code, b.name, b.country_code, b.region, b.city, b.address, b.location,
    b.website_url, b.inclusion_reason, b.source_url, r.id, b.commune_code
  from b2 b left join public.wine_regions r on r.region_code = b.region_code
  returning id, vineyard_code
)
insert into public.worlds_50_best_vineyards (vineyard_id, year, rank, list_type, source_url, announced_on)
select ins.id, 2026, b.rank, b.list_type, b.rank_source_url, b.announced_on
from ins join b2 b using (vineyard_code)
where b.rank is not null;

do $$
declare v int; w int;
begin
  select count(*) into v from public.vineyards v join pg_temp.b2 b using (vineyard_code);
  select count(*) into w from public.worlds_50_best_vineyards x
    join public.vineyards v on v.id = x.vineyard_id
    join pg_temp.b2 b using (vineyard_code) where x.year = 2026;
  if v <> {n} or w <> {ranked} then
    raise exception 'expected {n} estates and {ranked} ranks, got % and %', v, w;
  end if;
end $$;

commit;
"""
    open(os.path.join(HERE, 'prepared_batch02.sql'), 'w', encoding='utf-8').write(sql)


if __name__ == '__main__':
    main()
