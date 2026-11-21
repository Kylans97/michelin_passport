# Cahors: communes and sourcing

**Defining AOC area(s):** AOC Cahors.

45 INAO rows, 42 LAU ids after mergers. Barguelonne-en-Quercy is drawn whole for former Bagat-en-Quercy (marked partial; Saint-Pantaléon, merged into it in 2019, is not listed). The Cahors cahier (décret 2011) was read for style only; its commune list was not cross-checked.

- Source: INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, file 2025-10-09-COMAGRI-Communes_Aires_AO.csv), merged communes resolved through INSEE v_mvt_commune_2026, mapped to GISCO LAU 2024 ids FR_<INSEE>. Same logic as scratchpad/fr_communes.py (script: scripts/fr_classics_communes.py).
- INAO rows per area: {'Cahors': 45}
- LAU rows written: 42; unresolved INSEE codes: 0
- Partial (drawn whole): FR_46263 Barguelonne-en-Quercy: merged into 46263 Barguelonne-en-Quercy (INSEE); the whole commune is drawn
- Official names in this file follow INAO, which drops leading articles (e.g. "Arcs" for LAU "Les Arcs"); the gisco_id is the key.

## Style entry (style.json)

# Cahors: notes

Cahier read: AOC Cahors, décret n° 2011-1367 of 24 Oct 2011, inside a BO Agri compilation PDF (raw/bo_302391de-...txt, from line 10620). This is the cahier the INAO product page (www.inao.gouv.fr/node/2108) links to as current. A later amendment was not found; the web search budget ran out before a BO Agri search for a newer Cahors text could be made, so this is worth one more check.

## Kept
- summary: red only (cahier §III; UIVC vindecahors.fr "réservée exclusivement aux vins rouges"); Lot river (cahier §X; Lot Tourisme; INAO page); Malbec/Côt with Merlot and Tannat (cahier §V; UIVC; Lot Tourisme); dark colour (cahier "forte intensité colorante"; Lot Tourisme "robe sombre", "vin noir"; INAO page "couleur sombre et profonde"); ageing (cahier "bonne aptitude au vieillissement"; Lot Tourisme "évoluer longtemps en bouteille").
- label_note (cahier): §III still red only; §V 2° b "cot N ... supérieure ou égale à 70 % de l'encépagement" (assessed on the estate's plantings, not per blend; UIVC and Lot Tourisme phrase it as 70 % of the blend); §XII 2° labels may add "Sud-Ouest", characters no larger than the appellation name.
- grapes: Malbec (cahier "cot N (également appelé malbec)", principal), Merlot, Tannat (accessory) per cahier, UIVC, Lot Tourisme. Merlot before Tannat is not a sourced order (cahier lists Merlot first, UIVC Tannat first).
- appellations: Cahors only.
- aliases: "AOC Cahors" (cahier), "Vin de Cahors" (cahier and INAO page).

## Held back
- red_body, red_acidity, red_tannin: no second independent source describing Cahors (not Malbec in general). Cahier says tannins "peuvent être particulièrement bien présents"; Lot Tourisme says "puissant" but nothing on tannin or acidity; Wine Folly's Malbec profile (full body, medium tannin, medium-low acidity) is generic Malbec, mainly Argentina, not Cahors. INAO's product page is not independent of the cahier (same body). Decanter/Wine Scholar Guild Cahors pages could not be located (404 on guessed URLs; search budget exhausted).
- pairing: only Lot Tourisme is specific (meat, stews, duck, lamb, cheese, truffle); INAO says only "la plupart de vos plats"; UIVC pairing page had no text. Single sourced, held.
- "Black wine" nickname: Lot Tourisme only; left out.
