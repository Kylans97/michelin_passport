#!/usr/bin/env python3
"""Build the restaurant-cuisines staging files and prepared SQL (2026-11-01).

  python3 -I _tools/build.py        (run from restaurant_cuisines_2026/)

Inputs (all in this folder):
  _source/restaurants_LIVE_20261102.csv     read-only export of production
  _source/cuisines_LIVE_20261102.csv        read-only export, with use counts
  _source/michelin_restaurant_pages_20261101.jsonl   fetch_michelin.py
  _source/w50b_style_20261101.jsonl                  fetch_w50b.py
  vocabulary_families.csv     hand-curated: MICHELIN label -> family
  legacy_label_map.csv        hand-curated: old cuisines.name -> MICHELIN label
  w50b_style_map.csv          hand-reviewed: 50 Best style line -> MICHELIN label(s)

Outputs:
  cuisines_canonical.csv          the new vocabulary, with family and use counts
  cuisines_legacy_resolution.csv  every old cuisines row: kept / renamed / removed
  restaurant_cuisines_staging.csv every link to insert, with evidence
  held_back.csv                   every restaurant/source left empty, and why
  prepared_restaurant_cuisines.sql

Rules: identity is the stored URL (MICHELIN or 50 Best), never a name. The
canonical vocabulary is exactly the set of labels MICHELIN's own pages use;
a legacy or 50 Best value that is not one of them is left empty and logged.
"""
import collections, csv, json, re, sys, urllib.parse

VERIFIED_ON = '2026-11-01'
SRC = '_source/'


def read_csv(p):
    return list(csv.DictReader(open(p, encoding='utf-8')))


