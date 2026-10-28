"""Match our World's 50 Best venues to the50.com profile pages.

Candidates come only from the site's own sitemap (never built from our
names). A candidate is VERIFIED only when the fetched page states a
World's 50 Best rank + year that exactly equals one of our own
worlds_50_best(_hotels) rows for that venue, AND the page's country equals
ours. Everything else is left for review or recorded as not found.

usage: python3 -I match_w50.py <workdir> restaurants|hotels
"""
import csv, html, json, os, re, subprocess, sys, time, unicodedata, hashlib

W, KIND = sys.argv[1], sys.argv[2]
SRC = os.path.join(W, 'r.csv' if KIND == 'restaurants' else 'h.csv')
CACHE = os.path.join(W, 'pages')
os.makedirs(CACHE, exist_ok=True)

ALIASES = {
    'United Kingdom': {'UK', 'Scotland'}, 'United States': {'US'},
    'United Arab Emirates': {'United-Arab-Emirates', 'UAE'},
    'Turkey': {'Turkey', 'Türkiye'}, 'Maldives': {'Maldives', 'Republic-of-Maldives'},
    'St. Barthélemy': {'French-West-Indies'},
    'Hong Kong': {'Hong-Kong', 'China'}, 'Macau': {'Macau', 'China'},
}
PAGE_COUNTRY = {'UK': 'United Kingdom', 'USA': 'United States', 'US': 'United States',
                'UAE': 'United Arab Emirates', 'Türkiye': 'Turkey', 'Scotland': 'United Kingdom',
                'England': 'United Kingdom', 'Republic of Maldives': 'Maldives',
                'St. Barths': 'St. Barthélemy'}


