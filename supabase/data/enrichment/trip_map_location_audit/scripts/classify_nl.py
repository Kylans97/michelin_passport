"""Classify Dutch seed rows: BAG point for street + number, corroborated by
an OSM eating place found by name in the same city."""
import csv, json, math, re, sys
sys.path.insert(0, '.')
seed, gcache, bcache, out = sys.argv[1:5]
g = json.load(open(gcache)); b = json.load(open(bcache))
def hav(a, b_, c, d):
    R = 6371000; p1, p2 = math.radians(a), math.radians(c)
    h = math.sin((p2-p1)/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(math.radians(d-b_)/2)**2
    return 2*R*math.asin(math.sqrt(h))
def parse(addr):
    first, rest = addr.split(',', 1)
    pc = re.search(r'\b(\d{4})\s?([A-Z]{2})\b', rest)
    town = rest[pc.end():].strip() if pc else rest.strip()
    m = re.search(r'(\d+)\s*([A-Za-z]?)(?:-(\d+))?\s*$', first.strip())
    street = first[:m.start()].strip() if m else first
    return (pc.group(1) + pc.group(2)) if pc else None, (int(m.group(1)) if m else None), (m.group(2) if m else ''), street, town
def ns(s):
    s = s.lower().replace('st. ', 'sint ')
    return re.sub(r'[^a-z0-9]', '', s)
EAT = {('amenity', 'restaurant'), ('amenity', 'cafe'), ('amenity', 'bar'), ('amenity', 'pub'), ('tourism', 'hotel')}
fields = ['restaurant_code', 'country_code', 'name', 'stored_address', 'current_lat', 'current_lng', 'latitude', 'longitude',
          'moved_m', 'coordinate_quality', 'bag_address', 'bag_id', 'osm_venue', 'source_url', 'certainty', 'notes']
w = csv.DictWriter(open(out, 'w'), fieldnames=fields); w.writeheader()
for r in csv.DictReader(open(seed)):
    if r['cc'] != 'NL': continue
    pc, nr, letter, street, town = parse(r['address'])
    docs = [d for d in b[f'{street}|{nr}|{town}'] if ns(d['straatnaam']) == ns(street) and d['huisnummer'] == nr]
    row = dict(restaurant_code=r['code'], country_code='NL', name=r['name'], stored_address=r['address'],
               current_lat=r['lat'], current_lng=r['lng'], latitude='', longitude='', moved_m='', bag_address='',
               bag_id='', osm_venue='', source_url='', certainty='unclear', notes='')
    towns = {d['woonplaatsnaam'] for d in docs}
    if len(towns) > 1:
        same = [d for d in docs if d.get('postcode', '')[:4] == (pc or '')[:4] or ns(d['woonplaatsnaam']) == ns(town)]
        if len({d['woonplaatsnaam'] for d in same}) == 1: docs = same
    if not docs:
        row.update(coordinate_quality='BAG_NOT_FOUND', notes=f'No BAG address {street} {nr} near {town}. Address itself needs checking.')
        w.writerow(row); continue
    if len({d['woonplaatsnaam'] for d in docs}) > 1:
        row.update(coordinate_quality='AMBIGUOUS', notes='Street and number exist in more than one town: ' + '; '.join(sorted({d['weergavenaam'] for d in docs})))
        w.writerow(row); continue
    pick = [d for d in docs if (d.get('huisletter', '') or '').lower() == letter.lower() and not d.get('huisnummertoevoeging')] or docs
    pts = [tuple(map(float, re.findall(r'[-\d.]+', d['centroide_ll']))) for d in pick]
    lng, lat = pts[0]
    spread = max(hav(lat, lng, p[1], p[0]) for p in pts)
    if spread > 40:
        row.update(coordinate_quality='AMBIGUOUS', notes=f'{len(pick)} BAG units at this number, {round(spread)} m apart: ' + '; '.join(d['weergavenaam'] for d in pick[:6]))
        w.writerow(row); continue
    d = pick[0]
    V = g.get(json.dumps({'q': f"{r['name']}, {r['city']}", 'countrycodes': 'nl', 'format': 'jsonv2', 'addressdetails': 1, 'limit': 5}, sort_keys=True), [])
    ven = [(round(hav(lat, lng, float(v['lat']), float(v['lon']))), v) for v in V if (v.get('category'), v.get('type')) in EAT]
    near = [x for x in ven if x[0] <= 150]; far = [x for x in ven if x[0] > 150]
    pc_ok = d.get('postcode') == pc
    row.update(bag_address=d['weergavenaam'], bag_id=d['id'],
               source_url=f"https://api.pdok.nl/bzk/locatieserver/search/v3_1/lookup?id={d['id']}")
    notes = [] if pc_ok else [f'Stored postcode {pc} is wrong; BAG has {d.get("postcode", "none")}.']
    if len(pick) > 1: notes.append(f'{len(pick)} BAG units at this number, within {round(spread)} m; first taken.')
    def accept(q):
        row.update(latitude=f'{lat:.7f}', longitude=f'{lng:.7f}', moved_m=round(hav(float(r['lat']), float(r['lng']), lat, lng)), coordinate_quality=q)
    if near:
        m, v = near[0]
        row['osm_venue'] = f"{v['osm_type']}/{v['osm_id']} {v.get('name')} ({m} m)"
        accept('VENUE_EXACT'); row['certainty'] = 'confirmed'
    elif far:
        m, v = far[0]
        row['osm_venue'] = f"{v['osm_type']}/{v['osm_id']} {v.get('name')} ({m} m)"
        row['coordinate_quality'] = 'CONFLICT'
        notes.append('OSM has an eating place by this name over 150 m from the address: moved, a namesake, or stale OSM. Held back.')
    else:
        accept('ADDRESS_EXACT')
        row['certainty'] = 'confirmed' if pc_ok else 'unclear'
        notes.append('No OSM venue by this name to corroborate.' + ('' if pc_ok else ' Postcode disagreement leaves the address itself in doubt.'))
    row['notes'] = ' '.join(notes)
    w.writerow(row)
