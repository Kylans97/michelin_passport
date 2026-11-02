#!/usr/bin/env python3
"""Fetch each restaurant's own MICHELIN page and record its cuisine label
(2026-11-01). guide.michelin.com only; the URL is the identity, never a name.

  python3 -I fetch_michelin.py <restaurants_LIVE.csv> <out.jsonl>   (resumable)

The page's visible "Cuisine:" label is recorded as well as JSON-LD
servesCuisine, because servesCuisine carries only the first of two cuisines
(e.g. Ducasse au Château de Versailles: LD "Classic Cuisine", label
"Classic Cuisine, French"). Pacing 2.5 s; a page without the label on HTTP 202
(MICHELIN's throttle) waits 180 s and retries, up to five times.

Stored URLs carry various locale prefixes (/en/, /us/en/, /nl/nl/, /ca/fr/,
/ae-az/en/). A Dutch- or French-locale page gives a translated label
("Eigentijds"), so every page is fetched at the same path under /en/ — the
same MICHELIN restaurant, only the language differs. The stored URL stays the
identity and is recorded beside the fetched one.
"""
import csv, html, json, os, re, subprocess, sys, time

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'


def get(url):
    p = subprocess.run(['curl', '-s', '-L', '--compressed', '--max-time', '60', '-A', UA,
                        '-w', '\n%{http_code} %{url_effective}', url], capture_output=True)
    out = p.stdout.decode('utf-8', 'replace')
    body, _, tail = out.rpartition('\n')
    code, _, final = tail.partition(' ')
    time.sleep(2.5)
    return int(code or 0), final, body


LOCALE = re.compile(r'^https://guide\.michelin\.com/(?:[a-z]{2}(?:-[a-z]{2})?/)?[a-z]{2}/')


def english(url):
    m = LOCALE.match(url)
    if not m:
        raise SystemExit('unexpected MICHELIN URL shape: ' + url)
    return 'https://guide.michelin.com/en/' + url[m.end():]


def parse(body):
    label = None
    m = re.search(r'Cuisine:\s*</div>\s*<div class="data-sheet__block--text">([^<]*)</div>', body)
    if m:
        label = html.unescape(m.group(1)).strip()
    ld = None
    for s in re.finditer(r'<script type="application/ld\+json">(.*?)</script>', body, re.S):
        try:
            x = json.loads(s.group(1))
        except ValueError:
            continue
        if isinstance(x, dict) and x.get('@type') == 'Restaurant':
            ld = x
    h1 = re.search(r'<h1[^>]*>(.*?)</h1>', body, re.S)
    return dict(label=label, ld_cuisine=(ld or {}).get('servesCuisine'), ld_url=(ld or {}).get('url'),
                ld_name=(ld or {}).get('name'), star=(ld or {}).get('starRating'),
                h1=html.unescape(re.sub(r'<[^>]+>', '', h1.group(1))).strip() if h1 else None)


def main(src, out):
    done = set()
    if os.path.exists(out):
        done = {json.loads(l)['restaurant_id'] for l in open(out)}
    rows = [r for r in csv.DictReader(open(src)) if r['michelin_url'].startswith('http') and r['id'] not in done]
    print(len(rows), 'to fetch', file=sys.stderr)
    with open(out, 'a') as f:
        for i, r in enumerate(rows):
            for attempt in range(6):
                fetch_url = english(r['michelin_url'])
                code, final, body = get(fetch_url)
                d = parse(body)
                if code == 202 and not d['label']:
                    print('  202, waiting 180 s', r['michelin_url'], file=sys.stderr)
                    time.sleep(180)
                    continue
                break
            rec = dict(restaurant_id=r['id'], restaurant_code=r['restaurant_code'], country_code=r['country_code'],
                       url=r['michelin_url'], fetch_url=fetch_url, status=code, final_url=final, attempt=attempt + 1,
                       fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), **d)
            f.write(json.dumps(rec, ensure_ascii=False) + '\n')
            f.flush()
            if i % 100 == 0:
                print(i, code, r['restaurant_code'], d['label'], file=sys.stderr)


if __name__ == '__main__':
    main(*sys.argv[1:])
