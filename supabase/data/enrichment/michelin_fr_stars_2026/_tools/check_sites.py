"""For each (key, website): fetch homepage + a few contact-like pages, collect phone numbers.
Input JSON list of {key, website}. Output JSON {key: {pages:[...], phones:{e164:[context...]}, error}}."""
import sys, json, re, html, hashlib, pathlib, urllib.request, urllib.parse, ssl, concurrent.futures as cf
items = json.load(open(sys.argv[1])); outp = sys.argv[2]; cache = pathlib.Path(sys.argv[3]); cache.mkdir(exist_ok=True)
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
ctx = ssl.create_default_context(); import time
PH = re.compile(r'(?:\+|00)\s?33\s?\(?0?\)?[\s.\-]?[1-9](?:[\s.\-]?\d{2}){4}|\b0[1-9](?:[\s.\-]?\d{2}){4}\b|(?:\+|00)\s?377[\s.\-]?\d{2}(?:[\s.\-]?\d{2}){3}')
def norm(s):
    d = re.sub(r'\D', '', s)
    if d.startswith('0033'): d = d[2:]
    if d.startswith('330'): d = '33' + d[3:]
    if d.startswith('0') and len(d) == 10: d = '33' + d[1:]
    return '+' + d if d.startswith('33') and len(d) == 11 else None
def get(url):
    f = cache / (hashlib.md5(url.encode()).hexdigest() + ".html")
    if f.exists(): return f.read_text(errors="replace"), json.loads((cache / (f.name + ".meta")).read_text())["final"]
    r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "fr,en"}), timeout=20, context=ctx)
    b = r.read(3_000_000).decode(r.headers.get_content_charset() or "utf-8", errors="replace")
    f.write_text(b); (cache / (f.name + ".meta")).write_text(json.dumps({"url": url, "final": r.geturl()}))
    return b, r.geturl()
def text(h): return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', re.sub(r'<script(?![^>]*ld\+json).*?</script>|<style.*?</style>', ' ', h, flags=re.S))))
KW = re.compile(r'contact|reserv|réserv|infos|acces|accès|nous-trouver|venir|book|booking|practical|pratique|restaurant', re.I)
def one(it):
    time.sleep(3)
    res = {"key": it["key"], "website": it["website"], "pages": [], "phones": {}, "error": None}
    try:
        h, final = get(it["website"]); res["final"] = final
        pages = [(final, h)]
        host = urllib.parse.urlparse(final).netloc
        links = []
        for m in re.finditer(r'href="([^"#]+)"', h):
            u = urllib.parse.urljoin(final, html.unescape(m.group(1)))
            if urllib.parse.urlparse(u).netloc == host and KW.search(urllib.parse.urlparse(u).path) and u not in links and u != final: links.append(u)
        for u in links[:4]:
            try: pages.append((u, get(u)[0]))
            except Exception: pass
        for u, h in pages:
            res["pages"].append(u)
            for m in re.finditer(r'href="tel:([^"]+)"', h):
                n = norm(urllib.parse.unquote(m.group(1)))
                if n: res["phones"].setdefault(n, []).append("tel-link @ " + u)
            t = text(h)
            for m in PH.finditer(t):
                n = norm(m.group(0))
                if n: res["phones"].setdefault(n, []).append(t[max(0, m.start()-80):m.end()+20].strip() + " @ " + u)
        for n in res["phones"]: res["phones"][n] = res["phones"][n][:3]
    except Exception as e:
        res["error"] = (type(e).__name__ + ": " + str(e))[:150]
    return res
with cf.ThreadPoolExecutor(1) as ex: out = {r["key"]: r for r in ex.map(one, items)}
json.dump(out, open(outp, "w"), ensure_ascii=False, indent=1)
print(len(out), sum(1 for r in out.values() if r["error"]))
