import sys, json, time, hashlib, urllib.request, urllib.error, pathlib
q = json.load(open(sys.argv[1])); out = pathlib.Path(sys.argv[2]); out.mkdir(exist_ok=True)
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
log = open(out / "_log.jsonl", "a")
for k in q:
    f = out / (hashlib.md5(k.encode()).hexdigest() + ".html")
    if f.exists(): continue
    url = "https://guide.michelin.com/en/" + k
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "en"}), timeout=30)
        f.write_bytes(r.read()); log.write(json.dumps({"key": k, "status": r.status, "final": r.geturl(), "file": f.name}) + "\n")
    except urllib.error.HTTPError as e:
        log.write(json.dumps({"key": k, "status": e.code, "final": None, "file": None}) + "\n")
    except Exception as e:
        log.write(json.dumps({"key": k, "status": "ERR " + str(e)[:80], "final": None, "file": None}) + "\n")
    log.flush(); time.sleep(2.0)
print("done")
