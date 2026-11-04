#!/usr/bin/env python3
"""QA-431 (http:// links are opened as https://: only https goes
through the proxy here): open the official site behind each Google record (and its contact
page) and record: final URL, HTTP status, whether the venue's name appears,
and which of the MICHELIN / Google phone numbers are printed on it.
Output: sites_<date>.json. Blocked hosts are recorded, not routed around."""
import json, csv, re, sys, os, urllib.request, urllib.parse, ssl, html
HERE = os.path.dirname(os.path.abspath(__file__))
P = json.load(open(os.path.join(HERE, 'places_raw_20261103.json')))
C = {r['code']: r for r in csv.DictReader(open(os.path.join(HERE, '..', 'gr_control.csv')))}
UA = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36', 'Accept-Language': 'en'}

def get(url):
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=25)
        return r.status, r.geturl(), r.read(3_000_000).decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, url, ''
    except Exception as e:
        return 'ERR ' + str(e)[:80], url, ''

def digits(s):
    d = re.sub(r'\D', '', s)
    return re.sub(r'^(00)?30', '', d)

def phones_in(text):
    t = html.unescape(text)
    found = set()
    for m in re.finditer(r'(?:\+|00)?\s*\(?30\)?[\s\-\.\(\)]*\d[\d\s\-\.\(\)]{8,16}\d|\b2\d{9}\b|\b69\d{8}\b|\b2\d[\d\s\-\.]{8,13}\d', t):
        d = digits(m.group())
        if len(d) == 10: found.add(d)
    for m in re.finditer(r'tel:([+\d\s\-\.\(\)]+)', t):
        d = digits(m.group(1))
        if len(d) == 10: found.add(d)
    return found

def clean(u):
    p = urllib.parse.urlsplit(u)
    return urllib.parse.urlunsplit(('https', p.netloc, p.path or '/', '', ''))

codes = sys.argv[2:] or list(P)
out = {}
for code in codes:
    cand = P[code]['candidates'][0] if P[code]['candidates'] else {}
    url = clean(cand.get('websiteUri', '')) if cand.get('websiteUri') else ''
    if not url:
        out[code] = {'url': ''}; continue
    st, final, body = get(url)
    pages = [(url, st, final)]
    ph = phones_in(body)
    # follow one contact link
    m = re.search(r'href="([^"]*contact[^"]*)"', body, re.I)
    if m:
        cu = urllib.parse.urljoin(final, html.unescape(m.group(1)))
        st2, f2, b2 = get(cu)
        pages.append((cu, st2, f2)); ph |= phones_in(b2); body += b2
    text = html.unescape(re.sub(r'<[^>]+>', ' ', body)).lower()
    name = P[code]['name'].lower()
    key = [w for w in re.findall(r'[a-zà-ÿ|]+', name) if len(w) > 3 and w not in ('hotel', 'suites', 'villas', 'resort', 'santorini', 'mykonos', 'athens', 'collection', 'restaurant', 'boutique', 'village')]
    hits = {w: (w in text) for w in key}
    mich = [digits(x) for x in C[code]['michelin_phone'].split('/') if x.strip()] if code in C else []
    goog = digits(cand.get('internationalPhoneNumber', ''))
    out[code] = {'url': url, 'pages': pages, 'name_tokens': hits,
                 'michelin_on_site': [x for x in mich if x in ph], 'google_on_site': goog if goog in ph else '',
                 'phones_on_site': sorted(ph)}
    print(code, P[code]['name'][:30], '|', st, final[:60], '|', hits, '| M', out[code]['michelin_on_site'], '| G', out[code]['google_on_site'], '|', sorted(ph)[:5])
json.dump(out, open(os.path.join(HERE, sys.argv[1]), 'w'), indent=1)
