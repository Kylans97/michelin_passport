"""Verify missing World's 50 Best rank-years against archived official
entry pages.

A slot (year, rank) is VERIFIED for one of our restaurants only when the
archived official entry page for that slot (a) states that exact year and
rank in its title and (b) shows our phone, our own website domain, or our
street + house number. Name and city only chose which page to fetch.

usage: python3 -I verify_slots.py <dir with official_lists.json etc.>
"""
import csv, hashlib, html, json, os, re, subprocess, sys, time, unicodedata

D = sys.argv[1]
SNAP = {2021: '20211109', 2022: '20220904', 2023: '20230905', 2024: '20241002'}
links = {int(y): {int(r): u for r, u in e.items()} for y, e in json.load(open(f'{D}/entry_links.json')).items()}
contacts = json.load(open(f'{D}/contacts.json'))
os.makedirs(f'{D}/entries', exist_ok=True)


def norm(s):
    s = unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', ' ', s).strip()


def domain(u):
    return re.sub(r'^www\d?\.', '', re.sub(r'^https?://', '', (u or '').strip().lower()).split('/')[0])


def fetch(y, path):
    url = f'https://web.archive.org/web/{SNAP[y]}id_/https://www.theworlds50best.com{path}'
    p = f'{D}/entries/' + hashlib.sha1(url.encode()).hexdigest() + '.html'
    for _ in range(3):
        if os.path.exists(p) and os.path.getsize(p) >= 2000:
            break
        time.sleep(3)
        subprocess.run(['curl', '-sL', '--max-time', '120', '-o', p, url])
    if not os.path.exists(p):
        return url, ''  # unreachable: counts as no evidence, never a match
    return url, open(p, encoding='utf-8', errors='replace').read()


rows = [r for r in csv.DictReader(open(sys.argv[2] if len(sys.argv) > 2 else f'{D}/missing_slots_2021_2024.csv'))
        if r['in_catalogue'] != 'no' and int(r['rank']) <= 50]
out = []
for r in rows:
    y, rk = int(r['year']), int(r['rank'])
    path = links.get(y, {}).get(rk)
    rec = dict(r, entry_url='', page_title='', evidence='', code='', status='no_entry_page')
    if path:
        url, s = fetch(y, path)
        title = html.unescape((re.findall(r'(?s)<title>(.*?)</title>', s) or [''])[0]).strip()
        m = re.search(r"(\d{4})\s*\|\s*Ranked No\.\s*(\d+)", title)
        t = re.sub(r'(?s)<script.*?</script>|<style.*?</style>', '', s)
        text = ' ' + norm(html.unescape(re.sub(r'<[^>]+>', ' ', t))) + ' '
        digits = re.sub(r'\D', '', html.unescape(re.sub(r'<[^>]+>', ' ', t)))
        sites = {domain(h) for h in re.findall(r'href="(https?://[^"]+)"', s)}
        rec.update(entry_url=url, page_title=title)
        slot_ok = bool(m) and int(m.group(1)) == y and int(m.group(2)) == rk
        for code in r['candidate_codes'].split():
            c = contacts[code]
            ph = re.sub(r'\D', '', c.get('phone') or '')[-8:]
            seg = next((x for x in (c.get('address') or '').split(',') if re.search(r'\d', x)), '')
            ev = [k for k, v in [
                ('phone', len(ph) == 8 and ph in digits),
                ('website', bool(c.get('website_url')) and domain(c['website_url']) in sites
                 and len(re.sub(r'^https?://[^/]+', '', c['website_url']).strip('/').split('/')) <= 2),
                ('address', len(norm(seg)) >= 6 and f' {norm(seg)} ' in text)] if v]
            if slot_ok and ev:
                rec.update(code=code, evidence=' '.join(ev), status='verified')
                break
        else:
            rec['status'] = 'review' if slot_ok else 'slot_mismatch'
    out.append(rec)
    print(rec['status'], y, rk, r['official_name'], rec['code'], rec['evidence'], file=sys.stderr)

f = ['year', 'rank', 'official_name', 'official_city', 'status', 'code', 'evidence', 'page_title', 'entry_url', 'candidate_codes', 'candidate_names']
w = csv.DictWriter(open(sys.argv[3] if len(sys.argv) > 3 else f'{D}/top50_slots_verified.csv', 'w', newline=''), fieldnames=f, extrasaction='ignore')
w.writeheader()
w.writerows(out)
from collections import Counter
print(Counter(r['status'] for r in out))
