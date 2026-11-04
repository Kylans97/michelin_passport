#!/usr/bin/env python3
"""Decide, per exported row, which Place ID / phone / website may be proposed,
and write one <cc>_contact_fill.csv per country (every row, also the ones held
back). World contact-gap pass, 2026-11-04.

  python3 build_contact_fill.py <export.json> <places_details.json> <places_search.json>
                                <michelin_parsed.json> <sites_raw_dir> <out_dir> [CC ...]

Rules (README.md has the Dutch summary):
- Place ID (only rows without one; never CN): the venue's own Google record from a
  text search near the stored point. Hotel: a lodging record. Restaurant: not a
  lodging record unless the record carries the restaurant's own name. Under 100 m
  with a matching name: accepted. 100-500 m: only when the record's website is on
  MICHELIN's official domain. Two different acceptable records: held back.
  Permanently closed: held back.
- Website: MICHELIN's link and the Google record's link share the registrable
  domain, or one of them loads and names the venue. Never a booking, aggregator,
  guide or social link; tracking parameters removed. A restaurant inside a hotel
  never gets the hotel's general site: the page itself must name the restaurant
  in its title or path.
- Phone: MICHELIN and Google give the same number, or the number is printed on
  the venue's own site. One source alone: held back. A restaurant inside a hotel:
  only a number on the restaurant's own page. Hotels: a toll-free / shared-cost /
  UAN / foreign number is held back (central reservations, head office); if the
  hotel's own site loads and prints other numbers but not this one, held back.
  A number proposed for two rows, or a restaurant number equal to a hotel number,
  is held back.
- Google CLOSED_PERMANENTLY, or the venue's site says it has closed: nothing filled.
"""
import csv, difflib, gzip, json, math, os, re, sys, unicodedata
from collections import defaultdict
sys.path.insert(0, os.path.dirname(__file__))
from common import clean_url, reg_domain, host, blocked, fold, parse_phone, e164, intl, phones_in
import phonenumbers
from phonenumbers import PhoneNumberType as PT

EXP, PD, PS, MP, SR, OUT = sys.argv[1:7]
ONLY = set(sys.argv[7:])
EXPORT = json.load(open(EXP))
ROWS = [r for r in EXPORT['gaps'] if r['country'] != 'GR' and (not ONLY or r['country'] in ONLY)]
ALL = [r for r in EXPORT['gaps'] if r['country'] != 'GR']
DET = json.load(open(PD))
SEARCH = json.load(open(PS)) if os.path.exists(PS) else {}
MICH = json.load(open(MP))
SIDX = json.load(open(os.path.join(SR, 'index.json')))

GENERIC = set('restaurant restaurante ristorante hotel hotels resort spa the and by at le la les de del di da du des el los il of a an '
              'sushi kitchen bar dining room house table inn ryokan lodge villa villas suites club cuisine maison casa'.split())
CLOSED_WORDS = ('permanently closed', 'closed permanently', 'has closed its doors', 'have closed our doors', 'we have closed',
                'closed for good', 'chiuso definitivamente', 'definitivement fermé', 'endgültig geschlossen',
                '閉店いたしました', '閉店しました', '閉店のお知らせ', '永久停業', '結束營業', '结束营业', '歇業', '歇业')


