import re,json,sys,html,os
def parse(path):
    h=open(path,encoding='utf-8',errors='replace').read()
    d={'file':os.path.basename(path)}
    rest=None
    for m in re.finditer(r'<script type="application/ld\+json">(.*?)</script>',h,re.S):
        try: j=json.loads(m.group(1))
        except Exception: continue
        if j.get('@type')=='Restaurant': rest=j
    if rest:
        a=rest.get('address',{})
        d.update(ld_name=html.unescape(rest.get('name','')),street=a.get('streetAddress'),postcode=a.get('postalCode'),
                 locality=a.get('addressLocality'),addr_country=a.get('addressCountry'),url=rest.get('url'),
                 ld_rating=(rest.get('aggregateRating') or {}).get('ratingValue'))
    # hero block: between <h1 and </h1>
    i=h.find('<h1'); j=h.find('</h1>',i); hero=h[i:j] if i>0 else ''
    s=re.search(r'score__value">([^<]*)<',hero)
    d['hero_score']=s.group(1).strip() if s else None
    tq=re.search(r'score__toques[^>]*>(.*?)</span>',hero,re.S)
    d['hero_toques']=tq.group(1).count('<svg') if tq else None
    d['hero_icons']=re.findall(r'cdn\.gault-?millau\.(?:nl|be)/[^"]*?\.svg',hero)
    d['hero_text']=re.sub(r'\s+',' ',re.sub(r'<[^>]+>',' ',re.sub(r'<svg.*?</svg>','',hero,flags=re.S))).strip()[:200]
    w=re.search(r'<a href="([^"]+)" target="_blank" rel="noreferrer" class="list-group-item[^"]*">\s*<i class="bi bi-globe">',h)
    d['website']=w.group(1) if w else None
    t=re.search(r'href="tel:([^"]+)"',h); d['phone']=t.group(1) if t else None
    d['canonical']=(re.search(r'<link rel="canonical" href="([^"]+)"',h) or [None,None])[1]
    d['title']=html.unescape((re.search(r'<title>(.*?)</title>',h,re.S) or [None,''])[1].strip())
    c=re.search(r'mapkit\.Coordinate\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)',h)
    d['lat'],d['lng']=(float(c.group(1)),float(c.group(2))) if c else (None,None)
    return d
if __name__=='__main__':
    for f in sys.argv[1:]: print(json.dumps(parse(f),ensure_ascii=False))
