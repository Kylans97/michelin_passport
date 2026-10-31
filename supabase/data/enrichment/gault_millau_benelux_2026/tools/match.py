"""Match G&M profiles to live catalogue rows on address/website/coordinates,
never on name. Output: staging rows + QA log. Name is carried only for the
human reviewer's eye."""
import csv,json,re,math,sys,os,glob,collections,unicodedata
sys.path.insert(0,os.path.dirname(__file__))
from parse_prof import parse

def norm_domain(u):
    if not u: return None
    u=u.strip().lower(); u=re.sub(r'^https?://','',u); u=u.split('/')[0].split('?')[0]
    u=re.sub(r'^www\d?\.','',u); return u or None
def strip_acc(s): return ''.join(c for c in unicodedata.normalize('NFKD',s) if not unicodedata.combining(c))
def pc(cc,s):
    if not s: return None
    s=s.upper()
    if cc=='NL':
        m=re.search(r'\b(\d{4})\s?([A-Z]{2})\b',s); return m.group(1)+m.group(2) if m else None
    m=re.search(r'\b(?:L-?)?(\d{4})\b',s); return m.group(1) if m else None
def street_nr(s):
    """street part and house number of the first comma segment"""
    if not s: return (None,None)
    seg=s.split(',')[0]; seg=strip_acc(seg).lower()
    m=re.search(r'(\d+)\s*([a-z])?\b',seg)
    nr=m.group(1) if m else None
    st=re.sub(r'[^a-z]','',re.sub(r'\d.*$','',seg) if m and m.start()>0 else re.sub(r'^\d+\s*[a-z]?\b','',seg))
    st=st.replace('straat','str').replace('steenweg','stwg').replace('laan','ln')
    return (st or None,nr)
def norm_phone(p):
    if not p: return None
    d=re.sub(r'\D','',p); return d[-9:] if len(d)>=9 else None
def km(a,b,c,d):
    if None in (a,b,c,d): return None
    R=6371; p1,p2=math.radians(a),math.radians(c); dp=p2-p1; dl=math.radians(d-b)
    x=math.sin(dp/2)**2+math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2*R*math.asin(math.sqrt(x))
def fnum(x):
    try: return float(x)
    except: return None

live=list(csv.DictReader(open('benelux_live.csv')))
for r in live:
    for k,v in list(r.items()):
        if v in ('NULL',''): r[k]=None
for r in live:
    r['_dom']=norm_domain(r['website_url']); r['_pc']=pc(r['country_code'],r['address'])
    r['_st'],r['_nr']=street_nr(r['address']); r['_ph']=norm_phone(r['phone']); r['_lat']=fnum(r['lat']); r['_lng']=fnum(r['lng'])

gm=[]
lists={c:{json.loads(l)['url']:json.loads(l) for l in open(f'gm_list_{c}.jsonl')} for c in ('nl','be','lu')}
for c in ('nl','be','lu'):
    for u,li in lists[c].items():
        f=f'prof_{c}/'+u.rsplit('/',1)[1]+'.html'
        if not os.path.exists(f) or os.path.getsize(f)==0:
            gm.append(dict(site=c,url=u,list=li,missing=True)); continue
        d=parse(f); d.update(site=c,url=u,list=li,missing=False)
        d['_cc']=(d.get('addr_country') or '').upper()
        d['_dom']=norm_domain(d.get('website')); d['_pc']=pc(d['_cc'],(d.get('postcode') or '')+' ')
        d['_st'],d['_nr']=street_nr(d.get('street')); d['_ph']=norm_phone(d.get('phone'))
        gm.append(d)

def evidence(g,r):
    ev=[]
    if g['_cc']!=r['country_code']: return None
    if g['_dom'] and r['_dom'] and g['_dom']==r['_dom']: ev.append('website')
    if g['_ph'] and r['_ph'] and g['_ph']==r['_ph']: ev.append('phone')
    if g['_pc'] and r['_pc'] and g['_pc']==r['_pc'] and g['_nr'] and g['_nr']==r['_nr']:
        if r['country_code']=='NL' or (g['_st'] and r['_st'] and (g['_st'][:6]==r['_st'][:6])):
            ev.append('address')
    d=km(g.get('lat'),g.get('lng'),r['_lat'],r['_lng'])
    if d is not None and d<=0.15: ev.append('coords<=150m')
    return ev,d

