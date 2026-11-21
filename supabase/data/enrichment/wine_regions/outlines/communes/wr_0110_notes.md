# Roussillon: communes and sourcing

**Defining AOC area(s):** AOC Côtes du Roussillon plus Côtes du Roussillon Villages.

All 36 Villages communes are inside the 117 Côtes du Roussillon communes. Cahier 2017 (raw/cdc_cdr.pdf, BO 21 Dec 2017) has no partial-commune clauses; no newer version was checked. The Villages cahier was not obtained. Collioure/Banyuls communes (Banyuls-sur-Mer, Cerbère, Collioure, Port-Vendres) and Cluses, Amélie-les-Bains are in AOC Languedoc but not Côtes du Roussillon, so they are not drawn.

- Source: INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, file 2025-10-09-COMAGRI-Communes_Aires_AO.csv), merged communes resolved through INSEE v_mvt_commune_2026, mapped to GISCO LAU 2024 ids FR_<INSEE>. Same logic as scratchpad/fr_communes.py (script: scripts/fr_classics_communes.py).
- INAO rows per area: {'Côtes du Roussillon': 117, 'Côtes du Roussillon Villages': 36}
- LAU rows written: 116; unresolved INSEE codes: 0
- Partial (drawn whole): none
- Official names in this file follow INAO, which drops leading articles (e.g. "Arcs" for LAU "Les Arcs"); the gisco_id is the key.

## Style entry (style.json)

# Roussillon style notes

Map basis: AOC Côtes du Roussillon and Côtes du Roussillon Villages (Pyrénées-Orientales). The regional AOC Languedoc also covers 121 Pyrénées-Orientales communes (INAO dataset), so it is listed here with that note. Rivesaltes and Muscat de Rivesaltes each reach 9 Aude communes (INAO dataset; Hachette Rivesaltes: "empiète sur la zone des corbières").

## Kept

| Field | Value | Sources |
|---|---|---|
| summary: Pyrénées-Orientales; known for VDN (Banyuls, Maury, Rivesaltes) | | Hachette region page 100 ("réputé pour ses vins doux naturels"); roussillon.wine singularités (80% of French VDN output); roussillon.wine AOP list; Wine Folly (Banyuls VDN, Maury fortified Grenache) |
| summary: dry reds blend Grenache, Carignan, Syrah, Mourvèdre | | Côtes du Roussillon cahier (the four red main grapes); Hachette region; roussillon.wine cépages |
| red_body | 4 | Wine Folly (Languedoc-Roussillon reds "more full-bodied"); Hachette Côtes du Roussillon ("puissants et généreux", solid structure) and Villages ("fortement charpentés"). The Wine Folly line covers Languedoc-Roussillon jointly. |
| pairing | Red Banyuls with chocolate desserts | Wine Folly Banyuls ("pair exceptionally well with chocolate"); Hachette Banyuls (dessert, "notamment chocolat") |
| label_note | Red blend rules | Côtes du Roussillon cahier 2017, V.2: at least two grapes; Mourvèdre plus Syrah at least 25%; Carignan at most 50%. These are proportions of the grower's plantings (encépagement), worded as such. |
| grapes | Grenache, Carignan, Syrah, Mourvèdre, Grenache Blanc, Macabeo (local note: Macabeu), Muscat Blanc à Petits Grains | cahier (reds, Grenache Blanc, Macabeu); Hachette region; roussillon.wine cépages; Hachette Muscat de Rivesaltes plus roussillon.wine for the Muscat |
| appellations | 8 | INAO dataset for existence and the five Villages names; Hachette pages for colour and VDN status; roussillon.wine AOP list (dry versus VDN grouping, Villages names, Maury Sec and Maury Doux) |

Vins doux naturels are named as such in the appellation notes (Maury, Banyuls, Rivesaltes, Muscat de Rivesaltes), per Hachette and roussillon.wine, which also explains mutage (neutral alcohol added during fermentation).

## Held back

| Item | Why |
|---|---|
| red_acidity, red_tannin | No two sources rate dry Roussillon reds. Hachette Villages says "tanins délicats" while Collioure has "souplesse tannique" and Maury young wines are "tanniques"; not one value. |
| "most southerly vineyard in France" | Hachette only. |
| Old vines claim | roussillon.wine says the region has among the most old vines in the world; no second source. |
| Grapes not on the brief list | Lledoner Pelut, Malvoisie du Roussillon (Tourbat), Muscat d'Alexandrie, Grenache Gris: local main grapes, left out by rule. |
| Côtes du Roussillon Villages label rule | The five village names are in the INAO dataset and on roussillon.wine, but the Villages cahier was not obtained, so they appear only in the appellation note, not in label_note. |
| Newer Côtes du Roussillon cahier | 2017 text used; a newer version could not be searched for. |
| aliases | None sourced. |

## Session limits (apply to all three southern regions)

- The shared web search budget ran out after my first two searches, so no further searching was possible. Everything else came from pages I fetched directly or found through site sitemaps (winefolly.com/sitemap.xml, hachette-vins.com/sitemap.xml).
- INAO pages (www.inao.gouv.fr) return HTTP 403 to curl; not used.
- Official existence of each appellation: INAO "Aires géographiques des AOC/AOP" dataset (https://www.data.gouv.fr/datasets/aires-geographiques-des-aoc-aop), local copy scratchpad/dl_inao/ca.csv, read by name and department. Colour per appellation from the cahier where I hold it, otherwise from the Hachette Vins appellation page (one official source is the rule for appellations; the dataset is official but carries no colour, so colour rests on Hachette where no cahier was available; flagged).
- Cahiers des charges actually read (BO Agri): Bandol, homologated 11 Aug 2026 (BO 20 Aug 2026, id 5dba9fe2, the newest of four Bandol versions found); Côtes de Provence, homologated 22 Dec 2021 (id 04ce000c); Coteaux Varois en Provence, 25 Apr 2022 (id 56db90a9); Les Baux de Provence, 24 Oct 2024 (id 1af2db8a); Côtes du Roussillon, 15 Dec 2017 (raw/cdc_cdr.pdf).
- Not checked: whether a Côtes du Roussillon cahier newer than 2017 exists (no search budget). A search snippet suggested a Côtes de Provence DGC file dated 9 March 2026 on the INAO extranet; not opened, so the 2021 text was used. The five Côtes de Provence terroir names are the same in the 2021 cahier and on the INAO dataset.
- The Côtes du Roussillon cahier download URL was not recorded by whoever fetched it; sources cite it by its BO date and local path.
- Grape names: only names on the brief list used. Ranking order within grapes is not double sourced anywhere; order follows the order shared by the sources (reds before whites), and every grape listed has at least two sources naming it as a main grape.
- Unreachable or not tried: Wine Enthusiast, JancisRobinson, Decanter (see grapes_b_notes.md for the same session). France.fr and Wine Folly guessed URLs 404ed before the sitemap was used.

