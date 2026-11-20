# Morocco and Ethiopia wine regions — research report (2026-11-20)

All files are under this folder. Region detail and per-claim sources are in each `*_notes.md`. Downloads are in `ma/raw/` and `et/raw/`; extracted texts in `ma/work/`. Nothing was written to git or the database.

## Headline
- **Morocco**: 14 AOGs (1977) and 5 AOCs (1998-2022), all in ONSSA-published arrêtés. **No appellation is defined by administrative units you can map.** The AOGs are described by rivers, roads, mountains and 1977 locality names. The AOCs list "parts of" communes, bounded by roads and rivers on cadastral plans that are not published. No official commune boundary layer is openly available (HCP's COD-AB on HDX stops at provinces). GADM communes, the last resort, failed a position check. So **every Moroccan region is a point**, and `ma/ma_units.geojson` is deliberately an empty FeatureCollection.
- **Ethiopia**: **two grape-wine producers are documented, not one, and neither is ~1 h from Addis.** Castel Winery's vineyard is at Ziway/Batu, ~160 km and ~2.5 h south. Awash Wine's vineyard is at Merti (Jeju), Arsi, 115-180 km east (sources conflict). A third name, "Kana", appears in one source only (held back). There is no wine appellation. Two point regions are given.

## Part A — Morocco

### Official texts (all downloaded from ONSSA, the regulator's text library: https://www.onssa.gov.ma/reglementation/reglementation-sectorielle/produits-alimentaires/boissons-alcoolisees/)
| Text | Content |
|---|---|
| Décret 2-75-321, 12 Aug 1977 | Wine regulation; creates the Commission nationale viti-vinicole |
| Arrêté 869-75, 15 Aug 1977 (BO 3388 p.1091), consolidated | **Art. 1 defines the 14 AOGs**; Art. 2 grapes and rules (completed by 1956-98, BO 4662); Art. 3 AOCs to be delimited inside AOGs; Art. 6 labelling |
| Arrêté 1955-98, 8 Oct 1998 (BO 4662 p.102) | General AOC conditions; each AOC arrêté must list "communes ou parties de communes" |
| Arrêté 1957-98, 8 Oct 1998 (BO 4662 p.104) | AOC **Les Coteaux de l'Atlas** (inside AOG Béni M'Tir; parts of Sidi-Slimane, Mjat, Boufekrane) |
| Arrêté 352-09, 12 Feb 2009 (BO 5732 p.745) | AOC **Crémant de l'Atlas** (sparkling, same area as Coteaux de l'Atlas) |
| Arrêté 250-14, 4 Feb 2014 (BO 6248 p.2986) | AOC **Les Côtes de Rommani** (inside AOG Zaër; bounded by Oued El Machra and roads P4303/P4307; no communes listed) |
| Arrêté 3477-22, 16 Dec 2022 (BO 7166 p.296) | AOC **Côtes de Sebaa Ayoun** (inside AOG Béni M'Tir; part of Sebaa Ayoun commune) |
| Arrêté 3478-22, 16 Dec 2022 (BO 7166 p.297) | AOC **Hauts Plateaux de Meknès** (inside AOG Guerrouane; parts of Aït Yazem, Mjat, Boufekrane, El Hajeb, Ifrane, Azrou) |
| Arrêté 815-04, 14 Oct 2004 | Rules for the "château" mention (not an area) |

**AOGs (869-75 Art. 1)**: Berkane, Angad, Saïs, Beni-Sadden, Zerhoun, Guerrouane, Beni-M'Tir, Rharb, Chellah, Zaër, Zemmour, Zenata, Sahel, Doukkala. Doukkala is rosé only, from "gros rosé des Doukkala" clones. Corroborated by WIPO Lex (MA008/MA009/MA011) and French Wikipedia "Viticulture au Maroc".
**AOCs**: the five above. Secondary sources say "1 AOC, Coteaux de l'Atlas 1er Cru, 2001". That is outdated and misdated against the BO.
Caveat: the ONSSA list (read 2026-11-20) has no text after BO 7166 (Feb 2023). A search found no later wine AOC. A Bulletin Officiel search was not done.

### Recommended (shown as points; coordinates in `ma/ma_points.csv`, all GeoNames, MA dump 2026-11-20)
| Region | Why | Point (GeoNames) |
|---|---|---|
| Guerrouane (AOG) | Meknès/Fès core; current labels (Zouina, Les Deux Domaines) in Jancis Robinson; Wine-Searcher; OCW via Wikipedia | Ait Yaazem 8542600 (33.73148, -5.5791) |
| Beni M'Tir (AOG) | Meknès core; Celliers de Meknès (~30m bottles/yr, JR); contains 3 AOCs | Sebaa Aioun 2537654 (33.90313, -5.37814) |
| Les Coteaux de l'Atlas (AOC) | First AOC; Château Roslane "Premier Cru" (JR, Wine-Searcher) | Sidi Sliman Mol Kifa 6546145 (33.83781, -5.44462) |
| Zenata (AOG) | Ouled Thaleb Syrah (Wine Spectator 2009, Decanter) | Benslimane 2555519 (33.61601, -7.12153) |
Each point is tied to the official text: a commune a later arrêté places inside the AOG, or a locality the 1977 text names. None marks a vineyard.

Not recommended (no current reference evidence found): Berkane, Angad, Saïs, Beni-Sadden, Zerhoun, Rharb, Chellah, Zaër, Zemmour, Sahel, Doukkala; and the AOCs Crémant de l'Atlas (a sparkling style of Coteaux de l'Atlas), Côtes de Rommani, Côtes de Sebaa Ayoun. Hauts Plateaux de Meknès shows up as a label in Jancis Robinson's database (Zouina) and could be added later; one source.

