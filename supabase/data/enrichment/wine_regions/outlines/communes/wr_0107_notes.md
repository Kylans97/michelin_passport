# Alsace: communes and sourcing

**Defining AOC area(s):** AOC Alsace (Vin d'Alsace).

The INAO file has no row named plain "Alsace"; it lists the area under "Alsace suivi d'un nom de lieu-dit" (119 rows). The cahier des charges (BO 15 Jan 2026, IV 1° a, https://info.agriculture.gouv.fr/boagri/document_administratif-6fe90f2b-ac49-4fec-a13f-309ce19ef3e7/telechargement) gives one area for AOC Alsace "suivie ou non du nom d'un lieu-dit", so that row set is AOC Alsace's area. Checked name by name against the cahier list (53 Haut-Rhin + 64 Bas-Rhin, COG 2025): all 117 match (Gimbrett is a commune associée of Berstett; Boersch/Bœrsch and Voegtlinshoffen/Vœgtlinshoffen are spelling only). Crémant d'Alsace (129 rows) adds 10 communes such as Strasbourg, Ostheim and Seebach that are not in the AOC Alsace area; not drawn. The 51 grand cru areas lie inside it.

- Source: INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, file 2025-10-09-COMAGRI-Communes_Aires_AO.csv), merged communes resolved through INSEE v_mvt_commune_2026, mapped to GISCO LAU 2024 ids FR_<INSEE>. Same logic as scratchpad/fr_communes.py (script: scripts/fr_classics_communes.py).
- INAO rows per area: {'Alsace suivi d’un nom de lieu-dit': 119}
- LAU rows written: 117; unresolved INSEE codes: 0
- Partial (drawn whole): FR_67034 Berstett: merged into 67034 Berstett (INSEE); the whole commune is drawn
- Official names in this file follow INAO, which drops leading articles (e.g. "Arcs" for LAU "Les Arcs"); the gisco_id is the key.

## Style entry (style.json)

# Alsace: sourcing notes (2026-11-21)

Source keys: ALS = AOC Alsace cahier (BO 15 Jan 2026, doc 6fe90f2b); AGC = Alsace grand cru cahier (BO 15 Jan 2026, doc 47631e47); ACR = Crémant d'Alsace cahier (BO 5 Jun 2025, doc 66812bef); HV = Hachette Vins Alsace region page (regions-vins/76); VA = vinsalsace.com (AOC page, grape varieties page, Muscat page; Alsace interprofession, counted once); INAO = inao.gouv.fr/node/6425 product sheet.

## Kept
| Field | Claim | Sources |
|---|---|---|
| aliases | Vin d'Alsace | ALS (official alternative name) |
| summary | Vosges foothills | INAO ("collines du piémont des Vosges"), ALS (lien section) |
| summary | mostly dry white | HV (about 80% dry whites), VA (90% of AOC Alsace is white) |
| summary | sold under grape name | INAO ("le nom du cépage est stipulé sur l'étiquette"), HV (frequent on label, not mandatory) |
| summary | Pinot Noir red/rosé, Crémant | HV (10% red/rosé; crémant), VA (Crémant a quarter of production), ALS/ACR |
| label_note | varietal labels, no two grape names, Vin du Rhin flute, grand cru varieties, VT/SGN vintage + five grape names | ALS II 4° and 5°, IX 3° a), XII 2° b) and d); AGC II, V 1°, XII 2° e) |
| grapes | presence of the seven: Riesling, Gewurztraminer, Pinot Gris, Pinot Blanc, Sylvaner, Muscat, Pinot Noir | INAO (7 cépages), VA (grape page), HV (riesling, pinot blanc, gewurztraminer, pinot gris; pinot noir), ALS |
| grapes | Pinot Blanc may be Auxerrois | ALS (dénomination Pinot blanc = auxerrois B, pinot blanc B) |
| grapes | Muscat local_note | VA Muscat page ("most often ... Muscat à petits grains and Muscat Ottonel"), ALS (Muscat = muscat à petits grains B/Rs, muscat ottonel B); see grapes_a_notes.md |
| grapes | Pinot Noir only red/rosé grape | ALS (vins rouges/rosés: pinot noir N), HV |
| appellations | Alsace with 13 DGCs and lieux-dits; 51 grands crus, reds allowed only in Hengst, Kirchberg de Barr, Vorbourg; Crémant white/rosé, bottle fermented, rosé Pinot Noir only | ALS, AGC III, ACR |

## Held back
- **Grape order by planted area.** No fetched page gives planting shares (VA's key figure charts are images with no text). The order used puts Riesling first (first in INAO, VA and HV lists) and keeps the cahier's grand cru varieties ahead of the rest; treat it as presentation, not a ranking.
- **Pairing.** VA's food page gives only flavour principles per grape (e.g. Gewurztraminer for spicy, strong dishes); HV has no Alsace pairing text. No second source for a concrete dish.
- **Red ratings.** White-led region (HV 80% dry white), so red_* null by rule.
- **Auxerrois and Muscat Ottonel** as separate grapes: Auxerrois is on the allowed list but only appears as a component of Pinot Blanc labelling here; Ottonel is not on the allowed list.
- **Klevener de Heiligenstein** (Savagnin Rose) not included as a grape: one DGC only.
- Note on change: the 2026 grand cru cahier now allows Pinot Noir reds in three grands crus and Sylvaner only in Zotzenberg; older guides say grand cru is white only.
- Unreachable: Wine Folly Alsace guide URLs tried returned 404; web search budget for the turn was exhausted, so no further secondary sources were sought.

## Map
AOC Alsace and Crémant d'Alsace harvest areas are communes of Haut-Rhin and Bas-Rhin only (ALS IV 1°). Grand cru vinification areas extend to more Bas-Rhin communes (e.g. Strasbourg, Wissembourg) but those are not vineyard areas. The 13 DGCs and 51 grands crus all sit inside the AOC Alsace area.
