#!/usr/bin/env python3
"""QA-431: fetch Google Places candidates for the 93 new GR rows + hotel_716.

Text Search (New), biased to a 500 m circle around the stored point. Raw
responses go to places_raw_<date>.json; nothing is decided here.
Needs GOOGLE_PLACES_API_KEY (never written out).
"""
import csv, json, os, sys, urllib.request, math, time
HERE = os.path.dirname(os.path.abspath(__file__))
CTRL = os.path.join(HERE, '..', 'gr_control.csv')
OUT = os.path.join(HERE, sys.argv[1] if len(sys.argv) > 1 and __name__ == '__main__' else 'places_raw.json')
KEY = os.environ['GOOGLE_PLACES_API_KEY']
FIELDS = ('places.id,places.displayName,places.location,places.types,places.primaryType,'
          'places.businessStatus,places.nationalPhoneNumber,places.internationalPhoneNumber,'
          'places.websiteUri,places.formattedAddress')

def search(q, lat, lon):
    body = json.dumps({'textQuery': q, 'maxResultCount': 5, 'languageCode': 'en',
                       'locationBias': {'circle': {'center': {'latitude': lat, 'longitude': lon}, 'radius': 500.0}}}).encode()
    req = urllib.request.Request('https://places.googleapis.com/v1/places:searchText', data=body,
                                 headers={'Content-Type': 'application/json', 'X-Goog-Api-Key': KEY, 'X-Goog-FieldMask': FIELDS})
    return json.load(urllib.request.urlopen(req, timeout=30)).get('places', [])

def dist(a, b, c, d):
    R = 6371000; p1, p2 = math.radians(a), math.radians(c)
    h = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(d - b) / 2) ** 2
    return round(2 * R * math.asin(math.sqrt(h)))

def main():
    rows = [r for r in csv.DictReader(open(CTRL)) if r['kind'] in ('restaurant', 'hotel') and r['code']]
    out = {}
    for r in rows:
        if not r['lat']:
            print('no point', r['code']); continue
        lat, lon = float(r['lat']), float(r['lon'])
        q = f"{r['name']} {r['michelin_locality'] or r['town']} Greece"
        res = search(q, lat, lon)
        for p in res:
            p['distance_m'] = dist(lat, lon, p['location']['latitude'], p['location']['longitude'])
        out[r['code']] = {'name': r['name'], 'kind': r['kind'], 'query': q, 'lat': lat, 'lon': lon, 'candidates': res}
        time.sleep(0.1)
    json.dump(out, open(OUT, 'w'), indent=1, ensure_ascii=False)
    print('written', OUT, len(out))


if __name__ == '__main__':
    main()
