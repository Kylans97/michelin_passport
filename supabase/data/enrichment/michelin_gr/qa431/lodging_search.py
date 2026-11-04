#!/usr/bin/env python3
"""QA-431 follow-up: lodging-only Text Search for hotel rows whose first
candidate failed type or distance. Usage: lodging_search.py out.json code=query ..."""
import json, os, sys, urllib.request, csv, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_places import dist, FIELDS, KEY, CTRL
C = {r['code']: r for r in csv.DictReader(open(CTRL))}
out = {}
for arg in sys.argv[2:]:
    code, q = arg.split('=', 1)
    r = C[code]; lat, lon = float(r['lat']), float(r['lon'])
    body = json.dumps({'textQuery': q, 'maxResultCount': 5, 'includedType': 'lodging', 'languageCode': 'en',
                       'locationBias': {'circle': {'center': {'latitude': lat, 'longitude': lon}, 'radius': 2000.0}}}).encode()
    req = urllib.request.Request('https://places.googleapis.com/v1/places:searchText', data=body,
          headers={'Content-Type': 'application/json', 'X-Goog-Api-Key': KEY, 'X-Goog-FieldMask': FIELDS})
    res = json.load(urllib.request.urlopen(req, timeout=30)).get('places', [])
    for p in res: p['distance_m'] = dist(lat, lon, p['location']['latitude'], p['location']['longitude'])
    out[code] = {'query': q, 'candidates': res}
    for p in res: print(code, p['distance_m'], p['displayName']['text'], p.get('primaryType'), p.get('businessStatus'), p['id'], p.get('formattedAddress'), (p.get('websiteUri') or '')[:50], sep=' | ')
json.dump(out, open(sys.argv[1], 'w'), indent=1, ensure_ascii=False)
