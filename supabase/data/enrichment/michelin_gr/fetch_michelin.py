#!/usr/bin/env python3
"""Fetch MICHELIN's Greece selection for the GR pass (2026-11-04).
guide.michelin.com only. Adapted from ../michelin_pl_tr_2026/fetch_michelin.py.

  python3 fetch_michelin.py stars  <out.json>              starred listings /en/gr/restaurants/all-starred
  python3 fetch_michelin.py hotels <out.json>              hotel listings /en/hotels-stays/greece
  python3 fetch_michelin.py rpages <urls.txt> <out.json>   restaurant pages (resumable)
  python3 fetch_michelin.py hpages <urls.txt> <out.json>   hotel pages (resumable)

Pacing: 2.5 s between requests; on HTTP 202 (MICHELIN's throttle) wait 180 s and
retry, up to five times. Nothing else is fetched.
"""
import json, os, re, subprocess, sys, time, html

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'
BASE = 'https://guide.michelin.com'
STAR_PATHS = {'GR': '/en/gr/restaurants/all-starred'}
HOTEL_PATHS = {'GR': '/en/hotels-stays/greece'}


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


def lds(body):
    out = []
    for m in re.finditer(r'<script type="application/ld\+json">(.*?)</script>', body, re.S):
        try:
            out.append(json.loads(m.group(1)))
        except ValueError:
            pass
    return [x for x in out if isinstance(x, dict)]


def paged(path, split, keep):
    """Every page of a listing; returns (rows, header texts)."""
    rows, n, heads = [], 1, []
    while True:
        url = BASE + path + (f'/page/{n}' if n > 1 else '')
        code, final, body = get(url)
        cards = [x for x in body.split(split)[1:] if keep(x)]
        total = re.search(r'([0-9,]+) (restaurants|hotels)', body)
        heads.append(dict(url=url, status=code, final=final, total=total.group(0) if total else None, cards=len(cards)))
        print(path, n, code, len(cards), total.group(0) if total else None, file=sys.stderr)
        if code != 200 or not cards or (n > 1 and final.rstrip('/').endswith(path.rstrip('/'))):
            break
        rows += [(n, x) for x in cards]
        n += 1
    return rows, heads


def stars(out):
    res, heads = [], {}
    for cc, path in STAR_PATHS.items():
        rows, heads[cc] = paged(path, 'card__menu selection-card', lambda x: 'data-view="restaurant"' in x[:600])
        for page, x in rows:
            href = re.search(r'href="(/en/[^"]+/restaurant/[^"]+)"', x)
            res.append(dict(listing=cc, page=page, michelin_id=attr(x, 'data-id'), lat=attr(x, 'data-lat'), lon=attr(x, 'data-lng'),
                            pin=attr(x, 'data-map-pin-name'), distinction=attr(x, 'data-dtm-distinction'),
                            restaurant_country=attr(x, 'data-restaurant-country'), name=attr(x, 'data-restaurant-name'),
                            city=attr(x, 'data-dtm-city'), region=attr(x, 'data-dtm-region'),
                            url=BASE + href.group(1) if href else None))
    json.dump(dict(fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), heads=heads, rows=res),
              open(out, 'w'), ensure_ascii=False, indent=1)


def hotels(out):
    res, heads = [], {}
    for cc, path in HOTEL_PATHS.items():
        rows, heads[cc] = paged(path, 'class="card__menu selection-card', lambda x: 'js-bookmark-hotel' in x)
        for page, x in rows:
            bm = x[x.find('js-bookmark-hotel'):]
            href = re.search(r'href="(/en/hotels-stays/[^"]+)"', x)
            res.append(dict(listing=cc, page=page, pid=attr(bm, 'data-pid'), distinction=attr(bm, 'data-distinction'),
                            hotel_country=attr(x, 'data-hotel-country'), name=attr(bm, 'data-hotel-name'),
                            city=attr(bm, 'data-dtm-city'), url=BASE + href.group(1) if href else None))
    json.dump(dict(fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), heads=heads, rows=res),
              open(out, 'w'), ensure_ascii=False, indent=1)


def sections(body):
    """h2 section heading -> hotel page links listed under it."""
    out, parts = {}, re.split(r'<h2 class="section__heading section__heading_title">', body)
    for p in parts[1:]:
        head = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', p.split('</h2>')[0]))).strip()
        out[head] = sorted(set(re.findall(r'href="(/en/hotels-stays/[^"?#]+)"', p)))
    return out


def rpage(url):
    code, final, body = get(url)
    ld = next((x for x in lds(body) if x.get('@type') == 'Restaurant'), None)
    web = re.search(r'<a href="([^"]+)"[^>]*\n?[^>]*data-event="CTA_website"', body) or \
        re.search(r'href="([^"]+)" target="_blank" rel="nofollow noopener"\s*class="[^"]*"\s*data-event="CTA_website"', body)
    tel = re.search(r'href="(tel:[^"]+)"', body)
    title = re.search(r'<title>(.*?)</title>', body, re.S)
    secs = sections(body)
    stay = next((v for k, v in secs.items() if k.lower().startswith('stay at')), [])
    desc = re.search(r'<meta name="description" content="([^"]*)"', body)
    return dict(url=url, status=code, final_url=final, ld=ld, website=html.unescape(web.group(1)) if web else None,
                tel_link=tel.group(1) if tel else None, stay_hotel_urls=stay, sections=list(secs),
                description=html.unescape(desc.group(1)) if desc else None,
                title=html.unescape(title.group(1)).strip() if title else None)


def hpage(url):
    code, final, body = get(url)
    L = lds(body)
    ld = next((x for x in L if x.get('@type') in ('Hotel', 'LodgingBusiness', 'Resort')), None)
    h1 = re.search(r'<h1[^>]*>(.*?)</h1>', body, re.S)
    rests = sorted(set(re.findall(r'href="(/en/[^"]+/restaurant/[^"?#]+)"', body)))
    web = re.search(r'href="(https?://[^"]+)"[^>]*data-event="CTA_website"', body)
    return dict(url=url, status=code, final_url=final,
                h1=html.unescape(re.sub(r'<[^>]+>', '', h1.group(1))).strip() if h1 else None,
                ld=ld, ld_types=[x.get('@type') for x in L], restaurants=rests, sections=list(sections(body)),
                website=html.unescape(web.group(1)) if web else None)


def pages(fn, urls_file, out):
    done = json.load(open(out))['pages'] if os.path.exists(out) else []
    seen = {p['url'] for p in done}
    urls = [u.strip() for u in open(urls_file) if u.strip()]
    for i, u in enumerate(urls):
        if u in seen:
            continue
        p = fn(u)
        done.append(p)
        print(i, len(urls), p['status'], u, file=sys.stderr)
        if len(done) % 10 == 0:
            json.dump(dict(pages=done), open(out, 'w'), ensure_ascii=False, indent=1)
    json.dump(dict(fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), pages=done), open(out, 'w'),
              ensure_ascii=False, indent=1)


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'stars':
        stars(sys.argv[2])
    elif cmd == 'hotels':
        hotels(sys.argv[2])
    else:
        pages(rpage if cmd == 'rpages' else hpage, sys.argv[2], sys.argv[3])
