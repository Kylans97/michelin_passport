#!/usr/bin/env python3
"""Fetch candidate venue sites once each and keep the raw HTML (gzipped,
named by sha1 of the URL) so decisions can be re-run offline. For each home
page, also fetch up to three contact/access/reservation pages on the same
registrable domain (the phone is often only there).

  python3 fetch_sites.py <urls.txt> <raw_dir>
Plain curl GET, 20 s timeout, 8 sites in parallel. Resumable via <raw_dir>/index.json."""
import concurrent.futures as cf, gzip, hashlib, json, os, re, subprocess, sys, threading, time
from urllib.parse import urljoin
sys.path.insert(0, os.path.dirname(__file__))
from common import reg_domain

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'
URLS, RAW = sys.argv[1:3]
os.makedirs(RAW, exist_ok=True)
IP = os.path.join(RAW, 'index.json')
idx = json.load(open(IP)) if os.path.exists(IP) else {}
lock = threading.Lock()
CONTACT = re.compile(r'href="([^"#]*(?:contact|kontakt|contatt|contacto|access|acces|reserv|booking|about|info|location|visit|'
                     r'%e3%82%a2%e3%82%af%e3%82%bb%e3%82%b9|アクセス|お問い合わせ|予約|店舗|会社概要|聯絡|联系|聯繫|預約|预约|關於|关于)[^"#]*)"', re.I)


def fetch(u):
    p = subprocess.run(['curl', '-s', '-L', '--compressed', '-m', '20', '--max-redirs', '8', '-A', UA,
                        '-H', 'Accept-Language: en,ja;q=0.8,zh;q=0.7,*;q=0.5', '-w', '\n%{http_code} %{url_effective}', u],
                       capture_output=True, errors='replace', text=True)
    body, _, tail = p.stdout.rpartition('\n')
    code, _, final = tail.partition(' ')
    h = hashlib.sha1(u.encode()).hexdigest()
    with gzip.open(os.path.join(RAW, h + '.html.gz'), 'wt') as f:
        f.write(body)
    return dict(status=code, final=final, length=len(body), file=h, fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())), body


def work(u):
    if u in idx:
        return
    d, body = fetch(u)
    subs = []
    if d['status'] == '200':
        base = d['final'] or u
        seen = set()
        for m in CONTACT.finditer(body):
            l = urljoin(base, m.group(1).replace('&amp;', '&'))
            if not l.startswith('http') or reg_domain(l) != reg_domain(base) or l in seen or l.rstrip('/') == base.rstrip('/'):
                continue
            if re.search(r'\.(jpg|png|pdf|css|js|svg|webp)(\?|$)', l, re.I):
                continue
            seen.add(l)
            if len(seen) > 3:
                break
            sd, _ = fetch(l)
            sd['url'] = l
            subs.append(sd)
    d['subpages'] = subs
    with lock:
        idx[u] = d
        print(len(idx), d['status'], u, file=sys.stderr, flush=True)
        if len(idx) % 20 == 0:
            json.dump(idx, open(IP, 'w'), indent=1)


urls = sorted({u.strip() for u in open(URLS) if u.strip()})
with cf.ThreadPoolExecutor(int(os.environ.get("WORKERS", "8"))) as ex:
    list(ex.map(work, urls))
json.dump(idx, open(IP, 'w'), indent=1)
print('done', len(idx))