def write_csv(p, header, rows):
    with open(p, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def slug(name):
    return re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')


def q(s):
    return 'null' if s is None else "'" + s.replace("'", "''") + "'"


def tail_segment(url):
    return urllib.parse.urlparse(url or '').path.rstrip('/').rsplit('/', 1)[-1]


restaurants = {r['id']: r for r in read_csv(SRC + 'restaurants_LIVE_20261102.csv')}
legacy_cuisines = read_csv(SRC + 'cuisines_LIVE_20261102.csv')
families = {r['michelin_label']: r['family_slug'] for r in read_csv('vocabulary_families.csv')}
legacy_map = {r['legacy_name']: r for r in read_csv('legacy_label_map.csv')}
w50b_map = {r['restaurant_code']: r for r in read_csv('w50b_style_map.csv')}

links = []      # (restaurant_id, source, position, cuisine, source_url, source_label)
held = []       # (restaurant_code, country, source, url, reason, detail)

# ---- MICHELIN ---------------------------------------------------------------
michelin_pages = [json.loads(l) for l in open(SRC + 'michelin_restaurant_pages_20261101.jsonl', encoding='utf-8')]
seen = set()
michelin_ok = set()
for p in michelin_pages:
    if p['restaurant_id'] in seen:
        continue
    seen.add(p['restaurant_id'])
    code, cc = p['restaurant_code'], p['country_code']
    if p['status'] != 200:
        held.append((code, cc, 'michelin', p['url'], f"HTTP {p['status']}", p['final_url']))
        continue
    # Identity: the page we landed on must be the restaurant we asked for.
    # MICHELIN moves pages between region paths (istanbul -> istanbul-province)
    # but keeps the restaurant slug; a different slug is a different page.
    if tail_segment(p['final_url']) != tail_segment(p['fetch_url']) or '/restaurant/' not in p['final_url']:
        held.append((code, cc, 'michelin', p['url'], 'redirected to another page', p['final_url']))
        continue
    if p.get('ld_url') and tail_segment(p['ld_url']) != tail_segment(p['fetch_url']):
        held.append((code, cc, 'michelin', p['url'], 'JSON-LD url names another page', p['ld_url']))
        continue
    if not p['label']:
        held.append((code, cc, 'michelin', p['url'], 'no Cuisine label on page', p.get('ld_cuisine') or ''))
        continue
    parts = [x.strip() for x in p['label'].split(',') if x.strip()]
    if p['ld_cuisine'] and parts[0] != p['ld_cuisine'].strip():
        held.append((code, cc, 'michelin', p['url'], 'label and JSON-LD disagree', f"{p['label']} | {p['ld_cuisine']}"))
        continue
    if len(parts) > 2 or len(set(parts)) != len(parts):
        held.append((code, cc, 'michelin', p['url'], 'unexpected label shape', p['label']))
        continue
    for i, c in enumerate(parts, 1):
        links.append((p['restaurant_id'], 'michelin', i, c, p['fetch_url'], p['label']))
    michelin_ok.add(p['restaurant_id'])

vocabulary = collections.Counter(l[3] for l in links)
unmapped = sorted(c for c in vocabulary if c not in families)
if unmapped:
    sys.exit('MICHELIN labels without a family in vocabulary_families.csv: ' + '; '.join(unmapped))
not_seen = sorted(c for c in families if c not in vocabulary)

# ---- World's 50 Best --------------------------------------------------------
w50b_ok = set()
deeper = {}
for line in open(SRC + 'w50b_style_deeper_20261101.jsonl', encoding='utf-8'):
    d = json.loads(line)
    if d['style']:
        deeper[d['restaurant_id']] = d
for line in open(SRC + 'w50b_style_20261101.jsonl', encoding='utf-8'):
    p = json.loads(line)
    if not p['style'] and p['restaurant_id'] in deeper:
        d = deeper[p['restaurant_id']]
        p = dict(p, style=d['style'], evidence_page=d['evidence_page'], neighbours_tried=d['pages_tried'])
    elif not p['style']:
        p['neighbours_tried'] = f"{p['neighbours_tried']} + deeper pass"
    code, cc = p['restaurant_code'], p['country_code']
    if p['status'] != 200:
        held.append((code, cc, 'worlds_50_best', p['url'], f"HTTP {p['status']}", ''))
        continue
    if not p.get('style'):
        held.append((code, cc, 'worlds_50_best', p['url'], 'no card with this URL on neighbouring pages',
                     f"{p['neighbours_tried']} pages tried"))
        continue
    m = w50b_map.get(code)
    if m is None or m['style'] != p['style']:
        sys.exit(f'w50b_style_map.csv has no reviewed row for {code} / {p["style"]!r}')
    names = [x.strip() for x in m['cuisines'].split(';') if x.strip()]
    if not names:
        held.append((code, cc, 'worlds_50_best', p['url'], 'style line names no cuisine', f"{p['style']} — {m['note']}"))
        continue
    bad = [n for n in names if n not in vocabulary]
    if bad:
        held.append((code, cc, 'worlds_50_best', p['url'], 'mapped label not in MICHELIN vocabulary', '; '.join(bad)))
        continue
    for i, c in enumerate(names, 1):
        links.append((p['restaurant_id'], 'worlds_50_best', i, c, p['evidence_page'], p['style']))
    w50b_ok.add(p['restaurant_id'])

# ---- Legacy -----------------------------------------------------------------
# Only for restaurants neither source covers, and only where the old label is
# a MICHELIN label already, or a 1:1 translation of one.
legacy_ok = set()
for rid, r in restaurants.items():
    if rid in michelin_ok or rid in w50b_ok or r['cuisine'] in ('', 'NULL'):
        continue
    m = legacy_map[r['cuisine']]
    target = m['canonical_name']
    if target not in vocabulary:
        held.append((r['restaurant_code'], r['country_code'], 'legacy', '', 'old label is not a MICHELIN label',
                     r['cuisine']))
        continue
    links.append((rid, 'legacy', 1, target, None, r['cuisine']))
    legacy_ok.add(rid)

# ---- Outputs ----------------------------------------------------------------
links.sort(key=lambda l: (restaurants[l[0]]['restaurant_code'], l[1], l[2]))
canonical = sorted(vocabulary)
effective = {}
for l in links:
    rank = {'michelin': 1, 'worlds_50_best': 2, 'legacy': 3}[l[1]]
    effective.setdefault(l[0], rank)
    effective[l[0]] = min(effective[l[0]], rank)
eff_use = collections.Counter(l[3] for l in links if {'michelin': 1, 'worlds_50_best': 2, 'legacy': 3}[l[1]] == effective[l[0]])

write_csv('cuisines_canonical.csv', ['name', 'slug', 'family_slug', 'michelin_page_uses', 'effective_restaurants'],
          [(c, slug(c), families[c], vocabulary[c], eff_use[c]) for c in canonical])
legacy_rows = []
for lc in legacy_cuisines:
    n = lc['name']
    if n in vocabulary:
        action = 'kept (is a MICHELIN label)'
    else:
        tgt = legacy_map[n]['canonical_name']
        action = f'removed; its restaurants now use {tgt!r} (translation)' if tgt in vocabulary and tgt != n \
            else 'removed (not a MICHELIN label)'
    legacy_rows.append((lc['id'], n, lc['n'], action))
write_csv('cuisines_legacy_resolution.csv', ['legacy_id', 'legacy_name', 'restaurants_before', 'resolution'], legacy_rows)
write_csv('restaurant_cuisines_staging.csv',
          ['restaurant_id', 'restaurant_code', 'country_code', 'source', 'position', 'cuisine', 'source_url',
           'source_label', 'verified_on'],
          [(l[0], restaurants[l[0]]['restaurant_code'], restaurants[l[0]]['country_code'], l[1], l[2], l[3],
            l[4] or '', l[5], VERIFIED_ON) for l in links])
held.sort()
write_csv('held_back.csv', ['restaurant_code', 'country_code', 'source', 'url', 'reason', 'detail'], held)

# ---- Prepared SQL -----------------------------------------------------------
n_rest = len(restaurants)
n_legacy = len(legacy_cuisines)
covered = len(set(l[0] for l in links))
lost = [rid for rid, r in restaurants.items() if r['cuisine'] not in ('', 'NULL') and rid not in effective]
keep_ids = [lc['id'] for lc in legacy_cuisines if lc['name'] in vocabulary]
fam_values = ',\n'.join(f'  ({q(c)}, {q(families[c])})' for c in canonical)
link_values = ',\n'.join(f"  ({q(l[0])}::uuid, {q(l[1])}, {l[2]}, {q(l[3])}, {q(l[4])}, {q(l[5])})" for l in links)

sql = f"""-- Restaurant cuisines: MICHELIN vocabulary and every link. Prepared 2026-11-01.
-- Generated by _tools/build.py — do not hand-edit; rerun the build.
--
-- Needs 20261101150000_add_restaurant_cuisines.sql applied first, and must
-- run before 20261101160000_cuisines_slug_unique.sql.
--
-- What it does, in one transaction:
--   1. Guards: production still looks exactly like the export this was built
--      from ({n_rest} restaurants, {n_legacy} cuisines rows, no
--      restaurant_cuisines rows yet).
--   2. Adds the {len(canonical)} MICHELIN labels that are missing and sets
--      every label's family.
--   3. Inserts {len(links)} restaurant_cuisines rows ({len(michelin_ok)} restaurants
--      from MICHELIN, {len(w50b_ok)} from World's 50 Best, {len(legacy_ok)} legacy).
--      The trigger sets restaurants.cuisine_id to each effective position 1.
--   4. Clears cuisine_id on the {len(lost)} restaurants whose only cuisine was an old
--      label that is not a MICHELIN one (each listed in held_back.csv).
--   5. Removes every cuisines row that is not a MICHELIN label.
--   6. Checks the end state, or rolls everything back.

begin;

do $$
begin
  if (select count(*) from public.restaurants) <> {n_rest} then
    raise exception 'restaurants count changed since the export';
  end if;
  if (select count(*) from public.cuisines) <> {n_legacy} then
    raise exception 'cuisines count changed since the export';
  end if;
  if exists (select 1 from public.restaurant_cuisines) then
    raise exception 'restaurant_cuisines is not empty';
  end if;
end $$;

create temp table _vocab (name text primary key, family_slug text not null) on commit drop;
insert into _vocab values
{fam_values};

do $$
begin
  if exists (select 1 from _vocab v left join public.cuisine_families f on f.slug = v.family_slug where f.id is null) then
    raise exception 'a family_slug is not in cuisine_families';
  end if;
end $$;

insert into public.cuisines (name)
select v.name from _vocab v
where not exists (select 1 from public.cuisines c where c.name = v.name);

update public.cuisines c
   set family_id = f.id
  from _vocab v
  join public.cuisine_families f on f.slug = v.family_slug
 where c.name = v.name;

create temp table _links (
  restaurant_id uuid, source text, position smallint, cuisine text, source_url text, source_label text
) on commit drop;
insert into _links values
{link_values};

do $$
begin
  if exists (select 1 from _links l left join public.restaurants r on r.id = l.restaurant_id where r.id is null) then
    raise exception 'a staged restaurant_id is not in restaurants';
  end if;
end $$;

insert into public.restaurant_cuisines
  (restaurant_id, cuisine_id, position, source, source_url, source_label, verified_on)
select l.restaurant_id, c.id, l.position, l.source, l.source_url, l.source_label, date '{VERIFIED_ON}'
from _links l
join public.cuisines c on c.name = l.cuisine;

update public.restaurants r
   set cuisine_id = null
 where r.cuisine_id is not null
   and not exists (select 1 from public.restaurant_cuisines rc where rc.restaurant_id = r.id);

delete from public.cuisines c
 where not exists (select 1 from _vocab v where v.name = c.name);

do $$
begin
  if (select count(*) from public.restaurant_cuisines) <> {len(links)} then
    raise exception 'restaurant_cuisines row count is not {len(links)}';
  end if;
  if (select count(*) from public.cuisines) <> {len(canonical)} then
    raise exception 'cuisines is not exactly the {len(canonical)} MICHELIN labels';
  end if;
  if exists (select 1 from public.cuisines where family_id is null) then
    raise exception 'a cuisine has no family';
  end if;
  if (select count(*) from public.restaurants where cuisine_id is not null) <> {covered} then
    raise exception 'restaurants with a cuisine_id is not {covered}';
  end if;
  if exists (
    select 1 from public.restaurants r
    join public.restaurant_cuisines_effective e on e.restaurant_id = r.id and e.position = 1
    where r.cuisine_id is distinct from e.cuisine_id
  ) then
    raise exception 'cuisine_id out of step with the effective position-1 cuisine';
  end if;
end $$;

commit;
"""
open('prepared_restaurant_cuisines.sql', 'w', encoding='utf-8').write(sql)

two = sum(1 for l in links if l[1] == 'michelin' and l[2] == 2)
print(f'restaurants {n_rest}; covered {covered} (before: {sum(1 for r in restaurants.values() if r["cuisine"] not in ("", "NULL"))})')
print(f'  michelin {len(michelin_ok)} (two cuisines: {two}); w50b {len(w50b_ok)}; legacy {len(legacy_ok)}')
print(f'  w50b rows that are a cross-check behind MICHELIN: {len(w50b_ok & michelin_ok)}')
print(f'canonical labels {len(canonical)}; kept legacy ids {len(keep_ids)}; removed {n_legacy - len(keep_ids)}')
print(f'old label lost with no replacement: {len(lost)}')
print(f'held back {len(held)}:', collections.Counter((h[2], h[4]) for h in held).most_common())
print('vocabulary_families rows not seen on any MICHELIN page:', not_seen)
