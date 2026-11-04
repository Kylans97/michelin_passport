#!/usr/bin/env python3
"""Place Details (Places API New) for every stored google_place_id in the
world contact-gap export, GR skipped. No search: only the Place ID production
already holds. Two calls per Place ID: English, and the country's own language
(for the native-script name a Japanese/Chinese site prints).

  GOOGLE_PLACES_API_KEY=... python3 fetch_places.py <export.json> <out.json>
The key is read from the environment and never written out."""
import json, os, sys, time, urllib.request, urllib.error

KEY = os.environ['GOOGLE_PLACES_API_KEY']
FIELDS = 'id,displayName,businessStatus,nationalPhoneNumber,internationalPhoneNumber,websiteUri,location,types,primaryType,formattedAddress'
LANG = {'JP': 'ja', 'CN': 'zh-CN', 'TW': 'zh-TW', 'HK': 'zh-HK', 'MO': 'zh-HK', 'KR': 'ko', 'TH': 'th'}
EXP, OUT = sys.argv[1:3]
done = json.load(open(OUT)) if os.path.exists(OUT) else {}


def details(pid, lang):
    req = urllib.request.Request(f'https://places.googleapis.com/v1/places/{pid}?languageCode={lang}',
                                 headers={'X-Goog-Api-Key': KEY, 'X-Goog-FieldMask': FIELDS})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {'error': e.code, 'body': e.read().decode('utf-8', 'replace')[:300]}


rows = [r for r in json.load(open(EXP))['gaps'] if r['country'] != 'GR' and r['google_place_id']]
for i, r in enumerate(rows):
    if r['code'] in done and 'error' not in done[r['code']]['en']:
        continue
    d = {'place_id': r['google_place_id'], 'en': details(r['google_place_id'], 'en')}
    if r['country'] in LANG:
        d['native'] = details(r['google_place_id'], LANG[r['country']])
    d['fetched_at'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    done[r['code']] = d
    time.sleep(0.1)
    if i % 25 == 0:
        print(i, len(rows), file=sys.stderr, flush=True)
        json.dump(done, open(OUT, 'w'), ensure_ascii=False, indent=1)
json.dump(done, open(OUT, 'w'), ensure_ascii=False, indent=1)
print('done', len(done), 'errors', sum('error' in v['en'] for v in done.values()))
