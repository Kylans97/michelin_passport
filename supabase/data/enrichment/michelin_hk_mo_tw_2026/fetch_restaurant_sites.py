#!/usr/bin/env python3
"""Fetch each restaurant's official site (MICHELIN's website link): home page plus up to
four same-host contact/booking/about pages. Used by check_restaurant_phones.py. 2026-10-29.
Copied from ../michelin_cn_2026 for Hong Kong, Macau and Taiwan."""
import json, sys, os, re, urllib.request, ssl, concurrent.futures, hashlib, urllib.parse
pages = [json.loads(l) for l in open(sys.argv[1])]
out = sys.argv[2]
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Safari/537.36'
ctx = ssl.create_default_context()
def get(u):
    try:
        r = urllib.request.urlopen(urllib.request.Request(u, headers={'User-Agent': UA, 'Accept-Language': 'en-GB,zh-TW;q=0.8'}), timeout=20, context=ctx)
        return r.geturl(), r.status, r.read(3_000_000).decode('utf-8', 'replace')
    except Exception as e:
        return u, getattr(e, 'code', None) or str(e)[:80], ''
def job(p):
    w = p.get('website')
    if not w: return p['url'], None
    res = {'home': get(w)}
    base = res['home'][0]
    html = res['home'][2]
    # contact-like links on the same host
    links = set()
    for m in re.finditer(r'href="([^"#]+)"', html):
        h = m.group(1)
        if re.search(r'contact|find-us|location|visit|book|reserv|about', h, re.I):
            a = urllib.parse.urljoin(base, h)
            if urllib.parse.urlparse(a).netloc == urllib.parse.urlparse(base).netloc:
                links.add(a)
    for a in sorted(links)[:4]:
        res[a] = get(a)
    return p['url'], {k: [v[0], v[1], v[2]] for k, v in res.items()}
with concurrent.futures.ThreadPoolExecutor(12) as ex:
    for url, res in ex.map(job, pages):
        fn = os.path.join(out, hashlib.md5(url.encode()).hexdigest() + '.json')
        json.dump({'url': url, 'res': res}, open(fn, 'w'))
print('done')