STOP={'restaurant','restaurants','de','het','the','le','la','les','l','t','by','at','and','en','bij','van','den','der','du','des','d','chez','resto','brasserie','bistro','hotel'}
def toks(n):
    n=strip_acc(n or '').lower().replace('&amp;','&')
    return {w for w in re.split(r"[^a-z0-9]+",n) if w and w not in STOP and (len(w)>2 or w.isdigit())}
def name_conflict(a,b):
    # a VETO only: names never create a match, they can only stop one
    ta,tb=toks(a),toks(b)
    ca,cb=re.sub(r'[^a-z0-9]','',strip_acc(a or '').lower()),re.sub(r'[^a-z0-9]','',strip_acc(b or '').lower())
    if ta & tb: return False
    if ca and cb and (ca in cb or cb in ca): return False
    return True
pairs=collections.defaultdict(list)
vetoed=collections.defaultdict(list)
for g in gm:
    if g.get('missing'): continue
    for r in live:
        e=evidence(g,r)
        if not e: continue
        ev,d=e
        # coordinates alone never make a candidate (proved unsafe: Vermeer->MOS,
        # CUE->Spectrum, Lastage->Zoldering all sit within 150 m of another venue)
        if 'website' in ev or 'address' in ev or 'phone' in ev:
            # names never make a match; a name with nothing in common removes
            # a candidate (sibling bistros share website/phone/address)
            if name_conflict(g.get('ld_name'),r['name']): vetoed[g['url']].append((r,ev,d))
            else: pairs[g['url']].append((r,ev,d))
by_code=collections.defaultdict(list)
for u,lst in pairs.items():
    for r,ev,d in lst: by_code[r['restaurant_code']].append(u)

rows=[]
for g in gm:
    if g.get('missing'):
        rows.append(dict(g,cls='FETCH_FAILED')); continue
    lst=pairs.get(g['url'],[])
    strong=[x for x in lst if len(x[1])>=2]
    rec=dict(g)
    if not lst and vetoed.get(g['url']):
        rec['cls']='REVIEW_NAME_CONFLICT'; rec['cands']=vetoed[g['url']]; rows.append(rec); continue
    if not lst: rec['cls']='NOT_IN_CATALOGUE'; rows.append(rec); continue
    cands=strong if strong else lst
    if len(cands)>1:
        rec['cls']='REVIEW_MULTIPLE_CANDIDATES'; rec['cands']=cands
    else:
        r,ev,d=cands[0]
        other=[u for u in by_code[r['restaurant_code']] if u!=g['url']]
        rec['cands']=cands
        if other: rec['cls']='REVIEW_CODE_CLAIMED_BY_OTHER_GM'; rec['other']=other
        elif 'address' in ev and ('website' in ev or 'phone' in ev): rec['cls']='MATCH_A'
        elif 'address' in ev and r['_dom'] and g['_dom'] and r['_dom']!=g['_dom']: rec['cls']='REVIEW_WEBSITE_CONFLICT'
        elif 'address' in ev and r['_ph'] and g['_ph'] and r['_ph']!=g['_ph']: rec['cls']='REVIEW_PHONE_CONFLICT'
        elif 'address' in ev: rec['cls']='MATCH_B_ADDRESS_ONLY'
        elif 'website' in ev and 'phone' in ev: rec['cls']='MATCH_A2_WEBSITE_PHONE_ADDRESS_DIFFERS'
        elif ('website' in ev or 'phone' in ev) and 'coords<=150m' in ev: rec['cls']='MATCH_A3_CONTACT_AND_LOCATION'
        else: rec['cls']='REVIEW_SINGLE_SIGNAL_'+ev[0].upper()
    rows.append(rec)
json.dump([{k:v for k,v in r.items()} for r in rows],open('match_rows.json','w'),default=str,ensure_ascii=False)
print(collections.Counter((r['site'],r['cls']) for r in rows))
