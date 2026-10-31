#!/usr/bin/env python3
"""Fetch MICHELIN's hotel listings and hotel pages for the IT/ES/DE/BE/NL/LU Keys
refresh (2026-10-31). guide.michelin.com only.

  python3 fetch_michelin.py listing <out.json>
  python3 fetch_michelin.py pages <urls.txt> <out.json>     (resumable)

Pacing: 2.5 s between requests; on HTTP 202 (MICHELIN's throttle) wait 180 s and
retry, up to five times. Nothing else is fetched.
"""
import json, os, re, subprocess, sys, time, html

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'
BASE = 'https://guide.michelin.com'
COUNTRIES = ['italy', 'spain', 'germany', 'belgium', 'netherlands', 'luxembourg']


def get(url):
    for attempt in range(6):
        p = subprocess.run(['curl', '-s', '-L', '--compressed', '-A', UA, '-w', '\n%{http_code} %{url_effective}', url],
                           capture_output=True, text=True)
        body, _, tail = p.stdout.rpartition('\n')
        code, _, final = tail.partition(' ')
        time.sleep(2.5)
        if code == '202':
            print('  202, waiting 180 s', url, file=sys.stderr)
            time.sleep(180)
            continue
        return int(code), final, body
    raise SystemExit('still 202 after retries: ' + url)


def attr(block, name):
    m = re.search(name + r'="([^"]*)"', block)
    return html.unescape(m.group(1)) if m else None


def listing(out):
    rows = []
    for c in COUNTRIES:
        n = 1
        while True:
            url = f'{BASE}/en/hotels-stays/{c}' + (f'/page/{n}' if n > 1 else '')
            code, final, body = get(url)
            cards = body.split('class="card__menu selection-card')[1:]
            cards = [x for x in cards if 'js-bookmark-hotel' in x]
            total = re.search(r'of ([0-9,]+) hotels', body)
            print(c, n, code, len(cards), total.group(1) if total else None, file=sys.stderr)
            if code != 200 or not cards or (n > 1 and final.rstrip('/').endswith(c)):
                break
            for x in cards:
                bm = x[x.find('js-bookmark-hotel'):]
                href = re.search(r'href="(/en/hotels-stays/[^"]+)"', x)
                rows.append(dict(listing=c, page=n, pid=attr(bm, 'data-pid'), distinction=attr(bm, 'data-distinction'),
                                 hotel_country=attr(x, 'data-hotel-country'), name=attr(bm, 'data-hotel-name'),
                                 city=attr(bm, 'data-dtm-city'), url=BASE + href.group(1) if href else None,
                                 header_total=total.group(1) if total else None))
            n += 1
    json.dump(dict(fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), rows=rows), open(out, 'w'),
              ensure_ascii=False, indent=1)


def page(url):
    code, final, body = get(url)
    lds = []
    for m in re.finditer(r'<script type="application/ld\+json">(.*?)</script>', body, re.S):
        try:
            lds.append(json.loads(m.group(1)))
        except ValueError:
            pass
    ld = next((x for x in lds if isinstance(x, dict) and x.get('@type') in ('Hotel', 'LodgingBusiness', 'Resort')), None)
    h1 = re.search(r'<h1[^>]*>(.*?)</h1>', body, re.S)
    rests = sorted(set(re.findall(r'href="(/en/[^"]+/restaurant/[^"]+)"', body)))
    return dict(url=url, status=code, final_url=final, h1=html.unescape(re.sub(r'<[^>]+>', '', h1.group(1))).strip() if h1 else None,
                ld=ld, ld_types=[x.get('@type') for x in lds if isinstance(x, dict)], restaurants=rests)


def pages(urls_file, out):
    done = json.load(open(out))['pages'] if os.path.exists(out) else []
    seen = {p['url'] for p in done}
    urls = [u.strip() for u in open(urls_file) if u.strip()]
    for i, u in enumerate(urls):
        if u in seen:
            continue
        p = page(u)
        done.append(p)
        print(i, len(urls), p['status'], u, file=sys.stderr)
        if len(done) % 20 == 0:
            json.dump(dict(pages=done), open(out, 'w'), ensure_ascii=False, indent=1)
    json.dump(dict(fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), pages=done), open(out, 'w'),
              ensure_ascii=False, indent=1)


if __name__ == '__main__':
    if sys.argv[1] == 'listing':
        listing(sys.argv[2])
    else:
        pages(sys.argv[2], sys.argv[3])
