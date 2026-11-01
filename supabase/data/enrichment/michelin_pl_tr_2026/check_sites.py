#!/usr/bin/env python3
"""Check each restaurant's MICHELIN website link: does it load, name the
restaurant, and print MICHELIN's phone number? (PL/TR pass, 2026-11-01)
  python3 check_sites.py <restaurant_pages.json> <out.json>
One plain GET per site (curl, 20 s timeout, 1 s apart); the home page plus, if
the phone is not there, one contact page linked from it."""
import json, re, subprocess, sys, time, unicodedata
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'

def get(u):
    p = subprocess.run(['curl', '-s', '-L', '--compressed', '-m', '20', '-A', UA, '-w', '\n%{http_code} %{url_effective}', u], capture_output=True, text=True, errors='replace')
    body, _, tail = p.stdout.rpartition('\n'); code, _, final = tail.partition(' ')
    time.sleep(1)
    return code, final, body

def fold(s):
    return ''.join(c for c in unicodedata.normalize('NFKD', s or '') if not unicodedata.combining(c)).lower().replace('ı', 'i')

def digits(s):
    return re.sub(r'\D', '', s or '')

def has_phone(body, phone):
    d = digits(phone)
    local = d[2:]  # drop the 48 / 90 country code
    flat = digits(body)
    return local in flat or ('0' + local) in flat

out = []
for p in json.load(open(sys.argv[1]))['pages']:
    ld = p['ld'] or {}
    name, phone, web = ld.get('name'), ld.get('telephone'), p['website']
    r = dict(url=p['url'], name=name, michelin_phone=phone, website=web)
    if web:
        code, final, body = get(web)
        r.update(status=code, final=final, length=len(body))
        key = [t for t in re.split(r'\W+', fold(name)) if len(t) > 2 and t not in ('by', 'the', 'restaurant')]
        r['names_venue'] = any(t in fold(body) for t in key)
        r['phone_on_site'] = has_phone(body, phone) if phone else None
        if phone and not r['phone_on_site']:
            links = re.findall(r'href="([^"#]*(?:contact|kontakt|iletisim|iletişim|rezerwacj|reservation)[^"#]*)"', body, re.I)
            if links:
                l = links[0] if links[0].startswith('http') else re.match(r'https?://[^/]+', final).group(0) + '/' + links[0].lstrip('/')
                c2, f2, b2 = get(l)
                r.update(contact_page=f2, contact_status=c2, phone_on_contact=has_phone(b2, phone))
    out.append(r)
    print(r, file=sys.stderr)
json.dump(out, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)