### Boundary data reviewed
- HDX COD-AB "cod-ab-mar" (source HCP, CC BY-IGO, reviewed 19 Dec 2024): admin 1-2 only (10 regions, 69 provinces), no communes. Saved in `ma/raw/hdx_cod_ab/`.
- geoBoundaries MAR: ADM0-2 only, repackaging OpenStreetMap (ODbL). Not useful.
- GADM 4.1 level 4 (`ma/raw/gadm41/`), the last resort, was rejected. GeoNames commune and town points land in the wrong GADM commune. GADM's El Hajeb, Sebaa Aiyoun, Benslimane and Boufakrane polygons sit ~3-5 km north of their towns. Candidate kept in `ma/work/HELD_BACK_gadm_coteaux_communes.geojson`.
- Region CSVs (`ma/<slug>.csv`) are header-only, since there are no units.

## Part B — Ethiopia
| Producer | Vineyard | From Addis | Grapes | Sources |
|---|---|---|---|---|
| Castel Winery (BGI Ethiopia / Castel Group), operating 2025 | Near Ziway = Batu, East Shewa, Oromia, Central Rift Valley; 120-162 ha; ~1,600 m | ~160-163 km road; Wikivoyage 2 h 30 via Modjo and the expressways; 121 km straight line | Syrah, Cabernet Sauvignon, Merlot, Chardonnay | Ethiopian Embassy Belgium 2015; How We Made It In Africa 2016; Wikivoyage; Wikipedia BGI; BGI on X 2025 |
| Awash Wine S.C. (Addis wineries at Lideta and Mekanisa), operating 2025 | "Merti Jeju" farm, Merti woreda, Arsi zone, Oromia; 517 ha, 225 ha vines | 180 km east (Reporter 2019) vs 115 km south-east (Drinks Business 2014); 131 km straight line to Abomsa; drive time unsourced | not sourced | The Reporter 2019; awashwines.com; Drinks Business 2014 (snippet) |
- **"Only one winery, ~1 h from Addis" does not hold.** Two producers exist. Awash's wineries are in Addis itself, but its vineyard is 115-180 km away, and Castel's is ~2.5 h by road.
- No wine appellation or wine GI. Ethiopia's first GI framework was only finalised in April 2026 (Capital Ethiopia).
- Points (`et/et_points.csv`): Ziway, GeoNames 325579 (7.93333, 38.71667), for Castel's vineyard area. Ābomsa, GeoNames 345703 (8.58333, 39.85), the seat of Merti woreda, for Awash's farm. Recommend Ziway as the main Ethiopian point, with Merti as optional.

## Part C — Style (summary; detail and sources in notes)
Mapping for structure: low = 1-2, medium = 3, high = 4-5.
- **Guerrouane / Beni M'Tir**: Meknès plateau at ~600-700 m below the Middle Atlas. Altitude moderates a hot, dry climate. Reds, rosés and Morocco's pale vin gris (Jancis Robinson; Wine-Searcher). Region-specific grape order and red structure: held back.
- **Coteaux de l'Atlas**: grapes from the official text: Cabernet Sauvignon, Merlot, Syrah, Tempranillo ≥ 2/3 of reds; then Carignan, Cinsault, Grenache; whites Chardonnay, Sauvignon blanc (≥ 50%), Vermentino. Structure: held back.
- **Zenata**: coastal hills between Casablanca and Rabat, Atlantic-cooled nights (trade sources). Syrah-led (Wine Spectator; Decanter). Body 4 (Decanter "full-bodied"; one explicit source). Acidity and tannin held back.
- **Ethiopia, Rift Valley**: ~1,600 m, warm all year, sandy soils, two harvests possible (Embassy 2015). Syrah, Cabernet Sauvignon, Merlot, Chardonnay. Structure and pairing are producer-only: held back.
- **Labels (Morocco, 869-75 Art. 6)**: the appellation name with "appellation d'origine garantie" or "appellation d'origine contrôlée" in very apparent characters under it. Coteau, Côte, Château, Domaine and similar words are allowed only on AOG/AOC wine from an estate that has existed for at least 5 years. "1er cru" is allowed only for an AOC terroir classified by the national commission (the basis of "Coteaux de l'Atlas Premier Cru").
- Pairings: none from two independent sources for any region: held back.

## Held back
1. Morocco: every commune or province outline (no unit-based definitions; GADM failed its position check).
2. Zenata locality-to-commune mapping (name matching across 1977 to 2015).
3. Coteaux de l'Atlas Art. 2: the second group reads "minimum 1/3", likely meant as a maximum. Reported as printed.
4. Meknès soils (clay-limestone: trade sources only); Zenata soils (sources conflict).
5. Region-specific grape order for Guerrouane and Beni M'Tir; red structure everywhere except Zenata body; all pairings.
6. Syrocco origin conflict (Zenata label vs a "Meknès hillsides" note).
7. Ethiopia: "Kana" winery (Addis Fortune 2019 only; no location). Awash grape varieties and altitude. Awash vineyard distance (115 vs 180 km) and drive time. Castel's 42 ha of Sangiovese (attribution unclear). Two harvests a year (one independent source).
8. Sources not read directly (403 or blocked): Wine-Searcher, Jancis Robinson, Decanter feature, Drinks Business 2014, the Oxford Companion (read via Wikipedia's citation), SAWIS VinIntell 2016 (TLS error; not retried insecurely). Where they are cited, it is from search-result snippets, and the notes say so.
