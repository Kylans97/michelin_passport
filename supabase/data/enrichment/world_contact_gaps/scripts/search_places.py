#!/usr/bin/env python3
"""Text Search (Places API New) for rows WITHOUT a stored google_place_id
(added on the product owner's request, 2026-11-04). Mainland China (CN) is
skipped: Google's commercial coverage there is too thin to trust (see the
enrich-venue-data skill). GR skipped. Query "<name> <city>", biased to a
500 m circle around the stored point; hotels get a second, lodging-only query.
Every candidate is kept; the choice is made in build_contact_fill.py.

  GOOGLE_PLACES_API_KEY=... python3 search_places.py <export.json> <out.json>"""
import json, os, sys, time, urllib.request, urllib.error

KEY = os.environ['GOOGLE_PLACES_API_KEY']
FIELDS = ','.join('places.' + f for f in ('id', 'displayName', 'businessStatus', 'internationalPhoneNumber', 'websiteUri',
                                          'location', 'types', 'primaryType', 'formattedAddress'))
EXP, OUT = sys.argv[1:3]
done = json.load(open(OUT)) if os.path.exists(OUT) else {}


def search(q, lat, lon, typ=None):
    body = {'textQuery': q, 'pageSize': 5, 'languageCode': 'en',
            'locationBias': {'circle': {'center': {'latitude': lat, 'longitude': lon}, 'radius': 500.0}}}
    if typ:
        body['includedType'] = typ
    req = urllib.request.Request('https://places.googleapis.com/v1/places:searchText', data=json.dumps(body).encode(),
                                 headers={'X-Goog-Api-Key': KEY, 'X-Goog-FieldMask': FIELDS, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r).get('places', [])
    except urllib.error.HTTPError as e:
        return [{'error': e.code, 'body': e.read().decode('utf-8', 'replace')[:300]}]


rows = [r for r in json.load(open(EXP))['gaps'] if r['country'] not in ('GR', 'CN') and not r['google_place_id']]
for i, r in enumerate(rows):
    if r['code'] in done:
        continue
    q = f"{r['name']} {r['city']}"
    d = {'query': q, 'results': search(q, r['lat'], r['lon'])}
    if r['kind'] == 'hotel':
        d['lodging_results'] = search(r['name'], r['lat'], r['lon'], 'lodging')
    d['fetched_at'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    done[r['code']] = d
    time.sleep(0.1)
    if i % 25 == 0:
        print(i, len(rows), file=sys.stderr, flush=True)
        json.dump(done, open(OUT, 'w'), ensure_ascii=False, indent=1)
json.dump(done, open(OUT, 'w'), ensure_ascii=False, indent=1)
print('done', len(done))