def dist(a1, o1, a2, o2):
    R = 6371000.0
    p1, p2 = math.radians(a1), math.radians(a2)
    dp, dl = p2 - p1, math.radians(o2 - o1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def page(url):
    """(status, final, text, title) of a fetched URL, plus its sub-pages."""
    d = SIDX.get(url)
    if not d:
        return None
    def load(h):
        try:
            return gzip.open(os.path.join(SR, h + '.html.gz'), 'rt').read()
        except OSError:
            return ''
    body = load(d['file'])
    subs = [(s, load(s['file'])) for s in d.get('subpages', []) if s['status'] == '200']
    return dict(status=d['status'], final=d['final'], body=body, subs=subs)


def visible(body):
    b = re.sub(r'(?is)<(script|style|noscript)[^>]*>.*?</\1>', ' ', body)
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', b)).replace('&amp;', '&')


def title_of(body):
    t = re.search(r'(?is)<title[^>]*>(.*?)</title>', body)
    og = re.search(r'(?is)<meta[^>]+property="og:(?:site_name|title)"[^>]+content="([^"]*)"', body)
    return ' '.join(x.group(1) for x in (t, og) if x)


def name_variants(r, g_en, g_native, m_name):
    """Our name, MICHELIN's and Google's names whole (parenthesised parts dropped);
    split parts only of our own / MICHELIN's name, and only when distinctive."""
    out = []
    def add(x):
        x = x.strip(' )）-–')
        if x and x not in out:
            out.append(x)
    m_name = re.sub(r'\s+in\s+[^,]+$', '', m_name) if m_name else m_name
    for n in (r['name'], m_name, g_en, g_native):
        if n:
            add(n)
            add(re.sub(r'\s*[(（][^)）]*[)）]', '', n))
    for n in (r['name'], m_name):
        if not n:
            continue
        for part in re.split(r',|\s[/|–—-]\s|[(（]', n):
            part = part.strip(' )）')
            words = [w for w in fold(part).split() if w not in GENERIC]
            if is_cjk(part) and len(part) >= 3 or len(words) >= 2 or (words and len(words[0]) >= 6):
                add(part)
    return out


def is_cjk(s):
    return any(unicodedata.east_asian_width(c) in ('W', 'F') for c in s)


def names_in(text, variants, title_only=False):
    """Which name variant the text names: latin as a whole-word phrase of at least
    one non-generic word; CJK as a substring of at least two characters."""
    t = ' ' + fold(text) + ' '
    raw = unicodedata.normalize('NFKC', text).replace(' ', '')
    for v in variants:
        if is_cjk(v):
            vv = unicodedata.normalize('NFKC', v).replace(' ', '')
            vv = re.sub(r'[()（）]', '', vv)
            if len(vv) >= 2 and vv in raw:
                return v
            continue
        f = fold(v)
        words = f.split()
        if not words or all(w in GENERIC for w in words) or len(f.replace(' ', '')) < 4:
            continue
        if ' ' + f + ' ' in t:
            return v
    return None


def name_sim(a, b, extra=()):
    """difflib ratio of the folded names; 0.9 when one name's distinctive words
    are contained in the other's and every extra word is generic or the city
    (or the shorter name still has two distinctive words)."""
    fa, fb = fold(a), fold(b)
    if not fa or not fb:
        return 0.0
    r = difflib.SequenceMatcher(None, fa, fb).ratio()
    ok = GENERIC | {w for e in extra for w in fold(e).split()}
    ta = {w for w in fa.split() if w not in GENERIC}
    tb = {w for w in fb.split() if w not in GENERIC}
    if ta and tb and (ta <= tb or tb <= ta):
        small, big = (ta, tb) if len(ta) <= len(tb) else (tb, ta)
        if len(small) >= 2 or all(w in ok for w in big - small):
            r = max(r, 0.9)
    return r


def fmt_phone(n, google_str, cc):
    """Production's format: Google's international form; +1 numbers with spaces."""
    gn = parse_phone(google_str, cc) if google_str else None
    s = google_str if gn and e164(gn) == e164(n) else intl(n)
    if n.country_code == 1:
        s = s.replace('-', ' ')
    return s


def country_ok(n, cc):
    want = phonenumbers.country_code_for_region(cc)
    return want == 0 or n.country_code == want


# ---------- pass 1: per-row facts ----------
facts = {}
for r in ALL:
    c, cc = r['code'], r['country']
    f = dict(row=r, notes=[], closed=None)
    m = MICH.get(c)
    f['m'] = m if m and m.get('identity_ok') else None
    if r['michelin_url'] and not f['m']:
        f['notes'].append('MICHELIN page not used: ' + (m['identity_note'] if m else 'not fetched'))
    # Google record
    g, gsrc, gnative = None, None, None
    if r['google_place_id'] and c in DET:
        g, gsrc = DET[c]['en'], 'stored'
        gnative = (DET[c].get('native') or {}).get('displayName', {}).get('text')
    f['g'], f['gsrc'], f['gnative'] = g, gsrc, gnative
    f['g_usable'] = False
    f['place'] = None
    if g:
        loc = g.get('location') or {}
        d = dist(r['lat'], r['lon'], loc.get('latitude', 0), loc.get('longitude', 0)) if loc else None
        f['gdist'] = d
        types = g.get('types') or []
        bad = None
        if d is None or d > 500:
            bad = 'stored Place ID record is %s m from the stored point' % (round(d) if d is not None else '?')
        elif r['kind'] == 'hotel' and 'lodging' not in types:
            bad = 'stored Place ID record is not a lodging record (%s)' % g.get('primaryType')
        elif r['kind'] == 'restaurant' and g.get('primaryType') == 'lodging' and name_sim(r['name'], g['displayName']['text'], [r['city']]) < 0.8:
            bad = 'stored Place ID record is a lodging record of another name (%s)' % g['displayName']['text']
        if bad:
            f['notes'].append(bad + ': Google not used as a source')
        else:
            f['g_usable'] = True
        if g.get('businessStatus') == 'CLOSED_PERMANENTLY':
            f['closed'] = 'Google record (stored Place ID) is CLOSED_PERMANENTLY'
        elif g.get('businessStatus') == 'CLOSED_TEMPORARILY':
            f['notes'].append('Google: CLOSED_TEMPORARILY')
    elif not r['google_place_id']:
        if cc == 'CN':
            f['place'] = dict(status='held', reason='mainland China: no Place ID search (Google coverage unreliable)')
        elif c in SEARCH:
            cands = {}
            for p in SEARCH[c].get('results', []) + SEARCH[c].get('lodging_results', []):
                if 'error' in p or p['id'] in cands:
                    continue
                loc = p['location']
                p = dict(p, dist=dist(r['lat'], r['lon'], loc['latitude'], loc['longitude']),
                         sim=max(name_sim(r['name'], p['displayName']['text'], [r['city']]), name_sim(r['name'].split(',')[0], p['displayName']['text'], [r['city']])))
                cands[p['id']] = p
            ok, near = [], []
            mweb = f['m'] and f['m'].get('website') and clean_url(f['m']['website'])
            for p in cands.values():
                types = p.get('types') or []
                if p['sim'] < 0.8 or p['dist'] > 500:
                    if p['dist'] <= 500 and p['sim'] >= 0.6:
                        near.append(p)
                    continue
                if r['kind'] == 'hotel' and 'lodging' not in types:
                    continue
                if r['kind'] == 'restaurant' and 'lodging' in types and p.get('primaryType') == 'lodging' and p['sim'] < 0.9:
                    continue
                if p['dist'] <= 100:
                    ok.append((p, '%d m, name %.2f' % (p['dist'], p['sim'])))
                elif mweb and p.get('websiteUri') and reg_domain(clean_url(p['websiteUri'])) == reg_domain(mweb):
                    ok.append((p, '%d m, name %.2f, official domain %s' % (p['dist'], p['sim'], reg_domain(mweb))))
                else:
                    near.append(p)
            if len(ok) == 1:
                p, why = ok[0]
                if p.get('businessStatus') == 'CLOSED_PERMANENTLY':
                    f['place'] = dict(status='held', reason='matching record is CLOSED_PERMANENTLY: ' + why, cand=p)
                    f['closed'] = 'Google record found by search is CLOSED_PERMANENTLY (%s)' % p['displayName']['text']
                else:
                    f['place'] = dict(status='confirmed', value=p['id'], reason=why, cand=p)
                    f['g'], f['gsrc'], f['g_usable'], f['gdist'] = p, 'search', True, p['dist']
            elif len(ok) > 1:
                f['place'] = dict(status='held', reason='ambiguous: ' + '; '.join('%s %s (%s)' % (p['id'], p['displayName']['text'], w) for p, w in ok))
            else:
                best = min(near or cands.values(), key=lambda p: p['dist'], default=None)
                f['place'] = dict(status='held', reason='no record passes (name >= 0.8, type, < 100 m or < 500 m with official domain)' +
                                  ('; nearest candidate: %s, %d m, name %.2f, %s' % (best['displayName']['text'], best['dist'], best['sim'], best.get('primaryType')) if best else '; no results'))
        else:
            f['place'] = dict(status='held', reason='not searched')
    facts[c] = f

# hotel phone numbers known anywhere in the pass, to catch a restaurant given its hotel's number
hotel_numbers = defaultdict(set)
for c, f in facts.items():
    r = f['row']
    if r['kind'] != 'hotel':
        continue
    for raw in (r['phone'], f['m'] and f['m'].get('telephone'), f['g'] and f['g_usable'] and f['g'].get('internationalPhoneNumber')):
        n = parse_phone(raw, r['country']) if raw else None
        if n:
            hotel_numbers[e164(n)].add(c)


# ---------- pass 2: website and phone ----------
def site_view(url, r, variants, in_hotel):
    """What a candidate site shows. None if not fetched."""
    p = page(url)
    if p is None:
        return None
    v = dict(url=url, status=p['status'], final=p['final'])
    if p['status'] != '200' or not p['body']:
        v['ok'] = False
        return v
    if blocked(p['final']):
        v.update(ok=False, why='redirects to ' + host(p['final']))
        return v
    text = visible(p['body'])
    title = title_of(p['body'])
    v['ok'] = True
    v['cross_domain'] = reg_domain(p['final']) != reg_domain(url)
    v['names'] = names_in(title + ' ' + text, variants)
    v['names_title'] = names_in(title + ' ' + ' '.join(re.split(r'[/_\-.]', p['final'])), variants)
    v['root'] = re.sub(r'^/((en|ja|jp|zh|tw|cn|en-us|en-gb|us|ko|th|it|fr|de|es|pt)(/|$))?', '', re.sub(r'index\.\w+$', '', p['final'].split('://', 1)[-1].partition('/')[2].split('?')[0])) == ''
    v['closed_text'] = next((w for w in CLOSED_WORDS if w in text.lower()), None)
    phones = phones_in(p['body'], r['country'])
    for s, b in p['subs']:
        phones |= phones_in(b, r['country'])
    v['phones'] = phones
    v['own_page'] = bool(v['names_title'])
    return v


decisions = {}
proposed_phone = defaultdict(list)
for r in ROWS:
    c, cc = r['code'], r['country']
    f = facts[c]
    m, g = f['m'], (f['g'] if f['g_usable'] else None)
    in_hotel = r['kind'] == 'restaurant' and bool(r['property_name'] or (m and m.get('stay_hotels')))
    if in_hotel:
        f['notes'].append('restaurant in a hotel (%s)' % (r['property_name'] or ', '.join(m['stay_hotels'])))
    variants = name_variants(r, g and g['displayName']['text'], f['gnative'] if g else None, m and m.get('name'))
    D = dict(place=f['place'], website=None, phone=None)
    # candidate websites
    mw = clean_url(m['website']) if m and m.get('website') else None
    gw = clean_url(g['websiteUri']) if g and g.get('websiteUri') else None
    cands = []
    for src, u in (('MICHELIN', mw), ('Google', gw)):
        if not u:
            continue
        b = blocked(u)
        if b:
            f['notes'].append('%s link is a booking/aggregator/social link (%s): not used' % (src, host(u)))
            continue
        cands.append((src, u))
    views = {u: site_view(u, r, variants, in_hotel) for _, u in cands}
    existing = clean_url(r['website_url']) if r['website_url'] and not blocked(r['website_url']) else None
    if r['website_url'] and blocked(r['website_url']):
        f['notes'].append('production website_url is a booking/aggregator link (%s): left as is (fill-only)' % host(r['website_url']))
    if existing and existing not in views:
        views[existing] = site_view(existing, r, variants, in_hotel)
    closed_site = next((u for u, v in views.items() if v and v.get('ok') and v.get('closed_text') and v.get('own_page')), None)
    if closed_site:
        f['closed'] = f['closed'] or 'own site %s says "%s"' % (closed_site, views[closed_site]['closed_text'])

    # ---- website
    if r['website_url'] is None:
        if f['closed']:
            D['website'] = dict(status='held', reason='closed: ' + f['closed'])
        elif not cands:
            D['website'] = dict(status='held', reason='no usable candidate (MICHELIN %s, Google %s)' % ('none' if not (m and m.get('website')) else 'blocked', 'none' if not (g and g.get('websiteUri')) else 'blocked'))
        else:
            chosen, why = None, None
            good = [(s, u) for s, u in cands if views[u] and views[u].get('ok') and views[u]['own_page'] and not views[u]['cross_domain']]
            if mw and gw and mw in [u for _, u in cands] and gw in [u for _, u in cands] and reg_domain(mw) == reg_domain(gw):
                pick = next(((s, u) for s, u in good), None) or ('MICHELIN', mw)
                v = views[pick[1]]
                if (in_hotel or r['kind'] == 'hotel') and v and v.get('ok') and v['root'] and not v['names_title']:
                    why = 'MICHELIN and Google agree on %s, but it is a site root that does not name the venue in its title (group or hotel site)' % reg_domain(mw)
                else:
                    chosen, why = pick[1], 'MICHELIN and Google agree on the domain %s' % reg_domain(mw) + (', page loads and names the venue' if v and v.get('ok') and v['own_page'] else ' (page not confirmed: %s)' % (v and v.get('status')))
            elif good:
                if len({reg_domain(u) for _, u in good}) > 1:
                    why = 'two different sites both name the venue: ' + ', '.join(u for _, u in good)
                else:
                    s, u = good[0]
                    chosen, why = u, '%s link loads and names the venue ("%s")' % (s, views[u]['names_title'] or views[u]['names'])
            else:
                parts = []
                for s, u in cands:
                    v = views[u]
                    if v is None:
                        parts.append('%s %s not fetched' % (s, u))
                    elif not v.get('ok'):
                        parts.append('%s %s: HTTP %s %s' % (s, u, v['status'], v.get('why', '')))
                    elif v['cross_domain']:
                        parts.append('%s %s redirects to another domain %s' % (s, u, host(v['final'])))
                    else:
                        parts.append('%s %s loads but %s' % (s, u, 'does not name the venue' if not v['names'] else 'names it only in the body, not in its title/path (hotel or group page)'))
                why = '; '.join(parts)
            D['website'] = dict(status='confirmed', value=chosen, reason=why) if chosen else dict(status='held', reason=why)
    # own site for phones: the confirmed website, or production's existing site
    own = None
    for u in ([D['website']['value']] if D['website'] and D['website'].get('value') else []) + ([existing] if existing else []) + [u for _, u in cands]:
        v = views.get(u)
        if v and v.get('ok') and v['own_page'] and not v['cross_domain']:
            own = v
            break
    # ---- phone
    if r['phone'] is None:
        mp = parse_phone(m.get('telephone'), cc) if m and m.get('telephone') else None
        gs = g.get('internationalPhoneNumber') if g else None
        gp = parse_phone(gs, cc) if gs else None
        on_site = own['phones'] if own else set()
        res = None
        if f['closed']:
            res = dict(status='held', reason='closed: ' + f['closed'])
        elif not mp and not gp:
            res = dict(status='held', reason='no number from MICHELIN or Google')
        else:
            srcs = {}
            for s, n in (('MICHELIN', mp), ('Google', gp)):
                if n:
                    srcs.setdefault(e164(n), []).append(s)
            agree = [k for k, v in srcs.items() if len(v) == 2]
            site_hits = [k for k in srcs if k in on_site]
            pick, why = None, None
            if len(site_hits) == 1:
                pick, why = site_hits[0], '%s; printed on the own site %s' % ('+'.join(srcs[site_hits[0]]), own['url'])
            elif len(site_hits) > 1:
                why = 'MICHELIN and Google differ and both numbers are on the own site'
            elif agree and not in_hotel:
                if r['kind'] == 'hotel' and own and on_site:
                    why = 'MICHELIN and Google agree, but the hotel\'s own site prints other numbers (%s), not this one' % ', '.join(sorted(on_site)[:4])
                else:
                    pick, why = agree[0], 'MICHELIN and Google agree' + ('' if own else ' (own site not readable)')
            elif agree and in_hotel:
                why = 'MICHELIN and Google agree, but a restaurant in a hotel needs the number on its own page' + (' (not on %s)' % own['url'] if own else ' (no own page readable)')
            else:
                why = 'one source only (%s)' % ', '.join('%s %s' % ('+'.join(v), k) for k, v in srcs.items()) + \
                      ('; not on the own site %s' % own['url'] if own else '; no own site readable')
            if pick:
                n = phonenumbers.parse(pick)
                t = phonenumbers.number_type(n)
                if not country_ok(n, cc):
                    why, pick = 'number is not in the venue\'s country (%s): %s' % (pick, why), None
                elif r['kind'] == 'hotel' and t in (PT.TOLL_FREE, PT.SHARED_COST, PT.UAN, PT.PREMIUM_RATE):
                    why, pick = 'central-reservations type number (%s, %s): %s' % (pick, str(t).split('.')[-1], why), None
                elif t in (PT.VOIP, PT.UAN, PT.TOLL_FREE, PT.SHARED_COST) and pick not in on_site:
                    why, pick = 'forwarding / non-geographic number not on the own site (%s): %s' % (pick, why), None
                elif r['kind'] == 'restaurant' and pick in hotel_numbers and (pick not in on_site or not in_hotel):
                    why, pick = 'same number as hotel %s: %s' % (', '.join(sorted(hotel_numbers[pick])), why), None
            if pick:
                res = dict(status='confirmed', value=fmt_phone(phonenumbers.parse(pick), gs, cc), e164=pick, reason=why)
                proposed_phone[pick].append(c)
            else:
                res = dict(status='held', reason=why)
        D['phone'] = res
    D['site'] = own
    D['views'] = views
    D['in_hotel'] = in_hotel
    decisions[c] = D

# a number proposed for two rows is held back for both
for num, codes in proposed_phone.items():
    if len(codes) > 1:
        for c in codes:
            D = decisions[c]
            D['phone'] = dict(status='held', reason='same number proposed for %s: %s' % (', '.join(codes), D['phone']['reason']))
# a Place ID proposed for two rows of the same table is held back
seen = defaultdict(list)
for c, D in decisions.items():
    if D['place'] and D['place'].get('value'):
        seen[(facts[c]['row']['kind'], D['place']['value'])].append(c)
for k, codes in seen.items():
    if len(codes) > 1:
        for c in codes:
            decisions[c]['place'] = dict(status='held', reason='same record found for %s: %s' % (', '.join(codes), decisions[c]['place']['reason']))

# ---------- write ----------
COLS = ['kind', 'code', 'country', 'name', 'city', 'property_name', 'in_hotel', 'michelin_url', 'need_place_id', 'need_phone', 'need_website',
        'michelin_page', 'michelin_name', 'michelin_phone', 'michelin_website', 'google_source', 'google_id', 'google_name',
        'google_distance_m', 'google_primary_type', 'business_status', 'google_phone', 'google_website', 'own_site_checked',
        'own_site_phones', 'place_id', 'place_status', 'place_reason', 'phone', 'phone_status', 'phone_reason',
        'website', 'website_status', 'website_reason', 'confidence', 'match_method', 'evidence_source', 'status', 'notes']
by_cc = defaultdict(list)
for r in ROWS:
    c = r['code']
    f, D = facts[c], decisions[c]
    m, g = f['m'], f['g']
    def st(x):
        return '' if x is None else x['status']
    filled = [k for k in ('place', 'phone', 'website') if D[k] and D[k]['status'] == 'confirmed']
    ev = []
    if m:
        ev.append('MICHELIN page %s (fetched 2026-11-04)' % r['michelin_url'])
    if g:
        ev.append('Google Place Details %s (%s, 2026-11-04)' % (g['id'], f['gsrc']))
    if D['site']:
        ev.append('own site %s' % D['site']['url'])
    conf = ''
    if filled:
        conf = 'high' if all('agree' in D[k]['reason'] or 'own site' in D[k]['reason'] or 'names the venue' in D[k]['reason'] or k == 'place' for k in filled) else 'medium'
    by_cc[r['country']].append({
        'kind': r['kind'], 'code': c, 'country': r['country'], 'name': r['name'], 'city': r['city'], 'property_name': r['property_name'] or '',
        'in_hotel': D['in_hotel'], 'michelin_url': r['michelin_url'] or '',
        'need_place_id': not r['google_place_id'], 'need_phone': r['phone'] is None, 'need_website': r['website_url'] is None,
        'michelin_page': ('used' if m else ('not used: ' + (MICH[c]['identity_note'] if c in MICH else 'not fetched'))) if r['michelin_url'] else 'no michelin_url',
        'michelin_name': (m or {}).get('name', ''), 'michelin_phone': (m or {}).get('telephone') or '', 'michelin_website': (m or {}).get('website') or '',
        'google_source': f['gsrc'] or '', 'google_id': (g or {}).get('id', ''), 'google_name': (g or {}).get('displayName', {}).get('text', ''),
        'google_distance_m': round(f['gdist']) if f.get('gdist') is not None else '', 'google_primary_type': (g or {}).get('primaryType', ''),
        'business_status': (g or {}).get('businessStatus', ''), 'google_phone': (g or {}).get('internationalPhoneNumber', ''),
        'google_website': (g or {}).get('websiteUri', ''),
        'own_site_checked': '; '.join('%s -> %s' % (u, v['status'] if v else 'not fetched') for u, v in D['views'].items()),
        'own_site_phones': ' '.join(sorted(D['site']['phones']))[:300] if D['site'] else '',
        'place_id': (D['place'] or {}).get('value', ''), 'place_status': st(D['place']) or 'not needed', 'place_reason': (D['place'] or {}).get('reason', ''),
        'phone': (D['phone'] or {}).get('value', ''), 'phone_status': st(D['phone']) or 'not needed', 'phone_reason': (D['phone'] or {}).get('reason', ''),
        'website': (D['website'] or {}).get('value', ''), 'website_status': st(D['website']) or 'not needed', 'website_reason': (D['website'] or {}).get('reason', ''),
        'confidence': conf, 'match_method': 'code_exact', 'evidence_source': '; '.join(ev),
        'status': 'rejected' if f['closed'] else ('proposed' if filled else 'unresolved'),
        'notes': '; '.join(dict.fromkeys(f['notes'] + ([f['closed']] if f['closed'] else []))),
    })
os.makedirs(OUT, exist_ok=True)
for cc, rows in sorted(by_cc.items()):
    with open(os.path.join(OUT, cc.lower() + '_contact_fill.csv'), 'w', newline='') as fh:
        w = csv.DictWriter(fh, COLS)
        w.writeheader()
        w.writerows(rows)
    n = lambda k: sum(1 for x in rows if x[k + '_status'] == 'confirmed')
    need = lambda k: sum(1 for x in rows if x[k + '_status'] not in ('not needed',))
    print(cc, len(rows), 'place %d/%d phone %d/%d web %d/%d' % (n('place'), need('place'), n('phone'), need('phone'), n('website'), need('website')))
