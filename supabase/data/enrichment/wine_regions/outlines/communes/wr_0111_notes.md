# Provence: communes and sourcing

**Defining AOC area(s):** AOC Côtes de Provence, Coteaux d'Aix-en-Provence, Coteaux Varois en Provence and Bandol.

Côtes de Provence alone leaves a hole in central Var, which is Coteaux Varois en Provence, so it is added. Les Baux de Provence and Palette lie wholly inside this union. Cassis (1 commune), Bellet (Nice) and Pierrevert (11 communes, Alpes-de-Haute-Provence) lie outside and are not drawn; Cassis, Bellet and Palette appear as appellations in style.json. Côtes de Provence, Coteaux Varois and Bandol cahiers have no partial-commune clauses; the Coteaux d'Aix cahier was not obtained.

- Source: INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, file 2025-10-09-COMAGRI-Communes_Aires_AO.csv), merged communes resolved through INSEE v_mvt_commune_2026, mapped to GISCO LAU 2024 ids FR_<INSEE>. Same logic as scratchpad/fr_communes.py (script: scripts/fr_classics_communes.py).
- INAO rows per area: {'Côtes de Provence': 84, "Coteaux d'Aix-en-Provence": 49, 'Coteaux Varois en Provence': 28, 'Bandol': 8}
- LAU rows written: 163; unresolved INSEE codes: 0
- Partial (drawn whole): none
- Official names in this file follow INAO, which drops leading articles (e.g. "Arcs" for LAU "Les Arcs"); the gisco_id is the key.

## Style entry (style.json)

# Provence style notes

Map basis: Côtes de Provence, Coteaux d'Aix-en-Provence, Coteaux Varois en Provence and Bandol.

## Kept

| Field | Value | Sources |
|---|---|---|
| summary: rosé close to 90% | | Hachette region page 102 ("près de 90 %"); Wine Folly Provence guide ("88%"); Côtes de Provence cahier (rosé 89% of that AOC) |
| summary: mostly dry | | Wine Folly Provence rosé ("Dry"); Hachette Côtes de Provence ("vins secs") |
| summary: from Grenache, Cinsault, Syrah | | Côtes de Provence cahier (principal grapes for rosé); Hachette region (red and rosé grapes) |
| summary: Bandol long-lived reds on Mourvèdre | | Bandol cahier 2026 ("longue conservation", Mourvèdre dominant); Wine Folly Provence guide ("long-lived", at least 50% Mourvèdre); Hachette Bandol |
| red_body | 4 | Describes red Bandol, as the caller allowed: Wine Folly Bandol red ("Full Body"); Bandol cahier ("puissants, charpentés") |
| red_tannin | 4 | Red Bandol: Wine Folly ("High Tannins"); Bandol cahier ("tanniques"); Hachette Bandol ("structure tannique du mourvèdre") |
| pairing | rosé with charcuterie and cold starters | Wine Folly Provence rosé (charcuterie, cold appetisers); Hachette Côtes de Provence rosé (charcuterie, entrées) |
| label_note | Bandol red rule; Côtes de Provence terroir names | Bandol cahier homologated 11 Aug 2026: red plantings 50 to 95% Mourvèdre (V.2.a), reds aged at least 18 months in fûts or foudres (IX.2.a). Côtes de Provence cahier 2021, II: five dénominations géographiques complémentaires (La Londe for all three colours; the other four for red and rosé only). |
| grapes | Grenache, Cinsault, Syrah, Mourvèdre (note: leads Bandol reds), Vermentino (note: Rolle) | Côtes de Provence cahier; vinsdeprovence.com Côtes de Provence page; Hachette region; Wine Folly guide (Rolle aka Vermentino); Bandol cahier |
| appellations | 8 | cahiers for Côtes de Provence, Coteaux Varois, Bandol, Les Baux; Hachette for Coteaux d'Aix, Cassis, Bellet, Palette; Wine Folly guide for the short style notes (rosé leads, Cassis whites, Bellet Rolle, Palette smallest, Baux mostly red); INAO dataset for existence |

## Held back or flagged

| Item | Why |
|---|---|
| red_* describe Bandol, not a typical Provence red | Caller allowed Bandol. Hachette describes Côtes de Provence and Coteaux d'Aix reds as often light and supple, so the 4/4 ratings fit Bandol, not the average Provence red. If the app shows these as "the region's red", consider nulling them. |
| red_acidity | Only Wine Folly rates Bandol acidity (medium). |
| Pale colour of the rosé | Wine Folly only ("pale pink"); the CIVP page shows six colour shades and does not call them pale. |
| "France's leading rosé region" | Hachette ("première région en France") and CIVP (40 to 45% of French AOP rosé) agree in substance, but the wording is a superlative; left out of the summary. |
| Grapes not on the brief list | Tibouren, Clairette, Ugni Blanc. |
| Semillon, Carignan, Cabernet Sauvignon | Semillon is a principal white grape in the Côtes de Provence cahier, but no source ranks it as a main grape of the region; the other two are accessory grapes there. |
| Côtes de Provence cahier version | 2021 text used; a 2026 DGC file may exist (search snippet only, not opened). vinsdeprovence.com still names four terroir designations and treats Notre-Dame des Anges as a production area; the 2021 cahier lists all five. |
| Pierrevert | A Provence AOC per Wine Folly, outside the caller's list; not added. |
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



**Coordinator change:** red_body 4 and red_tannin 4 described red Bandol only; Hachette describes typical Côtes de Provence and Coteaux d'Aix reds as light and supple, so all red_* were set to null. The "largest" (Côtes de Provence) and "smallest" (Palette) wording was removed from appellation notes because the fetched sources do not say it.
