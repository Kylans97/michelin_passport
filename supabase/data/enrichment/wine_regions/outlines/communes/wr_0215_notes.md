# cotnari (Cotnari, RO): municipality mapping notes

Prepared 2026-11-21. CSV: cotnari.csv.

## Official text
- PDO Cotnari, EUGI00000004730, PDO-RO-A0135. Single document as published with the standard amendment PDO-RO-A0135-AM03, OJ C/2025/821, 13.2.2025 (http://data.europa.eu/eli/C/2025/821/oj; raw/cotnari_C2025_821_ro.txt). Later than AM02 (OJ L 2024/2774). Section 6 lists communes and villages in Iași and Botoșani. National specification linked: https://www.onvpv.ro/sites/default/files/caiet_sarcini_doc_cotnari_aprobat_rue_1913_2021_categorii_modif_cf_cerere_1316_10.07.2024_no_track_changes.pdf.

## How resolved
- As dealu-mare (SIRUTA s1 2026, tools: ro_resolve.py), județe Iași 22, Botoșani 7. All villages matched. partial: 8 of 9 UATs (only Balș whole). Băiceni is listed under both Cucuteni and Todirești, and SIRUTA has a Băiceni in each.
- The plai viticol names (Dealul Castel, etc.) are optional label names, not boundaries.

## Counts
- Rows: 9
- Partial: 8
- Provinces: Județul Botoșani, Județul Iași

## Held back / left out (style)
- Cotnari long dry autumns, sheltered slopes, six microclimates: Single document only. English Wikipedia's Cotnari article mentions microclimatic advantages but also vulnerability to early autumn frosts; not the same claim.
- Cotnari: Busuioacă de Bohotin and Fetească Neagră as Cotnari grapes: Both are in the single document and Busuioacă is on the Cotnari producer site, but Busuioacă has no app grape (see alias hold) and Fetească Neagră at Cotnari lacks a second source.
- Grasă de Cotnari tastes (apricot, walnut, almond, honey, raisins), acidity, Furmint relationship: Apricot/walnut/almond: Wikipedia only. Honey/raisins: single document only. 'Fine acid structure': Wikipedia only. Wikipedia links it to the Furmint group and VIVC lists FURMINT among its synonyms, but VIVC also gives pedigree Heunisch Weiss x unknown; relationship too unclear to state.

## Style content
See style.json. A claim was kept only where two independent sources agree; an EU single document and its national specification count as one government source.
