import re,sys,json
def parse(h):
    out=[]
    for blk in h.split('<div class="place position-relative">')[1:]:
        m=re.search(r'href="([^"?]+)\?ref=link" class="stretched-link"',blk)
        n=re.search(r'<h3[^>]*>(.*?)</h3>',blk,re.S)
        s=re.search(r'score__value">([^<]*)<',blk)
        tq=re.search(r'score__toques[^>]*>(.*?)</span>',blk,re.S)
        out.append(dict(url=m.group(1) if m else None,name=re.sub(r'\s+',' ',n.group(1)).strip() if n else None,
          score=s.group(1).strip() if s else None,toque_svgs=tq.group(1).count('<svg') if tq else None,
          other=re.findall(r'class="(badge[^"]*|label[^"]*)"',blk)[:5]))
    return out
if __name__=='__main__':
    for f in sys.argv[1:]:
        for r in parse(open(f).read()): print(json.dumps(r,ensure_ascii=False))
