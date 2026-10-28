"""Does MICHELIN's phone number for each Monaco restaurant also appear on the
restaurant's own website (homepage + a few contact-like pages)?
Input: parsed.json from parse_details.py. Prints one line per restaurant."""
import sys, json, re, html, urllib.request, urllib.parse, time

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
KW = re.compile(r'contact|reserv|réserv|infos|acces|accès|book|booking|practical|pratique|restaurant', re.I)


def get(url):
    r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "fr,en"}), timeout=20)
    return r.read(3_000_000).decode(r.headers.get_content_charset() or "utf-8", errors="replace"), r.geturl()


def digits(s):
    return re.sub(r"\D", "", s)


for k, r in json.load(open(sys.argv[1])).items():
    if r.get("status") != 200:
        continue
    want = digits(r["phone"] or "")[-8:]  # the 8-digit Monaco subscriber number
    found, pages, err = False, [], None
    try:
        h, final = get(r["website"])
        pages.append(final)
        host = urllib.parse.urlparse(final).netloc
        cands = []
        for m in re.finditer(r'href="([^"#]+)"', h):
            u = urllib.parse.urljoin(final, html.unescape(m.group(1)))
            if urllib.parse.urlparse(u).netloc == host and KW.search(urllib.parse.urlparse(u).path) and u not in cands:
                cands.append(u)
        texts = [h]
        for u in cands[:4]:
            try:
                time.sleep(1)
                texts.append(get(u)[0]); pages.append(u)
            except Exception:
                pass
        for t in texts:
            if want and want in digits(html.unescape(t)):
                found = True
                break
    except Exception as e:
        err = (type(e).__name__ + ": " + str(e))[:90]
    print(("CONFIRMED" if found else "not found"), "|", r["name"], "|", r["phone"], "|", r["website"], "|", err or f"{len(pages)} pages")
    time.sleep(2)
