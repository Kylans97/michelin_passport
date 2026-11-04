#!/usr/bin/env python3
"""Save the full inspector text of each starred restaurant page, the evidence for hotel
links and property_name (the JSON-LD review is cut off). guide.michelin.com only, 2.5 s apart.
  python3 fetch_reviews.py <michelin_restaurant_pages.json> <out.json>"""
import html, json, re, subprocess, sys, time
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'
out = []
for p in json.load(open(sys.argv[1]))['pages']:
    if p['status'] != 200:
        continue
    b = subprocess.run(['curl', '-s', '-L', '--compressed', '-A', UA, p['url']], capture_output=True, text=True, errors='replace').stdout
    time.sleep(2.5)
    m = re.search(r'class="data-sheet__description[^"]*"[^>]*>(.*?)</div>', b, re.S)
    t = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', m.group(1)))).strip() if m else None
    out.append(dict(url=p['url'], name=(p['ld'] or {}).get('name'), review=t))
    print(out[-1]['name'], len(t or ''), file=sys.stderr)
json.dump(out, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)
