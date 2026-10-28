import sys, re, json, html, pathlib
d = pathlib.Path(sys.argv[1]); rows = {}
card_re = re.compile(r'class="card__menu selection-card[^"]*"\s+data-index="\d+"\s+data-id="(\d+)"\s+data-lat="([^"]*)"\s+data-lng="([^"]*)"(.*?)(?=class="card__menu selection-card|\Z)', re.S)
for f in sorted(d.glob("list_*.html")):
    t = f.read_text()
    tot = re.search(r'1-48 of (\d+)|(\d+)-(\d+) of (\d+)', t)
    for mid, lat, lng, body in card_re.findall(t):
        g = lambda a: html.unescape(m.group(1)) if (m := re.search(a + r'="([^"]*)"', body)) else None
        href = re.search(r'<a href="(/en/[^"]+/restaurant/[^"]+)"', body)
        loc = re.search(r'card__menu-footer--score[^>]*>\s*([^<]+)<', body)
        locs = loc.group(1).strip() if loc else ""
        if not locs.endswith("France"): continue
        rows[mid] = dict(mid=mid, name=g("data-restaurant-name"), city=g("data-dtm-city"), region=g("data-dtm-region"),
                         dist=g("data-dtm-distinction"), lat=lat, lng=lng, url="https://guide.michelin.com" + href.group(1) if href else None, page=f.name)
print(len(rows), file=sys.stderr)
from collections import Counter; print(Counter(r["dist"] for r in rows.values()), file=sys.stderr)
json.dump(list(rows.values()), open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
