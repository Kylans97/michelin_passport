# Wine region outlines

How each region's shape on the globe was made (migration
`20261101590000_add_wine_region_outlines.sql`, product owner 2026-11-20:
"Build the outlines from each region's official list of communes, merged
and simplified, with the source stored per region").

**Method.** A region is the union of the municipalities its official
specification lists, on the EU's official municipality boundaries
(Eurostat GISCO LAU 2024, 1:1M, © EuroGeographics), with gaps and notches
under ~1.5 km closed, simplified to ~1 km and parts under 4 km² dropped.
Nothing is traced by hand. Matching is by official code wherever the
document gives one; where it gives only names, by name **within the right
province only**, each name to exactly one unit, every judgement call
written down in that region's notes.

**Rule for part-municipalities.** A municipality only partly in the zone
is drawn whole and marked `partial` with the document's wording — the
outline then overstates the region there. One the document includes only
as a single enclave, village or a few named estates is **left out** instead
(`LEFT_OUT` in `import_commune_lists.py`).

**Rebuild:** `fr_communes.py` (France) and `import_commune_lists.py`
(elsewhere) write `communes/`; `scripts/build_wine_region_outlines.py`
writes `outlines.json` and `wine_region_outlines.sql`.

| Region | Defined as | Official source | Units | Partial | Left out |
|---|---|---|---|---|---|
| wr_0001 Burgundy | AOC Bourgogne + the region's listed names (Chablis, Meursault, Puligny-Montrachet, Mâcon Villages, Volnay, Pommard, Gevrey-Chambertin, Nuits-Saint-Georges) | INAO, *Aires géographiques des AOC/AOP* (data.gouv.fr, 2025-10-09) | 310 | 1 | — |
| wr_0002 Bordeaux | AOC Bordeaux + Médoc, Haut-Médoc, Pauillac, Margaux, Saint-Emilion, Pomerol, Pessac-Léognan, Graves, Sauternes | INAO, same | 494 | — | — |
| wr_0003 Champagne | AOC Champagne | INAO, same | 618 | 1 | — |
| wr_0004 Rhône Valley | AOC Côtes du Rhône + Châteauneuf-du-Pape, Côte Rôtie, Hermitage, Crozes-Hermitage, Gigondas | INAO, same | 172 | — | — |
| wr_0005 Loire Valley | AOC Crémant de Loire + Sancerre, Pouilly-Fumé, Vouvray, Chinon, Muscadet | INAO, same | 342 | 7 | — |
| wr_0006 Rioja | DOCa Rioja, zona de producción | MAPA, pliego de condiciones (last modified 7 Oct 2026) | 140 | 2 | Miranda de Ebro (El Ternero enclave only) |
| wr_0007 Ribera del Duero | DO Ribera del Duero, zona de producción | MAPA, pliego PDO-ES-A0626 (rev. 5, 2023-07-31) | 81 | 13 | Burgo de Osma (one village only) |
| wr_0008 Douro | Região Demarcada do Douro (DO Douro = Porto area) | EU technical file PDO-PT-A1539, hosted by IVDP | 131 | 9 | Várzea de Abrunhais, Frechas, Carvalhais, Avantos e Romeu (named estates only) |
| wr_0009 Mosel | Anbaugebiet / g.U. Mosel | RLP product specification PDO-DE-A1270 (2011-12-19) | 132 | 1 | — |
| wr_0010 Piedmont | DOC Piemonte Art. 3 (Barolo, Barbaresco, Barbera d'Alba and Asti/Moscato d'Asti all lie wholly inside it) | MASAF disciplinari (DOC Piemonte, DM 08.08.2019) | 681 | 1 | — (2 names held back, below) |
| wr_0012 Achterhoek-Winterswijk | "de gehele gemeente Winterswijk" | RVO productdossier BOB (Jan 2022) | 1 | — | — |
| wr_0014 Mergelland | 8 gemeenten + former Nuth (CBS wijken 01-04 of Beekdaelen), "voor zover" on loess | RVO productdossier BOB (2016) | 12 | 12 | — |
| wr_0015 Oolde | the 1832 neighbourhood Oolde, 658 ha | RVO productdossier BOB (Dec 2016); CBS buurt BU02620206 | 1 | 1 (buurt ~1.8x the area) | — |
| wr_0017 Schouwen-Duiveland | "het eiland Schouwen-Duiveland" | RVO productdossier BOB (Dec 2021) | 1 | — | — |
| wr_0018 Twente | eastern Overijssel, 150,300 ha (the dossier map's 14 gemeenten, 150,377 ha) | RVO productdossier BOB (Apr 2022) | 14 | — | — |
| wr_0019 Vijlen | a mapped area in the village of Vijlen, 419 ha | RVO productdossier BOB; BAG woonplaats Vijlen (1431) | 1 | 1 (woonplaats ~2.7x) | — |
| wr_0011 Tuscany | IGT Toscana: the 10 provinces of Regione Toscana | MASAF disciplinari (IGT Toscano/Toscana, 12.07.2019) | 273 | — | — |

**The Americas** (`import_americas.py`; official texts and boundary
datasets in each region's notes):

| Region | Defined as | Official source | Boundary data |
|---|---|---|---|
| wr_0021 Napa Valley | AVA | 27 CFR 9.23 | TTB AVA polygon (AVA Map Explorer, CC0) |
| wr_0022 Sonoma County | the county (a legal US appellation, 27 CFR 4.25(a)(1)(iv)); no AVA or union of AVAs matches it | 27 CFR 4.25 | US Census county, shoreline-clipped |
| wr_0023 Willamette Valley | AVA (parent; 11 sub-AVAs) | 27 CFR 9.90 | TTB |
| wr_0024 Paso Robles | AVA (parent; 11 sub-AVAs cover ~59%) | 27 CFR 9.84 | TTB |
| wr_0025 Finger Lakes | AVA | 27 CFR 9.34 | TTB |
| wr_0026 Mendoza | IG at province level: all 18 departamentos | INV Res. C.32/2002 | IGN departamentos |
| wr_0027 Valle de Uco | IG: San Carlos, Tunuyán, Tupungato (wording of INV's register, not the resolution) | INV Res. C.37/2002; register 2024 | IGN |
| wr_0028 Cafayate | IG Cafayate = Valle de Cafayate: departamento Cafayate | INV Res. C.32/2002, C.15/2004 | IGN |
| wr_0029 Valle del Maipo | all provinces of the Metropolitan Region (52 comunas) | Decreto 464, art. 1.4 | BCN comunas |
| wr_0030 Valle de Colchagua | provinces Colchagua and Cardenal Caro (16 comunas) | Decreto 464 | BCN |
| wr_0031 Valle de Casablanca | comuna Casablanca | Decreto 464 | BCN |

Held back: IG Valles Calchaquíes (no official text gives it a boundary).
TTB's outlines are informational; the written CFR description prevails.
Source polygons are stored simplified to ~100 m.

**Not drawn** (published with a point only; the municipalities the
dossier names are kept in `communes_reference/` for the record):
wr_0013 Maasvallei Limburg (a 155 km² strip on both Maas banks fixed by
roads and canals; its 11 municipalities are 5-7x that), wr_0016
Rivierenland (5 km either side of the river centrelines; the 13 named
municipalities are only part of it), wr_0020 Voerendaalse Bergen (six
named slopes, ~900 ha; Voerendaal is 3.5x). See `import_nl_regions.py`.

Dutch units finer than a municipality come from PDOK open data (BAG
woonplaatsen, Kadaster, CC0; CBS Wijk- en Buurtkaart 2024, CC BY 4.0) in
`geometry/nl_finer_units.geojson`. Zones under ~40 km across get
proportionally finer smoothing and tolerance.

France: merged communes resolve through INSEE's official event history
(`v_mvt_commune_2026.csv`) to the commune that absorbed them, drawn whole
and marked partial.

**Known limits — read before relying on an edge:**
- The Mosel list is the 2011 specification; a 2021 DLR presentation counts
  128 municipalities against 132 here. A later amendment is not in it. The
  text covers only each Gemeinde's vineyard area, so the cities (Koblenz,
  Trier, Wittlich, Konz, Saarburg) are drawn whole.
- The Douro list is from the EU technical file (saved 2011), not the
  decree itself (DL 173/2009, republished as DL 97/2020), which could not
  be read. Pre-2013 freguesias map to their 2013 unions; several unions
  include a place the document does not.
- Ribera del Duero is defined village by village; 13 municipalities may
  be only partly in, not checked against INE's village register.
- Piedmont: two names in the disciplinare match no comune and are held
  back, not guessed: "San Giorgio di Susa" (Torino; probably San Giorio
  di Susa) and "Landonia" (Novara; probably Landiona). Lessona and Busca
  are listed whole but have since absorbed unlisted comuni (Crosa,
  Valmala), drawn with them.
- Rioja's table was read from the PDF's text; checked against the
  document's own totals, not against an image of the page.

Per-region notes with every judgement call: `communes/wr_NNNN_notes.md`
(Spain, Portugal, Germany, Italy, the Netherlands).
