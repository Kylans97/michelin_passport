"""BAG lookup by street + house number + town (PDOK Locatieserver), cached."""
import csv, json, os, re, sys, time, urllib.parse, urllib.request
src, cache_path = sys.argv[1:3]
cache = json.load(open(cache_path)) if os.path.exists(cache_path) else {}
FL = 'weergavenaam,straatnaam,huisnummer,huisletter,huisnummertoevoeging,postcode,woonplaatsnaam,gemeentenaam,centroide_ll,id'
def parse(addr):
    first, rest = addr.split(',', 1)
    pc = re.search(r'\b(\d{4})\s?([A-Z]{2})\b', rest)
    town = rest[pc.end():].strip() if pc else rest.strip()
    m = re.search(r'(\d+)\s*([A-Za-z]?)(?:-(\d+))?\s*$', first.strip())
    street = first[:m.start()].strip() if m else first
    return (pc.group(1) + pc.group(2)) if pc else None, (int(m.group(1)) if m else None), (m.group(2) if m else ''), street, town
for r in csv.DictReader(open(src)):
    if r['cc'] != 'NL': continue
    pc, nr, letter, street, town = parse(r['address'])
    key = f'{street}|{nr}|{town}'
    if key in cache: continue
    q = urllib.parse.urlencode([('q', f'{street} {nr} {town}'), ('fq', 'type:adres'), ('rows', 15), ('fl', FL)])
    cache[key] = json.load(urllib.request.urlopen('https://api.pdok.nl/bzk/locatieserver/search/v3_1/free?' + q, timeout=20))['response']['docs']
    json.dump(cache, open(cache_path, 'w')); time.sleep(0.3)
print(len(cache))
