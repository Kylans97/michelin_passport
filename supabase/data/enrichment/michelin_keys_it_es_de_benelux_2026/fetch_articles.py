#!/usr/bin/env python3
"""Save MICHELIN Key articles as text plus their hotel links in reading order, each
link with the last heading (h2/h3/h4) printed before it (2026-10-31).

  python3 fetch_articles.py <out_dir> <edition> <url> [<url> ...]

<edition> is the Key edition the article lists (2024, 2025, 2026), written into the
JSON as `edition`; build_keys.py reads tiers only from articles that carry one.
"""
import html, json, os, re, sys, time, subprocess
from fetch_michelin import get


def main():
    out = sys.argv[1]
    edition = int(sys.argv[2])
    for url in sys.argv[3:]:
        code, final, body = get(url)
        name = re.sub(r'[^a-z0-9]+', '_', url.split('guide.michelin.com/')[1].lower()).strip('_')
        snap = re.search(r'web\.archive\.org/web/(\d{14})', url)
        if snap:  # MICHELIN's own page as the Internet Archive captured it (raw id_ capture)
            name = 'wayback_' + snap.group(1)[:8] + '_' + name
        if code != 200:
            print(code, url); continue
        b = re.sub(r'<(script|style)\b.*?</\1>|<!--.*?-->', '', body, flags=re.S)
        title = re.search(r'<title>(.*?)</title>', body, re.S)
        date = re.search(r'"datePublished"\s*:\s*"([^"]+)"', body)
        mod = re.search(r'"dateModified"\s*:\s*"([^"]+)"', body)
        links, head, h2 = [], None, None
        for m in re.finditer(r'<(h[1-4])[^>]*>(.*?)</\1>|<a [^>]*href="([^"]*(?:/hotels-stays/|/h/)[^"]+)"[^>]*>(.*?)</a>', b, re.S):
            if m.group(1):
                head = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', m.group(2)))).strip()
                if m.group(1) in ('h1', 'h2'):
                    h2 = head  # section heading; h3/h4 (a country inside a tier, Benelux) keep it
            else:
                pre = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', b[max(0, m.start() - 120):m.start()]))).strip()
                links.append(dict(heading=head, section=h2, prefix=pre[-60:], href=m.group(3), text=re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', m.group(4)))).strip()))
        text = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', b)))
        meta = dict(url=url, final_url=final, status=code, title=html.unescape(title.group(1)).strip() if title else None,
                    date_published=date.group(1) if date else None, date_modified=mod.group(1) if mod else None,
                    read='2026-10-31 (curl)', archived_at=snap.group(1) if snap else None)
        json.dump(dict(meta=meta, edition=edition, links=links, text=text), open(os.path.join(out, f'michelin_article_{name}.json'), 'w'),
                  ensure_ascii=False, indent=1)
        print(code, meta['title'], meta['date_published'], len(links), 'hotel links'); continue
        json.dump(dict(meta=meta, links=links, text=text), open(os.path.join(out, f'michelin_article_{name}.json'), 'w'),
                  ensure_ascii=False, indent=1)
        print(code, meta['title'], meta['date_published'], len(links), 'hotel links')


if __name__ == '__main__':
    main()
