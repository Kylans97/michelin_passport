"""Geocode researched current addresses and merge with the first pass into
one staged file. Coordinates are written only for a confirmed address with a
house-level hit: BAG (exact postcode + house number) in NL, OSM with the
same house number and postcode elsewhere."""
import csv, glob, json, math, os, re, time, urllib.parse, urllib.request
CACHE = 'final_cache.json'
cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
def fetch(url, pause):
    if url in cache: return cache[url]
    req = urllib.request.Request(url, headers={'User-Agent': 'MantelierLocationQA/1.0 (research)'})
    cache[url] = json.load(urllib.request.urlopen(req, timeout=20))
    json.dump(cache, open(CACHE, 'w')); time.sleep(pause)
    return cache[url]
def hav(a, b, c, d):
    R = 6371000; p1, p2 = math.radians(a), math.radians(c)
    h = math.sin((p2-p1)/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(math.radians(d-b)/2)**2
    return 2*R*math.asin(math.sqrt(h))
norm = lambda s: re.sub(r'[^0-9A-Z]', '', (s or '').upper())
def first_number(addr):
    first = addr.split(',')[0]
    m = re.search(r'(\d+)\s*([A-Za-z]?)\b', first) if not re.match(r'^\d', first.strip()) else re.match(r'\s*(\d+)\s*([A-Za-z]?)\b', first)
    return (m.group(1), m.group(2)) if m else (None, '')
def bag(addr):
    pc = re.search(r'\b(\d{4})\s?([A-Z]{2})\b', addr)
    first = addr.split(',')[0]
    m = re.search(r'(\d+)\s*([A-Za-z]?)(?:\s*-\s*\d+)?\s*$', first.strip())
    if not pc or not m: return None, 'no postcode or house number to look up'
    q = urllib.parse.urlencode([('q', '*'), ('fq', 'type:adres'), ('fq', f'postcode:{pc.group(1)}{pc.group(2)}'),
                                ('fq', f'huisnummer:{m.group(1)}'), ('rows', 20),
                                ('fl', 'weergavenaam,straatnaam,huisletter,huisnummertoevoeging,centroide_ll,id')])
    docs = fetch('https://api.pdok.nl/bzk/locatieserver/search/v3_1/free?' + q, 0.3)['response']['docs']
    street = first[:m.start()].strip().lower().replace('st. ', 'sint ')
    docs = [d for d in docs if re.sub(r'[^a-z]', '', d['straatnaam'].lower()) == re.sub(r'[^a-z]', '', street)] or docs
    if not docs: return None, 'postcode + house number not in BAG'
    pick = [d for d in docs if (d.get('huisletter') or '').lower() == m.group(2).lower()] or docs
    pts = [tuple(map(float, re.findall(r'[-\d.]+', d['centroide_ll']))) for d in pick]
    if max(hav(pts[0][1], pts[0][0], p[1], p[0]) for p in pts) > 40: return None, 'several BAG units far apart'
    return (pts[0][1], pts[0][0], f"BAG {pick[0]['weergavenaam']}", f"https://api.pdok.nl/bzk/locatieserver/search/v3_1/lookup?id={pick[0]['id']}"), ''
def osm(addr, cc):
    q = urllib.parse.urlencode({'q': addr, 'countrycodes': cc.lower(), 'format': 'jsonv2', 'addressdetails': 1, 'limit': 5})
    res = fetch('https://nominatim.openstreetmap.org/search?' + q, 1.2)
    nr, _ = first_number(addr)
    pcm = re.search(r'\b\d{3}\s?\d{2}\b|\b\d{4,5}\b|\b[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}\b', addr.split(',', 1)[-1])
    for a in res:
        ad = a.get('address', {})
        nums = [norm(x) for x in re.split(r'[;,]', ad.get('house_number', ''))]
        if nr and norm(nr) in nums and (not pcm or not ad.get('postcode') or norm(ad['postcode']) == norm(pcm.group(0))):
            return (float(a['lat']), float(a['lon']), f"OSM {a['osm_type']}/{a['osm_id']} {a.get('display_name')}",
                    f"https://www.openstreetmap.org/{a['osm_type']}/{a['osm_id']}"), ''
    return None, 'no house-level OSM hit with the same number and postcode'
seed = {r['code']: r for r in csv.DictReader(open('seed.csv'))}
first = {r['restaurant_code']: r for r in csv.DictReader(open('staged_nl.csv'))}
research = {}
for f in sorted(glob.glob('research/batch_*_out.csv')):
    for r in csv.DictReader(open(f)): research[r['restaurant_code']] = r
F = ['restaurant_code', 'country_code', 'name', 'stored_address', 'current_address', 'status', 'current_lat', 'current_lng',
     'latitude', 'longitude', 'moved_m', 'coordinate_source', 'source_url', 'address_source_url', 'second_source_url',
     'certainty', 'notes']
out = []
for code, s in seed.items():
    row = dict.fromkeys(F, ''); row.update(restaurant_code=code, country_code=s['cc'], name=s['name'],
                                         stored_address=s['address'], current_lat=s['lat'], current_lng=s['lng'])
    f1 = first.get(code)
    if f1 and f1['certainty'] == 'confirmed' and code not in research:
        row.update(current_address=s['address'] if f1['bag_address'] == '' else f1['bag_address'].replace('BAG ', ''),
                   latitude=f1['latitude'], longitude=f1['longitude'], moved_m=f1['moved_m'],
                   coordinate_source=f"BAG {f1['bag_address']}" + (f"; OSM venue {f1['osm_venue']}" if f1['osm_venue'] else ''),
                   source_url=f1['source_url'], certainty='confirmed', notes=f1['notes'])
        out.append(row); continue
    r = research.get(code)
    if not r:
        row.update(certainty='unclear', notes='Not yet researched.'); out.append(row); continue
    row.update(current_address=r['current_address'], status=r['status'], address_source_url=r['address_source_url'],
               second_source_url=r['second_source_url'])
    notes = [r['notes']] if r['notes'] else []
    if r['certainty'] != 'confirmed' or not r['current_address'] or r['status'] in ('permanently_closed', 'unknown'):
        row['certainty'] = 'unclear'; notes.append('Address not confirmed by two sources; no coordinate written.')
    else:
        hit, why = bag(r['current_address']) if s['cc'] == 'NL' else osm(r['current_address'], s['cc'])
        if hit:
            lat, lng, desc, url = hit
            if s['cc'] == 'NL' and not (50.7 < lat < 53.6 and 3.3 < lng < 7.3):
                row['certainty'] = 'unclear'; notes.append('Geocoded point outside the Netherlands; held back.')
            else:
                row.update(latitude=f'{lat:.7f}', longitude=f'{lng:.7f}', moved_m=round(hav(float(s['lat']), float(s['lng']), lat, lng)),
                           coordinate_source=desc, source_url=url, certainty='confirmed')
        else:
            row['certainty'] = 'unclear'; notes.append(f'Address confirmed, but {why}; no coordinate written.')
    row['notes'] = ' '.join(notes)
    out.append(row)
w = csv.DictWriter(open('seed_coordinates_staged.csv', 'w'), fieldnames=F); w.writeheader(); w.writerows(out)
import collections
print(collections.Counter(r['certainty'] for r in out), collections.Counter(r['status'] for r in out))
