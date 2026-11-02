#!/usr/bin/env python3
"""Fetch each restaurant's World's 50 Best Discovery "style" line (2026-11-01).
the50.com only.

  python3 -I fetch_w50b.py <restaurants_LIVE.csv> <out.jsonl>   (resumable)

The Discovery page has no cuisine field. Each venue card carries a short
50 Best-written style line (<p class="style">, e.g. "Hyper-creative fine
Indian"), but a venue's own page shows only its neighbours' cards. So the
line is read from the card on a neighbouring page whose href is exactly our
stored worlds_50_best_url path — identity by URL, never by name. Up to eight
neighbour pages per venue; not found is recorded, not guessed.

  python3 -I fetch_w50b.py --deeper <in.jsonl> <out.jsonl>

A second pass for venues the first left without a style line: breadth-first
over neighbours of neighbours, up to 30 pages, same exact-URL rule. The first
pass's record is kept; the deeper result is written to its own file.
"""
import csv, html, json, os, re, subprocess, sys, time, urllib.parse

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'
BASE = 'https://www.the50.com'
CARD = re.compile(r'href="(/discovery/Establishments/[^"]+)" ><h2>([^<]*)</h2></a><p>([^<]*)</p><p class="style " >([^<]*)<')


def get(url):
    p = subprocess.run(['curl', '-s', '-L', '--compressed', '--max-time', '60', '-A', UA, '-w', '\n%{http_code}', url],
                       capture_output=True)
    body, _, code = p.stdout.decode('utf-8', 'replace').rpartition('\n')
    time.sleep(2.0)
    return int(code or 0), body


def norm(path):
    return urllib.parse.unquote(path).rstrip('/')


def main(src, out):
    done = {json.loads(l)['restaurant_id'] for l in open(out)} if os.path.exists(out) else set()
    rows = [r for r in csv.DictReader(open(src)) if r['worlds_50_best_url'].startswith('http') and r['id'] not in done]
    with open(out, 'a') as f:
        for r in rows:
            own = norm(urllib.parse.urlparse(r['worlds_50_best_url']).path)
            code, body = get(BASE + urllib.parse.quote(own))
            title = re.search(r'<title>([^<]*)</title>', body)
            found, tried = None, []
            for href, *_ in CARD.findall(body)[:8]:
                nurl = BASE + urllib.parse.quote(norm(href))
                tried.append(nurl)
                _, nb = get(nurl)
                for h, name, place, style in CARD.findall(nb):
                    if norm(h) == own:
                        found = dict(style=html.unescape(style).strip(), card_name=html.unescape(name),
                                     card_place=html.unescape(place), evidence_page=nurl)
                        break
                if found:
                    break
            rec = dict(restaurant_id=r['id'], restaurant_code=r['restaurant_code'], country_code=r['country_code'],
                       url=r['worlds_50_best_url'], status=code, title=html.unescape(title.group(1)) if title else None,
                       neighbours_tried=len(tried), fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                       **(found or dict(style=None)))
            f.write(json.dumps(rec, ensure_ascii=False) + '\n')
            f.flush()
            print(r['restaurant_code'], code, rec['style'], file=sys.stderr)


def deeper(src, out):
    done = {json.loads(l)['restaurant_id'] for l in open(out)} if os.path.exists(out) else set()
    for line in open(src):
        r = json.loads(line)
        if r['style'] or r['status'] != 200 or r['restaurant_id'] in done:
            continue
        own = norm(urllib.parse.urlparse(r['url']).path)
        queue, seen, found = [own], {own}, None
        pages = 0
        while queue and pages < 30 and not found:
            path = queue.pop(0)
            _, b = get(BASE + urllib.parse.quote(path))
            pages += 1
            for h, name, place, style in CARD.findall(b):
                if norm(h) == own and path != own:
                    found = dict(style=html.unescape(style).strip(), card_name=html.unescape(name),
                                 card_place=html.unescape(place), evidence_page=BASE + urllib.parse.quote(path))
                    break
                if norm(h) not in seen:
                    seen.add(norm(h))
                    queue.append(norm(h))
        rec = dict(restaurant_id=r['restaurant_id'], restaurant_code=r['restaurant_code'], country_code=r['country_code'],
                   url=r['url'], status=r['status'], pages_tried=pages,
                   fetched_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), **(found or dict(style=None)))
        with open(out, 'a') as f:
            f.write(json.dumps(rec, ensure_ascii=False) + '\n')
        print(r['restaurant_code'], pages, rec['style'], file=sys.stderr)


if __name__ == '__main__':
    if sys.argv[1] == '--deeper':
        deeper(*sys.argv[2:])
    else:
        main(*sys.argv[1:])
