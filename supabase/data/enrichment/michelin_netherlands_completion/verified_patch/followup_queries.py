import json, time, urllib.parse, urllib.request

UA = "ChasingStarsMichelinPassport-NLPatch/1.0 (research; contact: kylan_97@live.nl)"
def q(query):
    params = {"q": query, "format": "json", "limit": 3, "addressdetails": 1, "countrycodes": "nl"}
    url = f"https://nominatim.openstreetmap.org/search?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    time.sleep(1.1)
    return data

queries = [
    "Huize Lindenoord, Wolvega, Netherlands",
    "Van Harenstraat, Wolvega, Netherlands",
    "Strandhotel, Cadzand-Bad, Netherlands",
    "Pure C, Boulevard de Wielingen, Cadzand-Bad, Netherlands",
    "Boulevard de Wielingen 49, Cadzand-Bad, Netherlands",
    "AIRrepublic Cadzand Marina, Netherlands",
]
out = {}
for query in queries:
    r = q(query)
    out[query] = r
    top = r[0] if r else None
    print(query, "->", (top.get("display_name"), top.get("lat"), top.get("lon"), top.get("type"), top.get("class")) if top else "NO RESULT")

json.dump(out, open("geocode_followup_results.json", "w"), indent=2, ensure_ascii=False)
