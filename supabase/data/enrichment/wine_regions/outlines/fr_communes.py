import csv, json, sys
SRC = 'https://www.data.gouv.fr/datasets/aires-geographiques-des-aoc-aop (INAO, 2025-10-09-COMAGRI-Communes_Aires_AO.csv)'
REGIONS = {
  'wr_0001': ['Bourgogne', 'Chablis', 'Meursault', 'Puligny-Montrachet', 'Mâcon Villages', 'Volnay', 'Pommard', 'Gevrey-Chambertin', 'Nuits-Saint-Georges'],
  'wr_0002': ['Bordeaux', 'Médoc', 'Haut-Médoc', 'Pauillac', 'Margaux', 'Saint-Emilion', 'Pomerol', 'Pessac-Léognan', 'Graves', 'Sauternes'],
  'wr_0003': ['Champagne'],
  'wr_0004': ['Côtes du Rhône', 'Châteauneuf-du-Pape', 'Côte Rôtie', 'Hermitage', 'Crozes-Hermitage', 'Gigondas'],
  'wr_0005': ['Crémant de Loire', 'Sancerre', 'Pouilly-Fumé ou Blanc Fumé de Pouilly et Pouilly-sur-Loire', 'Vouvray', 'Chinon', 'Muscadet'],
}
lau = {x['GISCO_ID']: x['LAU_NAME'] for x in json.load(open(sys.argv[2])) if x['CNTR_CODE'] == 'FR'}
rows = list(csv.reader(open(sys.argv[1], encoding='utf-8'), delimiter=';'))[1:]
# INSEE's official event history: a commune since merged into a commune
# nouvelle resolves to the commune that absorbed it (the whole of which
# is then drawn - marked partial).
succ = {}
for r in csv.DictReader(open(sys.argv[3], encoding='utf-8')):
    if r['TYPECOM_AP'] == 'COM' and r['COM_AP'] != r['COM_AV'] and r['MOD'] in ('31', '32', '33', '34', '35'):
        if r['DATE_EFF'] >= succ.get(r['COM_AV'], ('', ''))[1]:
            succ[r['COM_AV']] = (r['COM_AP'], r['DATE_EFF'], r['LIBELLE_AP'])
def resolve(ci):
    path = []
    while 'FR_' + ci not in lau and ci in succ and len(path) < 5:
        ci, _, name = succ[ci]
        path.append(f'{ci} {name}')
    return ci, path
for code, aires in REGIONS.items():
    seen, held = {}, []
    for aire in aires:
        n = 0
        for ci, dep, com, art, a, ida in rows:
            if a != aire: continue
            n += 1
            code2, path = resolve(ci)
            gid = 'FR_' + code2
            if gid in lau:
                part = f'merged into {path[-1]} (INSEE); the whole commune is drawn' if path else ''
                prev = seen.get(gid)
                if prev is None or (prev[4] and not part):
                    seen[gid] = (com if not path else lau[gid], lau[gid], dep, aire, part)
            else:
                held.append((ci, com, dep, aire))
        assert n > 0, aire
    with open(f'communes/{code}.csv', 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['region_code', 'gisco_id', 'official_name', 'lau_name', 'province', 'partial', 'source_url'])
        for gid, (com, ln, dep, aire, part) in sorted(seen.items()):
            w.writerow([code, gid, com, ln, dep, part, SRC])
    print(code, 'matched', len(seen), 'of which via merger', sum(1 for v in seen.values() if v[4]), 'held', len(held))
    for h in held: print('   held', h)
