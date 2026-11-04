#!/usr/bin/env python3
"""Fetch every stored michelin_url in the world contact-gap export (GR skipped)
and keep the raw HTML, gzipped, one file per row code, so the decisions can be
re-run offline. guide.michelin.com only; pacing as in ../michelin_gr/fetch_michelin.py:
2.5 s between requests, on HTTP 202 (throttle) wait 180 s and retry up to five times.

  python3 fetch_michelin_raw.py <export.json> <raw_dir>
Resumable: a code whose file exists is skipped. Writes <raw_dir>/index.json
(code -> status, final url)."""
import gzip, json, os, subprocess, sys, time

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'
EXP, RAW = sys.argv[1:3]
os.makedirs(RAW, exist_ok=True)
idx_path = os.path.join(RAW, 'index.json')
idx = json.load(open(idx_path)) if os.path.exists(idx_path) else {}


def get(url):
    for _ in range(6):
        p = subprocess.run(['curl', '-s', '-L', '--compressed', '-m', '40', '-A', UA, '-w', '\n%{http_code} %{url_effective}', url],
                           capture_output=True, text=True, errors='replace')
        body, _, tail = p.stdout.rpartition('\n')
        code, _, final = tail.partition(' ')
        time.sleep(2.5)
        if code == '202':
            print('  202, waiting 180 s', url, file=sys.stderr, flush=True)
            time.sleep(180)
            continue
        return code, final, body
    return '202', url, ''


ALL = [r for r in json.load(open(EXP))['gaps'] if r['country'] != 'GR']
rows = [r for r in ALL if r['michelin_url']]
# countries with the most export rows first, as the run is ordered
order = {}
for r in ALL:
    order[r['country']] = order.get(r['country'], 0) + 1
rows.sort(key=lambda r: (-order[r['country']], r['country'], r['kind'], r['code']))
for i, r in enumerate(rows):
    if r['code'] in idx and idx[r['code']]['status'] not in ('000', '202'):
        continue
    code, final, body = get(r['michelin_url'])
    with gzip.open(os.path.join(RAW, r['code'] + '.html.gz'), 'wt') as f:
        f.write(body)
    idx[r['code']] = dict(url=r['michelin_url'], status=code, final=final,
                         fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
    print(i, len(rows), r['country'], code, r['code'], file=sys.stderr, flush=True)
    if i % 10 == 0:
        json.dump(idx, open(idx_path, 'w'), indent=1)
json.dump(idx, open(idx_path, 'w'), indent=1)
print('done', len(idx))
