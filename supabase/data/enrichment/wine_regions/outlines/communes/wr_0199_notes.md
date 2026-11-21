# weststeiermark: municipality mapping notes

Prepared 2026-11-21. Source of truth for the boundary: the official text below.

## Official text

Weingesetz 2009 § 21 Abs. 3 Z 3 lit. b: „die Stadt Graz und die Gemeinden des politischen Bezirkes Graz-Umgebung mit Ausnahme der Gemeinden links der Mur sowie die politischen Bezirke Deutschlandsberg und Voitsberg“. DAC-Verordnung „Weststeiermark“ § 1 (idF BGBl. II Nr. 250/2024): DAC area equals the Weinbaugebiet. Schilcherland DAC: DAC-Verordnung „Schilcherland“ (BGBl. II Nr. 273/2017) was in force 12.10.2017 to 29.11.2018 and replaced by BGBl. II Nr. 299/2018 (Weststeiermark DAC); there is no current Schilcherland DAC.

Source URL: https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40254626/NOR40254626.html

Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer), checked against Statistik Austria Gemeindeliste 2026 and politische Bezirke (alps_hr/at/raw/). For every whole Bezirk, the LAU 2024 and Gemeindeliste 2026 code sets were asserted identical.

## Counts

- Rows: 49
- Partial: 1
- Länder/provinces: Steiermark

## Judgement calls

- Graz (AT_60101), Deutschlandsberg (603) and Voitsberg (616) whole; Graz-Umgebung (606) is the complement of the Vulkanland Steiermark split (round4/held/raw/grazumgebung_mur_sides.tsv, OSM Mur centreline): Gemeinden 90% or more left of the Mur are left out (they are in Vulkanland), slivers under 3% kept whole.
- Frohnleiten (AT_60663) is partial: about 27% left of the Mur, which is also its partial row in vulkanland-steiermark.csv. That is the only overlap with an existing Austrian region.
- Conflict noted: the product specification (section d) says Weststeiermark is the Bezirke Deutschlandsberg, Voitsberg, Graz and Graz-Umgebung, without the Mur exception. The law was followed, as for Vulkanland.

## Held back / left out

- Style: soils (gneiss and schist per the specification) left out of the summary: the second sources were read only as search excerpts.
- Style: other DAC grapes (Welschriesling, Sauvignon Blanc, Pinot Blanc and others) left out of the grape list: no area figures.

## Style content

See style.json. A claim was kept only where two independent sources agree; the EU or ministry specification and the DAC-Verordnung count as one government source, and all DWI pages and statistics count as one. Red structure scores are null for all regions: no two sources gave region-level body, acidity or tannin.
