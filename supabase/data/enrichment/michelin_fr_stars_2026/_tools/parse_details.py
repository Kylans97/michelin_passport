import sys, json, re, html, pathlib
d = pathlib.Path(sys.argv[1]); out = {}
for line in open(d / "_log.jsonl"):
    e = json.loads(line); k = e["key"]
    rec = dict(key=k, status=e["status"], final=e["final"])
    if e["file"]:
        t = (d / e["file"]).read_text(errors="replace")
        ld = None
        for m in re.findall(r'<script type="application/ld\+json">(.*?)</script>', t, re.S):
            try:
                j = json.loads(m)
            except Exception: continue
            if isinstance(j, dict) and j.get("@type") == "Restaurant": ld = j
        if ld:
            a = ld.get("address", {})
            rec.update(name=ld.get("name"), street=a.get("streetAddress"), postcode=a.get("postalCode"), locality=a.get("addressLocality"),
                       country=a.get("addressCountry"), phone=ld.get("telephone"), lat=ld.get("latitude"), lng=ld.get("longitude"),
                       cuisine=ld.get("servesCuisine"), star=ld.get("starRating"), award_year=(ld.get("award") or {}).get("dateAwarded"),
                       url=ld.get("url"))
        w = re.search(r'href="([^"]+)"[^>]*data-event="CTA_website"', t) or re.search(r'data-event="CTA_website"[^>]*href="([^"]+)"', t)
        rec["website"] = html.unescape(w.group(1)) if w else None
        rec["closed_banner"] = bool(re.search(r'permanently closed|définitivement fermé|no longer in the (MICHELIN )?Guide|not part of the selection', t, re.I))
        rec["tels"] = sorted(set(re.findall(r'href="tel:([^"]+)"', t)))
    out[k] = rec
json.dump(out, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
from collections import Counter
print(len(out), Counter(str(r["status"]) for r in out.values()), Counter(r.get("star") for r in out.values()))