def norm(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', ' ', s).strip()


STOP = {'the', 'restaurant', 'hotel', 'de', 'la', 'le', 'by', 'at', 'and', 'a'}


def toks(s):
    return {t for t in norm(s).split() if t not in STOP} or set(norm(s).split())


def score(a, b):
    # Candidate selection only — never evidence. Symmetric, so "Steirereck"
    # can find "Steirereck im Stadtpark" and vice versa.
    if norm(a).replace(' ', '') == norm(b).replace(' ', ''):
        return 1.0
    ta, tb = toks(a), toks(b)
    if not ta or not tb:
        return 0
    return len(ta & tb) / min(len(ta), len(tb))


urls = [u.strip() for u in open(os.path.join(W, 'urls.txt'))]
disc = [u for u in urls if '/discovery/Establishments/' in u]
hotel_list = [u for u in urls if '/hotels/best-in-the-world/the-list/' in u]


def candidates(row):
    allowed = {row['country'].replace(' ', '-')} | ALIASES.get(row['country'], set())
    out = []
    for u in disc:
        parts = u.split('/discovery/Establishments/')[1].split('/')
        if parts[0] not in allowed:
            continue
        leaf = re.sub(r'\.html$', '', parts[-1]).replace('-', ' ')
        s = score(row['name'], leaf)
        if s >= 0.5:
            out.append((s, u))
    if KIND == 'hotels':
        for u in hotel_list:
            leaf = re.sub(r'\.html$', '', u.rsplit('/', 1)[1]).replace('-', ' ')
            s = score(row['name'], leaf)
            if s >= 0.5:
                out.append((s, u))
    # A discovery profile outlives the yearly list, so it wins a tie with a
    # list page for the same venue.
    out.sort(key=lambda x: (-x[0], '/the-list/' in x[1]))
    return [u for _, u in out[:8]]


def domain(u):
    h = re.sub(r'^https?://', '', u.strip().lower()).split('/')[0]
    return re.sub(r'^www\d?\.', '', h)


LANG = {'en', 'nl', 'fr', 'de', 'it', 'es', 'ja', 'zh', 'en-gb', 'en-us', 'home', 'index.html'}


def own_site(u):
    path = re.sub(r'^https?://[^/]+', '', u.strip().lower()).split('?')[0]
    segs = [x for x in path.split('/') if x and x not in LANG]
    return len(segs) <= 1


def fetch(u):
    path = os.path.join(CACHE, hashlib.sha1(u.encode()).hexdigest() + '.html')
    if not os.path.exists(path):
        time.sleep(1.1)  # robots.txt crawl-delay 1
        subprocess.run(['curl', '-sL', '-A', 'Mozilla/5.0', '--max-time', '30', '-o', path, u])
    try:
        return open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return ''


def parse(s):
    t = re.sub(r'(?s)<script.*?</script>|<style.*?</style>', '', s)
    lines = [l.strip() for l in html.unescape(re.sub(r'<[^>]+>', '\n', t)).split('\n') if l.strip()]
    title = (re.findall(r'(?s)<title>(.*?)</title>', s) or [''])[0].strip()
    ranks = set()
    for l in lines:
        for m in re.finditer(r"No\.\s?(\d+)\s+The World.s 50 Best (Restaurants|Hotels)\s+(\d{4})", l):
            ranks.add((int(m.group(3)), int(m.group(1))))
    # The "City, Country" line sits right after the venue-name heading; a
    # name that itself contains a comma ("Mandapa, a Ritz-Carlton Reserve")
    # must not be mistaken for it, so take the last such line before the
    # body text rather than the first.
    locs = [l for l in lines[:12] if re.fullmatch(r"[^,]{2,60}, [A-Za-zÀ-ÿ .'-]{2,40}", l)]
    loc = locs[-1] if locs else ''
    m = re.search(r'The 50 Best Hotels (\d{4}) \| Ranked No\. (\d+)', title)
    if m:
        ranks.add((int(m.group(1)), int(m.group(2))))
    site = re.findall(r'href="(https?://[^"]+)"[^>]*>\s*Visit', s)
    best_years = set()
    for l in lines:
        if re.search(r"World.s Best (Restaurant|Hotel)", l):
            best_years |= {int(y) for y in re.findall(r'\b(20\d\d)\b', l)}
    hof = any(l == 'Best of the Best' for l in lines)
    phones = {re.sub(r'\D', '', l)[-8:] for l in lines
              if re.fullmatch(r'\+?[\d ()./-]{7,22}', l) and len(re.sub(r'\D', '', l)) >= 8}
    return title, loc, ranks, (site[0] if site else ''), best_years, hof, phones, norm(' '.join(lines))


def hist(row):
    out = set()
    for h in row['hist'].split():
        y, r, _ = h.split(':', 2)
        if r.isdigit():
            out.add((int(y), int(r)))
    return out


rows = list(csv.DictReader(open(SRC)))
out = []
for i, row in enumerate(rows):
    ours = hist(row)
    best = None
    for u in candidates(row):
        title, loc, ranks, site, best_years, hof, phones, page_text = parse(fetch(u))
        page_country = loc.rsplit(', ', 1)[-1] if loc else ''
        page_country = PAGE_COUNTRY.get(page_country, page_country)
        country_ok = norm(page_country) == norm(row['country'])
        # A hotel list page has no location line, but a rank + year is
        # unique within one year's list, so an exact match identifies it.
        if '/the-list/' in u and matched:
            country_ok = True
        # the50.com files Hong Kong and Macau under China ("Hong Kong, China").
        if (not country_ok and row['country'] in ('Hong Kong', 'Macau')
                and norm(page_country) == 'china'
                and norm(loc.rsplit(', ', 1)[0]) == norm(row['city'])):
            country_ok = True
        matched = sorted(ranks & ours)
        rec = dict(code=row['code'], name=row['name'], city=row['city'], country=row['country'],
                   url=u, page_title=title, page_location=loc,
                   page_ranks=' '.join(f'{y}:{r}' for y, r in sorted(ranks)),
                   matched_ranks=' '.join(f'{y}:{r}' for y, r in matched),
                   page_website=site, our_website=row['website_url'])
        our_no1 = {y for y, r in ours if r == 1}
        our_hof = 'hall_of_fame' in row['hist']
        our_phone = re.sub(r'\D', '', row.get('phone') or '')[-8:]
        # A domain match only proves identity on a venue's own site. A
        # sub-page of a group site (fourseasons.com/hongkong/dining/...)
        # is shared by sibling venues — Caprice vs Caprice Bar — so it
        # never counts.
        site_ok = (bool(site) and bool(row['website_url'])
                   and domain(site) == domain(row['website_url'])
                   and own_site(row['website_url']))
        phone_ok = bool(our_phone) and len(our_phone) == 8 and our_phone in phones
        # Our street + house number (first address segment containing a
        # digit) must appear verbatim, normalised, in the page text.
        seg = next((x for x in row['address'].split(',') if re.search(r'\d', x)), '')
        street = norm(seg)
        address_ok = len(street) >= 6 and re.search(r'\d', street) is not None and f' {street} ' in f' {page_text} '
        rec['evidence'] = ' '.join(k for k, v in [
            ('rank', bool(matched)), ('worlds_best_year', bool(best_years & our_no1)),
            ('hall_of_fame', hof and our_hof), ('website', site_ok), ('phone', phone_ok), ('address', address_ok)] if v)
        # A profile's title names its type ("De Librije - Zwolle - Restaurant
        # - The 50 Discovery"). A bar or hotel page is never a restaurant's
        # page, even on the same domain (The Connaught vs Connaught Bar).
        want = 'Restaurant' if KIND == 'restaurants' else 'Hotel'
        type_ok = (re.search(rf'\s-\s+{want}\s', title) is not None
                   or (KIND == 'hotels' and '/hotels/best-in-the-world/the-list/' in u))
        rec['page_type_ok'] = type_ok
        if country_ok and type_ok and rec['evidence']:
            rec['status'] = 'verified'
        elif country_ok and not ranks:
            rec['status'] = 'review_no_rank_on_page'
        else:
            rec['status'] = 'rejected'
        # A verified discovery profile beats a verified list page (it
        # outlives the yearly list); otherwise the first verified wins.
        def order(x):
            return {'verified': 0, 'review_no_rank_on_page': 2, 'rejected': 3}[x['status']] \
                + (1 if x['status'] == 'verified' and '/the-list/' in x['url'] else 0)
        if best is None or order(rec) < order(best):
            best = rec
        if rec['status'] == 'verified' and '/the-list/' not in u:
            break
    if best is None:
        best = dict(code=row['code'], name=row['name'], city=row['city'], country=row['country'],
                    url='', page_title='', page_location='', page_ranks='', matched_ranks='',
                    page_website='', our_website=row['website_url'], status='no_candidate', evidence='')
    if best['status'] == 'rejected':
        best['status'] = 'not_found'
    best['our_ranks'] = row['hist']
    out.append(best)
    print(i + 1, best['status'], best['code'], best['name'], best['url'], file=sys.stderr)

fields = ['code', 'name', 'city', 'country', 'status', 'evidence', 'url', 'matched_ranks', 'page_title',
          'page_location', 'page_ranks', 'our_ranks', 'page_website', 'our_website']
with open(os.path.join(W, f'{KIND}_matched.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
    w.writeheader()
    w.writerows(out)
from collections import Counter
print(Counter(r['status'] for r in out))
