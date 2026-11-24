"""Batch 3: Benelux wine estates named by an official source.

Reads research/nl.csv, be.csv and lu.csv (one row per estate; the official
source and every value's origin in its note; sources per designation in
research/*_sources.md) and writes batch03_estates.csv and
prepared_batch03.sql for review.

Codes: vine_0106 onward, in file order nl, be, lu (held rows get a code
too, so codes stay stable when they are added later).

Region: from the protected designation the official source and the estate
give, never from a name match. A designation that is a region in the atlas
(REGION_OF) places the estate there. A designation covering a whole country
part (Vlaamse mousserende kwaliteitswijn, Crémant de Wallonie, landwijn) is
not a region, so an estate holding only those has none.

Village: the unit of that region's official commune list that holds the
estate's municipality, by its id:
  * NL: the gemeente code is the first four digits of the BAG
    nummeraanduiding the research recorded for the address (an official
    identifier, not a name);
  * BE and LU: the municipality as the address gives it (for Belgium the
    one in brackets after a deelgemeente), matched to exactly one unit of
    that region's list, either language of a bilingual name. A locality
    that is not itself a municipality (most Luxembourg villages) gets no
    village rather than a guessed one.
A one-unit region is its own village. Where the estate published a pin, it
must lie inside the region outline.

Run from the repo root:
    python3 -I supabase/data/enrichment/vineyards_global/batch_03_benelux/assemble_batch03.py
"""
import csv
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
ENR = os.path.join(HERE, '..', '..')
WR = os.path.join(ENR, 'wine_regions', 'outlines')
REGIONS_LIVE = os.path.join(HERE, '..', 'batch_01_existing_44', 'wine_regions_LIVE_20261124.csv')
sys.path.insert(0, os.path.join(HERE, '..', 'batch_02_w50b'))
from assemble_batch02 import in_polygons, region_units, q  # noqa: E402

FIRST_CODE = 106

# Maasvallei Limburg is one BOB across the Dutch-Belgian border; the atlas
# keeps it under NL. A Belgian estate using it belongs there too.
CROSS_BORDER = {'wr_0013': {'NL', 'BE'}}

# Outlines are simplified to about 1 km (wine_regions/outlines/README.md),
# so an estate pin up to 1 km outside its region's outline is consistent
# with it; the distance is logged.
OUTLINE_TOLERANCE_KM = 1.0


def km_to_outline(lng, lat, polygons):
    import math
    best = 1e9
    kx, ky = 111.32 * math.cos(math.radians(lat)), 110.57
    for p in polygons:
        for ring in p:
            for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
                ax, ay, bx, by = (x1 - lng) * kx, (y1 - lat) * ky, (x2 - lng) * kx, (y2 - lat) * ky
                dx, dy = bx - ax, by - ay
                t = max(0, min(1, -(ax * dx + ay * dy) / ((dx * dx + dy * dy) or 1)))
                best = min(best, math.hypot(ax + t * dx, ay + t * dy))
    return best

# Designation (as the research writes it, without "BOB"/"AOP") -> atlas region.
REGION_OF = {
    'Achterhoek-Winterswijk': 'wr_0012',
    'Maasvallei Limburg': 'wr_0013',
    'Mergelland': 'wr_0014',
    'Oolde': 'wr_0015',
    'Rivierenland': 'wr_0016',
    'Schouwen-Duiveland': 'wr_0017',
    'Twente': 'wr_0018',
    'Vijlen': 'wr_0019',
    'Voerendaalse Bergen': 'wr_0020',
    'Hagelandse wijn': 'wr_0127',
    'Haspengouwse wijn': 'wr_0128',
    'Heuvellandse wijn': 'wr_0129',
    'Côtes de Sambre et Meuse': 'wr_0130',
    'Moselle Luxembourgeoise': 'wr_0131',
}
NOT_A_REGION = {'Vlaamse mousserende kwaliteitswijn', 'Vlaamse landwijn', 'Crémant de Wallonie',
                'Vin mousseux de qualité de Wallonie', 'Vin de pays des jardins de Wallonie',
                'Crémant de Luxembourg'}


def fold(s):
    s = unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', ' ', s).strip()


def designations(text):
    out = []
    for part in (text or '').split(';'):
        part = re.sub(r'^(BOB|AOP|BGA|IGP|BGP)\s+', '', part.strip())
        if part:
            out.append(part)
    return out


def municipality(row):
    city = row['city'] or ''
    m = re.search(r'\(([^)]+)\)', city)
    return (m.group(1) if m else city).strip()


