"""Geocode each seed restaurant's stored address and its name+city on
public Nominatim (cached, 1.2 s apart), for trip_map_location_audit."""
import csv, json, os, sys, time, urllib.parse, urllib.request
src, cache_path = sys.argv[1], sys.argv[2]
cache = json.load(open(cache_path)) if os.path.exists(cache_path) else {}
def get(params):
    key = json.dumps(params, sort_keys=True)
    if key in cache: return cache[key]
    url = 'https://nominatim.openstreetmap.org/search?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'User-Agent': 'MantelierLocationQA/1.0 (research)'})
    try: res = json.load(urllib.request.urlopen(req, timeout=20))
    except Exception as e: res = {'error': str(e)}
    cache[key] = res
    json.dump(cache, open(cache_path, 'w'))
    time.sleep(1.2)
    return res
for r in csv.DictReader(open(src)):
    cc = r['cc'].lower()
    get({'q': r['address'], 'countrycodes': cc, 'format': 'jsonv2', 'addressdetails': 1, 'limit': 3})
    get({'q': f"{r['name']}, {r['city']}", 'countrycodes': cc, 'format': 'jsonv2', 'addressdetails': 1, 'limit': 5})
print('done', len(cache))
