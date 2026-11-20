# Kremstal: municipality mapping notes

Prepared 2026-11-20. Source of truth for the boundary: the official text below. Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer).

## Official text

„b) Kremstal: die Stadt Krems an der Donau und die Gemeinden Droß, Furth bei Göttweig, Gedersdorf, Paudorf, Rohrendorf bei Krems, Senftenberg und Stratzing;“ (Weingesetz 2009 § 21 Abs. 3 Z 1 lit. b)

Source URL(s): https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40254626/NOR40254626.html, https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40241629/NOR40241629.html

Weingesetz 2009 (BGBl. I Nr. 111/2009), § 21 Abs. 3, consolidated version on RIS, last amended by BGBl. I Nr. 91/2023 (in force 21.07.2023; that amendment changed § 21 Abs. 1, 6 and 8 only, Abs. 3 is the original wording). Read 2026-11-20 from the RIS consolidated PDF of document NOR40254626 (raw copy in raw/WG_21_NOR40254626.txt).

Municipality codes: Statistik Austria Gemeindeliste nach Gemeindekennziffer, Gebietsstand 2026 (raw/gemliste_knz.csv), and politische Bezirke (raw/polbezirke.csv). The first three digits of the Gemeindekennziffer are the current politischer Bezirk. All Gemeinden used here have identical codes and names in GISCO LAU 2024; the only 2024 to 2026 change in Austria (Fürstenfeld/Söchau merger, 2025) is outside these regions.

## Counts

- Rows in kremstal.csv: 8
- Partial: 0
- Provinces: Niederösterreich

## Judgement calls

- „Stadt Krems an der Donau“ is the Statutarstadt (AT_30101, Bezirk 301). The other seven names each matched exactly one Gemeinde, all in Bezirk Krems (Land) (313).
- The Kremstal DAC annex (Ortsangaben, BGBl. II Nr. 273/2017 as amended by BGBl. II Nr. 30/2022) names Katastralgemeinden such as Höbenbach and Krustetten (in Paudorf and Furth). They are label names inside the area, not a boundary change.

## Held back / left out

- None.
- Style: Climate held back: only the product specification describes it.

## Style content

See style.json. Climate, soil and style claims there were kept only where two independent sources agree (the official product specification published by the ministry counts as one; the DAC-Verordnung and the specification are treated as one government source). Red structure scores are null for all regions: no two independent sources gave region-level body, acidity or tannin, including for Leithaberg Blaufränkisch and Neusiedlersee Zweigelt.
