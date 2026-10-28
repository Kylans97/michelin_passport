import sys, time, urllib.request, pathlib
out = pathlib.Path(sys.argv[1]); out.mkdir(exist_ok=True)
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
for p in range(1, 15):
    url = "https://guide.michelin.com/en/fr/restaurants/all-starred" + ("" if p == 1 else f"/page/{p}")
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "en"})
    (out / f"list_{p:02d}.html").write_bytes(urllib.request.urlopen(req, timeout=30).read())
    time.sleep(1)
print("ok")
