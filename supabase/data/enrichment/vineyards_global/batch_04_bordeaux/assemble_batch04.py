"""Batch 4: the Bordeaux classifications (1855 Médoc, 1855 Sauternes and
Barsac, Graves 1959, Saint-Émilion 2022).

Reads research/*.csv (one row per estate per list, from the official list
named in official_source_url) and writes batch04_estates.csv,
batch04_recognitions.csv and prepared_batch04.sql for review.

Identity, never by name:
  * an estate already in the catalogue is linked by the existing_code the
    research confirmed by website domain or address;
  * the same château on two different lists in this batch (Haut-Brion:
    1855 and Graves) is one estate only when both rows give the same
    website domain AND the same printed name. A shared domain alone is not
    identity: owner groups run one site for several classified châteaux
    (Lafite and Duhart-Milon, Léoville and Langoa Barton), and two entries
    on one list are always two estates.
Display name: the estate's own spelling, read from its own site
(names/own_names_*.csv; product owner, 2026-11-25: "use the estates own
spelling"), used only when it is the same name as the official print once
accents, case and punctuation are folded. Otherwise, or where the site gave
none, the print in title case. The printed form is kept in aliases for
search.
Region: all Bordeaux (wr_0002); village = the commune the estate's address
gives, matched to exactly one unit of the Bordeaux list.
class_order sorts within a list (CLASS_ORDER); a printed class not in it
stops the script.

Run from the repo root:
    python3 -I supabase/data/enrichment/vineyards_global/batch_04_bordeaux/assemble_batch04.py
"""
import csv
import glob
import json
import os
import re
import sys
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'batch_02_w50b'))
sys.path.insert(0, os.path.join(HERE, '..', 'batch_03_benelux'))
from assemble_batch02 import in_polygons, region_units, q, WR  # noqa: E402
from assemble_batch03 import fold, km_to_outline, OUTLINE_TOLERANCE_KM  # noqa: E402

FIRST_CODE = 207
REGION = 'wr_0002'
CLASS_ORDER = {
    'bordeaux_1855_medoc': {'Premier Cru': 1, 'Second Cru': 2, 'Troisième Cru': 3,
                            'Quatrième Cru': 4, 'Cinquième Cru': 5},
    'bordeaux_1855_sauternes': {'Premier Cru Supérieur': 1, 'Premier Cru': 2, 'Second Cru': 3},
    'graves_1959': {'Cru Classé de Graves': 1, 'Cru Classé de Graves (rouge et blanc)': 1},
    'saint_emilion': {'Premier Grand Cru Classé A': 1, 'Premier Grand Cru Classé B': 2,
                      'Grand Cru Classé': 3},
}
SMALL = {'de', 'du', 'des', 'la', 'le', 'les', 'et', 'en'}


def display_name(printed):
    def word(w, first):
        if not (w.isupper() and len(w) > 1):
            return w
        if "'" in w or '’' in w:
            head, _, tail = w.replace('’', "'").partition("'")
            return head.lower() + "'" + word(tail, True)
        parts = w.split('-')
        out = [p[:1] + p[1:].lower() for p in parts]
        joined = '-'.join(out)
        return joined.lower() if (not first and joined.lower() in SMALL) else joined
    words = printed.split()
    return ' '.join(word(w, i == 0) for i, w in enumerate(words))


def own_names():
    out = {}
    for f in sorted(glob.glob(os.path.join(HERE, 'names', 'own_names_*.csv'))):
        for r in csv.DictReader(open(f, encoding='utf-8')):
            if r['own_name'].strip():
                # One apostrophe for all names: the lists and sites mix ' and ’.
                out[r['vineyard_code']] = (r['own_name'].strip().replace('’', "'"), r['source_url'])
    return out


def domain(url):
    host = urlparse(url or '').netloc.lower()
    return host[4:] if host.startswith('www.') else host


