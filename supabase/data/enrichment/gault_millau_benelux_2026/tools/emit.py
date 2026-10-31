import json,csv,collections,re,html,sys
rows=json.load(open('match_rows.json'))
RET='2026-10-31'
YEAR={'nl':2026,'be':2026,'lu':2027}
def score(r):
    hs=r.get('hero_score'); ld=r.get('ld_rating')
    v=float(hs.replace(',','.')) if hs and re.fullmatch(r'\d+(,5)?',hs) else None
    l=float(ld) if ld else None
    return v,l
def addr(o): return f"{o.get('street')}, {o.get('postcode')} {o.get('locality')}"
stag=[];log=[];notcat=[]
TIER={'MATCH_A':'A','MATCH_A2_WEBSITE_PHONE_ADDRESS_DIFFERS':'A2','MATCH_A3_CONTACT_AND_LOCATION':'A3','MATCH_B_ADDRESS_ONLY':'B'}
n=0
for r in sorted(rows,key=lambda x:(x['site'],x['url'])):
    li=r['list']
    if r['cls']=='FETCH_FAILED':
        log.append(dict(kind='FETCH_FAILED',gm_url=r['url'],detail='profile page not downloaded')); continue
    if r['cls']=='NOT_IN_CATALOGUE':
        notcat.append(dict(country=r.get('_cc'),gm_name=r.get('ld_name'),gm_address=addr(r),gm_score=r.get('hero_score'),gm_toques=r.get('hero_toques'),gm_url=r['url'],retrieval_date=RET)); continue
    n+=1
    v,l=score(r); c=r['cands'][0]; cat=c[0]
    toq=r.get('hero_toques')
    notes=[]
    decision='PROPOSE' if r['cls'] in TIER else 'HOLD'
    if v is None:
        decision='HOLD'; notes.append('no score published on profile (unscored entry) - not imported')
    elif l is not None and abs(v-l)>0.01:
        decision='HOLD'; notes.append(f'hero score {v} != structured rating {l}')
    if li.get('score') and v is not None and float(li['score'].replace(',','.'))!=v:
        decision='HOLD'; notes.append('listing score != profile score')
    if li.get('toque_svgs') is not None and toq is not None and li['toque_svgs']!=toq:
        decision='HOLD'; notes.append('listing toques != profile toques')
    if r['cls']=='REVIEW_NAME_CONFLICT': notes.append('NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto)')
    if r['cls'].startswith('REVIEW'):
        notes.append('candidates: '+'; '.join(f"{x[0]['restaurant_code']} {x[0]['name']} [{'+'.join(x[1])}]" for x in r['cands']))
        if r.get('other'): notes.append('code also matched by: '+', '.join(r['other']))
    prod=cat.get('gm_current') if r['cls']!='REVIEW_NAME_CONFLICT' else None
    change=''
    if prod:
        ps,pt,py=prod.split('|')
        if int(py)==YEAR[r['site']]:
            same=(v is not None and float(ps)==v and (pt=='' or toq is None or int(pt)==toq))
            change='UNCHANGED_IN_PROD' if same else f'DIFFERS_FROM_PROD ({ps}/{pt})'
            if same and decision=='PROPOSE': decision='ALREADY_IN_PROD'
            elif same: notes.append('production already holds the same value')
            elif not same: decision='HOLD'; notes.append(f'production has {ps}/20 {pt} toques for {py}; site now shows {v}/{toq} - correction candidate, not an insert')
    if r['cls'] in ('MATCH_A2_WEBSITE_PHONE_ADDRESS_DIFFERS','MATCH_A3_CONTACT_AND_LOCATION'): notes.append('catalogue address differs from G&M: "'+(cat['address'] or '')+'"')
    stag.append(dict(staging_id=f"gm26_{r['site']}_{n:04d}",decision=decision,match_tier=TIER.get(r['cls'],''),match_class=r['cls'],
        restaurant_code=cat['restaurant_code'],country_code=cat['country_code'],catalogue_name=cat['name'],catalogue_address=cat['address'],
        gm_name=html.unescape(r.get('ld_name') or ''),gm_address=addr(r),evidence='+'.join(c[1]),coord_distance_km=None if c[2] is None else round(float(c[2]),3),
        guide_year=YEAR[r['site']],score=v,toque_count=toq,recognition_type='scored' if v is not None else '',distinction_label='',
        gault_millau_url=r['url'],source_url=r['url'],retrieval_date=RET,production_current=prod or '',notes=' | '.join(notes)))
def w(fn,rs):
    if not rs: return
    with open(fn,'w',newline='') as f:
        wr=csv.DictWriter(f,fieldnames=list(rs[0].keys())); wr.writeheader(); wr.writerows(rs)
w('out/gault_millau_benelux_2026_staging.csv',stag); w('out/gault_millau_benelux_2026_not_in_catalogue.csv',notcat); w('out/fetch_log.csv',log)
print(collections.Counter((s['country_code'],s['decision'],s['match_tier']) for s in stag))
print('not in catalogue',collections.Counter(x['country'] for x in notcat),'fetch failed',len(log))
