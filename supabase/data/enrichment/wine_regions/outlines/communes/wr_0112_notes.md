# Jura: communes and sourcing

**Defining AOC area(s):** AOC Côtes du Jura (Arbois, Château-Chalon and L'Etoile lie inside it).

Cahier Côtes du Jura BO 29 Sep 2022 (raw/bo_40d171ab-...). Three communes are partial by the cahier's own words: La Chailleuse (only former Saint-Laurent-la-Roche), Trenal (only former Trenal), Val-Sonnette (only former Grusse, Vercia, Vincelles). Communes nouvelles listed whole in the cahier (Arlay, Beaufort-Orbagna, Domblans, Les Trois-Châteaux, Saint-Cyr-Montmalin) are not partial. Doubs communes in the Arbois and Macvin cahiers are a winemaking proximity zone only.

- Source: INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, file 2025-10-09-COMAGRI-Communes_Aires_AO.csv), merged communes resolved through INSEE v_mvt_commune_2026, mapped to GISCO LAU 2024 ids FR_<INSEE>. Same logic as scratchpad/fr_communes.py (script: scripts/fr_classics_communes.py).
- INAO rows per area: {'Côtes du Jura': 100, 'Arbois': 12, 'Château-Chalon': 4, "L'Etoile": 4}
- LAU rows written: 97; unresolved INSEE codes: 0
- Partial (drawn whole): FR_39021 La Chailleuse: cahier Côtes du Jura (BO 29 Sep 2022): only the former commune of Saint-Laurent-la-Roche; the whole commune is drawn; FR_39537 Trenal: cahier Côtes du Jura (BO 29 Sep 2022): only the former commune of Trenal; the whole commune is drawn; FR_39576 Val-Sonnette: cahier Côtes du Jura (BO 29 Sep 2022): only the former communes of Grusse, Vercia and Vincelles; the whole commune is drawn
- Official names in this file follow INAO, which drops leading articles (e.g. "Arcs" for LAU "Les Arcs"); the gisco_id is the key.

## Style entry (style.json)

# Jura: sourcing notes (2026-11-21)

Source keys: CDJ = Côtes du Jura cahier (BO 29 Sep 2022, doc 40d171ab); ARB = Arbois (BO 15 Sep 2022, f3ff41c6); CHC = Château-Chalon (BO 27 Aug 2026, 80d3d5a7); ETO = L'Etoile (BO 17 Sep 2026, 7d79e5e4); CRJ = Crémant du Jura (BO 5 Dec 2019, 3639eb82); MAC = Macvin du Jura (BO 11 Dec 2025, 3fdd2783). GS-L = GuildSomm, Wink Lorch, Jura wine styles; HV = Hachette Vins Jura page; FR = france.fr Jura article; JV = jura-vins.com (interprofession; vin jaune page and pairing page, counted once); SAQ = SAQ Savagnin profile.

## Kept
| Field | Claim | Sources |
|---|---|---|
| summary | one of France's smaller regions | GS-L ("one of France's smaller wine regions"), FR ("good things come in small packages") |
| summary | mostly white, Chardonnay and Savagnin | HV (whites two thirds of production; chardonnay and savagnin), GS-L (Chardonnay 43.5% and Savagnin about 25% of plantings) |
| summary | vin jaune: Savagnin, over six years in oak under veil of yeast | HV, GS-L, FR, JV, CDJ |
| pairing | vin jaune with Comté | GS-L, JV (Comté among cheeses for vin jaune), SAQ (firm cheeses like comté) |
| label_note | vin jaune élevage to 15 Dec of 6th year, 60 months under veil, clavelin about 62 cl reserved to vin jaune | CDJ IX 2° a), 3° b); CHC (62 cl clavelin) |
| grapes | five grapes; Chardonnay > Savagnin > Poulsard = Pinot Noir > Trousseau | presence: HV, FR, GS-L, CDJ; order: GS-L percentages only |
| grapes | Poulsard called Ploussard | CDJ ("appelé localement ploussard"), GS-L |
| appellations | six AOCs and their colours | CDJ, ARB, CHC, ETO, CRJ, MAC; GS-L and HV list the same six |

## Held back
- **Red ratings.** Two thirds white (HV), so treated as white-led and red_* left null. Also not double sourced: GS-L says Jura reds have high acidity and light to moderate grippy tannins; HV and FR describe Poulsard as light and low in tannin but Trousseau as more tannic. Only GS-L gives acidity. Tannin conflicts by grape.
- **Grape order after Savagnin** rests on GS-L's planting figures alone; presence of all five is double sourced.
- **Poultry with cream or morels** for vin jaune: JV gives it; SAQ mentions vin jaune as a sauce for poultry (cooking use, not a match). Not kept.
- **Vin de paille** details (CDJ: at least 6 weeks drying, 320 to 420 g/l sugar) left out of label_note to keep it to two sentences.
- **Crémant du Jura cahier date.** The newest BO version found is 2019; a 2023 temporary modification notice exists. Content used (white or rosé sparkling) is basic and stable.
- **Aliases:** none sourced.

## Map
All six AOCs harvest only in communes of the Jura département (CDJ, ARB, CHC, ETO, CRJ, MAC IV 1°). Côtes du Jura's commune list contains Arbois, Château-Chalon and L'Etoile communes, so Côtes du Jura plus Arbois defines the region; Crémant du Jura and Macvin cover the same whole area (GS-L). Doubs communes appear only as the "aire de proximité immédiate" (winemaking zone), not as vineyard area: do not draw them.
