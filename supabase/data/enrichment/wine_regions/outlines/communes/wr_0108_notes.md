# Beaujolais: communes and sourcing

**Defining AOC area(s):** AOC Beaujolais (with the Villages mention and the ten crus).

AOC Beaujolais covers the whole region; the Villages mention and all ten crus fall inside its 96 INAO rows (union adds nothing). Cahier BO 15 Sep 2022 (raw/bo_fc518a15-...). 96 rows collapse to 88 LAU ids because several former communes merged into communes nouvelles that are themselves listed. The cahier itself marks Vindry-sur-Turdine as partial (former Dareizé, Les Olmes, Saint-Loup only). Overlap: 26 of these communes are also in Burgundy (wr_0001), whose regional Bourgogne AOC area includes the Beaujolais cru communes.

- Source: INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, file 2025-10-09-COMAGRI-Communes_Aires_AO.csv), merged communes resolved through INSEE v_mvt_commune_2026, mapped to GISCO LAU 2024 ids FR_<INSEE>. Same logic as scratchpad/fr_communes.py (script: scripts/fr_classics_communes.py).
- INAO rows per area: {'Beaujolais': 96, 'Beaujolais Villages': 38, 'Brouilly': 6, 'Côte de Brouilly': 4, 'Chénas': 2, 'Chiroubles': 1, 'Fleurie': 1, 'Juliénas': 4, 'Morgon': 1, 'Moulin-à-Vent': 2, 'Régnié': 2, 'Saint-Amour': 1}
- LAU rows written: 88; unresolved INSEE codes: 0
- Partial (drawn whole): FR_69157 Vindry-sur-Turdine: merged into 69157 Vindry-sur-Turdine (INSEE); the whole commune is drawn
- Official names in this file follow INAO, which drops leading articles (e.g. "Arcs" for LAU "Les Arcs"); the gisco_id is the key.

## Style entry (style.json)

# Beaujolais: notes

Cahiers read (raw/bo_<id>.txt): AOC Beaujolais, BO 15 Sept 2022 (arrêté 2 Sept 2022), id fc518a15; the ten crus, all arrêtés of 20 Feb 2024 (BO 14 Mar 2024; Morgon republished BO 2 Jan 2025). An older Beaujolais text (décret 2011, id 61bc21c9) was also found and not used. No newer Beaujolais version was found, but the web search budget ran out, so a post-2022 revision cannot be ruled out.

## Kept
- summary: Gamay dominant (Inter Beaujolais gamay page "98 %"; Wine Folly gamay "main variety planted in Beaujolais"); mostly light fruity reds (Wine Folly Beaujolais "Most Beaujolais are simple, rustic reds", medium-light body; Inter Beaujolais rouge page "frais, peu alcoolisés", 95 % red; cahier "robe légère ... gouleyants, fruités"); Nouveau (cahier + Inter rouge page); ten crus (Wine Folly + Inter); white from Chardonnay (cahier "seul cépage chardonnay B"; Inter home "2 cépages").
- red_body 2: Wine Folly Beaujolais "Medium-light Body" (gamay page agrees, same site); Inter Beaujolais "peu alcoolisés", "souples"; cahier "robe légère".
- red_tannin 2: Wine Folly "Low Tannins" (gamay page "No Tannins"); Inter Beaujolais "tanins fins", Gamay "souples". Inter also says terroirs give wines "plus ou moins tanniques", so 2 is the typical, not universal, level.
- pairing: Wine Folly "from barbecue beef to cedar-planked salmon"; Inter Beaujolais "spécialités lyonnaises ... poisson ... cuisine d'Asie". Kept only the common ground (meat and fish).
- label_note: Beaujolais cahier ch. I §II and §XII (Villages, commune name same size as appellation, primeur/nouveau red and rosé only with mandatory vintage); every cru cahier §XII 2° b allows "Cru du Beaujolais" (checked in all ten).
- grapes: Gamay, Chardonnay (see summary). Accessory grapes in the cahier (aligoté, melon, pinot noir, pinot gris, gamay de Bouze, gamay de Chaudenay, max 15 % / 10 %) are not main grapes; left out.
- appellations: Beaujolais (red, rosé, white: cahier §III), Beaujolais Villages, and ten crus, each "réservée aux vins tranquilles rouges" in its own cahier §III. Cross-checked against Inter Beaujolais "Nos 12 appellations".
- aliases: "Vin du Beaujolais" (cahier §XII allows it as the larger geographical unit; Inter site titled "Vins du Beaujolais").

## Held back
- red_acidity: Wine Folly says medium-high, but the cahiers conflict (Fleurie "acidité peu marquée"; primeur "acidulés") and Inter Beaujolais only says "frais". Not two clear agreeing sources.
- Beaujolais Villages is legally a complementary mention of AOC Beaujolais (cahier §II 2°), not a separate AOC. Kept as an entry because the brief lists it and Inter Beaujolais counts it among 12 appellations; its note says it is a mention. Drop it if only standalone AOCs are wanted.
- "Supérieur" mention, the Beaujolais + commune name + nouveau transitional rule (to harvest 2025), the "third Thursday of November" date (appears only in the cahier's history section, not as a rule): left out of label_note.
- Cru by cru style notes (e.g. Fleurie light, Moulin-à-Vent structured): single sourced, not used.