def main():
    regions = {r['region_code']: r for r in csv.DictReader(open(REGIONS_LIVE, encoding='utf-8'))}
    outlines = json.load(open(os.path.join(WR, 'outlines.json'), encoding='utf-8'))
    rows = []
    for c in ('nl', 'be', 'lu'):
        rows += list(csv.DictReader(open(os.path.join(HERE, 'research', f'{c}.csv'), encoding='utf-8')))

    out = []
    for i, r in enumerate(rows):
        code = f'vine_{FIRST_CODE + i:04d}'
        des = designations(r['protected_name'])
        unknown = [d for d in des if d not in REGION_OF and d not in NOT_A_REGION]
        specific = sorted({REGION_OF[d] for d in des if d in REGION_OF})
        checks, problems, basis = [], [], []
        if unknown:
            problems.append(f'designation not mapped: {unknown}')
        region = village = None
        village_name = ''
        if len(specific) == 1:
            region = specific[0]
            basis.append(f'designation {[d for d in des if REGION_OF.get(d) == region][0]} -> {region} {regions[region]["name"]}')
        elif len(specific) > 1:
            problems.append(f'two regional designations {specific}')
        else:
            basis.append('only country-wide designations ' + ', '.join(des) + '; no region')
        if region:
            if regions[region]['country_code'] != r['country_code'] and \
                    r['country_code'] not in CROSS_BORDER.get(region, ()):
                problems.append('region in another country')
            lst = region_units(region)
            if lst is None:
                basis.append('region has no commune list, so no village')
            elif len(lst) == 1:
                basis.append('one-unit region, so no village')
            elif r['country_code'] == 'NL':
                m = re.search(r'nummeraanduiding[^0-9]{0,40}(\d{4})\d{12}', r['note'])
                gm = f'NL_GM{m.group(1)}' if m else None
                if gm and gm in lst:
                    village, village_name = gm, lst[gm]['lau_name']
                    basis.append(f'gemeente {m.group(1)} from the BAG nummeraanduiding')
                else:
                    basis.append('no BAG gemeente code matching the list, so no village')
            else:
                muni = fold(municipality(r))
                hits = [u for u, x in lst.items()
                        if muni and muni in [fold(p) for p in x['lau_name'].split('/')]]
                if len(hits) == 1:
                    village, village_name = hits[0], lst[hits[0]]['lau_name']
                    basis.append(f'municipality {municipality(r)} in the region list')
                else:
                    basis.append(f'{municipality(r) or "no town"} is not one municipality of the region list, so no village')
            lat = float(r['latitude']) if r['latitude'] else None
            if lat is not None and region in outlines:
                if in_polygons(float(r['longitude']), lat, outlines[region]):
                    checks.append('pin inside region outline')
                else:
                    d = km_to_outline(float(r['longitude']), lat, outlines[region])
                    if d <= OUTLINE_TOLERANCE_KM:
                        checks.append(f'pin {d:.2f} km outside the simplified outline (within its ~1 km accuracy)')
                    else:
                        problems.append(f'pin {d:.1f} km OUTSIDE region outline')
        held = r['verification_status'] == 'held_back'
        status = ('held_back' if held or problems else
                  'no_region' if not region else 'region_only' if not village else 'ready')
        out.append({
            'vineyard_code': code, 'name': r['official_name'], 'country_code': r['country_code'],
            'protected_name': r['protected_name'], 'city': r['city'], 'address': r['address'],
            'latitude': r['latitude'], 'longitude': r['longitude'], 'website_url': r['website_url'],
            'source_url': r['official_source_url'], 'research_status': r['verification_status'],
            'region_code': region or '', 'region_name': regions[region]['name'] if region else '',
            'village_id': village or '', 'village_name': village_name, 'status': status,
            'basis': '; '.join(basis), 'checks': '; '.join(checks), 'problems': '; '.join(problems),
        })

    with open(os.path.join(HERE, 'batch03_estates.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(out[0]))
        w.writeheader()
        w.writerows(out)
    write_sql([o for o in out if o['status'] != 'held_back'])
    from collections import Counter
    print(Counter(o['status'] for o in out), Counter(o['country_code'] for o in out if o['status'] != 'held_back'))
    for o in out:
        if o['problems'] or o['status'] == 'held_back':
            print(o['vineyard_code'], o['name'], o['status'], o['problems'])


def write_sql(rows):
    vals = []
    for o in rows:
        loc = (f"st_setsrid(st_makepoint({float(o['longitude'])}, {float(o['latitude'])}), 4326)::geography"
               if o['latitude'] else 'null')
        region_text = o['region_name'] or None
        vals.append(f"  ({q(o['vineyard_code'])}, {q(o['name'])}, {q(o['country_code'])}, {q(region_text)}, "
                    f"{q(o['city'])}, {q(o['address'])}, {loc}, {q(o['website_url'])}, "
                    f"{q(o['source_url'])}, {q(o['region_code'])}, {q(o['village_id'])})")
    n = len(rows)
    sql = f"""-- Batch 3 of the wine estates database: {n} Benelux estates named by an
-- official source (Dutch BOB documents, the Flemish list of appellation
-- producers, the Walloon 2016 list, the Luxembourg sector's list).
-- Generated by assemble_batch03.py from batch03_estates.csv; held_back rows
-- stay out. inclusion_reason 'official_register' needs migration
-- 20261101760000. location only where the estate itself publishes a pin.
-- PREPARED -- review before applying.

begin;

create temporary table b3 (
  vineyard_code text, name text, country_code char(2), region text, city text,
  address text, location geography(Point,4326), website_url text,
  source_url text, region_code text, commune_code text
) on commit drop;

insert into b3 values
{(','+chr(10)).join(vals)};

do $$
begin
  if exists (select 1 from public.vineyards v join b3 using (vineyard_code)) then
    raise exception 'a batch 3 code already exists; refusing to insert twice';
  end if;
end $$;

insert into public.vineyards (vineyard_code, name, country_code, region, city, address, location,
  website_url, inclusion_reason, source_url, wine_region_id, commune_code)
select b.vineyard_code, b.name, b.country_code, b.region, b.city, b.address, b.location,
  b.website_url, 'official_register', b.source_url, r.id, b.commune_code
from b3 b left join public.wine_regions r on r.region_code = b.region_code;

do $$
begin
  if (select count(*) from public.vineyards v join pg_temp.b3 b using (vineyard_code)) <> {n} then
    raise exception 'expected {n} new estates';
  end if;
end $$;

commit;
"""
    open(os.path.join(HERE, 'prepared_batch03.sql'), 'w', encoding='utf-8').write(sql)


if __name__ == '__main__':
    main()