def main():
    outline = json.load(open(os.path.join(WR, 'outlines.json'), encoding='utf-8'))[REGION]
    units = region_units(REGION)
    rows = []
    for f in sorted(glob.glob(os.path.join(HERE, 'research', '*.csv'))):
        rows += list(csv.DictReader(open(f, encoding='utf-8')))

    estates, by_key, recs = [], {}, []
    for r in rows:
        order = CLASS_ORDER[r['scheme']].get(r['class'])
        if order is None:
            raise SystemExit(f"class not in CLASS_ORDER: {r['scheme']} {r['class']}")
        if r['verification_status'] == 'held_back':
            recs.append({**r, 'class_order': order, 'vineyard_code': '', 'status': 'held_back'})
            continue
        same = None
        if not r['existing_code'] and r['website_url']:
            for e in estates:
                if any(x['scheme'] != r['scheme'] and domain(x['website_url']) == domain(r['website_url'])
                       and fold(x['official_name']) == fold(r['official_name']) for x in e['rows']):
                    same = e
                    break
        key = r['existing_code'] or (f"same:{id(same)}" if same else f"row:{len(rows)}:{r['scheme']}:{r['official_name']}")
        if same is not None:
            by_key[key] = same
        if key not in by_key:
            code = r['existing_code'] or f'vine_{FIRST_CODE + sum(1 for e in estates if not e["existing"]):04d}'
            e = {'vineyard_code': code, 'existing': bool(r['existing_code']), 'rows': []}
            by_key[key] = e
            estates.append(e)
        by_key[key]['rows'].append(r)
        recs.append({**r, 'class_order': order, 'vineyard_code': by_key[key]['vineyard_code'], 'status': 'ok'})

    owns = own_names()
    out = []
    for e in estates:
        r = e['rows'][0]
        name = display_name(r['official_name'])
        name_note = 'print, title case'
        own = owns.get(e['vineyard_code'])
        if own and not e['existing']:
            if fold(own[0]) == fold(r['official_name'].replace('’', "'")):
                name, name_note = own[0], 'own spelling, ' + own[1]
            else:
                name_note = 'own spelling "' + own[0] + '" differs from the print beyond accents and case; print kept'
        printed = sorted({x['official_name'] for x in e['rows']} - {name})
        problems, checks = [], []
        village = ''
        if not e['existing']:
            muni = fold(r['city'])
            hits = [u for u, x in units.items() if muni and muni == fold(x['lau_name'])]
            if len(hits) == 1:
                village = hits[0]
            if r['latitude']:
                lat, lng = float(r['latitude']), float(r['longitude'])
                if in_polygons(lng, lat, outline):
                    checks.append('pin inside Bordeaux outline')
                else:
                    d = km_to_outline(lng, lat, outline)
                    (checks if d <= OUTLINE_TOLERANCE_KM else problems).append(f'pin {d:.2f} km outside outline')
        if len(e['rows']) > 1:
            checks.append('same estate on ' + ', '.join(x['scheme'] for x in e['rows']) + ' (same website domain and printed name)')
        out.append({
            'vineyard_code': e['vineyard_code'], 'existing': 'yes' if e['existing'] else '',
            'name': name, 'aliases': '; '.join(printed), 'city': r['city'], 'address': r['address'],
            'latitude': r['latitude'], 'longitude': r['longitude'], 'website_url': r['website_url'],
            'source_url': r['official_source_url'], 'village_id': village,
            'village_name': units[village]['lau_name'] if village else '',
            'name_source': name_note,
            'research_status': ', '.join(sorted({x['verification_status'] for x in e['rows']})),
            'checks': '; '.join(checks), 'problems': '; '.join(problems),
        })

    with open(os.path.join(HERE, 'batch04_estates.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(out[0]))
        w.writeheader()
        w.writerows(out)
    with open(os.path.join(HERE, 'batch04_recognitions.csv'), 'w', newline='', encoding='utf-8') as f:
        cols = ['vineyard_code', 'official_name', 'scheme', 'class', 'class_order', 'edition', 'official_source_url', 'status']
        w = csv.DictWriter(f, fieldnames=cols, extrasaction='ignore')
        w.writeheader()
        w.writerows(recs)
    if any(o['problems'] for o in out):
        for o in out:
            if o['problems']:
                print('PROBLEM', o['vineyard_code'], o['name'], o['problems'])
        raise SystemExit('fix problems first')
    write_sql(out, [x for x in recs if x['status'] == 'ok'])
    new = [o for o in out if not o['existing']]
    print(len(new), 'new estates,', len(out) - len(new), 'existing,', sum(1 for o in new if o['village_id']), 'with village;',
          sum(1 for x in recs if x['status'] == 'ok'), 'recognitions,', sum(1 for x in recs if x['status'] == 'held_back'), 'held back')
    for o in out:
        if o['checks'].startswith('same') or 'same estate' in o['checks']:
            print('MERGED', o['vineyard_code'], o['name'], o['checks'])


def write_sql(estates, recs):
    new = [o for o in estates if not o['existing']]
    ev = []
    for o in new:
        loc = (f"st_setsrid(st_makepoint({float(o['longitude'])}, {float(o['latitude'])}), 4326)::geography"
               if o['latitude'] else 'null')
        aliases = "'{}'::text[]" if not o['aliases'] else 'array[' + ', '.join(q(a) for a in o['aliases'].split('; ')) + ']'
        ev.append(f"  ({q(o['vineyard_code'])}, {q(o['name'])}, {aliases}, {q(o['city'])}, {q(o['address'])}, {loc}, "
                  f"{q(o['website_url'])}, {q(o['source_url'])}, {q(o['village_id'])})")
    rv = [f"  ({q(x['vineyard_code'])}, {q(x['scheme'])}, {q(x['class'])}, {x['class_order']}, {int(x['edition'][:4])}, {q(x['official_source_url'])})"
          for x in recs]
    sql = f"""-- Batch 4 of the wine estates database: the Bordeaux classifications.
-- {len(new)} new estates and {len(recs)} recognitions (1855 Médoc, 1855 Sauternes and
-- Barsac, Graves 1959, Saint-Émilion 2022), some on estates already in the
-- catalogue. Generated by assemble_batch04.py; held-back rows stay out.
-- Needs migration 20261101830000 (vineyard_recognitions).
-- PREPARED -- review before applying.

begin;

create temporary table b4e (
  vineyard_code text, name text, aliases text[], city text, address text,
  location geography(Point,4326), website_url text, source_url text, commune_code text
) on commit drop;
insert into b4e values
{(','+chr(10)).join(ev)};

create temporary table b4r (
  vineyard_code text, scheme text, class text, class_order smallint, edition smallint, source_url text
) on commit drop;
insert into b4r values
{(','+chr(10)).join(rv)};

do $$
begin
  if exists (select 1 from public.vineyards v join b4e using (vineyard_code)) then
    raise exception 'a batch 4 code already exists; refusing to insert twice';
  end if;
end $$;

insert into public.vineyards (vineyard_code, name, aliases, country_code, region, city, address,
  location, website_url, inclusion_reason, source_url, wine_region_id, commune_code)
select b.vineyard_code, b.name, b.aliases, 'FR', 'Bordeaux', b.city, b.address, b.location,
  b.website_url, 'official_classification', b.source_url,
  (select id from public.wine_regions where region_code = '{REGION}'), b.commune_code
from b4e b;

insert into public.vineyard_recognitions (vineyard_id, scheme, class, class_order, edition, source_url)
select v.id, r.scheme, r.class, r.class_order, r.edition, r.source_url
from b4r r join public.vineyards v using (vineyard_code);

do $$
begin
  if (select count(*) from public.vineyard_recognitions) <> {len(recs)} then
    raise exception 'expected {len(recs)} recognitions';
  end if;
end $$;

commit;
"""
    open(os.path.join(HERE, 'prepared_batch04.sql'), 'w', encoding='utf-8').write(sql)


if __name__ == '__main__':
    main()
