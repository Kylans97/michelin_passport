# Languedoc: communes and sourcing

**Defining AOC area(s):** AOC Languedoc (red/rosé and white areas), limited to Aude, Gard and Hérault.

AOC Languedoc's own area also covers 121 to 123 communes of Pyrénées-Orientales; those 244 rows are left to the separate Roussillon region so the two do not overlap. That department cut is our editorial choice, not an INAO boundary; say so if shown. The white area adds the Picpoul de Pinet zone (Pinet, Mèze, Florensac, Pomérols, Castelnau-de-Guers). Not checked against the Languedoc cahier des charges (not obtained: the shared web search budget ran out), so partial-commune clauses there are unverified. Val-du-Faby marked partial: the INAO list names only the former commune of Fa.

- Source: INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, file 2025-10-09-COMAGRI-Communes_Aires_AO.csv), merged communes resolved through INSEE v_mvt_commune_2026, mapped to GISCO LAU 2024 ids FR_<INSEE>. Same logic as scratchpad/fr_communes.py (script: scripts/fr_classics_communes.py).
- INAO rows per area: {'Languedoc': 409, 'Languedoc blanc': 414}
- LAU rows written: 412; unresolved INSEE codes: 0
- Partial (drawn whole): FR_11131 Val-du-Faby: INAO list names the former commune of Fa only; Rouvenac, merged into Val-du-Faby in 2019, is not listed; the whole commune is drawn
- Official names in this file follow INAO, which drops leading articles (e.g. "Arcs" for LAU "Les Arcs"); the gisco_id is the key.

## Style entry (style.json)

# Languedoc style notes

Map basis: AOC Languedoc area in Aude, Gard and Hérault. AOC Languedoc itself also covers Pyrénées-Orientales (INAO dataset: 195 Aude, 32 Gard, 182 Hérault and 121 Pyrénées-Orientales communes; CIVL lists departments 11, 30, 34 and 66; Hachette: the AOC covers "presque toutes les aires" of Languedoc and Roussillon). The appellation is therefore also listed under Roussillon, with a note.

## Kept

| Field | Value | Sources |
|---|---|---|
| summary: Aude, Gard, Hérault; red, rosé, white | | Hachette region page 98 (three departments, all colours); CIVL home and AOC Languedoc page |
| summary: sparkling Limoux, sweet Muscats | | Hachette region (effervescents, vins doux naturels); CIVL home (Blanquette, Crémant, Muscat de Lunel and Mireval as VDN); Wine Folly Languedoc-Roussillon (Limoux sparkling) |
| summary: reds blend Grenache, Syrah, Carignan, Mourvèdre | | Wine Folly ("Syrah, Grenache, Carignan, and Mourvèdre as major components"); CIVL AOC Languedoc; Hachette region |
| red_body | 4 | Wine Folly ("more full-bodied and fruit-driven"); Hachette AOC Languedoc ("Puissants et structurés", reds "puissants") |
| pairing | Picpoul de Pinet with oysters | Hachette Picpoul de Pinet ("parfaits pour les huîtres"); Wine Folly ("Perfect with oysters") |
| grapes | Grenache, Syrah, Carignan, Mourvèdre, Cinsault, Grenache Blanc | Hachette region and AOC page; CIVL AOC Languedoc page; Wine Folly (first four). Cinsault and Grenache Blanc on Hachette plus CIVL only |
| appellations | 11, see JSON | INAO dataset for existence; Hachette appellation pages for colour; CIVL for Terrasses du Larzac (red 100%, AOC since 2014) |

## Held back

| Item | Why |
|---|---|
| red_acidity, red_tannin | No source rates them for the region as a whole. Hachette varies by appellation (Saint-Chinian schist reds "faible acidité"; Fitou firm tannins), so no single value is honest. |
| label_note | AOC Languedoc cahier not obtained (search budget gone, INAO blocked). Hachette says fifteen geographic names may appear on the label, but that is not the cahier; not used. |
| Grapes not on the brief list | Clairette, Bourboulenc, Picpoul (Piquepoul), Lledoner Pelut: main local grapes per Hachette and CIVL, left out by rule. |
| Vermentino, Macabeo, Roussanne, Marsanne | Named, but Hachette calls the first group recent arrivals and Macabeu appears only on Hachette for Languedoc; not shown as main grapes by two sources. |
| Wider pairing for reds | Hachette lists red meat and game for several appellations; no second reachable source. |
| aliases | "Coteaux du Languedoc" (old name of the AOC until 2007) is on Hachette only. |
| Appellations left out for length | Clairette du Languedoc, Limoux (still), Blanquette de Limoux, Cabardès, Malepère, Grés de Montpellier, Corbières-Boutenac, Minervois-La Livinière, Muscat de Lunel, Muscat de Mireval, Muscat de Frontignan, Muscat de Saint-Jean-de-Minervois. All exist in the INAO dataset. |

## Session limits (apply to all three southern regions)

- The shared web search budget ran out after my first two searches, so no further searching was possible. Everything else came from pages I fetched directly or found through site sitemaps (winefolly.com/sitemap.xml, hachette-vins.com/sitemap.xml).
- INAO pages (www.inao.gouv.fr) return HTTP 403 to curl; not used.
- Official existence of each appellation: INAO "Aires géographiques des AOC/AOP" dataset (https://www.data.gouv.fr/datasets/aires-geographiques-des-aoc-aop), local copy scratchpad/dl_inao/ca.csv, read by name and department. Colour per appellation from the cahier where I hold it, otherwise from the Hachette Vins appellation page (one official source is the rule for appellations; the dataset is official but carries no colour, so colour rests on Hachette where no cahier was available; flagged).
- Cahiers des charges actually read (BO Agri): Bandol, homologated 11 Aug 2026 (BO 20 Aug 2026, id 5dba9fe2, the newest of four Bandol versions found); Côtes de Provence, homologated 22 Dec 2021 (id 04ce000c); Coteaux Varois en Provence, 25 Apr 2022 (id 56db90a9); Les Baux de Provence, 24 Oct 2024 (id 1af2db8a); Côtes du Roussillon, 15 Dec 2017 (raw/cdc_cdr.pdf).
- Not checked: whether a Côtes du Roussillon cahier newer than 2017 exists (no search budget). A search snippet suggested a Côtes de Provence DGC file dated 9 March 2026 on the INAO extranet; not opened, so the 2021 text was used. The five Côtes de Provence terroir names are the same in the 2021 cahier and on the INAO dataset.
- The Côtes du Roussillon cahier download URL was not recorded by whoever fetched it; sources cite it by its BO date and local path.
- Grape names: only names on the brief list used. Ranking order within grapes is not double sourced anywhere; order follows the order shared by the sources (reds before whites), and every grape listed has at least two sources naming it as a main grape.
- Unreachable or not tried: Wine Enthusiast, JancisRobinson, Decanter (see grapes_b_notes.md for the same session). France.fr and Wine Folly guessed URLs 404ed before the sitemap was used.



**Coordinator change:** the Corbières note "reds generally powerful and firm" was cut to a plain description (single source).
